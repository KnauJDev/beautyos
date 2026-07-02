-- ============================================================
-- 006_get_stylists_summary.sql
-- BeautyOS AI
-- Propósito:
-- Crear una función segura para listar estilistas activos sin
-- exponer directamente toda la tabla public.stylists.
--
-- Nota:
-- Esta función está pensada para etapa MVP/demo.
-- Más adelante se ajustará con autenticación, roles, tenant_id,
-- horarios, disponibilidad y ranking.
-- ============================================================

create or replace function public.get_stylists_summary()
returns table (
  id uuid,
  name text,
  phone text,
  specialty text,
  created_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    stylists.id,
    stylists.name,
    stylists.phone,
    stylists.specialty,
    stylists.created_at
  from public.stylists
  where stylists.active = true
  order by stylists.name asc;
$$;

grant execute on function public.get_stylists_summary() to anon, authenticated;
