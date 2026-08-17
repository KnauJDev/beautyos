-- ==============================================================================
-- Control 173: Verificacion de RPCs del Tablero de Agenda (Fase 4 / D-147)
-- ==============================================================================
-- Se ejecuta en una transaccion aislada que termina en ROLLBACK (sin dejar basura).
-- Prueba:
--   1. Permisos y aislamiento de sede (beautyos_resolve_branch_access).
--   2. Conteos en cubetas de 15 minutos en hora colombiana (America/Bogota).
--   3. Conteos diarios en rangos de semana/mes.
--   4. Lista ampliada de Nivel 2 con ticket_code, telefono, abonos y saldos.
--   5. Validaciones de parametros (rango de fechas y granularidad).
-- ==============================================================================

begin;

do $$
declare
  v_owner_user_id uuid := gen_random_uuid();
  v_tenant_id uuid;
  v_branch_id uuid;
  v_other_branch_id uuid;
  v_client_id uuid;
  v_stylist_id uuid;
  v_service_1_id uuid;
  v_service_2_id uuid;
  v_ticket_1_id uuid;
  v_ticket_2_id uuid;
  v_ticket_3_id uuid;
  v_ticket_4_id uuid;
  v_test_date date := '2026-08-20';
  v_count_row record;
  v_list_row record;
  v_found boolean;
