-- CONTROL 204: El pago que activa una sede (D-192, Etapa 3b de D-188).
--
-- POR QUÉ ESTE ARCHIVO
--
-- La migración 20260902160000 crea `beautyos_procesar_pago_de_sede`, que aplica
-- un pago de ePayco a UNA sede. Es código de dinero, y convive con
-- `beautyos_procesar_evento_epayco`, que sigue cobrando el negocio entero.
--
-- Este control valida transaccionalmente:
--   - Un pago suficiente activa la sede y le pone su período.
--   - **Un pago corto NO la activa** (misma defensa que D-159).
--   - **Un cobro PRORRATEADO por debajo de $10.000 sí se acepta**: es el caso
--     que obligó a separar esta función de la que cobra el negocio, porque
--     aquella tiene un piso de $10.000 que lo rechazaría.
--   - Un pago rechazado por la pasarela no activa nada.
--   - **La idempotencia de D-141 sostiene**: la misma referencia no se procesa
--     dos veces, ni siquiera cruzando las dos funciones de cobro.
--   - Una sede que no es del negocio que paga se rechaza (clase de TL-01).
--   - **La sede PRINCIPAL arrastra la suscripción del negocio**, o un salón de
--     una sola sede pagaría y se quedaría fuera de su aplicación.
--   - **Una sede SECUNDARIA no la toca**: correr la fecha de corte del negocio
--     le regalaría un mes al cliente.
--   - "Nadie entra solo" (D-125): un negocio en revisión no se cuela pagando.
--
-- CÓMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\204_test_pago_de_sede_etapa3b.sql"
--
-- TERMINA EN ROLLBACK. Todos los datos de prueba se descartan limpiamente.

begin;

do $$
declare
  v_fallos integer := 0;
  v_tenant uuid;
  v_otro_tenant uuid;
  v_principal uuid;
  v_secundaria uuid;
  v_estado_original text;
  v_corte_original timestamptz;
  v_corte_negocio timestamptz;
  v_res record;
  v_cargo record;
  v_bs record;
  v_ref text := 'ref-204-' || extract(epoch from now())::bigint::text;
