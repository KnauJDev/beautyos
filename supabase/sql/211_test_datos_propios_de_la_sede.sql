-- CONTROL 211: Una sede tiene datos propios (D-241, paso 9.42).
--
-- POR QUE ESTE ARCHIVO
--
-- `branches` nacio el 20-jul con `contact_email`, `contact_phone`, `whatsapp`,
-- `address`, `city` y `department`. **Llevaban dos meses vacias porque nadie
-- las escribia.** D-241 abre la puerta; este control vigila que siga abierta y
-- que nadie que no deba la cruce.
--
-- Lo que mas importa vigilar no es que guarde: es
--   * que **solo** el rol de plataforma pueda escribir datos de un cliente, y
--   * que **escribir vacio vacie**. Esa es la semantica elegida en D-241 a
--     proposito, para no repetir el `coalesce` de D-237 que hacia que `null`
--     conservara y dejaba una funcion que sabia poner pero no quitar. Si
--     alguien "arregla" esto metiendo un coalesce, este control lo caza.
--
-- Que valida, transaccionalmente:
--   1. Las dos funciones existen y son SECURITY DEFINER.
--   2. La columna `manager_name` existe.
--   3. El lector devuelve los siete campos nuevos.
--   4. Lo escrito se lee igual.
--   5. **Escribir vacio VACIA** (no conserva). La importante.
--   6. Un correo sin arroba se rechaza.
--   7. Un usuario sin rol de plataforma es rechazado.
--   8. Una sede que no existe se rechaza en vez de no hacer nada.
--   9. `anon` no alcanza la funcion de escritura.
--
-- COMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\211_test_datos_propios_de_la_sede.sql"
--
-- TERMINA EN ROLLBACK. Todos los datos de prueba se descartan limpiamente.
--
-- NOTA para quien anada fixtures: `branches.slug` es NOT NULL sin default y
-- unico por negocio, y el disparador `branches_crear_suscripcion` (D-190) ya
-- le crea su suscripcion `pending` a cada sede. Las dos cosas costaron una
-- corrida cada una en el control 208.

begin;

do $ctrl$
declare
  v_owner    uuid := gen_random_uuid();
  v_ajeno    uuid := gen_random_uuid();
  v_plan     uuid;
  v_tenant   uuid;
  v_sede     uuid;
  v_def      text;
  v_capturo  boolean;
  v_error    text;
  r          record;
