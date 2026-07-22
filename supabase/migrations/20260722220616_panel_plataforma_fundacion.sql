-- BeautyOS - Fundacion del panel de plataforma (platform_owner).
--
-- Antes de esta migracion no existia ningun dato que distinguiera al
-- propietario de BeautyOS de un simple usuario de un tenant. Se agrega:
--
-- 1. public.platform_operators: identidad de plataforma (platform_owner /
--    platform_operator), separada por completo de tenant_memberships
--    (ADR-001: plataforma, tenant y sede son fronteras distintas).
-- 2. private.beautyos_current_platform_role(): helper interno.
-- 3. public.get_my_platform_role(): para que Flutter sepa si debe mostrar
--    la entrada al panel de plataforma.
-- 4. RPC de gestion: platform_list_tenants() (platform_owner y
--    platform_operator pueden ver), platform_suspend_tenant(),
--    platform_reactivate_tenant(), platform_extend_trial() (solo
--    platform_owner; exigen motivo y quedan auditadas en
--    subscription_events).
-- 5. Semilla: se registra como platform_owner el UID
--    dbee91f0-36e0-4bd8-9303-fe173418ba55 (juankdev2026@gmail.com),
--    confirmado por el propietario como su cuenta real, separada de las
--    cuentas de prueba del tenant ficticio "Bella Mujer".
--
-- Fuera de alcance (bloques aparte): flujo de soporte con acceso temporal
-- y auditado a datos operativos de un tenant (ROLES_Y_PERMISOS.md, seccion
-- 6); pantalla de Flutter para este panel; gestion de otros
-- platform_operators desde la UI (hoy solo existe la semilla inicial).

begin;

create table public.platform_operators (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  role text not null check (role in ('platform_owner', 'platform_operator')),
  active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint platform_operators_user_id_key unique (user_id)
);

create trigger platform_operators_set_updated_at
before update on public.platform_operators
for each row execute function private.beautyos_set_updated_at();

alter table public.platform_operators enable row level security;

revoke all on table public.platform_operators from public, anon, authenticated;
grant all on table public.platform_operators to service_role;

create or replace function private.beautyos_current_platform_role()
returns text
language sql
security definer
set search_path = pg_catalog
as $$
  select po.role
  from public.platform_operators po
  where po.user_id = auth.uid()
    and po.active
  limit 1;
$$;

revoke all on function private.beautyos_current_platform_role()
  from public, anon, authenticated;
grant execute on function private.beautyos_current_platform_role()
  to service_role;

create or replace function public.get_my_platform_role()
returns text
language sql
security definer
set search_path = pg_catalog
as $$
  select private.beautyos_current_platform_role();
$$;

revoke all on function public.get_my_platform_role() from public, anon;
grant execute on function public.get_my_platform_role()
  to authenticated, service_role;

-- Lectura: cualquier rol de plataforma puede ver la lista de tenants.

