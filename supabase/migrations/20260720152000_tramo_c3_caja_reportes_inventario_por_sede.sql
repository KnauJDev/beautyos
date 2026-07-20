-- BeautyOS - Tramo C3: caja, reportes e inventario aislados por sede.
--
-- Alcance aditivo:
-- 1. Toda consulta recibe p_branch_id y valida el acceso en el servidor.
-- 2. El cierre diario calcula sus limites con la zona horaria de la sede.
-- 3. El inventario muestra el stock y los precios propios de branch_products.
-- 4. Las RPC heredadas permanecen intactas durante la ventana de compatibilidad.

begin;

create or replace function public.get_daily_close_v2(
  p_branch_id uuid,
  p_business_date date
)
returns table (
  business_date date,
  payments_count integer,
  paid_tickets_count integer,
  commission_services_count integer,
  total_received numeric,
  cash_received numeric,
  card_received numeric,
  transfer_received numeric,
  other_received numeric,
  total_purchases numeric,
  total_expenses numeric,
  total_commissions numeric,
  expected_cash numeric,
  estimated_result numeric
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_timezone text;
  v_start_at timestamptz;
  v_end_at timestamptz;
begin
  select c.tenant_id, c.timezone
    into v_tenant_id, v_timezone
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner','admin'], true
  ) c;

  if p_business_date is null then
    raise exception 'La fecha del cierre es obligatoria.';
  end if;

  v_start_at := p_business_date::timestamp at time zone v_timezone;
  v_end_at := (p_business_date + 1)::timestamp at time zone v_timezone;

  return query
  with payment_totals as (
    select
      count(*)::integer as payments_count,
      count(distinct tp.ticket_id)::integer as paid_tickets_count,
      coalesce(sum(tp.amount), 0)::numeric as total_received,
      coalesce(sum(tp.amount) filter (where tp.method = 'efectivo'), 0)::numeric as cash_received,
      coalesce(sum(tp.amount) filter (where tp.method = 'tarjeta'), 0)::numeric as card_received,
      coalesce(sum(tp.amount) filter (where tp.method = 'transferencia'), 0)::numeric as transfer_received,
      coalesce(sum(tp.amount) filter (where tp.method = 'otro'), 0)::numeric as other_received
    from public.ticket_payments tp
    where tp.tenant_id = v_tenant_id
      and tp.branch_id = p_branch_id
      and tp.status = 'registrado'
      and tp.received_at >= v_start_at
      and tp.received_at < v_end_at
  ),
  purchase_totals as (
    select
      coalesce(sum(p.total_amount), 0)::numeric as total_purchases,
      coalesce(sum(p.total_amount) filter (where p.payment_method = 'cash'), 0)::numeric as cash_purchases
    from public.purchases p
    where p.tenant_id = v_tenant_id
      and p.branch_id = p_branch_id
      and p.active
      and p.purchase_date = p_business_date
  ),
  expense_totals as (
    select
      coalesce(sum(e.amount), 0)::numeric as total_expenses,
      coalesce(sum(e.amount) filter (where e.payment_method = 'cash'), 0)::numeric as cash_expenses
    from public.expenses e
    where e.tenant_id = v_tenant_id
      and e.branch_id = p_branch_id
      and e.active
      and e.expense_date = p_business_date
  ),
  commission_totals as (
    select
      count(*)::integer as services_count,
      coalesce(sum(sc.commission_amount), 0)::numeric as total_commissions
    from public.stylist_commissions sc
    where sc.tenant_id = v_tenant_id
      and sc.branch_id = p_branch_id
      and sc.status = 'generada'
      and sc.generated_at >= v_start_at
      and sc.generated_at < v_end_at
  )
  select
    p_business_date,
    pt.payments_count,
    pt.paid_tickets_count,
    ct.services_count,
    pt.total_received,
    pt.cash_received,
    pt.card_received,
    pt.transfer_received,
    pt.other_received,
    pur.total_purchases,
    exp.total_expenses,
    ct.total_commissions,
    (pt.cash_received - pur.cash_purchases - exp.cash_expenses)::numeric,
    (pt.total_received - pur.total_purchases - exp.total_expenses - ct.total_commissions)::numeric
  from payment_totals pt
  cross join purchase_totals pur
  cross join expense_totals exp
  cross join commission_totals ct;
end;
$$;

