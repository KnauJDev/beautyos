-- Extrae el texto VIVO de todo lo que toca el hallazgo AJ.
--
-- POR QUE. La regla del proyecto dice que al reescribir una funcion hay que
-- sacar primero su texto actual y comparar linea por linea (D-119, D-122,
-- D-123). Y aqui pesa el doble: `commission_policies` **no existe en ninguna
-- migracion** -- nacio en `supabase/sql/015`, de julio --, asi que lo unico
-- que sabe como es de verdad es la base (hallazgo AI).
--
-- NO MODIFICA NADA. Solo lee el catalogo y escribe archivos en el disco.

\pset format unaligned
\pset tuples_only on

-- 1. Las columnas de commission_policies, con sus defaults.
\o C:/Proyectos/salonymas/_vivo_tabla_comisiones.txt
select c.column_name || ' | ' || c.data_type
       || ' | null=' || c.is_nullable
       || ' | default=' || coalesce(c.column_default, '(ninguno)')
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name = 'commission_policies'
order by c.ordinal_position;

\echo '--- restricciones ---'
select con.conname || ' | ' || pg_get_constraintdef(con.oid)
from pg_constraint con
join pg_class rel on rel.oid = con.conrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public' and rel.relname = 'commission_policies'
order by con.conname;

\echo '--- indices ---'
select indexdef from pg_indexes
where schemaname = 'public' and tablename = 'commission_policies'
order by indexname;

\echo '--- politicas RLS ---'
select polname from pg_policy pol
join pg_class rel on rel.oid = pol.polrelid
where rel.relname = 'commission_policies';

\echo '--- cuantas filas y cuantas siguen en el 40 por defecto ---'
select 'filas=' || count(*)
       || ' | en_40_porcentaje=' || count(*) filter (
            where commission_type = 'percentage' and commission_percentage = 40)
       || ' | tocadas_despues_de_nacer=' || count(*) filter (
            where updated_at > created_at + interval '1 second')
from public.commission_policies;
\o

-- 2. Las tres funciones que se reescriben.
\o C:/Proyectos/salonymas/_vivo_get_commission_policy.sql
select pg_get_functiondef('public.get_commission_policy()'::regprocedure);
\o

\o C:/Proyectos/salonymas/_vivo_update_commission_policy.sql
select pg_get_functiondef(
  'public.update_commission_policy(uuid, text, numeric, numeric, boolean, text)'::regprocedure
);
\o

\o C:/Proyectos/salonymas/_vivo_get_onboarding_progress.sql
select pg_get_functiondef('public.get_onboarding_progress(uuid)'::regprocedure);
\o

\pset tuples_only off
\pset format aligned

\echo ''
\echo 'Listo. Quedaron cuatro archivos _vivo_*.txt / _vivo_*.sql en la carpeta del proyecto.'
