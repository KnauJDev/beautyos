-- Paso 1031: incluir pagado y saldo en el resumen administrativo de tickets.

drop function if exists public.get_tickets_summary();

create function public.get_tickets_summary()
returns table(
  id uuid,
  client_name text,
  scheduled_at timestamptz,
  status text,
  channel text,
  service_names text,
  stylist_names text,
  total_price numeric,
  total_duration_minutes integer,
  paid_amount numeric,
  balance_amount numeric,
  payment_status text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  current_tenant_id uuid;
begin
  current_tenant_id := public.get_my_tenant_id();

  if current_tenant_id is null then
    raise exception 'No existe un perfil activo asociado al usuario actual.';
  end if;

  if not public.is_owner_or_admin() then
    raise exception 'No autorizado. Solo owner o admin puede ver tickets.';
  end if;

  return query
  with service_summary as (
    select
      ts.ticket_id,
      coalesce(
        string_agg(distinct s.name, ', ' order by s.name)
          filter (where ts.status <> 'cancelado'),
        'Sin servicios'
      ) as service_names,
      coalesce(
        string_agg(distinct st.name, ', ' order by st.name)
          filter (where ts.status <> 'cancelado'),
        'Sin estilista'
      ) as stylist_names,
      coalesce(sum(ts.price) filter (where ts.status <> 'cancelado'), 0)::numeric
        as total_price,
      coalesce(
        sum(ts.duration_minutes) filter (where ts.status <> 'cancelado'),
        0
      )::integer as total_duration_minutes
    from public.ticket_services ts
    left join public.services s
      on s.id = ts.service_id
     and s.tenant_id = current_tenant_id
    left join public.stylists st
      on st.id = ts.stylist_id
     and st.tenant_id = current_tenant_id
    where ts.tenant_id = current_tenant_id
    group by ts.ticket_id
  ),
  payment_summary as (
    select
      tp.ticket_id,
      coalesce(sum(tp.amount), 0)::numeric as paid_amount
    from public.ticket_payments tp
    where tp.tenant_id = current_tenant_id
      and tp.status = 'registrado'
    group by tp.ticket_id
  )
  select
    tk.id,
    coalesce(c.name, 'Cliente sin nombre'),
    tk.scheduled_at,
    tk.status,
    tk.channel,
    coalesce(ss.service_names, 'Sin servicios'),
    coalesce(ss.stylist_names, 'Sin estilista'),
    coalesce(ss.total_price, 0)::numeric,
    coalesce(ss.total_duration_minutes, 0)::integer,
    coalesce(ps.paid_amount, 0)::numeric,
    greatest(
      coalesce(ss.total_price, 0) - coalesce(ps.paid_amount, 0),
      0
    )::numeric,
    case
      when coalesce(ps.paid_amount, 0) = 0 then 'sin_pago'
      when coalesce(ps.paid_amount, 0) < coalesce(ss.total_price, 0) then 'parcial'
      else 'pagado'
    end
  from public.tickets tk
  left join public.clients c
    on c.id = tk.client_id
   and c.tenant_id = current_tenant_id
   and c.active = true
  left join service_summary ss
    on ss.ticket_id = tk.id
  left join payment_summary ps
    on ps.ticket_id = tk.id
  where tk.tenant_id = current_tenant_id
  order by tk.scheduled_at desc nulls last, tk.created_at desc;
end;
$$;

revoke all on function public.get_tickets_summary() from public;
revoke all on function public.get_tickets_summary() from anon;
grant execute on function public.get_tickets_summary() to authenticated;
