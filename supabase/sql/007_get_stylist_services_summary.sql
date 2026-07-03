-- ============================================================
-- 007_get_stylist_services_summary.sql
-- BeautyOS AI
-- Propósito:
-- Crear una función segura para listar qué servicios puede
-- realizar cada estilista activo.
--
-- Nota:
-- Esta función está pensada para etapa MVP/demo.
-- Más adelante se ajustará con autenticación, roles, tenant_id,
-- disponibilidad, comisiones y reglas por sucursal.
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
language sql
security definer
set search_path = public
as $$
  select
    stylist_services.id,
    stylists.name as stylist_name,
    services.name as service_name,
    services.category,
    services.price,
    services.duration_minutes,
    stylist_services.active
  from public.stylist_services
  left join public.stylists
    on stylists.id = stylist_services.stylist_id
  left join public.services
    on services.id = stylist_services.service_id
  where stylist_services.active = true
    and stylists.active = true
    and services.active = true
  order by
    stylists.name asc,
    services.name asc;
$$;

grant execute on function public.get_stylist_services_summary() to anon, authenticated;