begin
  raise notice 'Iniciando Control 173: Tablero de Agenda (D-147)...';

  -- ============================================================================
  -- PREPARACIÓN: Crear tenant, sedes, cliente, estilista y servicios
  -- ============================================================================
  insert into public.tenants (name, business_type, contact_email, whatsapp, is_demo, active)
  values ('Salon Agenda Test', 'peluqueria', 'agenda_test@salonymas.com', '+573001234567', true, true)
  returning id into v_tenant_id;

  insert into auth.users (id, email)
  values (v_owner_user_id, 'owner_agenda_' || floor(random()*100000)::text || '@salonymas.com');

  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant_id, v_owner_user_id, 'tenant_owner', true);

  perform set_config('request.jwt.claim.sub', v_owner_user_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  insert into public.branches (tenant_id, name, slug, timezone, currency_code, is_primary, active)
  values (v_tenant_id, 'Sede Principal', 'sede-principal-' || floor(random()*100000)::text, 'America/Bogota', 'COP', true, true)
  returning id into v_branch_id;

  insert into public.branches (tenant_id, name, slug, timezone, currency_code, is_primary, active)
  values (v_tenant_id, 'Sede Otra', 'sede-otra-' || floor(random()*100000)::text, 'America/Bogota', 'COP', false, true)
  returning id into v_other_branch_id;

  insert into public.clients (tenant_id, name, phone, active)
  values (v_tenant_id, 'Carolina Gómez', '+573001234567', true)
  returning id into v_client_id;

  insert into public.stylists (tenant_id, name, active)
  values (v_tenant_id, 'Valentina Estilista', true)
  returning id into v_stylist_id;

  insert into public.branch_stylists (tenant_id, branch_id, stylist_id, active)
  values (v_tenant_id, v_branch_id, v_stylist_id, true);

  insert into public.services (tenant_id, name, price, duration_minutes, active)
  values (v_tenant_id, 'Corte Dama', 45000, 45, true)
  returning id into v_service_1_id;

  insert into public.services (tenant_id, name, price, duration_minutes, active)
  values (v_tenant_id, 'Cepillado y Secado', 35000, 30, true)
  returning id into v_service_2_id;

  insert into public.branch_services (tenant_id, branch_id, service_id, price, duration_minutes, active)
  values
    (v_tenant_id, v_branch_id, v_service_1_id, 45000, 45, true),
    (v_tenant_id, v_branch_id, v_service_2_id, 35000, 30, true);

  -- Crear 4 tickets en distintas horas y estados en la fecha de prueba (2026-08-20)
  -- Nota: en America/Bogota (UTC-5), 08:15 es 13:15 UTC.
  -- Ticket 1: 08:15 AM -> 'solicitado', valor 45.000, sin pagos
  insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at)
  values (v_tenant_id, v_branch_id, v_client_id, 'solicitado', 'web', '2026-08-20 08:15:00-05')
  returning id into v_ticket_1_id;

  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant_id, v_branch_id, v_ticket_1_id, v_service_1_id, v_stylist_id, 45000, 45, 'pendiente');

  -- Ticket 2: 08:15 AM -> 'cotizado', valor 35.000, sin pagos
  insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at)
  values (v_tenant_id, v_branch_id, v_client_id, 'cotizado', 'whatsapp', '2026-08-20 08:15:00-05')
  returning id into v_ticket_2_id;

  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant_id, v_branch_id, v_ticket_2_id, v_service_2_id, v_stylist_id, 35000, 30, 'pendiente');

  -- Ticket 3: 11:30 AM -> 'confirmado', valor 45.000
  insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at)
  values (v_tenant_id, v_branch_id, v_client_id, 'confirmado', 'manual', '2026-08-20 11:30:00-05')
  returning id into v_ticket_3_id;

  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant_id, v_branch_id, v_ticket_3_id, v_service_1_id, v_stylist_id, 45000, 45, 'pendiente');

  -- Ticket 4: 15:45 (03:45 PM) -> 'finalizado', 2 servicios (45.000 + 35.000 = 80.000), con abono parcial de 30.000 (saldo 50.000)
  insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at)
  values (v_tenant_id, v_branch_id, v_client_id, 'finalizado', 'manual', '2026-08-20 15:45:00-05')
  returning id into v_ticket_4_id;

  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant_id, v_branch_id, v_ticket_4_id, v_service_1_id, v_stylist_id, 45000, 45, 'finalizado');

  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant_id, v_branch_id, v_ticket_4_id, v_service_2_id, v_stylist_id, 35000, 30, 'finalizado');

  insert into public.ticket_payments (tenant_id, branch_id, ticket_id, amount, payment_method, status)
  values (v_tenant_id, v_branch_id, v_ticket_4_id, 30000, 'nequi', 'registrado');

  -- ============================================================================
  -- PRUEBA 1: Conteos en vista Día con intervalos de 15 minutos ('15min')
  -- ============================================================================
  v_found := false;
  for v_count_row in
    select * from public.get_ticket_board_counts_v2(v_branch_id, v_test_date, v_test_date, '15min')
  loop
    if v_count_row.bucket = '08:15' and v_count_row.status = 'solicitado' then
      if v_count_row.ticket_count != 1 or v_count_row.total_price != 45000 then
        raise exception 'Fallo Prueba 1: conteo/precio incorrecto en 08:15 solicitado. Obtenido: % tickets, % precio',
          v_count_row.ticket_count, v_count_row.total_price;
      end if;
      v_found := true;
    end if;

    if v_count_row.bucket = '15:45' and v_count_row.status = 'finalizado' then
      if v_count_row.ticket_count != 1 or v_count_row.total_price != 80000 or v_count_row.total_pending_balance != 50000 then
        raise exception 'Fallo Prueba 1: saldo incorrecto en 15:45 finalizado. Precio: %, Saldo: % (esperado 80.000 / 50.000)',
          v_count_row.total_price, v_count_row.total_pending_balance;
      end if;
    end if;
  end loop;

  if not v_found then
    raise exception 'Fallo Prueba 1: no se encontro la cubeta 08:15 para solicitado.';
  end if;
  raise notice '✅ Prueba 1 superada: conteos en intervalos de 15 minutos en hora Colombia calculados correctamente.';

  -- ============================================================================
  -- PRUEBA 2: Conteos en vista Semana/Mes agrupados por día ('day')
  -- ============================================================================
  v_found := false;
  for v_count_row in
    select * from public.get_ticket_board_counts_v2(v_branch_id, v_test_date, v_test_date, 'day')
  loop
    if v_count_row.bucket = '2026-08-20' and v_count_row.status = 'finalizado' then
      if v_count_row.ticket_count != 1 or v_count_row.total_price != 80000 then
        raise exception 'Fallo Prueba 2: conteo diario incorrecto.';
      end if;
      v_found := true;
    end if;
  end loop;

  if not v_found then
    raise exception 'Fallo Prueba 2: no se encontraron conteos diarios para la fecha de prueba.';
  end if;
  raise notice '✅ Prueba 2 superada: conteos diarios para vista Semana y Mes validados.';

  -- ============================================================================
  -- PRUEBA 3: Lista ampliada de Nivel 2 con ticket_code, teléfono y saldos
  -- ============================================================================
  v_found := false;
  for v_list_row in
    select * from public.get_ticket_board_list_v2(
      v_branch_id,
      v_test_date,
      v_test_date,
      array['finalizado'],
      '15:45',
      '15min'
    )
  loop
    v_found := true;
    if v_list_row.id != v_ticket_4_id then
      raise exception 'Fallo Prueba 3: id de ticket no coincide.';
    end if;
    if v_list_row.ticket_code is null or length(v_list_row.ticket_code) = 0 then
      raise exception 'Fallo Prueba 3: ticket_code nulo o vacio.';
    end if;
    if v_list_row.client_phone != '+573001234567' then
      raise exception 'Fallo Prueba 3: telefono de cliente incorrecto: %', v_list_row.client_phone;
    end if;
    if v_list_row.total_price != 80000 or v_list_row.paid_amount != 30000 or v_list_row.pending_balance != 50000 then
      raise exception 'Fallo Prueba 3: valores de dinero incorrectos. Precio: %, Pagado: %, Saldo: %',
        v_list_row.total_price, v_list_row.paid_amount, v_list_row.pending_balance;
    end if;
    if v_list_row.payment_status != 'parcial' then
      raise exception 'Fallo Prueba 3: estado de pago incorrecto: %', v_list_row.payment_status;
    end if;
    if v_list_row.service_names not like '%Corte Dama%' or v_list_row.service_names not like '%Cepillado%' then
      raise exception 'Fallo Prueba 3: concatenacion de servicios incorrecta: %', v_list_row.service_names;
    end if;
  end loop;

  if not v_found then
    raise exception 'Fallo Prueba 3: no se obtuvo la fila en la lista ampliada de Nivel 2.';
  end if;
  raise notice '✅ Prueba 3 superada: lista de Nivel 2 devuelve consecutivo, cliente, telefono, servicios y saldos exactos.';

  -- ============================================================================
  -- PRUEBA 4: Aislamiento por sede (Sede Otra sin tickets no debe ver los de Sede Principal)
  -- ============================================================================
  select count(*) > 0 into v_found
  from public.get_ticket_board_counts_v2(v_other_branch_id, v_test_date, v_test_date, '15min');

  if v_found then
    raise exception 'Fallo Prueba 4: fuga de datos entre sedes distintas.';
  end if;
  raise notice '✅ Prueba 4 superada: aislamiento estricto por sede verificado.';

  -- ============================================================================
  -- PRUEBA 5: Validación de parámetros inválidos
  -- ============================================================================
  begin
    perform public.get_ticket_board_counts_v2(v_branch_id, '2026-08-25', '2026-08-20', '15min');
    raise exception 'Fallo Prueba 5: debio fallar con rango de fechas invertido.';
  exception when others then
    if sqlerrm not like '%Rango de fechas invalido%' then
      raise exception 'Fallo Prueba 5: mensaje de error inesperado: %', sqlerrm;
    end if;
  end;

  begin
    perform public.get_ticket_board_counts_v2(v_branch_id, v_test_date, v_test_date, 'invalido');
    raise exception 'Fallo Prueba 5: debio fallar con granularidad desconocida.';
  exception when others then
    if sqlerrm not like '%Granularidad invalida%' then
      raise exception 'Fallo Prueba 5: mensaje de error inesperado: %', sqlerrm;
    end if;
  end;

  raise notice '✅ Prueba 5 superada: validaciones de parametros probadas.';

  raise notice '==================================================';
  raise notice 'CONTROL 173: 5 DE 5 PRUEBAS EN VERDE.';
  raise notice '==================================================';
end;
$$;

rollback;
