-- Control 176: Verificación de Reportes V3 por períodos, métodos de pago, arqueo y comparación (Paso 4.7 / D-154)
--
-- Ejecuta en un bloque transaccional con ROLLBACK para no dejar registros de prueba.

begin;

do $$
declare
  v_tenant_id uuid;
  v_user_id uuid := '00000000-0000-0000-0000-000000000176'::uuid;
  v_branch_id uuid;
  v_service_id uuid;
  v_stylist_id uuid;
  v_client_id uuid;
  v_ticket_prev uuid;
  v_ticket_curr1 uuid;
  v_ticket_curr2 uuid;
  v_ticket_curr3 uuid;
  v_res record;
  v_today date := current_date;
  v_prev_date date := current_date - 1;
begin
  -- 1. Crear tenant de prueba
  insert into public.tenants (id, name, slug)
  values (gen_random_uuid(), 'Tenant Test Control 176', 'tenant-test-176')
  returning id into v_tenant_id;

  -- 2. Crear sede
  insert into public.branches (tenant_id, name, address)
  values (v_tenant_id, 'Sede Principal 176', 'Carrera 7 # 72-01')
  returning id into v_branch_id;

  -- 3. Crear perfil de owner
  insert into public.user_profiles (id, tenant_id, user_id, email, full_name, role, active)
  values (gen_random_uuid(), v_tenant_id, v_user_id, 'owner176@salonymas.com', 'Dueño 176', 'tenant_owner', true);

  -- 4. Crear un servicio y un estilista
  insert into public.services (tenant_id, name, price, duration_minutes, active)
  values (v_tenant_id, 'Balayage Control 176', 150000, 120, true)
  returning id into v_service_id;

  insert into public.stylists (tenant_id, branch_id, name, active)
  values (v_tenant_id, v_branch_id, 'Estilista Estrella 176', true)
  returning id into v_stylist_id;

  insert into public.clients (tenant_id, name, phone, active)
  values (v_tenant_id, 'Clienta Test 176', '+573009990176', true)
  returning id into v_client_id;

  -- Simular sesion del usuario de prueba
  perform set_config('request.jwt.claim.sub', v_user_id::text, true);

  -- 5. Insertar datos en el PERIODO PREVIO (Ayer)
  insert into public.tickets (tenant_id, branch_id, client_id, scheduled_at, closed_at, status, channel)
  values (v_tenant_id, v_branch_id, v_client_id, (v_prev_date::text || ' 10:00:00-05')::timestamptz, (v_prev_date::text || ' 12:00:00-05')::timestamptz, 'cerrado', 'manual')
  returning id into v_ticket_prev;

  insert into public.ticket_payments (tenant_id, branch_id, ticket_id, amount, method, status, received_at)
  values (v_tenant_id, v_branch_id, v_ticket_prev, 100000, 'efectivo', 'registrado', (v_prev_date::text || ' 12:00:00-05')::timestamptz);

  insert into public.expenses (tenant_id, branch_id, description, amount, payment_method, expense_date, active)
  values (v_tenant_id, v_branch_id, 'Gasto ayer', 20000, 'cash', v_prev_date, true);

  -- 6. Insertar datos en el PERIODO ACTUAL (Hoy)
  -- Ticket 1: Pago Efectivo $50.000
  insert into public.tickets (tenant_id, branch_id, client_id, scheduled_at, closed_at, status, channel)
  values (v_tenant_id, v_branch_id, v_client_id, (v_today::text || ' 09:00:00-05')::timestamptz, (v_today::text || ' 10:00:00-05')::timestamptz, 'cerrado', 'manual')
  returning id into v_ticket_curr1;
  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant_id, v_branch_id, v_ticket_curr1, v_service_id, v_stylist_id, 50000, 60, 'finalizado');
  insert into public.ticket_payments (tenant_id, branch_id, ticket_id, amount, method, status, received_at)
  values (v_tenant_id, v_branch_id, v_ticket_curr1, 50000, 'efectivo', 'registrado', (v_today::text || ' 10:00:00-05')::timestamptz);

  -- Ticket 2: Pago Transferencia $80.000 (Nequi)
  insert into public.tickets (tenant_id, branch_id, client_id, scheduled_at, closed_at, status, channel)
  values (v_tenant_id, v_branch_id, v_client_id, (v_today::text || ' 11:00:00-05')::timestamptz, (v_today::text || ' 12:00:00-05')::timestamptz, 'cerrado', 'manual')
  returning id into v_ticket_curr2;
  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant_id, v_branch_id, v_ticket_curr2, v_service_id, v_stylist_id, 80000, 60, 'finalizado');
  insert into public.ticket_payments (tenant_id, branch_id, ticket_id, amount, method, status, received_at)
  values (v_tenant_id, v_branch_id, v_ticket_curr2, 80000, 'transferencia', 'registrado', (v_today::text || ' 12:00:00-05')::timestamptz);

  -- Ticket 3: Pago Tarjeta $70.000
  insert into public.tickets (tenant_id, branch_id, client_id, scheduled_at, closed_at, status, channel)
  values (v_tenant_id, v_branch_id, v_client_id, (v_today::text || ' 14:00:00-05')::timestamptz, (v_today::text || ' 15:00:00-05')::timestamptz, 'cerrado', 'manual')
  returning id into v_ticket_curr3;
  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant_id, v_branch_id, v_ticket_curr3, v_service_id, v_stylist_id, 70000, 60, 'finalizado');
  insert into public.ticket_payments (tenant_id, branch_id, ticket_id, amount, method, status, received_at)
  values (v_tenant_id, v_branch_id, v_ticket_curr3, 70000, 'tarjeta', 'registrado', (v_today::text || ' 15:00:00-05')::timestamptz);

  -- Compra en efectivo: $30.000
  insert into public.purchases (tenant_id, branch_id, supplier_name, purchase_date, invoice_number, total_amount, payment_method, active)
  values (v_tenant_id, v_branch_id, 'Proveedor Tintes', v_today, 'FAC-101', 30000, 'cash', true);

  -- Gasto operativo no en efectivo: $10.000
  insert into public.expenses (tenant_id, branch_id, description, amount, payment_method, expense_date, active)
  values (v_tenant_id, v_branch_id, 'Gasto domicilios', 10000, 'transfer', v_today, true);

  -- Comisión de estilista: $40.000
  insert into public.stylist_commissions (tenant_id, branch_id, stylist_id, ticket_service_id, service_amount, commission_rate, commission_amount, status, generated_at)
  values (v_tenant_id, v_branch_id, v_stylist_id, gen_random_uuid(), 100000, 0.40, 40000, 'generada', (v_today::text || ' 12:00:00-05')::timestamptz);

  -- ==============================================================
  -- VERIFICACIONES
  -- ==============================================================

  -- Ejecutar RPC para HOY (1 día de rango -> compara automáticamente con AYER)
  select * into v_res from public.get_branch_reports_v3(v_branch_id, v_today, v_today);

  -- Comprobación 1: Ingresos totales y por método de pago
  assert v_res.total_received = 200000, 'Prueba 1 falló: total_received debe ser 200000 (50k+80k+70k)';
  assert v_res.payments_count = 3, 'Prueba 1 falló: payments_count debe ser 3';
  assert v_res.cash_received = 50000, 'Prueba 1 falló: cash_received debe ser 50000';
  assert v_res.transfer_received = 80000, 'Prueba 1 falló: transfer_received debe ser 80000';
  assert v_res.card_received = 70000, 'Prueba 1 falló: card_received debe ser 70000';
  assert v_res.other_received = 0, 'Prueba 1 falló: other_received debe ser 0';

  -- Comprobación 2: Egresos y Arqueo de efectivo
  assert v_res.total_purchases = 30000, 'Prueba 2 falló: total_purchases debe ser 30000';
  assert v_res.cash_purchases = 30000, 'Prueba 2 falló: cash_purchases debe ser 30000';
  assert v_res.total_expenses = 10000, 'Prueba 2 falló: total_expenses debe ser 10000';
  assert v_res.total_commissions = 40000, 'Prueba 2 falló: total_commissions debe ser 40000';
  -- Arqueo esperado en caja: Efectivo recibido (50k) - Compras efectivo (30k) = 20k
  assert v_res.expected_cash = 20000, 'Prueba 2 falló: expected_cash debe ser 20000';
  -- Resultado neto: Ingresos (200k) - Compras (30k) - Gastos (10k) - Comisiones (40k) = 120k
  assert v_res.net_result = 120000, 'Prueba 2 falló: net_result debe ser 120000';

  -- Comprobación 3: Comparación con período previo (Ayer)
  assert v_res.prev_total_received = 100000, 'Prueba 3 falló: prev_total_received debe ser 100000';
  assert v_res.prev_net_result = 80000, 'Prueba 3 falló: prev_net_result debe ser 80000 (100k - 20k)';

  -- Comprobación 4: JSONs de desglose
  assert jsonb_array_length(v_res.commissions_by_stylist) = 1, 'Prueba 4 falló: commissions_by_stylist debe tener 1 registro';
  assert jsonb_array_length(v_res.sales_by_service) >= 1, 'Prueba 4 falló: sales_by_service debe tener al menos 1 registro';

  raise notice 'Control 176: Las 4 comprobaciones de reportes v3 pasaron exitosamente en verde.';
end;
$$;

rollback;
