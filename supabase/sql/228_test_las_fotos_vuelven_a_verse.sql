-- CONTROL 228: Las fotos de soporte vuelven a verse, como decidio julio.
--              Hallazgo BC (D-076, D-274).
--
-- POR QUE ESTE ARCHIVO
--
-- `platform_get_tenant_work_photos` nunca supo que desde el 09-ago una foto
-- pendiente vive en el almacen privado, sin `photo_url`. Este control crea
-- una foto pendiente de verdad y comprueba que la RPC ya trae por donde
-- encontrarla, que el rol de plataforma sigue siendo obligatorio, y que la
-- politica del almacen privado quedo con la condicion nueva.
--
-- LO QUE NO PUEDE PROBAR, Y SE DICE (mismo criterio que el control 162): la
-- firma de la direccion temporal la hace el navegador con la sesion real de
-- quien la pide (`WorkPhotoStorage.firmar`, llamada al Storage API de
-- Supabase), y eso no se puede simular aqui sin esa sesion real. Es el
-- propietario quien lo comprueba en el Panel de plataforma (regla 21).
--
-- Que valida, transaccionalmente:
--   1. Un negocio con una foto PENDIENTE (almacen privado, sin photo_url).
--   2. Sin rol de plataforma, la RPC se sigue negando (no se ensancho de mas).
--   3. Con rol de plataforma, la RPC devuelve la foto CON su almacen y su
--      ruta, donde antes solo devolvia photo_url en null.
--   4. Una foto YA aprobada (publica) sigue trayendo su photo_url de siempre.
--   5. La politica del almacen privado quedo con la condicion nueva, y solo
--      esa: se compara su texto completo, no solo que contenga una palabra.
--
-- COMO SE EJECUTA (despues de aplicar 20260924100000_las_fotos_de_soporte_vuelven_a_verse_bc.sql)
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\228_test_las_fotos_vuelven_a_verse.sql"
--
-- TERMINA EN ROLLBACK.

begin;

do $ctrl$
declare
  v_plan        uuid;
  v_tenant      uuid;
  v_branch      uuid;
  v_dueno       uuid := gen_random_uuid();
  v_plataforma  uuid := gen_random_uuid();
  v_ajeno       uuid := gen_random_uuid();
  v_memb        uuid;
  v_pendiente   uuid;
  v_aprobada    uuid;
  v_bucket      text;
  v_ruta        text;
  v_photo_url   text;
  v_capturo     boolean;
  v_texto_politica text;
