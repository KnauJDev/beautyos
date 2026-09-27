-- Por qué publicar una foto en el portafolio responde "Object not found"
-- (27-sep, después de D-284). Hallazgo BW, segunda parte.
--
-- LO QUE SE SABE: D-284 arregló LEER el almacén privado (la galería volvió
-- a mostrar las fotos). Pero aprobar sigue fallando, ahora al MOVER el
-- archivo del almacén privado al público. Según la documentación de
-- Supabase, mover exige permiso de UPDATE (y SELECT) en storage.objects, y
-- la lectura del 27-sep no mostró ninguna política de UPDATE para las
-- fotos. Además, en el repositorio, `beautyos_can_delete_work_photo` (la
-- que decide publicar y borrar) nació el 09-ago SIN permiso para
-- `authenticated`. Nada de esto está comprobado en la base todavía: esta
-- lectura lo comprueba antes de arreglar (regla 25 a).
--
-- NO MODIFICA NADA.
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\verificar_publicar_fotos_bw.sql"
--
-- Deja `_vivo_publicar_fotos.sql` en la raiz. No se sube (.gitignore).

\encoding UTF8
\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_publicar_fotos.sql

-- 1. TODAS las políticas de storage.objects, de cualquier tipo (también
--    UPDATE y ALL), sin filtrar por nombre: una política genérica también
--    cuenta.
select '-- ===== POLITICA ' || policyname || ' (' || cmd || ') ROLES: '
       || array_to_string(roles, ',')
       || chr(10) || 'USING: ' || coalesce(qual, '(sin USING)')
       || chr(10) || 'WITH CHECK: ' || coalesce(with_check, '(sin WITH CHECK)')
from pg_policies
where schemaname = 'storage' and tablename = 'objects'
order by cmd, policyname;

-- 2. Quién puede ejecutar cada función que usan esas políticas.
select '-- permiso ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') -> authenticated = '
       || has_function_privilege('authenticated', p.oid, 'execute')
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('private', 'public')
  and p.proname in (
    'beautyos_can_upload_work_photo',
    'beautyos_can_delete_work_photo',
    'get_my_platform_role',
    'beautyos_current_platform_role'
  )
order by p.proname;

-- 3. ¿Alguna vez se publicó una foto moviéndola? Archivos que hay en el
--    almacén público, por mes en que se crearon.
select '-- en work-photos: ' || count(*) || ' archivo(s) creados en '
       || to_char(date_trunc('month', o.created_at), 'YYYY-MM')
from storage.objects o
where o.bucket_id = 'work-photos'
group by date_trunc('month', o.created_at)
order by date_trunc('month', o.created_at);

select '-- fotos aprobadas con su archivo en el almacen publico: ' || count(*)
       || ' | la mas reciente aprobada: '
       || coalesce(to_char(max(wp.updated_at), 'YYYY-MM-DD HH24:MI'), '(ninguna)')
from public.work_photos wp
where wp.active and wp.approved_for_portfolio
  and exists (
    select 1 from storage.objects o
    where o.bucket_id = 'work-photos' and o.name = wp.storage_path);

-- 4. Cómo quedaron las dos fotos de la prueba después del intento de hoy
--    (¿la app deshizo la aprobación al fallar el movimiento?).
select '-- foto ' || wp.id || ' | aprobada=' || wp.approved_for_portfolio
       || ' | almacen=' || wp.storage_bucket
       || ' | url=' || coalesce(wp.photo_url, '(nula)')
       || ' | consentimiento=' || wp.client_consent
       || ' | archivo en privado=' || exists (
            select 1 from storage.objects o
            where o.bucket_id = 'work-photos-private' and o.name = wp.storage_path)
       || ' | archivo en publico=' || exists (
            select 1 from storage.objects o
            where o.bucket_id = 'work-photos' and o.name = wp.storage_path)
from public.work_photos wp
where wp.id in ('f34f1725-602b-41a0-9269-1e212af2d55d', 'caa1e986-f5b2-4df8-9b7d-2baf7475c850');

\o
