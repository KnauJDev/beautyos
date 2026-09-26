-- CONTROL 230: Paso 9.48, Bloque 2 (D-282) -- la clienta decide, se
--              arrepiente, y elige con qué nombre aparece.
--
-- POR QUE ESTE ARCHIVO
--
-- El Bloque 2 cambia lo que ve el público por tres puertas nuevas, y cada
-- una tiene un fallo posible que no se ve en pantalla:
--   * Retirar una foto publicada: si la base la marcara privada sin que el
--     archivo saliera del almacén público, la foto seguiría en internet con
--     la base diciendo lo contrario. Por eso `client_consent_set_photo` se
--     niega, y la única que la retira (`client_consent_finish_revoke`) es
--     solo de service_role. Aquí se prueba que la puerta esté CERRADA.
--   * Un nombre escrito por ella vuelve a moderación: sin esto saldría a la
--     página sin que nadie lo viera. Y una reseña rechazada NO se resucita.
--   * El salón modera viendo el nombre con el que la reseña sale en público.
--
-- Datos de prueba copiados del control 229, que corrió en verde (regla 25 d).
--
-- COMO SE EJECUTA (después de aplicar
-- 20260926170000_la_clienta_decide_y_se_arrepiente_9_48_b2.sql)
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\230_test_la_clienta_decide_y_se_arrepiente_9_48_b2.sql"
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
  v_memb uuid;
  v_cliente1 uuid;
  v_cliente2 uuid;
  v_portal_token1 text := 'control230-portal-token-uno';
  v_portal_token2 text := 'control230-portal-token-dos';
  v_enlace1 text;
  v_enlace1_repetido text;
  v_ticket1 uuid;
  v_ticket2 uuid;
  v_foto1 uuid;
  v_foto2 uuid;
  v_resena1 uuid;
  v_resena2 uuid;
  v_pendientes jsonb;
  v_ruta text;
  v_fila record;
  v_estudio record;
  v_capturo boolean;
  v_error text;
  v_fallos integer := 0;