create or replace function public.get_commission_summary_v2(
  p_branch_id uuid,
  p_business_date date
)
returns table (
  stylist_id uuid,
  stylist_name text,
  services_count integer,
  service_sales numeric,
  commission_total numeric
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_timezone text;
  v_start_at timestamptz;
  v_end_at timestamptz;
begin
  select c.tenant_id, c.timezone
    into v_tenant_id, v_timezone
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner','admin'], true
  ) c;

  if p_business_date is null then
    raise exception 'La fecha de comisiones es obligatoria.';
  end if;

  v_start_at := p_business_date::timestamp at time zone v_timezone;
  v_end_at := (p_business_date + 1)::timestamp at time zone v_timezone;

  return query
  select
    st.id,
    st.name,
    count(*)::integer,
    coalesce(sum(sc.service_amount), 0)::numeric,
    coalesce(sum(sc.commission_amount), 0)::numeric
  from public.stylist_commissions sc
  join public.stylists st
    on st.id = sc.stylist_id
   and st.tenant_id = v_tenant_id
  where sc.tenant_id = v_tenant_id
    and sc.branch_id = p_branch_id
    and sc.status = 'generada'
    and sc.generated_at >= v_start_at
    and sc.generated_at < v_end_at
  group by st.id, st.name
  order by commission_total desc, st.name asc;
end;
$$;

create or replace function public.get_branch_financial_summary_v2(
  p_branch_id uuid
)
returns table (
  total_sales numeric,
  total_purchases numeric,
  total_expenses numeric,
  total_commissions numeric,
  net_result numeric
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select c.tenant_id into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner','admin'], true
  ) c;

  return query
  with totals as (
    select
      coalesce((
        select sum(tp.amount)
        from public.ticket_payments tp
        where tp.tenant_id = v_tenant_id
          and tp.branch_id = p_branch_id
          and tp.status = 'registrado'
      ), 0)::numeric as sales,
      coalesce((
        select sum(p.total_amount)
        from public.purchases p
        where p.tenant_id = v_tenant_id
          and p.branch_id = p_branch_id
          and p.active
      ), 0)::numeric as purchases,
      coalesce((
        select sum(e.amount)
        from public.expenses e
        where e.tenant_id = v_tenant_id
          and e.branch_id = p_branch_id
          and e.active
      ), 0)::numeric as expenses,
      coalesce((
        select sum(sc.commission_amount)
        from public.stylist_commissions sc
        where sc.tenant_id = v_tenant_id
          and sc.branch_id = p_branch_id
          and sc.status = 'generada'
      ), 0)::numeric as commissions
  )
  select
    t.sales,
    t.purchases,
    t.expenses,
    t.commissions,
    (t.sales - t.purchases - t.expenses - t.commissions)::numeric
  from totals t;
end;
$$;

create or replace function public.get_sales_report_summary_v2(
  p_branch_id uuid
)
returns table (
  service_name text,
  stylist_name text,
  tickets_count integer,
  total_sales numeric,
  total_duration_minutes integer
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select c.tenant_id into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner','admin'], true
  ) c;

  return query
  select
    coalesce(s.name, 'Sin servicio'),
    coalesce(st.name, 'Sin estilista'),
    count(distinct t.id)::integer,
    coalesce(sum(ts.price), 0)::numeric,
    coalesce(sum(ts.duration_minutes), 0)::integer
  from public.tickets t
  join public.ticket_services ts
    on ts.ticket_id = t.id
   and ts.tenant_id = v_tenant_id
   and ts.branch_id = p_branch_id
   and ts.status = 'finalizado'
  join public.services s
    on s.id = ts.service_id
   and s.tenant_id = v_tenant_id
  left join public.stylists st
    on st.id = ts.stylist_id
   and st.tenant_id = v_tenant_id
  where t.tenant_id = v_tenant_id
    and t.branch_id = p_branch_id
    and t.status = 'cerrado'
  group by s.name, st.name
  order by total_sales desc, service_name asc;
end;
$$;

create or replace function public.get_purchases_summary_v2(
  p_branch_id uuid
)
returns table (
  id uuid,
  supplier_name text,
  purchase_date date,
  invoice_number text,
  total_amount numeric,
  payment_method text,
  notes text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select c.tenant_id into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner','admin'], true
  ) c;

  return query
  select p.id, p.supplier_name, p.purchase_date, p.invoice_number,
         p.total_amount, p.payment_method, p.notes
  from public.purchases p
  where p.tenant_id = v_tenant_id
    and p.branch_id = p_branch_id
    and p.active
  order by p.purchase_date desc, p.created_at desc;
end;
$$;

