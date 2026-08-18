-- ==============================================================================
-- CONTROL 174: Número de venta consecutivo e inmutable por sede (Paso 4.4 / D-150)
-- ==============================================================================
-- Se ejecuta en ROLLBACK para no ensuciar la base de datos de producción / dev.
-- Prueba:
--   1. Asignación automática de sale_number y sale_code al cerrar ticket.
--   2. Tickets no cerrados (abiertos o cancelados) no reciben número de venta.
--   3. Independencia y aislamiento estricto de consecutivos entre sedes.
--   4. Inmutabilidad estricta: intento de modificar sale_number/sale_code falla.
--   5. Reabrir un ticket cerrado (mismo camino que void_ticket_payment) y
--      volverlo a cerrar NO reasigna un número de venta nuevo.
--   6. Configuración de reglas DIAN y validación de next_number.
--   7. get_ticket_board_list_v2 devuelve los campos de venta.
-- ==============================================================================

begin;

do $$
declare
  v_owner_user_id uuid := 'a1111111-1111-1111-1111-111111111111'::uuid;
  v_tenant_id uuid;
  v_branch_1_id uuid;
  v_branch_2_id uuid;
  v_client_id uuid;
  v_service_id uuid;
  v_stylist_id uuid;
  v_ticket_1_id uuid;
  v_ticket_2_id uuid;
  v_ticket_branch2_id uuid;

  v_ticket_row record;
  v_cfg_row record;
  v_list_row record;
  v_found boolean;
