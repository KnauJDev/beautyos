-- ==============================================================================
-- Migracion: Paso 3.11 — Avisos de Vencimiento por Correo y Manejo de Suspensión (D-143)
-- ==============================================================================
-- 1. Agrega columna suspended_at a tenant_subscriptions.
-- 2. Tabla de log anti-spam para envios de notificaciones de suscripcion.
-- 3. RPC private.beautyos_suspender_suscripciones_vencidas() con auditoria en subscription_events.
-- 4. RPC private.beautyos_obtener_alertas_suscripcion_pendientes() con calculo por dias de calendario.
-- 5. RPC private.beautyos_registrar_alerta_enviada(...)
-- ==============================================================================

-- 1. Columna suspended_at en tenant_subscriptions
alter table public.tenant_subscriptions
  add column if not exists suspended_at timestamptz;


-- 2. Tabla de registro de notificaciones enviadas
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


-- 3. RPC para suspender suscripciones cuya gracia de 5 dias expiro (con auditoria en subscription_events)
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
  v_row record;
begin
  for v_row in
    update public.tenant_subscriptions
    set
      status = 'suspended',
      suspended_at = coalesce(suspended_at, now()),
      updated_at = now()
    where status in ('past_due', 'grace')
      and grace_ends_at is not null
      and grace_ends_at < now()
    returning id, tenant_id
  loop
    v_count := v_count + 1;

    -- Auditoria estricta en subscription_events
    insert into public.subscription_events (
      tenant_id,
      tenant_subscription_id,
      event_type,
      provider,
      provider_event_id,
      payload
    ) values (
      v_row.tenant_id,
      v_row.id,
      'auto_suspended_grace_expired',
      'system',
      'suspend_' || v_row.id || '_' || to_char(now(), 'YYYYMMDD_HH24MISS'),
      jsonb_build_object(
        'motivo', 'Periodo de gracia de 5 dias vencido sin registrar pago',
        'fecha_suspension', now()
      )
    );
  end loop;

  return query select v_count;
end;
$$;

revoke all on function private.beautyos_suspender_suscripciones_vencidas() from public, anon, authenticated;
grant execute on function private.beautyos_suspender_suscripciones_vencidas() to service_role;

comment on function private.beautyos_suspender_suscripciones_vencidas()
  is 'Suspende suscripciones vencidas tras agotar los 5 dias de gracia y deja constancia en subscription_events.';


-- 4. RPC para obtener la lista de negocios que requieren notificacion hoy (calculo calendario)
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
  with due_owners as (
    -- Obtener el contacto principal del dueno activo por cada salon (evita filas duplicadas)
    select distinct on (tm.tenant_id)
      tm.tenant_id,
      u.email as owner_user_email,
      coalesce(up.full_name, u.raw_user_meta_data->>'full_name', 'Propietario(a)') as owner_full_name
    from public.tenant_memberships tm
    join auth.users u on u.id = tm.user_id
    left join public.user_profiles up on up.id = tm.user_id
    where tm.role in ('owner', 'tenant_owner')
      and tm.active
    order by tm.tenant_id, tm.created_at asc
  ),
  candidatos as (
    select
      t.id as c_tenant_id,
      t.name as c_tenant_name,
      coalesce(t.contact_email, dow.owner_user_email) as c_recipient_email,
      coalesce(dow.owner_full_name, 'Propietario(a)') as c_owner_name,
      ts.id as c_subscription_id,
      ts.status as c_subscription_status,
      p.name as c_plan_name,
      coalesce(pe.precio_cop, ts.price_cop, p.price_cop) as c_price_cop,
      ts.trial_ends_at,
      ts.current_period_end,
      ts.grace_ends_at,
      ts.suspended_at,
      ts.updated_at,

      -- Calculos basados en fechas de calendario (independiente de la hora exacta del cron)
      case
        -- Caso 1: Prueba gratis por vencer (10, 5, 3, 1 dias)
        when ts.status = 'trialing' and ts.trial_ends_at is not null then
          case
            when (ts.trial_ends_at::date - current_date) = 10 then 'trial_10d'
            when (ts.trial_ends_at::date - current_date) = 5 then 'trial_5d'
            when (ts.trial_ends_at::date - current_date) = 3 then 'trial_3d'
            when (ts.trial_ends_at::date - current_date) <= 1 and (ts.trial_ends_at::date - current_date) >= 0 then 'trial_1d'
            else null
          end

        -- Caso 2: Mensualidad activa por vencer (5, 3, 1 dias)
        when ts.status = 'active' and ts.current_period_end is not null then
          case
            when (ts.current_period_end::date - current_date) = 5 then 'period_5d'
            when (ts.current_period_end::date - current_date) = 3 then 'period_3d'
            when (ts.current_period_end::date - current_date) <= 1 and (ts.current_period_end::date - current_date) >= 0 then 'period_1d'
            else null
          end

        -- Caso 3: Periodo de gracia (D-141: Cuenta regresiva dias 1 al 5)
        when ts.status in ('past_due', 'grace') and ts.grace_ends_at is not null and ts.grace_ends_at > now() then
          case
            when (ts.grace_ends_at::date - current_date) >= 5 then 'grace_day_1'
            when (ts.grace_ends_at::date - current_date) = 4 then 'grace_day_2'
            when (ts.grace_ends_at::date - current_date) = 3 then 'grace_day_3'
            when (ts.grace_ends_at::date - current_date) = 2 then 'grace_day_4'
            when (ts.grace_ends_at::date - current_date) <= 1 then 'grace_day_5'
            else null
          end

        -- Caso 4: Negocio recien suspendido hoy
        when ts.status = 'suspended' and coalesce(ts.suspended_at::date, ts.updated_at::date) = current_date then
          'suspended'

        else null
      end as c_notification_type,

      case
        when ts.status = 'trialing' then (ts.trial_ends_at::date - current_date)
        when ts.status = 'active' then (ts.current_period_end::date - current_date)
        when ts.status in ('past_due', 'grace') then (ts.grace_ends_at::date - current_date)
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
    left join due_owners dow on dow.tenant_id = t.id
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


-- 5. RPC para registrar el envio exitoso de una notificacion
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
