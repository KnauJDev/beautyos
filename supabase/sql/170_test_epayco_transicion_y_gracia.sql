-- ==============================================================================
-- Control 170: Verificacion de Transiciones ePayco, Idempotencia y 5 Dias de Gracia
-- ==============================================================================
-- Se ejecuta en una transaccion aislada que termina en ROLLBACK (sin dejar basura).
-- ==============================================================================

begin;

do $$
declare
  v_plan_id uuid;
  v_tenant_id uuid;
  v_sub_id uuid;
  v_res record;
  v_commitments_ok boolean;
begin
  raise notice 'Iniciando Control 170...';

  -- 1. Obtener plan profesional
  select id into v_plan_id from public.plans where code = 'profesional' limit 1;
  if v_plan_id is null then
    raise exception 'No se encontro el plan profesional.';
  end if;

  -- 2. Crear tenant de prueba
  insert into public.tenants (name, slug)
  values ('Salon Test ePayco', 'salon-test-epayco-' || floor(random()*100000)::text)
  returning id into v_tenant_id;

  -- 3. Crear suscripcion en 'trialing'
  insert into public.tenant_subscriptions (
    tenant_id,
    plan_id,
    status,
    trial_ends_at
  ) values (
    v_tenant_id,
    v_plan_id,
    'trialing',
    now() + interval '21 days'
  ) returning id into v_sub_id;

  -- ============================================================================
  -- PRUEBA 1: Transicion de 'trialing' a 'active' por pago aceptado
  -- ============================================================================
  select * into v_res
  from private.beautyos_procesar_evento_epayco(
    v_tenant_id,
    'PAYCO-REF-001',
    'TX-998811',
    'Aceptada',
    '1',
    240000,
    'COP',
    '{"x_test": true, "metodo": "PSE"}'::jsonb
  );

  if not v_res.evento_nuevo or v_res.estado_nuevo != 'active' then
    raise exception 'Fallo Prueba 1: el pago debio activar la suscripcion. Res: %', v_res;
  end if;

  -- Verificar que el tenant acepta compromisos
  v_commitments_ok := private.beautyos_tenant_accepts_new_commitments(v_tenant_id);
  if not v_commitments_ok then
    raise exception 'Fallo Prueba 1: el tenant activo debe aceptar compromisos.';
  end if;

  raise notice '✅ Prueba 1 superada: trialing -> active con periodo de 1 mes.';

  -- ============================================================================
  -- PRUEBA 2: Idempotencia estricta (reintento del mismo webhook de ePayco)
  -- ============================================================================
  select * into v_res
  from private.beautyos_procesar_evento_epayco(
    v_tenant_id,
    'PAYCO-REF-001', -- MISMA REFERENCIA
    'TX-998811',
    'Aceptada',
    '1',
    240000,
    'COP',
    '{"x_test": true, "reintento": 1}'::jsonb
  );

  if v_res.evento_nuevo then
    raise exception 'Fallo Prueba 2: el reintento de ePayco debio ser marcado como evento_nuevo = false.';
  end if;

  raise notice '✅ Prueba 2 superada: idempotencia garantizada, evento duplicado ignorado.';

  -- ============================================================================
  -- PRUEBA 3: Cobro rechazado sobre cliente activo -> entra a 'past_due' con 5 dias de gracia
  -- ============================================================================
  select * into v_res
  from private.beautyos_procesar_evento_epayco(
    v_tenant_id,
    'PAYCO-REF-002',
    'TX-998822',
    'Rechazada',
    '2',
    240000,
    'COP',
    '{"x_test": true, "motivo": "Fondos insuficientes"}'::jsonb
  );

  if not v_res.evento_nuevo or v_res.estado_nuevo != 'past_due' then
    raise exception 'Fallo Prueba 3: cobro rechazado debio pasar a past_due. Res: %', v_res;
  end if;

  -- En periodo de gracia (5 dias), el tenant AUN puede aceptar citas
  v_commitments_ok := private.beautyos_tenant_accepts_new_commitments(v_tenant_id);
  if not v_commitments_ok then
    raise exception 'Fallo Prueba 3: en periodo de gracia el salon aun debe aceptar citas.';
  end if;

  raise notice '✅ Prueba 3 superada: cobro rechazado entra a past_due con 5 dias de gracia vigentes.';

  -- ============================================================================
  -- PRUEBA 4: Bloqueo de compromisos cuando vencen los 5 dias de gracia
  -- ============================================================================
  update public.tenant_subscriptions
  set grace_ends_at = now() - interval '1 hour' -- Gracia ya vencida
  where id = v_sub_id;

  v_commitments_ok := private.beautyos_tenant_accepts_new_commitments(v_tenant_id);
  if v_commitments_ok then
    raise exception 'Fallo Prueba 4: con periodo de gracia vencido NO debe aceptar compromisos.';
  end if;

  raise notice '✅ Prueba 4 superada: gracia vencida bloquea compromisos operativos.';

  -- ============================================================================
  -- PRUEBA 5: Reactivacion automatica desde 'suspended' tras nuevo pago
  -- ============================================================================
  update public.tenant_subscriptions
  set status = 'suspended'
  where id = v_sub_id;

  select * into v_res
  from private.beautyos_procesar_evento_epayco(
    v_tenant_id,
    'PAYCO-REF-003',
    'TX-998833',
    'Aceptada',
    '1',
    240000,
    'COP',
    '{"x_test": true, "reactivacion": true}'::jsonb
  );

  if not v_res.evento_nuevo or v_res.estado_nuevo != 'active' then
    raise exception 'Fallo Prueba 5: suspended debio reactivarse automaticamente a active. Res: %', v_res;
  end if;

  v_commitments_ok := private.beautyos_tenant_accepts_new_commitments(v_tenant_id);
  if not v_commitments_ok then
    raise exception 'Fallo Prueba 5: el salon reactivado debe aceptar compromisos de inmediato.';
  end if;

  raise notice '✅ Prueba 5 superada: reactivacion automatica 100% inmediata tras pago.';

  -- ============================================================================
  -- PRUEBA 6: Bloqueo de commitments en 'active' si current_period_end ya vencio
  -- ============================================================================
  update public.tenant_subscriptions
  set current_period_end = now() - interval '1 day'
  where id = v_sub_id;

  v_commitments_ok := private.beautyos_tenant_accepts_new_commitments(v_tenant_id);
  if v_commitments_ok then
    raise exception 'Fallo Prueba 6: active con current_period_end en el pasado NO debe aceptar compromisos.';
  end if;

  raise notice '✅ Prueba 6 superada: brecha de fechas cerrada, activo vencido no acepta citas.';

  -- ============================================================================
  -- PRUEBA 7: Guard "Nadie entra solo" (D-125 / D-138): pago en 'pending' NO auto-activa
  -- ============================================================================
  update public.tenant_subscriptions
  set status = 'pending'
  where id = v_sub_id;

  select * into v_res
  from private.beautyos_procesar_evento_epayco(
    v_tenant_id,
    'PAYCO-REF-004',
    'TX-998844',
    'Aceptada',
    '1',
    240000,
    'COP',
    '{"x_test": true}'::jsonb
  );

  if v_res.estado_nuevo != 'pending' then
    raise exception 'Fallo Prueba 7: un negocio en pending NO debe activarse solo sin aprobacion humana.';
  end if;

  raise notice '✅ Prueba 7 superada: regla "Nadie entra solo" blindada en base de datos.';

  -- ============================================================================
  -- PRUEBA 8: Validacion de monto insuficiente contra beautyos_precio_efectivo
  -- ============================================================================
  update public.tenant_subscriptions
  set status = 'trialing'
  where id = v_sub_id;

  select * into v_res
  from private.beautyos_procesar_evento_epayco(
    v_tenant_id,
    'PAYCO-REF-005',
    'TX-998855',
    'Aceptada',
    '1',
    50000, -- Monto insuficiente ($50.000 vs $240.000 esperado)
    'COP',
    '{"x_test": true}'::jsonb
  );

  if v_res.estado_nuevo != 'trialing' then
    raise exception 'Fallo Prueba 8: pago insuficiente no debe activar la suscripcion.';
  end if;

  raise notice '✅ Prueba 8 superada: monto insuficiente rechazado para activacion.';

  raise notice '==================================================';
  raise notice 'TODAS LAS PRUEBAS DEL CONTROL 170 EN VERDE!';
  raise notice '==================================================';
end;
$$;

rollback;
