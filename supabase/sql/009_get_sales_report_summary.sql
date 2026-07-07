-- ============================================================
-- 009_get_sales_report_summary.sql
-- BeautyOS AI
-- Proposito:
-- Crear una funcion segura para reportar ventas agrupadas por
-- servicio y estilista, sin exponer directamente las tablas.
--
-- Version endurecida:
-- - Usa tenant del usuario conectado.
-- - Requiere rol owner/admin.
-- - No permite acceso anon.
-- ============================================================

create or replace function public.get_sales_report_summary()
returns table (
  service_name text,
  stylist_name text,
  tickets_count integer,
  total_sales numeric,
  total_duration_minutes integer
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
    raise exception 'No autorizado. Solo owner o admin puede ver reportes de ventas.';
  end if;

  return query
  select
    coalesce(s.name, 'Sin servicio') as service_name,
    coalesce(st.name, 'Sin estilista') as stylist_name,
    count(distinct t.id)::integer as tickets_count,
    coalesce(sum(ts.price), 0)::numeric as total_sales,
    coalesce(sum(ts.duration_minutes), 0)::integer as total_duration_minutes
  from public.tickets t
  left join public.ticket_services ts
    on ts.ticket_id = t.id
    and ts.tenant_id = current_tenant_id
  left join public.services s
    on s.id = ts.service_id
    and s.tenant_id = current_tenant_id
    and s.active = true
  left join public.stylists st
    on st.id = ts.stylist_id
    and st.tenant_id = current_tenant_id
    and st.active = true
  where t.tenant_id = current_tenant_id
    and lower(t.status) in ('confirmado', 'en_proceso', 'finalizado')
  group by
    s.name,
    st.name
  order by
    total_sales desc,
    service_name asc;
end;
$$;

revoke execute on function public.get_sales_report_summary() from anon;
revoke execute on function public.get_sales_report_summary() from public;

grant execute on function public.get_sales_report_summary() to authenticated;
