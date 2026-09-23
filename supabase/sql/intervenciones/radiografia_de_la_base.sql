-- Radiografia de la base viva: esquema, seguridad y costo. Revision integral 23-sep.
--
-- POR QUE. El repositorio no describe la base entera (hallazgo AI): las
-- migraciones crean 25 tablas y faltan las grandes. Asi que la foto de la
-- seguridad y del tamano se le pide al catalogo, no al repositorio.
--
-- Escrito con las trampas de esta semana a la vista: `prokind = 'f'` antes de
-- `pg_get_functiondef` (revienta con agregados), ningun nombre de tabla
-- supuesto (solo catalogo estandar de PostgreSQL y de Supabase), y todo el
-- texto sale por `select` dentro del `\o`, porque `\echo` va a la consola.
--
-- NO MODIFICA NADA.

\pset format unaligned
\pset tuples_only on
\o C:/Proyectos/salonymas/_radiografia.txt

select '=== 1. TABLAS POR ESQUEMA ===';
select n.nspname || ': ' || count(*)
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where c.relkind = 'r' and n.nspname in ('public','private','storage','auth')
group by n.nspname order by 1;

select '';
select '=== 2. TABLAS DE public SIN RLS (deberian ser cero) ===';
select c.relname
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where c.relkind = 'r' and n.nspname = 'public' and not c.relrowsecurity
order by 1;

select '';
select '=== 3. TABLAS DE public CON RLS Y CERO POLITICAS (solo por RPC: correcto por diseno) ===';
select c.relname
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where c.relkind = 'r' and n.nspname = 'public' and c.relrowsecurity
  and not exists (select 1 from pg_policy p where p.polrelid = c.oid)
order by 1;

select '';
select '=== 4. TODAS LAS TABLAS DE public (para cruzar con las migraciones) ===';
select c.relname
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where c.relkind = 'r' and n.nspname = 'public' order by 1;

select '';
select '=== 5. FUNCIONES POR ESQUEMA ===';
select n.nspname || ': ' || count(*)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public','private') and p.prokind = 'f'
group by n.nspname order by 1;

select '';
select '=== 6. SECURITY DEFINER SIN search_path FIJO (D-087 dijo cero) ===';
select n.nspname || '.' || p.proname
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public','private') and p.prokind = 'f' and p.prosecdef
  and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) cfg where cfg like 'search_path=%')
order by 1;

select '';
select '=== 7. FUNCIONES QUE PUEDE EJECUTAR anon (la superficie publica, sin cuenta) ===';
select n.nspname || '.' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')'
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public','private') and p.prokind = 'f'
  and has_function_privilege('anon', p.oid, 'execute')
order by 1;

select '';
select '=== 8. VERSIONES DUPLICADAS DEL MISMO NOMBRE (como las 3 del cobro, D-252) ===';
select n.nspname || '.' || p.proname || ' x' || count(*)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public','private') and p.prokind = 'f'
group by n.nspname, p.proname having count(*) > 1 order by 1;

select '';
select '=== 9. ALMACENES DE ARCHIVOS ===';
select id || ' | publico=' || public from storage.buckets order by id;

select '';
select '=== 10. EXTENSIONES ===';
select extname || ' ' || extversion from pg_extension order by 1;

select '';
select '=== 11. NEGOCIOS: cuales son de prueba ===';
select name || ' | is_demo=' || is_demo || ' | activo=' || active from public.tenants order by name;

select '';
select '=== 12. TAMANO (plan Free: base 500 MB) ===';
select 'base de datos: ' || pg_size_pretty(pg_database_size(current_database()));
select 'archivos en storage: ' || count(*) || ' objetos, '
       || pg_size_pretty(coalesce(sum((metadata->>'size')::bigint), 0))
from storage.objects;

select '';
select '=== 13. LAS 10 TABLAS MAS GRANDES ===';
select c.relname || ' | ' || pg_size_pretty(pg_total_relation_size(c.oid))
       || ' | ~' || c.reltuples::bigint || ' filas'
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where c.relkind = 'r' and n.nspname = 'public'
order by pg_total_relation_size(c.oid) desc limit 10;

\o
\pset tuples_only off
\pset format aligned
