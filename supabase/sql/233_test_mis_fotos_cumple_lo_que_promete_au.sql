-- CONTROL 233: AU (D-286), paso 9.48 -- "Mis fotos de trabajos" muestra
--              toda foto que el salón le marcó como visible, esté o no en
--              el portafolio, y marca cuáles están publicadas.
--
-- POR QUE ESTE ARCHIVO
--
-- Quitar `photo_url is not null` de `get_client_portal_data` abre la lista
-- a las fotos del almacén privado. Lo que puede salir mal no se ve en
-- pantalla con una sola clienta:
--   * que se cuele una foto que el salón NO le marcó como visible;
--   * que se cuele una foto de OTRA clienta;
--   * que una privada llegue marcada como publicada, o al revés;
--   * que la URL temporal (client_consent_get_photo_path, D-281) sirva para
--     la foto de otra.
-- Y el caso que lo destapó el 27-sep: una foto retirada del portafolio sigue
-- en su portal, marcada como no publicada.
--
-- Datos de prueba copiados del control 230, que corrió en verde (regla 25 d).
--
-- COMO SE EJECUTA (después de aplicar
-- 20260927160000_mis_fotos_cumple_lo_que_promete_au.sql)
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\233_test_mis_fotos_cumple_lo_que_promete_au.sql"
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
  v_portal_token1 text := 'control233-portal-token-uno';
  v_portal_token2 text := 'control233-portal-token-dos';
  v_ticket1 uuid;
  v_ticket2 uuid;
  v_foto1 uuid;
  v_foto2 uuid;
  v_foto_privada uuid;
  v_foto_oculta uuid;
  v_datos jsonb;
  v_ids uuid[];
  v_ruta text;
  v_capturo boolean;
  v_error text;
  v_fallos integer := 0;
