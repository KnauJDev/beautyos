-- BeautyOS / Salón y Más - Paso 3.7: Filtro de Aceptación ("Nadie entra solo" - D-125).
--
-- Modifica el flujo de registro self-serve para que un negocio nuevo nazca en
-- estado 'pending' (sin arrancar la prueba gratis) hasta que el dueño de la
-- plataforma lo apruebe desde su panel, fijando el plan, precio o descuento
-- pionero, e iniciando la prueba gratis de 21 días en el instante de la aprobación.
--
-- Si se rechaza, se guarda el motivo y se marca como 'rejected' sin borrado físico (D-051/D-056).

begin;

-- ---------------------------------------------------------------------------
-- 1. Columnas de cuestionario de solicitud en `public.tenants`
-- ---------------------------------------------------------------------------

alter table public.tenants
  add column if not exists city text,
  add column if not exists estimated_branches integer not null default 1 check (estimated_branches > 0),
  add column if not exists estimated_team_size integer not null default 1 check (estimated_team_size > 0),
  add column if not exists referral_source text,
  add column if not exists rejection_reason text;

comment on column public.tenants.city is 'Ciudad donde opera el negocio principal.';
comment on column public.tenants.estimated_branches is 'Número de sedes estimadas del negocio.';
comment on column public.tenants.estimated_team_size is 'Número estimado de personas en el equipo.';
comment on column public.tenants.referral_source is 'Cómo conoció Salón y Más. Alimenta el sistema de referidos (Fase 7).';
comment on column public.tenants.rejection_reason is 'Motivo del rechazo de la solicitud si no fue aprobada (D-125).';

-- ---------------------------------------------------------------------------
-- 2. Permitir estado 'rejected' en `tenant_subscriptions`
-- ---------------------------------------------------------------------------

alter table public.tenant_subscriptions
  drop constraint if exists tenant_subscriptions_status_check;

alter table public.tenant_subscriptions
  add constraint tenant_subscriptions_status_check
  check (status in ('pending', 'trialing', 'active', 'past_due', 'grace', 'suspended', 'cancelled', 'rejected'));

-- ---------------------------------------------------------------------------
-- 3. Reemplazo de `register_tenant` con formulario enriquecido y estado 'pending'
-- ---------------------------------------------------------------------------

drop function if exists public.register_tenant(text, text, text, text);

