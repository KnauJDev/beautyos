-- BeautyOS - Prueba integral reversible del Tramo C3.

begin;

do $$
declare
  v_tenant_id uuid;
  v_owner_user uuid;
  v_primary_branch uuid;
  v_secondary_branch uuid;
  v_foreign_tenant uuid := gen_random_uuid();
  v_foreign_branch uuid;
  v_client_id uuid;
  v_service_id uuid;
  v_stylist_id uuid;
  v_product_id uuid;
  v_ticket_id uuid;
  v_ticket_service_id uuid;
  v_purchase_id uuid;
  v_date date;
  v_received_at timestamptz;
  v_primary_sales_before numeric;
  v_primary_sales_after numeric;
  v_row record;
  v_count integer;
  v_blocked boolean;
begin
  select tm.tenant_id, tm.user_id, b.id
    into v_tenant_id, v_owner_user, v_primary_branch
  from public.tenant_memberships tm
  join public.branches b
    on b.tenant_id = tm.tenant_id
   and b.is_primary
   and b.active
  where tm.role = 'tenant_owner'
    and tm.active
  order by tm.created_at
  limit 1;

  select c.id into v_client_id
  from public.clients c
  where c.tenant_id = v_tenant_id and c.active
  order by c.created_at
  limit 1;

  select s.id into v_service_id
  from public.services s
  where s.tenant_id = v_tenant_id and s.active
  order by s.created_at
  limit 1;

  select st.id into v_stylist_id
  from public.stylists st
  where st.tenant_id = v_tenant_id and st.active
  order by st.created_at
  limit 1;

  select p.id into v_product_id
  from public.products p
  where p.tenant_id = v_tenant_id and p.active
  order by p.created_at
  limit 1;

  if v_owner_user is null or v_client_id is null or v_service_id is null
     or v_stylist_id is null or v_product_id is null then
    raise exception 'La prueba C3 requiere owner, cliente, servicio, estilista y producto activos.';
  end if;

  v_date := (now() at time zone 'America/Bogota')::date;
  v_received_at := (v_date::timestamp + time '12:00') at time zone 'America/Bogota';

  perform set_config('request.jwt.claim.sub', v_owner_user::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  execute 'set local role authenticated';
  select f.total_sales into v_primary_sales_before
  from public.get_branch_financial_summary_v2(v_primary_branch) f;
  execute 'reset role';

  insert into public.branches (
    tenant_id, name, slug, timezone, currency_code, is_primary, active
  ) values (
    v_tenant_id, 'Sede A2 Tramo C3', 'sede-a2-tramo-c3',
    'America/Bogota', 'COP', false, true
  ) returning id into v_secondary_branch;

  insert into public.branch_services (
    tenant_id, branch_id, service_id, price, duration_minutes,
    booking_interval_minutes, visible_to_customer, active
  ) values (
    v_tenant_id, v_secondary_branch, v_service_id,
    123, 45, 15, true, true
  );

  insert into public.branch_stylists (
    tenant_id, branch_id, stylist_id, active
  ) values (
    v_tenant_id, v_secondary_branch, v_stylist_id, true
  );

  insert into public.branch_products (
    tenant_id, branch_id, product_id, current_stock, minimum_stock,
    average_cost, sale_price, visible_for_sale, active
  ) values (
    v_tenant_id, v_secondary_branch, v_product_id,
    777, 70, 11, 22, true, true
  );

  insert into public.tickets (
    tenant_id, branch_id, client_id, scheduled_at, status, channel, notes
  ) values (
    v_tenant_id, v_secondary_branch, v_client_id, v_received_at,
    'cerrado', 'manual', 'Prueba C3 reversible'
  ) returning id into v_ticket_id;

  insert into public.ticket_services (
    tenant_id, branch_id, ticket_id, service_id, stylist_id,
    price, duration_minutes, status
  ) values (
    v_tenant_id, v_secondary_branch, v_ticket_id, v_service_id,
    v_stylist_id, 123, 45, 'finalizado'
  ) returning id into v_ticket_service_id;

  insert into public.ticket_payments (
    tenant_id, branch_id, ticket_id, amount, method, status,
    received_at, created_by, notes
  ) values (
    v_tenant_id, v_secondary_branch, v_ticket_id, 123, 'efectivo',
    'registrado', v_received_at, v_owner_user, 'Prueba C3 reversible'
  );

  insert into public.stylist_commissions (
    tenant_id, branch_id, ticket_id, ticket_service_id, stylist_id,
    service_amount, commission_type, commission_percentage,
    fixed_commission_amount, applies_after_discount, commission_amount,
    status, generated_at, generated_by
  ) values (
    v_tenant_id, v_secondary_branch, v_ticket_id, v_ticket_service_id,
    v_stylist_id, 123, 'fixed', 0, 30, true, 30,
    'generada', v_received_at, v_owner_user
  );

  insert into public.purchases (
    tenant_id, branch_id, supplier_name, purchase_date, invoice_number,
    total_amount, payment_method, notes, active
  ) values (
    v_tenant_id, v_secondary_branch, 'Proveedor C3', v_date, 'C3-001',
    20, 'cash', 'Prueba C3 reversible', true
  ) returning id into v_purchase_id;

  insert into public.purchase_items (
    tenant_id, branch_id, purchase_id, product_id, quantity, unit_cost, notes
  ) values (
    v_tenant_id, v_secondary_branch, v_purchase_id, v_product_id,
    2, 10, 'Prueba C3 reversible'
  );

  insert into public.expenses (
    tenant_id, branch_id, expense_date, category, description,
    amount, payment_method, notes, active
  ) values (
    v_tenant_id, v_secondary_branch, v_date, 'Prueba', 'Gasto C3',
    10, 'cash', 'Prueba C3 reversible', true
  );

  insert into public.inventory_movements (
    tenant_id, branch_id, product_id, movement_type, quantity,
    unit_cost, notes, created_at
  ) values (
    v_tenant_id, v_secondary_branch, v_product_id, 'purchase', 2,
    10, 'Prueba C3 reversible', v_received_at
  );

  perform set_config('request.jwt.claim.sub', v_owner_user::text, true);
  execute 'set local role authenticated';

  select * into v_row
  from public.get_daily_close_v2(v_secondary_branch, v_date);
  if v_row.total_received <> 123 or v_row.cash_received <> 123
     or v_row.total_purchases <> 20 or v_row.total_expenses <> 10
     or v_row.total_commissions <> 30 or v_row.expected_cash <> 93
     or v_row.estimated_result <> 63 then
    raise exception 'El cierre C3 de A2 no coincide con sus cifras aisladas: %.', row_to_json(v_row);
  end if;

  select * into v_row
  from public.get_branch_financial_summary_v2(v_secondary_branch);
  if v_row.total_sales <> 123 or v_row.total_purchases <> 20
     or v_row.total_expenses <> 10 or v_row.total_commissions <> 30
     or v_row.net_result <> 63 then
    raise exception 'El resumen financiero C3 de A2 es incorrecto: %.', row_to_json(v_row);
  end if;

  select count(*) into v_count
  from public.get_commission_summary_v2(v_secondary_branch, v_date) c
  where c.stylist_id = v_stylist_id
    and c.services_count = 1
    and c.service_sales = 123
    and c.commission_total = 30;
  if v_count <> 1 then
    raise exception 'El resumen de comisiones C3 no quedo aislado en A2.';
  end if;

  select count(*) into v_count
  from public.get_sales_report_summary_v2(v_secondary_branch) s
  where s.tickets_count = 1 and s.total_sales = 123;
  if v_count <> 1 then
    raise exception 'El reporte de ventas C3 no quedo aislado en A2.';
  end if;

  select count(*) into v_count
  from public.get_purchases_summary_v2(v_secondary_branch);
  if v_count <> 1 then raise exception 'Compras C3 mezclo sedes.'; end if;

  select count(*) into v_count
  from public.get_purchase_items_summary_v2(v_secondary_branch);
  if v_count <> 1 then raise exception 'Detalle de compras C3 mezclo sedes.'; end if;

  select count(*) into v_count
  from public.get_expenses_summary_v2(v_secondary_branch);
  if v_count <> 1 then raise exception 'Gastos C3 mezclo sedes.'; end if;

  select count(*) into v_count
  from public.get_products_summary_v2(v_secondary_branch) p
  where p.id = v_product_id and p.current_stock = 777
    and p.minimum_stock = 70 and p.purchase_price = 11
    and p.sale_price = 22;
  if v_count <> 1 then
    raise exception 'Productos C3 no uso el stock propio de A2.';
  end if;

  select count(*) into v_count
  from public.get_inventory_movements_summary_v2(v_secondary_branch) m
  where m.quantity = 2 and m.unit_cost = 10;
  if v_count <> 1 then raise exception 'Movimientos C3 mezclo sedes.'; end if;

  select f.total_sales into v_primary_sales_after
  from public.get_branch_financial_summary_v2(v_primary_branch) f;
  if v_primary_sales_after is distinct from v_primary_sales_before then
    raise exception 'A2 altero el resumen financiero visible en A1.';
  end if;

  execute 'reset role';

  insert into public.tenants (
    id, name, business_type, contact_email, whatsapp, active
  ) values (
    v_foreign_tenant, 'Tenant B Tramo C3', 'test',
    'tenant-b-c3@example.invalid', '+570000000303', true
  );
  insert into public.branches (
    tenant_id, name, slug, timezone, currency_code, is_primary, active
  ) values (
    v_foreign_tenant, 'Sede B1 Tramo C3', 'sede-b1-tramo-c3',
    'America/Bogota', 'COP', true, true
  ) returning id into v_foreign_branch;

  perform set_config('request.jwt.claim.sub', v_owner_user::text, true);
  execute 'set local role authenticated';
  v_blocked := false;
  begin
    perform 1 from public.get_branch_financial_summary_v2(v_foreign_branch);
  exception when raise_exception then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'Aislamiento C3 fallido: Owner A consulto Tenant B.';
  end if;
  execute 'reset role';
end;
$$;

rollback;
