-- ============================================================
-- 039_revoke_anon_table_privileges.sql
-- BeautyOS AI
-- Propósito:
-- Quitar permisos directos del rol anon sobre las tablas públicas
-- de BeautyOS.
--
-- Motivo:
-- Aunque RLS ya bloquea anon porque no existen políticas para anon,
-- es más seguro retirar también los permisos directos de tabla.
--
-- Regla:
-- - anon no debe leer, insertar, actualizar ni borrar tablas internas.
-- - Flutter usa usuario authenticated después del login.
-- - Las lecturas internas se hacen por RPC seguras o RLS controlado.
-- ============================================================

revoke all privileges on all tables in schema public from anon;

-- Verificación recomendada después de ejecutar:
-- select
--   table_schema,
--   table_name,
--   privilege_type
-- from information_schema.table_privileges
-- where table_schema = 'public'
--   and grantee = 'anon'
-- order by table_name, privilege_type;
