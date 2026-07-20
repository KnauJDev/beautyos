-- BeautyOS - Tramo C4.
-- Auditoria de solo lectura de compatibilidad, seguridad e integridad C1-C3.

do $$
declare
  v_signature text;
  v_table text;
  v_count bigint;
  v_definition text;
begin
  foreach v_signature in array array[
    'public.get_my_branch_context_v2()',
    'public.get_ticket_service_options_v2(uuid)',
    'public.get_available_appointment_slots_v2(uuid,uuid,uuid,date)',
    'public.create_scheduled_ticket_with_service_v2(uuid,uuid,uuid,uuid,timestamptz,text,text)',
    'public.get_tickets_summary_v2(uuid)',
    'public.get_agenda_summary_v2(uuid)',
    'public.get_my_stylist_agenda_by_date_v2(uuid,date)',
    'public.get_ticket_services_for_management_v2(uuid,uuid)',
    'public.add_ticket_service_v2(uuid,uuid,uuid,uuid)',
    'public.update_ticket_service_assignment_v2(uuid,uuid,uuid,uuid,text)',
    'public.remove_ticket_service_v2(uuid,uuid,text)',
    'public.reschedule_ticket_v2(uuid,uuid,timestamptz,text)',
    'public.change_ticket_status_v2(uuid,uuid,text,text)',
    'public.change_ticket_service_status_v2(uuid,uuid,text)',
    'public.get_ticket_services_for_correction_v2(uuid,uuid)',
    'public.reopen_finished_ticket_service_v2(uuid,uuid,text)',
    'public.get_ticket_payment_summary_v2(uuid,uuid)',
    'public.get_ticket_payments_v2(uuid,uuid)',
    'public.register_ticket_payment_v2(uuid,uuid,numeric,text,text,text)',
    'public.void_ticket_payment_v2(uuid,uuid,text)',
    'public.get_daily_close_v2(uuid,date)',
    'public.get_commission_summary_v2(uuid,date)',
    'public.get_branch_financial_summary_v2(uuid)',
    'public.get_sales_report_summary_v2(uuid)',
    'public.get_purchases_summary_v2(uuid)',
    'public.get_purchase_items_summary_v2(uuid)',
    'public.get_expenses_summary_v2(uuid)',
    'public.get_products_summary_v2(uuid)',
    'public.get_inventory_movements_summary_v2(uuid)'
  ] loop
    if to_regprocedure(v_signature) is null then
      raise exception 'C4: falta la RPC %.', v_signature;
    end if;
    if has_function_privilege('anon', v_signature, 'EXECUTE') then
      raise exception 'C4: anon conserva EXECUTE sobre %.', v_signature;
    end if;
    if not has_function_privilege('authenticated', v_signature, 'EXECUTE') then
      raise exception 'C4: authenticated no puede ejecutar %.', v_signature;
    end if;

    select pg_get_functiondef(to_regprocedure(v_signature)) into v_definition;
    if position('SECURITY DEFINER' in v_definition) = 0
       or position('SET search_path TO ''pg_catalog''' in v_definition) = 0 then
      raise exception 'C4: % no conserva SECURITY DEFINER y search_path seguro.', v_signature;
    end if;
  end loop;

  if to_regprocedure(
       'private.beautyos_resolve_branch_access(uuid,text[],boolean)'
     ) is null then
    raise exception 'C4: falta el resolver privado de sede.';
  end if;

  if has_function_privilege(
       'authenticated',
       'private.beautyos_resolve_branch_access(uuid,text[],boolean)',
       'EXECUTE'
     ) then
    raise exception 'C4: el resolver privado es ejecutable directamente.';
  end if;

  foreach v_signature in array array[
    'public.get_tickets_summary()',
    'public.get_agenda_summary()',
    'public.get_daily_close(date,timestamp with time zone,timestamp with time zone)',
    'public.get_commission_summary(timestamp with time zone,timestamp with time zone)',
    'public.get_financial_summary_v2()',
    'public.get_sales_report_summary()',
    'public.get_purchases_summary()',
    'public.get_purchase_items_summary()',
    'public.get_expenses_summary()',
    'public.get_products_summary()',
    'public.get_inventory_movements_summary()'
  ] loop
    if to_regprocedure(v_signature) is null then
      raise exception 'C4: se retiro antes de tiempo la firma heredada %.', v_signature;
    end if;
  end loop;

  foreach v_table in array array[
    'business_hours','appointment_policies','tickets','ticket_services',
    'ticket_history','ticket_service_history','ticket_service_change_history',
    'ticket_payments','stylist_commissions','inventory_movements','purchases',
    'purchase_items','expenses','work_photos','reviews'
  ] loop
    execute format('select count(*) from public.%I where branch_id is null', v_table)
      into v_count;
    if v_count <> 0 then
      raise exception 'C4: %.branch_id contiene % nulo(s).', v_table, v_count;
    end if;

    execute format(
      'select count(*) from public.%1$I x where not exists (' ||
      'select 1 from public.branches b ' ||
      'where b.id=x.branch_id and b.tenant_id=x.tenant_id)',
      v_table
    ) into v_count;
    if v_count <> 0 then
      raise exception 'C4: % contiene % sede(s) ajenas al tenant.', v_table, v_count;
    end if;
  end loop;

  select count(*) into v_count
  from pg_constraint
  where connamespace = 'public'::regnamespace
    and (
      conname like '%tenant_branch_fkey'
      or conname like '%branch_ticket_fkey'
      or conname like '%branch_service_fkey'
      or conname like '%branch_stylist_fkey'
      or conname like '%branch_product_fkey'
      or conname = 'purchase_items_branch_purchase_fkey'
    )
    and not convalidated;
  if v_count <> 0 then
    raise exception 'C4: existen % FK multisede sin validar.', v_count;
  end if;

  select count(*) into v_count
  from pg_trigger
  where not tgisinternal
    and tgname in (
      'business_hours_set_branch','appointment_policies_set_branch',
      'tickets_set_branch','inventory_movements_set_branch',
      'purchases_set_branch','expenses_set_branch','ticket_services_set_branch',
      'ticket_history_set_branch','ticket_service_history_set_branch',
      'ticket_service_change_history_set_branch','ticket_payments_set_branch',
      'stylist_commissions_set_branch','purchase_items_set_branch',
      'work_photos_set_branch','reviews_set_branch'
    );
  if v_count <> 15 then
    raise exception 'C4: se esperaban 15 triggers de compatibilidad y existen %.', v_count;
  end if;

  select count(*) into v_count
  from public.tenants t
  where t.active
    and (
      select count(*)
      from public.branches b
      where b.tenant_id = t.id and b.is_primary
    ) <> 1;
  if v_count <> 0 then
    raise exception 'C4: % tenant(s) activo(s) no tienen exactamente una Sede principal.', v_count;
  end if;

  if to_regclass('public.tickets_branch_schedule_active_idx') is null
     or to_regclass('public.ticket_services_branch_stylist_active_idx') is null
     or to_regclass('public.ticket_payments_branch_received_active_idx') is null
     or to_regclass('public.inventory_movements_branch_created_idx') is null
     or to_regclass('public.purchases_branch_date_active_idx') is null
     or to_regclass('public.expenses_branch_date_active_idx') is null then
    raise exception 'C4: falta al menos un indice operativo por sede.';
  end if;
end;
$$;

select
  (select count(*) from public.tenants where active) as active_tenants,
  (select count(*) from public.branches where active) as active_branches,
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname like '%\_v2' escape '\') as public_v2_functions,
  (select count(*) from public.tickets) as tickets,
  (select coalesce(sum(amount),0) from public.ticket_payments where status='registrado')
    as active_payments,
  (select coalesce(sum(commission_amount),0)
   from public.stylist_commissions where status='generada') as active_commissions,
  (select coalesce(sum(current_stock),0)
   from public.branch_products where active) as branch_stock;
