-- CONTROL 236: El alta de una sede cobra al menos el minimo de ePayco ($5.000).
--              Hallazgo BY (D-296).
--
-- POR QUE ESTE ARCHIVO
--
-- El 30-sep ePayco rechazo el alta de "Barberia Barber Elite": $10.000 al mes,
-- 9 dias hasta el corte, $3.000. ePayco solo acepta entre $5.000 y $5.000.000,
-- asi que la sede no se podia activar. El propietario decidio cobrar $5.000
-- cuando el prorrateo de menos.
--
-- Como el 226, este control no solo lee el calculo: **paga**, por la misma
-- funcion que llama el webhook de ePayco (D-245: los controles ejecutan el
-- camino). Fixtures copiados del 226.
--
-- Que valida, transaccionalmente:
--   1. El minimo de la pasarela es $5.000, en un solo sitio.
--   2. Un alta a 9 dias de una sede de $10.000 cobra $5.000, no $3.000, y la
--      sede sigue pagada solo hasta la fecha de corte del negocio.
--   3. Pagar $4.999 NO la activa, y dice por que.
--   4. Pagar $5.000 la activa hasta la fecha de corte, y NO toca la fecha del
--      negocio (es una sede secundaria, D-192).
--   5. Por encima del minimo el prorrateo no cambia: a 20 dias son $6.667.
--   6. Lo que no es prorrateo sigue cobrando el mes completo ($10.000).
--
-- COMO SE EJECUTA (despues de aplicar 20260930100000_el_alta_de_sede_cobra_el_minimo_de_epayco_by.sql)
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\236_test_el_alta_de_sede_cobra_el_minimo_de_epayco_by.sql"
--
-- TERMINA EN ROLLBACK.

begin;

do $ctrl$
declare
  v_plan      uuid;
  v_tenant    uuid;
  v_principal uuid;
  v_sede      uuid;
  v_sede20    uuid;
  v_ancla     timestamptz := now() + interval '9 days' - interval '1 hour';
  v_ancla20   timestamptz := now() + interval '20 days' - interval '1 hour';
  v_calc      record;
  v_res       record;
  v_estado    text;
  v_hasta     timestamptz;
  v_negocio   timestamptz;
