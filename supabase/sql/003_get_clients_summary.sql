-- ============================================================
-- 003_get_clients_summary.sql
-- BeautyOS AI
-- Propósito:
-- Crear una función segura para listar clientes resumidos sin
-- exponer directamente toda la tabla public.clients.
--
-- Nota:
-- Esta función está pensada para etapa MVP/demo.
-- Más adelante se ajustará con autenticación, roles y tenant_id.
-- ============================================================

create or replace function public.get_clients_summary()
returns table (
  id uuid,
  name text,
  phone text,
  created_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    clients.id,
    clients.name,
    clients.phone,
    clients.created_at
  from public.clients
  where clients.active = true
  order by clients.created_at desc;
$$;

grant execute on function public.get_clients_summary() to anon, authenticated;