begin
  select id into v_plan from public.plans where status = 'active' limit 1;
  if v_plan is null then
    raise exception 'FALLO: no hay ningun plan activo con el que probar';
  end if;

  insert into auth.users (id, email) values
    (v_dueno, 'dueno_test233@salonymas.com'),
    (v_estilista_cuenta, 'estilista_test233@salonymas.com')
  on conflict (id) do nothing;

  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 233', 'peluqueria', 'c233@salonymas.com', '3000000233', true)
  returning id into v_tenant;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_tenant, v_plan, 'active', now() + interval '30 days');

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C233 sede', 'c233-sede', true, true)
  returning id into v_branch;

  -- El dueño.
  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_dueno, 'tenant_owner', true)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);
  insert into public.user_profiles (tenant_id, user_id, full_name, role, active)
  values (v_tenant, v_dueno, 'C233 dueno', 'owner', true);

  insert into public.services (tenant_id, name, category, duration_minutes, price, visible_to_customer)
  values (v_tenant, 'C233 corte', 'Corte', 30, 50000, true)
  returning id into v_service;

  insert into public.stylists (tenant_id, name, phone, specialty)
  values (v_tenant, 'C233 estilista', '3000000233', 'Corte')
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

  -- El estilista con cuenta: copiado tal cual del control 230, donde se
  -- usa; aquí no, pero quitarlo sería cambiar lo que ya corrió en verde.
  insert into public.tenant_memberships (tenant_id, user_id, role, active, stylist_id)
  values (v_tenant, v_estilista_cuenta, 'stylist', true, v_stylist)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);
  insert into public.user_profiles (tenant_id, user_id, full_name, role, active, stylist_id)
  values (v_tenant, v_estilista_cuenta, 'C233 estilista cuenta', 'stylist', true, v_stylist);

  -- Dos clientas. La uno ya tiene sesión de portal abierta (D-167); la dos
  -- solo existe para probar que nadie decide por ella.
  insert into public.clients (tenant_id, name, phone, active, portal_session_token, portal_session_expires_at)
  values (v_tenant, 'C233 Clienta Uno', '3010000001', true, v_portal_token1, now() + interval '60 days')
  returning id into v_cliente1;

  insert into public.clients (tenant_id, name, phone, active, portal_session_token, portal_session_expires_at)
  values (v_tenant, 'C233 Clienta Dos', '3010000002', true, v_portal_token2, now() + interval '60 days')
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
    v_branch, v_ticket1, v_branch::text || '/control233-foto1.jpg', 'final', 'Foto 1', v_stylist, false
  );
  v_foto2 := public.create_work_photo(
    v_branch, v_ticket2, v_branch::text || '/control233-foto2.jpg', 'final', 'Foto 2', v_stylist, false
  );

  -- Dos fotos más de la clienta uno, las dos privadas: una que el salón le
  -- marca como visible y otra que no.
  v_foto_privada := public.create_work_photo(
    v_branch, v_ticket1, v_branch::text || '/control233-privada.jpg', 'final', 'Privada', v_stylist, false
  );
  v_foto_oculta := public.create_work_photo(
    v_branch, v_ticket1, v_branch::text || '/control233-oculta.jpg', 'final', 'Oculta', v_stylist, false
  );

  -- Visibles para su clienta: la foto 1, la privada y la de la clienta dos.
  -- La oculta NO. Igual que el control 187: el salón lo enciende desde la
  -- galería.
  perform public.set_work_photo_customer_visibility(v_branch, v_foto1, true);
  perform public.set_work_photo_customer_visibility(v_branch, v_foto_privada, true);
  perform public.set_work_photo_customer_visibility(v_branch, v_foto2, true);

  -- La foto 1 se publica: primero ella autoriza (D-281), después el salón
  -- aprueba -- el mismo orden del control 230.
  perform set_config('request.jwt.claims', '{}', true);
  perform public.client_consent_set_photo(v_foto1, true, v_portal_token1, null);
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);
  perform public.set_work_photo_portfolio_approval(
    v_branch, v_foto1, true,
    'https://ejemplo.supabase.co/storage/v1/object/public/work-photos/' ||
      v_branch::text || '/control233-foto1.jpg'
  );

  -- Sin sesión desde aquí: la clienta entra con su token (D-167).
  perform set_config('request.jwt.claims', '{}', true);

  -- ==========================================================================
  -- 1. La clienta uno ve sus DOS fotos visibles: la publicada y la privada.
  -- ==========================================================================
  v_datos := public.get_client_portal_data(v_tenant, '3010000001', v_portal_token1);
  select array_agg((f ->> 'id')::uuid) into v_ids
  from jsonb_array_elements(v_datos -> 'photos') f;

  if jsonb_array_length(v_datos -> 'photos') = 2
     and v_foto1 = any(v_ids) and v_foto_privada = any(v_ids)
  then
    raise notice 'OK    1  ve sus dos fotos visibles: la publicada y la privada';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 1  %', v_datos -> 'photos';
  end if;

  -- ==========================================================================
  -- 2. La que el salón NO marcó como visible no aparece.
  -- ==========================================================================
  if not (v_foto_oculta = any(v_ids)) then
    raise notice 'OK    2  la foto no marcada como visible no aparece';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 2  se colo la foto oculta';
  end if;

  -- ==========================================================================
  -- 3. La foto de la clienta dos no aparece en el portal de la uno.
  -- ==========================================================================
  if not (v_foto2 = any(v_ids)) then
    raise notice 'OK    3  la foto de otra clienta no aparece';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 3  se colo la foto de la clienta dos';
  end if;

  -- ==========================================================================
  -- 4. La marca: la publicada con dirección e in_portfolio; la privada sin
  --    dirección y sin in_portfolio.
  -- ==========================================================================
  if exists (
       select 1 from jsonb_array_elements(v_datos -> 'photos') f
       where (f ->> 'id')::uuid = v_foto1
         and (f ->> 'in_portfolio')::boolean
         and f ->> 'photo_url' like '%/object/public/work-photos/%')
     and exists (
       select 1 from jsonb_array_elements(v_datos -> 'photos') f
       where (f ->> 'id')::uuid = v_foto_privada
         and not (f ->> 'in_portfolio')::boolean
         and f ->> 'photo_url' is null)
  then
    raise notice 'OK    4  la publicada llega marcada y con direccion; la privada sin ninguna';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 4  %', v_datos -> 'photos';
  end if;

  -- ==========================================================================
  -- 5. La clienta dos ve solo la suya, privada.
  -- ==========================================================================
  v_datos := public.get_client_portal_data(v_tenant, '3010000002', v_portal_token2);
  if jsonb_array_length(v_datos -> 'photos') = 1
     and (v_datos -> 'photos' -> 0 ->> 'id')::uuid = v_foto2
     and not (v_datos -> 'photos' -> 0 ->> 'in_portfolio')::boolean
  then
    raise notice 'OK    5  la clienta dos ve solo su foto, marcada como no publicada';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 5  %', v_datos -> 'photos';
  end if;

  -- ==========================================================================
  -- 6. La URL temporal: con su token, la ruta de su foto privada sale.
  -- ==========================================================================
  v_ruta := public.client_consent_get_photo_path(v_foto_privada, v_portal_token1, null);
  if v_ruta = v_branch::text || '/control233-privada.jpg' then
    raise notice 'OK    6  su token le da la ruta de su foto privada, para firmarla';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 6  ruta=%', v_ruta;
  end if;

  -- ==========================================================================
  -- 7. ... y con el token de otra clienta, no.
  -- ==========================================================================
  v_capturo := false;
  begin
    perform public.client_consent_get_photo_path(v_foto_privada, v_portal_token2, null);
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;
  if v_capturo and v_error like '%no es tuya%' then
    raise notice 'OK    7  el token de otra clienta no sirve para firmar su foto';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 7  capturo=%, mensaje=%', v_capturo, v_error;
  end if;

  -- ==========================================================================
  -- 8. El caso del 27-sep: el salón retira la foto 1 del portafolio y ella
  --    la sigue viendo en su portal, ahora como no publicada.
  -- ==========================================================================
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);
  perform public.set_work_photo_portfolio_approval(v_branch, v_foto1, false, null);
  perform set_config('request.jwt.claims', '{}', true);

  v_datos := public.get_client_portal_data(v_tenant, '3010000001', v_portal_token1);
  if exists (
       select 1 from jsonb_array_elements(v_datos -> 'photos') f
       where (f ->> 'id')::uuid = v_foto1
         and not (f ->> 'in_portfolio')::boolean
         and f ->> 'photo_url' is null)
     and jsonb_array_length(v_datos -> 'photos') = 2
  then
    raise notice 'OK    8  retirada del portafolio, sigue en su portal como no publicada';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 8  %', v_datos -> 'photos';
  end if;

  -- ==========================================================================
  -- 9. Sin sesión válida no entrega nada (lo de D-167 sigue igual).
  -- ==========================================================================
  v_capturo := false;
  begin
    perform public.get_client_portal_data(v_tenant, '3010000001', 'control233-token-falso');
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;
  if v_capturo and v_error like '%expir%' then
    raise notice 'OK    9  con un token falso no entrega nada';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 9  capturo=%, mensaje=%', v_capturo, v_error;
  end if;

  raise notice ' ';
  if v_fallos = 0 then
    raise notice '=== CONTROL 233: 9/9 ===';
  else
    raise notice '=== % FALLO(S) EN EL CONTROL 233. Revisar arriba. ===', v_fallos;
  end if;
end
$ctrl$;

rollback;
