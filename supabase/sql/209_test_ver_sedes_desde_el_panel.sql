-- CONTROL 209: El Panel ve el estado de cada sede (D-235, paso 9.35).
--
-- POR QUE ESTE ARCHIVO
--
-- Existia `platform_set_branch_subscription` para ESCRIBIR el estado de una
-- sede, y ninguna funcion para LEERLO: se podia cambiar a ciegas lo que no se
-- podia consultar. `platform_get_tenant_branches` cierra ese hueco.
--
-- Lo que mas importa vigilar aqui no es que devuelva filas, sino:
--   * que **solo** la alcance el rol de plataforma, porque `security definer`
--     le deja saltarse el aislamiento por tenant, y
--   * que calcule "al dia" **igual** que `get_branch_subscriptions`, la que ve
--     el salon. Si las dos difirieran, una conversacion de soporte se volveria
--     imposible: cada lado del telefono veria una cosa.
--
-- Que valida, transaccionalmente:
--   1. La funcion existe y es SECURITY DEFINER.
--   2. Devuelve TODAS las sedes del negocio, con la principal primero.
--   3. "al dia" no es lo mismo que "activa": una sede cerrada pero pagada sale
--      al dia, y una abierta sin pagar sale en mora.
--   4. Un usuario SIN rol de plataforma es rechazado.
--   5. `anon` no tiene permiso de ejecucion.
--   6. No se cuelan sedes de otro negocio.
--
-- COMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\209_test_ver_sedes_desde_el_panel.sql"
--
-- TERMINA EN ROLLBACK. Todos los datos de prueba se descartan limpiamente.
--
-- NOTA para quien anada fixtures: `branches.slug` es NOT NULL sin default y
-- unico por negocio, y un disparador (`branches_crear_suscripcion`, D-190) ya
-- le crea su suscripcion `pending` a cada sede. Por eso se usa
-- `on conflict (branch_id) do update`. Las dos cosas costaron una corrida cada
-- una en el control 208.

begin;

do $ctrl$
declare
  v_owner    uuid := gen_random_uuid();
  v_ajeno    uuid := gen_random_uuid();
  v_plan     uuid;
  v_tenant   uuid;
  v_otro     uuid;
  v_sede_a   uuid;
  v_sede_b   uuid;
  v_sede_c   uuid;
  v_sede_x   uuid;
  v_def      text;
  v_filas    int;
  v_primera  text;
  v_capturo  boolean;
  v_error    text;
  r          record;
