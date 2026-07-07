-- ============================================================
-- 008_update_dashboard_metrics.sql
-- BeautyOS AI
-- Proposito:
-- Actualizar la funcion segura del Dashboard para incluir
-- metricas de estilistas y servicios asignados.
--
-- Version endurecida:
-- - Usa tenant del usuario conectado.
-- - Requiere usuario autenticado con perfil activo.
-- - No permite acceso anon.
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

  return query
  select
    (
      select count(*)::integer
      from public.services s
      where s.tenant_id = current_tenant_id
        and s.active = true
        and s.visible_to_customer = true
    ) as active_services_count,

    (
      select count(*)::integer
      from public.clients c
      where c.tenant_id = current_tenant_id
        and c.active = true
    ) as clients_count,

    (
      select count(*)::integer
      from public.tickets tk
      where tk.tenant_id = current_tenant_id
        and lower(tk.status) = 'confirmado'
    ) as confirmed_tickets_count,

    (
      select count(*)::integer
      from public.tickets tk
      where tk.tenant_id = current_tenant_id
        and (tk.scheduled_at at time zone 'America/Bogota')::date =
            (now() at time zone 'America/Bogota')::date
    ) as today_tickets_count,

    (
      select count(*)::integer
      from public.stylists st
      where st.tenant_id = current_tenant_id
        and st.active = true
    ) as active_stylists_count,

    (
      select count(*)::integer
      from public.stylist_services ss
      join public.stylists st
        on st.id = ss.stylist_id
       and st.tenant_id = current_tenant_id
      join public.services s
        on s.id = ss.service_id
       and s.tenant_id = current_tenant_id
      where ss.tenant_id = current_tenant_id
        and ss.active = true
        and st.active = true
        and s.active = true
    ) as active_stylist_services_count;
end;
$$;

revoke execute on function public.get_dashboard_metrics() from anon;
revoke execute on function public.get_dashboard_metrics() from public;

grant execute on function public.get_dashboard_metrics() to authenticated;
