-- Extrae el texto VIVO de lo que decide qué temas puede elegir un salón.
-- Paso 3 del plan de David (D-308): el tema "Inspirant" (barra dorada,
-- títulos negros, fondos con el rosa de las flores del local), para todos
-- los salones. NO MODIFICA NADA.
--
-- POR QUÉ. La lista de temas permitidos está escrita en DOS sitios de la base
-- (migración del 07-ago, D-093b): la restricción `tenants_theme_key_valido` y
-- el cuerpo de `update_tenant_theme`. Para agregar 'inspirant' hay que
-- reescribir la función, así que se lee primero lo vivo (regla 10):
--   1. La definición viva de la restricción (y la del color personalizado).
--   2. El texto vivo de `update_tenant_theme`, y sus permisos.
--   3. Los NOMBRES de las demás funciones que nombran un tema (por si la
--      lista está en un tercer sitio).
--   4. Cuántos negocios hay en cada tema (sin nombres).
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\extraer_tema_inspirant_paso3.sql"
--
-- Deja `_vivo_paso3_tema.sql` en la raiz. No se sube (.gitignore).

\encoding UTF8
\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_paso3_tema.sql

select '-- ===== 1. RESTRICCIONES DE tenants SOBRE EL TEMA';
select '-- ' || con.conname || ' | ' || pg_get_constraintdef(con.oid)
from pg_constraint con
join pg_class rel on rel.oid = con.conrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public'
  and rel.relname = 'tenants'
  and (con.conname ilike '%theme%' or con.conname ilike '%brand_color%')
order by con.conname;

select '-- ===== 2. LA FUNCION';
select '-- ===== FUNCION ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind = 'f'
  and n.nspname = 'public'
  and p.proname = 'update_tenant_theme';

select '-- ===== PERMISOS ' || routine_schema || '.' || routine_name || ' -> '
       || string_agg(grantee || ':' || privilege_type, ', ' order by grantee)
from information_schema.routine_privileges
where routine_schema = 'public' and routine_name = 'update_tenant_theme'
group by routine_schema, routine_name;

select '-- ===== 3. OTRAS FUNCIONES QUE NOMBRAN UN TEMA (solo el nombre)';
select '-- ' || n.nspname || '.' || p.proname
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public', 'private')
  and p.prokind = 'f'
  and p.prosrc ilike '%spa_unas%'
group by n.nspname, p.proname
order by n.nspname, p.proname;

select '-- ===== 4. NEGOCIOS POR TEMA (sin nombres)';
select '-- ' || t.theme_key || ' | ' || count(*)
from public.tenants t
group by t.theme_key
order by t.theme_key;

\o

\echo 'Listo: _vivo_paso3_tema.sql'
