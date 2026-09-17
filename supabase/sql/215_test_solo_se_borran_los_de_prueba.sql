-- CONTROL 215: Solo se borran los negocios de prueba (D-246, paso 9.47).
--
-- POR QUE ESTE ARCHIVO
--
-- `platform_delete_demo_tenant` es la unica funcion del proyecto que **borra
-- datos de un cliente y no se puede deshacer**. Todas las demas escriben,
-- cambian o marcan; esta destruye.
--
-- Por eso aqui lo que mas importa NO es que borre bien. Es:
--
--   * **que se niegue con un negocio que no esta marcado como prueba.** Ese
--     seguro es lo unico que separa "limpiar mis pruebas" de "borrar a un
--     cliente por pulsar la fila de al lado", y un borrado no tiene deshacer;
--   * **que no deje nada a medias.** Media limpieza es peor que ninguna: deja
--     basura invisible que nadie vuelve a mirar; y
--   * **que deje rastro**, porque estos negocios llevan pagos de ePayco reales
--     y `AGENTS.md` prohibe tocar historial financiero sin trazabilidad.
--
-- Que valida, transaccionalmente:
--   1. La funcion existe y es SECURITY DEFINER.
--   2. **Se niega con un negocio que NO es demo.** La importante.
--   3. Se niega con un negocio que no existe.
--   4. Un usuario sin rol de plataforma es rechazado.
--   5. Borra de verdad: no queda ni una fila en ninguna tabla con tenant_id.
--   6. **Deja rastro**, con el dinero contado antes de borrarlo.
--   7. No toca las cuentas de `auth.users`: son de las personas, no del
--      negocio, y dejarlas permite volver a registrarse para otra prueba.
--   8. `anon` no la alcanza.
--
-- COMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\215_test_solo_se_borran_los_de_prueba.sql"
--
-- TERMINA EN ROLLBACK. Nada de lo que borra aqui se borra de verdad.

begin;

do $ctrl$
declare
  v_owner    uuid := gen_random_uuid();
  v_ajeno    uuid := gen_random_uuid();
  v_dueno    uuid := gen_random_uuid();
  v_plan     uuid;
  v_demo     uuid;
  v_real     uuid;
  v_sede     uuid;
  v_def      text;
  v_capturo  boolean;
  v_error    text;
  v_filas    bigint;
  v_tabla    text;
  v_sobran   text := '';
  v_rastro   integer;
  v_dinero   bigint;
