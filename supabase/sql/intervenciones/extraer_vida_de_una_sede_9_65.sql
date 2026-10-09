-- Extrae el texto VIVO de lo que decide la vida de una SEDE, antes de diseñar
-- cómo se cierra una sin borrar nada (paso 9.65, D-328, hallazgo CQ).
-- NO MODIFICA NADA.
--
-- POR QUÉ. El 09-oct el propietario quiso cerrar una sede en mora de Prueba
-- Barbería Elite y, como el Panel no tiene botón para eso, usó "Borrar negocio
-- de prueba": se borró el negocio entero. Decidió: una sede que se cierra NO
-- se borra; conserva sus clientas, su historial y sus pagos, y se puede volver
-- a abrir. Antes de proponer cómo, se lee lo vivo (regla 10):
--   1. Las columnas de `branches` y `branch_subscriptions`.
--   2. Sus restricciones y disparadores.
--   3. Las funciones que deciden si una sede se puede usar: el acceso del
--      equipo, la que dice si la sede acepta citas nuevas, el contexto de la
--      app, la reserva en línea, la página pública, el Panel y el alta.
--   4. Qué otras funciones miran la suscripción de la sede (solo nombres).
--   5. Cuántas sedes hay en cada estado (solo números).
--   6. El rastro del borrado de Prueba Barbería Elite (sin correos).
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\extraer_vida_de_una_sede_9_65.sql"
--
-- Deja `_vivo_vida_de_una_sede.sql` en la raiz. No se sube (.gitignore).

\encoding UTF8
\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_vida_de_una_sede.sql

select '-- ===== 1. COLUMNAS';
select '-- ' || c.table_name || '.' || c.column_name || ' | ' || c.data_type
       || ' | nulo=' || c.is_nullable || ' | defecto=' || coalesce(c.column_default, '-')
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name in ('branches', 'branch_subscriptions')
order by c.table_name, c.ordinal_position;

select '-- ===== 2. RESTRICCIONES Y DISPARADORES';
select '-- RESTRICCION ' || rel.relname || ' | ' || con.conname || ' | ' || pg_get_constraintdef(con.oid)
from pg_constraint con
join pg_class rel on rel.oid = con.conrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public'
  and rel.relname in ('branches', 'branch_subscriptions')
order by rel.relname, con.conname;

select '-- DISPARADOR ' || rel.relname || ' | ' || pg_get_triggerdef(tg.oid)
from pg_trigger tg
join pg_class rel on rel.oid = tg.tgrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public'
  and rel.relname in ('branches', 'branch_subscriptions')
  and not tg.tgisinternal
order by rel.relname, tg.tgname;

select '-- ===== 3. LAS FUNCIONES QUE DECIDEN SI UNA SEDE SE USA';
select '-- ===== FUNCION ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind = 'f'
  and (
    (n.nspname = 'private' and p.proname in (
      'beautyos_branch_accepts_new_commitments',
      'beautyos_resolve_branch_access',
      'beautyos_resolve_branch'
    ))
    or (n.nspname = 'public' and p.proname in (
      'get_my_branch_context_v2',
      'get_branch_subscriptions',
      'platform_set_branch_subscription',
      'platform_get_tenant_branches',
      'public_get_branch_booking_info',
      'get_public_salon_by_slug',
      'get_my_tenant_subscription_status',
      'create_branch'
    ))
  )
order by n.nspname, p.proname;

select '-- ===== 4. QUIÉN MÁS MIRA LA SUSCRIPCIÓN O EL CANDADO DE UNA SEDE (solo nombres)';
select '-- ' || n.nspname || '.' || p.proname || '('
       || pg_get_function_identity_arguments(p.oid) || ')'
       || case when p.prosrc ilike '%beautyos_branch_accepts_new_commitments%'
               then ' | usa el candado de citas nuevas' else '' end
       || case when p.prosrc ilike '%branch_subscriptions%'
               then ' | lee branch_subscriptions' else '' end
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind = 'f'
  and n.nspname in ('public', 'private')
  and (p.prosrc ilike '%beautyos_branch_accepts_new_commitments%'
       or p.prosrc ilike '%branch_subscriptions%')
order by n.nspname, p.proname;

select '-- ===== 5. CUÁNTAS SEDES (solo números)';
select '-- sedes activas=' || b.active || ' principal=' || b.is_primary || ': ' || count(*)
from public.branches b
group by b.active, b.is_primary
order by b.active desc, b.is_primary desc;

select '-- suscripciones de sede en estado ' || bs.status || ': ' || count(*)
from public.branch_subscriptions bs
group by bs.status
order by bs.status;

select '-- negocios con mas de una sede: ' || count(*)
from (
  select b.tenant_id from public.branches b group by b.tenant_id having count(*) > 1
) x;

select '-- ===== 6. EL RASTRO DE LOS BORRADOS (sin correos)';
select '-- ' || d.tenant_name || ' | ' || d.deleted_at || ' | pagos=' || d.pagos_registrados
       || ' | dinero=' || d.dinero_cop || ' | filas=' || d.filas_por_tabla::text
from public.deleted_demo_tenants d
order by d.deleted_at desc
limit 3;

\o

\echo 'Listo: _vivo_vida_de_una_sede.sql'