create or replace function public.get_purchase_items_summary_v2(
  p_branch_id uuid
)
returns table (
  id uuid,
  purchase_id uuid,
  supplier_name text,
  purchase_date date,
  invoice_number text,
  product_name text,
  product_category text,
  quantity numeric,
  unit text,
  unit_cost numeric,
  line_total numeric,
  notes text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select c.tenant_id into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner','admin'], true
  ) c;

  return query
  select
    pi.id, p.id, p.supplier_name, p.purchase_date, p.invoice_number,
    pr.name, pr.category, pi.quantity, pr.unit, pi.unit_cost,
    pi.line_total, pi.notes
  from public.purchase_items pi
  join public.purchases p
    on p.id = pi.purchase_id
   and p.tenant_id = v_tenant_id
   and p.branch_id = p_branch_id
  join public.products pr
    on pr.id = pi.product_id
   and pr.tenant_id = v_tenant_id
  where pi.tenant_id = v_tenant_id
    and pi.branch_id = p_branch_id
    and p.active
    and pr.active
  order by p.purchase_date desc, pi.created_at desc;
end;
$$;

create or replace function public.get_expenses_summary_v2(
  p_branch_id uuid
)
returns table (
  id uuid,
  expense_date date,
  category text,
  description text,
  amount numeric,
  payment_method text,
  notes text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select c.tenant_id into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner','admin'], true
  ) c;

  return query
  select e.id, e.expense_date, e.category, e.description,
         e.amount, e.payment_method, e.notes
  from public.expenses e
  where e.tenant_id = v_tenant_id
    and e.branch_id = p_branch_id
    and e.active
  order by e.expense_date desc, e.created_at desc;
end;
$$;

create or replace function public.get_products_summary_v2(
  p_branch_id uuid
)
returns table (
  id uuid,
  name text,
  category text,
  product_type text,
  unit text,
  current_stock numeric,
  minimum_stock numeric,
  purchase_price numeric,
  sale_price numeric,
  visible_for_sale boolean
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select c.tenant_id into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner','admin'], true
  ) c;

  return query
  select
    p.id, p.name, p.category, p.product_type, p.unit,
    bp.current_stock, bp.minimum_stock, bp.average_cost,
    bp.sale_price, bp.visible_for_sale
  from public.branch_products bp
  join public.products p
    on p.id = bp.product_id
   and p.tenant_id = v_tenant_id
  where bp.tenant_id = v_tenant_id
    and bp.branch_id = p_branch_id
    and bp.active
    and p.active
  order by p.name asc;
end;
$$;

create or replace function public.get_inventory_movements_summary_v2(
  p_branch_id uuid
)
returns table (
  id uuid,
  product_name text,
  product_category text,
  movement_type text,
  quantity numeric,
  unit text,
  unit_cost numeric,
  notes text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select c.tenant_id into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner','admin'], true
  ) c;

  return query
  select
    im.id, p.name, p.category, im.movement_type, im.quantity,
    p.unit, im.unit_cost, im.notes, im.created_at
  from public.inventory_movements im
  join public.products p
    on p.id = im.product_id
   and p.tenant_id = v_tenant_id
  where im.tenant_id = v_tenant_id
    and im.branch_id = p_branch_id
    and p.active
  order by im.created_at desc
  limit 50;
end;
$$;

revoke all on function public.get_daily_close_v2(uuid, date) from public, anon;
revoke all on function public.get_commission_summary_v2(uuid, date) from public, anon;
revoke all on function public.get_branch_financial_summary_v2(uuid) from public, anon;
revoke all on function public.get_sales_report_summary_v2(uuid) from public, anon;
revoke all on function public.get_purchases_summary_v2(uuid) from public, anon;
revoke all on function public.get_purchase_items_summary_v2(uuid) from public, anon;
revoke all on function public.get_expenses_summary_v2(uuid) from public, anon;
revoke all on function public.get_products_summary_v2(uuid) from public, anon;
revoke all on function public.get_inventory_movements_summary_v2(uuid) from public, anon;

grant execute on function public.get_daily_close_v2(uuid, date) to authenticated, service_role;
grant execute on function public.get_commission_summary_v2(uuid, date) to authenticated, service_role;
grant execute on function public.get_branch_financial_summary_v2(uuid) to authenticated, service_role;
grant execute on function public.get_sales_report_summary_v2(uuid) to authenticated, service_role;
grant execute on function public.get_purchases_summary_v2(uuid) to authenticated, service_role;
grant execute on function public.get_purchase_items_summary_v2(uuid) to authenticated, service_role;
grant execute on function public.get_expenses_summary_v2(uuid) to authenticated, service_role;
grant execute on function public.get_products_summary_v2(uuid) to authenticated, service_role;
grant execute on function public.get_inventory_movements_summary_v2(uuid) to authenticated, service_role;

commit;
