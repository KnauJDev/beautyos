-- D-167: cierre de la Fase 5. Consentimiento Ley 1581 para publicar fotos
-- en portafolio (paso 5.7) y portal seguro de la clienta (paso 5.6).
--
-- POR QUE ESTE ARCHIVO
--
-- Son dos superficies de riesgo real: publicar la foto de una clienta sin
-- su autorización (legal) y un portal público que guarda su historial de
-- citas y sus fotos detrás de un PIN de 4 dígitos (seguridad). Un fallo
-- aquí no es un detalle visual -- es una publicación indebida o una cuenta
-- ajena abierta.
--
-- COMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\187_test_habeas_data_y_portal_cliente.sql"
--
-- TERMINA EN ROLLBACK. No deja ni una fila, incluida la clienta de prueba
-- que crea para no tocar clientes reales con PINes/consentimientos de
-- prueba.

begin;

do $$
declare
  v_tenant uuid;
  v_branch uuid;
  v_owner uuid;
  v_stylist_user uuid;
  v_service uuid;
  v_stylist uuid;
  v_client uuid;
  v_ticket_futuro uuid;
  v_ticket_pasado uuid;
  v_ticket_reseñado uuid;
  v_photo_con_consentimiento uuid;
  v_photo_sin_consentimiento uuid;
  v_photo_privada_visible uuid;
  v_token text;
  v_token_viejo text;
  v_capturo boolean;
  v_error_msg text;
  v_portal_data jsonb;
  v_auth jsonb;
  v_count integer;
  v_intentos integer;
  v_locked_until timestamptz;
  v_fallos integer := 0;
  v_error text;
