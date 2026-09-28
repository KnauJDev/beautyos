-- CONTROL 235: Paso 9.48, Bloque 4 (D-288) -- la llave es de ella. Cierra AQ.
--
-- POR QUE ESTE ARCHIVO
--
-- Hasta hoy, quien subía la foto marcaba una casilla y el servidor guardaba
-- "la clienta autorizó". Desde D-288 el servidor ignora ese permiso: solo lo
-- da ella. Si esto se rompe, nada en pantalla lo delata -- la casilla ya no
-- existe --, pero cualquiera que llame a la función directamente volvería a
-- firmar por ella. Y el botón nuevo del WhatsApp entrega el celular de la
-- clienta: dueño, administrador o asistente (que ya lo ven en Clientes y
-- Tickets), nunca el estilista.
--
-- Datos de prueba copiados del control 230, que corrió en verde (regla 25 d).
--
-- COMO SE EJECUTA (después de aplicar
-- 20260928140000_la_llave_es_de_ella_9_48_b4.sql)
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\235_test_la_llave_es_de_ella_9_48_b4.sql"
--
-- TERMINA EN ROLLBACK. No deja ni una fila.

begin;

do $ctrl$
declare
  v_plan uuid;
  v_tenant uuid;
  v_branch uuid;
  v_service uuid;
  v_stylist uuid;
  v_dueno uuid := gen_random_uuid();
  v_estilista_cuenta uuid := gen_random_uuid();
  v_asistente uuid := gen_random_uuid();
  v_memb uuid;
  v_cliente1 uuid;
  v_cliente2 uuid;
  v_portal_token1 text := 'control235-portal-token-uno';
  v_portal_token2 text := 'control235-portal-token-dos';
  v_ticket1 uuid;
  v_ticket2 uuid;
  v_foto_dueno uuid;
  v_foto_estilista uuid;
  v_foto_vieja uuid;
  v_datos jsonb;
  v_fila record;
  v_capturo boolean;
  v_error text;
  v_fallos integer := 0;
