-- Cómo quedaron las fotos de la Peluquería Éxito Prueba después de la
-- primera prueba real de publicar y retirar (27-sep, D-285 + 9.48).
--
-- LO QUE SE VIO EN PANTALLA: antes de retirar, el portafolio público mostraba
-- DOS fotos (la misma imagen); después de que Juan Carlos retiró la suya,
-- queda UNA. En su portal solo aparecía una foto como respondida, así que la
-- que queda no se sabe de quién es ni con qué consentimiento salió. Además,
-- "Mis fotos de trabajos" del portal quedó vacío. Esta lectura lo comprueba
-- antes de afirmar nada (regla 25 a).
--
-- NO MODIFICA NADA.
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\verificar_fotos_tras_retiro_9_48.sql"
--
-- Deja `_vivo_fotos_tras_retiro.sql` en la raiz. No se sube (.gitignore).

\encoding UTF8
\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_fotos_tras_retiro.sql

-- 1. TODAS las fotos activas del negocio, de quién son y dónde está el
--    archivo de verdad.
select '-- foto ' || wp.id
       || chr(10) || '   clienta=' || coalesce(c.name, '(sin clienta)')
       || ' | creada ' || to_char(wp.created_at, 'YYYY-MM-DD HH24:MI')
       || ' | tipo=' || coalesce(wp.photo_type, '(nulo)')
       || chr(10) || '   visible_cliente=' || wp.visible_to_customer
       || ' | aprobada_portafolio=' || wp.approved_for_portfolio
       || ' | consentimiento=' || wp.client_consent
       || ' | ella_decidio=' || coalesce(to_char(wp.client_consent_decided_at, 'YYYY-MM-DD HH24:MI'), '(nunca)')
       || chr(10) || '   almacen=' || coalesce(wp.storage_bucket, '(nulo)')
       || ' | en work-photos=' || exists (
            select 1 from storage.objects o
            where o.bucket_id = 'work-photos' and o.name = wp.storage_path)
       || ' | en work-photos-private=' || exists (
            select 1 from storage.objects o
            where o.bucket_id = 'work-photos-private' and o.name = wp.storage_path)
       || ' | url=' || case when wp.photo_url is null then '(nula)' else '(tiene)' end
from public.work_photos wp
join public.tenants t on t.id = wp.tenant_id
left join public.clients c on c.id = wp.client_id
where t.slug = 'peluqueria-exito-prueba'
  and wp.active
order by wp.created_at;

-- 2. Lo que el portafolio público entrega hoy, tal cual.
select '-- portafolio publico: ' || count(*) || ' foto(s)'
from public.work_photos wp
join public.tenants t on t.id = wp.tenant_id
where t.slug = 'peluqueria-exito-prueba'
  and wp.active
  and wp.approved_for_portfolio;

\o
