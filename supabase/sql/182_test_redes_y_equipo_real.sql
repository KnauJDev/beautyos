-- ============================================================================
-- CONTROL 182: TEST REDES SOCIALES Y CAPACIDAD OPERATIVA REAL (D-162)
-- Valida update_tenant_contact_info con Instagram/Facebook, y que
-- platform_list_tenants() calcule sedes activas y equipo activo (con
-- desglose por rol y pluralización) desde datos reales, excluyendo
-- filas inactivas.
-- ============================================================================

begin;

do $$
declare
  v_platform_owner_id uuid := '00000000-0000-0000-0000-000000000184';
  v_owner_id uuid := '00000000-0000-0000-0000-000000000185';
  v_tenant_id uuid;
  v_plan_id uuid;
  v_row record;
  v_admin1_id uuid := gen_random_uuid();
  v_admin2_id uuid := gen_random_uuid();
  v_assistant_id uuid := gen_random_uuid();
  v_stylist1_id uuid := gen_random_uuid();
  v_stylist2_id uuid := gen_random_uuid();
  v_stylist3_id uuid := gen_random_uuid();
  v_stylist_inactivo_id uuid := gen_random_uuid();
begin
  raise notice 'Control 182: Iniciando pruebas de redes sociales y equipo real...';

  -- 1. Setup: platform_owner de prueba.
  insert into auth.users (id, email)
  values (v_platform_owner_id, 'platform_owner_test182@salonymas.com')
  on conflict (id) do nothing;

  insert into public.platform_operators (user_id, role, active)
  values (v_platform_owner_id, 'platform_owner', true)
  on conflict (user_id) do update set role = 'platform_owner', active = true;

  select id into v_plan_id from public.plans where code = 'profesional' and status = 'active';
  if v_plan_id is null then
    raise exception 'No se encontró el plan profesional activo.';
  end if;

  -- 2. Tenant de prueba con equipo mixto (activos e inactivos) y sedes
  -- mixtas (activas e inactivas), para probar que solo cuenta lo activo.
  insert into public.tenants (name, business_type, contact_email, contact_phone, whatsapp, is_demo, active)
  values ('Salon Prueba Equipo Real', 'peluqueria', 'equipo@gmail.com', '3000000010', '3000000011', false, true)
  returning id into v_tenant_id;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, is_founder, trial_ends_at)
  values (v_tenant_id, v_plan_id, 'trialing', false, now() + interval '15 days');

  -- Sedes: 2 activas, 1 inactiva (no debe contar).
  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values
    (v_tenant_id, 'Sede Principal', 'sede-principal-182', true, true),
    (v_tenant_id, 'Sede Norte', 'sede-norte-182', false, true),
    (v_tenant_id, 'Sede Cerrada', 'sede-cerrada-182', false, false);

  -- Owner (autoservicio): 1 owner activo.
  insert into auth.users (id, email)
  values (v_owner_id, 'owner_test182@salonymas.com')
  on conflict (id) do nothing;

  insert into public.user_profiles (tenant_id, user_id, full_name, role, active)
  values (v_tenant_id, v_owner_id, 'Titular Prueba 182', 'owner', true)
  on conflict (user_id) do update set tenant_id = v_tenant_id, full_name = 'Titular Prueba 182', active = true;

  insert into public.tenant_memberships (tenant_id, user_id, role, active, starts_at)
  values (v_tenant_id, v_owner_id, 'tenant_owner', true, now());

  -- Equipo restante: user_profiles.user_id exige auth.users(id) por FK, así
  -- que cada miembro necesita su propia fila mínima en auth.users.
  -- 2 admins activos, 1 asistente INACTIVO (no debe aparecer en el desglose),
  -- 3 estilistas activos, 1 estilista INACTIVO (no debe contar).
  insert into auth.users (id, email)
  values
    (v_admin1_id, 'admin1_test182@salonymas.com'),
    (v_admin2_id, 'admin2_test182@salonymas.com'),
    (v_assistant_id, 'asistente_test182@salonymas.com'),
    (v_stylist1_id, 'estilista1_test182@salonymas.com'),
    (v_stylist2_id, 'estilista2_test182@salonymas.com'),
    (v_stylist3_id, 'estilista3_test182@salonymas.com'),
    (v_stylist_inactivo_id, 'estilista_inactivo_test182@salonymas.com')
  on conflict (id) do nothing;

  insert into public.user_profiles (tenant_id, user_id, full_name, role, active)
  values
    (v_tenant_id, v_admin1_id, 'Admin Uno 182', 'admin', true),
    (v_tenant_id, v_admin2_id, 'Admin Dos 182', 'admin', true),
    (v_tenant_id, v_assistant_id, 'Asistente Inactivo 182', 'assistant', false),
    (v_tenant_id, v_stylist1_id, 'Estilista Uno 182', 'stylist', true),
    (v_tenant_id, v_stylist2_id, 'Estilista Dos 182', 'stylist', true),
    (v_tenant_id, v_stylist3_id, 'Estilista Tres 182', 'stylist', true),
    (v_tenant_id, v_stylist_inactivo_id, 'Estilista Inactivo 182', 'stylist', false);

  -- ---------------------------------------------------------------------
  -- PRUEBA 1: update_tenant_contact_info guarda Instagram y Facebook.
  -- ---------------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', v_owner_id::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', v_owner_id::text)::text, true);

  perform public.update_tenant_contact_info(
    'Titular Prueba 182', 'peluqueria', '3000000010', '3000000011',
    '@naguaradeunas', 'facebook.com/naguaradeunas'
  );

  perform 1 from public.tenants
  where id = v_tenant_id
    and instagram = '@naguaradeunas'
    and facebook = 'facebook.com/naguaradeunas';

  if not found then
    raise exception 'Fallo PRUEBA 1: instagram/facebook no quedaron guardados en tenants.';
  end if;

  raise notice 'Control 182: PRUEBA 1 (update_tenant_contact_info con redes sociales) EXITOSA.';

  -- ---------------------------------------------------------------------
  -- PRUEBA 2: platform_list_tenants() expone teléfono/redes y la capacidad
  -- operativa real (sedes activas, equipo activo con desglose y plural).
  -- ---------------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', v_platform_owner_id::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', v_platform_owner_id::text)::text, true);

  select * into v_row
  from public.platform_list_tenants()
  where tenant_id = v_tenant_id;

  if v_row.contact_phone is distinct from '3000000010' then
    raise exception 'Fallo PRUEBA 2: contact_phone no coincide (%)', v_row.contact_phone;
  end if;

  if v_row.instagram is distinct from '@naguaradeunas' or v_row.facebook is distinct from 'facebook.com/naguaradeunas' then
    raise exception 'Fallo PRUEBA 2: instagram/facebook no coinciden (%, %)', v_row.instagram, v_row.facebook;
  end if;

  if v_row.real_branches_count is distinct from 2 then
    raise exception 'Fallo PRUEBA 2: real_branches_count esperaba 2, llegó %', v_row.real_branches_count;
  end if;

  if v_row.real_team_count is distinct from 6 then
    raise exception 'Fallo PRUEBA 2: real_team_count esperaba 6 (1+2+3, sin contar inactivos), llegó %', v_row.real_team_count;
  end if;

  if v_row.team_breakdown is distinct from '1 dueño, 2 admins, 3 estilistas' then
    raise exception 'Fallo PRUEBA 2: team_breakdown esperaba "1 dueño, 2 admins, 3 estilistas" (sin asistentes, todos inactivos), llegó "%"', v_row.team_breakdown;
  end if;

  raise notice 'Control 182: PRUEBA 2 (platform_list_tenants con capacidad operativa real) EXITOSA.';

  raise notice 'Control 182: Todas las pruebas pasaron exitosamente en VERDE.';
end $$;

rollback;
