-- ============================================================
-- 004_get_tickets_summary.sql
-- BeautyOS AI
-- Propósito:
-- Crear una función segura para listar tickets resumidos sin
-- exponer directamente toda la tabla public.tickets.
--
-- Nota:
-- Esta función está pensada para etapa MVP/demo.
-- Más adelante se ajustará con autenticación, roles y tenant_id.
-- ============================================================

create or replace function public.get_tickets_summary()
returns table (
  id uuid,
  client_name text,
  scheduled_at timestamptz,
  status text,
  channel text,
  service_names text,
  stylist_names text,
  total_price numeric,
  total_duration_minutes integer
)
language sql
security definer
set search_path = public
as $$
  select
    tickets.id,
    coalesce(clients.name, 'Cliente sin nombre') as client_name,
    tickets.scheduled_at,
    tickets.status,
    tickets.channel,
    coalesce(
      string_agg(distinct services.name, ', ' order by services.name),
      'Sin servicios'
    ) as service_names,
    coalesce(
      string_agg(distinct stylists.name, ', ' order by stylists.name),
      'Sin estilista'
    ) as stylist_names,
    coalesce(sum(ticket_services.price), 0)::numeric as total_price,
    coalesce(sum(ticket_services.duration_minutes), 0)::integer as total_duration_minutes
  from public.tickets
  left join public.clients
    on clients.id = tickets.client_id
  left join public.ticket_services
    on ticket_services.ticket_id = tickets.id
  left join public.services
    on services.id = ticket_services.service_id
  left join public.stylists
    on stylists.id = ticket_services.stylist_id
  group by
    tickets.id,
    clients.name,
    tickets.scheduled_at,
    tickets.status,
    tickets.channel,
    tickets.created_at
  order by
    tickets.scheduled_at desc nulls last,
    tickets.created_at desc;
$$;

grant execute on function public.get_tickets_summary() to anon, authenticated;