begin
  select id into v_plan from public.plans where status = 'active' limit 1;
  if v_plan is null then
    raise exception 'FALLO: no hay ningun plan activo con el que probar';
  end if;

  -- 1. El minimo de la pasarela
  if private.beautyos_cobro_minimo_pasarela_cop() is distinct from 5000 then
    raise exception 'FALLO 1: el minimo de la pasarela es % y debia ser 5000.',
      private.beautyos_cobro_minimo_pasarela_cop();
  end if;
  raise notice 'OK 1   el minimo de ePayco es $5.000, en un solo sitio';

  -- Un negocio al dia, con su fecha de corte dentro de 9 dias, y una sede
  -- nueva de $10.000 que nunca se ha pagado.
  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 236', 'barberia', 'c236@salonymas.com', '3000000236', true)
  returning id into v_tenant;

  insert into public.tenant_subscriptions (
    tenant_id, plan_id, status, current_period_start, current_period_end
  ) values (
    v_tenant, v_plan, 'active', v_ancla - interval '30 days', v_ancla
  );

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C236 principal', 'c236-principal', true, true)
  returning id into v_principal;

  update public.branch_subscriptions
  set status = 'active', price_cop = 10000, price_reason = 'control 236',
      current_period_start = v_ancla - interval '30 days', current_period_end = v_ancla,
      activated_at = v_ancla - interval '30 days'
  where branch_id = v_principal;

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C236 sede nueva', 'c236-sede-nueva', false, true)
  returning id into v_sede;

  update public.branch_subscriptions
  set price_cop = 10000, price_reason = 'control 236',
      current_period_start = null, current_period_end = null
  where branch_id = v_sede;

  -- 2. El alta a 9 dias cobra el minimo, no el prorrateo
  select * into v_calc from private.beautyos_calcular_cargo_sede(v_sede);
  if v_calc.motivo is distinct from 'alta_de_sede_prorrateada' then
    raise exception 'FALLO 2: el motivo es % y debia ser alta_de_sede_prorrateada.', v_calc.motivo;
  end if;
  if v_calc.monto_cop is distinct from 5000 then
    raise exception 'FALLO 2b: a 9 dias el cargo es % y debia ser 5000 (el prorrateo daria 3000, que ePayco rechaza).', v_calc.monto_cop;
  end if;
  if v_calc.periodo_fin is distinct from v_ancla then
    raise exception 'FALLO 2c: el periodo termina % y debia terminar en la fecha de corte del negocio (%).', v_calc.periodo_fin, v_ancla;
  end if;
  raise notice 'OK 2   un alta a 9 dias de una sede de $10.000 cobra $5.000, hasta la misma fecha de corte';

  -- 3. Un peso menos no activa
  select * into v_res from private.beautyos_procesar_pago_de_sede(
    v_tenant, v_sede, 'c236_ref_1', 'c236_tx_1', 'Aceptada', '1', 4999, 'COP', '{}'::jsonb);
  select bs.current_period_end into v_hasta from public.branch_subscriptions bs where bs.branch_id = v_sede;
  if v_hasta is not null then
    raise exception 'FALLO 3: un pago de $4.999 activo la sede (hasta %). Dijo: %', v_hasta, v_res.message;
  end if;
  if v_res.message not ilike '%menor al requerido%' then
    raise exception 'FALLO 3b: se nego, pero sin decir por que. Dijo: %', v_res.message;
  end if;
  raise notice 'OK 3   un pago de $4.999 no activa la sede, y dice por que';

  -- 4. $5.000 la activan hasta el corte, sin tocar la fecha del negocio
  select * into v_res from private.beautyos_procesar_pago_de_sede(
    v_tenant, v_sede, 'c236_ref_2', 'c236_tx_2', 'Aceptada', '1', 5000, 'COP', '{}'::jsonb);
  select bs.status, bs.current_period_end into v_estado, v_hasta
  from public.branch_subscriptions bs where bs.branch_id = v_sede;
  select ts.current_period_end into v_negocio from public.tenant_subscriptions ts where ts.tenant_id = v_tenant;
  if v_estado <> 'active' or v_hasta is distinct from v_ancla then
    raise exception 'FALLO 4: pagando $5.000 la sede quedo en % hasta % (debia quedar activa hasta %). Dijo: %', v_estado, v_hasta, v_ancla, v_res.message;
  end if;
  if v_negocio is distinct from v_ancla then
    raise exception 'FALLO 4b: una sede secundaria movio la fecha de corte del negocio a % (era %).', v_negocio, v_ancla;
  end if;
  raise notice 'OK 4   $5.000 activan la sede hasta la fecha de corte, y la fecha del negocio no se mueve';

  -- 5. Por encima del minimo, el prorrateo no cambia
  update public.tenant_subscriptions set current_period_end = v_ancla20 where tenant_id = v_tenant;

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C236 sede a 20 dias', 'c236-sede-20', false, true)
  returning id into v_sede20;

  update public.branch_subscriptions
  set price_cop = 10000, price_reason = 'control 236',
      current_period_start = null, current_period_end = null
  where branch_id = v_sede20;

  select * into v_calc from private.beautyos_calcular_cargo_sede(v_sede20);
  if v_calc.monto_cop is distinct from 6667 then
    raise exception 'FALLO 5: a 20 dias el cargo es % y debia seguir siendo el prorrateo (6667).', v_calc.monto_cop;
  end if;
  raise notice 'OK 5   por encima del minimo el prorrateo no cambia: a 20 dias son $6.667';

  -- 6. Lo que no es prorrateo, igual que antes
  select * into v_calc from private.beautyos_calcular_cargo_sede(v_sede);
  if v_calc.motivo is distinct from 'renovacion_anticipada' or v_calc.monto_cop is distinct from 10000 then
    raise exception 'FALLO 6: la renovacion de una sede de $10.000 da % (%) y debia ser 10000 (renovacion_anticipada).', v_calc.monto_cop, v_calc.motivo;
  end if;
  raise notice 'OK 6   la renovacion sigue cobrando el mes completo ($10.000)';

  raise notice '--- CONTROL 236: 6/6 ---';
end
$ctrl$;

rollback;
