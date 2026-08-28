-- D-165: la página pública completa del negocio -- servicios, portafolio,
-- equipo, reseñas, horarios y el botón de reserva (Fase 5, paso 5.5).
--
-- POR QUE ESTE ARCHIVO
--
-- Las cuatro RPC nuevas son de lectura pública (rol "anon", sin sesión) y
-- cada una tiene una regla de filtrado que, si se rompe, se nota de dos
-- formas opuestas y ambas malas: o un negocio muestra algo que no debería
-- (una foto sin aprobar, una reseña sin moderar, un estilista dado de baja),
-- o la página pública se ve vacía cuando sí hay contenido real.
--
-- Se usa un tenant de prueba dedicado y aislado (no uno real) porque estas
-- RPC dependen de combinaciones de banderas (aprobada/visible, activo/
-- inactivo, visible_to_public) que un tenant real puede no tener en los dos
-- estados a la vez -- crearlas a propósito es la única forma de probar el
-- filtro, no solo el camino feliz.
--
-- COMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\185_test_perfil_publico_completo.sql"
--
-- TERMINA EN ROLLBACK. No deja ni una fila.

begin;

do $$
declare
  v_tenant uuid;
  v_branch uuid;
  v_client uuid;
  v_ticket uuid;
  v_service_visible uuid;
  v_service_oculto uuid;
  v_stylist_activo uuid;
  v_stylist_inactivo uuid;
  v_foto_publica uuid;
  v_review_publica uuid;
  v_slug_info record;
  v_count integer;
  v_avg numeric;
  v_total integer;
  v_fallos integer := 0;
  v_error text;