create or replace function public.platform_list_tenants()
returns table (
  tenant_id uuid,
  tenant_name text,
  contact_email text,
  whatsapp text,
  tenant_active boolean,
  plan_code text,
  subscription_status text,
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
    t.contact_email,
    t.whatsapp,
    t.active,
    p.code,
    ts.status,
    ts.trial_ends_at,
    ts.current_period_end,
    ts.grace_ends_at,
    t.created_at
  from public.tenants t
  left join public.tenant_subscriptions ts on ts.tenant_id = t.id
  left join public.plans p on p.id = ts.plan_id
  order by t.created_at desc;
end;
$$;

-- Escritura: solo platform_owner; exige motivo; queda auditado.

create or replace function public.platform_suspend_tenant(
  p_tenant_id uuid,
  p_reason text
)
returns public.tenant_subscriptions
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_result public.tenant_subscriptions%rowtype;
begin
  if private.beautyos_current_platform_role() is distinct from 'platform_owner' then
    raise exception 'No autorizado: solo platform_owner puede suspender un tenant.';
  end if;

  if length(trim(coalesce(p_reason, ''))) = 0 then
    raise exception 'El motivo es obligatorio para suspender un tenant.';
  end if;

  update public.tenant_subscriptions
     set status = 'suspended', updated_at = now()
   where tenant_id = p_tenant_id
     and status <> 'cancelled'
  returning * into v_result;

  if v_result.id is null then
    raise exception 'No se encontro una suscripcion activa para ese tenant.';
  end if;

  insert into public.subscription_events (
    tenant_id, tenant_subscription_id, event_type, payload, created_by
  ) values (
    p_tenant_id, v_result.id, 'suspended_by_platform',
    jsonb_build_object('reason', p_reason), auth.uid()
  );

  return v_result;
end;
$$;

create or replace function public.platform_reactivate_tenant(
  p_tenant_id uuid,
  p_reason text
)
returns public.tenant_subscriptions
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_result public.tenant_subscriptions%rowtype;
begin
  if private.beautyos_current_platform_role() is distinct from 'platform_owner' then
    raise exception 'No autorizado: solo platform_owner puede reactivar un tenant.';
  end if;

  if length(trim(coalesce(p_reason, ''))) = 0 then
    raise exception 'El motivo es obligatorio para reactivar un tenant.';
  end if;

  update public.tenant_subscriptions
     set status = 'active', updated_at = now()
   where tenant_id = p_tenant_id
     and status = 'suspended'
  returning * into v_result;

  if v_result.id is null then
    raise exception 'No se encontro una suscripcion suspendida para ese tenant.';
  end if;

  insert into public.subscription_events (
    tenant_id, tenant_subscription_id, event_type, payload, created_by
  ) values (
    p_tenant_id, v_result.id, 'reactivated_by_platform',
    jsonb_build_object('reason', p_reason), auth.uid()
  );

  return v_result;
end;
$$;

create or replace function public.platform_extend_trial(
  p_tenant_id uuid,
  p_new_trial_ends_at timestamptz,
  p_reason text
)
returns public.tenant_subscriptions
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_result public.tenant_subscriptions%rowtype;
begin
  if private.beautyos_current_platform_role() is distinct from 'platform_owner' then
    raise exception 'No autorizado: solo platform_owner puede extender una prueba.';
  end if;

  if length(trim(coalesce(p_reason, ''))) = 0 then
    raise exception 'El motivo es obligatorio para extender una prueba.';
  end if;

  if p_new_trial_ends_at is null or p_new_trial_ends_at <= now() then
    raise exception 'La nueva fecha de fin de prueba debe ser futura.';
  end if;

  update public.tenant_subscriptions
     set trial_ends_at = p_new_trial_ends_at, updated_at = now()
   where tenant_id = p_tenant_id
     and status = 'trialing'
  returning * into v_result;

  if v_result.id is null then
    raise exception 'No se encontro una suscripcion en periodo de prueba para ese tenant.';
  end if;

  insert into public.subscription_events (
    tenant_id, tenant_subscription_id, event_type, payload, created_by
  ) values (
    p_tenant_id, v_result.id, 'trial_extended',
    jsonb_build_object('reason', p_reason, 'new_trial_ends_at', p_new_trial_ends_at),
    auth.uid()
  );

  return v_result;
end;
$$;

revoke all on function public.platform_list_tenants() from public, anon;
revoke all on function public.platform_suspend_tenant(uuid, text) from public, anon;
revoke all on function public.platform_reactivate_tenant(uuid, text) from public, anon;
revoke all on function public.platform_extend_trial(uuid, timestamptz, text) from public, anon;

grant execute on function public.platform_list_tenants() to authenticated, service_role;
grant execute on function public.platform_suspend_tenant(uuid, text) to authenticated, service_role;
grant execute on function public.platform_reactivate_tenant(uuid, text) to authenticated, service_role;
grant execute on function public.platform_extend_trial(uuid, timestamptz, text) to authenticated, service_role;

-- Semilla: platform_owner confirmado por el propietario (juankdev2026@gmail.com).

insert into public.platform_operators (user_id, role, active)
values ('dbee91f0-36e0-4bd8-9303-fe173418ba55', 'platform_owner', true)
on conflict (user_id) do nothing;

commit;
