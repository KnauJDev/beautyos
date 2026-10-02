-- Extrae el texto VIVO de como se decide que modulos ve cada negocio.
-- Paso 1 del plan del primer cliente real (D-308). NO MODIFICA NADA.
--
-- POR QUE. David Rojas quiere solo agenda: el propietario decidio apagarle
-- caja y cobros, finanzas, inventario y compras, comisiones, fotos, resenas y
-- blog, y que lo apagado DESAPAREZCA de su app (hoy sale con candado, D-184).
-- Hacen falta capacidades nuevas (caja, comisiones, blog) y que cada negocio
-- pueda tenerlas apagadas desde el Panel. Antes de escribir la migracion se
-- lee lo vivo (regla 10):
--   1. Las capacidades que existen (`features`).
--   2. Los planes y que capacidades trae cada uno (`plan_features`).
--      Una capacidad nueva SIN fila en un plan podria quedar negada a todos:
--      hay que saber como se resuelve antes de anadirla.
--   3. Las funciones que deciden: la que resuelve una capacidad, la que la
--      lee la app (`get_my_entitlements`), la que la exige en el servidor, y
--      las del Panel que ponen, leen y quitan excepciones.
--   4. Cuantas excepciones hay hoy y de que capacidad (sin nombres de nadie).
--   5. Las restricciones de las tres tablas.
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\extraer_capacidades_por_negocio_paso1.sql"
--
-- Deja `_vivo_paso1_capacidades.sql` en la raiz. No se sube (.gitignore).

\encoding UTF8
\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_paso1_capacidades.sql

select '-- ===== 1. CAPACIDADES';
select '-- ' || f.key || ' | ' || f.name || ' | ' || coalesce(f.description, '')
from public.features f
order by f.key;

select '-- ===== 2. PLANES Y LO QUE TRAE CADA UNO';
select '-- plan ' || p.code || ' | ' || p.name || ' | estado ' || coalesce(p.status::text, '?')
from public.plans p
order by p.code;
select '-- ' || p.code || ' -> ' || f.key || ' | enabled=' || pf.enabled
       || ' | limite=' || coalesce(pf.limit_value::text, 'sin limite')
from public.plan_features pf
join public.plans p on p.id = pf.plan_id
join public.features f on f.id = pf.feature_id
order by p.code, f.key;

select '-- ===== 3. LAS FUNCIONES QUE DECIDEN';
select '-- ===== FUNCION ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind = 'f'
  and n.nspname in ('public', 'private')
  and p.proname in (
    'beautyos_resolve_entitlement',
    'get_my_entitlements',
    'beautyos_require_entitlement',
    'platform_set_tenant_feature_override',
    'platform_get_tenant_feature_overrides',
    'platform_delete_tenant_feature_override'
  )
order by n.nspname, p.proname;

select '-- ===== PERMISOS ' || routine_schema || '.' || routine_name || ' -> '
       || string_agg(grantee || ':' || privilege_type, ', ' order by grantee)
from information_schema.routine_privileges
where routine_schema in ('public', 'private')
  and routine_name in (
    'beautyos_resolve_entitlement',
    'get_my_entitlements',
    'beautyos_require_entitlement',
    'platform_set_tenant_feature_override',
    'platform_get_tenant_feature_overrides',
    'platform_delete_tenant_feature_override'
  )
group by routine_schema, routine_name
order by routine_schema, routine_name;

select '-- ===== 4. EXCEPCIONES QUE HAY HOY (sin nombres)';
select '-- ' || f.key || ' | enabled=' || o.enabled || ' | vigentes='
       || count(*) filter (where o.starts_at <= now() and (o.ends_at is null or o.ends_at > now()))
       || ' | total=' || count(*)
from public.tenant_feature_overrides o
join public.features f on f.id = o.feature_id
group by f.key, o.enabled
order by f.key, o.enabled;

select '-- ===== 5. RESTRICCIONES';
select '-- ' || rel.relname || ' | ' || con.conname || ' | ' || pg_get_constraintdef(con.oid)
from pg_constraint con
join pg_class rel on rel.oid = con.conrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public'
  and rel.relname in ('features', 'plan_features', 'tenant_feature_overrides')
order by rel.relname, con.conname;

\o

\echo 'Listo: _vivo_paso1_capacidades.sql'
