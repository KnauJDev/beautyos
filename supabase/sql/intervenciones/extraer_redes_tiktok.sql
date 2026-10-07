-- Extrae el texto VIVO de todo lo que guarda y enseña las redes sociales de
-- un salón (Instagram y Facebook), para agregar TikTok. Lo pidió David, el
-- primer cliente real (D-308); el propietario lo pidió el 07-oct.
-- NO MODIFICA NADA.
--
-- POR QUÉ. Agregar TikTok es una columna nueva y reescribir las funciones que
-- guardan y devuelven las redes. Antes de reescribir una función se lee la
-- viva (regla 10):
--   1. Las columnas de `tenants` y `branches` que parecen redes o contacto.
--   2. Las restricciones de esas tablas que nombran una red.
--   3. El texto vivo de TODA función de `public` o `private` que nombra
--      `instagram`, con sus permisos.
--   4. Las vistas que nombran `instagram` (solo el nombre).
--   5. Cuántos salones hay (sin nombres): cuántas filas toca la columna nueva.
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\extraer_redes_tiktok.sql"
--
-- Deja `_vivo_redes_tiktok.sql` en la raiz. No se sube (.gitignore).

\encoding UTF8
\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_redes_tiktok.sql

select '-- ===== 1. COLUMNAS DE REDES Y CONTACTO';
select '-- ' || c.table_name || '.' || c.column_name || ' | ' || c.data_type
       || ' | nulo: ' || c.is_nullable
       || coalesce(' | por defecto: ' || c.column_default, '')
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name in ('tenants', 'branches')
  and (c.column_name ilike '%instagram%'
       or c.column_name ilike '%facebook%'
       or c.column_name ilike '%tiktok%'
       or c.column_name ilike '%whatsapp%'
       or c.column_name ilike '%social%'
       or c.column_name ilike '%web%'
       or c.column_name ilike '%phone%')
order by c.table_name, c.ordinal_position;

select '-- ===== 2. RESTRICCIONES QUE NOMBRAN UNA RED';
select '-- ' || rel.relname || '.' || con.conname || ' | ' || pg_get_constraintdef(con.oid)
from pg_constraint con
join pg_class rel on rel.oid = con.conrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public'
  and rel.relname in ('tenants', 'branches')
  and (pg_get_constraintdef(con.oid) ilike '%instagram%'
       or pg_get_constraintdef(con.oid) ilike '%facebook%')
order by rel.relname, con.conname;

select '-- ===== 3. FUNCIONES QUE NOMBRAN instagram (texto completo)';
select '-- ===== FUNCION ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind = 'f'
  and n.nspname in ('public', 'private')
  and p.prosrc ilike '%instagram%'
order by n.nspname, p.proname;

select '-- ===== PERMISOS ' || r.routine_schema || '.' || r.routine_name || ' -> '
       || string_agg(r.grantee || ':' || r.privilege_type, ', ' order by r.grantee)
from information_schema.routine_privileges r
where r.routine_schema in ('public', 'private')
  and r.routine_name in (
    select p.proname
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'private') and p.prosrc ilike '%instagram%'
  )
group by r.routine_schema, r.routine_name
order by r.routine_schema, r.routine_name;

select '-- ===== 4. VISTAS QUE NOMBRAN instagram (solo el nombre)';
select '-- ' || v.schemaname || '.' || v.viewname
from pg_views v
where v.schemaname in ('public', 'private')
  and v.definition ilike '%instagram%'
order by v.schemaname, v.viewname;

select '-- ===== 5. CUANTOS SALONES HAY (sin nombres)';
select '-- tenants: ' || count(*) || ' en total'
from public.tenants;

\o

\echo 'Listo: _vivo_redes_tiktok.sql'
