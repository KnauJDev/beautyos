-- ===========================================================================
-- BeautyOS / Salón y Más — Migración de Seguridad y Blindaje RLS (D-139)
-- Fecha: 16 de agosto de 2026
--
-- Propósito:
-- 1. Activar Row Level Security (RLS) en la tabla `public.tenants` y `public.user_profiles`,
--    cerrando el vector de lectura directa por PostgREST para datos sensibles
--    (city, estimated_team_size, referral_source, rejection_reason, contact_email, whatsapp).
-- 2. Añadir política de aislamiento multi-tenant estricta para lectura (solo miembros
--    activos de ese salón o el platform_owner).
-- 3. Añadir guards de estado en `public.platform_approve_tenant` (solo permite aprobar
--    negocios en estado 'pending' o 'rejected', evitando sobreescrituras accidentales
--    de planes o reset de pruebas a clientes activos).
-- 4. Añadir guard de estado en `public.platform_reject_tenant` (solo permite rechazar
--    solicitudes en estado 'pending', impidiendo desactivar por error a clientes activos).
-- ===========================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1. Blindaje RLS en `public.tenants` y `public.user_profiles`
-- ---------------------------------------------------------------------------

alter table public.tenants enable row level security;
alter table public.user_profiles enable row level security;

revoke all on table public.tenants from public, anon;
revoke all on table public.user_profiles from public, anon;

-- Solo lectura autenticada gobernada por RLS; escrituras únicamente vía RPCs SECURITY DEFINER
grant select on table public.tenants to authenticated;
grant select on table public.user_profiles to authenticated;

grant all on table public.tenants to service_role;
grant all on table public.user_profiles to service_role;

-- Política de aislamiento en tenants: un usuario solo puede ver su propio salón
-- o el platform_owner puede ver todos los salones.
drop policy if exists tenant_isolation_select on public.tenants;
create policy tenant_isolation_select on public.tenants
  for select
  to authenticated
  using (
    id in (
      select tm.tenant_id
      from public.tenant_memberships tm
      where tm.user_id = auth.uid() and tm.active = true
    )
    or private.beautyos_current_platform_role() = 'platform_owner'
  );

-- Política de aislamiento en user_profiles: ver perfiles del propio salón o platform_owner
drop policy if exists user_profiles_isolation_select on public.user_profiles;
create policy user_profiles_isolation_select on public.user_profiles
  for select
  to authenticated
  using (
    tenant_id in (
      select tm.tenant_id
      from public.tenant_memberships tm
      where tm.user_id = auth.uid() and tm.active = true
    )
    or private.beautyos_current_platform_role() = 'platform_owner'
  );

-- ---------------------------------------------------------------------------
-- 2. Actualización de `public.platform_approve_tenant` con Guard de Estado
-- ---------------------------------------------------------------------------

drop function if exists public.platform_approve_tenant(uuid, text, boolean, bigint, numeric, timestamptz, text, integer);
drop function if exists public.platform_approve_tenant(uuid, text, integer, boolean, numeric, numeric, timestamptz, text);

create or replace function public.platform_approve_tenant(
  p_tenant_id uuid,
  p_plan_code text default 'profesional',
  p_is_founder boolean default false,
  p_price_cop bigint default null,
  p_discount_percent numeric default null,
  p_discount_ends_at timestamptz default null,
  p_price_reason text default null,
  p_trial_days integer default 21
)
returns public.tenant_subscriptions
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_caller_role text := private.beautyos_current_platform_role();
  v_plan_id uuid;
  v_trial_days integer := greatest(1, coalesce(p_trial_days, 21));
  v_trial_ends_at timestamptz := now() + (v_trial_days || ' days')::interval;
  v_subscription public.tenant_subscriptions%rowtype;
  v_current_status text;
  v_discount_percent numeric(5,2) := p_discount_percent;
  v_price_reason text := nullif(trim(coalesce(p_price_reason, '')), '');
