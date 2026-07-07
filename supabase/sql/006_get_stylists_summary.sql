-- ============================================================
-- 006_get_stylists_summary.sql
-- BeautyOS AI
-- Propósito:
-- Crear una función segura para listar estilistas activos sin
-- exponer directamente toda la tabla public.stylists.
--
-- Version endurecida:
-- - Usa tenant del usuario conectado.
-- - Requiere rol owner/admin.
-- - No permite acceso anon.
-- ============================================================

create or replace function public.get_stylists_summary()
returns table (
  id uuid,
  name text,
  phone text,
  specialty text,
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
    raise exception 'No autorizado. Solo owner o admin puede ver estilistas.';
  end if;

  return query
  select
    st.id,
    st.name,
    st.phone,
    st.specialty,
    st.created_at
  from public.stylists st
  where st.tenant_id = current_tenant_id
    and st.active = true
  order by st.name asc;
end;
$$;

revoke execute on function public.get_stylists_summary() from anon;
revoke execute on function public.get_stylists_summary() from public;

grant execute on function public.get_stylists_summary() to authenticated;