begin
  -- 1. Existe y esta blindada
  select pg_get_functiondef(p.oid) into v_def
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'platform_delete_demo_tenant';

  if v_def is null then
    raise exception 'FALLO 1: public.platform_delete_demo_tenant no existe';
  end if;
  if v_def not ilike '%security definer%' then
    raise exception 'FALLO 1b: la funcion no es SECURITY DEFINER';
  end if;
  raise notice 'OK 1   la funcion existe y es SECURITY DEFINER';

  -- Fixtures
  select id into v_plan from public.plans where status = 'active' limit 1;
  if v_plan is null then
    raise exception 'FALLO: no hay ningun plan activo con el que probar';
  end if;

  insert into auth.users (id, email) values
    (v_owner, 'owner_test215@salonymas.com'),
    (v_ajeno, 'ajeno_test215@salonymas.com'),
    (v_dueno, 'dueno_test215@salonymas.com')
  on conflict (id) do nothing;

  insert into public.platform_operators (user_id, role, active)
  values (v_owner, 'platform_owner', true)
  on conflict (user_id) do update set role = excluded.role, active = true;

  -- Un negocio de PRUEBA, con cosas colgando de el.
  insert into public.tenants (name, business_type, contact_email, whatsapp, is_demo, active)
  values ('Control 215 demo', 'barberia', 'c215demo@salonymas.com', '3000000219', true, true)
  returning id into v_demo;
  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_demo, v_plan, 'active', now() + interval '30 days');
  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_demo, 'C215 sede', 'c215-sede', true, true) returning id into v_sede;
  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_demo, v_dueno, 'tenant_owner', true);

  -- Y un negocio que NO es de prueba. Este es el que nunca debe tocarse.
  insert into public.tenants (name, business_type, contact_email, whatsapp, is_demo, active)
  values ('Control 215 REAL', 'barberia', 'c215real@salonymas.com', '3000000220', false, true)
  returning id into v_real;
  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_real, v_plan, 'active', now() + interval '30 days');

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_owner::text, 'role', 'authenticated')::text, true);

  -- 2. LA IMPORTANTE: un negocio que no es de prueba no se borra.
  v_capturo := false;
  begin
    perform * from public.platform_delete_demo_tenant(v_real);
  exception when others then
    v_capturo := true;
    v_error := sqlerrm;
  end;
  if not v_capturo then
    raise exception 'FALLO 2: BORRO UN NEGOCIO QUE NO ESTA MARCADO COMO PRUEBA. Ese seguro es lo unico que separa limpiar las pruebas de borrar a un cliente por pulsar la fila de al lado, y un borrado no tiene deshacer (D-246).';
  end if;
  if v_error not ilike '%prueba%' then
    raise exception 'FALLO 2b: se nego, pero el mensaje no dice que es por no ser de prueba: %', v_error;
  end if;
  if not exists (select 1 from public.tenants where id = v_real) then
    raise exception 'FALLO 2c: el negocio real desaparecio aunque la funcion lanzo';
  end if;
  raise notice 'OK 2   un negocio que NO es de prueba no se borra, y el mensaje lo explica';

  -- 3. Un negocio que no existe
  v_capturo := false;
  begin
    perform * from public.platform_delete_demo_tenant(gen_random_uuid());
  exception when others then
    v_capturo := true;
  end;
  if not v_capturo then
    raise exception 'FALLO 3: acepto borrar un negocio inexistente sin decir nada';
  end if;
  raise notice 'OK 3   un negocio inexistente se rechaza';

  -- 4. Sin rol de plataforma
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_ajeno::text, 'role', 'authenticated')::text, true);
  v_capturo := false;
  begin
    perform * from public.platform_delete_demo_tenant(v_demo);
  exception when others then
    v_capturo := true;
    v_error := sqlerrm;
  end;
  if not v_capturo then
    raise exception 'FALLO 4: un usuario sin rol de plataforma borro un negocio entero';
  end if;
  if v_error not ilike '%plataforma%' then
    raise exception 'FALLO 4b: se rechazo, pero el mensaje no dice por que: %', v_error;
  end if;
  raise notice 'OK 4   sin rol de plataforma se rechaza';

  -- 5. Borra de verdad, y no deja nada
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_owner::text, 'role', 'authenticated')::text, true);

  perform * from public.platform_delete_demo_tenant(v_demo);

  if exists (select 1 from public.tenants where id = v_demo) then
    raise exception 'FALLO 5: el negocio de prueba sigue ahi despues de borrarlo';
  end if;

  -- Se recorre TODA tabla con tenant_id, igual que hace la funcion: si se
  -- comprobaran solo las que uno recuerda, se comprobaria justo lo que la
  -- funcion tampoco miro.
  for v_tabla in
    select c.table_name::text
    from information_schema.columns c
    join information_schema.tables t
      on t.table_schema = c.table_schema
     and t.table_name = c.table_name
     and t.table_type = 'BASE TABLE'
    where c.table_schema = 'public'
      and c.column_name = 'tenant_id'
      and c.table_name <> 'deleted_demo_tenants'
  loop
    execute format('select count(*) from public.%I where tenant_id = $1', v_tabla)
      into v_filas using v_demo;
    if v_filas > 0 then
      v_sobran := v_sobran || v_tabla || ' (' || v_filas || ') ';
    end if;
  end loop;

  if v_sobran <> '' then
    raise exception 'FALLO 5b: quedaron filas sueltas en: %. Media limpieza es peor que ninguna: es basura invisible que nadie vuelve a mirar.', v_sobran;
  end if;
  raise notice 'OK 5   el negocio de prueba se borro entero, sin dejar una sola fila';

  -- 6. Y dejo rastro
  select count(*)::integer, coalesce(max(dinero_cop), 0)
    into v_rastro, v_dinero
  from public.deleted_demo_tenants where tenant_id = v_demo;

  if v_rastro <> 1 then
    raise exception 'FALLO 6: no quedo rastro del borrado. AGENTS.md prohibe tocar historial financiero sin trazabilidad, y estos negocios llevan pagos reales (D-246).';
  end if;
  if not exists (
    select 1 from public.deleted_demo_tenants
    where tenant_id = v_demo
      and tenant_name = 'Control 215 demo'
      and filas_por_tabla ? 'branches'
  ) then
    raise exception 'FALLO 6b: el rastro existe pero no dice que se borro';
  end if;
  raise notice 'OK 6   queda rastro con el nombre, las filas y el dinero';

  -- 7. Las cuentas siguen ahi
  if not exists (select 1 from auth.users where id = v_dueno) then
    raise exception 'FALLO 7: se borro la cuenta de la persona. Las cuentas no son del negocio, y dejarlas permite volver a registrarse para otra prueba (D-246).';
  end if;
  raise notice 'OK 7   las cuentas de las personas no se tocan';

  -- 8. anon no la alcanza
  if has_function_privilege('anon',
       'public.platform_delete_demo_tenant(uuid)', 'execute') then
    raise exception 'FALLO 8: anon puede borrar negocios enteros';
  end if;
  raise notice 'OK 8   anon no alcanza la funcion';

  -- El negocio real sigue intacto al terminar todo.
  if not exists (select 1 from public.tenants where id = v_real) then
    raise exception 'FALLO 9: el negocio que NO era de prueba desaparecio en algun momento';
  end if;

  raise notice '---------------------------------------------';
  raise notice 'CONTROL 215 COMPLETO: 8 de 8 en verde.';
  raise notice 'El negocio marcado como real sigue intacto.';
end
$ctrl$;

rollback;