begin
  select id into v_plan from public.plans where status = 'active' limit 1;
  if v_plan is null then
    raise exception 'FALLO: no hay ningun plan activo con el que probar';
  end if;

  insert into auth.users (id, email) values
    (v_dueno, 'dueno_test230@salonymas.com'),
    (v_estilista_cuenta, 'estilista_test230@salonymas.com')
  on conflict (id) do nothing;

  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 230', 'peluqueria', 'c230@salonymas.com', '3000000230', true)
  returning id into v_tenant;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_tenant, v_plan, 'active', now() + interval '30 days');

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C230 sede', 'c230-sede', true, true)
  returning id into v_branch;

  -- El dueño.
  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_dueno, 'tenant_owner', true)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);
  insert into public.user_profiles (tenant_id, user_id, full_name, role, active)
  values (v_tenant, v_dueno, 'C230 dueno', 'owner', true);

  insert into public.services (tenant_id, name, category, duration_minutes, price, visible_to_customer)
  values (v_tenant, 'C230 corte', 'Corte', 30, 50000, true)
  returning id into v_service;

  insert into public.stylists (tenant_id, name, phone, specialty)
  values (v_tenant, 'C230 estilista', '3000000230', 'Corte')
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

  -- El estilista SÍ tiene cuenta -- para probar que no puede generar el
  -- enlace de consentimiento de nadie (paso 4).
  insert into public.tenant_memberships (tenant_id, user_id, role, active, stylist_id)
  values (v_tenant, v_estilista_cuenta, 'stylist', true, v_stylist)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);
  insert into public.user_profiles (tenant_id, user_id, full_name, role, active, stylist_id)
  values (v_tenant, v_estilista_cuenta, 'C230 estilista cuenta', 'stylist', true, v_stylist);

  -- Dos clientas. La uno ya tiene sesión de portal abierta (D-167); la dos
  -- solo existe para probar que nadie decide por ella.
  insert into public.clients (tenant_id, name, phone, active, portal_session_token, portal_session_expires_at)
  values (v_tenant, 'C230 Clienta Uno', '3010000001', true, v_portal_token1, now() + interval '60 days')
  returning id into v_cliente1;

  insert into public.clients (tenant_id, name, phone, active, portal_session_token, portal_session_expires_at)
  values (v_tenant, 'C230 Clienta Dos', '3010000002', true, v_portal_token2, now() + interval '60 days')
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

  -- Las fotos: privadas, sin decidir todavía -- el estado real de hoy antes
  -- de este bloque (quien las sube marca la casilla; aquí se deja en false
  -- a propósito para probar que "pendiente" es distinto de "dijo que no").
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);

  v_foto1 := public.create_work_photo(
    v_branch, v_ticket1, v_branch::text || '/control230-foto1.jpg', 'final', 'Foto 1', v_stylist, false
  );
  v_foto2 := public.create_work_photo(
    v_branch, v_ticket2, v_branch::text || '/control230-foto2.jpg', 'final', 'Foto 2', v_stylist, false
  );

  -- Las reseñas: escritas y ya moderadas/visibles al público, el nombre
  -- todavía sin autorizar -- el estado real de hoy.
  insert into public.reviews (tenant_id, branch_id, ticket_id, client_id, rating, comment, moderation_status, visible_to_public, active)
  values (v_tenant, v_branch, v_ticket1, v_cliente1, 5, 'Control230 comentario clienta uno', 'approved', true, true)
  returning id into v_resena1;
  insert into public.reviews (tenant_id, branch_id, ticket_id, client_id, rating, comment, moderation_status, visible_to_public, active)
  values (v_tenant, v_branch, v_ticket2, v_cliente2, 4, 'Control230 comentario clienta dos', 'approved', true, true)
  returning id into v_resena2;

  -- Sin sesión desde aquí: la clienta se identifica con su token (D-167).
  perform set_config('request.jwt.claims', '{}', true);

  -- ==========================================================================
  -- 1. Lo que ve ella trae el salón, y separa pendiente de respondido.
  -- ==========================================================================
  perform public.client_consent_set_photo(v_foto1, true, v_portal_token1, null);
  v_pendientes := public.client_consent_get_pending(v_portal_token1, null);
  if (v_pendientes ->> 'business_name') = 'Control 230'
     and jsonb_array_length(v_pendientes -> 'pending_photos') = 0
     and jsonb_array_length(v_pendientes -> 'answered_photos') = 1
     and (v_pendientes -> 'answered_photos' -> 0 ->> 'authorized')::boolean
  then
    raise notice 'OK    1  trae el salon, y la foto respondida pasa a "ya respondiste"';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 1  %', v_pendientes;
  end if;

  -- La foto 1 se publica, como lo haría el salón con su permiso ya dado.
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);
  perform public.set_work_photo_portfolio_approval(
    v_branch, v_foto1, true,
    'https://ejemplo.supabase.co/storage/v1/object/public/work-photos/' ||
      v_branch::text || '/control230-foto1.jpg'
  );
  perform set_config('request.jwt.claims', '{}', true);

  -- ==========================================================================
  -- 2. Un "no" sobre una foto PUBLICADA no se acepta por la puerta normal.
  -- ==========================================================================
  v_capturo := false;
  begin
    perform public.client_consent_set_photo(v_foto1, false, v_portal_token1, null);
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;
  select approved_for_portfolio, client_consent into v_fila
  from public.work_photos where id = v_foto1;
  if v_capturo and v_error like '%ya está publicada%'
     and v_fila.approved_for_portfolio and v_fila.client_consent
  then
    raise notice 'OK    2  retirar una foto publicada por set_photo se niega, y no toca nada';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 2  capturo=%, mensaje=%, fila=%', v_capturo, v_error, v_fila;
  end if;

  -- ==========================================================================
  -- 3 y 4. La ruta publicada: la suya sí, la no publicada y la ajena no.
  -- ==========================================================================
  v_ruta := public.client_consent_get_published_photo_path(v_foto1, v_portal_token1, null);
  if v_ruta = v_branch::text || '/control230-foto1.jpg' then
    raise notice 'OK    3  entrega la ruta de SU foto publicada';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 3  ruta=%', v_ruta;
  end if;

  v_capturo := false;
  begin
    perform public.client_consent_get_published_photo_path(v_foto2, v_portal_token1, null);
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;
  if v_capturo and v_error like '%no es tuya%' then
    raise notice 'OK    4  no entrega la de la OTRA clienta';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 4  capturo=%, mensaje=%', v_capturo, v_error;
  end if;

  -- ==========================================================================
  -- 5. La puerta que anota el retiro es SOLO de service_role.
  -- ==========================================================================
  if not has_function_privilege('anon', 'public.client_consent_finish_revoke(uuid, text, text)', 'execute')
     and not has_function_privilege('authenticated', 'public.client_consent_finish_revoke(uuid, text, text)', 'execute')
     and has_function_privilege('service_role', 'public.client_consent_finish_revoke(uuid, text, text)', 'execute')
     and has_function_privilege('anon', 'public.client_consent_get_published_photo_path(uuid, text, text)', 'execute')
  then
    raise notice 'OK    5  nadie sin service_role puede anotar un retiro sin mover el archivo';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 5  permisos de client_consent_finish_revoke abiertos de mas';
  end if;

  -- ==========================================================================
  -- 6. La Edge Function, ya movido el archivo, lo anota: queda privada,
  --    sin dirección, sin consentimiento, y en "ya respondiste" como no.
  --    (El control corre como dueño de la base, que es lo que hace
  --    service_role al llamarla.)
  -- ==========================================================================
  perform public.client_consent_finish_revoke(v_foto1, v_portal_token1, null);
  select approved_for_portfolio, storage_bucket, photo_url, client_consent,
         client_consent_at, client_consent_decided_at
    into v_fila
  from public.work_photos where id = v_foto1;
  v_pendientes := public.client_consent_get_pending(v_portal_token1, null);
  if not v_fila.approved_for_portfolio and v_fila.storage_bucket = 'work-photos-private'
     and v_fila.photo_url is null and not v_fila.client_consent
     and v_fila.client_consent_at is null and v_fila.client_consent_decided_at is not null
     and not (v_pendientes -> 'answered_photos' -> 0 ->> 'authorized')::boolean
     and not (v_pendientes -> 'answered_photos' -> 0 ->> 'is_published')::boolean
  then
    raise notice 'OK    6  el retiro deja la foto privada, sin direccion y sin consentimiento';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 6  fila=%', v_fila;
  end if;

  -- ==========================================================================
  -- 7. Un nombre de 1 letra se rechaza.
  -- ==========================================================================
  v_capturo := false;
  begin
    perform public.client_consent_set_review_alias(v_resena1, ' A ', v_portal_token1, null);
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;
  if v_capturo and v_error like '%entre 2 y 40%' then
    raise notice 'OK    7  un nombre de una letra se rechaza';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 7  capturo=%, mensaje=%', v_capturo, v_error;
  end if;

  -- ==========================================================================
  -- 8. Un nombre propio sobre una reseña APROBADA la devuelve a moderación:
  --    sale de la página.
  -- ==========================================================================
  perform public.client_consent_set_review_alias(v_resena1, '  Caro de Chapinero ', v_portal_token1, null);
  select moderation_status, visible_to_public, client_display_name into v_fila
  from public.reviews where id = v_resena1;
  if v_fila.moderation_status = 'pending' and not v_fila.visible_to_public
     and v_fila.client_display_name = 'Caro de Chapinero'
     and not exists (
       select 1 from public.get_public_salon_reviews(v_tenant) p
       where p.comment = 'Control230 comentario clienta uno')
  then
    raise notice 'OK    8  un nombre propio vuelve a moderacion y sale de la pagina';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 8  fila=%', v_fila;
  end if;

  -- ==========================================================================
  -- 9. El salón ve CON QUÉ NOMBRE sale antes de aprobar, y al aprobar sale
  --    con ese nombre.
  -- ==========================================================================
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);
  select s.public_name, s.client_name into v_fila
  from public.get_reviews_summary_v2(v_branch) s where s.id = v_resena1;
  if v_fila.public_name = 'Caro de Chapinero' and v_fila.client_name = 'C230 Clienta Uno' then
    raise notice 'OK    9  el salon ve el nombre propio y el real antes de moderar';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 9  fila=%', v_fila;
  end if;

  perform public.moderate_review(v_branch, v_resena1, true);
  perform set_config('request.jwt.claims', '{}', true);

  select client_name into v_fila
  from public.get_public_salon_reviews(v_tenant)
  where comment = 'Control230 comentario clienta uno';
  if v_fila.client_name = 'Caro de Chapinero' then
    raise notice 'OK    10 aprobada, la pagina publica la muestra con su nombre propio';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 10 client_name=%', v_fila.client_name;
  end if;

  -- ==========================================================================
  -- 11. Reescribir el MISMO nombre no la saca de la página.
  -- ==========================================================================
  perform public.client_consent_set_review_alias(v_resena1, 'Caro de Chapinero', v_portal_token1, null);
  select moderation_status, visible_to_public into v_fila
  from public.reviews where id = v_resena1;
  if v_fila.moderation_status = 'approved' and v_fila.visible_to_public then
    raise notice 'OK    11 reescribir el mismo nombre no la devuelve a moderacion';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 11 fila=%', v_fila;
  end if;

  -- ==========================================================================
  -- 12. El Estudio de Publicación usa el nombre que ella eligió. La foto 2
  --     se autoriza y se publica para poder armar la pieza.
  -- ==========================================================================
  perform public.client_consent_set_photo(v_foto2, true, v_portal_token2, null);
  perform public.client_consent_set_review_alias(v_resena2, 'Lu', v_portal_token2, null);
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);
  perform public.moderate_review(v_branch, v_resena2, true);
  perform public.set_work_photo_portfolio_approval(
    v_branch, v_foto2, true,
    'https://ejemplo.supabase.co/storage/v1/object/public/work-photos/' ||
      v_branch::text || '/control230-foto2.jpg'
  );
  select * into v_estudio from public.get_publication_studio_data(v_branch, v_foto2);
  if v_estudio.review_client_name = 'Lu' then
    raise notice 'OK    12 el Estudio de Publicacion usa el nombre que ella eligio';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 12 review_client_name=%', v_estudio.review_client_name;
  end if;

  -- ==========================================================================
  -- 13. Una reseña RECHAZADA sigue rechazada aunque le escriba un nombre.
  -- ==========================================================================
  perform public.moderate_review(v_branch, v_resena2, false);
  perform set_config('request.jwt.claims', '{}', true);
  perform public.client_consent_set_review_alias(v_resena2, 'Lucia', v_portal_token2, null);
  select moderation_status, visible_to_public into v_fila
  from public.reviews where id = v_resena2;
  if v_fila.moderation_status = 'rejected' and not v_fila.visible_to_public then
    raise notice 'OK    13 escribir un nombre no resucita una resena rechazada';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 13 fila=%', v_fila;
  end if;

  -- ==========================================================================
  -- 14. Volver a "mi nombre real" borra el nombre propio.
  -- ==========================================================================
  perform public.client_consent_set_review_name(v_resena1, true, v_portal_token1, null);
  select client_name into v_fila
  from public.get_public_salon_reviews(v_tenant)
  where comment = 'Control230 comentario clienta uno';
  if v_fila.client_name = 'C230 Clienta Uno'
     and (select client_display_name from public.reviews where id = v_resena1) is null
  then
    raise notice 'OK    14 volver a "mi nombre real" borra el nombre propio';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 14 client_name=%', v_fila.client_name;
  end if;

  -- ==========================================================================
  -- 15. Nadie elige el nombre de la reseña de otra.
  -- ==========================================================================
  v_capturo := false;
  begin
    perform public.client_consent_set_review_alias(v_resena2, 'Otra', v_portal_token1, null);
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;
  if v_capturo and v_error like '%no es tuya%' then
    raise notice 'OK    15 no puede poner nombre a la resena de otra clienta';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 15 capturo=%, mensaje=%', v_capturo, v_error;
  end if;

  raise notice ' ';
  if v_fallos = 0 then
    raise notice '=== CONTROL 230: 15/15 ===';
  else
    raise notice '=== % FALLO(S) EN EL CONTROL 230. Revisar arriba. ===', v_fallos;
  end if;
end
$ctrl$;

rollback;
