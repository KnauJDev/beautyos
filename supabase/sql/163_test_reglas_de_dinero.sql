-- Accion A6 de la Etapa A: las tres reglas de dinero y el rechazo por rol.
-- Segunda mitad de H-03 (la primera son las pruebas de Dart en
-- `test/dinero_y_roles_test.dart`).
--
-- POR QUE ESTE ARCHIVO
--
-- Las tres regresiones del 06-ago las encontro el propietario probando en
-- produccion, no las pruebas. La auditoria del 06-ago pidio empezar por las
-- **tres reglas de dinero cuya ruptura seria mas costosa y silenciosa**:
--
--   1. El saldo de un ticket = servicios finalizados menos pagos registrados.
--   2. La resolucion de comision: primero la excepcion de sede/estilista/
--      servicio (D-078), la politica del negocio como respaldo.
--   3. El costo promedio ponderado al comprar y su reversion al anular
--      (D-055).
--
-- COMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\163_test_reglas_de_dinero.sql"
--
-- TERMINA EN ROLLBACK. No deja ni una fila. Se puede correr contra produccion
-- las veces que haga falta.
--
-- HONESTIDAD SOBRE QUE ES Y QUE NO ES ESTO
--
-- **No es una prueba automatica.** Es un guion que alguien tiene que correr.
-- Que se ejecute solo en cada cambio exige una base de pruebas, que es la
-- accion **A2** y todavia no existe. Mientras tanto, esto es lo que hay, y es
-- mucho mas de lo que habia: cero.
--
-- Se hace pasar por el propietario poniendo su identificador en la sesion,
-- que es lo que leen las funciones para saber quien llama. Es la unica forma
-- de ejercitar de verdad funciones que dependen de la sesion.

begin;

do $$
declare
  v_tenant uuid;
  v_branch uuid;
  v_owner uuid;
  v_stylist_user uuid;
  v_stylist uuid;
  v_client uuid;
  v_service uuid;
  v_ticket uuid;
  v_ticket_service uuid;
  v_saldo numeric;
  v_pagado numeric;
  v_comision numeric;
  v_esperado numeric;
  v_pct numeric;
  v_tipo text;
  v_stock_antes numeric;
  v_costo_antes numeric;
  v_stock numeric;
  v_costo numeric;
  v_product uuid;
  v_purchase uuid;
  v_fallos integer := 0;
  v_error text;