begin
  raise notice 'Iniciando Control 174: Número de Venta por Sede (D-150)...';

  -- ============================================================================
  -- 0. Configuración de sesión y datos base
  -- ============================================================================
  insert into public.tenants (name, business_type, contact_email, whatsapp, is_demo, active)
  values ('Centro Estética Control 174', 'peluqueria', 'control174@salonymas.com', '+573001112233', true, true)
  returning id into v_tenant_id;

  insert into auth.users (id, email)
  values (v_owner_user_id, 'owner_174_' || floor(random()*100000)::text || '@salonymas.com');

  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant_id, v_owner_user_id, 'tenant_owner', true);

  perform set_config('request.jwt.claim.sub', v_owner_user_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  insert into public.branches (tenant_id, name, slug, timezone, currency_code, is_primary, active)
  values (v_tenant_id, 'Sede Principal 174', 'sede-174-1-' || floor(random()*100000)::text, 'America/Bogota', 'COP', true, true)
  returning id into v_branch_1_id;

  insert into public.branches (tenant_id, name, slug, timezone, currency_code, is_primary, active)
  values (v_tenant_id, 'Sede Poblado 174', 'sede-174-2-' || floor(random()*100000)::text, 'America/Bogota', 'COP', false, true)
  returning id into v_branch_2_id;

  insert into public.clients (tenant_id, name, phone, active)
  values (v_tenant_id, 'Clienta Prueba 174', '+573009998877', true)
  returning id into v_client_id;

  insert into public.services (tenant_id, name, duration_minutes, price, active)
  values (v_tenant_id, 'Corte y Peinado', 45, 60000, true)
  returning id into v_service_id;

  insert into public.branch_services (tenant_id, branch_id, service_id, price, duration_minutes, active)
  values
    (v_tenant_id, v_branch_1_id, v_service_id, 60000, 45, true),
    (v_tenant_id, v_branch_2_id, v_service_id, 60000, 45, true);

  insert into public.stylists (tenant_id, name, active)
  values (v_tenant_id, 'Estilista 174', true)
  returning id into v_stylist_id;

  insert into public.branch_stylists (tenant_id, branch_id, stylist_id, active)
  values
    (v_tenant_id, v_branch_1_id, v_stylist_id, true),
    (v_tenant_id, v_branch_2_id, v_stylist_id, true);

  -- ============================================================================
  -- PRUEBA 1: Asignación automática de sale_number y sale_code al cerrar ticket
  -- ============================================================================
  insert into public.tickets (
    tenant_id, branch_id, client_id, scheduled_at, status, channel
  ) values (
    v_tenant_id, v_branch_1_id, v_client_id, '2026-08-17 10:00:00-05', 'finalizado', 'manual'
  ) returning id into v_ticket_1_id;

  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant_id, v_branch_1_id, v_ticket_1_id, v_service_id, v_stylist_id, 60000, 45, 'finalizado');

  -- Verificar que en 'finalizado' aún no tiene número de venta
  select sale_number, sale_code into v_ticket_row
  from public.tickets where id = v_ticket_1_id;

  if v_ticket_row.sale_number is not null or v_ticket_row.sale_code is not null then
    raise exception 'Fallo Prueba 1: el ticket en finalizado no debe tener número de venta.';
  end if;

  -- Pasar a 'cerrado'
  update public.tickets
     set status = 'cerrado'
   where id = v_ticket_1_id;

  select sale_number, sale_code, closed_at into v_ticket_row
  from public.tickets where id = v_ticket_1_id;

  if v_ticket_row.sale_number != 1 or v_ticket_row.sale_code != 'VTA-0000001' or v_ticket_row.closed_at is null then
    raise exception 'Fallo Prueba 1: no se asignó correctamente el número de venta. Obtenido: %, %',
      v_ticket_row.sale_number, v_ticket_row.sale_code;
  end if;

  -- Verificar incremento en branch_sale_numbering
  select next_number into v_cfg_row
  from public.branch_sale_numbering
  where tenant_id = v_tenant_id and branch_id = v_branch_1_id;

  if v_cfg_row.next_number != 2 then
    raise exception 'Fallo Prueba 1: next_number debió incrementar a 2. Obtenido: %', v_cfg_row.next_number;
  end if;

  raise notice '✅ Prueba 1 superada: número de venta y código asignados atómicamente al pasar a cerrado.';

  -- ============================================================================
  -- PRUEBA 2: Tickets abiertos y cancelados conservan sale_code = null
  -- ============================================================================
  insert into public.tickets (
    tenant_id, branch_id, client_id, scheduled_at, status, channel
  ) values (
    v_tenant_id, v_branch_1_id, v_client_id, '2026-08-17 11:00:00-05', 'cancelado', 'manual'
  ) returning id into v_ticket_2_id;

  select sale_number, sale_code into v_ticket_row
  from public.tickets where id = v_ticket_2_id;

  if v_ticket_row.sale_number is not null or v_ticket_row.sale_code is not null then
    raise exception 'Fallo Prueba 2: el ticket cancelado no debe quemar número de venta.';
  end if;

  raise notice '✅ Prueba 2 superada: citas canceladas o abiertas no queman números de venta.';

  -- ============================================================================
  -- PRUEBA 3: Consecutivos contables independientes por sede
  -- ============================================================================
  insert into public.tickets (
    tenant_id, branch_id, client_id, scheduled_at, status, channel
  ) values (
    v_tenant_id, v_branch_2_id, v_client_id, '2026-08-17 10:00:00-05', 'finalizado', 'manual'
  ) returning id into v_ticket_branch2_id;

  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant_id, v_branch_2_id, v_ticket_branch2_id, v_service_id, v_stylist_id, 60000, 45, 'finalizado');

  update public.tickets
     set status = 'cerrado'
   where id = v_ticket_branch2_id;

  select sale_number, sale_code into v_ticket_row
  from public.tickets where id = v_ticket_branch2_id;

  -- Sede 2 debe arrancar en su propio 1 ('VTA-0000001') sin colisionar con Sede 1
  if v_ticket_row.sale_number != 1 or v_ticket_row.sale_code != 'VTA-0000001' then
    raise exception 'Fallo Prueba 3: la Sede 2 debe tener su propio consecutivo independiente. Obtenido: %, %',
      v_ticket_row.sale_number, v_ticket_row.sale_code;
  end if;

  raise notice '✅ Prueba 3 superada: aislamiento e independencia de consecutivos contables por sede verificado.';

  -- ============================================================================
  -- PRUEBA 4: Inmutabilidad contable estricta
  -- ============================================================================
  begin
    update public.tickets
       set sale_code = 'HACK-999'
     where id = v_ticket_1_id;
    raise exception 'Fallo Prueba 4: debió rechazar la modificación de sale_code en un ticket cerrado.';
  exception when others then
    if sqlerrm not like '%no se puede modificar ni reasignar%' then
      raise exception 'Fallo Prueba 4: mensaje de error inesperado: %', sqlerrm;
    end if;
  end;

  raise notice '✅ Prueba 4 superada: inmutabilidad contable de números de venta probada.';

  -- ============================================================================
  -- PRUEBA 5: Reabrir un ticket cerrado y volverlo a cerrar NO reasigna número
  -- ============================================================================
  -- Mismo camino real que usa void_ticket_payment (079_void_ticket_payment_rpc.sql):
  -- anular el pago que cerró el ticket lo regresa a 'finalizado'. Si luego se
  -- vuelve a cerrar, el número de venta original debe conservarse intacto.
  update public.tickets
     set status = 'finalizado'
   where id = v_ticket_1_id;

  select sale_number, sale_code into v_ticket_row
  from public.tickets where id = v_ticket_1_id;

  if v_ticket_row.sale_number != 1 or v_ticket_row.sale_code != 'VTA-0000001' then
    raise exception 'Fallo Prueba 5: reabrir el ticket (sin tocar sale_number/sale_code) no debió alterar el numero ya asignado. Obtenido: %, %',
      v_ticket_row.sale_number, v_ticket_row.sale_code;
  end if;

  update public.tickets
     set status = 'cerrado'
   where id = v_ticket_1_id;

  select sale_number, sale_code into v_ticket_row
  from public.tickets where id = v_ticket_1_id;

  if v_ticket_row.sale_number != 1 or v_ticket_row.sale_code != 'VTA-0000001' then
    raise exception 'Fallo Prueba 5: al volver a cerrar el ticket se reasigno un numero de venta nuevo (esperado 1 / VTA-0000001, obtenido % / %). Se rompio la inmutabilidad.',
      v_ticket_row.sale_number, v_ticket_row.sale_code;
  end if;

  -- El contador de la sede NO debe haber avanzado por esta reapertura.
  select next_number into v_cfg_row
  from public.branch_sale_numbering
  where tenant_id = v_tenant_id and branch_id = v_branch_1_id;

  if v_cfg_row.next_number != 2 then
    raise exception 'Fallo Prueba 5: reabrir y volver a cerrar no debio consumir un numero nuevo del contador. next_number obtenido: %', v_cfg_row.next_number;
  end if;

  raise notice '✅ Prueba 5 superada: reabrir y volver a cerrar un ticket conserva su número de venta original.';

  -- ============================================================================
  -- PRUEBA 6: Configuración de Resolución DIAN y validación de next_number
  -- ============================================================================
  -- Intentar fijar next_number menor o igual al último emitido (1) -> Debe fallar
  begin
    perform public.set_branch_sale_numbering(
      v_branch_1_id, 'FJ-', 1, 6::smallint, '18764000123', '2026-08-01'::date, 20000, 29999, '2028-08-01'::date
    );
    raise exception 'Fallo Prueba 6: debió rechazar next_number <= último emitido.';
  exception when others then
    if sqlerrm not like '%debe ser estrictamente mayor%' then
      raise exception 'Fallo Prueba 6: mensaje de error inesperado: %', sqlerrm;
    end if;
  end;

  -- Fijar configuración DIAN válida con rango 20000..29999 y next_number = 20000
  perform public.set_branch_sale_numbering(
    v_branch_1_id, 'FJ-', 20000, 6::smallint, '18764000123', '2026-08-01'::date, 20000, 29999, '2028-08-01'::date
  );

  select prefix, next_number, padding, resolution_number into v_cfg_row
  from public.get_branch_sale_numbering(v_branch_1_id);

  if v_cfg_row.prefix != 'FJ-' or v_cfg_row.next_number != 20000 or v_cfg_row.resolution_number != '18764000123' then
    raise exception 'Fallo Prueba 6: no se guardó la configuración DIAN correctamente.';
  end if;

  raise notice '✅ Prueba 6 superada: configuración de resolución DIAN y validaciones probadas.';

  -- ============================================================================
  -- PRUEBA 7: get_ticket_board_list_v2 devuelve sale_number, sale_code y closed_at
  -- ============================================================================
  v_found := false;
  for v_list_row in (
    select * from public.get_ticket_board_list_v2(
      v_branch_1_id, '2026-08-17'::date, '2026-08-17'::date, array['cerrado'], null, null
    )
  ) loop
    if v_list_row.id = v_ticket_1_id then
      v_found := true;
      if v_list_row.sale_number != 1 or v_list_row.sale_code != 'VTA-0000001' or v_list_row.closed_at is null then
        raise exception 'Fallo Prueba 7: campos de venta incorrectos en RPC: %, %, %',
          v_list_row.sale_number, v_list_row.sale_code, v_list_row.closed_at;
      end if;
    end if;
  end loop;

  if not v_found then
    raise exception 'Fallo Prueba 7: no se encontró el ticket cerrado en get_ticket_board_list_v2.';
  end if;

  raise notice '✅ Prueba 7 superada: RPC de lista Nivel 2 devuelve consecutivo contable exacto.';

  raise notice '==================================================';
  raise notice 'CONTROL 174: 7 DE 7 PRUEBAS EN VERDE.';
  raise notice '==================================================';
end;
$$;

rollback;
