-- CONTROL 195: Paso 8.1 -- Purga de funciones huérfanas (H-05).
--
-- POR QUÉ ESTE ARCHIVO
--
-- La migración 20260830160000 hace tres cosas y este control las separa:
--   1. Confirma que las 30 firmas retiradas (6 de D-024 + 24 de D-040) ya
--      no existen en `pg_proc` -- ni una.
--   2. Confirma que las 6 firmas internas que D-040 protegió siguen
--      existiendo y llevan el `COMMENT ON FUNCTION` de "NO ELIMINAR".
--   3. Prueba real de extremo a extremo con un tenant de producción:
--      registra un abono con `register_ticket_payment_v2` y lo anula con
--      `void_ticket_payment_v2` -- las dos funciones internas que hacen el
--      trabajo de dinero más delicado de las seis. Las otras cuatro
--      (`change_ticket_service_status`, `change_ticket_status`,
--      `remove_ticket_service`, `reopen_finished_ticket_service`) se
--      verifican solo por existencia+comentario en el punto 2: un
--      `DROP FUNCTION` apunta a una firma exacta por OID, no puede tocar
--      por accidente una función con otro nombre o argumentos --
--      encadenar las seis en una sola coreografía de estados de ticket
--      (que además depende de dos sistemas de autorización en paralelo,
--      `tenant_memberships` y el legado `user_profiles`, D-010/D3.5.3)
--      añadiría fragilidad sin probar nada que el punto 1 no pruebe ya.
--
-- CÓMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\195_test_purga_funciones_huerfanas_h05.sql"
--
-- TERMINA EN ROLLBACK. El pago que se registra y se anula desaparece.

begin;

do $$
declare
  v_fallos integer := 0;
  v_error text;
  v_sig text;
  v_existentes integer;
  v_comentario text;
  v_tenant uuid;
  v_owner_user uuid;
  v_branch uuid;
  v_client uuid;
  v_service uuid;
  v_stylist uuid;
  v_ticket uuid;
  v_payment_id uuid;
  v_retiradas text[] := array[
    'public.get_appointment_policy()',
    'public.get_business_hours()',
    'public.get_dashboard_metrics()',
    'public.get_my_stylist_work_photos()',
    'public.get_reviews_summary()',
    'public.get_work_photos_summary()',
    'public.add_ticket_service(uuid, uuid, uuid)',
    'public.create_scheduled_ticket_with_service(uuid, uuid, uuid, timestamp with time zone, text, text)',
    'public.create_ticket(uuid, timestamp with time zone, text, text)',
    'public.get_agenda_summary()',
    'public.get_available_appointment_slots(uuid, uuid, date)',
    'public.get_commission_summary(timestamp with time zone, timestamp with time zone)',
    'public.get_daily_close(date, timestamp with time zone, timestamp with time zone)',
    'public.get_expenses_summary()',
    'public.get_financial_summary()',
    'public.get_inventory_movements_summary()',
    'public.get_my_stylist_agenda()',
    'public.get_my_stylist_agenda_by_date(date)',
    'public.get_products_summary()',
    'public.get_purchase_items_summary()',
    'public.get_purchases_summary()',
    'public.get_sales_report_summary()',
    'public.get_ticket_payment_summary(uuid)',
    'public.get_ticket_payments(uuid)',
    'public.get_ticket_service_options()',
    'public.get_ticket_services_for_correction(uuid)',
    'public.get_ticket_services_for_management(uuid)',
    'public.get_tickets_summary()',
    'public.reschedule_ticket(uuid, timestamp with time zone, text)',
    'public.update_ticket_service_assignment(uuid, uuid, uuid, text)'
  ];
  v_internas text[] := array[
    'public.change_ticket_service_status(uuid, text)',
    'public.change_ticket_status(uuid, text, text)',
    'public.register_ticket_payment(uuid, numeric, text, text, text)',
    'public.remove_ticket_service(uuid, text)',
    'public.reopen_finished_ticket_service(uuid, text)',
    'public.void_ticket_payment(uuid, text)'
  ];
