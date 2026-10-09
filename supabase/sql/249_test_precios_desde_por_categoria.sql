-- CONTROL 249: Precios "desde", por categoría (D-326).
--
-- Que valida, transaccionalmente:
--   1. Un negocio nace sin categorías "desde".
--   2. El dueño marca "Color": queda una sola vez, en minúsculas, aunque se
--      escriba " COLOR " o se marque dos veces.
--   3. Marcar otra ("Cortes") no borra la primera; desmarcar "Color" deja
--      solo "cortes"; desmarcar todo deja la lista vacía.
--   4. Sin sesión se LEE (la página pública la necesita), pero no se marca.
--   5. La recepción no marca (como update_service: dueño y administrador).
--   6. Una categoría vacía se niega.
--   7. Con la sede apagada, la lista no se entrega.
--
-- COMO SE EJECUTA (despues de aplicar 20261009100000_precios_desde_por_categoria_d326.sql)
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\249_test_precios_desde_por_categoria.sql"
--
-- TERMINA EN ROLLBACK.
--
-- Datos de prueba copiados del control 248 (08-oct), que ya pasó (regla
-- 25d): el negocio, su sede, el dueño y la recepción.

set client_encoding = 'UTF8';

begin;

do $ctrl$
declare
  v_plan      uuid;
  v_tenant    uuid;
  v_branch    uuid;
  v_cerrada   uuid;
  v_memb      uuid;
  v_dueno     uuid := gen_random_uuid();
  v_asistente uuid := gen_random_uuid();
  v_lista     text[];
  v_capturo   boolean;
  v_error     text;
begin
  -- ---------------------------------------------------------------- fixtures
  select id into v_plan from public.plans where status = 'active' limit 1;
  if v_plan is null then
    raise exception 'FALLO: no hay ningun plan activo con el que probar';
  end if;

  insert into auth.users (id, email) values
    (v_dueno, 'dueno_test249@salonymas.com'),
    (v_asistente, 'asistente_test249@salonymas.com')
  on conflict (id) do nothing;

  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 249', 'peluqueria', 'c249@salonymas.com', '3000000249', true)
  returning id into v_tenant;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_tenant, v_plan, 'active', now() + interval '30 days');

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C249 sede', 'c249-sede', true, true)
  returning id into v_branch;

  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_dueno, 'tenant_owner', true)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);
  insert into public.user_profiles (tenant_id, user_id, full_name, role, active)
  values (v_tenant, v_dueno, 'C249 dueno', 'owner', true);

  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_asistente, 'assistant', true)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);

  -- ---------------------------------------------------------------- 1
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);
  v_lista := public.get_price_from_categories(v_branch);
  if v_lista is distinct from '{}'::text[] then
    raise exception 'FALLO 1: el negocio no nacio sin categorias "desde" (%)', v_lista;
  end if;
  raise notice 'OK 1   el negocio nace sin categorias "desde"';

  -- ---------------------------------------------------------------- 2
  v_lista := public.set_price_from_category(v_branch, ' COLOR ', true);
  v_lista := public.set_price_from_category(v_branch, 'Color', true);
  if v_lista is distinct from array['color']::text[] then
    raise exception 'FALLO 2: marcar Color dos veces dio %', v_lista;
  end if;
  raise notice 'OK 2   "Color" queda una vez, en minusculas';

  -- ---------------------------------------------------------------- 3
  v_lista := public.set_price_from_category(v_branch, 'Cortes', true);
  if v_lista is distinct from array['color', 'cortes']::text[] then
    raise exception 'FALLO 3: marcar Cortes dio %', v_lista;
  end if;
  v_lista := public.set_price_from_category(v_branch, 'color', false);
  if v_lista is distinct from array['cortes']::text[] then
    raise exception 'FALLO 3b: desmarcar Color dio %', v_lista;
  end if;
  v_lista := public.set_price_from_category(v_branch, 'Cortes', false);
  if v_lista is distinct from '{}'::text[] then
    raise exception 'FALLO 3c: desmarcar todo dio %', v_lista;
  end if;
  v_lista := public.set_price_from_category(v_branch, 'Color', true);
  raise notice 'OK 3   marcar otra no borra la primera; desmarcar quita solo esa';

  -- ---------------------------------------------------------------- 4
  begin
    perform set_config('request.jwt.claims', '{"role":"anon"}', true);
    execute 'set local role anon';
    v_lista := public.get_price_from_categories(v_branch);
    execute 'reset role';
  exception when others then
    execute 'reset role';
    raise exception 'FALLO 4: sin sesion no se pudo leer la lista (%)', sqlerrm;
  end;
  if v_lista is distinct from array['color']::text[] then
    raise exception 'FALLO 4b: sin sesion se leyo %', v_lista;
  end if;

  v_capturo := false;
  begin
    execute 'set local role anon';
    perform public.set_price_from_category(v_branch, 'Cortes', true);
    execute 'reset role';
  exception when others then
    v_capturo := true; v_error := sqlerrm;
    execute 'reset role';
  end;
  if not v_capturo then
    raise exception 'FALLO 4c: sin sesion se pudo marcar una categoria';
  end if;
  raise notice 'OK 4   sin sesion se lee, pero no se marca (%)', v_error;

  -- ---------------------------------------------------------------- 5
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_asistente::text, 'role', 'authenticated')::text, true);
  v_capturo := false;
  begin
    perform public.set_price_from_category(v_branch, 'Cortes', true);
  exception when others then v_capturo := true;
  end;
  if not v_capturo then
    raise exception 'FALLO 5: la recepcion pudo marcar una categoria';
  end if;
  raise notice 'OK 5   la recepcion no marca';

  -- ---------------------------------------------------------------- 6
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);
  v_capturo := false;
  begin
    perform public.set_price_from_category(v_branch, '   ', true);
  exception when others then v_capturo := true; v_error := sqlerrm;
  end;
  if not v_capturo then
    raise exception 'FALLO 6: se acepto una categoria vacia';
  end if;
  raise notice 'OK 6   una categoria vacia se niega (%)', v_error;

  -- ---------------------------------------------------------------- 7
  -- Una segunda sede, creada ya cerrada (como en el control 241).
  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C249 sede cerrada', 'c249-sede-cerrada', false, false)
  returning id into v_cerrada;
  v_capturo := false;
  begin
    v_lista := public.get_price_from_categories(v_cerrada);
  exception when others then v_capturo := true;
  end;
  if not v_capturo then
    raise exception 'FALLO 7: con la sede apagada se entrego la lista (%)', v_lista;
  end if;
  raise notice 'OK 7   con la sede apagada no se entrega';

  perform set_config('request.jwt.claims', '{}', true);
  raise notice '--- CONTROL 249: 7/7 ---';
end
$ctrl$;

rollback;
