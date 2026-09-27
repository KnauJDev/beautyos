-- Por qué el portafolio público de la Peluquería Éxito Prueba muestra un
-- cuadro roto (visto por el propietario el 27-sep, probando el 9.48).
--
-- Lo que se sabe sin haberlo mirado todavía: NO es la foto de la prueba de
-- hoy (aún no está publicada) ni la Edge Function de retiro (nunca se ha
-- ejecutado con datos reales). La foto privada del portal SÍ cargó desde el
-- mismo almacenamiento, así que tampoco son permisos del navegador. Lo
-- probable es una foto aprobada cuyo archivo no está donde dice su
-- dirección -- pero eso es lo que esta lectura tiene que comprobar, no
-- suponer (regla 25 a).
--
-- 27-sep, AMPLIADA antes de correrla: al aprobar una foto, el salón recibió
-- "permission denied for function beautyos_current_platform_role". En el
-- repositorio, BC (20260924100000) metió private.beautyos_current_platform_role()
-- en la política del almacén privado, y esa función solo la ejecuta
-- service_role desde el 22-jul. Si la base está igual, ningún salón puede ver
-- ni publicar sus fotos privadas desde el 24-sep. Esta lectura trae la
-- política VIVA y los permisos REALES para confirmarlo antes de arreglar.
--
-- NO MODIFICA NADA.
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\verificar_portafolio_exito.sql"
--
-- Deja `_vivo_portafolio_exito.sql` en la raiz. No se sube (.gitignore).

\encoding UTF8
\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_portafolio_exito.sql

-- 1. La función que alimenta el portafolio, tal como vive.
select '-- ===== FUNCION ' || p.proname || ' =====' || chr(10) || pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'get_public_salon_portfolio';

-- 2. Cada foto aprobada para el portafolio de ese negocio, y si su archivo
--    existe de verdad en cada almacén.
select '-- foto ' || wp.id
       || ' | creada ' || to_char(wp.created_at, 'YYYY-MM-DD HH24:MI')
       || ' | visible_cliente=' || wp.visible_to_customer
       || ' | consentimiento=' || wp.client_consent
       || ' | almacen=' || coalesce(wp.storage_bucket, '(nulo)')
       || ' | ruta=' || coalesce(wp.storage_path, '(nula)')
       || ' | en work-photos=' || exists (
            select 1 from storage.objects o
            where o.bucket_id = 'work-photos' and o.name = wp.storage_path)
       || ' | en work-photos-private=' || exists (
            select 1 from storage.objects o
            where o.bucket_id = 'work-photos-private' and o.name = wp.storage_path)
       || chr(10) || '   url=' || coalesce(wp.photo_url, '(nula)')
from public.work_photos wp
join public.tenants t on t.id = wp.tenant_id
where t.slug = 'peluqueria-exito-prueba'
  and wp.active
  and wp.approved_for_portfolio
order by wp.created_at;

-- 3. Por si no sale ninguna arriba: cuántas fotos tiene ese negocio en total.
select '-- fotos activas del negocio: ' || count(*)
       || ' | aprobadas: ' || count(*) filter (where wp.approved_for_portfolio)
from public.work_photos wp
join public.tenants t on t.id = wp.tenant_id
where t.slug = 'peluqueria-exito-prueba' and wp.active;

-- 4. Las políticas de storage.objects sobre las fotos, con su condición viva.
select '-- ===== POLITICA storage.objects.' || policyname || ' (' || cmd || ') ====='
       || chr(10) || 'ROLES: ' || array_to_string(roles, ',')
       || chr(10) || 'USING: ' || coalesce(qual, '(sin USING)')
       || chr(10) || 'WITH CHECK: ' || coalesce(with_check, '(sin WITH CHECK)')
from pg_policies
where schemaname = 'storage' and tablename = 'objects'
  and (policyname ilike '%work_photo%' or qual ilike '%work-photos%' or with_check ilike '%work-photos%')
order by policyname;

-- 5. Quién puede ejecutar cada función de la política (la sospecha).
select '-- permiso ' || n.nspname || '.' || p.proname || ' -> '
       || r.rolname || ' = ' || has_function_privilege(r.rolname, p.oid, 'execute')
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
cross join (select unnest(array['anon', 'authenticated', 'service_role']) as rolname) r
where (n.nspname, p.proname) in (
  ('private', 'beautyos_current_platform_role'),
  ('public', 'get_my_platform_role'),
  ('private', 'beautyos_can_upload_work_photo')
)
order by n.nspname, p.proname, r.rolname;

-- 6. En TODOS los negocios: fotos que la base da por publicadas y cuyo
--    archivo no está en el almacén público (el cuadro roto, donde sea).
select '-- ROTA negocio=' || t.name || ' | foto ' || wp.id
       || ' | creada ' || to_char(wp.created_at, 'YYYY-MM-DD HH24:MI')
       || ' | en work-photos-private=' || exists (
            select 1 from storage.objects o
            where o.bucket_id = 'work-photos-private' and o.name = wp.storage_path)
from public.work_photos wp
join public.tenants t on t.id = wp.tenant_id
where wp.active
  and wp.approved_for_portfolio
  and not exists (
    select 1 from storage.objects o
    where o.bucket_id = 'work-photos' and o.name = wp.storage_path)
order by wp.created_at;

\o
