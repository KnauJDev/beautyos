-- Tercera lectura del paso 9.65 (cerrar una sede sin borrar nada, D-328).
-- NO MODIFICA NADA.
--
-- POR QUÉ. El reporte de todo el negocio (`get_tenant_reports_v3`) recorre
-- las sedes de `get_my_branch_context_v2` (que solo lista las abiertas) y
-- pide el reporte de cada una a `get_branch_reports_v3`. Para que lo hecho en
-- una sede cerrada siga saliendo (decisión del propietario, D-328) hay que
-- saber si esa función rechaza una sede cerrada. Se lee su texto vivo
-- (regla 10), con sus permisos.
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\extraer_reporte_de_sede_9_65.sql"
--
-- Deja `_vivo_reporte_de_sede.sql` en la raiz. No se sube (.gitignore).

\encoding UTF8
\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_reporte_de_sede.sql

select '-- ===== FUNCION ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind = 'f'
  and n.nspname = 'public'
  and p.proname = 'get_branch_reports_v3'
order by p.oid;

select '-- PERMISOS ' || routine_schema || '.' || routine_name || ' -> '
       || string_agg(grantee || ':' || privilege_type, ', ' order by grantee)
from information_schema.routine_privileges
where routine_schema = 'public'
  and routine_name in ('get_branch_reports_v3', 'get_tenant_reports_v3')
group by routine_schema, routine_name;

\o

\echo 'Listo: _vivo_reporte_de_sede.sql'
