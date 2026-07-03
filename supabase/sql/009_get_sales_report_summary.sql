-- ============================================================
-- 009_get_sales_report_summary.sql
-- BeautyOS AI
-- Proposito:
-- Crear una funcion segura para reportar ventas agrupadas por
-- servicio y estilista, sin exponer directamente las tablas.
--
-- Nota:
-- Esta funcion esta pensada para etapa MVP/demo.
-- Mas adelante se ajustara con filtros por fecha, tenant_id,
-- sucursal, metodo de pago y estados contables.
-- ============================================================

create or replace function public.get_sales_report_summary()
returns table (
  service_name text,
  stylist_name text,
  tickets_count integer,
  total_sales numeric,
  total_duration_minutes integer
)
language sql
security definer
set search_path = public
as $$
  with demo_tenant as (
    select id
    from public.tenants
    where name = 'Bella Mujer'
    limit 1
  )
  select
    coalesce(services.name, 'Sin servicio') as service_name,
    coalesce(stylists.name, 'Sin estilista') as stylist_name,
    count(distinct tickets.id)::integer as tickets_count,
    coalesce(sum(ticket_services.price), 0)::numeric as total_sales,
    coalesce(sum(ticket_services.duration_minutes), 0)::integer
      as total_duration_minutes
  from public.tickets
  join demo_tenant t
    on t.id = tickets.tenant_id
  left join public.ticket_services
    on ticket_services.ticket_id = tickets.id
  left join public.services
    on services.id = ticket_services.service_id
  left join public.stylists
    on stylists.id = ticket_services.stylist_id
  where lower(tickets.status) in ('confirmado', 'en_proceso', 'finalizado')
  group by
    services.name,
    stylists.name
  order by
    total_sales desc,
    service_name asc;
$$;

grant execute on function public.get_sales_report_summary() to anon, authenticated;
