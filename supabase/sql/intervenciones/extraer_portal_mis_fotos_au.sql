-- Extrae el texto VIVO de lo que el arreglo de AU (paso 9.48) va a tocar.
--
-- POR QUE. El propietario decidió el 27-sep que en "Mis fotos de trabajos"
-- la clienta vea TODA foto que el salón le marque como visible, esté o no en
-- el portafolio, con una marca que distinga las publicadas. Hoy
-- `get_client_portal_data` exige `photo_url is not null`, así que solo
-- entrega las publicadas (D-167, 29-ago). Hay que reescribirla, y la regla
-- 10 manda leer su texto vivo antes: la primera migración del 9.48 falló
-- justo por reescribir desde el repositorio (D-281).
--
-- También trae `client_consent_get_photo_path` (la que autoriza firmar una
-- foto privada suya, D-281) y `beautyos_resolve_consent_client`, para
-- confirmar que viven como en el repositorio antes de apoyarse en ellas, y
-- cualquier función privada del portal que `get_client_portal_data` use.
--
-- NO MODIFICA NADA.
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\extraer_portal_mis_fotos_au.sql"
--
-- Deja `_vivo_portal_au.sql` en la raiz. No se sube (.gitignore).

\encoding UTF8
\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_portal_au.sql

-- 1. Las funciones, tal como viven.
select '-- ===== FUNCION ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind = 'f'
  and (
    (n.nspname = 'public' and p.proname in (
      'get_client_portal_data',
      'client_consent_get_photo_path'
    ))
    or (n.nspname = 'private' and (
      p.proname = 'beautyos_resolve_consent_client'
      or p.proname ilike '%portal%'
    ))
  )
order by n.nspname, p.proname;

-- 2. Quién puede ejecutarlas (anon tiene que poder: la clienta no tiene
--    sesión de Supabase Auth).
select '-- permiso ' || routine_schema || '.' || routine_name || ' -> ' || grantee
from information_schema.routine_privileges
where (routine_schema = 'public'
       and routine_name in ('get_client_portal_data', 'client_consent_get_photo_path'))
   or (routine_schema = 'private'
       and (routine_name = 'beautyos_resolve_consent_client' or routine_name ilike '%portal%'))
order by routine_schema, routine_name, grantee;

\o
