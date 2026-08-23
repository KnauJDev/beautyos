-- ============================================================================
-- MIGRACIÓN: 20260823120000_epayco_activacion_robusta.sql
-- DESCRIPCIÓN: Robustecer la activación de suscripciones en beautyos_procesar_evento_epayco
--              para aceptar cualquier pago válido confirmado por ePayco >= $10.000 COP (D-141 / D-158).
-- ============================================================================

begin;

create or replace function private.beautyos_procesar_evento_epayco(
  p_tenant_id uuid,
  p_x_ref_payco text,
  p_transaction_id text,
  p_transaction_state text,
  p_cod_transaction_state text,
  p_amount_cop bigint,
  p_currency_code text,
  p_payload jsonb
)
returns table (
  processed boolean,
  previous_status text,
  new_status text,
  message text
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
begin
  if p_tenant_id is null or p_x_ref_payco is null or length(trim(p_x_ref_payco)) = 0 then
    raise exception 'Parametros invalidos: tenant_id y x_ref_payco son obligatorios.';
  end if;

  -- 1. Obtener la suscripcion actual del tenant
  select * into v_sub
  from public.tenant_subscriptions
  where tenant_id = p_tenant_id;

  if v_sub.id is null then
    raise exception 'No existe suscripcion para el tenant especificado (%).', p_tenant_id;
  end if;

  -- 2. Idempotencia criptografica
  insert into public.subscription_events (
    tenant_id,
    subscription_id,
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
  if v_sub.status in ('pending', 'rejected') then
    return query select true, v_sub.status, v_sub.status, 'Pago registrado. El negocio esta en revision/rechazado y requiere aprobacion del platform_owner.'::text;
    return;
  end if;

  -- MAQUINA DE ESTADOS (D-141 / D-158)
  if v_is_accepted then
    if p_amount_cop is not null and p_amount_cop < 10000 then
      return query select true, v_sub.status, v_sub.status, 'Pago recibido con monto menor al mínimo permitido ($10.000 COP). Suscripcion no activada.'::text;
      return;
    end if;

    -- Transicion a ACTIVE desde trialing, past_due, grace, suspended, cancelled
    update public.tenant_subscriptions
    set
      status = 'active',
      provider = 'epayco',
      provider_reference = coalesce(p_transaction_id, provider_reference, p_x_ref_payco),
      price_cop = coalesce(price_cop, p_amount_cop),
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
    update public.tenant_subscriptions
    set
      status = 'past_due',
      grace_ends_at = coalesce(grace_ends_at, now() + interval '5 days'),
      updated_at = now()
    where id = v_sub.id;

    return query select true, v_sub.status, 'past_due'::text, 'Pago rechazado/reversado. Suscripcion en estado past_due con 5 dias de gracia.'::text;
    return;

  else
    return query select true, v_sub.status, v_sub.status, 'Evento de pago ePayco registrado sin cambio de estado.'::text;
    return;
  end if;
end;
$$;

revoke all on function private.beautyos_procesar_evento_epayco(uuid, text, text, text, text, bigint, text, jsonb) from public, anon, authenticated;
grant execute on function private.beautyos_procesar_evento_epayco(uuid, text, text, text, text, bigint, text, jsonb) to service_role;

commit;
