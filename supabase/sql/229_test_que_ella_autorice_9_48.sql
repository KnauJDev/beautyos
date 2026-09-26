-- CONTROL 229: Paso 9.48, Bloque 1 -- que ELLA autorice, no quien sube la
--              foto ni quien modera la reseña.
--
-- POR QUE ESTE ARCHIVO
--
-- Este bloque agrega tres piezas que nadie ha probado contra la base real:
-- (1) resolver a la clienta por su token de portal O por su enlace directo,
-- sin sesión de Supabase Auth; (2) que ella decida foto por foto y reseña
-- por reseña, sin que su decisión se confunda con "todavía no le
-- preguntaron"; (3) que el nombre real solo salga en la página pública y en
-- el Estudio de Publicación cuando ella lo autorizó.
--
-- Fixtures propios, aislados (patrón de los controles 218/227): un negocio
-- nuevo con dos clientas -- una es la protagonista, la otra existe solo
-- para probar que nadie decide por la de al lado.
--
-- Que valida, transaccionalmente:
--   1. client_consent_get_pending por el token del portal trae lo suyo.
--   2. Un token que no existe se rechaza.
--   3. get_or_create_client_consent_link: el dueño lo genera, y siempre
--      genera el MISMO al pedirlo otra vez.
--   4. Un estilista (no owner/admin) no puede generar el enlace de nadie.
--   5. El mismo pendiente se ve igual por el enlace directo que por el
--      portal -- son dos puertas a la misma resolución.
--   6. client_consent_get_photo_path entrega la ruta de SU propia foto.
--   7. Y la niega para la foto de la OTRA clienta.
--   8. client_consent_set_photo(true) marca consentida, con las tres
--      columnas coherentes entre sí.
--   9. Y esa foto deja de aparecer como pendiente.
--   10. client_consent_set_photo sobre la foto de otra clienta se rechaza.
--   11. Declinar también "decide": la foto de la clienta dos deja de
--       aparecer pendiente, con consent en falso y sin fecha de aprobación.
--   12. Antes de autorizar el nombre, la página pública dice "Clienta
--       verificada" y el comentario/calificación se ven igual.
--   13. Autorizado, la página pública ya muestra su nombre real.
--   14. Sobre la reseña de otra clienta, se rechaza.
--   15. get_publication_studio_data: sin autorizar el nombre, la pieza
--       trae calificación y comentario pero NO el nombre.
--   16. Autorizado, el mismo llamado ya trae el nombre.
--
-- COMO SE EJECUTA (después de aplicar 20260926130000_que_ella_autorice_9_48.sql)
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\229_test_que_ella_autorice_9_48.sql"
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
  v_portal_token1 text := 'control229-portal-token-uno';
  v_portal_token2 text := 'control229-portal-token-dos';
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
    (v_dueno, 'dueno_test229@salonymas.com'),
    (v_estilista_cuenta, 'estilista_test229@salonymas.com')
  on conflict (id) do nothing;

  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 229', 'peluqueria', 'c229@salonymas.com', '3000000229', true)
  returning id into v_tenant;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_tenant, v_plan, 'active', now() + interval '30 days');

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C229 sede', 'c229-sede', true, true)
  returning id into v_branch;

  -- El dueño.
  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_dueno, 'tenant_owner', true)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);
  insert into public.user_profiles (tenant_id, user_id, full_name, role, active)
  values (v_tenant, v_dueno, 'C229 dueno', 'owner', true);

  insert into public.services (tenant_id, name, category, duration_minutes, price, visible_to_customer)
  values (v_tenant, 'C229 corte', 'Corte', 30, 50000, true)
  returning id into v_service;

  insert into public.stylists (tenant_id, name, phone, specialty)
  values (v_tenant, 'C229 estilista', '3000000230', 'Corte')
  returning id into v_stylist;

  -- El estilista SÍ tiene cuenta -- para probar que no puede generar el
  -- enlace de consentimiento de nadie (paso 4).
  insert into public.tenant_memberships (tenant_id, user_id, role, active, stylist_id)
  values (v_tenant, v_estilista_cuenta, 'stylist', true, v_stylist)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);
  insert into public.user_profiles (tenant_id, user_id, full_name, role, active, stylist_id)
  values (v_tenant, v_estilista_cuenta, 'C229 estilista cuenta', 'stylist', true, v_stylist);

  -- Dos clientas. La uno ya tiene sesión de portal abierta (D-167); la dos
  -- solo existe para probar que nadie decide por ella.
  insert into public.clients (tenant_id, name, phone, active, portal_session_token, portal_session_expires_at)
  values (v_tenant, 'C229 Clienta Uno', '3010000001', true, v_portal_token1, now() + interval '60 days')
  returning id into v_cliente1;

  insert into public.clients (tenant_id, name, phone, active, portal_session_token, portal_session_expires_at)
  values (v_tenant, 'C229 Clienta Dos', '3010000002', true, v_portal_token2, now() + interval '60 days')
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
    v_branch, v_ticket1, v_branch::text || '/control229-foto1.jpg', 'final', 'Foto 1', v_stylist, false
  );
  v_foto2 := public.create_work_photo(
    v_branch, v_ticket2, v_branch::text || '/control229-foto2.jpg', 'final', 'Foto 2', v_stylist, false
  );

  -- Las reseñas: escritas y ya moderadas/visibles al público, el nombre
  -- todavía sin autorizar -- el estado real de hoy.
  insert into public.reviews (tenant_id, branch_id, ticket_id, client_id, rating, comment, moderation_status, visible_to_public, active)
  values (v_tenant, v_branch, v_ticket1, v_cliente1, 5, 'Control229 comentario clienta uno', 'approved', true, true)
  returning id into v_resena1;
  insert into public.reviews (tenant_id, branch_id, ticket_id, client_id, rating, comment, moderation_status, visible_to_public, active)
  values (v_tenant, v_branch, v_ticket2, v_cliente2, 4, 'Control229 comentario clienta dos', 'approved', true, true)
  returning id into v_resena2;

  -- Sin sesión desde aquí: todo lo que sigue de la clienta se identifica
  -- con su token, no con un JWT (D-167, mismo criterio que el portal).
  perform set_config('request.jwt.claims', '{}', true);

  -- ==========================================================================
  -- 1. client_consent_get_pending por el token del portal.
  -- ==========================================================================
  v_pendientes := public.client_consent_get_pending(v_portal_token1, null);
  if (v_pendientes ->> 'client_name') = 'C229 Clienta Uno'
     and jsonb_array_length(v_pendientes -> 'pending_photos') = 1
     and jsonb_array_length(v_pendientes -> 'pending_reviews') = 1
  then
    raise notice 'OK    1  el portal trae la foto y la resena pendientes de la propia clienta';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 1  pendientes inesperados: %', v_pendientes;
  end if;

  -- ==========================================================================
  -- 2. Un token que no existe se rechaza.
  -- ==========================================================================
  v_capturo := false;
  begin
    perform public.client_consent_get_pending('esto-no-existe', null);
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;
  if v_capturo and v_error like '%sesión expiró%' then
    raise notice 'OK    2  un token de portal invalido se rechaza';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 2  capturo=%, mensaje=%', v_capturo, v_error;
  end if;

  -- ==========================================================================
  -- 3. get_or_create_client_consent_link: el dueño lo genera y es estable.
  -- ==========================================================================
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);

  v_enlace1 := public.get_or_create_client_consent_link(v_cliente1);
  v_enlace1_repetido := public.get_or_create_client_consent_link(v_cliente1);
  if v_enlace1 is not null and v_enlace1 = v_enlace1_repetido then
    raise notice 'OK    3  el enlace directo se crea una vez y se repite igual despues';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 3  primero=%, segundo=%', v_enlace1, v_enlace1_repetido;
  end if;

  -- ==========================================================================
  -- 4. Un estilista con cuenta no puede generar el enlace de nadie.
  -- ==========================================================================
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_estilista_cuenta::text, 'role', 'authenticated')::text, true);
  v_capturo := false;
  begin
    perform public.get_or_create_client_consent_link(v_cliente1);
  exception when others then
    v_capturo := true;
  end;
  if v_capturo then
    raise notice 'OK    4  un estilista no puede generar el enlace de consentimiento de una clienta';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 4  el estilista pudo generar el enlace';
  end if;

  perform set_config('request.jwt.claims', '{}', true);

  -- ==========================================================================
  -- 5. El mismo pendiente se ve igual por el enlace directo.
  -- ==========================================================================
  v_pendientes := public.client_consent_get_pending(null, v_enlace1);
  if (v_pendientes ->> 'client_name') = 'C229 Clienta Uno'
     and jsonb_array_length(v_pendientes -> 'pending_photos') = 1
  then
    raise notice 'OK    5  el enlace directo resuelve a la misma clienta que el portal';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 5  pendientes por enlace directo: %', v_pendientes;
  end if;

  -- ==========================================================================
  -- 6 y 7. client_consent_get_photo_path: la suya sí, la ajena no.
  -- ==========================================================================
  v_ruta := public.client_consent_get_photo_path(v_foto1, v_portal_token1, null);
  if v_ruta = v_branch::text || '/control229-foto1.jpg' then
    raise notice 'OK    6  la clienta puede leer la ruta de SU propia foto privada';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 6  ruta=%', v_ruta;
  end if;

  v_capturo := false;
  begin
    perform public.client_consent_get_photo_path(v_foto2, v_portal_token1, null);
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;
  if v_capturo and v_error like '%no es tuya%' then
    raise notice 'OK    7  no puede leer la ruta de la foto de la OTRA clienta';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 7  capturo=%, mensaje=%', v_capturo, v_error;
  end if;

  -- ==========================================================================
  -- 8 y 9. Autorizar de verdad, y que deje de estar pendiente.
  -- ==========================================================================
  perform public.client_consent_set_photo(v_foto1, true, v_portal_token1, null);

  select client_consent, (client_consent_at is not null) as tiene_fecha,
         (client_consent_decided_at is not null) as decidio
    into v_fila
  from public.work_photos where id = v_foto1;

  if v_fila.client_consent and v_fila.tiene_fecha and v_fila.decidio then
    raise notice 'OK    8  la foto queda consentida por ELLA, con sus tres columnas coherentes';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 8  fila=%', v_fila;
  end if;

  v_pendientes := public.client_consent_get_pending(v_portal_token1, null);
  if jsonb_array_length(v_pendientes -> 'pending_photos') = 0 then
    raise notice 'OK    9  la foto ya decidida deja de aparecer como pendiente';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 9  todavia aparece pendiente: %', v_pendientes -> 'pending_photos';
  end if;

  -- ==========================================================================
  -- 10. No puede decidir sobre la foto de la OTRA clienta.
  -- ==========================================================================
  v_capturo := false;
  begin
    perform public.client_consent_set_photo(v_foto2, true, v_portal_token1, null);
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;
  if v_capturo and v_error like '%no es tuya%' then
    raise notice 'OK    10 no puede autorizar la foto de la otra clienta';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 10 capturo=%, mensaje=%', v_capturo, v_error;
  end if;

  -- ==========================================================================
  -- 11. Declinar también "decide": no queda pendiente para siempre.
  -- ==========================================================================
  perform public.client_consent_set_photo(v_foto2, false, v_portal_token2, null);

  select client_consent, (client_consent_at is null) as sin_fecha,
         (client_consent_decided_at is not null) as decidio
    into v_fila
  from public.work_photos where id = v_foto2;

  v_pendientes := public.client_consent_get_pending(v_portal_token2, null);

  if not v_fila.client_consent and v_fila.sin_fecha and v_fila.decidio
     and jsonb_array_length(v_pendientes -> 'pending_photos') = 0
  then
    raise notice 'OK    11 declinar deja consent en falso, sin fecha, y ya no pendiente';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 11 fila=%, pendientes=%', v_fila, v_pendientes -> 'pending_photos';
  end if;

  -- ==========================================================================
  -- 12. Antes de autorizar el nombre, la página pública lo esconde.
  -- ==========================================================================
  select client_name, comment, rating into v_fila
  from public.get_public_salon_reviews(v_tenant)
  where comment = 'Control229 comentario clienta uno';

  if v_fila.client_name = 'Clienta verificada' and v_fila.rating = 5 then
    raise notice 'OK    12 sin autorizar, sale "Clienta verificada" y el comentario/calificacion igual';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 12 fila=%', v_fila;
  end if;

  -- ==========================================================================
  -- 13 y 14. Autorizar el nombre, y que nadie decida por la otra clienta.
  -- ==========================================================================
  perform public.client_consent_set_review_name(v_resena1, true, v_portal_token1, null);

  select client_name into v_fila
  from public.get_public_salon_reviews(v_tenant)
  where comment = 'Control229 comentario clienta uno';

  if v_fila.client_name = 'C229 Clienta Uno' then
    raise notice 'OK    13 autorizado, la pagina publica ya muestra su nombre real';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 13 client_name=%', v_fila.client_name;
  end if;

  v_capturo := false;
  begin
    perform public.client_consent_set_review_name(v_resena2, true, v_portal_token1, null);
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;
  if v_capturo and v_error like '%no es tuya%' then
    raise notice 'OK    14 no puede autorizar el nombre de la resena de la otra clienta';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 14 capturo=%, mensaje=%', v_capturo, v_error;
  end if;

  -- ==========================================================================
  -- 15 y 16. El Estudio de Publicación respeta lo mismo.
  -- ==========================================================================
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);

  perform public.set_work_photo_portfolio_approval(
    v_branch, v_foto1, true,
    'https://ejemplo.supabase.co/storage/v1/object/public/work-photos/' ||
      v_branch::text || '/control229-foto1.jpg'
  );

  -- Se revoca la autorización del nombre para probar el "antes" del Estudio
  -- sin tener que crear una tercera reseña.
  perform public.client_consent_set_review_name(v_resena1, false, v_portal_token1, null);

  select * into v_estudio from public.get_publication_studio_data(v_branch, v_foto1);
  if v_estudio.review_rating = 5
     and v_estudio.review_comment = 'Control229 comentario clienta uno'
     and v_estudio.review_client_name is null
  then
    raise notice 'OK    15 sin autorizar el nombre, el Estudio trae calificacion y comentario, sin nombre';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 15 estudio=%', v_estudio;
  end if;

  perform public.client_consent_set_review_name(v_resena1, true, v_portal_token1, null);

  select * into v_estudio from public.get_publication_studio_data(v_branch, v_foto1);
  if v_estudio.review_client_name = 'C229 Clienta Uno' then
    raise notice 'OK    16 autorizado, el Estudio ya trae su nombre';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 16 review_client_name=%', v_estudio.review_client_name;
  end if;

  raise notice ' ';
  if v_fallos = 0 then
    raise notice '=== CONTROL 229: 16/16 ===';
  else
    raise notice '=== % FALLO(S) EN EL CONTROL 229. Revisar arriba. ===', v_fallos;
  end if;
end
$ctrl$;

rollback;
