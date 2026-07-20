-- BeautyOS - Verificacion repetible del Tramo B.
-- Solo lectura: no modifica datos ni estructura.

do $$
declare
  v_table text;
  v_count bigint;
begin
  foreach v_table in array array[
    'business_hours','appointment_policies','tickets','ticket_services',
    'ticket_history','ticket_service_history','ticket_service_change_history',
    'ticket_payments','stylist_commissions','inventory_movements','purchases',
    'purchase_items','expenses','work_photos','reviews'
  ] loop
    execute format('select count(*) from public.%I where branch_id is null', v_table)
      into v_count;
    if v_count <> 0 then
      raise exception 'Tramo B invalido: %.branch_id tiene % nulo(s).', v_table, v_count;
    end if;

    execute format(
      'select count(*) from public.%1$I x where not exists (' ||
      'select 1 from public.branches b where b.id=x.branch_id and b.tenant_id=x.tenant_id)',
      v_table
    ) into v_count;
    if v_count <> 0 then
      raise exception 'Tramo B invalido: % tiene % sede(s) ajenas al tenant.', v_table, v_count;
    end if;
  end loop;

  select count(*) into v_count
  from public.ticket_services x
  join public.tickets t on t.id = x.ticket_id
  where (x.tenant_id, x.branch_id) is distinct from (t.tenant_id, t.branch_id);
  if v_count <> 0 then
    raise exception 'Tramo B invalido: % servicio(s) no heredan la sede del ticket.', v_count;
  end if;

  select count(*) into v_count
  from public.ticket_history x
  join public.tickets t on t.id = x.ticket_id
  where (x.tenant_id, x.branch_id) is distinct from (t.tenant_id, t.branch_id);
  if v_count <> 0 then
    raise exception 'Tramo B invalido: % historial(es) no heredan la sede del ticket.', v_count;
  end if;

  select count(*) into v_count
  from public.ticket_service_history x
  join public.tickets t on t.id = x.ticket_id
  join public.ticket_services ts on ts.id = x.ticket_service_id
  where (x.tenant_id, x.branch_id) is distinct from (t.tenant_id, t.branch_id)
     or (x.tenant_id, x.branch_id, x.ticket_id)
        is distinct from (ts.tenant_id, ts.branch_id, ts.ticket_id);
  if v_count <> 0 then
    raise exception 'Tramo B invalido: % historial(es) de servicio con contexto cruzado.', v_count;
  end if;

  select count(*) into v_count
  from public.ticket_service_change_history x
  join public.tickets t on t.id = x.ticket_id
  join public.ticket_services ts on ts.id = x.ticket_service_id
  where (x.tenant_id, x.branch_id) is distinct from (t.tenant_id, t.branch_id)
     or (x.tenant_id, x.branch_id, x.ticket_id)
        is distinct from (ts.tenant_id, ts.branch_id, ts.ticket_id);
  if v_count <> 0 then
    raise exception 'Tramo B invalido: % cambio(s) de servicio con contexto cruzado.', v_count;
  end if;

  select count(*) into v_count
  from public.ticket_payments x
  join public.tickets t on t.id = x.ticket_id
  where (x.tenant_id, x.branch_id) is distinct from (t.tenant_id, t.branch_id);
  if v_count <> 0 then
    raise exception 'Tramo B invalido: % pago(s) no heredan la sede del ticket.', v_count;
  end if;

  select count(*) into v_count
  from public.stylist_commissions x
  join public.tickets t on t.id = x.ticket_id
  join public.ticket_services ts on ts.id = x.ticket_service_id
  where (x.tenant_id, x.branch_id) is distinct from (t.tenant_id, t.branch_id)
     or (x.tenant_id, x.branch_id, x.ticket_id)
        is distinct from (ts.tenant_id, ts.branch_id, ts.ticket_id);
  if v_count <> 0 then
    raise exception 'Tramo B invalido: % comision(es) con contexto cruzado.', v_count;
  end if;

  select count(*) into v_count
  from public.purchase_items x
  join public.purchases p on p.id = x.purchase_id
  where (x.tenant_id, x.branch_id) is distinct from (p.tenant_id, p.branch_id);
  if v_count <> 0 then
    raise exception 'Tramo B invalido: % item(s) no heredan la sede de la compra.', v_count;
  end if;

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
    raise exception 'Tramo B invalido: % nueva(s) FK siguen sin validar.', v_count;
  end if;

  select count(*) into v_count
  from pg_trigger
  where not tgisinternal
    and tgname in (
      'business_hours_set_branch','appointment_policies_set_branch','tickets_set_branch',
      'inventory_movements_set_branch','purchases_set_branch','expenses_set_branch',
      'ticket_services_set_branch','ticket_history_set_branch',
      'ticket_service_history_set_branch','ticket_service_change_history_set_branch',
      'ticket_payments_set_branch','stylist_commissions_set_branch',
      'purchase_items_set_branch','work_photos_set_branch','reviews_set_branch'
    );
  if v_count <> 15 then
    raise exception 'Tramo B invalido: se esperaban 15 triggers puente y existen %.', v_count;
  end if;

  select count(*) into v_count
  from information_schema.role_routine_grants
  where routine_schema = 'private'
    and routine_name like 'beautyos_%branch%'
    and grantee in ('PUBLIC','anon','authenticated');
  if v_count <> 0 then
    raise exception 'Tramo B invalido: hay % grant(s) directos sobre helpers privados.', v_count;
  end if;
end;
$$;

select
  (select count(*) from public.tickets) as tickets,
  (select count(*) from public.ticket_services) as ticket_services,
  (select count(*) from public.ticket_history) as ticket_history,
  (select count(*) from public.ticket_service_history) as ticket_service_history,
  (select count(*) from public.ticket_service_change_history) as ticket_service_changes,
  (select count(*) from public.ticket_payments) as ticket_payments,
  (select count(*) from public.stylist_commissions) as stylist_commissions,
  (select count(*) from public.inventory_movements) as inventory_movements,
  (select count(*) from public.purchases) as purchases,
  (select count(*) from public.purchase_items) as purchase_items,
  (select count(*) from public.expenses) as expenses,
  (select count(*) from public.work_photos) as work_photos,
  (select count(*) from public.reviews) as reviews;

select
  (select coalesce(sum(amount), 0) from public.ticket_payments where status='registrado') as active_payments,
  (select coalesce(sum(amount), 0) from public.ticket_payments where status='anulado') as voided_payments,
  (select coalesce(sum(commission_amount), 0) from public.stylist_commissions where status='generada') as active_commissions,
  (select coalesce(sum(commission_amount), 0) from public.stylist_commissions where status='anulada') as voided_commissions,
  (select coalesce(sum(current_stock), 0) from public.branch_products where active) as branch_stock;