begin
  select t.id into v_tenant
  from public.tenants t
  where t.active
  order by t.created_at
  limit 1;

  select b.id into v_branch
  from public.branches b
  where b.tenant_id = v_tenant and b.active and b.is_primary
  limit 1;

  select tm.user_id into v_owner
  from public.tenant_memberships tm
  where tm.tenant_id = v_tenant
    and tm.role = 'tenant_owner'
    and tm.active
  limit 1;

  select tm.user_id into v_stylist_user
  from public.tenant_memberships tm
  where tm.tenant_id = v_tenant
    and tm.role = 'stylist'
    and tm.active
  limit 1;

  select bs.service_id into v_service
  from public.branch_services bs
  where bs.tenant_id = v_tenant and bs.branch_id = v_branch and bs.active
  limit 1;

  select st.id into v_stylist
  from public.stylists st
  where st.tenant_id = v_tenant and st.active
  limit 1;

  if v_tenant is null or v_branch is null or v_owner is null or v_service is null then
    raise notice 'SIN DATOS suficientes para las pruebas. Nada que comprobar.';
    return;
  end if;

  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_owner::text, 'role', 'authenticated')::text,
    true
  );

  -- =====================================================================
  -- Fixture: una clienta de prueba con una cita futura, una pasada sin
  -- reseñar y una pasada ya reseñada.
  -- =====================================================================
  insert into public.clients (tenant_id, name, phone, active)
  values (v_tenant, 'Clienta Portal D167', '300 000 0199', true)
  returning id into v_client;

  insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at)
  values (v_tenant, v_branch, v_client, 'confirmado', 'manual', now() + interval '3 days')
  returning id into v_ticket_futuro;

  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant, v_branch, v_ticket_futuro, v_service, v_stylist, 50000, 45, 'pendiente');

  insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at)
  values (v_tenant, v_branch, v_client, 'cerrado', 'manual', now() - interval '10 days')
  returning id into v_ticket_pasado;

  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant, v_branch, v_ticket_pasado, v_service, v_stylist, 50000, 45, 'finalizado');

  insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at)
  values (v_tenant, v_branch, v_client, 'cerrado', 'manual', now() - interval '20 days')
  returning id into v_ticket_reseñado;

  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant, v_branch, v_ticket_reseñado, v_service, v_stylist, 50000, 45, 'finalizado');

  insert into public.reviews (tenant_id, branch_id, ticket_id, client_id, rating, comment, moderation_status, visible_to_public, active)
  values (v_tenant, v_branch, v_ticket_reseñado, v_client, 5, 'Excelente', 'approved', true, true);

  -- =====================================================================
  -- CASO 1: Habeas Data -- create_work_photo con y sin consentimiento.
  -- =====================================================================
  v_photo_con_consentimiento := public.create_work_photo(
    v_branch, v_ticket_pasado, v_branch::text || '/prueba-con-consentimiento.jpg',
    'after', 'Con autorizacion', v_stylist, true
  );

  if exists (
    select 1 from public.work_photos
    where id = v_photo_con_consentimiento
      and client_consent = true
      and client_consent_at is not null
  ) then
    raise notice 'OK  1a  create_work_photo con consentimiento guarda client_consent=true y la fecha';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 1a  el consentimiento no quedo guardado como se esperaba';
  end if;

  v_photo_sin_consentimiento := public.create_work_photo(
    v_branch, v_ticket_pasado, v_branch::text || '/prueba-sin-consentimiento.jpg',
    'after'::text, 'Sin autorizacion'::text, v_stylist
  );

  if exists (
    select 1 from public.work_photos
    where id = v_photo_sin_consentimiento
      and client_consent = false
      and client_consent_at is null
  ) then
    raise notice 'OK  1b  create_work_photo sin consentimiento (parametro omitido) queda en false, sin fecha';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 1b  el default de consentimiento no fue false/null como se esperaba';
  end if;

  -- =====================================================================
  -- CASO 2: set_work_photo_portfolio_approval rechaza sin consentimiento.
  -- =====================================================================
  v_capturo := false;
  begin
    perform public.set_work_photo_portfolio_approval(
      v_branch, v_photo_sin_consentimiento, true,
      'https://ejemplo.supabase.co/storage/v1/object/public/work-photos/' ||
        v_branch::text || '/prueba-sin-consentimiento.jpg'
    );
  exception
    when others then
      v_capturo := true;
      v_error_msg := sqlerrm;
  end;

  if v_capturo and v_error_msg = 'No se puede publicar en portafolio sin consentimiento de la clienta (Ley 1581)' then
    raise notice 'OK  2a  aprobar sin consentimiento se rechaza con el mensaje exacto de Ley 1581';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 2a  se esperaba el rechazo exacto de Ley 1581; capturo=%, mensaje="%"', v_capturo, v_error_msg;
  end if;

  perform public.set_work_photo_portfolio_approval(
    v_branch, v_photo_con_consentimiento, true,
    'https://ejemplo.supabase.co/storage/v1/object/public/work-photos/' ||
      v_branch::text || '/prueba-con-consentimiento.jpg'
  );

  -- Aprobar para portafolio NO cambia `visible_to_customer` -- son banderas
  -- independientes a proposito (D-119). Para que la foto llegue al portal
  -- de la clienta (Caso 9) hace falta encenderla tambien, igual que hace el
  -- equipo del salon desde la galeria interna.
  perform public.set_work_photo_customer_visibility(v_branch, v_photo_con_consentimiento, true);

  if exists (
    select 1 from public.work_photos
    where id = v_photo_con_consentimiento and approved_for_portfolio = true
  ) then
    raise notice 'OK  2b  con consentimiento, aprobar para portafolio funciona igual que siempre';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 2b  no se pudo aprobar una foto con consentimiento';
  end if;

  -- =====================================================================
  -- CASO 3: get_work_photos_summary_v2 expone client_consent.
  -- =====================================================================
  if exists (
    select 1 from public.get_work_photos_summary_v2(v_branch)
    where id = v_photo_con_consentimiento and client_consent = true
  ) and exists (
    select 1 from public.get_work_photos_summary_v2(v_branch)
    where id = v_photo_sin_consentimiento and client_consent = false
  ) then
    raise notice 'OK  3a  la galeria interna distingue las fotos con y sin consentimiento';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 3a  get_work_photos_summary_v2 no distingue el consentimiento correctamente';
  end if;

  -- Foto visible al cliente pero SIN aprobar para portafolio (D-119): no
  -- debe salir en el portal porque no tiene URL publica todavia.
  v_photo_privada_visible := public.create_work_photo(
    v_branch, v_ticket_pasado, v_branch::text || '/prueba-privada-visible.jpg',
    'after', 'Visible pero privada', v_stylist, false
  );
  update public.work_photos set visible_to_customer = true where id = v_photo_privada_visible;

  -- =====================================================================
  -- =====================================================================
  -- CASO 4: client_portal_authenticate rechaza cuando no hay PIN asignado.
  -- =====================================================================
  v_auth := public.client_portal_authenticate(v_tenant, '3000000199', '1234');

  if (v_auth->>'error') = 'Todavía no tienes un PIN de acceso. Pídelo en el salón.' then
    raise notice 'OK  4a  sin PIN asignado, el portal rechaza el ingreso (no lo crea solo)';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 4a  el portal dejo entrar o creo un PIN sin que el salon lo asignara: %', v_auth;
  end if;

  -- =====================================================================
  -- CASO 5: el salon asigna el PIN; login correcto funciona y da token.
  -- =====================================================================
  perform public.admin_reset_client_portal_pin(v_client, '1234');

  v_auth := public.client_portal_authenticate(v_tenant, '3000000199', '1234');
  v_token := v_auth->>'token';

  if v_token is not null and length(v_token) > 10 then
    raise notice 'OK  5a  con el PIN asignado por el salon, el login funciona y devuelve un token';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 5a  el login no devolvio un token valido: %', v_auth;
  end if;

  -- El telefono con otro formato de puntuacion (guiones y parentesis, los
  -- mismos digitos) debe autenticar igual: se compara por digitos, no por
  -- el texto exacto guardado.
  v_auth := public.client_portal_authenticate(v_tenant, '(300) 000-0199', '1234');
  if (v_auth->>'token') is not null then
    raise notice 'OK  5b  el celular se compara por digitos, sin importar la puntuacion';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 5b  el login con otro formato de celular no funciono igual: %', v_auth;
  end if;

  -- =====================================================================
  -- CASO 6: PIN incorrecto se rechaza y cuenta como intento fallido.
  -- =====================================================================
  v_auth := public.client_portal_authenticate(v_tenant, '3000000199', '9999');

  select portal_failed_attempts into v_intentos from public.clients where id = v_client;

  if (v_auth->>'error') = 'PIN incorrecto.' and v_intentos = 1 then
    raise notice 'OK  6a  un PIN incorrecto se rechaza y queda contado como intento fallido';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 6a  se esperaba rechazo y 1 intento fallido; auth=%, intentos=%', v_auth, v_intentos;
  end if;

  -- =====================================================================
  -- CASO 7: 5 intentos fallidos bloquean el acceso, incluso con el PIN
  -- correcto.
  -- =====================================================================
  for i in 1..4 loop
    perform public.client_portal_authenticate(v_tenant, '3000000199', '9999');
  end loop;

  select portal_failed_attempts into v_intentos from public.clients where id = v_client;

  v_auth := public.client_portal_authenticate(v_tenant, '3000000199', '1234');

  if v_intentos = 5 and (v_auth->>'error') like 'Demasiados intentos%' then
    raise notice 'OK  7a  tras 5 intentos fallidos, hasta el PIN correcto queda bloqueado';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 7a  se esperaba bloqueo tras 5 intentos; intentos=%, auth=%',
      v_intentos, v_auth;
  end if;

  -- =====================================================================
  -- CASO 8: restablecer el PIN limpia el bloqueo y los intentos, invalida
  -- la sesion vieja, y el PIN nuevo funciona.
  -- =====================================================================
  v_token_viejo := v_token;

  perform public.admin_reset_client_portal_pin(v_client, '5678');

  select portal_failed_attempts, portal_locked_until, portal_session_token
    into v_intentos, v_locked_until, v_token
  from public.clients where id = v_client;

  if v_intentos = 0 and v_locked_until is null and v_token is null then
    raise notice 'OK  8a  restablecer el PIN limpia intentos, bloqueo y la sesion anterior';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 8a  restablecer el PIN no limpio el estado como se esperaba';
  end if;

  v_capturo := false;
  begin
    perform public.get_client_portal_data(v_tenant, '3000000199', v_token_viejo);
  exception
    when others then
      v_capturo := true;
  end;

  if v_capturo then
    raise notice 'OK  8a2  el token de sesion de antes del restablecimiento ya no sirve';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 8a2  el token de sesion viejo siguio funcionando tras restablecer el PIN';
  end if;

  v_auth := public.client_portal_authenticate(v_tenant, '3000000199', '1234');

  if (v_auth->>'error') = 'PIN incorrecto.' then
    raise notice 'OK  8b  el PIN viejo (1234) ya no funciona tras restablecer';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 8b  el PIN viejo siguio funcionando despues de restablecer: %', v_auth;
  end if;

  v_auth := public.client_portal_authenticate(v_tenant, '3000000199', '5678');
  v_token := v_auth->>'token';

  if v_token is not null then
    raise notice 'OK  8c  el PIN nuevo (5678) funciona';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 8c  el PIN nuevo no funciono: %', v_auth;
  end if;

  -- =====================================================================
  -- CASO 9: get_client_portal_data -- citas, ya-reseñada, y fotos.
  -- =====================================================================
  v_portal_data := public.get_client_portal_data(v_tenant, '3000000199', v_token);

  if v_portal_data ->> 'client_name' = 'Clienta Portal D167' then
    raise notice 'OK  9a  el nombre de la clienta llega correcto';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 9a  se esperaba "Clienta Portal D167"; llego "%"', v_portal_data ->> 'client_name';
  end if;

  select jsonb_array_length(v_portal_data -> 'upcoming_appointments') into v_count;
  if v_count = 1 then
    raise notice 'OK  9b  hay exactamente 1 cita proxima (la confirmada a futuro)';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 9b  se esperaba 1 cita proxima; llegaron %', v_count;
  end if;

  select jsonb_array_length(v_portal_data -> 'past_appointments') into v_count;
  if v_count = 2 then
    raise notice 'OK  9c  hay exactamente 2 citas pasadas (cerradas)';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 9c  se esperaban 2 citas pasadas; llegaron %', v_count;
  end if;

  if exists (
    select 1 from jsonb_array_elements(v_portal_data -> 'past_appointments') a
    where (a ->> 'ticket_id')::uuid = v_ticket_reseñado
      and (a ->> 'already_reviewed')::boolean = true
  ) and exists (
    select 1 from jsonb_array_elements(v_portal_data -> 'past_appointments') a
    where (a ->> 'ticket_id')::uuid = v_ticket_pasado
      and (a ->> 'already_reviewed')::boolean = false
  ) then
    raise notice 'OK  9d  already_reviewed distingue la cita ya calificada de la que no';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 9d  already_reviewed no distingue correctamente';
  end if;

  select jsonb_array_length(v_portal_data -> 'photos') into v_count;
  if v_count = 1 then
    raise notice 'OK  9e  solo aparece 1 foto: la aprobada para portafolio (con URL publica)';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 9e  se esperaba 1 foto en el portal; llegaron %', v_count;
  end if;

  -- =====================================================================
  -- CASO 10: get_client_portal_data rechaza un token invalido.
  -- =====================================================================
  v_capturo := false;
  begin
    perform public.get_client_portal_data(v_tenant, '3000000199', 'token-que-no-existe');
  exception
    when others then
      v_capturo := true;
  end;

  if v_capturo then
    raise notice 'OK  10a  un token invalido se rechaza';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 10a  un token invalido no fue rechazado';
  end if;

  -- =====================================================================
  -- CASO 11: un estilista no puede restablecer el PIN de una clienta.
  -- =====================================================================
  if v_stylist_user is null then
    raise notice 'SALTADA 11a: el negocio no tiene estilista con cuenta.';
  else
    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', v_stylist_user::text, 'role', 'authenticated')::text,
      true
    );

    v_capturo := false;
    begin
      perform public.admin_reset_client_portal_pin(v_client, '0000');
    exception
      when others then
        v_capturo := true;
    end;

    if v_capturo then
      raise notice 'OK  11a  un estilista no puede restablecer el PIN del portal';
    else
      v_fallos := v_fallos + 1;
      raise notice 'FALLO 11a  un estilista pudo restablecer el PIN del portal';
    end if;

    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', v_owner::text, 'role', 'authenticated')::text,
      true
    );
  end if;

  -- =====================================================================
  raise notice ' ';
  if v_fallos = 0 then
    raise notice '=== TODAS LAS PRUEBAS DE HABEAS DATA Y PORTAL DE LA CLIENTA PASARON ===';
  else
    raise notice '=== % FALLO(S). Revisar arriba. ===', v_fallos;
  end if;

exception
  when others then
    v_error := sqlerrm;
    raise notice ' ';
    raise notice '=== LA PRUEBA SE DETUVO: % ===', v_error;
    raise notice 'Si es la primera vez que se corre, puede ser el guion y no';
    raise notice 'la aplicacion. Pasale este mensaje al asistente.';
end;
$$;

rollback;
