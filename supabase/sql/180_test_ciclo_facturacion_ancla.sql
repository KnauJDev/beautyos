-- ============================================================================
-- SCRIPT DE CONTROL 180: test_ciclo_facturacion_ancla.sql
-- Valida los ciclos de 30 dias anclados al primer pago, el prorrateo en
-- gracia, la reactivacion con reancla, el bloqueo de suspension manual, y
-- los dos bugs corregidos (plan_id no se actualizaba; el candado de pactado
-- no cubria descuento-sin-precio-fijo).
-- ============================================================================

begin;

do $$
declare
  v_tenant_id uuid;
  v_plan_basico_id uuid;
  v_plan_business_id uuid;
  v_plan_profesional_id uuid;
  v_sub_id uuid;
  v_processed boolean;
  v_prev text;
  v_new text;
  v_msg text;
  v_periodo_fin_1 timestamptz;
  v_plan_id_final uuid;
begin
  raise notice 'Control 180: Iniciando verificacion del ciclo de facturacion anclado...';

  select id into v_plan_basico_id from public.plans where code = 'basico' and status = 'active';
  select id into v_plan_business_id from public.plans where code = 'business' and status = 'active';
  select id into v_plan_profesional_id from public.plans where code = 'profesional' and status = 'active';

  if v_plan_basico_id is null or v_plan_business_id is null or v_plan_profesional_id is null then
    raise exception 'No se encontraron los 3 planes activos (basico/business/profesional).';
  end if;

  -- Tomamos un tenant real solo para probar sobre su fila (todo dentro de ROLLBACK,
  -- no se toca nada de forma permanente). Se guarda su estado para no depender de
  -- que sea siempre el mismo tenant en cada corrida.
  select ts.tenant_id, ts.id into v_tenant_id, v_sub_id
  from public.tenant_subscriptions ts
  limit 1;

  if v_tenant_id is null then
    raise exception 'No hay tenants en la base de datos para probar.';
  end if;

  raise notice 'Control 180: Probando con tenant_id %', v_tenant_id;

  -- ---------------------------------------------------------------------
  -- PRUEBA 1: primera activacion (sin periodo previo) -> mes completo.
  -- ---------------------------------------------------------------------
  update public.tenant_subscriptions
  set plan_id = v_plan_profesional_id,
      price_cop = null, discount_percent = null, discount_ends_at = null, price_reason = null,
      status = 'trialing', current_period_start = null, current_period_end = null,
      grace_ends_at = null, suspended_at = null
  where id = v_sub_id;

  select processed, previous_status, new_status, message
  into v_processed, v_prev, v_new, v_msg
  from private.beautyos_procesar_evento_epayco(
    v_tenant_id, 'TEST180_REF_' || floor(random()*1000000)::text, 'TX1', 'Aceptada', '1',
    240000, 'COP', '{"test":true,"caso":"primera_activacion"}'::jsonb, 'profesional'
  );

  raise notice 'PRUEBA 1 (primera activacion): New: %, Msg: %', v_new, v_msg;
  if v_new != 'active' or v_msg not like '%primera_activacion%' then
    raise exception 'Fallo PRUEBA 1: se esperaba active/primera_activacion, resultado: % / %', v_new, v_msg;
  end if;
  raise notice 'Control 180: PRUEBA 1 EXITOSA.';

  select current_period_end into v_periodo_fin_1 from public.tenant_subscriptions where id = v_sub_id;

  -- ---------------------------------------------------------------------
  -- PRUEBA 2: renovacion anticipada (paga mientras el periodo sigue vigente)
  -- -> el nuevo periodo se acumula al final del vigente, no se reinicia.
  -- ---------------------------------------------------------------------
  select processed, previous_status, new_status, message
  into v_processed, v_prev, v_new, v_msg
  from private.beautyos_procesar_evento_epayco(
    v_tenant_id, 'TEST180_REF_' || floor(random()*1000000)::text, 'TX2', 'Aceptada', '1',
    240000, 'COP', '{"test":true,"caso":"renovacion_anticipada"}'::jsonb, 'profesional'
  );

  raise notice 'PRUEBA 2 (renovacion anticipada): New: %, Msg: %', v_new, v_msg;
  if v_msg not like '%renovacion_anticipada%' then
    raise exception 'Fallo PRUEBA 2: se esperaba motivo renovacion_anticipada, mensaje: %', v_msg;
  end if;

  perform 1 from public.tenant_subscriptions
    where id = v_sub_id and current_period_start = v_periodo_fin_1;
  if not found then
    raise exception 'Fallo PRUEBA 2: el nuevo periodo no arranco donde termino el anterior (ancla corrida).';
  end if;
  raise notice 'Control 180: PRUEBA 2 EXITOSA - la ancla no se corrio.';

  -- ---------------------------------------------------------------------
  -- PRUEBA 3: pago tardio dentro de gracia -> prorrateado, sin piso de 10.000.
  -- current_period_end queda a 29.5 dias en el pasado, de modo que la proxima
  -- ancla (current_period_end + 30d) cae en ~12 horas: dias_restantes = 1
  -- (ceil), y con el plan Profesional ($240.000) el monto esperado es
  -- ceil(240000 * 1/30) = $8.000 -- por debajo del piso viejo de $10.000 a
  -- proposito, para demostrar que ya no se exige.
  -- ---------------------------------------------------------------------
  update public.tenant_subscriptions
  set status = 'past_due',
      current_period_end = now() - interval '29 days 12 hours',
      grace_ends_at = now() + interval '1 day'
  where id = v_sub_id;

  -- 3a: paga de menos ($1.000, por debajo del prorrateo real de $8.000) -> debe rechazarse.
  select processed, previous_status, new_status, message
  into v_processed, v_prev, v_new, v_msg
  from private.beautyos_procesar_evento_epayco(
    v_tenant_id, 'TEST180_REF_' || floor(random()*1000000)::text, 'TX3A', 'Aceptada', '1',
    1000, 'COP', '{"test":true,"caso":"pago_tardio_insuficiente"}'::jsonb, 'profesional'
  );

  raise notice 'PRUEBA 3a (pago tardio insuficiente, $1.000): New: %, Msg: %', v_new, v_msg;
  if v_new = 'active' then
    raise exception 'Fallo PRUEBA 3a: un pago de $1.000 no deberia activar un prorrateo de ~$8.000. Msg: %', v_msg;
  end if;
  raise notice 'Control 180: PRUEBA 3a EXITOSA - pago insuficiente rechazado.';

  -- 3b: paga $8.500 (por debajo del piso viejo de $10.000, por encima del prorrateo real) -> debe activar.
  select processed, previous_status, new_status, message
  into v_processed, v_prev, v_new, v_msg
  from private.beautyos_procesar_evento_epayco(
    v_tenant_id, 'TEST180_REF_' || floor(random()*1000000)::text, 'TX3B', 'Aceptada', '1',
    8500, 'COP', '{"test":true,"caso":"pago_tardio_prorrateado"}'::jsonb, 'profesional'
  );

  raise notice 'PRUEBA 3b (pago tardio prorrateado, $8.500 < piso viejo de $10.000): New: %, Msg: %', v_new, v_msg;
  if v_new != 'active' or v_msg not like '%pago_tardio_prorrateado%' then
    raise exception 'Fallo PRUEBA 3b: un pago de $8.500 deberia activar sin exigir el piso de $10.000. Resultado: % / %', v_new, v_msg;
  end if;
  raise notice 'Control 180: PRUEBA 3b EXITOSA - prorrateo sin piso de $10.000.';

  -- ---------------------------------------------------------------------
  -- PRUEBA 4: reactivacion tras suspension (gracia vencida) -> mes completo, reancla.
  -- ---------------------------------------------------------------------
  update public.tenant_subscriptions
  set status = 'suspended', suspended_at = now() - interval '10 days',
      current_period_end = now() - interval '15 days', grace_ends_at = now() - interval '10 days'
  where id = v_sub_id;

  -- created_at explicito y anterior a proposito: dentro de esta misma
  -- transaccion now() es constante (transaction_timestamp), asi que sin
  -- esto el evento de la PRUEBA 5 podria quedar con el mismo created_at y
  -- el "mas reciente" seria ambiguo.
  insert into public.subscription_events (tenant_id, tenant_subscription_id, event_type, provider, provider_event_id, payload, created_at)
  values (v_tenant_id, v_sub_id, 'auto_suspended_grace_expired', 'system', 'test180_auto_' || floor(random()*1000000)::text, '{"test":true}'::jsonb, now() - interval '10 minutes');

  select processed, previous_status, new_status, message
  into v_processed, v_prev, v_new, v_msg
  from private.beautyos_procesar_evento_epayco(
    v_tenant_id, 'TEST180_REF_' || floor(random()*1000000)::text, 'TX4', 'Aceptada', '1',
    240000, 'COP', '{"test":true,"caso":"reactivacion_post_suspension"}'::jsonb, 'profesional'
  );

  raise notice 'PRUEBA 4 (reactivacion tras suspension por gracia vencida): New: %, Msg: %', v_new, v_msg;
  if v_new != 'active' or v_msg not like '%reactivacion_post_suspension%' then
    raise exception 'Fallo PRUEBA 4: deberia reactivar con mes completo. Resultado: % / %', v_new, v_msg;
  end if;
  raise notice 'Control 180: PRUEBA 4 EXITOSA.';

  -- ---------------------------------------------------------------------
  -- PRUEBA 5: suspension MANUAL por la plataforma -> el pago NO reactiva.
  -- ---------------------------------------------------------------------
  update public.tenant_subscriptions
  set status = 'suspended', suspended_at = now()
  where id = v_sub_id;

  insert into public.subscription_events (tenant_id, tenant_subscription_id, event_type, provider, payload, created_by)
  values (v_tenant_id, v_sub_id, 'suspended_by_platform', 'platform_admin', jsonb_build_object('reason', 'prueba control 180'), null);

  select processed, previous_status, new_status, message
  into v_processed, v_prev, v_new, v_msg
  from private.beautyos_procesar_evento_epayco(
    v_tenant_id, 'TEST180_REF_' || floor(random()*1000000)::text, 'TX5', 'Aceptada', '1',
    240000, 'COP', '{"test":true,"caso":"suspension_manual"}'::jsonb, 'profesional'
  );

  raise notice 'PRUEBA 5 (suspension manual): New: %, Msg: %', v_new, v_msg;
  if v_new != 'suspended' or v_msg not like '%revision del propietario%' then
    raise exception 'Fallo PRUEBA 5: un pago NO deberia reactivar una suspension manual. Resultado: % / %', v_new, v_msg;
  end if;
  raise notice 'Control 180: PRUEBA 5 EXITOSA - suspension manual bloqueada correctamente.';

  -- ---------------------------------------------------------------------
  -- PRUEBA 6 (Bug A): sin precio pactado, paga un plan distinto al asignado
  -- -> plan_id debe quedar actualizado al plan pagado.
  -- ---------------------------------------------------------------------
  update public.tenant_subscriptions
  set plan_id = v_plan_basico_id,
      price_cop = null, discount_percent = null, discount_ends_at = null, price_reason = null,
      status = 'trialing', current_period_start = null, current_period_end = null,
      grace_ends_at = null, suspended_at = null
  where id = v_sub_id;

  select processed, previous_status, new_status, message
  into v_processed, v_prev, v_new, v_msg
  from private.beautyos_procesar_evento_epayco(
    v_tenant_id, 'TEST180_REF_' || floor(random()*1000000)::text, 'TX6', 'Aceptada', '1',
    200000, 'COP', '{"test":true,"caso":"bug_a_plan_id"}'::jsonb, 'business'
  );

  select plan_id into v_plan_id_final from public.tenant_subscriptions where id = v_sub_id;

  raise notice 'PRUEBA 6 (Bug A - plan_id se actualiza): plan pagado=business, plan_id final=%', v_plan_id_final;
  if v_plan_id_final != v_plan_business_id then
    raise exception 'Fallo PRUEBA 6: plan_id deberia haber quedado en Business (%), quedo en %', v_plan_business_id, v_plan_id_final;
  end if;
  raise notice 'Control 180: PRUEBA 6 EXITOSA - Bug A corregido.';

  -- ---------------------------------------------------------------------
  -- PRUEBA 7 (Bug B): pactado SOLO por descuento (sin price_cop), manda un
  -- p_plan_code distinto -> debe cobrar sobre el plan pactado (asignado), no
  -- sobre el que mando, y plan_id NO debe cambiar.
  -- ---------------------------------------------------------------------
  update public.tenant_subscriptions
  set plan_id = v_plan_basico_id,
      price_cop = null, discount_percent = 50, discount_ends_at = null,
      price_reason = 'Pionero (prueba control 180)',
      status = 'trialing', current_period_start = null, current_period_end = null,
      grace_ends_at = null, suspended_at = null
  where id = v_sub_id;

  -- El precio de lista de basico es 160.000; con 50% de descuento pactado, se
  -- espera 80.000, sin importar que el evento traiga p_plan_code='profesional'.
  select processed, previous_status, new_status, message
  into v_processed, v_prev, v_new, v_msg
  from private.beautyos_procesar_evento_epayco(
    v_tenant_id, 'TEST180_REF_' || floor(random()*1000000)::text, 'TX7', 'Aceptada', '1',
    80000, 'COP', '{"test":true,"caso":"bug_b_pactado_solo_descuento"}'::jsonb, 'profesional'
  );

  select plan_id into v_plan_id_final from public.tenant_subscriptions where id = v_sub_id;

  raise notice 'PRUEBA 7 (Bug B - pactado por descuento ignora p_plan_code): New: %, Msg: %, plan_id final=%', v_new, v_msg, v_plan_id_final;
  if v_new != 'active' or v_plan_id_final != v_plan_basico_id then
    raise exception 'Fallo PRUEBA 7: deberia activar sobre Basico ($80.000 = 160.000 - 50%%), plan_id final: %', v_plan_id_final;
  end if;
  raise notice 'Control 180: PRUEBA 7 EXITOSA - Bug B corregido (pactado por solo descuento respetado).';

  raise notice 'Control 180: TODAS LAS PRUEBAS EXITOSAS.';
end;
$$;

rollback;