begin
  -- 1. La funcion existe y esta blindada
  select pg_get_functiondef(p.oid) into v_def
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'platform_get_tenant_branches';

  if v_def is null then
    raise exception 'FALLO 1: public.platform_get_tenant_branches no existe';
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

  insert into auth.users (id, email) values
    (v_owner, 'owner_test209@salonymas.com'),
    (v_ajeno, 'ajeno_test209@salonymas.com')
  on conflict (id) do nothing;

  insert into public.platform_operators (user_id, role, active)
  values (v_owner, 'platform_owner', true)
  on conflict (user_id) do update set role = excluded.role, active = true;

  insert into public.tenants (name, business_type, contact_email, whatsapp, is_demo, active)
  values ('Control 209', 'barberia', 'c209@salonymas.com', '3000000210', true, true)
  returning id into v_tenant;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_tenant, v_plan, 'active', now() + interval '30 days');

  -- Tres sedes que cubren los tres casos que importan.
  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C209 principal', 'c209-principal', true, true) returning id into v_sede_a;
  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C209 sin pagar', 'c209-sin-pagar', false, true) returning id into v_sede_b;
  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C209 cerrada pagada', 'c209-cerrada', false, false) returning id into v_sede_c;

  insert into public.branch_subscriptions
    (tenant_id, branch_id, status, price_cop, price_reason, current_period_end)
  values
    (v_tenant, v_sede_a, 'active',  50000, 'Control 209', now() + interval '30 days'),
    (v_tenant, v_sede_b, 'pending', null,  null,          null),
    (v_tenant, v_sede_c, 'active',  50000, 'Control 209', now() + interval '30 days')
  on conflict (branch_id) do update set
    status = excluded.status,
    price_cop = excluded.price_cop,
    price_reason = excluded.price_reason,
    current_period_end = excluded.current_period_end;

  -- Un negocio ajeno, para comprobar que no se cuela.
  insert into public.tenants (name, business_type, contact_email, whatsapp, is_demo, active)
  values ('Control 209 ajeno', 'barberia', 'c209x@salonymas.com', '3000000211', true, true)
  returning id into v_otro;
  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_otro, v_plan, 'active', now() + interval '30 days');
  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_otro, 'C209 ajena', 'c209-ajena', true, true) returning id into v_sede_x;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_owner::text, 'role', 'authenticated')::text, true);

  -- 2. Devuelve las tres, con la principal primero
  select count(*) into v_filas
  from public.platform_get_tenant_branches(v_tenant);
  if v_filas <> 3 then
    raise exception 'FALLO 2: devolvio % sedes y el negocio tiene 3', v_filas;
  end if;

  select branch_name into v_primera
  from public.platform_get_tenant_branches(v_tenant) limit 1;
  if v_primera <> 'C209 principal' then
    raise exception 'FALLO 2b: la primera fila es "%" y deberia ser la sede principal', v_primera;
  end if;
  raise notice 'OK 2   devuelve las 3 sedes, con la principal primero';

  -- 3. "al dia" no es lo mismo que "activa"
  for r in select * from public.platform_get_tenant_branches(v_tenant) loop
    if r.branch_name = 'C209 sin pagar' and r.al_dia then
      raise exception 'FALLO 3: una sede en pending sale como al dia';
    end if;
    if r.branch_name = 'C209 cerrada pagada' and not r.al_dia then
      raise exception 'FALLO 3b: una sede cerrada PERO pagada deberia salir al dia. Al dia y activa no son lo mismo';
    end if;
    if r.branch_name = 'C209 cerrada pagada' and r.branch_active then
      raise exception 'FALLO 3c: la sede cerrada sale como activa';
    end if;
    if r.branch_name = 'C209 sin pagar' and r.motivo_precio is distinct from 'Precio de lista' then
      raise exception 'FALLO 3d: una sede sin precio pactado deberia caer al de lista, y dice "%"', r.motivo_precio;
    end if;
  end loop;
  raise notice 'OK 3   al dia y activa se distinguen, y sin precio pactado cae al de lista';

  -- 6. No se cuelan sedes de otro negocio
  for r in select * from public.platform_get_tenant_branches(v_tenant) loop
    if r.branch_id = v_sede_x then
      raise exception 'FALLO 6: se colo una sede de otro negocio';
    end if;
  end loop;
  raise notice 'OK 6   no se cuelan sedes de otro negocio';

  -- 4. Sin rol de plataforma, se rechaza
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_ajeno::text, 'role', 'authenticated')::text, true);
  v_capturo := false;
  begin
    perform * from public.platform_get_tenant_branches(v_tenant);
  exception when others then
    v_capturo := true;
    v_error := sqlerrm;
  end;
  if not v_capturo then
    raise exception 'FALLO 4: un usuario sin rol de plataforma pudo leer las sedes de un negocio ajeno';
  end if;
  if v_error not like '%plataforma%' then
    raise exception 'FALLO 4b: se rechazo, pero el mensaje no dice por que: %', v_error;
  end if;
  raise notice 'OK 4   sin rol de plataforma se rechaza, y el mensaje lo explica';

  -- 5. anon no la alcanza
  if has_function_privilege('anon',
       'public.platform_get_tenant_branches(uuid)', 'execute') then
    raise exception 'FALLO 5: anon puede ejecutar la funcion';
  end if;
  raise notice 'OK 5   anon no alcanza la funcion';

  raise notice '---------------------------------------------';
  raise notice 'CONTROL 209 COMPLETO: 6 de 6 en verde.';
end
$ctrl$;

rollback;
