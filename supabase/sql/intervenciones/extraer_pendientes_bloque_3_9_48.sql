-- Extrae el texto VIVO de `client_consent_get_pending` antes del Bloque 3 del
-- paso 9.48 (la página del enlace directo).
--
-- POR QUE. La página del enlace no sabe de qué salón viene: solo trae el
-- token de la clienta. Para pintar los colores del salón (decisión del
-- propietario, 28-sep) y ofrecer "Ver la página de [Salón]" necesita el
-- `slug` del negocio, y hoy `client_consent_get_pending` devuelve el nombre y
-- el WhatsApp, no el slug. Hay que añadirlo, y la regla 10 manda leer el
-- texto vivo antes de reescribir (la primera migración del 9.48 falló por
-- saltarse esto, D-281).
--
-- NO MODIFICA NADA.
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\extraer_pendientes_bloque_3_9_48.sql"
--
-- Deja `_vivo_pendientes_b3.sql` en la raiz. No se sube (.gitignore).

\encoding UTF8
\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_pendientes_b3.sql

select '-- ===== FUNCION ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind = 'f'
  and n.nspname = 'public'
  and p.proname = 'client_consent_get_pending';

select '-- permiso ' || routine_name || ' -> ' || grantee
from information_schema.routine_privileges
where routine_schema = 'public'
  and routine_name = 'client_consent_get_pending'
order by grantee;

-- ¿Todos los negocios activos tienen slug? Si alguno no, la página del
-- enlace tiene que funcionar igual sin colores ni botón.
select '-- negocios activos: ' || count(*)
       || ' | sin slug: ' || count(*) filter (where coalesce(btrim(t.slug), '') = '')
from public.tenants t
where t.active;

\o
