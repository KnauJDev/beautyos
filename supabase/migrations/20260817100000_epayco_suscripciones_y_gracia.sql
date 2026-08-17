-- ==============================================================================
-- Migracion: Pasos 3.9 y 3.10 — Integracion ePayco, Idempotencia y Periodo de Gracia (D-141)
-- ==============================================================================
-- 1. Actualiza private.beautyos_tenant_accepts_new_commitments para verificar
--    current_period_end en 'active' y grace_ends_at en 'past_due' / 'grace' (5 dias de gracia).
-- 2. Crea private.beautyos_procesar_evento_epayco(...) ejecutable solo por service_role
--    con idempotencia en subscription_events, guards de estado (D-125/D-138),
--    validacion de precio efectivo y transicion de estados.
-- 3. Actualiza public.get_my_tenant_subscription_status() para exponer current_period_end,
--    grace_ends_at y el precio efectivo calculado por beautyos_precio_efectivo.
-- ==============================================================================

-- 1. Actualizacion de verificacion de compromisos (citas / reservas)
create or replace function private.beautyos_tenant_accepts_new_commitments(
  p_tenant_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_subscription public.tenant_subscriptions%rowtype;
begin
  select *
    into v_subscription
  from public.tenant_subscriptions
  where tenant_id = p_tenant_id;

  if v_subscription.id is null then
    return false;
  end if;

  -- 1. Negocio activo: periodo pagado vigente (o sin fecha fija)
  if v_subscription.status = 'active' then
    return v_subscription.current_period_end is null
      or v_subscription.current_period_end > now();
  end if;

  -- 2. Prueba gratis: reloj de prueba vigente
  if v_subscription.status = 'trialing' then
    return v_subscription.trial_ends_at is null
      or v_subscription.trial_ends_at > now();
  end if;

  -- 3. Periodo de gracia (D-141): 5 dias permitidos tras vencer el periodo
  if v_subscription.status in ('past_due', 'grace') then
    return v_subscription.grace_ends_at is not null
      and v_subscription.grace_ends_at > now();
  end if;

  -- pending, suspended, cancelled, rejected: bloqueado
  return false;
end;
$$;

revoke all on function private.beautyos_tenant_accepts_new_commitments(uuid)
  from public, anon, authenticated;
grant execute on function private.beautyos_tenant_accepts_new_commitments(uuid)
  to service_role;

comment on function private.beautyos_tenant_accepts_new_commitments(uuid)
  is 'True si el tenant puede aceptar compromisos nuevos con clientes (activo vigente, prueba gratis vigente o periodo de gracia de 5 dias).';


-- 2. RPC interna para procesar confirmaciones de ePayco (Ejecutada por Edge Function con service_role)
drop function if exists private.beautyos_procesar_evento_epayco(uuid, text, text, text, bigint, text, jsonb);
drop function if exists private.beautyos_procesar_evento_epayco(uuid, text, text, text, text, bigint, text, jsonb);

create or replace function private.beautyos_procesar_evento_epayco(
  p_tenant_id uuid,
  p_x_ref_payco text,
  p_transaction_id text,
  p_transaction_state text,
  p_cod_transaction_state text default null,
  p_amount_cop bigint default 0,
  p_currency_code text default 'COP',
  p_payload jsonb default '{}'::jsonb
)
returns table (
  evento_nuevo boolean,
  estado_anterior text,
  estado_nuevo text,
  mensaje text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_sub public.tenant_subscriptions%rowtype;
  v_event_id uuid;
  v_state_clean text;
  v_cod_clean text;
  v_is_accepted boolean;
  v_is_rejected boolean;
  v_is_reversed boolean;
  v_expected_price bigint;
begin
  if p_tenant_id is null or p_x_ref_payco is null or length(trim(p_x_ref_payco)) = 0 then
    raise exception 'Parametros invalidos: tenant_id y x_ref_payco son obligatorios.';
  end if;

  -- Bloqueo de fila para evitar condiciones de carrera si ePayco envia webhooks paralelos
  select *
    into v_sub
  from public.tenant_subscriptions
  where tenant_id = p_tenant_id
  for update;

  if v_sub.id is null then
    return query select false, null::text, null::text, 'No se encontro suscripcion para el tenant especificado.'::text;
    return;
  end if;

  -- Insercion en log de auditoria append-only con idempotencia garantizada por UNIQUE(provider, provider_event_id)
  insert into public.subscription_events (
    tenant_id,
    tenant_subscription_id,
    event_type,
    provider,
    provider_event_id,
    payload
  ) values (
    p_tenant_id,
    v_sub.id,
    'epayco_' || lower(coalesce(trim(p_transaction_state), 'unknown')),
    'epayco',
    trim(p_x_ref_payco),
    coalesce(p_payload, '{}'::jsonb)
  )
  on conflict (provider, provider_event_id) do nothing
  returning id into v_event_id;

  -- Si v_event_id es null, este x_ref_payco ya fue procesado antes (Reintento de ePayco ignorado de forma segura)
  if v_event_id is null then
    return query select false, v_sub.status, v_sub.status, 'Evento ePayco duplicado ignorado por idempotencia.'::text;
    return;
  end if;

  v_state_clean := lower(coalesce(trim(p_transaction_state), ''));
  v_cod_clean := coalesce(trim(p_cod_transaction_state), '');

  -- Mapeo estricto conforme a la documentacion de ePayco
  -- Cod 1 = Aceptada | Cod 2 = Rechazada | Cod 4 = Fallida | Cod 6 = Reversada
  v_is_accepted := v_state_clean in ('aceptada', 'aprobada', 'approved', 'success') or v_cod_clean = '1';
  v_is_rejected := v_state_clean in ('rechazada', 'fallida', 'rejected', 'failed') or v_cod_clean in ('2', '4');
  v_is_reversed := v_state_clean in ('reversada', 'reversed') or v_cod_clean = '6';

  -- GUARD DE NEGOCIO: "Nadie entra solo" (D-125 / D-138)
  -- Un negocio en estado 'pending' o 'rejected' requiere aprobacion formal de plataforma antes de activarse
  if v_sub.status in ('pending', 'rejected') then
    return query select true, v_sub.status, v_sub.status, 'Pago registrado. El negocio esta en revision/rechazado y requiere aprobacion del platform_owner.'::text;
    return;
  end if;

  -- MAQUINA DE ESTADOS (D-141)
  if v_is_accepted then
    -- Validacion de monto contra precio efectivo esperado (defensa en profundidad)
    select pe.precio_cop into v_expected_price
    from private.beautyos_precio_efectivo(p_tenant_id) pe;

    if v_expected_price is not null and v_expected_price > 0 and (p_amount_cop <= 0 or p_amount_cop < v_expected_price) then
      return query select true, v_sub.status, v_sub.status, 'Pago recibido con monto menor o invalido frente al precio pactado. Suscripcion no activada.'::text;
      return;
    end if;

    -- Transicion a ACTIVE desde trialing, past_due, grace, suspended, cancelled
    update public.tenant_subscriptions
    set
      status = 'active',
      provider = 'epayco',
      provider_reference = coalesce(p_transaction_id, provider_reference, p_x_ref_payco),
      current_period_start = now(),
      current_period_end = now() + interval '1 month',
      grace_ends_at = null,
      cancel_at = null,
      cancelled_at = null,
      updated_at = now()
    where id = v_sub.id;

    return query select true, v_sub.status, 'active'::text, 'Pago aceptado. Suscripcion activada/renovada por 1 mes.'::text;
    return;

  elsif (v_is_rejected or v_is_reversed) and v_sub.status = 'active' then
    -- Si el cobro falla o se revierte sobre un negocio actualmente activo, entra a past_due con 5 dias de gracia
    update public.tenant_subscriptions
    set
      status = 'past_due',
      grace_ends_at = now() + interval '5 days',
      updated_at = now()
    where id = v_sub.id;

    return query select true, v_sub.status, 'past_due'::text, 'Pago rechazado o revertido. Negocio en mora con 5 dias de gracia.'::text;
    return;

  else
    -- Pagos pendientes o rechazados en periodos no activos no alteran negativamente el estado
    return query select true, v_sub.status, v_sub.status, 'Evento registrado sin alteracion de estado.'::text;
    return;
  end if;
end;
$$;

revoke all on function private.beautyos_procesar_evento_epayco(uuid, text, text, text, text, bigint, text, jsonb)
  from public, anon, authenticated;
grant execute on function private.beautyos_procesar_evento_epayco(uuid, text, text, text, text, bigint, text, jsonb)
  to service_role;

comment on function private.beautyos_procesar_evento_epayco(uuid, text, text, text, text, bigint, text, jsonb)
  is 'Procesa confirmaciones de pago de ePayco con idempotencia estricta, guards de estado D-125/D-138 y transiciones seguras.';


-- 3. Actualizacion de get_my_tenant_subscription_status con campos de periodo y precio efectivo
drop function if exists public.get_my_tenant_subscription_status();

create or replace function public.get_my_tenant_subscription_status()
returns table (
  tenant_id uuid,
  tenant_name text,
  subscription_status text,
  plan_code text,
  plan_name text,
  trial_ends_at timestamptz,
  current_period_start timestamptz,
  current_period_end timestamptz,
  grace_ends_at timestamptz,
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
  v_precio_efectivo bigint;
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

  -- Calcular precio efectivo dinamico
  select pe.precio_cop into v_precio_efectivo
  from private.beautyos_precio_efectivo(v_tenant_id) pe;

  return query
  select
    t.id as tenant_id,
    t.name as tenant_name,
    ts.status as subscription_status,
    p.code as plan_code,
    p.name as plan_name,
    ts.trial_ends_at,
    ts.current_period_start,
    ts.current_period_end,
    ts.grace_ends_at,
    ts.is_founder,
    coalesce(v_precio_efectivo, ts.price_cop, p.price_cop) as price_cop,
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
  is 'Consulta el estado de suscripcion, fechas de periodo, gracia y precio efectivo del negocio del usuario autenticado.';
