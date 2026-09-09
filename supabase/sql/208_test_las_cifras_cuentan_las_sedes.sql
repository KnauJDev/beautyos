-- CONTROL 208: El dinero de las sedes cuenta (D-232, paso 9.34).
--
-- POR QUE ESTE ARCHIVO
--
-- D-188 decidio que el plan se cobra por sede activa, y D-190 a D-192 lo
-- construyeron. Pero las metricas eran del 29-ago y nunca se pusieron al dia:
-- el MRR sumaba el precio del negocio una sola vez, y el pago de sede no
-- escribia `monto_cop_recibido`, que es la clave que leen el cobrado historico
-- Y las comisiones de partners.
--
-- Un partner que refiriera un salon de tres sedes cobraba por una. Este
-- control existe para que eso no pueda volver a pasar en silencio.
--
-- Que valida, transaccionalmente:
--   1. Un negocio con DOS sedes activas aporta las DOS al MRR, no una.
--   2. Un negocio marcado como demo no aporta nada (D-225 sigue en pie).
--   3. Una sede desactivada no aporta, aunque su suscripcion diga active.
--   4. Un pago de sede aceptado deja `monto_cop_recibido` en el evento, que es
--      lo que hace que lo vean el cobrado historico y las comisiones.
--   5. El evento tambien guarda de que sede vino y si era la principal.
--
-- COMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\208_test_las_cifras_cuentan_las_sedes.sql"
--
-- TERMINA EN ROLLBACK. Todos los datos de prueba se descartan limpiamente.
--
-- NOTA: `branches.slug` es NOT NULL sin default y unico por negocio. La
-- primera version de este control lo omitio y fallo antes de probar nada.
-- Si se anaden sedes de prueba, cada una necesita su slug.

begin;

do $ctrl$
declare
  v_owner       uuid := gen_random_uuid();
  v_plan        uuid;
  v_tenant      uuid;
  v_demo        uuid;
  v_sede_a      uuid;
  v_sede_b      uuid;
  v_sede_off    uuid;
  v_sede_demo   uuid;
  v_mrr_antes   bigint;
  v_mrr_despues bigint;
  v_delta       bigint;
  v_payload     jsonb;
  v_res         record;
begin
  select id into v_plan from public.plans where code = 'pro' and status = 'active' limit 1;
  if v_plan is null then
    raise exception 'FALLO: no hay plan pro activo con el que probar';
  end if;

  insert into auth.users (id, email) values (v_owner, 'owner_test208@salonymas.com')
  on conflict (id) do nothing;

  insert into public.platform_operators (user_id, role, active)
  values (v_owner, 'platform_owner', true)
  on conflict (user_id) do update set role = excluded.role, active = true;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_owner::text, 'role', 'authenticated')::text, true);

  -- Foto del MRR antes de las fixtures, para medir solo lo que ellas aportan
  -- sin depender de cuantos negocios reales existan ya.
  select (public.platform_get_saas_metrics()->>'mrr_cop')::bigint into v_mrr_antes;

  -- Un negocio REAL con dos sedes activas a 30.000, mas una tercera
  -- desactivada que no debe contar.
  insert into public.tenants (name, business_type, contact_email, whatsapp, is_demo, active)
  values ('Control 208 - real', 'barberia', 'c208@salonymas.com', '3000000208', false, true)
  returning id into v_tenant;

  insert into public.tenant_subscriptions
    (tenant_id, plan_id, status, current_period_start, current_period_end)
  values (v_tenant, v_plan, 'active', now(), now() + interval '30 days');

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C208 principal', 'c208-principal', true, true) returning id into v_sede_a;

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C208 segunda', 'c208-segunda', false, true) returning id into v_sede_b;

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C208 cerrada', 'c208-cerrada', false, false) returning id into v_sede_off;

  insert into public.branch_subscriptions
    (tenant_id, branch_id, status, price_cop, price_reason,
     current_period_start, current_period_end)
  values
    (v_tenant, v_sede_a,   'active', 30000, 'Control 208', now(), now() + interval '30 days'),
    (v_tenant, v_sede_b,   'active', 30000, 'Control 208', now(), now() + interval '30 days'),
    (v_tenant, v_sede_off, 'active', 30000, 'Control 208', now(), now() + interval '30 days');

  -- Un negocio DEMO con una sede activa y caro: no debe aportar nada.
  insert into public.tenants (name, business_type, contact_email, whatsapp, is_demo, active)
  values ('Control 208 - demo', 'barberia', 'c208d@salonymas.com', '3000000209', true, true)
  returning id into v_demo;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_demo, v_plan, 'active', now() + interval '30 days');

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_demo, 'C208 demo', 'c208-demo', true, true) returning id into v_sede_demo;

  insert into public.branch_subscriptions
    (tenant_id, branch_id, status, price_cop, price_reason, current_period_end)
  values (v_demo, v_sede_demo, 'active', 99000, 'Control 208 demo', now() + interval '30 days');

  select (public.platform_get_saas_metrics()->>'mrr_cop')::bigint into v_mrr_despues;
  v_delta := v_mrr_despues - v_mrr_antes;

  -- 1, 2 y 3: el MRR cuenta las dos sedes activas y nada mas
  if v_delta <> 60000 then
    raise exception
      'FALLO 1: el MRR subio % y debia subir 60000 (dos sedes a 30.000). Si subio 30000, sigue contando por negocio. Si subio 90000 o mas, esta contando la sede cerrada o el demo.',
      v_delta;
  end if;
  raise notice 'OK 1   el MRR cuenta las DOS sedes activas: mas 60.000';
  raise notice 'OK 2   el negocio demo no aporta (habria sumado 99.000)';
  raise notice 'OK 3   la sede desactivada no aporta, aunque su suscripcion diga active';

  -- 4 y 5: el pago de una sede deja monto_cop_recibido en el evento
  select * into v_res from private.beautyos_procesar_pago_de_sede(
    v_tenant, v_sede_b, 'ref-control-208', 'tx-control-208',
    'Aceptada', '1', 30000, 'COP',
    jsonb_build_object('x_ref_payco', 'ref-control-208')
  );

  select payload into v_payload
  from public.subscription_events
  where provider = 'epayco' and provider_event_id = 'ref-control-208';

  if v_payload is null then
    raise exception 'FALLO 4: el pago de sede no dejo evento registrado';
  end if;

  if not (v_payload ? 'monto_cop_recibido') then
    raise exception 'FALLO 4b: el evento NO trae monto_cop_recibido. El cobrado historico y las comisiones de partners seguiran ciegos a las sedes (D-231).';
  end if;

  if (v_payload->>'monto_cop_recibido')::bigint <> 30000 then
    raise exception 'FALLO 4c: monto_cop_recibido dice % y se pagaron 30000',
      v_payload->>'monto_cop_recibido';
  end if;
  raise notice 'OK 4   el evento del pago de sede trae monto_cop_recibido = %',
    v_payload->>'monto_cop_recibido';

  if (v_payload->>'branch_id') is distinct from v_sede_b::text then
    raise exception 'FALLO 5: el evento no dice de que sede vino el pago';
  end if;

  if (v_payload->>'es_sede_principal')::boolean is not false then
    raise exception 'FALLO 5b: el evento marca como principal una sede secundaria';
  end if;
  raise notice 'OK 5   el evento identifica la sede y que no era la principal';

  raise notice '---------------------------------------------';
  raise notice 'CONTROL 208 COMPLETO: 5 de 5 en verde.';
end
$ctrl$;

rollback;
