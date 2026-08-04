-- Punto 5 de BENCHMARKING_2026-07-28.md: saldo acumulado del cliente.
-- get_clients_management_summary() gana balance_amount: suma del saldo
-- pendiente de todos los tickets `finalizado` del cliente, con el mismo
-- criterio que ya usa register_ticket_payment()/get_ticket_payment_summary()
-- (total de ticket_services finalizado menos pagos registrados). Un ticket
-- pasa a `cerrado` al pagarse por completo, así que deja de sumar.

drop function if exists public.get_clients_management_summary();

create or replace function public.get_clients_management_summary()
returns table (
  id uuid,
  name text,
  phone text,
  email text,
  notes text,
  active boolean,
  created_at timestamptz,
  balance_amount numeric
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
begin
  v_tenant_id := public.get_my_tenant_id();

  if v_tenant_id is null then
    raise exception 'No existe un perfil activo asociado al usuario actual.';
  end if;

  if not public.is_owner_or_admin() then
    raise exception 'No autorizado. Solo owner o admin puede administrar clientes.';
  end if;

  return query
  with ticket_totals as (
    select
      t.id as ticket_id,
      t.client_id,
      coalesce(sum(ts.price) filter (where ts.status = 'finalizado'), 0)::numeric as total_amount
    from public.tickets t
    join public.ticket_services ts
      on ts.ticket_id = t.id
     and ts.tenant_id = v_tenant_id
    where t.tenant_id = v_tenant_id
      and t.status = 'finalizado'
    group by t.id, t.client_id
  ),
  ticket_paid as (
    select
      tp.ticket_id,
      coalesce(sum(tp.amount), 0)::numeric as paid_amount
    from public.ticket_payments tp
    where tp.tenant_id = v_tenant_id
      and tp.status = 'registrado'
    group by tp.ticket_id
  ),
  client_balances as (
    select
      tt.client_id,
      sum(greatest(tt.total_amount - coalesce(tpaid.paid_amount, 0), 0)) as balance_amount
    from ticket_totals tt
    left join ticket_paid tpaid on tpaid.ticket_id = tt.ticket_id
    group by tt.client_id
  )
  select
    c.id,
    c.name,
    c.phone,
    c.email,
    c.notes,
    c.active,
    c.created_at,
    coalesce(cb.balance_amount, 0)::numeric
  from public.clients c
  left join client_balances cb on cb.client_id = c.id
  where c.tenant_id = v_tenant_id
  order by c.active desc, lower(c.name) asc, c.created_at desc;
end;
$$;

revoke all on function public.get_clients_management_summary() from public;
revoke all on function public.get_clients_management_summary() from anon;
grant execute on function public.get_clients_management_summary() to authenticated;
