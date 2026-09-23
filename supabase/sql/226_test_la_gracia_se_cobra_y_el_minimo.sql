-- CONTROL 226: La gracia se cobra entera, y nadie pacta por debajo del minimo.
--              Hallazgos BN y BO (D-264, D-265).
--
-- POR QUE ESTE ARCHIVO
--
-- BN: pagar dentro de los 5 dias de gracia costaba solo los dias que faltaban
-- hasta el corte; los dias de gracia salian gratis. El propietario decidio
-- cobrar el mes completo sin correr la fecha de corte.
--
-- BO: la activacion de una sede exige como minimo $10.000, y la sede de la
-- Peluqueria Exito estaba pactada en $4.500: su pago real se habria cobrado
-- sin activarla. El propietario decidio que el minimo se queda y que nadie
-- pacte por debajo.
--
-- Este control no lee los calculos: **paga**. Recorre la funcion que liquida
-- el pago de una sede, la misma que llama el webhook de ePayco (D-245: los
-- controles ejecutan el camino).
--
-- Que valida, transaccionalmente:
--   1. En la gracia, el cargo es el mes completo y la fecha de corte no se
--      corre.
--   2. Un pago de menos en la gracia NO activa la sede (antes era el pago
--      "prorrateado" y si la activaba).
--   3. El mes completo la activa, hasta la misma fecha de corte de siempre, y
--      arrastra al negocio porque es la principal (D-192).
--   4. Una sede pactada en $10.000 justos se activa pagando $10.000: el paso
--      9.8 ya no choca contra el minimo.
--   5. Pactar por debajo de $10.000 se niega, y dice por que.
--   6. $10.000 justos y "sin precio" (tarifa de lista) se aceptan.
--   7. En la base no queda ninguna sede por debajo del minimo.
--
-- COMO SE EJECUTA (despues de aplicar 20260923190000_la_gracia_se_cobra_y_el_cobro_minimo_bn_bo.sql)
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\226_test_la_gracia_se_cobra_y_el_minimo.sql"
--
-- TERMINA EN ROLLBACK.

begin;

do $ctrl$
declare
  v_plan      uuid;
  v_tenant    uuid;
  v_branch    uuid;
  v_fin       timestamptz := now() - interval '2 days';
  v_calc      record;
  v_res       record;
  v_estado    text;
  v_hasta     timestamptz;
  v_negocio   timestamptz;
  v_capturo   boolean;
  v_error     text;
  v_minimo    bigint;