create or replace function public.register_tenant(
  p_business_name text,
  p_owner_full_name text,
  p_whatsapp text,
  p_business_type text default null,
  p_city text default null,
  p_estimated_branches integer default 1,
  p_estimated_team_size integer default 1,
  p_referral_source text default null
)
returns table (
  tenant_id uuid,
  branch_id uuid,
  status text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_email text;
  v_tenant_id uuid;
  v_branch_id uuid;
  v_tenant_membership_id uuid;
  v_plan_id uuid;
  v_subscription_id uuid;
begin
  if v_user_id is null then
    raise exception 'Se requiere una sesion autenticada para registrar un negocio.';
  end if;

  if exists (
    select 1 from public.tenant_memberships where user_id = v_user_id
  ) then
    raise exception 'Este usuario ya pertenece a un negocio.';
  end if;

  if length(trim(coalesce(p_business_name, ''))) = 0 then
    raise exception 'El nombre del negocio es obligatorio.';
  end if;

  if length(trim(coalesce(p_owner_full_name, ''))) = 0 then
    raise exception 'Tu nombre completo es obligatorio.';
  end if;

  if length(trim(coalesce(p_whatsapp, ''))) = 0 then
    raise exception 'El WhatsApp de contacto es obligatorio.';
  end if;

  select email into v_email from auth.users where id = v_user_id;
  if v_email is null then
    raise exception 'No se encontro un correo asociado a esta sesion.';
  end if;

  select p.id into v_plan_id
  from public.plans p
  where p.code = 'profesional' and p.status = 'active';

  if v_plan_id is null then
    raise exception 'No hay un plan disponible para registrar la solicitud.';
  end if;

  insert into public.tenants (
    name,
    business_type,
    contact_email,
    whatsapp,
    city,
    estimated_branches,
    estimated_team_size,
    referral_source,
    active
  ) values (
    trim(p_business_name),
    nullif(trim(coalesce(p_business_type, '')), ''),
    v_email,
    trim(p_whatsapp),
    nullif(trim(coalesce(p_city, '')), ''),
    greatest(1, coalesce(p_estimated_branches, 1)),
    greatest(1, coalesce(p_estimated_team_size, 1)),
    nullif(trim(coalesce(p_referral_source, '')), ''),
    true
  )
  returning id into v_tenant_id;

  insert into public.branches (tenant_id, name, slug, is_primary)
  values (v_tenant_id, trim(p_business_name), 'principal', true)
  returning id into v_branch_id;

  insert into public.user_profiles (tenant_id, user_id, full_name, role, active)
  values (v_tenant_id, v_user_id, trim(p_owner_full_name), 'owner', true);

  insert into public.tenant_memberships (tenant_id, user_id, role, active, starts_at)
  values (v_tenant_id, v_user_id, 'tenant_owner', true, now())
  returning id into v_tenant_membership_id;

  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (
    v_tenant_id, v_branch_id, v_tenant_membership_id, true, now(), v_user_id
  );

  insert into public.business_hours (
    tenant_id, branch_id, day_of_week, opens_at, closes_at, is_open
  )
  select
    v_tenant_id,
    v_branch_id,
    schedule.day_of_week,
    schedule.opens_at,
    schedule.closes_at,
    schedule.is_open
  from (
    values
      (1, time '08:00', time '20:00', true),
      (2, time '08:00', time '20:00', true),
      (3, time '08:00', time '20:00', true),
      (4, time '08:00', time '20:00', true),
      (5, time '08:00', time '20:00', true),
      (6, time '08:00', time '20:00', true),
      (7, null::time, null::time, false)
  ) as schedule(day_of_week, opens_at, closes_at, is_open);

  insert into public.appointment_policies (tenant_id, branch_id)
  values (v_tenant_id, v_branch_id);

  insert into public.commission_policies (tenant_id)
  values (v_tenant_id);

  -- Filtro de Aceptación (D-125): el negocio nace en estado 'pending'.
  -- La prueba gratis NO arranca aquí (trial_ends_at = NULL).
  insert into public.tenant_subscriptions (
    tenant_id, plan_id, status, trial_ends_at, current_period_start
  ) values (
    v_tenant_id, v_plan_id, 'pending', null, null
  )
  returning id into v_subscription_id;

  insert into public.subscription_events (
    tenant_id, tenant_subscription_id, event_type, payload, created_by
  ) values (
    v_tenant_id,
    v_subscription_id,
    'registration_requested',
    jsonb_build_object(
      'business_name', trim(p_business_name),
      'owner_full_name', trim(p_owner_full_name),
      'city', nullif(trim(coalesce(p_city, '')), ''),
      'business_type', nullif(trim(coalesce(p_business_type, '')), ''),
      'estimated_branches', p_estimated_branches,
      'estimated_team_size', p_estimated_team_size,
      'referral_source', nullif(trim(coalesce(p_referral_source, '')), '')
    ),
    v_user_id
  );

  return query select v_tenant_id, v_branch_id, 'pending'::text;
end;
$$;

revoke all on function public.register_tenant(text, text, text, text, text, integer, integer, text) from public, anon;
grant execute on function public.register_tenant(text, text, text, text, text, integer, integer, text) to authenticated;

comment on function public.register_tenant(text, text, text, text, text, integer, integer, text)
  is 'Registra una solicitud de nuevo negocio en estado pendiente de aprobacion (D-125).';

-- ---------------------------------------------------------------------------
-- 4. Consulta del estado de aprobación y suscripción para el usuario autenticado
-- ---------------------------------------------------------------------------

create or replace function public.get_my_tenant_subscription_status()
returns table (
  tenant_id uuid,
  tenant_name text,
  subscription_status text,
  plan_code text,
  plan_name text,
  trial_ends_at timestamptz,
  is_founder boolean,
  price_cop bigint,
  discount_percent numeric,
  rejection_reason text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_tenant_id uuid;
begin
  if v_user_id is null then
    raise exception 'Se requiere una sesion autenticada.';
  end if;

  select tm.tenant_id into v_tenant_id
  from public.tenant_memberships tm
  where tm.user_id = v_user_id
    and tm.active
  limit 1;

  if v_tenant_id is null then
    return;
  end if;

  return query
  select
    t.id as tenant_id,
    t.name as tenant_name,
    ts.status as subscription_status,
    p.code as plan_code,
    p.name as plan_name,
    ts.trial_ends_at,
    ts.is_founder,
    ts.price_cop,
    ts.discount_percent,
    t.rejection_reason,
    t.created_at
  from public.tenants t
  join public.tenant_subscriptions ts on ts.tenant_id = t.id
  join public.plans p on p.id = ts.plan_id
  where t.id = v_tenant_id;
end;
$$;

revoke all on function public.get_my_tenant_subscription_status() from public, anon;
grant execute on function public.get_my_tenant_subscription_status() to authenticated;

comment on function public.get_my_tenant_subscription_status()
  is 'Consulta el estado de aprobacion y suscripcion del negocio del usuario autenticado (D-125).';

-- ---------------------------------------------------------------------------
-- 5. RPC `platform_approve_tenant`: Aprobar negocio e iniciar prueba
-- ---------------------------------------------------------------------------

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
  v_discount_percent numeric(5,2) := p_discount_percent;
  v_price_reason text := nullif(trim(coalesce(p_price_reason, '')), '');
begin
  if v_caller_role is null or v_caller_role != 'platform_owner' then
    raise exception 'No autorizado: solo el dueño de la plataforma puede aprobar negocios.';
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
      'discount_ends_at', p_discount_ends_at,
      'price_reason', v_price_reason,
      'approved_by', auth.uid()
    ),
    auth.uid()
  );

  return v_subscription;