begin
  -- =====================================================================
  -- 1. Las 30 retiradas ya no existen.
  -- =====================================================================
  v_existentes := 0;
  foreach v_sig in array v_retiradas loop
    if to_regprocedure(v_sig) is not null then
      v_existentes := v_existentes + 1;
      raise notice 'FALLO 1  % todavia existe', v_sig;
    end if;
  end loop;

  if v_existentes = 0 then
    raise notice 'OK 1  las 30 funciones huerfanas ya no existen en pg_proc';
  else
    v_fallos := v_fallos + v_existentes;
  end if;

  -- =====================================================================
  -- 2. Las 6 internas siguen existiendo y con su comentario de blindaje.
  -- =====================================================================
  v_existentes := 0;
  foreach v_sig in array v_internas loop
    if to_regprocedure(v_sig) is null then
      v_fallos := v_fallos + 1;
      raise notice 'FALLO 2  % ya no existe -- se elimino por error', v_sig;
    else
      select obj_description(to_regprocedure(v_sig), 'pg_proc') into v_comentario;
      if v_comentario is null or v_comentario not like 'NO ELIMINAR%' then
        v_fallos := v_fallos + 1;
        raise notice 'FALLO 2  % existe pero sin el comentario "NO ELIMINAR"', v_sig;
      else
        v_existentes := v_existentes + 1;
      end if;
    end if;
  end loop;

  if v_existentes = array_length(v_internas, 1) then
    raise notice 'OK 2  las 6 funciones internas siguen intactas y con su comentario de blindaje';
  end if;

  -- =====================================================================
  -- 3. Prueba real: register_ticket_payment_v2 + void_ticket_payment_v2.
  -- =====================================================================
  select up.tenant_id, up.user_id
    into v_tenant, v_owner_user
  from public.user_profiles up
  join public.tenant_memberships tm
    on tm.tenant_id = up.tenant_id
   and tm.user_id = up.user_id
   and tm.role = 'tenant_owner'
   and tm.active
  where up.role = 'owner'
    and up.active
  limit 1;

  if v_tenant is null then
    raise notice 'SIN DATOS  no hay ningun usuario con fila valida en user_profiles (legado) Y tenant_memberships (vigente) a la vez -- no se puede armar la prueba real de los wrappers. Los puntos 1 y 2 ya cubrieron lo esencial de H-05.';
  else
    select b.id into v_branch from public.branches b
      where b.tenant_id = v_tenant and b.active limit 1;
    select c.id into v_client from public.clients c
      where c.tenant_id = v_tenant and c.active limit 1;
    select s.id into v_service from public.services s
      where s.tenant_id = v_tenant and s.active limit 1;
    select st.id into v_stylist from public.stylists st
      where st.tenant_id = v_tenant and st.active limit 1;

    if v_branch is null or v_client is null or v_service is null or v_stylist is null then
      raise notice 'SIN DATOS  el tenant encontrado no tiene sede/cliente/servicio/estilista activos. Los puntos 1 y 2 ya cubrieron lo esencial de H-05.';
    else
      perform set_config(
        'request.jwt.claims',
        json_build_object('sub', v_owner_user::text, 'role', 'authenticated')::text,
        true
      );

      insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at)
      values (v_tenant, v_branch, v_client, 'confirmado', 'manual', now())
      returning id into v_ticket;

      insert into public.ticket_services (
        tenant_id, branch_id, ticket_id, service_id, stylist_id,
        price, duration_minutes, status
      ) values (
        v_tenant, v_branch, v_ticket, v_service, v_stylist,
        500, 30, 'pendiente'
      );

      begin
        select p.id into v_payment_id
        from public.register_ticket_payment_v2(v_branch, v_ticket, 200, 'efectivo') p;

        if v_payment_id is null then
          v_fallos := v_fallos + 1;
          raise notice 'FALLO 3  register_ticket_payment_v2 no devolvio ningun pago';
        else
          raise notice 'OK 3a  register_ticket_payment_v2 registro el abono de $200 (llama a register_ticket_payment internamente)';

          perform 1 from public.void_ticket_payment_v2(v_branch, v_payment_id, 'Reverso de prueba, control 195');

          if exists (
            select 1 from public.ticket_payments tp
            where tp.id = v_payment_id and tp.status = 'anulado'
          ) then
            raise notice 'OK 3b  void_ticket_payment_v2 anulo el pago correctamente (llama a void_ticket_payment internamente)';
          else
            v_fallos := v_fallos + 1;
            raise notice 'FALLO 3  void_ticket_payment_v2 no dejo el pago como anulado';
          end if;
        end if;
      exception
        when others then
          v_fallos := v_fallos + 1;
          raise notice 'FALLO 3  la prueba real de los wrappers reventó: %', sqlerrm;
      end;
    end if;
  end if;

  -- =====================================================================
  raise notice ' ';
  if v_fallos = 0 then
    raise notice '=== TODAS LAS PRUEBAS DEL PASO 8.1 (H-05) PASARON ===';
  else
    raise notice '=== % FALLO(S). Revisar arriba. ===', v_fallos;
  end if;

exception
  when others then
    v_error := sqlerrm;
    raise notice ' ';
    raise notice '=== LA PRUEBA SE DETUVO: % ===', v_error;
end;
$$;

rollback;
