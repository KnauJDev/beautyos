-- Segunda lectura del paso 9.65 (cerrar una sede sin borrar nada, D-328).
-- NO MODIFICA NADA.
--
-- POR QUÉ. El propietario decidió que lo hecho en una sede cerrada SIGA
-- saliendo en los reportes y el Dashboard. La primera lectura y el
-- repositorio muestran que la lista de sedes del Dashboard
-- (`private.beautyos_dashboard_branches`) solo toma las sedes con
-- `branches.active`: cerrar una sede la sacaría de ahí. Antes de cambiar nada
-- se lee lo vivo (regla 10):
--   1. `private.beautyos_dashboard_branches`, tal como está hoy.
--   2. Quién la usa (solo nombres).
--   3. Cómo eligen sus sedes los reportes de todo el negocio
--      (`get_tenant_reports_v3`) y el Dashboard de atenciones.
--   4. La tabla de eventos (`subscription_events`): columnas y reglas, para
--      dejar escrito cada cierre y cada reapertura.
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\extraer_reportes_de_una_sede_9_65.sql"
--
-- Deja `_vivo_reportes_de_una_sede.sql` en la raiz. No se sube (.gitignore).

\encoding UTF8
\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_reportes_de_una_sede.sql

select '-- ===== 1 y 3. FUNCIONES';
select '-- ===== FUNCION ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind = 'f'
  and (
    (n.nspname = 'private' and p.proname = 'beautyos_dashboard_branches')
    or (n.nspname = 'public' and p.proname in ('get_tenant_reports_v3', 'get_dashboard_atenciones'))
  )
order by n.nspname, p.proname;

select '-- ===== 2. QUIÉN USA beautyos_dashboard_branches (solo nombres)';
select '-- ' || n.nspname || '.' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')'
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind = 'f'
  and n.nspname in ('public', 'private')
  and p.prosrc ilike '%beautyos_dashboard_branches%'
order by n.nspname, p.proname;

select '-- PERMISOS ' || routine_schema || '.' || routine_name || ' -> '
       || string_agg(grantee || ':' || privilege_type, ', ' order by grantee)
from information_schema.routine_privileges
where routine_schema = 'private'
  and routine_name = 'beautyos_dashboard_branches'
group by routine_schema, routine_name;

select '-- ===== 4. LA TABLA DE EVENTOS';
select '-- ' || c.table_name || '.' || c.column_name || ' | ' || c.data_type
       || ' | nulo=' || c.is_nullable || ' | defecto=' || coalesce(c.column_default, '-')
from information_schema.columns c
where c.table_schema = 'public' and c.table_name = 'subscription_events'
order by c.ordinal_position;

select '-- RESTRICCION ' || con.conname || ' | ' || pg_get_constraintdef(con.oid)
from pg_constraint con
join pg_class rel on rel.oid = con.conrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public' and rel.relname = 'subscription_events'
order by con.conname;

select '-- tipos de evento que ya existen: ' || string_agg(distinct e.event_type, ', ')
from public.subscription_events e;

select '-- proveedores que ya existen: ' || string_agg(distinct e.provider, ', ')
from public.subscription_events e;

\o

\echo 'Listo: _vivo_reportes_de_una_sede.sql'
