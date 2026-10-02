-- Extrae los permisos VIVOS de las funciones que usan las paginas publicas.
-- Hallazgo CE.
--
-- POR QUE. El 02-oct el propietario abrio la pagina publica de un salon en su
-- celular, con su sesion de Salon y Mas abierta, y al ir a reservar le salio
-- "permission denied for function public_get_branch_booking_info". En una
-- ventana de incognito, sin sesion, si funcionaba. Segun el repositorio, las
-- seis funciones de la pagina publica se conceden solo a `anon` y se le quitan
-- a `authenticated`: con una sesion abierta, la llamada viaja como
-- `authenticated` y se niega.
--
-- Antes de escribir la migracion se lee, de la base viva y no del repositorio
-- (regla 10):
--   1. TODAS las funciones de `public` que `anon` puede ejecutar, con su firma
--      exacta y si `authenticated` tambien puede. Asi salen tambien las del
--      portal de la clienta o del enlace de autorizacion, si tuvieran lo mismo.
--   2. El texto de las que `anon` puede y `authenticated` no, para ver si
--      alguna se comporta distinto con una sesion (auth.uid, auth.role).
--
-- NO MODIFICA NADA.
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\extraer_permisos_de_la_pagina_publica_ce.sql"
--
-- Deja `_vivo_ce_permisos.sql` en la raiz. No se sube (.gitignore).

\encoding UTF8
\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_ce_permisos.sql

-- 1. Lo que anon puede ejecutar en public, y si authenticated tambien.
select '-- ===== QUE PUEDE anon EN public';
select '-- ' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')'
       || ' | anon=' || has_function_privilege('anon', p.oid, 'EXECUTE')
       || ' | authenticated=' || has_function_privilege('authenticated', p.oid, 'EXECUTE')
       || ' | security_definer=' || p.prosecdef
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prokind = 'f'
  and has_function_privilege('anon', p.oid, 'EXECUTE')
order by p.proname;

-- 2. El texto de las que anon puede y authenticated no.
select '-- ===== FUNCION ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prokind = 'f'
  and has_function_privilege('anon', p.oid, 'EXECUTE')
  and not has_function_privilege('authenticated', p.oid, 'EXECUTE')
order by p.proname;

\o

\echo 'Listo: _vivo_ce_permisos.sql'
