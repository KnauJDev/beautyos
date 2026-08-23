-- ============================================================================
-- SCRIPT DE CONTROL 179: test_epayco_activacion_robusta.sql
-- Valida que beautyos_procesar_evento_epayco RECHACE un pago por debajo del
-- precio pactado del plan y SOLO active la suscripción cuando el monto pagado
-- alcanza el precio esperado (corrige la regresión de 20260823120000, que
-- aceptaba cualquier pago >= $10.000 COP sin importar el precio real del plan).
-- ============================================================================

begin;

do $$
declare
  v_tenant_id uuid;
  v_sub_id uuid;
  v_plan_id uuid;
  v_expected_price bigint;
  v_status_before text;
  v_processed boolean;
  v_prev text;
  v_new text;
  v_msg text;
begin
  raise notice 'Control 179: Iniciando verificación de activación robusta de ePayco...';

  -- Buscar un tenant con precio de plan conocido (> $10.000 COP) para que la
  -- prueba de "pago insuficiente" sea significativa.
  select ts.tenant_id, ts.id, ts.plan_id, ts.status, p.price_cop
    into v_tenant_id, v_sub_id, v_plan_id, v_status_before, v_expected_price
  from public.tenant_subscriptions ts
  join public.plans p on p.id = ts.plan_id
  where coalesce(ts.price_cop, p.price_cop) > 10000
  limit 1;

  if v_tenant_id is null then
    raise exception 'No hay tenants con precio de plan > $10.000 COP para probar.';
  end if;

  raise notice 'Control 179: Probando con tenant_id % (precio de plan esperado: $% COP, estado previo: %)',
    v_tenant_id, v_expected_price, v_status_before;

  -- 1. Pago de $10.000 COP (piso mínimo, pero por debajo del precio del plan):
  --    NO debe activar la suscripción.
  select processed, previous_status, new_status, message
  into v_processed, v_prev, v_new, v_msg
  from private.beautyos_procesar_evento_epayco(
    v_tenant_id,
    'TEST_REF_INSUF_' || floor(random()*1000000)::text,
    'TX_TEST_INSUF',
    'Aceptada',
    '1',
    10000,
    'COP',
    '{"test": true, "case": "insuficiente"}'::jsonb
  );

  raise notice 'Control 179 (pago insuficiente): Processed: %, Prev: %, New: %, Msg: %',
    v_processed, v_prev, v_new, v_msg;

  if v_new = 'active' and v_prev != 'active' then
    raise exception 'Fallo: un pago de $10.000 COP activó una suscripción cuyo plan cuesta $% COP. La validación de precio no está funcionando.', v_expected_price;
  end if;

  raise notice 'Control 179: PASO 1 EXITOSO - El pago insuficiente NO activó la suscripción.';

  -- 2. Pago exacto al precio esperado del plan: SÍ debe activar la suscripción.
  select processed, previous_status, new_status, message
  into v_processed, v_prev, v_new, v_msg
  from private.beautyos_procesar_evento_epayco(
    v_tenant_id,
    'TEST_REF_OK_' || floor(random()*1000000)::text,
    'TX_TEST_OK',
    'Aceptada',
    '1',
    v_expected_price,
    'COP',
    '{"test": true, "case": "precio_correcto"}'::jsonb
  );

  raise notice 'Control 179 (pago correcto): Processed: %, Prev: %, New: %, Msg: %',
    v_processed, v_prev, v_new, v_msg;

  if v_new != 'active' then
    raise exception 'Fallo: un pago de $% COP (precio de lista del plan) debería activar la suscripción, pero el nuevo estado fue %.', v_expected_price, v_new;
  end if;

  raise notice 'Control 179: PASO 2 EXITOSO - El pago por el precio correcto sí activó la suscripción a active.';
end;
$$;

rollback;
