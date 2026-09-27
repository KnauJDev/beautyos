-- CONTROL 232: Publicar una foto lo autoriza la base, y lo mueve el servidor
--              (hallazgo BX, D-285).
--
-- POR QUE ESTE ARCHIVO
--
-- Desde el 09-ago ninguna foto llegó al almacén público: mover exige un
-- permiso de Storage que nadie tiene. El propietario decidió no darlo y
-- mover por una Edge Function con service_role. Toda la autorización de
-- esa Edge Function es `work_photo_authorize_move`, así que aquí se prueba
-- que diga que NO a quien no debe: a público, nada que no esté aprobado y
-- consentido; y ni el estilista ni alguien de fuera mueven nada.
--
-- Datos de prueba copiados del control 229, que corrió en verde.
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\232_test_publicar_fotos_por_el_servidor_bx.sql"
--
-- TERMINA EN ROLLBACK.

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
  v_portal_token1 text := 'control232-portal-token-uno';
  v_portal_token2 text := 'control232-portal-token-dos';
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
    (v_dueno, 'dueno_test232@salonymas.com'),
    (v_estilista_cuenta, 'estilista_test232@salonymas.com')
  on conflict (id) do nothing;

  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 232', 'peluqueria', 'c232@salonymas.com', '3000000232', true)
  returning id into v_tenant;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_tenant, v_plan, 'active', now() + interval '30 days');

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C232 sede', 'c232-sede', true, true)
  returning id into v_branch;

  -- El dueño.
  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_dueno, 'tenant_owner', true)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);
  insert into public.user_profiles (tenant_id, user_id, full_name, role, active)
  values (v_tenant, v_dueno, 'C232 dueno', 'owner', true);

  insert into public.services (tenant_id, name, category, duration_minutes, price, visible_to_customer)
  values (v_tenant, 'C232 corte', 'Corte', 30, 50000, true)
  returning id into v_service;

  insert into public.stylists (tenant_id, name, phone, specialty)
  values (v_tenant, 'C232 estilista', '3000000230', 'Corte')
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
  values (v_tenant, v_estilista_cuenta, 'C232 estilista cuenta', 'stylist', true, v_stylist);

  -- Dos clientas. La uno ya tiene sesión de portal abierta (D-167); la dos
  -- solo existe para probar que nadie decide por ella.
  insert into public.clients (tenant_id, name, phone, active, portal_session_token, portal_session_expires_at)
  values (v_tenant, 'C232 Clienta Uno', '3010000001', true, v_portal_token1, now() + interval '60 days')
  returning id into v_cliente1;

  insert into public.clients (tenant_id, name, phone, active, portal_session_token, portal_session_expires_at)
  values (v_tenant, 'C232 Clienta Dos', '3010000002', true, v_portal_token2, now() + interval '60 days')
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
    v_branch, v_ticket1, v_branch::text || '/control232-foto1.jpg', 'final', 'Foto 1', v_stylist, false
  );
  v_foto2 := public.create_work_photo(
    v_branch, v_ticket2, v_branch::text || '/control232-foto2.jpg', 'final', 'Foto 2', v_stylist, false
  );

  -- Las reseñas: escritas y ya moderadas/visibles al público, el nombre
  -- todavía sin autorizar -- el estado real de hoy.
  insert into public.reviews (tenant_id, branch_id, ticket_id, client_id, rating, comment, moderation_status, visible_to_public, active)
  values (v_tenant, v_branch, v_ticket1, v_cliente1, 5, 'Control232 comentario clienta uno', 'approved', true, true)
  returning id into v_resena1;
  insert into public.reviews (tenant_id, branch_id, ticket_id, client_id, rating, comment, moderation_status, visible_to_public, active)
  values (v_tenant, v_branch, v_ticket2, v_cliente2, 4, 'Control232 comentario clienta dos', 'approved', true, true)
  returning id into v_resena2;

  -- ==========================================================================
  -- 1. Nadie sin sesión la puede llamar; con sesión, sí (y ella decide).
  -- ==========================================================================
  if not has_function_privilege('anon', 'public.work_photo_authorize_move(uuid, uuid, text)', 'execute')
     and has_function_privilege('authenticated', 'public.work_photo_authorize_move(uuid, uuid, text)', 'execute')
  then
    raise notice 'OK    1  sin sesion no se llama; con sesion decide la funcion';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 1  permisos de work_photo_authorize_move';
  end if;

  -- Desde aquí, como el dueño (la sesión que dejó puesta el fixture).
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);

  -- ==========================================================================
  -- 2. Retirar (a privado) siempre se le permite al dueño.
  -- ==========================================================================
  v_ruta := public.work_photo_authorize_move(v_branch, v_foto1, 'privado');
  if v_ruta = v_branch::text || '/control232-foto1.jpg' then
    raise notice 'OK    2  el dueno puede llevar una foto al almacen privado';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 2  ruta=%', v_ruta;
  end if;

  -- ==========================================================================
  -- 3. A público NO, si no está aprobada ni consentida.
  -- ==========================================================================
  v_capturo := false;
  begin
    perform public.work_photo_authorize_move(v_branch, v_foto1, 'publico');
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;
  if v_capturo and v_error like '%Solo se publica una foto aprobada%' then
    raise notice 'OK    3  una foto sin aprobar ni consentir no se mueve a publico';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 3  capturo=%, mensaje=%', v_capturo, v_error;
  end if;

  -- ==========================================================================
  -- 4. Consentida por ELLA y aprobada por el salón: ahora sí.
  -- ==========================================================================
  perform public.client_consent_set_photo(v_foto1, true, v_portal_token1, null);
  perform public.set_work_photo_portfolio_approval(
    v_branch, v_foto1, true,
    'https://ejemplo.supabase.co/storage/v1/object/public/work-photos/' ||
      v_branch::text || '/control232-foto1.jpg'
  );
  v_ruta := public.work_photo_authorize_move(v_branch, v_foto1, 'publico');
  if v_ruta = v_branch::text || '/control232-foto1.jpg' then
    raise notice 'OK    4  aprobada y consentida, se autoriza moverla a publico';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 4  ruta=%', v_ruta;
  end if;

  -- ==========================================================================
  -- 5. Un destino que no existe se rechaza.
  -- ==========================================================================
  v_capturo := false;
  begin
    perform public.work_photo_authorize_move(v_branch, v_foto1, 'otro');
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;
  if v_capturo and v_error like '%Destino invalido%' then
    raise notice 'OK    5  un destino que no es publico ni privado se rechaza';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 5  capturo=%, mensaje=%', v_capturo, v_error;
  end if;

  -- ==========================================================================
  -- 6. El estilista sube fotos, pero no las mueve: ni a público ni a privado.
  -- ==========================================================================
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_estilista_cuenta::text, 'role', 'authenticated')::text, true);
  v_capturo := false;
  begin
    perform public.work_photo_authorize_move(v_branch, v_foto1, 'privado');
  exception when others then
    v_capturo := true;
  end;
  if v_capturo then
    raise notice 'OK    6  el estilista no puede mover fotos entre almacenes';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 6  el estilista pudo autorizar un movimiento';
  end if;

  -- ==========================================================================
  -- 7. Alguien con sesión pero de ningún negocio, tampoco.
  -- ==========================================================================
  perform set_config('request.jwt.claims',
    json_build_object('sub', gen_random_uuid()::text, 'role', 'authenticated')::text, true);
  v_capturo := false;
  begin
    perform public.work_photo_authorize_move(v_branch, v_foto1, 'privado');
  exception when others then
    v_capturo := true;
  end;
  if v_capturo then
    raise notice 'OK    7  alguien de fuera no puede mover fotos de la sede';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 7  alguien de fuera pudo autorizar un movimiento';
  end if;

  perform set_config('request.jwt.claims', '{}', true);

  raise notice ' ';
  if v_fallos = 0 then
    raise notice '=== CONTROL 232: 7/7 ===';
  else
    raise notice '=== % FALLO(S) EN EL CONTROL 232. Revisar arriba. ===', v_fallos;
  end if;
end
$ctrl$;

rollback;