begin
  select id into v_plan from public.plans where status = 'active' limit 1;
  if v_plan is null then
    raise exception 'FALLO: no hay ningun plan activo con el que probar';
  end if;

  insert into auth.users (id, email) values
    (v_dueno, 'dueno_test235@salonymas.com'),
    (v_estilista_cuenta, 'estilista_test235@salonymas.com')
  on conflict (id) do nothing;

  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 235', 'peluqueria', 'c235@salonymas.com', '3000000235', true)
  returning id into v_tenant;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_tenant, v_plan, 'active', now() + interval '30 days');

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C235 sede', 'c235-sede', true, true)
  returning id into v_branch;

  -- El dueño.
  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_dueno, 'tenant_owner', true)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);
  insert into public.user_profiles (tenant_id, user_id, full_name, role, active)
  values (v_tenant, v_dueno, 'C235 dueno', 'owner', true);

  insert into public.services (tenant_id, name, category, duration_minutes, price, visible_to_customer)
  values (v_tenant, 'C235 corte', 'Corte', 30, 50000, true)
  returning id into v_service;

  insert into public.stylists (tenant_id, name, phone, specialty)
  values (v_tenant, 'C235 estilista', '3000000235', 'Corte')
  returning id into v_stylist;

  -- El servicio y el estilista, dados de alta EN LA SEDE. Sin esto,
  -- ticket_services revienta: sus llaves apuntan a branch_services y a
  -- branch_stylists, no al catálogo (Tramo B). Copiado del control 218,
  -- que ya corrió en verde (regla 25 d) -- la primera versión de este
  -- control copió del 188, que usaba un negocio existente, y falló aquí.
  insert into public.branch_services (
    tenant_id, branch_id, service_id, price, duration_minutes, visible_to_customer, active
  ) values (v_tenant, v_branch, v_service, 50000, 30, true, true);
  insert into public.branch_stylists (tenant_id, branch_id, stylist_id, active, starts_at)
  values (v_tenant, v_branch, v_stylist, true, now() - interval '1 day');

  -- El estilista SÍ tiene cuenta -- para probar que no puede pedir la
  -- autorización por WhatsApp (caso 5), ni dar el permiso al subir (caso 2).
  insert into public.tenant_memberships (tenant_id, user_id, role, active, stylist_id)
  values (v_tenant, v_estilista_cuenta, 'stylist', true, v_stylist)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);
  insert into public.user_profiles (tenant_id, user_id, full_name, role, active, stylist_id)
  values (v_tenant, v_estilista_cuenta, 'C235 estilista cuenta', 'stylist', true, v_stylist);

  -- El asistente (decisión del propietario, 28-sep: también pide la
  -- autorización). Mismo alta que la del estilista, sin estilista.
  insert into auth.users (id, email) values (v_asistente, 'asistente_test235@salonymas.com')
  on conflict (id) do nothing;
  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_asistente, 'assistant', true)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);

  -- Dos clientas. La uno ya tiene sesión de portal abierta (D-167); la dos
  -- solo existe para probar que nadie decide por ella.
  insert into public.clients (tenant_id, name, phone, active, portal_session_token, portal_session_expires_at)
  values (v_tenant, 'C235 Clienta Uno', '3010000001', true, v_portal_token1, now() + interval '60 days')
  returning id into v_cliente1;

  insert into public.clients (tenant_id, name, phone, active, portal_session_token, portal_session_expires_at)
  values (v_tenant, 'C235 Clienta Dos', '3010000002', true, v_portal_token2, now() + interval '60 days')
  returning id into v_cliente2;

  -- Un ticket cerrado por clienta, con su servicio -- directo a las tablas,
  -- igual que el control 188 (no hace falta el flujo completo de reserva).
  insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at)
  values (v_tenant, v_branch, v_cliente1, 'cerrado', 'manual', now() - interval '2 days')
  returning id into v_ticket1;
  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant, v_branch, v_ticket1, v_service, v_stylist, 50000, 30, 'finalizado');

  insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at)
  values (v_tenant, v_branch, v_cliente2, 'cerrado', 'manual', now() - interval '3 days')
  returning id into v_ticket2;
  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant, v_branch, v_ticket2, v_service, v_stylist, 50000, 30, 'finalizado');

  -- ==========================================================================
  -- 1. El dueño sube una foto mandando el permiso en true: no se guarda.
  -- ==========================================================================
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);
  v_foto_dueno := public.create_work_photo(
    v_branch, v_ticket1, v_branch::text || '/control235-dueno.jpg', 'final', 'Dueno', v_stylist, true
  );
  if exists (
    select 1 from public.work_photos
    where id = v_foto_dueno
      and not client_consent
      and client_consent_at is null
      and client_consent_decided_at is null)
  then
    raise notice 'OK    1  el dueno manda el permiso en true y no se guarda';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 1  el permiso de quien sube la foto quedo guardado';
  end if;

  -- ==========================================================================
  -- 2. El estilista tampoco (el caso de AQ: sube desde "Mi agenda").
  -- ==========================================================================
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_estilista_cuenta::text, 'role', 'authenticated')::text, true);
  v_foto_estilista := public.create_work_photo(
    v_branch, v_ticket1, v_branch::text || '/control235-estilista.jpg', 'final', 'Estilista', null, true
  );
  if exists (
    select 1 from public.work_photos
    where id = v_foto_estilista and not client_consent and client_consent_at is null)
  then
    raise notice 'OK    2  el estilista tampoco puede dar el permiso por ella';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 2  el estilista firmo por la clienta';
  end if;

  -- ==========================================================================
  -- 3. La galería dice de qué clienta es cada foto y si ya respondió.
  -- ==========================================================================
  perform set_config('request.jwt.claims', '{}', true);
  perform public.client_consent_set_photo(v_foto_dueno, true, v_portal_token1, null);
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);

  if exists (
       select 1 from public.get_work_photos_summary_v2(v_branch) g
       where g.id = v_foto_dueno
         and g.client_id = v_cliente1
         and g.client_consent_decided_at is not null
         and g.client_consent)
     and exists (
       select 1 from public.get_work_photos_summary_v2(v_branch) g
       where g.id = v_foto_estilista
         and g.client_id = v_cliente1
         and g.client_consent_decided_at is null)
  then
    raise notice 'OK    3  la galeria trae la clienta y si ya respondio (la que si, la que no)';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 3  la galeria no distingue quien ya respondio';
  end if;

  -- ==========================================================================
  -- 4. El dueño obtiene lo del WhatsApp: el enlace de ella, nombre, celular.
  -- ==========================================================================
  v_datos := public.client_consent_whatsapp_data(v_cliente1);
  if v_datos ->> 'token' = public.get_or_create_client_consent_link(v_cliente1)
     and v_datos ->> 'client_name' = 'C235 Clienta Uno'
     and v_datos ->> 'client_phone' = '3010000001'
     and v_datos ->> 'business_name' = 'Control 235'
  then
    raise notice 'OK    4  el dueno recibe el enlace de ella, su nombre, su celular y el salon';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 4  %', v_datos;
  end if;

  -- ==========================================================================
  -- 5. El estilista no puede pedirlo (se conserva el caso 4 del control 229).
  -- ==========================================================================
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_estilista_cuenta::text, 'role', 'authenticated')::text, true);
  v_capturo := false;
  begin
    perform public.client_consent_whatsapp_data(v_cliente1);
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;
  if v_capturo and v_error like 'No autorizado%' then
    raise notice 'OK    5  el estilista no puede pedir el enlace ni ver el celular';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 5  capturo=%, mensaje=%', v_capturo, v_error;
  end if;

  -- ==========================================================================
  -- 5b. El asistente SÍ puede (decisión del propietario, 28-sep): recibe el
  --     mismo enlace que el dueño.
  -- ==========================================================================
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_asistente::text, 'role', 'authenticated')::text, true);
  v_capturo := false;
  begin
    v_datos := public.client_consent_whatsapp_data(v_cliente1);
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;
  if not v_capturo and v_datos ->> 'client_phone' = '3010000001'
     and v_datos ->> 'token' is not null
  then
    raise notice 'OK    5b el asistente si puede pedir la autorizacion';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 5b capturo=%, mensaje=%, datos=%', v_capturo, v_error, v_datos;
  end if;

  -- ==========================================================================
  -- 6. Una clienta que no es del negocio (o no existe) no devuelve nada.
  -- ==========================================================================
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);
  v_capturo := false;
  begin
    perform public.client_consent_whatsapp_data(gen_random_uuid());
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;
  if v_capturo and v_error like 'El cliente no existe%' then
    raise notice 'OK    6  una clienta ajena o inexistente se rechaza';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 6  capturo=%, mensaje=%', v_capturo, v_error;
  end if;

  -- ==========================================================================
  -- 7. Se respeta el permiso de la casilla vieja (decisión del propietario):
  --    una foto que ya lo tenía se sigue pudiendo publicar.
  -- ==========================================================================
  insert into public.work_photos (
    tenant_id, branch_id, ticket_id, client_id, stylist_id,
    storage_bucket, storage_path, photo_url, photo_type,
    visible_to_customer, approved_for_portfolio, client_consent, client_consent_at
  ) values (
    v_tenant, v_branch, v_ticket2, v_cliente2, v_stylist,
    'work-photos-private', v_branch::text || '/control235-vieja.jpg', null, 'final',
    false, false, true, now() - interval '10 days'
  ) returning id into v_foto_vieja;

  v_capturo := false;
  begin
    perform public.set_work_photo_portfolio_approval(
      v_branch, v_foto_vieja, true,
      'https://ejemplo.supabase.co/storage/v1/object/public/work-photos/' ||
        v_branch::text || '/control235-vieja.jpg'
    );
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;
  if not v_capturo and exists (
       select 1 from public.work_photos where id = v_foto_vieja and approved_for_portfolio)
  then
    raise notice 'OK    7  la foto con el permiso de la casilla vieja se sigue pudiendo publicar';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 7  capturo=%, mensaje=%', v_capturo, v_error;
  end if;

  raise notice ' ';
  if v_fallos = 0 then
    raise notice '=== CONTROL 235: 8/8 ===';
  else
    raise notice '=== % FALLO(S) EN EL CONTROL 235. Revisar arriba. ===', v_fallos;
  end if;
end
$ctrl$;

rollback;
