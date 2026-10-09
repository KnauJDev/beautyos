-- Extrae el texto VIVO de los estilistas de Inspirant (David) y de cómo se
-- guarda qué servicios hace cada uno, antes de asignárselos. NO MODIFICA NADA.
--
-- POR QUÉ. El 09-oct el propietario pidió asignar a los 4 estilistas de David
-- todos sus servicios, menos "Corte personalizado y asesoría", que va solo a
-- David (D-325). David ya lo aprobó. De sus 28 servicios solo 3 tenían
-- estilista, y la reserva en línea solo ofrece lo que alguien hace (D-322).
-- Antes de escribir el cambio se lee lo vivo (regla 10):
--   1. Sus sedes y sus estilistas, y en qué sede está activo cada uno.
--   2. Las columnas, restricciones y disparadores de las tablas de la
--      asignación (`stylist_services`, `branch_stylist_services`) y de las
--      que la acompañan (`branch_stylists`, `branch_services`).
--   3. Lo que tiene asignado hoy cada estilista (catálogo y sede).
--   4. `set_stylist_services` (la función de la pantalla Estilistas) y
--      `public_get_bookable_services` (la reserva en línea), para escribir
--      lo mismo que escribe la pantalla y comprobar que la reserva lo verá.
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\extraer_estilistas_de_inspirant.sql"
--
-- Deja `_vivo_estilistas_inspirant.sql` en la raiz. No se sube (.gitignore).

\encoding UTF8
\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_estilistas_inspirant.sql

select '-- ===== 1. SEDES';
select '-- ' || b.id || ' | ' || b.name || ' | principal=' || b.is_primary || ' | activa=' || b.active
from public.branches b
join public.tenants t on t.id = b.tenant_id
where t.slug = 'inspirant-salon'
order by b.is_primary desc, b.name;

select '-- ===== 1b. ESTILISTAS';
select '-- ' || st.id || ' | ' || st.name || ' | activo=' || st.active
from public.stylists st
join public.tenants t on t.id = st.tenant_id
where t.slug = 'inspirant-salon'
order by st.name;

select '-- ===== 1c. ESTILISTAS EN CADA SEDE (branch_stylists)';
select '-- ' || to_jsonb(bs)::text
from public.branch_stylists bs
join public.tenants t on t.id = bs.tenant_id
where t.slug = 'inspirant-salon';

select '-- ===== 2. COLUMNAS';
select '-- ' || c.table_name || '.' || c.column_name || ' | ' || c.data_type
       || ' | nulo=' || c.is_nullable || ' | defecto=' || coalesce(c.column_default, '-')
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name in ('stylist_services', 'branch_stylist_services',
                       'branch_stylists', 'branch_services')
order by c.table_name, c.ordinal_position;

select '-- RESTRICCION ' || rel.relname || ' | ' || con.conname || ' | ' || pg_get_constraintdef(con.oid)
from pg_constraint con
join pg_class rel on rel.oid = con.conrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public'
  and rel.relname in ('stylist_services', 'branch_stylist_services')
order by rel.relname, con.conname;

select '-- INDICE ' || tablename || ' | ' || indexdef
from pg_indexes
where schemaname = 'public'
  and tablename in ('stylist_services', 'branch_stylist_services')
order by tablename, indexname;

select '-- DISPARADOR ' || rel.relname || ' | ' || pg_get_triggerdef(tg.oid)
from pg_trigger tg
join pg_class rel on rel.oid = tg.tgrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public'
  and rel.relname in ('stylist_services', 'branch_stylist_services')
  and not tg.tgisinternal
order by rel.relname, tg.tgname;

select '-- ===== 3. LO QUE TIENEN HOY (stylist_services)';
select '-- ' || st.name || ' | ' || s.name || ' | ' || to_jsonb(ss)::text
from public.stylist_services ss
join public.stylists st on st.id = ss.stylist_id
join public.services s on s.id = ss.service_id
join public.tenants t on t.id = st.tenant_id
where t.slug = 'inspirant-salon'
order by st.name, s.name;

select '-- ===== 3b. LO QUE TIENEN HOY EN LA SEDE (branch_stylist_services)';
-- (09-oct: la primera corrida se detuvo aquí. Esta tabla no tiene
-- stylist_id ni service_id: apunta a branch_stylists y branch_services.)
select '-- ' || st.name || ' | ' || s.name || ' | ' || to_jsonb(bss)::text
from public.branch_stylist_services bss
join public.branch_stylists bst on bst.id = bss.branch_stylist_id
join public.branch_services bsv on bsv.id = bss.branch_service_id
join public.stylists st on st.id = bst.stylist_id
join public.services s on s.id = bsv.service_id
join public.tenants t on t.id = bss.tenant_id
where t.slug = 'inspirant-salon'
order by st.name, s.name;

select '-- ===== 3c. LOS SERVICIOS EN LA SEDE (branch_services)';
select '-- ' || s.name || ' | activo=' || bsv.active || ' | visible=' || bsv.visible_to_customer
from public.branch_services bsv
join public.services s on s.id = bsv.service_id
join public.tenants t on t.id = bsv.tenant_id
where t.slug = 'inspirant-salon'
order by s.name;

select '-- ===== 4. FUNCIONES';
select '-- ===== FUNCION ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind = 'f'
  and n.nspname = 'public'
  and p.proname in ('set_stylist_services', 'public_get_bookable_services')
order by p.proname;

\o

\echo 'Listo: _vivo_estilistas_inspirant.sql'
