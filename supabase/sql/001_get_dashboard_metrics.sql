-- ============================================================
-- BeautyOS
-- Archivo: 001_get_dashboard_metrics.sql
-- Propósito:
-- Crear una función segura para que el Dashboard consulte métricas
-- sin exponer directamente tablas privadas como clients o tickets.
-- ============================================================

create or replace function public.get_dashboard_metrics()
returns table (
  active_services_count integer,
  clients_count integer,
  confirmed_tickets_count integer,
  today_tickets_count integer
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
    (
      select count(*)::integer
      from public.services s
      join demo_tenant t on t.id = s.tenant_id
      where s.active = true
        and s.visible_to_customer = true
    ) as active_services_count,

    (
      select count(*)::integer
      from public.clients c
      join demo_tenant t on t.id = c.tenant_id
      where c.active = true
    ) as clients_count,

    (
      select count(*)::integer
      from public.tickets tk
      join demo_tenant t on t.id = tk.tenant_id
      where tk.status = 'confirmado'
    ) as confirmed_tickets_count,

    (
      select count(*)::integer
      from public.tickets tk
      join demo_tenant t on t.id = tk.tenant_id
      where (tk.scheduled_at at time zone 'America/Bogota')::date =
            (now() at time zone 'America/Bogota')::date
    ) as today_tickets_count;
$$;

grant execute on function public.get_dashboard_metrics() to anon, authenticated;

-- Prueba rápida:
-- select * from public.get_dashboard_metrics();