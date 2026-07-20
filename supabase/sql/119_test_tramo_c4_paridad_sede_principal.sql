-- BeautyOS - Tramo C4.
-- Paridad reversible entre contratos heredados y contratos por sede.

begin;

do $$
declare
  v_tenant_id uuid;
  v_owner_user uuid;
  v_primary_branch uuid;
  v_timezone text;
  v_business_date date;
  v_start_at timestamptz;
  v_end_at timestamptz;
  v_table text;
  v_count bigint;
begin
  select tm.tenant_id, tm.user_id, b.id, b.timezone
    into v_tenant_id, v_owner_user, v_primary_branch, v_timezone
  from public.tenant_memberships tm
  join public.branches b
    on b.tenant_id = tm.tenant_id
   and b.is_primary
   and b.active
  where tm.role = 'tenant_owner'
    and tm.active
  order by tm.created_at
  limit 1;

  if v_owner_user is null or v_primary_branch is null then
    raise exception 'La prueba C4 requiere un owner y una Sede principal activos.';
  end if;

  -- La ruta heredada consulta el tenant completo. Solo puede ser equivalente
  -- a la ruta por sede si el conjunto heredado está íntegramente en la principal.
  foreach v_table in array array[
    'tickets','ticket_services','ticket_history','ticket_service_history',
    'ticket_service_change_history','ticket_payments','stylist_commissions',
    'inventory_movements','purchases','purchase_items','expenses',
    'work_photos','reviews'
  ] loop
    execute format(
      'select count(*) from public.%I where tenant_id = $1 and branch_id <> $2',
      v_table
    ) into v_count using v_tenant_id, v_primary_branch;
    if v_count <> 0 then
      raise exception 'Paridad no aplicable: % contiene % registro(s) fuera de la Sede principal.',
        v_table, v_count;
    end if;
  end loop;

  select coalesce(
      max((tp.received_at at time zone v_timezone)::date),
      (now() at time zone v_timezone)::date
    )
    into v_business_date
  from public.ticket_payments tp
  where tp.tenant_id = v_tenant_id
    and tp.branch_id = v_primary_branch;

  v_start_at := v_business_date::timestamp at time zone v_timezone;
  v_end_at := (v_business_date + 1)::timestamp at time zone v_timezone;

  perform set_config('request.jwt.claim.sub', v_owner_user::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  execute 'set local role authenticated';

  if exists (
    select 1 from (
      (select * from public.get_tickets_summary()
       except all
       select * from public.get_tickets_summary_v2(v_primary_branch))
      union all
      (select * from public.get_tickets_summary_v2(v_primary_branch)
       except all
       select * from public.get_tickets_summary())
    ) difference
  ) then
    raise exception 'C4: get_tickets_summary no conserva paridad en la Sede principal.';
  end if;

  if exists (
    select 1 from (
      (select * from public.get_agenda_summary()
       except all
       select * from public.get_agenda_summary_v2(v_primary_branch))
      union all
      (select * from public.get_agenda_summary_v2(v_primary_branch)
       except all
       select * from public.get_agenda_summary())
    ) difference
  ) then
    raise exception 'C4: get_agenda_summary no conserva paridad en la Sede principal.';
  end if;

  if exists (
    select 1 from (
      (select * from public.get_daily_close(v_business_date, v_start_at, v_end_at)
       except all
       select * from public.get_daily_close_v2(v_primary_branch, v_business_date))
      union all
      (select * from public.get_daily_close_v2(v_primary_branch, v_business_date)
       except all
       select * from public.get_daily_close(v_business_date, v_start_at, v_end_at))
    ) difference
  ) then
    raise exception 'C4: cierre diario no conserva paridad en la Sede principal.';
  end if;

  if exists (
    select 1 from (
      (select * from public.get_commission_summary(v_start_at, v_end_at)
       except all
       select * from public.get_commission_summary_v2(v_primary_branch, v_business_date))
      union all
      (select * from public.get_commission_summary_v2(v_primary_branch, v_business_date)
       except all
       select * from public.get_commission_summary(v_start_at, v_end_at))
    ) difference
  ) then
    raise exception 'C4: comisiones no conservan paridad en la Sede principal.';
  end if;

  if exists (
    select 1 from (
      (select * from public.get_financial_summary_v2()
       except all
       select * from public.get_branch_financial_summary_v2(v_primary_branch))
      union all
      (select * from public.get_branch_financial_summary_v2(v_primary_branch)
       except all
       select * from public.get_financial_summary_v2())
    ) difference
  ) then
    raise exception 'C4: resumen financiero no conserva paridad en la Sede principal.';
  end if;

  if exists (
    select 1 from (
      (select * from public.get_sales_report_summary()
       except all
       select * from public.get_sales_report_summary_v2(v_primary_branch))
      union all
      (select * from public.get_sales_report_summary_v2(v_primary_branch)
       except all
       select * from public.get_sales_report_summary())
    ) difference
  ) then
    raise exception 'C4: reporte de ventas no conserva paridad en la Sede principal.';
  end if;

  if exists (
    select 1 from (
      (select * from public.get_purchases_summary()
       except all
       select * from public.get_purchases_summary_v2(v_primary_branch))
      union all
      (select * from public.get_purchases_summary_v2(v_primary_branch)
       except all
       select * from public.get_purchases_summary())
    ) difference
  ) then
    raise exception 'C4: compras no conservan paridad en la Sede principal.';
  end if;

  if exists (
    select 1 from (
      (select * from public.get_purchase_items_summary()
       except all
       select * from public.get_purchase_items_summary_v2(v_primary_branch))
      union all
      (select * from public.get_purchase_items_summary_v2(v_primary_branch)
       except all
       select * from public.get_purchase_items_summary())
    ) difference
  ) then
    raise exception 'C4: detalle de compras no conserva paridad en la Sede principal.';
  end if;

  if exists (
    select 1 from (
      (select * from public.get_expenses_summary()
       except all
       select * from public.get_expenses_summary_v2(v_primary_branch))
      union all
      (select * from public.get_expenses_summary_v2(v_primary_branch)
       except all
       select * from public.get_expenses_summary())
    ) difference
  ) then
    raise exception 'C4: gastos no conservan paridad en la Sede principal.';
  end if;

  if exists (
    select 1 from (
      (select * from public.get_products_summary()
       except all
       select * from public.get_products_summary_v2(v_primary_branch))
      union all
      (select * from public.get_products_summary_v2(v_primary_branch)
       except all
       select * from public.get_products_summary())
    ) difference
  ) then
    raise exception 'C4: productos/stock no conservan paridad en la Sede principal.';
  end if;

  if exists (
    select 1 from (
      (select * from public.get_inventory_movements_summary()
       except all
       select * from public.get_inventory_movements_summary_v2(v_primary_branch))
      union all
      (select * from public.get_inventory_movements_summary_v2(v_primary_branch)
       except all
       select * from public.get_inventory_movements_summary())
    ) difference
  ) then
    raise exception 'C4: movimientos de inventario no conservan paridad en la Sede principal.';
  end if;

  execute 'reset role';
end;
$$;

rollback;
