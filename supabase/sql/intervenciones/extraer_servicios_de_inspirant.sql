-- Extrae el texto VIVO del catálogo de servicios de Inspirant (David) antes de
-- ordenarlo por categorías. NO MODIFICA NADA.
--
-- POR QUÉ. El 09-oct el propietario pidió ordenar los 28 servicios de David en
-- 8 categorías (Cortes, Barbería, Color, Tratamientos capilares, Cepillados y
-- peinados, Maquillaje, Rostro y cejas, Extensiones) y corregir la ortografía
-- de los nombres; David ya lo aprobó. Ni precios ni duraciones. Antes de
-- escribir el cambio se lee lo vivo (regla 10):
--   1. Cada servicio del salón, con su id, nombre y categoría exactos (también
--      los ocultos o inactivos, que la página pública no muestra).
--   2. Las restricciones de `services` (por si un nombre no puede repetirse).
--   3. Los disparadores de `services` (por si un cambio deja rastro aparte).
--   4. `update_service`, la función con que el salón edita un servicio, para
--      no saltarse nada de lo que ella hace.
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\extraer_servicios_de_inspirant.sql"
--
-- Deja `_vivo_servicios_inspirant.sql` en la raiz. No se sube (.gitignore).

\encoding UTF8
\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_servicios_inspirant.sql

select '-- ===== 1. LOS SERVICIOS DE INSPIRANT';
select '-- ' || s.id || ' | ' || s.name || ' | categoria=' || coalesce(s.category, '(vacia)')
       || ' | ' || s.duration_minutes || ' min | ' || s.price
       || ' | activo=' || s.active || ' | visible=' || s.visible_to_customer
from public.services s
join public.tenants t on t.id = s.tenant_id
where t.slug = 'inspirant-salon'
order by s.category, s.name;

select '-- total: ' || count(*)
from public.services s
join public.tenants t on t.id = s.tenant_id
where t.slug = 'inspirant-salon';

select '-- ===== 2. RESTRICCIONES DE services';
select '-- ' || con.conname || ' | ' || pg_get_constraintdef(con.oid)
from pg_constraint con
join pg_class rel on rel.oid = con.conrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public' and rel.relname = 'services'
order by con.conname;

select '-- INDICE ' || indexname || ' | ' || indexdef
from pg_indexes
where schemaname = 'public' and tablename = 'services'
order by indexname;

select '-- ===== 3. DISPARADORES DE services';
select '-- ' || tg.tgname || ' | ' || pg_get_triggerdef(tg.oid)
from pg_trigger tg
join pg_class rel on rel.oid = tg.tgrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public' and rel.relname = 'services' and not tg.tgisinternal
order by tg.tgname;

select '-- ===== 4. update_service';
select '-- ===== FUNCION ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind = 'f'
  and n.nspname = 'public'
  and p.proname = 'update_service'
order by p.oid;

\o

\echo 'Listo: _vivo_servicios_inspirant.sql'
