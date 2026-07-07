-- ============================================================
-- 007_get_stylist_services_summary.sql
-- BeautyOS AI
-- Propósito:
-- Crear una función segura para listar qué servicios puede
-- realizar cada estilista activo.
--
-- Version endurecida:
-- - Usa tenant del usuario conectado.
-- - Requiere rol owner/admin.
-- - No permite acceso anon.
-- ============================================================

create or replace function public.get_stylist_services_summary()
returns table (
  id uuid,
  stylist_name text,
  service_name text,
  category text,
  price numeric,
  duration_minutes integer,
  active boolean
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
    raise exception 'No autorizado. Solo owner o admin puede ver servicios asignados.';
  end if;

  return query
  select
    ss.id,
    st.name as stylist_name,
    s.name as service_name,
    s.category,
    s.price,
    s.duration_minutes,
    ss.active
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
  order by
    st.name asc,
    s.name asc;
end;
$$;

revoke execute on function public.get_stylist_services_summary() from anon;
revoke execute on function public.get_stylist_services_summary() from public;

grant execute on function public.get_stylist_services_summary() to authenticated;
