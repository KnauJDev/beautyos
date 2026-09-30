-- Extrae el texto VIVO de lo que calcula y valida el cobro de una sede. Hallazgo BY.
--
-- POR QUE. El 30-sep, al activar la sede "Barberia Barber Elite", ePayco
-- rechazo el cobro: la sede cuesta $10.000 al mes, faltaban 9 dias para el corte
-- del negocio y el alta prorrateada dio $3.000. ePayco solo acepta entre $5.000
-- y $5.000.000 ("[VALIDATION_ERROR] - property Amount must be between 5000 and
-- 5000000"). La sede no se puede activar.
--
-- El propietario decidio (30-sep): cuando el prorrateo de menos de $5.000, se
-- cobran $5.000.
--
-- Antes de tocar nada se leen, del texto vivo y no del repositorio (regla 10):
--   1. `beautyos_calcular_cargo_sede` (la privada y su envoltorio publico): es
--      la que calcula el prorrateo y la que hay que cambiar.
--   2. `beautyos_procesar_pago_de_sede` (las dos, si existen): segun el
--      repositorio, para un alta prorrateada exige como minimo lo mismo que
--      calcula la anterior. Hay que confirmar que en la base viva sigue igual,
--      o un pago de $5.000 podria quedar cobrado y sin activar la sede.
--   3. `beautyos_cobro_minimo_cop` (D-265), para seguir su mismo patron.
--
-- NO MODIFICA NADA.
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\extraer_cargo_de_sede_by.sql"
--
-- Deja `_vivo_by_cargo_de_sede.sql` en la raiz. No se sube (.gitignore).

\encoding UTF8
\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_by_cargo_de_sede.sql
select '-- ===== FUNCION ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind = 'f'
  and n.nspname in ('public', 'private')
  and p.proname in (
    'beautyos_calcular_cargo_sede',
    'beautyos_procesar_pago_de_sede',
    'beautyos_cobro_minimo_cop'
  )
order by n.nspname, p.proname;

-- Los permisos de cada una: un CREATE OR REPLACE los conserva, pero conviene
-- verlos antes de escribir la migracion.
select '-- ===== PERMISOS ' || routine_schema || '.' || routine_name || ' -> '
       || string_agg(grantee || ':' || privilege_type, ', ' order by grantee)
from information_schema.routine_privileges
where routine_schema in ('public', 'private')
  and routine_name in (
    'beautyos_calcular_cargo_sede',
    'beautyos_procesar_pago_de_sede',
    'beautyos_cobro_minimo_cop'
  )
group by routine_schema, routine_name
order by routine_schema, routine_name;
\o

\echo 'Listo: _vivo_by_cargo_de_sede.sql'
