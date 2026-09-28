-- Extrae el texto VIVO de lo que el Bloque 4 del paso 9.48 va a tocar.
--
-- POR QUE. Decisiones del propietario del 28-sep:
--   * La casilla al subir la foto SE QUITA y el servidor deja de aceptar el
--     permiso por esa vía (AQ, D-260): hay que reescribir
--     `create_work_photo` para que ignore `p_client_consent`.
--   * En la galería, "Pedir autorización" sale solo en las fotos que ella
--     aún no ha respondido: `get_work_photos_summary_v2` tiene que decir si
--     ya respondió (`client_consent_decided_at`).
--   * El botón arma el WhatsApp con el enlace de `get_or_create_client_
--     consent_link`; se relee para apoyarse en ella tal como vive.
-- La regla 10 manda leer el texto vivo antes de reescribir (D-281).
--
-- Y cuenta las fotos con permiso marcado con la casilla vieja, que el
-- propietario decidió RESPETAR: no se tocan, solo se cuentan.
--
-- NO MODIFICA NADA.
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\extraer_bloque_4_9_48.sql"
--
-- Deja `_vivo_bloque_4.sql` en la raiz. No se sube (.gitignore).

\encoding UTF8
\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_bloque_4.sql

-- 1. Las funciones, tal como viven (todas las versiones, por si hay más de
--    una firma).
select '-- ===== FUNCION ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind = 'f'
  and n.nspname = 'public'
  and p.proname in (
    'create_work_photo',
    'get_work_photos_summary_v2',
    'get_or_create_client_consent_link'
  )
order by p.proname, pg_get_function_identity_arguments(p.oid);

-- 2. Quién puede ejecutarlas.
select '-- permiso ' || routine_name || ' -> ' || grantee
from information_schema.routine_privileges
where routine_schema = 'public'
  and routine_name in (
    'create_work_photo',
    'get_work_photos_summary_v2',
    'get_or_create_client_consent_link'
  )
order by routine_name, grantee;

-- 3. ¿Alguna otra función de la base llama a get_work_photos_summary_v2?
--    (Cambiar sus columnas exige borrarla y crearla de nuevo.)
select '-- la usa: ' || n.nspname || '.' || p.proname
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public', 'private')
  and p.proname <> 'get_work_photos_summary_v2'
  -- Solo funciones: pg_get_functiondef revienta con un agregado (primera
  -- corrida, 28-sep: "array_agg is an aggregate function"). Con CASE, porque
  -- Postgres no garantiza el orden de las condiciones de un WHERE.
  and case when p.prokind = 'f'
           then pg_get_functiondef(p.oid) ilike '%get_work_photos_summary_v2%'
           else false end;

-- 4. Las fotos con permiso de la casilla vieja (dado por quien subió la
--    foto, no por ella): se respetan; aquí solo se cuentan, por negocio.
select '-- permiso de la casilla vieja: ' || t.name || ' -> ' || count(*)
       || ' foto(s), publicadas: ' || count(*) filter (where wp.approved_for_portfolio)
from public.work_photos wp
join public.tenants t on t.id = wp.tenant_id
where wp.active
  and wp.client_consent
  and wp.client_consent_decided_at is null
group by t.name
order by t.name;

\o
