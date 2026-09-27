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

\o