begin
  -- 1. Las dos funciones existen y estan blindadas
  select pg_get_functiondef(p.oid) into v_def
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'platform_update_branch_info';

  if v_def is null then
    raise exception 'FALLO 1: public.platform_update_branch_info no existe';
  end if;
  if v_def not ilike '%security definer%' then
    raise exception 'FALLO 1b: la escritora no es SECURITY DEFINER';
  end if;

  select pg_get_functiondef(p.oid) into v_def
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'platform_get_tenant_branches';

  if v_def is null then
    raise exception 'FALLO 1c: el lector desaparecio';
  end if;
  raise notice 'OK 1   las dos funciones existen y la escritora es SECURITY DEFINER';

  -- 2. La columna nueva existe
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'branches'
      and column_name = 'manager_name'
  ) then
    raise exception 'FALLO 2: falta branches.manager_name. El duenyo del negocio puede no ser el encargado de la sede (D-239), y sin esta columna no hay donde decir quien la lleva.';
  end if;
  raise notice 'OK 2   branches.manager_name existe';

  -- Fixtures
  select id into v_plan from public.plans where code = 'pro' and status = 'active' limit 1;
  if v_plan is null then
    raise exception 'FALLO: no hay plan pro activo con el que probar';
  end if;

  insert into auth.users (id, email) values
    (v_owner, 'owner_test211@salonymas.com'),
    (v_ajeno, 'ajeno_test211@salonymas.com')
  on conflict (id) do nothing;

  insert into public.platform_operators (user_id, role, active)
  values (v_owner, 'platform_owner', true)
  on conflict (user_id) do update set role = excluded.role, active = true;

  insert into public.tenants (name, business_type, contact_email, whatsapp, is_demo, active)
  values ('Control 211', 'barberia', 'c211@salonymas.com', '3000000213', true, true)
  returning id into v_tenant;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_tenant, v_plan, 'active', now() + interval '30 days');

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C211 sede', 'c211-sede', true, true) returning id into v_sede;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_owner::text, 'role', 'authenticated')::text, true);

  -- 3 y 4. Se escribe, y el lector devuelve lo escrito
  perform public.platform_update_branch_info(
    v_sede,
    'Marta Encargada',
    'marta@c211.com',
    '6011234567',
    '3001234567',
    'Calle 123 #45-67',
    'Bogota',
    'Cundinamarca'
  );

  select * into r from public.platform_get_tenant_branches(v_tenant) limit 1;

  if r.manager_name is distinct from 'Marta Encargada' then
    raise exception 'FALLO 3: el lector no devuelve el encargado: %', r.manager_name;
  end if;
  if r.contact_email is distinct from 'marta@c211.com' then
    raise exception 'FALLO 4: el correo de la sede no volvio: %', r.contact_email;
  end if;
  if r.contact_phone is distinct from '6011234567' then
    raise exception 'FALLO 4b: el telefono no volvio: %', r.contact_phone;
  end if;
  if r.whatsapp is distinct from '3001234567' then
    raise exception 'FALLO 4c: el whatsapp no volvio: %', r.whatsapp;
  end if;
  if r.address is distinct from 'Calle 123 #45-67' then
    raise exception 'FALLO 4d: la direccion no volvio: %', r.address;
  end if;
  if r.city is distinct from 'Bogota' then
    raise exception 'FALLO 4e: la ciudad no volvio: %', r.city;
  end if;
  if r.department is distinct from 'Cundinamarca' then
    raise exception 'FALLO 4f: el departamento no volvio: %', r.department;
  end if;
  raise notice 'OK 3-4 los siete campos se escriben y el lector los devuelve';

  -- 5. LA IMPORTANTE: escribir vacio VACIA, no conserva.
  --
  -- D-241 eligio esta semantica a proposito. Si alguien mete un
  -- `coalesce(p_x, x)` "para no perder datos", la funcion volveria a saber
  -- poner y cambiar pero no quitar -- exactamente el fallo de D-237, que
  -- costo dos migraciones y lo encontro el propietario, no un control.
  perform public.platform_update_branch_info(
    v_sede, 'Marta Encargada', null, null, null, null, null, null
  );

  select * into r from public.platform_get_tenant_branches(v_tenant) limit 1;

  if r.contact_email is not null then
    raise exception 'FALLO 5: se mando el correo vacio y lo CONSERVO (%). Alguien puso un coalesce y la funcion ya no sabe quitar (D-237, D-241).', r.contact_email;
  end if;
  if r.address is not null then
    raise exception 'FALLO 5b: se mando la direccion vacia y la conservo: %', r.address;
  end if;
  if r.manager_name is distinct from 'Marta Encargada' then
    raise exception 'FALLO 5c: se vacio un campo que SI se mando con valor';
  end if;
  raise notice 'OK 5   escribir vacio vacia, y lo que se manda con valor se respeta';

  -- 6. Un correo sin arroba se rechaza
  v_capturo := false;
  begin
    perform public.platform_update_branch_info(
      v_sede, null, 'esto-no-es-un-correo', null, null, null, null, null
    );
  exception when others then
    v_capturo := true;
    v_error := sqlerrm;
  end;
  if not v_capturo then
    raise exception 'FALLO 6: guardo un correo sin arroba. Es por donde se le escribe a quien atiende la sede, y roto no se nota hasta el dia que hace falta.';
  end if;
  if v_error not like '%correo%' then
    raise exception 'FALLO 6b: se rechazo, pero el mensaje no dice que es el correo: %', v_error;
  end if;
  raise notice 'OK 6   un correo sin arroba se rechaza, y el mensaje lo explica';

  -- 7. Sin rol de plataforma, se rechaza
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_ajeno::text, 'role', 'authenticated')::text, true);
  v_capturo := false;
  begin
    perform public.platform_update_branch_info(
      v_sede, 'Intruso', null, null, null, null, null, null
    );
  exception when others then
    v_capturo := true;
    v_error := sqlerrm;
  end;
  if not v_capturo then
    raise exception 'FALLO 7: un usuario sin rol de plataforma escribio los datos de la sede de un cliente';
  end if;
  if v_error not like '%plataforma%' then
    raise exception 'FALLO 7b: se rechazo, pero el mensaje no dice por que: %', v_error;
  end if;
  raise notice 'OK 7   sin rol de plataforma se rechaza, y el mensaje lo explica';

  -- 8. Una sede que no existe se rechaza en vez de callarse
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_owner::text, 'role', 'authenticated')::text, true);
  v_capturo := false;
  begin
    perform public.platform_update_branch_info(
      gen_random_uuid(), 'Fantasma', null, null, null, null, null, null
    );
  exception when others then
    v_capturo := true;
  end;
  if not v_capturo then
    raise exception 'FALLO 8: acepto escribir sobre una sede inexistente y no dijo nada. Un update que no encuentra fila se ve igual que uno que funciono.';
  end if;
  raise notice 'OK 8   una sede inexistente se rechaza en vez de callarse';

  -- 9. anon no la alcanza
  if has_function_privilege('anon',
       'public.platform_update_branch_info(uuid, text, text, text, text, text, text, text)',
       'execute') then
    raise exception 'FALLO 9: anon puede escribir los datos de una sede';
  end if;
  raise notice 'OK 9   anon no alcanza la funcion de escritura';

  raise notice '---------------------------------------------';
  raise notice 'CONTROL 211 COMPLETO: 9 de 9 en verde.';
end
$ctrl$;

rollback;
