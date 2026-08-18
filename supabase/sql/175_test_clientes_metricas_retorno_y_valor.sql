-- Control 175: Verificación de métricas de retorno, valor y cadencia de clientes (Paso 4.6 / D-153)
--
-- Ejecuta en un bloque transaccional con ROLLBACK para no dejar registros de prueba.

begin;

do $$
declare
  v_tenant_id uuid;
  v_owner_user_id uuid := gen_random_uuid();
  v_branch_id uuid;
  v_client1_id uuid;
  v_client2_id uuid;
  v_client3_id uuid;
  v_client4_id uuid;
  v_ticket_id uuid;
  v_service_id uuid;
  v_res record;
begin
  -- 1. Crear tenant de prueba
  insert into public.tenants (name, business_type, contact_email, whatsapp, is_demo, active)
  values ('Centro Estética Control 175', 'peluqueria', 'control175@salonymas.com', '+573001112233', true, true)
  returning id into v_tenant_id;

  -- 2. Auth y membresía
  insert into auth.users (id, email)
  values (v_owner_user_id, 'owner_175_' || floor(random()*100000)::text || '@salonymas.com');

  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant_id, v_owner_user_id, 'tenant_owner', true);

  perform set_config('request.jwt.claim.sub', v_owner_user_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  -- 3. Crear sede
  insert into public.branches (tenant_id, name, slug, timezone, currency_code, is_primary, active)
  values (v_tenant_id, 'Sede Principal 175', 'sede-175-' || floor(random()*100000)::text, 'America/Bogota', 'COP', true, true)
  returning id into v_branch_id;

  -- 4. Crear un servicio y vincularlo a la sede
  insert into public.services (tenant_id, name, price, duration_minutes, active)
  values (v_tenant_id, 'Corte Control 175', 50000, 45, true)
  returning id into v_service_id;

  insert into public.branch_services (tenant_id, branch_id, service_id, price, duration_minutes, active)
  values (v_tenant_id, v_branch_id, v_service_id, 50000, 45, true);

  -- 5. Crear clientes
  -- Cliente 1: Sin visitas
  insert into public.clients (tenant_id, name, phone, active)
  values (v_tenant_id, 'Cliente Uno Sin Visitas', '+573001110001', true)
  returning id into v_client1_id;

  -- Cliente 2: 1 visita reciente ($50.000)
  insert into public.clients (tenant_id, name, phone, active)
  values (v_tenant_id, 'Cliente Dos Una Visita', '+573001110002', true)
  returning id into v_client2_id;

  insert into public.tickets (tenant_id, branch_id, client_id, scheduled_at, closed_at, status, channel)
  values (v_tenant_id, v_branch_id, v_client2_id, now() - interval '5 days', now() - interval '5 days', 'cerrado', 'manual')
  returning id into v_ticket_id;

  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, price, duration_minutes, status)
  values (v_tenant_id, v_branch_id, v_ticket_id, v_service_id, 50000, 45, 'finalizado');

  insert into public.ticket_payments (tenant_id, branch_id, ticket_id, amount, method, status)
  values (v_tenant_id, v_branch_id, v_ticket_id, 50000, 'efectivo', 'registrado');

  -- Cliente 3: 3 visitas espaciadas (Día -40 $60.000, Día -20 $80.000, Día -2 $100.000)
  insert into public.clients (tenant_id, name, phone, active)
  values (v_tenant_id, 'Cliente Tres VIP Recurrente', '+573001110003', true)
  returning id into v_client3_id;

  -- Visita 1 (-40 días)
  insert into public.tickets (tenant_id, branch_id, client_id, scheduled_at, closed_at, status, channel)
  values (v_tenant_id, v_branch_id, v_client3_id, now() - interval '40 days', now() - interval '40 days', 'cerrado', 'manual')
  returning id into v_ticket_id;
  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, price, duration_minutes, status)
  values (v_tenant_id, v_branch_id, v_ticket_id, v_service_id, 60000, 45, 'finalizado');
  insert into public.ticket_payments (tenant_id, branch_id, ticket_id, amount, method, status)
  values (v_tenant_id, v_branch_id, v_ticket_id, 60000, 'efectivo', 'registrado');

  -- Visita 2 (-20 días)
  insert into public.tickets (tenant_id, branch_id, client_id, scheduled_at, closed_at, status, channel)
  values (v_tenant_id, v_branch_id, v_client3_id, now() - interval '20 days', now() - interval '20 days', 'cerrado', 'manual')
  returning id into v_ticket_id;
  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, price, duration_minutes, status)
  values (v_tenant_id, v_branch_id, v_ticket_id, v_service_id, 80000, 45, 'finalizado');
  insert into public.ticket_payments (tenant_id, branch_id, ticket_id, amount, method, status)
  values (v_tenant_id, v_branch_id, v_ticket_id, 80000, 'efectivo', 'registrado');

  -- Visita 3 (-2 días)
  insert into public.tickets (tenant_id, branch_id, client_id, scheduled_at, closed_at, status, channel)
  values (v_tenant_id, v_branch_id, v_client3_id, now() - interval '2 days', now() - interval '2 days', 'cerrado', 'manual')
  returning id into v_ticket_id;
  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, price, duration_minutes, status)
  values (v_tenant_id, v_branch_id, v_ticket_id, v_service_id, 100000, 45, 'finalizado');
  insert into public.ticket_payments (tenant_id, branch_id, ticket_id, amount, method, status)
  values (v_tenant_id, v_branch_id, v_ticket_id, 100000, 'efectivo', 'registrado');

  -- Cliente 4: 1 visita hace 60 días (En riesgo) + Saldo pendiente de $30.000
  insert into public.clients (tenant_id, name, phone, active)
  values (v_tenant_id, 'Cliente Cuatro En Riesgo Con Saldo', '+573001110004', true)
  returning id into v_client4_id;

  insert into public.tickets (tenant_id, branch_id, client_id, scheduled_at, closed_at, status, channel)
  values (v_tenant_id, v_branch_id, v_client4_id, now() - interval '60 days', now() - interval '60 days', 'finalizado', 'manual')
  returning id into v_ticket_id;
  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, price, duration_minutes, status)
  values (v_tenant_id, v_branch_id, v_ticket_id, v_service_id, 70000, 45, 'finalizado');
  -- Pagó solo $40.000, debe $30.000
  insert into public.ticket_payments (tenant_id, branch_id, ticket_id, amount, method, status)
  values (v_tenant_id, v_branch_id, v_ticket_id, 40000, 'efectivo', 'registrado');

  -- ==============================================================
  -- VERIFICACIONES
  -- ==============================================================

  -- Comprobación 1: Cliente 1 (Sin visitas)
  select * into v_res from public.get_clients_management_summary() where id = v_client1_id;
  assert v_res.total_visits = 0, 'Prueba 1 falló: total_visits debe ser 0';
  assert v_res.total_spent = 0, 'Prueba 1 falló: total_spent debe ser 0';
  assert v_res.average_ticket = 0, 'Prueba 1 falló: average_ticket debe ser 0';
  assert v_res.avg_days_between_visits is null, 'Prueba 1 falló: avg_days_between_visits debe ser null';
  assert v_res.segment = 'sin_visitas', 'Prueba 1 falló: segment debe ser sin_visitas';
  assert v_res.balance_amount = 0, 'Prueba 1 falló: balance_amount debe ser 0';

  -- Comprobación 2: Cliente 2 (1 visita)
  select * into v_res from public.get_clients_management_summary() where id = v_client2_id;
  assert v_res.total_visits = 1, 'Prueba 2 falló: total_visits debe ser 1';
  assert v_res.total_spent = 50000, 'Prueba 2 falló: total_spent debe ser 50000';
  assert v_res.average_ticket = 50000, 'Prueba 2 falló: average_ticket debe ser 50000';
  assert v_res.days_since_last_visit >= 4 and v_res.days_since_last_visit <= 6, 'Prueba 2 falló: days_since_last_visit debe ser ~5';
  assert v_res.avg_days_between_visits is null, 'Prueba 2 falló: avg_days_between_visits debe ser null con 1 visita';
  assert v_res.segment = 'nuevo', 'Prueba 2 falló: segment debe ser nuevo';

  -- Comprobación 3: Cliente 3 (3 visitas, $240.000 total, promedio $80.000, cadencia ~19 días, VIP)
  select * into v_res from public.get_clients_management_summary() where id = v_client3_id;
  assert v_res.total_visits = 3, 'Prueba 3 falló: total_visits debe ser 3';
  assert v_res.total_spent = 240000, 'Prueba 3 falló: total_spent debe ser 240000 (60k+80k+100k)';
  assert v_res.average_ticket = 80000, 'Prueba 3 falló: average_ticket debe ser 80000';
  assert v_res.days_since_last_visit >= 1 and v_res.days_since_last_visit <= 3, 'Prueba 3 falló: days_since_last_visit debe ser ~2';
  assert v_res.avg_days_between_visits >= 18 and v_res.avg_days_between_visits <= 20, 'Prueba 3 falló: cadencia debe ser ~19 días';
  assert v_res.segment = 'vip', 'Prueba 3 falló: segment debe ser vip';

  -- Comprobación 4: Cliente 4 (1 visita hace 60 días -> En riesgo + Saldo $30.000)
  select * into v_res from public.get_clients_management_summary() where id = v_client4_id;
  assert v_res.total_visits = 1, 'Prueba 4 falló: total_visits debe ser 1';
  assert v_res.days_since_last_visit >= 59 and v_res.days_since_last_visit <= 61, 'Prueba 4 falló: days_since_last_visit debe ser ~60';
  assert v_res.segment = 'en_riesgo', 'Prueba 4 falló: segment debe ser en_riesgo';
  assert v_res.balance_amount = 30000, 'Prueba 4 falló: balance_amount debe ser 30000';

  raise notice 'Control 175: Las 4 comprobaciones de metricas de cliente pasaron exitosamente en verde.';
end;
$$;

rollback;
