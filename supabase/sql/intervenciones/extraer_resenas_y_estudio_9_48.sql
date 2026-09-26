-- Extrae el texto VIVO de las dos funciones que el paso 9.48 reescribe.
--
-- POR QUE. La migracion 20260926130000_que_ella_autorice_9_48.sql fallo al
-- aplicarse el 26-sep: "cannot change return type of existing function" en
-- `get_public_salon_reviews`. Se habia reescrito desde la migracion del
-- 27-ago (D-165), sin ver que el 29-ago (D-170) le agrego la columna
-- `business_reply` -- la respuesta del salon bajo cada reseña. De haber
-- pasado, la pagina publica habria dejado de mostrar esas respuestas sin
-- avisar a nadie. No paso: la migracion va en begin/commit y no aplico nada.
--
-- Es la regla 10 incumplida: se leyo el repositorio, no la base. Esta
-- lectura es la que falto, y la migracion se vuelve a generar desde lo que
-- salga de aqui, no desde la memoria.
--
-- Ademas comprueba que ninguna de las funciones y columnas NUEVAS del 9.48
-- exista ya en la base con otra forma (la misma trampa, al reves).
--
-- NO MODIFICA NADA.
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\extraer_resenas_y_estudio_9_48.sql"
--
-- Deja `_vivo_9_48_resenas_y_estudio.sql` en la raiz. No se sube (.gitignore).

\encoding UTF8
\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_9_48_resenas_y_estudio.sql

-- 1. Las dos funciones que se reescriben: su texto completo, tal cual vive.
select '-- ===== FUNCION ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind = 'f'
  and n.nspname = 'public'
  and p.proname in (
    'get_public_salon_reviews',
    'get_publication_studio_data'
  )
order by p.proname;

-- 2. Las funciones NUEVAS: si alguna ya existiera, saldria aqui. Lo esperado
--    es que esta seccion salga VACIA.
select '-- ===== YA EXISTE (no deberia): ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ')'
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public', 'private')
  and p.proname in (
    'beautyos_resolve_consent_client',
    'get_or_create_client_consent_link',
    'client_consent_get_pending',
    'client_consent_get_photo_path',
    'client_consent_set_photo',
    'client_consent_set_review_name'
  );

-- 3. Las columnas reales de las tres tablas que se tocan, para no inventar.
select '-- columna ' || table_name || '.' || column_name || ' ' || data_type
       || case when is_nullable = 'NO' then ' not null' else '' end
from information_schema.columns
where table_schema = 'public'
  and table_name in ('reviews', 'clients', 'work_photos')
order by table_name, ordinal_position;

\o