begin
  if v_caller_role is null or v_caller_role != 'platform_owner' then
    raise exception 'No autorizado: solo el dueño de la plataforma puede aprobar negocios.';
  end if;

  -- Guard de Estado (D-139 / Auditoría Claude):
  -- Solo se pueden aprobar solicitudes en estado 'pending' o 'rejected'.
  select ts.status into v_current_status
  from public.tenant_subscriptions ts
  where ts.tenant_id = p_tenant_id;

  if v_current_status is null then
    raise exception 'No se encontro la suscripcion para el negocio indicado.';
  end if;

  if v_current_status not in ('pending', 'rejected') then
    raise exception 'No se puede aprobar un negocio con estado "%". Solo se pueden aprobar solicitudes pendientes o previamente rechazadas.', v_current_status;
  end if;

  select p.id into v_plan_id
  from public.plans p
  where p.code = lower(trim(p_plan_code)) and p.status = 'active';

  if v_plan_id is null then
    raise exception 'El plan especificado (%) no existe o no esta activo.', p_plan_code;
  end if;

  -- Si es pionero, descuento 50% sin fecha de fin (D-124, D-136)
  if p_is_founder is true then
    v_discount_percent := coalesce(v_discount_percent, 50.00);
    if v_price_reason is null then
      v_price_reason := 'Pionero (50% de por vida)';
    end if;
  end if;

  -- Validar motivo obligatorio si hay precio propio o descuento
  if (p_price_cop is not null or v_discount_percent is not null) and v_price_reason is null then
    raise exception 'Debes ingresar un motivo para el precio especial o descuento.';
  end if;

  update public.tenant_subscriptions
  set
    plan_id = v_plan_id,
    status = 'trialing',
    trial_ends_at = v_trial_ends_at,
    current_period_start = now(),
    is_founder = coalesce(p_is_founder, false),
    price_cop = p_price_cop,
    discount_percent = v_discount_percent,
    discount_ends_at = p_discount_ends_at,
    price_reason = v_price_reason,
    updated_at = now()
  where tenant_id = p_tenant_id
  returning * into v_subscription;

  if not found then
    raise exception 'No se encontro la suscripcion para el negocio indicado.';
  end if;

  update public.tenants
  set
    active = true,
    rejection_reason = null
  where id = p_tenant_id;

  insert into public.subscription_events (
    tenant_id,
    tenant_subscription_id,
    event_type,
    payload,
    created_by
  ) values (
    p_tenant_id,
    v_subscription.id,
    'tenant_approved',
    jsonb_build_object(
      'plan_code', p_plan_code,
      'is_founder', coalesce(p_is_founder, false),
      'trial_days', v_trial_days,
      'trial_ends_at', v_trial_ends_at,
      'price_cop', p_price_cop,
      'discount_percent', v_discount_percent,
      'price_reason', v_price_reason,
      'previous_status', v_current_status
    ),
    auth.uid()
  );

  return v_subscription;
end;
$$;

revoke all on function public.platform_approve_tenant(uuid, text, boolean, bigint, numeric, timestamptz, text, integer) from public, anon;
grant execute on function public.platform_approve_tenant(uuid, text, boolean, bigint, numeric, timestamptz, text, integer) to authenticated;

comment on function public.platform_approve_tenant(uuid, text, boolean, bigint, numeric, timestamptz, text, integer)
  is 'Aprueba la solicitud de un negocio (en pending o rejected), arrancando su prueba gratis y fijando su plan/descuentos.';

-- ---------------------------------------------------------------------------
-- 3. Actualización de `public.platform_reject_tenant` con Guard de Estado
-- ---------------------------------------------------------------------------

drop function if exists public.platform_reject_tenant(uuid, text);

create or replace function public.platform_reject_tenant(
  p_tenant_id uuid,
  p_reason text
)
returns public.tenant_subscriptions
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_caller_role text := private.beautyos_current_platform_role();
  v_reason text := trim(coalesce(p_reason, ''));
  v_subscription public.tenant_subscriptions%rowtype;
  v_current_status text;
begin
  if v_caller_role is null or v_caller_role != 'platform_owner' then
    raise exception 'No autorizado: solo el dueño de la plataforma puede rechazar solicitudes.';
  end if;

  if length(v_reason) = 0 then
    raise exception 'Debes especificar un motivo para el rechazo.';
  end if;

  -- Guard de Estado (D-139 / Auditoría Claude):
  -- Solo se pueden rechazar solicitudes en estado 'pending'.
  select ts.status into v_current_status
  from public.tenant_subscriptions ts
  where ts.tenant_id = p_tenant_id;

  if v_current_status is null then
    raise exception 'No se encontro la suscripcion para el negocio indicado.';
  end if;

  if v_current_status != 'pending' then
    raise exception 'Solo se pueden rechazar solicitudes en estado "pending" (estado actual: %).', v_current_status;
  end if;

  update public.tenant_subscriptions
  set
    status = 'rejected',
    trial_ends_at = null,
    updated_at = now()
  where tenant_id = p_tenant_id
  returning * into v_subscription;

  if not found then
    raise exception 'No se encontro la suscripcion para el negocio indicado.';
  end if;

  update public.tenants
  set
    rejection_reason = v_reason,
    active = false
  where id = p_tenant_id;

  insert into public.subscription_events (
    tenant_id,
    tenant_subscription_id,
    event_type,
    payload,
    created_by
  ) values (
    p_tenant_id,
    v_subscription.id,
    'tenant_rejected',
    jsonb_build_object(
      'rejection_reason', v_reason,
      'previous_status', v_current_status
    ),
    auth.uid()
  );

  return v_subscription;
end;
$$;

revoke all on function public.platform_reject_tenant(uuid, text) from public, anon;
grant execute on function public.platform_reject_tenant(uuid, text) to authenticated;

comment on function public.platform_reject_tenant(uuid, text)
  is 'Rechaza respetuosamente una solicitud de negocio en estado pending guardando el motivo sin borrado fisico.';

commit;
