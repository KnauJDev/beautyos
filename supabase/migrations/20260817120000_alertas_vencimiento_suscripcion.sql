-- ==============================================================================
-- Migracion: Paso 3.11 — Avisos de Vencimiento por Correo y Manejo de Suspensión (D-143)
-- ==============================================================================
-- 1. Tabla de log anti-spam para envios de notificaciones de suscripcion.
-- 2. RPC private.beautyos_obtener_alertas_suscripcion_pendientes()
-- 3. RPC private.beautyos_registrar_alerta_enviada(...)
-- 4. RPC private.beautyos_suspender_suscripciones_vencidas()
-- ==============================================================================

-- 1. Tabla de registro de notificaciones enviadas
create table if not exists public.subscription_notification_logs (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  tenant_subscription_id uuid references public.tenant_subscriptions(id) on delete set null,
  notification_type text not null,
  recipient_email text not null,
  reference_date date not null default current_date,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint subscription_notification_logs_unique_day
    unique (tenant_id, notification_type, reference_date)
);

create index if not exists subscription_notification_logs_tenant_idx
  on public.subscription_notification_logs (tenant_id, created_at desc);

alter table public.subscription_notification_logs enable row level security;
revoke all on table public.subscription_notification_logs from public, anon, authenticated;
grant all on table public.subscription_notification_logs to service_role;

comment on table public.subscription_notification_logs
  is 'Log de auditoria e idempotencia diaria para no duplicar correos de cobro y vencimiento a los negocios.';