begin
  -- ---------------------------------------------------------------------
  -- Datos de partida: el negocio real, su sede principal y su dueno.
  -- ---------------------------------------------------------------------
  select t.id into v_tenant
  from public.tenants t
  where t.active
  order by t.created_at
  limit 1;

  select b.id into v_branch
  from public.branches b
  where b.tenant_id = v_tenant and b.active
  order by b.is_primary desc
  limit 1;

  select tm.user_id into v_owner
  from public.tenant_memberships tm
  where tm.tenant_id = v_tenant
    and tm.role = 'tenant_owner'
    and tm.active
  limit 1;

  select tm.user_id, tm.stylist_id into v_stylist_user, v_stylist
  from public.tenant_memberships tm
  where tm.tenant_id = v_tenant
    and tm.role = 'stylist'
    and tm.active
    and tm.stylist_id is not null
  limit 1;

  select c.id into v_client
  from public.clients c
  where c.tenant_id = v_tenant and c.active
  limit 1;

  select bs.service_id into v_service
  from public.branch_services bs
  where bs.tenant_id = v_tenant and bs.branch_id = v_branch and bs.active
  limit 1;

  if v_tenant is null or v_branch is null or v_owner is null
     or v_client is null or v_service is null then
    raise notice 'SIN DATOS suficientes para las pruebas. Nada que comprobar.';
    return;
  end if;

  -- La sesion pasa a ser la del propietario. Es lo que leen las funciones
  -- para resolver quien llama.
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_owner::text, 'role', 'authenticated')::text,
    true
  );

  -- =====================================================================
  -- REGLA 1: el saldo = servicios finalizados - pagos registrados (D-083)
  -- =====================================================================
  insert into public.tickets (
    tenant_id, branch_id, client_id, status, channel, scheduled_at
  )
  values (v_tenant, v_branch, v_client, 'finalizado', 'manual', now())
  returning id into v_ticket;

  insert into public.ticket_services (
    tenant_id, branch_id, ticket_id, service_id, stylist_id,
    price, duration_minutes, status
  )
  values (
    v_tenant, v_branch, v_ticket, v_service, v_stylist,
    100000, 60, 'finalizado'
  )
  returning id into v_ticket_service;

  -- Sin pagos: el saldo debe ser el total.
  select balance_amount, paid_amount into v_saldo, v_pagado
  from public.get_tickets_summary_v2(v_branch)
  where id = v_ticket;

  if v_saldo = 100000 and v_pagado = 0 then
    raise notice 'OK  1a  sin pagos, el saldo es el total (100.000)';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 1a  se esperaba saldo 100.000 y pagado 0; llego % y %',
      v_saldo, v_pagado;
  end if;

  -- Un abono parcial.
  insert into public.ticket_payments (
    tenant_id, branch_id, ticket_id, amount, method, status, created_by
  )
  values (v_tenant, v_branch, v_ticket, 40000, 'efectivo', 'registrado', v_owner);

  select balance_amount, paid_amount into v_saldo, v_pagado
  from public.get_tickets_summary_v2(v_branch)
  where id = v_ticket;

  if v_saldo = 60000 and v_pagado = 40000 then
    raise notice 'OK  1b  con un abono de 40.000, el saldo baja a 60.000';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 1b  se esperaba saldo 60.000 y pagado 40.000; llego % y %',
      v_saldo, v_pagado;
  end if;

  -- Un pago ANULADO no cuenta. Es la regla que mas silenciosamente podria
  -- romperse: si contara, el negocio creeria que cobro algo que devolvio.
  update public.ticket_payments
  set status = 'anulado', voided_at = now(), voided_by = v_owner,
      void_reason = 'prueba'
  where ticket_id = v_ticket;

  select balance_amount, paid_amount into v_saldo, v_pagado
  from public.get_tickets_summary_v2(v_branch)
  where id = v_ticket;

  if v_saldo = 100000 and v_pagado = 0 then
    raise notice 'OK  1c  un pago anulado deja de contar y el saldo vuelve a 100.000';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 1c  tras anular se esperaba saldo 100.000 y pagado 0; llego % y %',
      v_saldo, v_pagado;
  end if;

  -- Un servicio CANCELADO no suma al total.
  update public.ticket_services
  set status = 'cancelado'
  where id = v_ticket_service;

  select balance_amount into v_saldo
  from public.get_tickets_summary_v2(v_branch)
  where id = v_ticket;

  if v_saldo = 0 then
    raise notice 'OK  1d  un servicio cancelado no suma al total';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 1d  con el servicio cancelado el saldo deberia ser 0; llego %',
      v_saldo;
  end if;

  update public.ticket_services
  set status = 'finalizado'
  where id = v_ticket_service;

  -- =====================================================================
  -- REGLA 2: la comision usa la excepcion antes que la politica (D-078)
  -- =====================================================================
  if v_stylist is null then
    raise notice 'SALTADA regla 2: el negocio no tiene estilista con cuenta.';
  else
    select cp.commission_percentage, cp.commission_type
      into v_pct, v_tipo
    from public.commission_policies cp
    where cp.tenant_id = v_tenant and cp.active
    limit 1;

    if v_pct is null then
      raise notice 'SALTADA regla 2: el negocio no tiene politica de comision.';
    else
      -- Se cobra el ticket entero para que nazca la comision.
      delete from public.ticket_payments where ticket_id = v_ticket;

      perform public.register_ticket_payment_v2(
        v_branch, v_ticket, 100000, 'efectivo', null, null
      );

      select sc.commission_amount into v_comision
      from public.stylist_commissions sc
      where sc.ticket_service_id = v_ticket_service;

      if v_tipo = 'percentage' then
        v_esperado := round(100000 * v_pct / 100, 2);
      else
        v_esperado := null;
      end if;

      if v_esperado is null then
        raise notice 'INFO 2a  politica de tipo "%": comision generada = %',
          v_tipo, v_comision;
      elsif v_comision = v_esperado then
        raise notice 'OK  2a  sin excepcion se aplica la politica del negocio (% %% = %)',
          v_pct, v_comision;
      else
        v_fallos := v_fallos + 1;
        raise notice 'FALLO 2a  se esperaba comision % y llego %',
          v_esperado, v_comision;
      end if;

      -- Ahora con una excepcion para ese estilista y ese servicio.
      insert into public.stylist_service_commissions (
        tenant_id, branch_id, stylist_id, service_id,
        commission_type, commission_percentage, active, created_by
      )
      values (
        v_tenant, v_branch, v_stylist, v_service,
        'percentage', 10, true, v_owner
      );

      -- Segundo ticket, mismas condiciones, para comparar.
      insert into public.tickets (
        tenant_id, branch_id, client_id, status, channel, scheduled_at
      )
      values (v_tenant, v_branch, v_client, 'finalizado', 'manual', now())
      returning id into v_ticket;

      insert into public.ticket_services (
        tenant_id, branch_id, ticket_id, service_id, stylist_id,
        price, duration_minutes, status
      )
      values (
        v_tenant, v_branch, v_ticket, v_service, v_stylist,
        100000, 60, 'finalizado'
      )
      returning id into v_ticket_service;

      perform public.register_ticket_payment_v2(
        v_branch, v_ticket, 100000, 'efectivo', null, null
      );

      select sc.commission_amount into v_comision
      from public.stylist_commissions sc
      where sc.ticket_service_id = v_ticket_service;

      if v_comision = 10000 then
        raise notice 'OK  2b  la excepcion (10 %%) gana sobre la politica del negocio';
      else
        v_fallos := v_fallos + 1;
        raise notice 'FALLO 2b  con excepcion del 10 %% se esperaba 10.000; llego %',
          v_comision;
      end if;
    end if;
  end if;

  -- =====================================================================
  -- REGLA 3: costo promedio ponderado al comprar y al anular (D-055)
  -- =====================================================================
  select bp.product_id, bp.current_stock, bp.average_cost
    into v_product, v_stock_antes, v_costo_antes
  from public.branch_products bp
  where bp.tenant_id = v_tenant and bp.branch_id = v_branch and bp.active
  limit 1;

  if v_product is null then
    raise notice 'SALTADA regla 3: la sede no tiene productos.';
  else
    -- Se compran 10 unidades a 1.000. El promedio nuevo tiene que quedar
    -- entre el viejo y el nuevo, ponderado por cantidad.
    select cp.purchase_id into v_purchase
    from public.create_purchase(
      v_branch,
      'Proveedor de prueba',
      jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product,
          'quantity', 10,
          'unit_cost', 1000
        )
      )
    ) cp;

    select bp.current_stock, bp.average_cost into v_stock, v_costo
    from public.branch_products bp
    where bp.tenant_id = v_tenant
      and bp.branch_id = v_branch
      and bp.product_id = v_product;

    v_esperado := round(
      (v_stock_antes * v_costo_antes + 10 * 1000) / (v_stock_antes + 10), 2
    );

    if v_stock = v_stock_antes + 10 then
      raise notice 'OK  3a  el stock subio de % a %', v_stock_antes, v_stock;
    else
      v_fallos := v_fallos + 1;
      raise notice 'FALLO 3a  se esperaba stock %; llego %',
        v_stock_antes + 10, v_stock;
    end if;

    if abs(v_costo - v_esperado) <= 1 then
      raise notice 'OK  3b  el costo promedio quedo en % (esperado %)',
        v_costo, v_esperado;
    else
      v_fallos := v_fallos + 1;
      raise notice 'FALLO 3b  se esperaba costo promedio % y llego %',
        v_esperado, v_costo;
    end if;

    -- Anular la compra tiene que devolver las dos cosas a como estaban.
    perform public.void_purchase(v_branch, v_purchase);

    select bp.current_stock, bp.average_cost into v_stock, v_costo
    from public.branch_products bp
    where bp.tenant_id = v_tenant
      and bp.branch_id = v_branch
      and bp.product_id = v_product;

    if v_stock = v_stock_antes and abs(v_costo - v_costo_antes) <= 1 then
      raise notice 'OK  3c  anular la compra devolvio stock y costo a su estado anterior';
    else
      v_fallos := v_fallos + 1;
      raise notice 'FALLO 3c  tras anular se esperaba stock % y costo %; llego % y %',
        v_stock_antes, v_costo_antes, v_stock, v_costo;
    end if;
  end if;

  -- =====================================================================
  -- REGLA 4: el rechazo por rol (D-095)
  --
  -- Recepcion cobra, el dueno deshace. Un estilista no puede meterse en el
  -- dinero de nadie.
  -- =====================================================================
  if v_stylist_user is null then
    raise notice 'SALTADA regla 4: el negocio no tiene estilista con cuenta.';
  else
    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', v_stylist_user::text, 'role', 'authenticated')::text,
      true
    );

    begin
      perform public.get_tickets_summary_v2(v_branch);
      v_fallos := v_fallos + 1;
      raise notice 'FALLO 4a  un estilista pudo listar los tickets de la sede';
    exception
      when others then
        raise notice 'OK  4a  un estilista NO puede listar los tickets de la sede';
    end;

    begin
      perform public.get_work_photos_summary_v2(v_branch);
      v_fallos := v_fallos + 1;
      raise notice 'FALLO 4b  un estilista pudo ver la gestion de fotos del negocio';
    exception
      when others then
        raise notice 'OK  4b  un estilista NO puede ver la gestion de fotos del negocio';
    end;

    -- Volver a ser el dueno para no dejar la sesion suplantada.
    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', v_owner::text, 'role', 'authenticated')::text,
      true
    );
  end if;

  -- =====================================================================
  raise notice ' ';
  if v_fallos = 0 then
    raise notice '=== TODAS LAS REGLAS DE DINERO Y ROLES PASARON ===';
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
