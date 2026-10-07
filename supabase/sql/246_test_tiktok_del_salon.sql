-- CONTROL 246: TikTok en las redes del salón (D-319, 07-oct).
--
-- Que valida, transaccionalmente:
--   1. Existe `tenants.tiktok`, de texto.
--   2. El dueño lo guarda desde Configuración (con espacios alrededor, que se
--      quitan) y Configuración lo lee.
--   3. Una app VIEJA, que manda los seis datos de siempre, no lo borra.
--   4. Vacío lo borra.
--   5. La página pública lo enseña sin sesión, y con sesión de otro negocio.
--   6. Permisos iguales a los de antes: sin sesión no se guarda ni se lee
--      Configuración; la página sí. Y la firma vieja de seis ya no existe
--      (dos firmas harían dudar a la API sobre cuál llamar).
--
-- COMO SE EJECUTA (despues de aplicar 20261007200000_tiktok_del_salon_d319.sql)
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\246_test_tiktok_del_salon.sql"
--
-- TERMINA EN ROLLBACK.
--
-- Datos de prueba copiados del control 243 (dueño y administrador) y la
-- visita sin sesión del 241, que ya pasaron (regla 25d).

set client_encoding = 'UTF8';

begin;

do $ctrl$
declare
  v_plan    uuid;
  v_tenant  uuid;
  v_branch  uuid;
  v_memb    uuid;
  v_dueno   uuid := gen_random_uuid();
  v_admin   uuid := gen_random_uuid();
  v_tiktok  text;
  v_capturo boolean;
  v_error   text;
  r         record;
begin
  select id into v_plan from public.plans where status = 'active' limit 1;
  if v_plan is null then
    raise exception 'FALLO: no hay ningun plan activo con el que probar';
  end if;

  insert into auth.users (id, email) values
    (v_dueno, 'dueno_test246@salonymas.com'),
    (v_admin, 'admin_test246@salonymas.com')
  on conflict (id) do nothing;

  insert into public.tenants (name, business_type, contact_email, whatsapp, active, slug)
  values ('Control 246', 'peluqueria', 'c246@salonymas.com', '3000000246', true, 'control-246-salon')
  returning id into v_tenant;
  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_tenant, v_plan, 'active', now() + interval '30 days');
  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C246 sede', 'c246-sede', true, true)
  returning id into v_branch;

  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_dueno, 'tenant_owner', true)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);
  insert into public.user_profiles (tenant_id, user_id, full_name, role, active)
  values (v_tenant, v_dueno, 'C246 dueno', 'owner', true);

  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_admin, 'admin', true)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);
  insert into public.user_profiles (tenant_id, user_id, full_name, role, active)
  values (v_tenant, v_admin, 'C246 admin', 'admin', true);

  -- 1. La columna
  select c.data_type into r
  from information_schema.columns c
  where c.table_schema = 'public' and c.table_name = 'tenants' and c.column_name = 'tiktok';
  if r.data_type is distinct from 'text' then
    raise exception 'FALLO 1: tenants.tiktok no existe o no es texto (%)', r.data_type;
  end if;
  raise notice 'OK 1   existe tenants.tiktok, de texto';

  -- 2. El dueño lo guarda y Configuración lo lee
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);
  perform public.update_tenant_contact_info(
    'C246 dueno', 'peluqueria', null, '3000000246', '@ig246', null, '  @salon246  ');
  select s.tiktok into v_tiktok from public.get_business_settings() s;
  if v_tiktok is distinct from '@salon246' then
    raise exception 'FALLO 2: Configuracion leyo "%" y debia leer @salon246', v_tiktok;
  end if;
  raise notice 'OK 2   el dueno guarda su TikTok (sin espacios) y Configuracion lo lee';

  -- 3. Una app vieja (seis datos) no lo borra
  perform public.update_tenant_contact_info(
    'C246 dueno', 'peluqueria', null, '3000000246', '@ig246', null);
  select t.tiktok into v_tiktok from public.tenants t where t.id = v_tenant;
  if v_tiktok is distinct from '@salon246' then
    raise exception 'FALLO 3: una app vieja lo dejo en "%"', v_tiktok;
  end if;
  raise notice 'OK 3   una app vieja que manda los seis de siempre no lo borra';

  -- 4. Vacío lo borra
  perform public.update_tenant_contact_info(
    'C246 dueno', 'peluqueria', null, '3000000246', '@ig246', null, '');
  select t.tiktok into v_tiktok from public.tenants t where t.id = v_tenant;
  if v_tiktok is not null then
    raise exception 'FALLO 4: vacio lo dejo en "%"', v_tiktok;
  end if;
  raise notice 'OK 4   vacio lo borra';

  -- 5. La página pública lo enseña, sin sesión y con sesión de otro negocio
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_admin::text, 'role', 'authenticated')::text, true);
  perform public.update_tenant_contact_info(
    'C246 dueno', 'peluqueria', null, '3000000246', '@ig246', null, 'tiktok.com/@salon246');

  v_capturo := false; v_tiktok := null;
  begin
    perform set_config('request.jwt.claims', '{"role":"anon"}', true);
    execute 'set local role anon';
    select p.tiktok into v_tiktok from public.get_public_salon_by_slug('control-246-salon') p;
    execute 'reset role';
  exception when others then
    v_capturo := true; v_error := sqlerrm;
    execute 'reset role';
  end;
  if v_capturo or v_tiktok is distinct from 'tiktok.com/@salon246' then
    raise exception 'FALLO 5: sin sesion, capturo=% error=% dio=%', v_capturo, v_error, v_tiktok;
  end if;

  v_capturo := false; v_tiktok := null;
  begin
    perform set_config('request.jwt.claims',
      json_build_object('sub', gen_random_uuid()::text, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    select p.tiktok into v_tiktok from public.get_public_salon_by_slug('control-246-salon') p;
    execute 'reset role';
  exception when others then
    v_capturo := true; v_error := sqlerrm;
    execute 'reset role';
  end;
  if v_capturo or v_tiktok is distinct from 'tiktok.com/@salon246' then
    raise exception 'FALLO 5b: con sesion, capturo=% error=% dio=%', v_capturo, v_error, v_tiktok;
  end if;
  raise notice 'OK 5   el administrador tambien lo guarda, y la pagina lo ensena con y sin sesion';

  -- 6. Permisos, y la firma vieja ya no existe
  if has_function_privilege('anon',
       'public.update_tenant_contact_info(text, text, text, text, text, text, text)', 'execute')
     or has_function_privilege('anon', 'public.get_business_settings()', 'execute') then
    raise exception 'FALLO 6: sin sesion se puede guardar o leer Configuracion';
  end if;
  if not has_function_privilege('authenticated',
       'public.update_tenant_contact_info(text, text, text, text, text, text, text)', 'execute')
     or not has_function_privilege('authenticated', 'public.get_business_settings()', 'execute')
     or not has_function_privilege('anon', 'public.get_public_salon_by_slug(text)', 'execute')
     or not has_function_privilege('authenticated', 'public.get_public_salon_by_slug(text)', 'execute') then
    raise exception 'FALLO 6b: falta un permiso que antes estaba';
  end if;
  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'update_tenant_contact_info'
      and p.pronargs <> 7
  ) then
    raise exception 'FALLO 6c: quedo otra firma de update_tenant_contact_info';
  end if;
  raise notice 'OK 6   permisos iguales a los de antes, y una sola firma';

  perform set_config('request.jwt.claims', '{}', true);
  raise notice '--- CONTROL 246: 6/6 ---';
end
$ctrl$;

rollback;
