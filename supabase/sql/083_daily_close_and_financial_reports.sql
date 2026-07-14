-- Paso 1035: cierre diario, resumen de comisiones y finanzas sobre dinero recibido.

create or replace function public.get_daily_close(
  p_business_date date,
  p_start_at timestamptz,
  p_end_at timestamptz
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
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_role text;
begin
  select up.tenant_id, up.role
    into v_tenant_id, v_role
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.active = true
  limit 1;

  if v_tenant_id is null or v_role not in ('owner', 'admin') then
    raise exception 'Solo owner o admin puede consultar el cierre diario.';
  end if;

  if p_business_date is null or p_start_at is null or p_end_at is null then
    raise exception 'La fecha y el intervalo del cierre son obligatorios.';
  end if;

  if p_end_at <= p_start_at or p_end_at - p_start_at > interval '36 hours' then
    raise exception 'El intervalo del cierre diario no es valido.';
  end if;

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
      and tp.status = 'registrado'
      and tp.received_at >= p_start_at
      and tp.received_at < p_end_at
  ),
  purchase_totals as (
    select
      coalesce(sum(p.total_amount), 0)::numeric as total_purchases,
      coalesce(sum(p.total_amount) filter (where p.payment_method = 'cash'), 0)::numeric as cash_purchases
    from public.purchases p
    where p.tenant_id = v_tenant_id
      and p.active = true
      and p.purchase_date = p_business_date
  ),
  expense_totals as (
    select
      coalesce(sum(e.amount), 0)::numeric as total_expenses,
      coalesce(sum(e.amount) filter (where e.payment_method = 'cash'), 0)::numeric as cash_expenses
    from public.expenses e
    where e.tenant_id = v_tenant_id
      and e.active = true
      and e.expense_date = p_business_date
  ),
  commission_totals as (
    select
      count(*)::integer as services_count,
      coalesce(sum(sc.commission_amount), 0)::numeric as total_commissions
    from public.stylist_commissions sc
    where sc.tenant_id = v_tenant_id
      and sc.status = 'generada'
      and sc.generated_at >= p_start_at
      and sc.generated_at < p_end_at
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

create or replace function public.get_commission_summary(
  p_start_at timestamptz,
  p_end_at timestamptz
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
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_role text;
begin
  select up.tenant_id, up.role
    into v_tenant_id, v_role
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.active = true
  limit 1;

  if v_tenant_id is null or v_role not in ('owner', 'admin') then
    raise exception 'Solo owner o admin puede consultar comisiones.';
  end if;

  if p_start_at is null or p_end_at is null or p_end_at <= p_start_at then
    raise exception 'El intervalo de comisiones no es valido.';
  end if;

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
    and sc.status = 'generada'
    and sc.generated_at >= p_start_at
    and sc.generated_at < p_end_at
  group by st.id, st.name
  order by commission_total desc, st.name asc;
end;
$$;

create or replace function public.get_financial_summary_v2()
returns table (
  total_sales numeric,
  total_purchases numeric,
  total_expenses numeric,
  total_commissions numeric,
  net_result numeric
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_role text;
begin
  select up.tenant_id, up.role
    into v_tenant_id, v_role
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.active = true
  limit 1;

  if v_tenant_id is null or v_role not in ('owner', 'admin') then
    raise exception 'Solo owner o admin puede ver el resumen financiero.';
  end if;

  return query
  with totals as (
    select
      coalesce((
        select sum(tp.amount) from public.ticket_payments tp
        where tp.tenant_id = v_tenant_id and tp.status = 'registrado'
      ), 0)::numeric as sales,
      coalesce((
        select sum(p.total_amount) from public.purchases p
        where p.tenant_id = v_tenant_id and p.active = true
      ), 0)::numeric as purchases,
      coalesce((
        select sum(e.amount) from public.expenses e
        where e.tenant_id = v_tenant_id and e.active = true
      ), 0)::numeric as expenses,
      coalesce((
        select sum(sc.commission_amount) from public.stylist_commissions sc
        where sc.tenant_id = v_tenant_id and sc.status = 'generada'
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

create or replace function public.get_sales_report_summary()
returns table (
  service_name text,
  stylist_name text,
  tickets_count integer,
  total_sales numeric,
  total_duration_minutes integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_role text;
begin
  select up.tenant_id, up.role
    into v_tenant_id, v_role
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.active = true
  limit 1;

  if v_tenant_id is null or v_role not in ('owner', 'admin') then
    raise exception 'Solo owner o admin puede ver reportes de ventas.';
  end if;

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
   and ts.status = 'finalizado'
  join public.services s
    on s.id = ts.service_id
   and s.tenant_id = v_tenant_id
  left join public.stylists st
    on st.id = ts.stylist_id
   and st.tenant_id = v_tenant_id
  where t.tenant_id = v_tenant_id
    and t.status = 'cerrado'
  group by s.name, st.name
  order by total_sales desc, service_name asc;
end;
$$;

revoke all on function public.get_daily_close(date, timestamptz, timestamptz) from public;
revoke all on function public.get_daily_close(date, timestamptz, timestamptz) from anon;
grant execute on function public.get_daily_close(date, timestamptz, timestamptz) to authenticated;

revoke all on function public.get_commission_summary(timestamptz, timestamptz) from public;
revoke all on function public.get_commission_summary(timestamptz, timestamptz) from anon;
grant execute on function public.get_commission_summary(timestamptz, timestamptz) to authenticated;

revoke all on function public.get_financial_summary_v2() from public;
revoke all on function public.get_financial_summary_v2() from anon;
grant execute on function public.get_financial_summary_v2() to authenticated;

revoke all on function public.get_sales_report_summary() from public;
revoke all on function public.get_sales_report_summary() from anon;
grant execute on function public.get_sales_report_summary() to authenticated;
