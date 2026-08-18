-- ==============================================================================
-- Script de Control 177: Galería de fotos con consecutivo e IDs de filtro (D-156)
-- ==============================================================================
-- Verifica que get_work_photos_summary_v2 retorne:
--   1. ticket_number y ticket_code (#0000001) correctamente vinculados.
--   2. client_id y stylist_id presentes para soportar filtros en Flutter.
--
-- Crea su propio tenant de prueba desechable (mismo patrón que los controles
-- 175 y 176), en vez de tomar con "limit 1" un tenant ya existente: así no
-- depende de qué datos haya en la base donde se ejecute, ni arriesga colisionar
-- con el consecutivo real de un negocio real.
--
-- El ticket_number y ticket_code NO se insertan a mano: el trigger
-- tickets_set_number (D-117) los asigna solo al insertar y los congela
-- después, así que aquí se leen de vuelta con RETURNING en lugar de asumir
-- un valor fijo.
--
-- Todo envuelto en ROLLBACK para no alterar datos de prueba.
-- ==============================================================================

begin;

do $$
declare
  v_tenant_id uuid;
  v_user_id uuid := '00000000-0000-0000-0000-000000000177'::uuid;
  v_branch_id uuid;
  v_client_id uuid;
  v_stylist_id uuid;
  v_ticket_id uuid;
  v_ticket_number bigint;
  v_ticket_code text;
  v_photo_id uuid;
  v_photo_rec record;
begin
  -- 1. Crear tenant de prueba
  insert into public.tenants (id, name, slug)
  values (gen_random_uuid(), 'Tenant Test Control 177', 'tenant-test-177')
  returning id into v_tenant_id;

  -- 2. Crear sede
  insert into public.branches (tenant_id, name, address)
  values (v_tenant_id, 'Sede Principal 177', 'Calle 85 # 11-42')
  returning id into v_branch_id;

  -- 3. Crear perfil de owner
  insert into public.user_profiles (id, tenant_id, user_id, email, full_name, role, active)
  values (gen_random_uuid(), v_tenant_id, v_user_id, 'owner177@salonymas.com', 'Dueño 177', 'tenant_owner', true);

  -- 4. Crear cliente y estilista
  insert into public.clients (tenant_id, name, phone, active)
  values (v_tenant_id, 'Clienta Test 177', '+573009990177', true)
  returning id into v_client_id;

  insert into public.stylists (tenant_id, branch_id, name, active)
  values (v_tenant_id, v_branch_id, 'Estilista Test 177', true)
  returning id into v_stylist_id;

  -- Simular sesion del usuario de prueba
  perform set_config('request.jwt.claim.sub', v_user_id::text, true);

  -- 5. Crear ticket. El numero y el codigo los asigna el trigger
  -- tickets_set_number (D-117): no se insertan a mano, se leen de vuelta.
  insert into public.tickets (tenant_id, branch_id, client_id, scheduled_at, status, channel)
  values (v_tenant_id, v_branch_id, v_client_id, now(), 'en_proceso', 'manual')
  returning id, ticket_number, ticket_code into v_ticket_id, v_ticket_number, v_ticket_code;

  -- 6. Crear foto de prueba vinculada al ticket
  insert into public.work_photos (
    tenant_id, branch_id, ticket_id, client_id, stylist_id,
    photo_url, storage_bucket, storage_path, photo_type, caption,
    ai_status, visible_to_customer, approved_for_portfolio, active
  ) values (
    v_tenant_id, v_branch_id, v_ticket_id, v_client_id, v_stylist_id,
    'https://example.com/photo.jpg', 'work-photos', 'test/photo.jpg', 'after', 'Balayage hermoso',
    'not_required', true, true, true
  ) returning id into v_photo_id;

  -- 7. Consultar función RPC
  select * into v_photo_rec
  from public.get_work_photos_summary_v2(v_branch_id)
  where id = v_photo_id;

  -- 8. Aserciones
  assert v_photo_rec.ticket_number = v_ticket_number,
    'Fallo: ticket_number debe coincidir con el asignado por el trigger tickets_set_number';
  assert v_photo_rec.ticket_code = '#' || lpad(v_ticket_number::text, 7, '0'),
    'Fallo: ticket_code debe ser "#" + el consecutivo con 7 digitos';
  assert v_photo_rec.client_id = v_client_id, 'Fallo: client_id no coincide';
  assert v_photo_rec.stylist_id = v_stylist_id, 'Fallo: stylist_id no coincide';
  assert v_photo_rec.photo_type = 'after', 'Fallo: photo_type no coincide';

  raise notice 'Control 177: get_work_photos_summary_v2 verificado exitosamente (tenant aislado, ticket %).', v_ticket_code;
end $$;

rollback;
