-- CONTROL 210: Cambiar el estado de pago de una sede (D-236, paso 9.36).
--
-- POR QUE ESTE ARCHIVO
--
-- `platform_set_branch_subscription` existe desde D-190 y **nunca tuvo
-- control**, porque nunca tuvo pantalla: se construyo la capacidad y no la
-- puerta. Al darle boton en el Panel (D-236) pasa a poder usarse de verdad, y
-- toca dinero de un cliente: su precio y hasta cuando esta pagada su sede.
--
-- Lo que mas importa vigilar es lo que la funcion RECHAZA, no lo que acepta:
-- un estado inventado, y sobre todo **un precio sin motivo**. El motivo es lo
-- unico que deja escrito por que un salon paga distinto (D-136), y sin el, seis
-- meses despues nadie sabe si fue un acuerdo o un dedazo.
--
-- Que valida, transaccionalmente:
--   1. La funcion existe y es SECURITY DEFINER.
--   2. Un estado invalido se rechaza.
--   3. **Un precio pactado SIN motivo se rechaza** (D-136).
--   4. Con motivo, el precio queda guardado y lo ve el lector del Panel.
--   5. `activated_at` se sella la PRIMERA vez y no se mueve despues (D-190):
--      sirve para saber si una sede nunca llego a pagarse o si se cayo luego.
--   6. `anon` no la alcanza.
--   7. **QUITAR el precio devuelve la sede a la tarifa vigente** (D-237). Esto
--      es lo que fallaba: la funcion sabia poner y cambiar, nunca limpiar.
--   8. Limpiar y fijar a la vez se rechaza, en vez de adivinar cual gana.
--
-- COMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\210_test_cambiar_estado_de_sede.sql"
--
-- TERMINA EN ROLLBACK. Todos los datos de prueba se descartan limpiamente.
--
-- NOTA: `branches.slug` es NOT NULL y unico por negocio, y un disparador ya le
-- crea su suscripcion `pending` a cada sede (D-190).

begin;

do $ctrl$
declare
  v_owner    uuid := gen_random_uuid();
  v_plan     uuid;
  v_tenant   uuid;
  v_sede     uuid;
  v_def      text;
  v_capturo  boolean;
  v_error    text;
  v_sellado  timestamptz;
  v_despues  timestamptz;
  r          record;
