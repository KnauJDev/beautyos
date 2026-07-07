-- ============================================================
-- 003_get_clients_summary.sql
-- BeautyOS AI
-- Propósito:
-- Crear una función segura para listar clientes resumidos sin
-- exponer directamente toda la tabla public.clients.
--
-- Version endurecida:
-- - Usa tenant del usuario conectado.
-- - Requiere rol owner/admin.
-- - No permite acceso anon.
-- ============================================================

create or replace function public.get_clients_summary()
returns table (
  id uuid,
  name text,
  phone text,
  created_at timestamptz
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
    raise exception 'No autorizado. Solo owner o admin puede ver clientes.';
  end if;

  return query
  select
    c.id,
    c.name,
    c.phone,
    c.created_at
  from public.clients c
  where c.tenant_id = current_tenant_id
    and c.active = true
  order by c.created_at desc;
end;
$$;

revoke execute on function public.get_clients_summary() from anon;
revoke execute on function public.get_clients_summary() from public;

grant execute on function public.get_clients_summary() to authenticated;
