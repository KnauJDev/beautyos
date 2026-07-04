-- ============================================================
-- BeautyOS - Paso 639
-- Funcion segura de resumen financiero
-- Archivo: supabase/sql/027_get_financial_summary.sql
-- ============================================================

create or replace function public.get_financial_summary()
returns table (
  total_sales numeric,
  total_purchases numeric,
  total_expenses numeric,
  net_result numeric
)
language sql
security definer
set search_path = public
as $$
  select
    coalesce((
      select sum(ticket_services.price)
      from public.tickets
      join public.ticket_services
        on ticket_services.ticket_id = tickets.id
      where lower(tickets.status) in ('confirmado', 'en_proceso', 'finalizado')
    ), 0)::numeric as total_sales,

    coalesce((
      select sum(purchases.total_amount)
      from public.purchases
      where purchases.active = true
    ), 0)::numeric as total_purchases,

    coalesce((
      select sum(expenses.amount)
      from public.expenses
      where expenses.active = true
    ), 0)::numeric as total_expenses,

    (
      coalesce((
        select sum(ticket_services.price)
        from public.tickets
        join public.ticket_services
          on ticket_services.ticket_id = tickets.id
        where lower(tickets.status) in ('confirmado', 'en_proceso', 'finalizado')
      ), 0)
      -
      coalesce((
        select sum(purchases.total_amount)
        from public.purchases
        where purchases.active = true
      ), 0)
      -
      coalesce((
        select sum(expenses.amount)
        from public.expenses
        where expenses.active = true
      ), 0)
    )::numeric as net_result;
$$;

grant execute on function public.get_financial_summary() to anon, authenticated;