end;
$$;

revoke all on function public.platform_approve_tenant(uuid, text, boolean, bigint, numeric, timestamptz, text, integer) from public, anon;
grant execute on function public.platform_approve_tenant(uuid, text, boolean, bigint, numeric, timestamptz, text, integer) to authenticated;

comment on function public.platform_approve_tenant(uuid, text, boolean, bigint, numeric, timestamptz, text, integer)
  is 'Aprueba un negocio pendiente, asigna su plan, precio/descuento e inicia su prueba gratis (D-125). Exclusivo de platform_owner.';

-- ---------------------------------------------------------------------------
-- 6. RPC `platform_reject_tenant`: Rechazar negocio con motivo
-- ---------------------------------------------------------------------------

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
  v_subscription public.tenant_subscriptions%rowtype;
  v_reason text := trim(coalesce(p_reason, ''));
begin
  if v_caller_role is null or v_caller_role != 'platform_owner' then
    raise exception 'No autorizado: solo el dueño de la plataforma puede rechazar solicitudes.';
  end if;

  if length(v_reason) = 0 then
    raise exception 'Debes especificar un motivo para el rechazo.';
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
      'reason', v_reason,
      'rejected_by', auth.uid()
    ),
    auth.uid()
  );

  return v_subscription;
end;
$$;

revoke all on function public.platform_reject_tenant(uuid, text) from public, anon;
grant execute on function public.platform_reject_tenant(uuid, text) to authenticated;

comment on function public.platform_reject_tenant(uuid, text)
  is 'Rechaza la solicitud de un negocio con motivo registrado (D-125). Exclusivo de platform_owner.';

-- ---------------------------------------------------------------------------
-- 7. Actualizar `platform_list_tenants` con datos del cuestionario
-- ---------------------------------------------------------------------------

drop function if exists public.platform_list_tenants();

create or replace function public.platform_list_tenants()
returns table (
  tenant_id uuid,
  tenant_name text,
  business_type text,
  city text,
  estimated_branches integer,
  estimated_team_size integer,
  referral_source text,
  rejection_reason text,
  contact_email text,
  whatsapp text,
  tenant_active boolean,
  is_demo boolean,
  plan_code text,
  subscription_status text,
  is_founder boolean,
  price_cop bigint,
  discount_percent numeric,
  trial_ends_at timestamptz,
  current_period_end timestamptz,
  grace_ends_at timestamptz,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if private.beautyos_current_platform_role() is null then
    raise exception 'No autorizado: se requiere rol de plataforma.';
  end if;

  return query
  select
    t.id,
    t.name,
    t.business_type,
    t.city,
    t.estimated_branches,
    t.estimated_team_size,
    t.referral_source,
    t.rejection_reason,
    t.contact_email,
    t.whatsapp,
    t.active,
    t.is_demo,
    p.code,
    ts.status,
    ts.is_founder,
    ts.price_cop,
    ts.discount_percent,
    ts.trial_ends_at,
    ts.current_period_end,
    ts.grace_ends_at,
    t.created_at
  from public.tenants t
  left join public.tenant_subscriptions ts on ts.tenant_id = t.id
  left join public.plans p on p.id = ts.plan_id
  -- Orden:
  -- 1. Primero solicitudes pendientes de aprobación (status = 'pending')
  -- 2. Luego clientes activos (no demo)
  -- 3. Al final negocios de prueba
  order by
    case when ts.status = 'pending' then 0 else 1 end,
    t.is_demo,
    t.created_at desc;
end;
$$;

revoke all on function public.platform_list_tenants() from public, anon, authenticated;
grant execute on function public.platform_list_tenants() to authenticated;

comment on function public.platform_list_tenants()
  is 'Lista los negocios para el panel de plataforma con datos de solicitud y filtro de aceptacion (D-125).';

commit;
