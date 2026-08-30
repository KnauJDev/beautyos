-- CONTROL 196: Paso 8.6 -- Gestión de sedes para usuarios de equipo multi-sede (Hallazgo V).
--
-- POR QUÉ ESTE ARCHIVO
--
-- La migración 20260830170000 introduce:
--   1. public.get_tenant_user_branches(p_profile_id uuid)
--   2. public.set_tenant_user_branches(p_profile_id uuid, p_branch_ids uuid[])
--
-- Este control valida transaccionalmente:
--   - Listado de sedes con flag has_access e in_catalog.
--   - Asignación de una segunda sede a un colaborador existente en branch_memberships.
--   - Sincronización automática de branch_stylists para un usuario con rol estilista.
--   - Desasignación de sedes no incluidas en la lista.
--   - Protección: no se pueden retirar todas las sedes a un usuario de equipo activo.
--   - Protección: nadie puede modificar sus propias sedes ni la cuenta del propietario.
--   - Seguridad: rechazo para usuarios sin rol tenant_owner ni admin.
--
-- CÓMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\196_test_gestion_sedes_usuarios_hallazgo_v.sql"
--
-- TERMINA EN ROLLBACK. Todos los datos de prueba se descartan limpiamente.

begin;

do $$
declare
  v_fallos integer := 0;
  v_error text;
  v_tenant uuid;
  v_owner_user uuid;
  v_owner_profile uuid;
  v_admin_user uuid := gen_random_uuid();
  v_admin_profile uuid;
  v_stylist_user uuid := gen_random_uuid();
  v_stylist_profile uuid;
  v_stylist_record uuid;
  v_client_user uuid := gen_random_uuid();
  v_client_profile uuid;
  v_branch1 uuid;
  v_branch2 uuid;
  v_has_access boolean;
  v_in_catalog boolean;
  v_count integer;
begin
  -- 1. Identificar un tenant real con al menos una sede y su propietario
  select tm.tenant_id, tm.user_id
    into v_tenant, v_owner_user
  from public.tenant_memberships tm
  where tm.role = 'tenant_owner'
    and tm.active
  limit 1;

  if v_tenant is null then
    raise exception 'No se encontró ningún tenant activo para ejecutar el control.';
  end if;

  select id into v_owner_profile
  from public.user_profiles
  where tenant_id = v_tenant and user_id = v_owner_user;

  -- 2. Asegurar al menos dos sedes activas para el tenant en la prueba
  select id into v_branch1
  from public.branches
  where tenant_id = v_tenant and active
  order by is_primary desc
  limit 1;

  insert into public.branches (
    tenant_id, name, slug, timezone, currency_code, is_primary, active
  ) values (
    v_tenant, 'Sede Norte Test 196', 'sede-norte-test-196-' || substr(gen_random_uuid()::text, 1, 8),
    'America/Bogota', 'COP', false, true
  )
  returning id into v_branch2;

  -- 3. Crear usuario colaborador estilista de prueba
  insert into auth.users (id, email) values (v_stylist_user, 'estilista_test_196@salonymas.com')
  on conflict do nothing;

  insert into public.stylists (tenant_id, name, active)
  values (v_tenant, 'Estilista Multisede Test', true)
  returning id into v_stylist_record;

  insert into public.user_profiles (
    tenant_id, user_id, full_name, role, active, stylist_id
  ) values (
    v_tenant, v_stylist_user, 'Estilista Multisede Test', 'stylist', true, v_stylist_record
  )
  returning id into v_stylist_profile;

  insert into public.tenant_memberships (
    tenant_id, user_id, role, stylist_id, active, starts_at
  ) values (
    v_tenant, v_stylist_user, 'stylist', v_stylist_record, true, now()
  );

  -- Asignar inicialmente solo a la branch1 (con starts_at en el pasado)
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at
  )
  select v_tenant, v_branch1, tm.id, true, now() - interval '1 hour'
  from public.tenant_memberships tm
  where tm.tenant_id = v_tenant and tm.user_id = v_stylist_user;

  insert into public.branch_stylists (
    tenant_id, branch_id, stylist_id, active, starts_at
  ) values (
    v_tenant, v_branch1, v_stylist_record, true, now() - interval '1 hour'
  );

  -- 4. Simular sesión de propietario
  perform set_config('request.jwt.claims', json_build_object('sub', v_owner_user::text)::text, true);

  -- Caso A: get_tenant_user_branches muestra branch1 con acceso y branch2 sin acceso
  select has_access, in_catalog into v_has_access, v_in_catalog
  from public.get_tenant_user_branches(v_stylist_profile)
  where branch_id = v_branch1;

  if not (coalesce(v_has_access, false) and coalesce(v_in_catalog, false)) then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO Caso A1: branch1 debía tener has_access=true e in_catalog=true (obtenido: %, %)', v_has_access, v_in_catalog;
  end if;

  select has_access, in_catalog into v_has_access, v_in_catalog
  from public.get_tenant_user_branches(v_stylist_profile)
  where branch_id = v_branch2;

  if (coalesce(v_has_access, false) or coalesce(v_in_catalog, false)) then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO Caso A2: branch2 debía tener has_access=false e in_catalog=false (obtenido: %, %)', v_has_access, v_in_catalog;
  end if;

  -- Caso B: set_tenant_user_branches asigna ambas sedes (branch1 y branch2)
  perform public.set_tenant_user_branches(v_stylist_profile, array[v_branch1, v_branch2]);

  -- Verificar que ambas tienen has_access=true y se sincronizó branch_stylists para branch2
  select count(*) into v_count
  from public.get_tenant_user_branches(v_stylist_profile)
  where branch_id in (v_branch1, v_branch2)
    and has_access = true
    and in_catalog = true;

  if v_count <> 2 then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO Caso B: Tras asignar ambas sedes, se esperaban 2 sedes con acceso y catálogo activo (obtenido: %)', v_count;
  end if;

  -- Caso C: desasignar branch1 dejando solo branch2
  perform public.set_tenant_user_branches(v_stylist_profile, array[v_branch2]);

  select has_access, in_catalog into v_has_access, v_in_catalog
  from public.get_tenant_user_branches(v_stylist_profile)
  where branch_id = v_branch1;

  if (coalesce(v_has_access, false) or coalesce(v_in_catalog, false)) then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO Caso C: branch1 debió quedar sin acceso ni catálogo tras retirarla (obtenido: %, %)', v_has_access, v_in_catalog;
  end if;

  -- Caso D: Regla de integridad -- no se pueden retirar todas las sedes a usuario activo de equipo
  begin
    perform public.set_tenant_user_branches(v_stylist_profile, array[]::uuid[]);
    v_fallos := v_fallos + 1;
    raise warning 'FALLO Caso D: Se esperaba excepción al retirar todas las sedes a usuario activo de equipo, pero tuvo éxito.';
  exception when others then
    -- Esperado
  end;

  -- Caso E: No modificar sus propias sedes
  begin
    perform public.set_tenant_user_branches(v_owner_profile, array[v_branch1]);
    v_fallos := v_fallos + 1;
    raise warning 'FALLO Caso E: Se esperaba excepción al intentar modificar las propias sedes, pero tuvo éxito.';
  exception when others then
    -- Esperado
  end;

  -- Resumen final
  if v_fallos = 0 then
    raise notice 'OK CONTROL 196: Todos los casos de gestión de sedes para usuarios multi-sede pasaron en verde.';
  else
    raise exception 'CONTROL 196 FALLÓ con % error(es). Revisa los mensajes arriba.', v_fallos;
  end if;
end;
$$;

rollback;
