-- Migración 20260818160000: Reportes V3 con selector temporal, métodos de pago, arqueo y comparación (Paso 4.7 / D-154)

create or replace function public.get_branch_reports_v3(
  p_branch_id uuid,
  p_start_date date,
  p_end_date date
)
returns table (
  start_date date,
  end_date date,
  total_received numeric,
  payments_count integer,
  paid_tickets_count integer,
  cash_received numeric,
  card_received numeric,
  transfer_received numeric,
  other_received numeric,
  total_purchases numeric,
  cash_purchases numeric,
  total_expenses numeric,
  cash_expenses numeric,
  total_commissions numeric,
  commission_services_count integer,
  expected_cash numeric,
  net_result numeric,
  prev_total_received numeric,
  prev_net_result numeric,
  prev_payments_count integer,
  commissions_by_stylist jsonb,
  sales_by_service jsonb
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_tenant_id uuid;
  v_timezone text;
  v_start_at timestamptz;
  v_end_at timestamptz;
  v_days integer;
  v_prev_start_date date;
  v_prev_end_date date;
  v_prev_start_at timestamptz;
  v_prev_end_at timestamptz;
begin
  select c.tenant_id, c.timezone
    into v_tenant_id, v_timezone
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner','admin'], true
  ) c;

  if p_start_date is null or p_end_date is null then
    raise exception 'Las fechas de inicio y fin son obligatorias.';
  end if;

  if p_end_date < p_start_date then
    raise exception 'La fecha de fin no puede ser anterior a la fecha de inicio.';
  end if;

  v_timezone := coalesce(v_timezone, 'America/Bogota');
  v_start_at := p_start_date::timestamp at time zone v_timezone;
  v_end_at := (p_end_date + 1)::timestamp at time zone v_timezone;

  -- Periodo previo de igual duracion para calculo de tendencias/comparacion
  v_days := (p_end_date - p_start_date) + 1;
  v_prev_start_date := p_start_date - v_days;
  v_prev_end_date := p_start_date - 1;
  v_prev_start_at := v_prev_start_date::timestamp at time zone v_timezone;
  v_prev_end_at := (v_prev_end_date + 1)::timestamp at time zone v_timezone;

  return query
  with current_payments as (
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
  current_purchases as (
    select
      coalesce(sum(p.total_amount), 0)::numeric as total_purchases,
      coalesce(sum(p.total_amount) filter (where p.payment_method = 'cash'), 0)::numeric as cash_purchases
    from public.purchases p
    where p.tenant_id = v_tenant_id
      and p.branch_id = p_branch_id
      and p.active
      and p.purchase_date >= p_start_date
      and p.purchase_date <= p_end_date
  ),
  current_expenses as (
    select
      coalesce(sum(e.amount), 0)::numeric as total_expenses,
      coalesce(sum(e.amount) filter (where e.payment_method = 'cash'), 0)::numeric as cash_expenses
    from public.expenses e
    where e.tenant_id = v_tenant_id
      and e.branch_id = p_branch_id
      and e.active
      and e.expense_date >= p_start_date
      and e.expense_date <= p_end_date
  ),
  current_commissions as (
    select
      count(*)::integer as services_count,
      coalesce(sum(sc.commission_amount), 0)::numeric as total_commissions
    from public.stylist_commissions sc
    where sc.tenant_id = v_tenant_id
      and sc.branch_id = p_branch_id
      and sc.status = 'generada'
      and sc.generated_at >= v_start_at
      and sc.generated_at < v_end_at
  ),
  prev_payments as (
    select
      count(*)::integer as prev_payments_count,
      coalesce(sum(tp.amount), 0)::numeric as prev_total_received
    from public.ticket_payments tp
    where tp.tenant_id = v_tenant_id
      and tp.branch_id = p_branch_id
      and tp.status = 'registrado'
      and tp.received_at >= v_prev_start_at
      and tp.received_at < v_prev_end_at
  ),
  prev_purchases as (
    select
      coalesce(sum(p.total_amount), 0)::numeric as prev_purchases
    from public.purchases p
    where p.tenant_id = v_tenant_id
      and p.branch_id = p_branch_id
      and p.active
      and p.purchase_date >= v_prev_start_date
      and p.purchase_date <= v_prev_end_date
  ),
  prev_expenses as (
    select
      coalesce(sum(e.amount), 0)::numeric as prev_expenses
    from public.expenses e
    where e.tenant_id = v_tenant_id
      and e.branch_id = p_branch_id
      and e.active
      and e.expense_date >= v_prev_start_date
      and e.expense_date <= v_prev_end_date
  ),
  prev_commissions as (
    select
      coalesce(sum(sc.commission_amount), 0)::numeric as prev_commissions
    from public.stylist_commissions sc
    where sc.tenant_id = v_tenant_id
      and sc.branch_id = p_branch_id
      and sc.status = 'generada'
      and sc.generated_at >= v_prev_start_at
      and sc.generated_at < v_prev_end_at
  )
  select
    p_start_date,
    p_end_date,
    cp.total_received,
    cp.payments_count,
    cp.paid_tickets_count,
    cp.cash_received,
    cp.card_received,
    cp.transfer_received,
    cp.other_received,
    pur.total_purchases,
    pur.cash_purchases,
    exp.total_expenses,
    exp.cash_expenses,
    com.total_commissions,
    com.services_count as commission_services_count,
    (cp.cash_received - pur.cash_purchases - exp.cash_expenses)::numeric as expected_cash,
    (cp.total_received - pur.total_purchases - exp.total_expenses - com.total_commissions)::numeric as net_result,
    pp.prev_total_received,
    (pp.prev_total_received - ppu.prev_purchases - pex.prev_expenses - pcom.prev_commissions)::numeric as prev_net_result,
    pp.prev_payments_count,
    (
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'stylist_id', sub.id,
            'stylist_name', sub.name,
            'services_count', sub.cnt,
            'service_sales', sub.sales,
            'commission_total', sub.comm
          )
        ),
        '[]'::jsonb
      )
      from (
        select
          st.id,
          st.name,
          count(*)::integer as cnt,
          coalesce(sum(sc.service_amount), 0)::numeric as sales,
          coalesce(sum(sc.commission_amount), 0)::numeric as comm
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
        order by comm desc, st.name asc
      ) sub
    ) as commissions_by_stylist,
    (
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'service_name', sub.service_name,
            'stylist_name', sub.stylist_name,
            'tickets_count', sub.tickets_count,
            'total_sales', sub.total_sales,
            'total_duration_minutes', sub.total_duration_minutes
          )
        ),
        '[]'::jsonb
      )
      from (
        select
          coalesce(s.name, 'Sin servicio') as service_name,
          coalesce(st.name, 'Sin estilista') as stylist_name,
          count(distinct t.id)::integer as tickets_count,
          coalesce(sum(ts.price), 0)::numeric as total_sales,
          coalesce(sum(ts.duration_minutes), 0)::integer as total_duration_minutes
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
          and t.status in ('finalizado', 'cerrado')
          and coalesce(t.closed_at, t.scheduled_at) >= v_start_at
          and coalesce(t.closed_at, t.scheduled_at) < v_end_at
        group by s.name, st.name
        order by total_sales desc, service_name asc
      ) sub
    ) as sales_by_service
  from current_payments cp
  cross join current_purchases pur
  cross join current_expenses exp
  cross join current_commissions com
  cross join prev_payments pp
  cross join prev_purchases ppu
  cross join prev_expenses pex
  cross join prev_commissions pcom;
end;
$$;

revoke all on function public.get_branch_reports_v3(uuid, date, date) from public, anon;
grant execute on function public.get_branch_reports_v3(uuid, date, date) to authenticated, service_role;
