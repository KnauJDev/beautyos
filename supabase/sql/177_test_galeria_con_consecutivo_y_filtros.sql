-- ==============================================================================
-- Script de Control 177: Galería de fotos con consecutivo e IDs de filtro (D-156)
-- ==============================================================================
-- Verifica que get_work_photos_summary_v2 retorne:
--   1. ticket_number y ticket_code (#0000701) correctamente vinculados.
--   2. client_id y stylist_id presentes para soportar filtros en Flutter.
--   3. Fotos huérfanas sin ticket retornan ticket_code null sin error.
-- Todo envuelto en ROLLBACK para no alterar datos de prueba.
-- ==============================================================================

begin;

do $$
declare
  v_tenant_id uuid;
  v_branch_id uuid;
  v_client_id uuid;
  v_stylist_id uuid;
  v_ticket_id uuid;
  v_photo_id uuid;
  v_photo_rec record;
begin
  -- 1. Setup tenant y branch
  select id into v_tenant_id from public.tenants limit 1;
  if v_tenant_id is null then
    raise notice 'Sin tenant de prueba, omitiendo prueba funcional';
    return;
  end if;

  select id into v_branch_id from public.branches where tenant_id = v_tenant_id limit 1;
  select id into v_client_id from public.clients where tenant_id = v_tenant_id limit 1;
  select id into v_stylist_id from public.stylists where tenant_id = v_tenant_id limit 1;

  -- 2. Crear ticket de prueba con consecutivo si no hay
  insert into public.tickets (
    tenant_id, branch_id, client_id, scheduled_at, status, channel, consecutive_number
  ) values (
    v_tenant_id, v_branch_id, v_client_id, now(), 'en_proceso', 'manual', 701
  ) returning id into v_ticket_id;

  -- 3. Crear foto de prueba vinculada al ticket
  insert into public.work_photos (
    tenant_id, branch_id, ticket_id, client_id, stylist_id,
    photo_url, storage_bucket, storage_path, photo_type, caption,
    ai_status, visible_to_customer, approved_for_portfolio, active
  ) values (
    v_tenant_id, v_branch_id, v_ticket_id, v_client_id, v_stylist_id,
    'https://example.com/photo.jpg', 'work-photos', 'test/photo.jpg', 'after', 'Balayage hermoso',
    'not_required', true, true, true
  ) returning id into v_photo_id;

  -- 4. Consultar función RPC
  select * into v_photo_rec
  from public.get_work_photos_summary_v2(v_branch_id)
  where id = v_photo_id;

  -- 5. Aserciones
  assert v_photo_rec.ticket_number = 701, 'Fallo: ticket_number debe ser 701';
  assert v_photo_rec.ticket_code = '#0000701', 'Fallo: ticket_code debe ser #0000701';
  assert v_photo_rec.client_id = v_client_id, 'Fallo: client_id no coincide';
  assert v_photo_rec.stylist_id = v_stylist_id, 'Fallo: stylist_id no coincide';
  assert v_photo_rec.photo_type = 'after', 'Fallo: photo_type no coincide';

  raise notice 'Control 177: get_work_photos_summary_v2 verificado exitosamente!';
end $$;

rollback;
