-- ============================================================================
-- MIGRACIÓN: 20260823130000_epayco_validar_precio_por_plan.sql
-- DESCRIPCIÓN: Corrige una regresión de seguridad introducida en
--              20260823120000_epayco_activacion_robusta.sql: esa migración
--              eliminó por completo la validación del monto pagado contra el
--              precio pactado y la reemplazó por un piso plano de $10.000 COP,
--              permitiendo activar cualquier plan (hasta $240.000/mes) pagando
--              el mínimo. Esta migración restaura la validación de precio,
--              ahora consciente del plan que el negocio eligió pagar
--              (selector interactivo de D-158), no solo del plan ya asignado.
--
-- REGLA DE PRECIO ESPERADO (en este orden):
--   1. Si el tenant tiene un precio propio pactado (`tenant_subscriptions.price_cop`),
--      ese es el precio esperado, sin importar el plan elegido en el checkout.
--   2. Si no, se usa el precio de lista (`plans.price_cop`) del plan que se
--      está pagando (`p_plan_code`, viajando en `x_extra2` de ePayco); si no
--      llega `p_plan_code`, se usa el plan ya asignado al tenant.
--   3. Se aplica `discount_percent` si sigue vigente (mismo criterio que
--      `beautyos_precio_efectivo`, D-136).
--   4. El piso de $10.000 COP se mantiene como red de seguridad adicional
--      (monto mínimo absoluto), no como sustituto del precio pactado.
--
-- TAMBIÉN CORRIGE: 20260823120000 insertaba en `subscription_events` usando la
-- columna `subscription_id`, que no existe en la tabla (la columna real es
-- `tenant_subscription_id`, definida en 20260722184914). Esto habría hecho
-- fallar con una excepción de Postgres cada evento de pago de ePayco
-- procesado desde que esa migración se desplegó.
-- ============================================================================

begin;

drop function if exists private.beautyos_procesar_evento_epayco(uuid, text, text, text, text, bigint, text, jsonb);

create or replace function private.beautyos_procesar_evento_epayco(
  p_tenant_id uuid,
  p_x_ref_payco text,
  p_transaction_id text,
  p_transaction_state text,
  p_cod_transaction_state text,
  p_amount_cop bigint,
  p_currency_code text,
  p_payload jsonb,
  p_plan_code text default null
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
  v_plan_code_clean text;
  v_plan_price bigint;
  v_expected_price bigint;
  v_min_required bigint;
begin
  if p_tenant_id is null or p_x_ref_payco is null or length(trim(p_x_ref_payco)) = 0 then
    raise exception 'Parametros invalidos: tenant_id y x_ref_payco son obligatorios.';
  end if;

  -- 1. Obtener la suscripcion actual del tenant (con bloqueo, evita condiciones
  --    de carrera si el webhook y la verificacion inmediata llegan a la vez)
  select * into v_sub
  from public.tenant_subscriptions
  where tenant_id = p_tenant_id
  for update;

  if v_sub.id is null then
    raise exception 'No existe suscripcion para el tenant especificado (%).', p_tenant_id;
  end if;

  -- 2. Idempotencia criptografica
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
  if v_sub.status in ('pending', 'rejected') then
    return query select true, v_sub.status, v_sub.status, 'Pago registrado. El negocio esta en revision/rechazado y requiere aprobacion del platform_owner.'::text;
    return;
  end if;

  -- MAQUINA DE ESTADOS (D-141 / D-158, corregido en 20260823130000)
  if v_is_accepted then
    -- Precio esperado: propio pactado > lista del plan que se esta pagando > lista del plan asignado
    v_plan_code_clean := nullif(lower(trim(coalesce(p_plan_code, ''))), '');

    if v_sub.price_cop is not null and v_sub.price_cop > 0 then
      v_plan_price := v_sub.price_cop;
    else
      select pl.price_cop into v_plan_price
      from public.plans pl
      where pl.code = coalesce(v_plan_code_clean, (select p2.code from public.plans p2 where p2.id = v_sub.plan_id))
        and pl.status = 'active';

      if v_plan_price is null then
        select p3.price_cop into v_plan_price from public.plans p3 where p3.id = v_sub.plan_id;
      end if;

      if v_sub.discount_percent is not null
         and (v_sub.discount_ends_at is null or v_sub.discount_ends_at > now()) then
        v_plan_price := round(coalesce(v_plan_price, 0) * (1 - v_sub.discount_percent / 100.0));
      end if;
    end if;

    v_expected_price := coalesce(v_plan_price, 0);
    v_min_required := greatest(10000, v_expected_price);

    if p_amount_cop is null or p_amount_cop < v_min_required then
      return query select true, v_sub.status, v_sub.status,
        format(
          'Pago de $%s COP menor al precio pactado ($%s COP). Suscripcion no activada.',
          coalesce(p_amount_cop, 0), v_min_required
        )::text;
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

revoke all on function private.beautyos_procesar_evento_epayco(uuid, text, text, text, text, bigint, text, jsonb, text) from public, anon, authenticated;
grant execute on function private.beautyos_procesar_evento_epayco(uuid, text, text, text, text, bigint, text, jsonb, text) to service_role;

comment on function private.beautyos_procesar_evento_epayco(uuid, text, text, text, text, bigint, text, jsonb, text)
  is 'Procesa confirmaciones de pago de ePayco con idempotencia estricta, guards de estado D-125/D-138, validacion de monto contra el precio pactado o de lista del plan pagado (corrige regresion de 20260823120000) y transiciones seguras.';

commit;