begin
  -- 1. La funcion existe y esta blindada
  select pg_get_functiondef(p.oid) into v_def
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'platform_set_branch_subscription';

  if v_def is null then
    raise exception 'FALLO 1: public.platform_set_branch_subscription no existe';
  end if;
  if v_def not ilike '%security definer%' then
    raise exception 'FALLO 1b: la funcion no es SECURITY DEFINER';
  end if;
  raise notice 'OK 1   la funcion existe y es SECURITY DEFINER';

  -- Fixtures
  select id into v_plan from public.plans where code = 'pro' and status = 'active' limit 1;
  if v_plan is null then
    raise exception 'FALLO: no hay plan pro activo con el que probar';
  end if;

  insert into auth.users (id, email) values (v_owner, 'owner_test210@salonymas.com')
  on conflict (id) do nothing;
  insert into public.platform_operators (user_id, role, active)
  values (v_owner, 'platform_owner', true)
  on conflict (user_id) do update set role = excluded.role, active = true;

  insert into public.tenants (name, business_type, contact_email, whatsapp, is_demo, active)
  values ('Control 210', 'barberia', 'c210@salonymas.com', '3000000212', true, true)
  returning id into v_tenant;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_tenant, v_plan, 'active', now() + interval '30 days');

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C210 sede', 'c210-sede', true, true) returning id into v_sede;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_owner::text, 'role', 'authenticated')::text, true);

  -- 2. Un estado inventado se rechaza
  v_capturo := false;
  begin
    perform public.platform_set_branch_subscription(v_sede, 'al_dia_creo');
  exception when others then
    v_capturo := true;
    v_error := sqlerrm;
  end;
  if not v_capturo then
    raise exception 'FALLO 2: acepto un estado que no existe';
  end if;
  raise notice 'OK 2   un estado invalido se rechaza';

  -- 3. Un precio SIN motivo se rechaza. Esta es la importante.
  v_capturo := false;
  begin
    perform public.platform_set_branch_subscription(v_sede, 'active', 45000, null);
  exception when others then
    v_capturo := true;
    v_error := sqlerrm;
  end;
  if not v_capturo then
    raise exception 'FALLO 3: guardo un precio pactado SIN motivo. Sin motivo, en seis meses nadie sabe si fue acuerdo o dedazo (D-136).';
  end if;
  if v_error not like '%motivo%' then
    raise exception 'FALLO 3b: se rechazo, pero el mensaje no dice que falta el motivo: %', v_error;
  end if;
  raise notice 'OK 3   un precio sin motivo se rechaza, y el mensaje lo explica';

  -- 4. Con motivo, el precio queda y lo ve el lector del Panel
  perform public.platform_set_branch_subscription(
    v_sede, 'active', 45000, 'Control 210: tarifa vigente de sede adicional',
    now() + interval '30 days'
  );

  select * into r from public.platform_get_tenant_branches(v_tenant) limit 1;
  if r.precio_cop is distinct from 45000 then
    raise exception 'FALLO 4: el lector del Panel dice % y se guardaron 45000', r.precio_cop;
  end if;
  if r.motivo_precio not like 'Control 210%' then
    raise exception 'FALLO 4b: el motivo no llego al lector: %', r.motivo_precio;
  end if;
  if not r.al_dia then
    raise exception 'FALLO 4c: la sede quedo activa y el lector no la ve al dia';
  end if;
  raise notice 'OK 4   el precio y su motivo quedan guardados y los ve el Panel';

  -- 5. `activated_at` se sella una sola vez (D-190)
  select activated_at into v_sellado
  from public.branch_subscriptions where branch_id = v_sede;
  if v_sellado is null then
    raise exception 'FALLO 5: al activar no se sello activated_at';
  end if;

  perform pg_sleep(0.05);
  perform public.platform_set_branch_subscription(
    v_sede, 'active', 45000, 'Control 210: segunda activacion'
  );
  select activated_at into v_despues
  from public.branch_subscriptions where branch_id = v_sede;

  if v_despues is distinct from v_sellado then
    raise exception 'FALLO 5b: activated_at se movio en la segunda activacion. Deja de servir para saber si una sede nunca llego a pagarse (D-190).';
  end if;
  raise notice 'OK 5   activated_at se sella la primera vez y no se mueve';

  -- 7. QUITAR el precio devuelve la sede a la tarifa vigente (D-237).
  --
  -- Esto es lo que fallaba: `coalesce(p_price_cop, price_cop)` conservaba el
  -- valor al recibir null, asi que la funcion sabia poner y cambiar pero
  -- nunca limpiar. El propietario lo encontro intentando cumplir D-222.
  perform public.platform_set_branch_subscription(
    v_sede, 'active', null, null, null, true
  );

  select * into r from public.platform_get_tenant_branches(v_tenant) limit 1;
  if r.tiene_precio_pactado then
    raise exception 'FALLO 7: se pidio limpiar el precio y sigue habiendo uno pactado';
  end if;
  if r.precio_cop is distinct from (select price_cop from public.plans where id = v_plan) then
    raise exception 'FALLO 7b: sin precio pactado deberia cobrar la tarifa de lista, y dice %', r.precio_cop;
  end if;
  if r.motivo_precio is distinct from 'Precio de lista' then
    raise exception 'FALLO 7c: se limpio el precio y quedo un motivo huerfano: %', r.motivo_precio;
  end if;
  raise notice 'OK 7   quitar el precio devuelve la sede a la tarifa vigente';

  -- 8. Limpiar y fijar a la vez se rechaza en vez de adivinar
  v_capturo := false;
  begin
    perform public.platform_set_branch_subscription(
      v_sede, 'active', 33000, 'Contradictorio', null, true
    );
  exception when others then
    v_capturo := true;
  end;
  if not v_capturo then
    raise exception 'FALLO 8: acepto limpiar el precio Y fijar uno en la misma operacion';
  end if;
  raise notice 'OK 8   limpiar y fijar a la vez se rechaza';

  -- 6. anon no la alcanza
  if has_function_privilege('anon',
       'public.platform_set_branch_subscription(uuid, text, bigint, text, timestamptz)',
       'execute') then
    raise exception 'FALLO 6: anon puede cambiar el estado de pago de una sede';
  end if;
  raise notice 'OK 6   anon no alcanza la funcion';

  raise notice '---------------------------------------------';
  raise notice 'CONTROL 210 COMPLETO: 8 de 8 en verde.';
end
$ctrl$;

rollback;