begin
  select id into v_plan from public.plans where status = 'active' limit 1;
  if v_plan is null then
    raise exception 'FALLO: no hay ningun plan activo con el que probar';
  end if;

  -- Un negocio de una sede, en su gracia: vencio hace dos dias.
  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 226', 'peluqueria', 'c226@salonymas.com', '3000000229', true)
  returning id into v_tenant;

  insert into public.tenant_subscriptions (
    tenant_id, plan_id, status, current_period_start, current_period_end, grace_ends_at
  ) values (
    v_tenant, v_plan, 'past_due', v_fin - interval '30 days', v_fin, v_fin + interval '5 days'
  );

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C226 sede', 'c226-sede', true, true)
  returning id into v_branch;

  update public.branch_subscriptions
  set status = 'past_due', price_cop = 20000, price_reason = 'control 226',
      current_period_start = v_fin - interval '30 days', current_period_end = v_fin,
      grace_ends_at = v_fin + interval '5 days', activated_at = v_fin - interval '30 days'
  where branch_id = v_branch;

  -- 1. El cargo en la gracia
  select * into v_calc from private.beautyos_calcular_cargo_sede(v_branch);
  if v_calc.monto_cop is distinct from 20000 then
    raise exception 'FALLO 1: en la gracia el cargo es % y debia ser el mes completo (20000).', v_calc.monto_cop;
  end if;
  if v_calc.periodo_fin is distinct from v_fin + interval '30 days' then
    raise exception 'FALLO 1b: el periodo termina % y debia terminar en la misma fecha de corte (%).', v_calc.periodo_fin, v_fin + interval '30 days';
  end if;
  if v_calc.motivo is distinct from 'pago_tardio_en_gracia' then
    raise exception 'FALLO 1c: el motivo es % y debia ser pago_tardio_en_gracia.', v_calc.motivo;
  end if;
  raise notice 'OK 1   en la gracia se cobra el mes completo y la fecha de corte no se corre';

  -- 2. Un pago de menos no activa
  select * into v_res from private.beautyos_procesar_pago_de_sede(
    v_tenant, v_branch, 'c226_ref_1', 'c226_tx_1', 'Aceptada', '1', 18000, 'COP', '{}'::jsonb);
  select bs.status into v_estado from public.branch_subscriptions bs where bs.branch_id = v_branch;
  if v_estado <> 'past_due' then
    raise exception 'FALLO 2: un pago de $18.000 en la gracia activo la sede (quedo en %). Es el descuento que BN quita.', v_estado;
  end if;
  if v_res.message not ilike '%menor al requerido%' then
    raise exception 'FALLO 2b: se nego, pero sin decir por que. Dijo: %', v_res.message;
  end if;
  raise notice 'OK 2   un pago de menos en la gracia no activa la sede';

  -- 3. El mes completo activa, hasta la misma fecha
  select * into v_res from private.beautyos_procesar_pago_de_sede(
    v_tenant, v_branch, 'c226_ref_2', 'c226_tx_2', 'Aceptada', '1', 20000, 'COP', '{}'::jsonb);
  select bs.status, bs.current_period_end into v_estado, v_hasta
  from public.branch_subscriptions bs where bs.branch_id = v_branch;
  select ts.current_period_end into v_negocio from public.tenant_subscriptions ts where ts.tenant_id = v_tenant;
  if v_estado <> 'active' or v_hasta is distinct from v_fin + interval '30 days' then
    raise exception 'FALLO 3: pagando el mes completo la sede quedo en % hasta %. Dijo: %', v_estado, v_hasta, v_res.message;
  end if;
  if v_negocio is distinct from v_hasta then
    raise exception 'FALLO 3b: la sede principal pago hasta % y el negocio quedo hasta %.', v_hasta, v_negocio;
  end if;
  raise notice 'OK 3   el mes completo la activa hasta la misma fecha de corte, y arrastra al negocio';

  -- 4. $10.000 justos activan: el paso 9.8
  update public.branch_subscriptions set price_cop = 10000, price_reason = 'control 226 minimo'
  where branch_id = v_branch;
  select * into v_res from private.beautyos_procesar_pago_de_sede(
    v_tenant, v_branch, 'c226_ref_3', 'c226_tx_3', 'Aceptada', '1', 10000, 'COP', '{}'::jsonb);
  select bs.current_period_end into v_hasta from public.branch_subscriptions bs where bs.branch_id = v_branch;
  if v_hasta is distinct from v_fin + interval '60 days' then
    raise exception 'FALLO 4: una sede de $10.000 pagando $10.000 no renovo (hasta %). Dijo: %', v_hasta, v_res.message;
  end if;
  raise notice 'OK 4   una sede pactada en $10.000 se renueva pagando $10.000';

  -- 5. Por debajo del minimo se niega
  v_capturo := false;
  begin
    update public.branch_subscriptions set price_cop = 4500, price_reason = 'control 226 por debajo'
    where branch_id = v_branch;
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;
  if not v_capturo then
    raise exception 'FALLO 5: se pacto una sede en $4.500. Su pago no la activaria.';
  end if;
  if v_error not ilike '%cobro m%nimo%' then
    raise exception 'FALLO 5b: se nego, pero sin decir por que. Dijo: %', v_error;
  end if;
  raise notice 'OK 5   pactar por debajo de $10.000 se niega, y dice por que';

  -- 6. $10.000 justos y sin precio, si
  update public.branch_subscriptions set price_cop = 10000, price_reason = 'control 226'
  where branch_id = v_branch;
  update public.branch_subscriptions set price_cop = null, price_reason = null
  where branch_id = v_branch;
  raise notice 'OK 6   $10.000 justos y la tarifa de lista se aceptan';

  -- 7. Nadie por debajo en la base
  select min(bs.price_cop) into v_minimo
  from public.branch_subscriptions bs where bs.price_cop is not null;
  if v_minimo is not null and v_minimo < 10000 then
    raise exception 'FALLO 7: queda una sede pactada en $% en la base.', v_minimo;
  end if;
  raise notice 'OK 7   ninguna sede de la base queda por debajo del minimo (la mas barata: $%)', coalesce(v_minimo::text, 'ninguna pactada');

  raise notice '--- CONTROL 226: 7/7 ---';
end
$ctrl$;

rollback;
