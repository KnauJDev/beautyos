-- BeautyOS - Pruebas de compatibilidad e aislamiento del Tramo B.
-- Ejecutar exclusivamente en ensayo; todo termina con ROLLBACK.

begin;

do $$
declare
  v_tenant_id uuid;
  v_primary_branch uuid;
  v_other_branch uuid;
  v_foreign_tenant uuid := gen_random_uuid();
  v_foreign_branch uuid;
  v_foreign_client uuid;
  v_client_id uuid;
  v_service_id uuid;
  v_stylist_id uuid;
  v_product_id uuid;
  v_ticket_id uuid;
  v_other_ticket_id uuid;
  v_ticket_service_id uuid;
  v_purchase_id uuid;
  v_item_id uuid;
  v_photo_id uuid;
  v_review_id uuid;
  v_branch_id uuid;
  v_blocked boolean;
begin
  select b.tenant_id, b.id
    into v_tenant_id, v_primary_branch
  from public.branches b
  where b.is_primary and b.active
  order by b.id
  limit 1;

  select id into v_client_id from public.clients where tenant_id=v_tenant_id order by id limit 1;
  select id into v_service_id from public.services where tenant_id=v_tenant_id order by id limit 1;
  select id into v_stylist_id from public.stylists where tenant_id=v_tenant_id order by id limit 1;
  select id into v_product_id from public.products where tenant_id=v_tenant_id order by id limit 1;

  if v_tenant_id is null or v_client_id is null or v_service_id is null
     or v_stylist_id is null or v_product_id is null then
    raise exception 'La prueba requiere tenant, sede principal, cliente, servicio, estilista y producto.';
  end if;

  -- Compatibilidad: los INSERT heredados no envian branch_id.
  insert into public.tickets (tenant_id, client_id, status, channel, notes)
  values (v_tenant_id, v_client_id, 'solicitado', 'manual', 'Prueba Tramo B')
  returning id, branch_id into v_ticket_id, v_branch_id;
  if v_branch_id is distinct from v_primary_branch then
    raise exception 'Compatibilidad fallida: ticket heredado no recibio sede principal.';
  end if;

  insert into public.ticket_services (
    tenant_id, ticket_id, service_id, stylist_id, price, duration_minutes, status
  ) values (
    v_tenant_id, v_ticket_id, v_service_id, v_stylist_id, 1, 15, 'pendiente'
  ) returning id, branch_id into v_ticket_service_id, v_branch_id;
  if v_branch_id is distinct from v_primary_branch then
    raise exception 'Compatibilidad fallida: servicio no heredo sede del ticket.';
  end if;

  insert into public.purchases (
    tenant_id, supplier_name, total_amount, payment_method, notes
  ) values (
    v_tenant_id, 'Proveedor prueba Tramo B', 1, 'cash', 'Rollback automatico'
  ) returning id, branch_id into v_purchase_id, v_branch_id;
  if v_branch_id is distinct from v_primary_branch then
    raise exception 'Compatibilidad fallida: compra heredada no recibio sede principal.';
  end if;

  insert into public.purchase_items (
    tenant_id, purchase_id, product_id, quantity, unit_cost, notes
  ) values (
    v_tenant_id, v_purchase_id, v_product_id, 1, 1, 'Rollback automatico'
  ) returning id, branch_id into v_item_id, v_branch_id;
  if v_branch_id is distinct from v_primary_branch then
    raise exception 'Compatibilidad fallida: item no heredo sede de la compra.';
  end if;

  insert into public.work_photos (
    tenant_id, photo_url, caption
  ) values (
    v_tenant_id, 'https://example.invalid/tramo-b.jpg', 'Prueba Tramo B'
  ) returning id, branch_id into v_photo_id, v_branch_id;
  if v_branch_id is distinct from v_primary_branch then
    raise exception 'Compatibilidad fallida: foto sin ticket no recibio sede principal.';
  end if;

  insert into public.reviews (
    tenant_id, rating, comment
  ) values (
    v_tenant_id, 5, 'Prueba Tramo B'
  ) returning id, branch_id into v_review_id, v_branch_id;
  if v_branch_id is distinct from v_primary_branch then
    raise exception 'Compatibilidad fallida: resena sin ticket no recibio sede principal.';
  end if;

  insert into public.branches (tenant_id, name, slug, active, is_primary)
  values (v_tenant_id, 'Sede aislada Tramo B', 'sede-aislada-tramo-b', true, false)
  returning id into v_other_branch;

  insert into public.tenants (
    id, name, business_type, contact_email, whatsapp, active
  ) values (
    v_foreign_tenant, 'Tenant ajeno Tramo B', 'test',
    'tramo-b@example.invalid', '+570000000099', true
  );
  insert into public.branches (
    tenant_id, name, slug, active, is_primary
  ) values (
    v_foreign_tenant, 'Sede tenant ajeno', 'sede-tenant-ajeno', true, true
  ) returning id into v_foreign_branch;
  insert into public.clients (tenant_id, name, phone)
  values (v_foreign_tenant, 'Cliente ajeno Tramo B', '+570000000098')
  returning id into v_foreign_client;

  v_blocked := false;
  begin
    insert into public.tickets (
      tenant_id, branch_id, client_id, status, channel
    ) values (
      v_tenant_id, v_foreign_branch, v_client_id, 'solicitado', 'manual'
    );
  exception when raise_exception or foreign_key_violation then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'Aislamiento fallido: se acepto una sede de otro tenant.';
  end if;

  v_blocked := false;
  begin
    insert into public.tickets (
      tenant_id, client_id, status, channel
    ) values (
      v_tenant_id, v_foreign_client, 'solicitado', 'manual'
    );
  exception when foreign_key_violation then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'Aislamiento fallido: se acepto un cliente de otro tenant.';
  end if;

  -- Un registro raiz puede nacer en una sede valida, pero sus hijos no pueden
  -- usar catalogos que esa sede no tenga configurados.
  insert into public.tickets (
    tenant_id, branch_id, client_id, status, channel, notes
  ) values (
    v_tenant_id, v_other_branch, v_client_id, 'solicitado', 'manual', 'Aislamiento Tramo B'
  ) returning id into v_other_ticket_id;

  v_blocked := false;
  begin
    insert into public.ticket_services (
      tenant_id, ticket_id, service_id, stylist_id, price, duration_minutes, status
    ) values (
      v_tenant_id, v_other_ticket_id, v_service_id, v_stylist_id, 1, 15, 'pendiente'
    );
  exception when foreign_key_violation then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'Aislamiento fallido: se acepto un servicio no configurado en la sede.';
  end if;

  v_blocked := false;
  begin
    insert into public.ticket_history (
      tenant_id, branch_id, ticket_id, event_type, new_status, created_by
    ) values (
      v_tenant_id, v_primary_branch, v_other_ticket_id, 'status_changed', 'solicitado', gen_random_uuid()
    );
  exception when raise_exception or foreign_key_violation then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'Aislamiento fallido: se acepto historial con sede distinta al ticket.';
  end if;

  v_blocked := false;
  begin
    update public.tickets set branch_id=v_other_branch where id=v_ticket_id;
  exception when raise_exception then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'Integridad fallida: se permitio mover directamente un ticket historico.';
  end if;
end;
$$;

rollback;
