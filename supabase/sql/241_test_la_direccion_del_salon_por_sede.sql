-- CONTROL 241: la dirección pública del salón, a partir de una sede (D-313).
--
-- POR QUÉ ESTE ARCHIVO
--
-- La estilista no podía leer la dirección de su salón: la tabla `tenants`
-- pasa por una política que consulta `tenant_memberships`, que nadie con
-- sesión puede leer (lectura del 03-oct). La función nueva
-- `public_get_salon_slug_by_branch` la da a partir de la sede. Este control
-- comprueba que la da, que no la da de lo inactivo, y que la pueden usar
-- quien no tiene sesión y quien sí la tiene (la lección de CE, D-307).
--
-- Que valida, transaccionalmente:
--   1. Sede activa de un negocio activo con dirección: devuelve la dirección.
--   2. Sede inactiva: NULL.
--   3. Negocio inactivo: NULL.
--   4. Sin sesión (`anon`): funciona.
--   5. Con sesión de alguien de OTRO negocio (`authenticated`): funciona, sin
--      el "permission denied" que tumbó la lectura directa.
--   6. Devuelve solo texto, y es SECURITY DEFINER (lee como dueña de la base,
--      no como quien llama).
--
-- COMO SE EJECUTA (despues de aplicar 20261003150000_la_direccion_del_salon_por_sede_d313.sql)
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\241_test_la_direccion_del_salon_por_sede.sql"
--
-- TERMINA EN ROLLBACK.
--
-- Datos de prueba copiados de controles que pasaron (regla 25d): el negocio y
-- sus sedes, del 224 (23-sep); el cambio de rol, del 231 (30-sep).

set client_encoding = 'UTF8';

begin;

do $ctrl$
declare
  v_activo     uuid;
  v_inactivo   uuid;
  v_sede       uuid;
  v_sede_off   uuid;
  v_sede_neg   uuid;
  v_dir        text;
  v_capturo    boolean;
  v_error      text;
  r            record;
begin
  -- ---------------------------------------------------------------- fixtures
  insert into public.tenants (name, business_type, contact_email, whatsapp, active, slug)
  values ('Control 241', 'peluqueria', 'c241@salonymas.com', '3000000241', true, 'control-241-salon')
  returning id into v_activo;
  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_activo, 'C241 sede', 'c241-sede', true, true)
  returning id into v_sede;
  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_activo, 'C241 sede cerrada', 'c241-sede-cerrada', false, false)
  returning id into v_sede_off;

  insert into public.tenants (name, business_type, contact_email, whatsapp, active, slug)
  values ('Control 241 inactivo', 'peluqueria', 'c241b@salonymas.com', '3000000242', false, 'control-241-inactivo')
  returning id into v_inactivo;
  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_inactivo, 'C241 sede del inactivo', 'c241-sede-inactivo', true, true)
  returning id into v_sede_neg;

  -- 1. Lo activo da la dirección
  v_dir := public.public_get_salon_slug_by_branch(v_sede);
  if v_dir is distinct from 'control-241-salon' then
    raise exception 'FALLO 1: la sede activa dio "%" y debia dar control-241-salon', v_dir;
  end if;
  raise notice 'OK 1   una sede activa de un negocio activo da la direccion del salon';

  -- 2. Sede inactiva: nada
  v_dir := public.public_get_salon_slug_by_branch(v_sede_off);
  if v_dir is not null then
    raise exception 'FALLO 2: una sede inactiva dio "%"', v_dir;
  end if;
  raise notice 'OK 2   una sede inactiva no da direccion';

  -- 3. Negocio inactivo: nada
  v_dir := public.public_get_salon_slug_by_branch(v_sede_neg);
  if v_dir is not null then
    raise exception 'FALLO 3: la sede de un negocio inactivo dio "%"', v_dir;
  end if;
  raise notice 'OK 3   un negocio inactivo no da direccion';

  -- 4. Sin sesión
  v_capturo := false; v_dir := null;
  begin
    perform set_config('request.jwt.claims', '{"role":"anon"}', true);
    execute 'set local role anon';
    v_dir := public.public_get_salon_slug_by_branch(v_sede);
    execute 'reset role';
  exception when others then
    v_capturo := true; v_error := sqlerrm;
    execute 'reset role';
  end;
  if v_capturo or v_dir is distinct from 'control-241-salon' then
    raise exception 'FALLO 4: sin sesion, capturo=% error=% dio=%', v_capturo, v_error, v_dir;
  end if;
  raise notice 'OK 4   sin sesion funciona';

  -- 5. Con sesión de alguien de otro negocio
  v_capturo := false; v_dir := null;
  begin
    perform set_config('request.jwt.claims',
      json_build_object('sub', gen_random_uuid()::text, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    v_dir := public.public_get_salon_slug_by_branch(v_sede);
    execute 'reset role';
  exception when others then
    v_capturo := true; v_error := sqlerrm;
    execute 'reset role';
  end;
  if v_capturo or v_dir is distinct from 'control-241-salon' then
    raise exception 'FALLO 5: con sesion, capturo=% error=% dio=%', v_capturo, v_error, v_dir;
  end if;
  raise notice 'OK 5   con sesion funciona, sin el permission denied de la lectura directa';

  -- 6. Solo texto, y security definer
  select p.prorettype::regtype::text as tipo, p.prosecdef as definer into r
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'public_get_salon_slug_by_branch';
  if r.tipo <> 'text' or not r.definer then
    raise exception 'FALLO 6: devuelve % y security definer=%', r.tipo, r.definer;
  end if;
  raise notice 'OK 6   devuelve solo texto y lee como duena de la base';

  perform set_config('request.jwt.claims', '{}', true);
  raise notice '--- CONTROL 241: 6/6 ---';
end
$ctrl$;

rollback;