begin
  -- =====================================================================
  -- Fixture: un negocio aislado, con una de cada cosa en los dos estados
  -- que importan (visible/oculto, activo/inactivo, aprobado/sin aprobar).
  -- =====================================================================
  insert into public.tenants (
    name, slug, contact_email, whatsapp, city, active
  ) values (
    'Salon Publico D165', 'salon-publico-d165',
    'salon.publico.d165@salonymas.com', '3009998877', 'Bogotá', true
  )
  returning id into v_tenant;

  insert into public.branches (
    tenant_id, name, slug, address, city, is_primary, active
  ) values (
    v_tenant, 'Sede Principal', 'principal', 'Calle Publica 123', 'Bogotá', true, true
  )
  returning id into v_branch;

  insert into public.business_hours (
    tenant_id, branch_id, day_of_week, opens_at, closes_at, is_open
  ) values
    (v_tenant, v_branch, 1, time '09:00', time '18:00', true),
    (v_tenant, v_branch, 7, null, null, false);

  insert into public.services (
    tenant_id, name, category, duration_minutes, price, active, visible_to_customer
  ) values (
    v_tenant, 'Corte Publico', 'Cortes', 45, 35000, true, true
  )
  returning id into v_service_visible;

  insert into public.services (
    tenant_id, name, category, duration_minutes, price, active, visible_to_customer
  ) values (
    v_tenant, 'Servicio Oculto', 'Cortes', 30, 20000, true, false
  )
  returning id into v_service_oculto;

  insert into public.stylists (tenant_id, name, active)
  values (v_tenant, 'Estilista Activa', true)
  returning id into v_stylist_activo;

  insert into public.stylists (tenant_id, name, active)
  values (v_tenant, 'Estilista Retirada', false)
  returning id into v_stylist_inactivo;

  insert into public.clients (tenant_id, name, phone)
  values (v_tenant, 'Clienta de Prueba', '3001112233')
  returning id into v_client;

  insert into public.tickets (
    tenant_id, branch_id, client_id, status, channel, scheduled_at
  ) values (
    v_tenant, v_branch, v_client, 'cerrado', 'manual', now()
  )
  returning id into v_ticket;

  -- Foto aprobada Y visible: la unica que debe aparecer en el portafolio.
  insert into public.work_photos (
    tenant_id, branch_id, ticket_id, client_id, stylist_id,
    storage_bucket, storage_path, photo_url, photo_type, caption,
    visible_to_customer, approved_for_portfolio
  ) values (
    v_tenant, v_branch, v_ticket, v_client, v_stylist_activo,
    'work-photos-public', 'd165/publica.jpg', 'https://ejemplo.com/publica.jpg',
    'despues', 'Resultado final', true, true
  )
  returning id into v_foto_publica;

  -- Aprobada para portafolio pero NO visible al cliente: no debe aparecer.
  insert into public.work_photos (
    tenant_id, branch_id, ticket_id, client_id, stylist_id,
    storage_bucket, storage_path, photo_url, photo_type, caption,
    visible_to_customer, approved_for_portfolio
  ) values (
    v_tenant, v_branch, v_ticket, v_client, v_stylist_activo,
    'work-photos-private', 'd165/oculta.jpg', null,
    'antes', 'Sin aprobar todavia', false, true
  );

  -- Reseña visible al publico: la unica que debe contar en el promedio.
  insert into public.reviews (
    tenant_id, branch_id, ticket_id, client_id, rating, comment,
    moderation_status, visible_to_public, active
  ) values (
    v_tenant, v_branch, v_ticket, v_client, 5, 'Excelente atencion',
    'approved', true, true
  )
  returning id into v_review_publica;

  -- Reseña pendiente de moderacion: no debe contar ni aparecer.
  insert into public.reviews (
    tenant_id, branch_id, client_id, rating, comment,
    moderation_status, visible_to_public, active
  ) values (
    v_tenant, v_branch, v_client, 1, 'Reseña sin moderar',
    'pending', false, true
  );

  -- =====================================================================
  -- CASO 1: get_public_salon_by_slug -- primary_branch_id y business_hours.
  -- =====================================================================
  select * into v_slug_info
  from public.get_public_salon_by_slug('salon-publico-d165');

  if v_slug_info.primary_branch_id = v_branch then
    raise notice 'OK  1a  primary_branch_id apunta a la sede principal correcta';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 1a  se esperaba primary_branch_id = %; llego %',
      v_branch, v_slug_info.primary_branch_id;
  end if;

  if jsonb_array_length(v_slug_info.business_hours) = 2 then
    raise notice 'OK  1b  business_hours trae los 2 dias sembrados';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 1b  se esperaban 2 dias en business_hours; llegaron %',
      jsonb_array_length(v_slug_info.business_hours);
  end if;

  -- =====================================================================
  -- CASO 2: get_public_salon_services -- solo activo y visible al cliente.
  -- =====================================================================
  select count(*) into v_count
  from public.get_public_salon_services(v_tenant);

  if v_count = 1 then
    raise notice 'OK  2a  solo aparece 1 servicio (el visible), no el oculto';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 2a  se esperaba 1 servicio; llegaron %', v_count;
  end if;

  if exists (
    select 1 from public.get_public_salon_services(v_tenant)
    where id = v_service_visible
      and name = 'Corte Publico'
      and description = 'Cortes'
      and duration_minutes = 45
      and price_cop = 35000
  ) then
    raise notice 'OK  2b  el servicio visible trae nombre, categoria como "description", duracion y precio correctos';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 2b  los datos del servicio visible no coinciden';
  end if;

  if not exists (
    select 1 from public.get_public_salon_services(v_tenant) where id = v_service_oculto
  ) then
    raise notice 'OK  2c  el servicio marcado no-visible-al-cliente no aparece';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 2c  el servicio oculto aparecio en el catalogo publico';
  end if;

  -- =====================================================================
  -- CASO 3: get_public_salon_portfolio -- aprobada Y visible, nada mas.
  -- =====================================================================
  select count(*) into v_count
  from public.get_public_salon_portfolio(v_tenant);

  if v_count = 1 then
    raise notice 'OK  3a  solo aparece 1 foto (aprobada y visible)';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 3a  se esperaba 1 foto; llegaron %', v_count;
  end if;

  if exists (
    select 1 from public.get_public_salon_portfolio(v_tenant) where id = v_foto_publica
  ) then
    raise notice 'OK  3b  es exactamente la foto aprobada y visible';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 3b  la foto publica esperada no aparecio';
  end if;

  -- =====================================================================
  -- CASO 4: get_public_salon_team -- solo estilistas activos.
  -- =====================================================================
  select count(*) into v_count
  from public.get_public_salon_team(v_tenant);

  if v_count = 1 then
    raise notice 'OK  4a  solo aparece 1 estilista (el activo)';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 4a  se esperaba 1 estilista; llegaron %', v_count;
  end if;

  if not exists (
    select 1 from public.get_public_salon_team(v_tenant) where id = v_stylist_inactivo
  ) then
    raise notice 'OK  4b  el estilista retirado no aparece en el equipo publico';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 4b  un estilista inactivo aparecio en el equipo publico';
  end if;

  -- =====================================================================
  -- CASO 5: get_public_salon_reviews -- promedio, total y solo lo moderado.
  -- =====================================================================
  select count(*) into v_count
  from public.get_public_salon_reviews(v_tenant);

  if v_count = 1 then
    raise notice 'OK  5a  solo aparece 1 reseña (la aprobada y visible al publico)';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 5a  se esperaba 1 reseña; llegaron %', v_count;
  end if;

  select avg_rating, total_reviews into v_avg, v_total
  from public.get_public_salon_reviews(v_tenant)
  limit 1;

  if v_avg = 5.00 and v_total = 1 then
    raise notice 'OK  5b  promedio 5.00 y total 1, sin contar la reseña pendiente de moderar';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 5b  se esperaba promedio 5.00 y total 1; llego % y %', v_avg, v_total;
  end if;

  if not exists (
    select 1 from public.get_public_salon_reviews(v_tenant) where comment = 'Reseña sin moderar'
  ) then
    raise notice 'OK  5c  la reseña pendiente de moderar no aparece en la lista publica';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 5c  la reseña sin moderar aparecio en la lista publica';
  end if;

  -- =====================================================================
  -- CASO 6: un tenant sin nada de esto -- cero filas, sin explotar.
  -- =====================================================================
  select count(*) into v_count from public.get_public_salon_services(gen_random_uuid());
  if v_count = 0 then
    raise notice 'OK  6a  un tenant sin servicios da cero filas, no un error';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 6a  un tenant inexistente devolvio % servicios', v_count;
  end if;

  select count(*) into v_count from public.get_public_salon_reviews(gen_random_uuid());
  if v_count = 0 then
    raise notice 'OK  6b  un tenant sin reseñas da cero filas, no un error';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 6b  un tenant inexistente devolvio % reseñas', v_count;
  end if;

  -- =====================================================================
  raise notice ' ';
  if v_fallos = 0 then
    raise notice '=== TODAS LAS PRUEBAS DEL PERFIL PUBLICO COMPLETO PASARON ===';
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
