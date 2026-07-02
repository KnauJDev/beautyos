-- ============================================================
-- 005_get_agenda_summary.sql
-- BeautyOS AI
-- Propósito:
-- Crear una función segura para listar citas de agenda sin
-- exponer directamente las tablas public.tickets ni relacionadas.
--
-- Nota:
-- Esta función está pensada para etapa MVP/demo.
-- Más adelante se ajustará con autenticación, roles, tenant_id,
-- filtros por día, estilista y sucursal.
-- ============================================================

create or replace function public.get_agenda_summary()
returns table (
  id uuid,
  client_name text,
  scheduled_at timestamptz,
  status text,
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
  where tickets.scheduled_at is not null
    and lower(tickets.status) in ('confirmado', 'en_proceso')
  group by
    tickets.id,
    clients.name,
    tickets.scheduled_at,
    tickets.status
  order by
    tickets.scheduled_at asc;
$$;

grant execute on function public.get_agenda_summary() to anon, authenticated;