begin
  select id into v_plan from public.plans where status = 'active' limit 1;
  if v_plan is null then
    raise exception 'FALLO: no hay ningun plan activo con el que probar';
  end if;

  insert into auth.users (id, email) values
    (v_dueno, 'dueno_test228@salonymas.com'),
    (v_plataforma, 'plataforma_test228@salonymas.com'),
    (v_ajeno, 'ajeno_test228@salonymas.com')
  on conflict (id) do nothing;

  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 228', 'peluqueria', 'c228@salonymas.com', '3000000233', true)
  returning id into v_tenant;
  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_tenant, v_plan, 'active', now() + interval '30 days');
  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C228 sede', 'c228-sede', true, true)
  returning id into v_branch;

  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_dueno, 'tenant_owner', true)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);

  -- El rol de plataforma. Fixture copiado del control 221, que ya funciona:
  -- la tabla es platform_operators, no platform_admins.
  insert into public.platform_operators (user_id, role, active)
  values (v_plataforma, 'platform_owner', true)
  on conflict (user_id) do update set role = excluded.role, active = true;

  -- 1. Una foto PENDIENTE (almacen privado, sin photo_url) y una APROBADA
  -- (almacen publico, con photo_url), directo en la tabla: esta transaccion
  -- corre como el rol de conexion de aplicar_sql.ps1, que no esta sujeto a
  -- las politicas de RLS de public (son RPC-only, cero politicas).
  insert into public.work_photos (
    tenant_id, branch_id, photo_type, storage_bucket, storage_path, photo_url,
    visible_to_customer, approved_for_portfolio, active
  ) values (
    v_tenant, v_branch, 'before', 'work-photos-private',
    v_branch::text || '/control228-pendiente.jpg', null,
    false, false, true
  ) returning id into v_pendiente;

  insert into public.work_photos (
    tenant_id, branch_id, photo_type, storage_bucket, storage_path, photo_url,
    visible_to_customer, approved_for_portfolio, active
  ) values (
    v_tenant, v_branch, 'after', 'work-photos',
    v_branch::text || '/control228-aprobada.jpg',
    'https://eogppgbdnwxdtcbctaol.supabase.co/storage/v1/object/public/work-photos/'
      || v_branch::text || '/control228-aprobada.jpg',
    true, true, true
  ) returning id into v_aprobada;

  raise notice 'OK 1   una foto pendiente (almacen privado) y una aprobada (almacen publico)';

  -- 2. Sin rol de plataforma, la RPC se sigue negando
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_ajeno::text, 'role', 'authenticated')::text, true);
  v_capturo := false;
  begin
    perform 1 from public.platform_get_tenant_work_photos(v_tenant);
  exception when others then
    v_capturo := true;
  end;
  if not v_capturo then
    raise exception 'FALLO 2: alguien sin rol de plataforma pudo leer las fotos de otro negocio.';
  end if;
  raise notice 'OK 2   sin rol de plataforma, la RPC se sigue negando';

  -- 3. Con rol de plataforma, la pendiente trae almacen y ruta
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_plataforma::text, 'role', 'authenticated')::text, true);

  select storage_bucket, storage_path, photo_url
    into v_bucket, v_ruta, v_photo_url
  from public.platform_get_tenant_work_photos(v_tenant)
  where photo_id = v_pendiente;

  if v_bucket is distinct from 'work-photos-private' or v_ruta is distinct from (v_branch::text || '/control228-pendiente.jpg') then
    raise exception 'FALLO 3: la foto pendiente no trajo su almacen/ruta (almacen=%, ruta=%). Es exactamente lo que faltaba desde julio.', v_bucket, v_ruta;
  end if;
  if v_photo_url is not null then
    raise exception 'FALLO 3b: una foto pendiente trajo photo_url (%). No deberia tener direccion publica todavia.', v_photo_url;
  end if;
  raise notice 'OK 3   la foto pendiente ya trae su almacen y su ruta: se le puede pedir una direccion temporal';

  -- 4. La aprobada sigue trayendo su photo_url de siempre
  select photo_url into v_photo_url
  from public.platform_get_tenant_work_photos(v_tenant)
  where photo_id = v_aprobada;

  if v_photo_url is null or v_photo_url not like '%control228-aprobada.jpg' then
    raise exception 'FALLO 4: la foto ya aprobada dejo de traer su direccion publica.';
  end if;
  raise notice 'OK 4   una foto ya aprobada sigue trayendo su direccion publica de siempre';

  -- 5. La politica del almacen privado, texto completo
  select qual into v_texto_politica
  from pg_policies
  where schemaname = 'storage' and tablename = 'objects'
    and policyname = 'work_photos_private_select_staff';

  if v_texto_politica is distinct from
    '((bucket_id = ''work-photos-private''::text) AND (array_length(storage.foldername(name), 1) = 1) AND (private.beautyos_can_upload_work_photo(((storage.foldername(name))[1])::uuid) OR (private.beautyos_current_platform_role() IS NOT NULL)))'
  then
    raise exception 'FALLO 5: la politica del almacen privado no quedo con el texto esperado. Quedo: %', v_texto_politica;
  end if;
  raise notice 'OK 5   la politica del almacen privado gano la condicion de plataforma, y solo esa';

  raise notice '--- CONTROL 228: 5/5 ---';
  raise notice 'Falta lo que solo se ve en pantalla: Panel de plataforma -> Control 228 -> pestaña Fotos.';
end
$ctrl$;

rollback;
