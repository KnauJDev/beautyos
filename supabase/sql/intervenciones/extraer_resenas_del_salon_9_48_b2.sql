-- Extrae el texto VIVO de lo que el Bloque 2 del paso 9.48 va a reescribir.
--
-- POR QUE. La clienta podrá elegir con qué nombre aparece su reseña, y si
-- escribe uno propio la reseña vuelve a moderación (decisión del
-- propietario, 26-sep). El salón modera desde `get_reviews_summary_v2`, que
-- hoy muestra el nombre REAL: sin tocarla, el salón aprobaría un nombre que
-- no puede ver. Se lee antes de reescribirla (regla 10) -- la primera
-- migración del 9.48 falló precisamente por saltarse esta lectura.
--
-- También relee lo que se aplicó el 26-sep (Bloque 1) para confirmar que
-- vive tal como está en el repositorio antes de construir encima.
--
-- NO MODIFICA NADA.
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\extraer_resenas_del_salon_9_48_b2.sql"
--
-- Deja `_vivo_9_48_b2.sql` en la raiz. No se sube (.gitignore).

\encoding UTF8
\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_9_48_b2.sql

select '-- ===== FUNCION ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind = 'f'
  and n.nspname in ('public', 'private')
  and p.proname in (
    'get_reviews_summary_v2',
    'moderate_review',
    'get_public_salon_reviews',
    'get_publication_studio_data',
    'beautyos_resolve_consent_client',
    'client_consent_get_pending',
    'client_consent_get_photo_path',
    'client_consent_set_photo',
    'client_consent_set_review_name'
  )
order by n.nspname, p.proname;

-- Los permisos de las funciones del portal de la clienta (anon debe poder).
select '-- permiso ' || routine_name || ' -> ' || grantee
from information_schema.routine_privileges
where routine_schema = 'public'
  and routine_name like 'client_consent_%'
order by routine_name, grantee;

\o
