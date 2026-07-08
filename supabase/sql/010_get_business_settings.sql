-- ============================================================
-- 010_get_business_settings.sql
-- BeautyOS AI
-- Propósito:
-- Obtener los datos básicos de configuración del negocio
-- del usuario autenticado.
--
-- Versión endurecida:
-- - Usa tenant del usuario conectado.
-- - Requiere rol owner/admin.
-- - No permite acceso anon.
-- - Evita leer el primer tenant activo por error.
-- ============================================================

create or replace function public.get_business_settings()
returns table (
  id uuid,
  name text,
  business_type text,
  contact_email text,
  contact_phone text,
  whatsapp text,
  instagram text,
  facebook text
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
    raise exception 'No autorizado. Solo owner o admin puede ver la configuración del negocio.';
  end if;

  return query
  select
    t.id,
    t.name,
    t.business_type,
    t.contact_email,
    t.contact_phone,
    t.whatsapp,
    t.instagram,
    t.facebook
  from public.tenants t
  where t.id = current_tenant_id
    and t.active = true
  limit 1;
end;
$$;

revoke execute on function public.get_business_settings() from anon;
revoke execute on function public.get_business_settings() from public;

grant execute on function public.get_business_settings() to authenticated;