begin
  raise notice '======================================================================';
  raise notice 'CONTROL 204 - El pago que activa una sede (D-192, Etapa 3b)';
  raise notice '======================================================================';

  select ts.tenant_id, ts.status, ts.current_period_end
    into v_tenant, v_estado_original, v_corte_original
  from public.tenant_subscriptions ts order by ts.created_at limit 1;

  if v_tenant is null then
    raise exception 'No hay ninguna suscripcion de negocio: este control necesita al menos una.';
  end if;

  select id into v_otro_tenant from public.tenants where id <> v_tenant limit 1;

  -- El negocio con un corte vivo dentro de 10 dias, para que el alta de una
  -- sede nueva salga prorrateada.
  update public.tenant_subscriptions
  set status = 'active', current_period_end = now() + interval '10 days'
  where tenant_id = v_tenant;

  select b.id into v_principal
  from public.branches b
  where b.tenant_id = v_tenant and b.is_primary
  limit 1;

  insert into public.branches (tenant_id, name, slug, active, is_primary)
  values (v_tenant, 'Sede Control 204', 'sede-control-204', true, false)
  returning id into v_secundaria;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 1: un pago suficiente activa la sede secundaria ---';
  -- -------------------------------------------------------------------------
  select * into v_cargo from private.beautyos_calcular_cargo_sede(v_secundaria);

  select * into v_res from private.beautyos_procesar_pago_de_sede(
    v_tenant, v_secundaria, v_ref, 'tx-204', 'Aceptada', '1',
    v_cargo.monto_cop, 'COP', '{}'::jsonb
  );

  select * into v_bs from public.branch_subscriptions where branch_id = v_secundaria;

  if v_bs.status <> 'active' then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 1 (CRITICO): un pago suficiente no activo la sede (quedo en %). %',
      v_bs.status, v_res.message;
  elsif v_bs.current_period_end is null then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 1b: la sede se activo sin periodo.';
  else
    raise notice 'OK 1: sede activa hasta %. %', v_bs.current_period_end, v_res.message;
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 2: el prorrateo termina en el corte del NEGOCIO ---';
  -- -------------------------------------------------------------------------
  select current_period_end into v_corte_negocio
  from public.tenant_subscriptions where tenant_id = v_tenant;

  if abs(extract(epoch from (v_bs.current_period_end - v_corte_negocio))) > 5 then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 2 (CRITICO): la sede termina el % y el negocio el %. '
      'Un salon, una fecha de cobro (D-191).', v_bs.current_period_end, v_corte_negocio;
  else
    raise notice 'OK 2: la sede y el negocio cortan el mismo dia.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 3: la sede secundaria NO movio la fecha del negocio ---';
  -- -------------------------------------------------------------------------
  --
  -- Si la moviera, pagar una segunda sede le regalaria un mes al cliente.
  if abs(extract(epoch from (v_corte_negocio - (now() + interval '10 days')))) > 5 then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 3 (CRITICO): pagar una sede secundaria corrio la fecha de corte del negocio a %. '
      'Eso le regala un mes al cliente.', v_corte_negocio;
  else
    raise notice 'OK 3: la fecha del negocio no se movio.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 4: la idempotencia de D-141 sostiene ---';
  -- -------------------------------------------------------------------------
  select * into v_res from private.beautyos_procesar_pago_de_sede(
    v_tenant, v_secundaria, v_ref, 'tx-204', 'Aceptada', '1',
    999999::bigint, 'COP', '{}'::jsonb
  );

  if v_res.processed then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 4 (CRITICO): la misma referencia se proceso dos veces.';
  else
    raise notice 'OK 4: referencia repetida ignorada. %', v_res.message;
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 5: un pago CORTO no activa ---';
  -- -------------------------------------------------------------------------
  update public.branch_subscriptions
  set status = 'pending', current_period_end = null, activated_at = null
  where branch_id = v_secundaria;

  select * into v_cargo from private.beautyos_calcular_cargo_sede(v_secundaria);

  select * into v_res from private.beautyos_procesar_pago_de_sede(
    v_tenant, v_secundaria, v_ref || '-corto', 'tx-204b', 'Aceptada', '1',
    greatest(v_cargo.monto_cop - 1000, 1)::bigint, 'COP', '{}'::jsonb
  );

  select status into v_estado_original
  from public.branch_subscriptions where branch_id = v_secundaria;

  if v_estado_original = 'active' then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 5 (CRITICO): un pago menor al requerido activo la sede. Se perdio D-159.';
  else
    raise notice 'OK 5: pago corto rechazado. %', v_res.message;
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 6: un prorrateo por DEBAJO de 10.000 si se acepta ---';
  -- -------------------------------------------------------------------------
  --
  -- Es el caso que obligo a separar esta funcion de la que cobra el negocio:
  -- aquella tiene un piso de $10.000 y rechazaria un cobro legitimo de dos dias.
  update public.tenant_subscriptions
  set current_period_end = now() + interval '1 day'
  where tenant_id = v_tenant;

  update public.branch_subscriptions
  set status = 'pending', current_period_end = null, activated_at = null
  where branch_id = v_secundaria;

  select * into v_cargo from private.beautyos_calcular_cargo_sede(v_secundaria);

  if v_cargo.monto_cop >= 10000 then
    raise notice 'AVISO 6: con este precio, un dia cuesta % y no baja de 10.000. Caso no ejercitado.',
      v_cargo.monto_cop;
  else
    select * into v_res from private.beautyos_procesar_pago_de_sede(
      v_tenant, v_secundaria, v_ref || '-mini', 'tx-204c', 'Aceptada', '1',
      v_cargo.monto_cop, 'COP', '{}'::jsonb
    );

    select status into v_estado_original
    from public.branch_subscriptions where branch_id = v_secundaria;

    if v_estado_original <> 'active' then
      v_fallos := v_fallos + 1;
      raise warning 'FALLO 6 (CRITICO): se rechazo un prorrateo legitimo de % COP. '
        'El piso de 10.000 no aplica a los prorrateos.', v_cargo.monto_cop;
    else
      raise notice 'OK 6: prorrateo de % COP aceptado, sin el piso de 10.000.', v_cargo.monto_cop;
    end if;
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 7: un pago rechazado por la pasarela no activa ---';
  -- -------------------------------------------------------------------------
  update public.branch_subscriptions
  set status = 'pending', current_period_end = null
  where branch_id = v_secundaria;

  select * into v_cargo from private.beautyos_calcular_cargo_sede(v_secundaria);

  select * into v_res from private.beautyos_procesar_pago_de_sede(
    v_tenant, v_secundaria, v_ref || '-rech', 'tx-204d', 'Rechazada', '2',
    v_cargo.monto_cop, 'COP', '{}'::jsonb
  );

  select status into v_estado_original
  from public.branch_subscriptions where branch_id = v_secundaria;

  if v_estado_original = 'active' then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 7 (CRITICO): un pago RECHAZADO activo la sede.';
  else
    raise notice 'OK 7: rechazado por la pasarela, sede sin activar. %', v_res.message;
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 8: una sede de otro negocio se rechaza ---';
  -- -------------------------------------------------------------------------
  if v_otro_tenant is null then
    raise notice 'AVISO 8: solo hay un negocio, no se puede probar.';
  else
    begin
      perform private.beautyos_procesar_pago_de_sede(
        v_otro_tenant, v_secundaria, v_ref || '-ajena', 'tx-204e', 'Aceptada', '1',
        150000::bigint, 'COP', '{}'::jsonb
      );
      v_fallos := v_fallos + 1;
      raise warning 'FALLO 8 (CRITICO): se acepto pagar la sede de un negocio con otro negocio. '
        'Es la misma clase de agujero que cerro TL-01.';
    exception when others then
      raise notice 'OK 8: la sede tiene que ser del negocio que paga (%).', sqlerrm;
    end;
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 9: la sede PRINCIPAL si arrastra al negocio ---';
  -- -------------------------------------------------------------------------
  if v_principal is null then
    raise notice 'AVISO 9: el negocio no tiene sede principal marcada.';
  else
    update public.tenant_subscriptions
    set status = 'active', current_period_end = now() - interval '2 days'
    where tenant_id = v_tenant;

    update public.branch_subscriptions
    set status = 'active', current_period_end = now() - interval '2 days'
    where branch_id = v_principal;

    select * into v_cargo from private.beautyos_calcular_cargo_sede(v_principal);

    select * into v_res from private.beautyos_procesar_pago_de_sede(
      v_tenant, v_principal, v_ref || '-ppal', 'tx-204f', 'Aceptada', '1',
      v_cargo.monto_cop, 'COP', '{}'::jsonb
    );

    select current_period_end into v_corte_negocio
    from public.tenant_subscriptions where tenant_id = v_tenant;

    if v_corte_negocio is null or v_corte_negocio <= now() then
      v_fallos := v_fallos + 1;
      raise warning 'FALLO 9 (CRITICO): pagar la sede principal no revivio la suscripcion del negocio. '
        'Un salon de una sola sede pagaria y se quedaria fuera de su aplicacion. %', v_res.message;
    else
      raise notice 'OK 9: la sede principal arrastra al negocio hasta %.', v_corte_negocio;
    end if;
  end if;

  -- -------------------------------------------------------------------------
  raise notice '======================================================================';
  if v_fallos = 0 then
    raise notice 'CONTROL 204: TODOS LOS CASOS EN VERDE. El cobro por sede sostiene.';
  else
    raise exception 'CONTROL 204: % caso(s) fallaron. Revisar arriba.', v_fallos;
  end if;
  raise notice '======================================================================';
end;
$$;

rollback;
