-- ============================================================
-- 040_restrict_authenticated_table_privileges.sql
-- BeautyOS AI
-- Propósito:
-- Restringir permisos directos del rol authenticated sobre tablas
-- públicas de BeautyOS.
--
-- Motivo:
-- La mayoría de datos internos se consultan mediante RPC seguras
-- con security definer, tenant del usuario y validación de rol.
--
-- Regla:
-- - authenticated no debe tener permisos amplios directos sobre tablas.
-- - Flutter actualmente solo lee directamente public.services.
-- - user_profiles conserva permisos mínimos para perfil propio.
-- - RLS sigue siendo el portero de seguridad.
-- ============================================================

revoke all privileges on all tables in schema public from authenticated;

-- Flutter lee directamente la tabla services en:
-- lib/services/services_service.dart
-- La política RLS de services ya filtra por:
-- tenant_id = public.get_my_tenant_id()
-- active = true
-- visible_to_customer = true
grant select on public.services to authenticated;

-- Permiso mínimo para perfil propio.
-- La tabla user_profiles tiene RLS:
-- - leer solo perfil propio activo
-- - actualizar solo nombre propio
grant select on public.user_profiles to authenticated;
grant update (full_name, updated_at) on public.user_profiles to authenticated;

-- Verificación recomendada después de ejecutar:
-- select
--   table_schema,
--   table_name,
--   privilege_type
-- from information_schema.table_privileges
-- where table_schema = 'public'
--   and grantee = 'authenticated'
-- order by table_name, privilege_type;