-- 2. RPC para suspender suscripciones cuya gracia de 5 dias expiro
create or replace function private.beautyos_suspender_suscripciones_vencidas()
returns table (
  tenants_suspendidos integer
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_count integer := 0;
begin
  with actualizados as (
    update public.tenant_subscriptions
    set
      status = 'suspended',
      updated_at = now()
    where status in ('past_due', 'grace')
      and grace_ends_at is not null
      and grace_ends_at < now()
    returning id
  )
  select count(*) into v_count from actualizados;

  return query select v_count;
end;
$$;

revoke all on function private.beautyos_suspender_suscripciones_vencidas() from public, anon, authenticated;
grant execute on function private.beautyos_suspender_suscripciones_vencidas() to service_role;


-- 3. RPC para obtener la lista de negocios que requieren notificacion hoy
create or replace function private.beautyos_obtener_alertas_suscripcion_pendientes()
returns table (
  tenant_id uuid,
  tenant_name text,
  recipient_email text,
  owner_name text,
  subscription_id uuid,
  subscription_status text,
  plan_name text,
  price_cop bigint,
  notification_type text,
  days_remaining integer,
  expiry_date timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  return query
  with candidatos as (
    select
      t.id as c_tenant_id,
      t.name as c_tenant_name,
      coalesce(t.contact_email, u.email) as c_recipient_email,
      coalesce(up.full_name, u.raw_user_meta_data->>'full_name', 'Propietario(a)') as c_owner_name,
      ts.id as c_subscription_id,
      ts.status as c_subscription_status,
      p.name as c_plan_name,
      coalesce(pe.precio_cop, ts.price_cop, p.price_cop) as c_price_cop,
      ts.trial_ends_at,
      ts.current_period_end,
      ts.grace_ends_at,
      case
        -- Caso 1: Prueba gratis por vencer (10, 5, 3, 1 dias)
        when ts.status = 'trialing' and ts.trial_ends_at is not null then
          case
            when ceil(extract(epoch from (ts.trial_ends_at - now())) / 86400.0) = 10 then 'trial_10d'
            when ceil(extract(epoch from (ts.trial_ends_at - now())) / 86400.0) = 5 then 'trial_5d'
            when ceil(extract(epoch from (ts.trial_ends_at - now())) / 86400.0) = 3 then 'trial_3d'
            when ceil(extract(epoch from (ts.trial_ends_at - now())) / 86400.0) in (0, 1) then 'trial_1d'
            else null
          end

        -- Caso 2: Mensualidad activa por vencer (5, 3, 1 dias)
        when ts.status = 'active' and ts.current_period_end is not null then
          case
            when ceil(extract(epoch from (ts.current_period_end - now())) / 86400.0) = 5 then 'period_5d'
            when ceil(extract(epoch from (ts.current_period_end - now())) / 86400.0) = 3 then 'period_3d'
            when ceil(extract(epoch from (ts.current_period_end - now())) / 86400.0) in (0, 1) then 'period_1d'
            else null
          end

        -- Caso 3: Periodo de gracia (D-141: Cuenta regresiva dias 1 al 5)
        when ts.status in ('past_due', 'grace') and ts.grace_ends_at is not null and ts.grace_ends_at > now() then
          case
            when ceil(extract(epoch from (ts.grace_ends_at - now())) / 86400.0) >= 5 then 'grace_day_1'
            when ceil(extract(epoch from (ts.grace_ends_at - now())) / 86400.0) = 4 then 'grace_day_2'
            when ceil(extract(epoch from (ts.grace_ends_at - now())) / 86400.0) = 3 then 'grace_day_3'
            when ceil(extract(epoch from (ts.grace_ends_at - now())) / 86400.0) = 2 then 'grace_day_4'
            when ceil(extract(epoch from (ts.grace_ends_at - now())) / 86400.0) <= 1 then 'grace_day_5'
            else null
          end

        -- Caso 4: Negocio recien suspendido
        when ts.status = 'suspended' and ts.updated_at >= (now() - interval '24 hours') then
          'suspended'

        else null
      end as c_notification_type,

      case
        when ts.status = 'trialing' then ceil(extract(epoch from (ts.trial_ends_at - now())) / 86400.0)::integer
        when ts.status = 'active' then ceil(extract(epoch from (ts.current_period_end - now())) / 86400.0)::integer
        when ts.status in ('past_due', 'grace') then ceil(extract(epoch from (ts.grace_ends_at - now())) / 86400.0)::integer
        else 0
      end as c_days_remaining,

      case
        when ts.status = 'trialing' then ts.trial_ends_at
        when ts.status = 'active' then ts.current_period_end
        when ts.status in ('past_due', 'grace') then ts.grace_ends_at
        else ts.updated_at
      end as c_expiry_date

    from public.tenants t
    join public.tenant_subscriptions ts on ts.tenant_id = t.id
    join public.plans p on p.id = ts.plan_id
    left join private.beautyos_precio_efectivo(t.id) pe on true
    left join public.tenant_memberships tm on tm.tenant_id = t.id and tm.role in ('owner', 'tenant_owner') and tm.active
    left join auth.users u on u.id = tm.user_id
    left join public.user_profiles up on up.id = tm.user_id
    where t.is_demo = false -- No alertar salones demo sembrados (D-120)
  )
  select
    c.c_tenant_id,
    c.c_tenant_name,
    c.c_recipient_email,
    c.c_owner_name,
    c.c_subscription_id,
    c.c_subscription_status,
    c.c_plan_name,
    c.c_price_cop,
    c.c_notification_type,
    greatest(0, c.c_days_remaining),
    c.c_expiry_date
  from candidatos c
  where c.c_notification_type is not null
    and c.c_recipient_email is not null
    -- Filtro anti-spam: que no se haya enviado esta misma notificacion hoy
    and not exists (
      select 1
      from public.subscription_notification_logs snl
      where snl.tenant_id = c.c_tenant_id
        and snl.notification_type = c.c_notification_type
        and snl.reference_date = current_date
    );
end;
$$;

revoke all on function private.beautyos_obtener_alertas_suscripcion_pendientes() from public, anon, authenticated;
grant execute on function private.beautyos_obtener_alertas_suscripcion_pendientes() to service_role;


-- 4. RPC para registrar el envio exitoso de una notificacion
create or replace function private.beautyos_registrar_alerta_enviada(
  p_tenant_id uuid,
  p_subscription_id uuid,
  p_notification_type text,
  p_recipient_email text,
  p_metadata jsonb default '{}'::jsonb
)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  insert into public.subscription_notification_logs (
    tenant_id,
    tenant_subscription_id,
    notification_type,
    recipient_email,
    reference_date,
    metadata
  ) values (
    p_tenant_id,
    p_subscription_id,
    p_notification_type,
    p_recipient_email,
    current_date,
    coalesce(p_metadata, '{}'::jsonb)
  )
  on conflict (tenant_id, notification_type, reference_date) do nothing;

  return true;
end;
$$;

revoke all on function private.beautyos_registrar_alerta_enviada(uuid, uuid, text, text, jsonb) from public, anon, authenticated;
grant execute on function private.beautyos_registrar_alerta_enviada(uuid, uuid, text, text, jsonb) to service_role;
