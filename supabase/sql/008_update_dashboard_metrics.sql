-- ============================================================
-- 008_update_dashboard_metrics.sql
-- BeautyOS AI
-- Proposito:
-- Actualizar la funcion segura del Dashboard para incluir
-- metricas de estilistas y servicios asignados.
--
-- Nota:
-- Se elimina y recrea la funcion porque cambia la estructura
-- de columnas retornadas.
-- ============================================================

drop function if exists public.get_dashboard_metrics();

create or replace function public.get_dashboard_metrics()
returns table (
  active_services_count integer,
  clients_count integer,
  confirmed_tickets_count integer,
  today_tickets_count integer,
  active_stylists_count integer,
  active_stylist_services_count integer
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
    ) as today_tickets_count,

    (
      select count(*)::integer
      from public.stylists st
      join demo_tenant t on t.id = st.tenant_id
      where st.active = true
    ) as active_stylists_count,

    (
      select count(*)::integer
      from public.stylist_services ss
      join demo_tenant t on t.id = ss.tenant_id
      join public.stylists st on st.id = ss.stylist_id
      join public.services s on s.id = ss.service_id
      where ss.active = true
        and st.active = true
        and s.active = true
    ) as active_stylist_services_count;
$$;

grant execute on function public.get_dashboard_metrics() to anon, authenticated;
