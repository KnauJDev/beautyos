-- D-163: abonos y pagos en citas activas, sin esperar a 'finalizado'.
--
-- POR QUE ESTE ARCHIVO
--
-- La migracion `20260827100000_abonos_en_citas_activas.sql` relaja
-- `register_ticket_payment` para aceptar pagos en cualquier estado activo
-- (antes exigia 'finalizado') y mueve el cierre automatico + generacion de
-- comisiones a un helper compartido, llamado tambien desde
-- `change_ticket_status`. Es dinero y comisiones: cualquier fallo aqui es
-- silencioso y costoso, asi que se prueba contra datos reales antes de
-- confiar en que el boton nuevo del panel funciona.
--
-- COMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\183_test_abonos_en_citas_activas.sql"
--
-- TERMINA EN ROLLBACK. No deja ni una fila.

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
  v_status text;
  v_comision_count integer;
  v_pct numeric;
  v_fallos integer := 0;
  v_error text;
  v_capturo boolean;
begin
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

  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_owner::text, 'role', 'authenticated')::text,
    true
  );

  -- =====================================================================
  -- CASO 1: abono en una cita 'confirmado' con el servicio SIN finalizar.
  -- Antes de este bloque, esto fallaba con "no tiene servicios finalizados
  -- para cobrar" -- el total solo sumaba servicios status='finalizado'.
  -- =====================================================================
  insert into public.tickets (
    tenant_id, branch_id, client_id, status, channel, scheduled_at
  )
  values (v_tenant, v_branch, v_client, 'confirmado', 'manual', now())
  returning id into v_ticket;

  insert into public.ticket_services (
    tenant_id, branch_id, ticket_id, service_id, stylist_id,
    price, duration_minutes, status
  )
  values (
    v_tenant, v_branch, v_ticket, v_service, v_stylist,
    100000, 60, 'pendiente'
  )
  returning id into v_ticket_service;

  begin
    perform public.register_ticket_payment_v2(
      v_branch, v_ticket, 30000, 'efectivo', null, 'Abono anticipado'
    );
    raise notice 'OK  1a  se registro un abono de 30.000 en una cita confirmada sin atender';
  exception
    when others then
      v_fallos := v_fallos + 1;
      raise notice 'FALLO 1a  el abono deberia aceptarse; error: %', sqlerrm;
  end;

  select balance_amount, paid_amount into v_saldo, v_pagado
  from public.get_tickets_summary_v2(v_branch)
  where id = v_ticket;

  if v_saldo = 70000 and v_pagado = 30000 then
    raise notice 'OK  1b  el saldo baja a 70.000 sumando el servicio pendiente como total';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 1b  se esperaba saldo 70.000 y pagado 30.000; llego % y %',
      v_saldo, v_pagado;
  end if;

  -- =====================================================================
  -- CASO 2: el mismo abono llega al 100% ANTES de atender -- no debe
  -- cerrar la cita ni generar comision: el servicio todavia no se hizo.
  -- =====================================================================
  perform public.register_ticket_payment_v2(
    v_branch, v_ticket, 70000, 'efectivo', null, 'Resto del abono'
  );

  select status into v_status from public.tickets where id = v_ticket;

  if v_status = 'confirmado' then
    raise notice 'OK  2a  pagado el 100%% por anticipado, la cita sigue "confirmado" (no se cierra sola)';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 2a  se esperaba que la cita siguiera "confirmado"; quedo en "%"', v_status;
  end if;

  select count(*) into v_comision_count
  from public.stylist_commissions
  where ticket_service_id = v_ticket_service;

  if v_comision_count = 0 then
    raise notice 'OK  2b  no se genero comision por un servicio que aun no se presto';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 2b  se generaron % comisiones antes de atender el servicio', v_comision_count;
  end if;

  -- =====================================================================
  -- CASO 3: al atender el servicio y finalizar el ticket, como ya estaba
  -- pagado al 100%, debe cerrarse solo y generar la comision en ese
  -- momento (el helper llamado desde change_ticket_status).
  -- =====================================================================
  perform public.change_ticket_status_v2(v_branch, v_ticket, 'en_proceso', null);

  update public.ticket_services
     set status = 'finalizado'
   where id = v_ticket_service;

  perform public.change_ticket_status_v2(v_branch, v_ticket, 'finalizado', null);

  select status into v_status from public.tickets where id = v_ticket;

  if v_status = 'cerrado' then
    raise notice 'OK  3a  al finalizar el servicio ya pagado, la cita se cerro sola';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 3a  se esperaba que la cita quedara "cerrado"; quedo en "%"', v_status;
  end if;

  if v_stylist is null then
    raise notice 'SALTADA 3b: el negocio no tiene estilista con cuenta.';
  else
    select cp.commission_percentage into v_pct
    from public.commission_policies cp
    where cp.tenant_id = v_tenant and cp.active
    limit 1;

    if v_pct is null then
      raise notice 'SALTADA 3b: el negocio no tiene politica de comision.';
    else
      select count(*) into v_comision_count
      from public.stylist_commissions
      where ticket_service_id = v_ticket_service
        and status = 'generada';

      if v_comision_count = 1 then
        raise notice 'OK  3b  la comision se genero al finalizar, no al abonar';
      else
        v_fallos := v_fallos + 1;
        raise notice 'FALLO 3b  se esperaba 1 comision generada; llegaron %', v_comision_count;
      end if;
    end if;
  end if;

  -- =====================================================================
  -- CASO 4: una cita cancelada o no asistida sigue sin admitir pagos.
  -- =====================================================================
  insert into public.tickets (
    tenant_id, branch_id, client_id, status, channel, scheduled_at
  )
  values (v_tenant, v_branch, v_client, 'cancelado', 'manual', now())
  returning id into v_ticket;

  insert into public.ticket_services (
    tenant_id, branch_id, ticket_id, service_id, stylist_id,
    price, duration_minutes, status
  )
  values (v_tenant, v_branch, v_ticket, v_service, v_stylist, 100000, 60, 'cancelado');

  v_capturo := false;
  begin
    perform public.register_ticket_payment_v2(
      v_branch, v_ticket, 10000, 'efectivo', null, null
    );
  exception
    when others then
      v_capturo := true;
  end;

  if v_capturo then
    raise notice 'OK  4a  una cita cancelada sigue rechazando pagos';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 4a  se registro un pago sobre una cita cancelada';
  end if;

  -- =====================================================================
  -- CASO 5: regresion -- el camino de siempre (cobrar tras finalizar)
  -- sigue cerrando la cita y generando comision, sin cambios.
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

  perform public.register_ticket_payment_v2(
    v_branch, v_ticket, 100000, 'efectivo', null, null
  );

  select status into v_status from public.tickets where id = v_ticket;

  if v_status = 'cerrado' then
    raise notice 'OK  5a  el camino de siempre (cobrar tras finalizar) sigue cerrando la cita';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 5a  se esperaba "cerrado" tras cobrar el total; quedo en "%"', v_status;
  end if;

  -- =====================================================================
  raise notice ' ';
  if v_fallos = 0 then
    raise notice '=== TODAS LAS PRUEBAS DE ABONOS EN CITAS ACTIVAS PASARON ===';
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
