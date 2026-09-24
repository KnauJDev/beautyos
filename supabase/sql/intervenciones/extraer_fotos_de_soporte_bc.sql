-- Extrae el texto VIVO de lo que decide si soporte ve una foto. Hallazgo BC.
--
-- POR QUE. El propietario decidio: "arregla las fotos y dejalo como julio"
-- (D-076: el dueno de plataforma ve reseñas y fotos de cualquier negocio, en
-- solo lectura, mientras la plataforma no tenga clientes reales).
--
-- `platform_get_tenant_work_photos` nacio el 27-jul, ANTES de que el 09-ago
-- las fotos pendientes se volvieran privadas (H-09, D-119). Nunca se toco
-- despues: solo selecciona `photo_url`, que desde esa fecha es NULL hasta que
-- el negocio aprueba la foto. Por eso la pantalla de soporte dice "Vista no
-- disponible" tambien para fotos que julio si autorizaba ver.
--
-- Arreglarlo de verdad exige DOS piezas, y las dos se leen antes de tocarlas:
--   1. La RPC: tiene que devolver tambien `storage_bucket` y `storage_path`,
--      no solo `photo_url`.
--   2. La politica de seguridad del almacen privado (`work_photos_private_
--      select_staff`, en `storage.objects`): hoy solo deja firmar una
--      direccion temporal a quien pertenece al negocio. Hay que ampliarla
--      para el rol de plataforma, sin tocar lo que ya protege al negocio.
--
-- NO MODIFICA NADA.
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\extraer_fotos_de_soporte_bc.sql"
--
-- Deja `_vivo_bc_fotos_de_soporte.sql` en la raiz. No se sube (.gitignore).

\encoding UTF8
\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_bc_fotos_de_soporte.sql
select '-- ===== FUNCION ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind = 'f'
  and n.nspname in ('public', 'private')
  and p.proname in (
    'platform_get_tenant_work_photos',
    'platform_get_tenant_reviews',
    'beautyos_can_upload_work_photo',
    'beautyos_current_platform_role'
  )
order by n.nspname, p.proname;

-- Las politicas del almacen privado, con su condicion exacta.
select '-- ===== POLITICA storage.objects.' || policyname || ' (' || cmd || ') ====='
       || chr(10) || 'USING: ' || coalesce(qual, '(sin USING)')
       || chr(10) || 'WITH CHECK: ' || coalesce(with_check, '(sin WITH CHECK)')
from pg_policies
where schemaname = 'storage' and tablename = 'objects'
  and policyname ilike '%work_photos%'
order by policyname;

-- Las columnas reales de work_photos, para no inventar nombres.
select '-- columna work_photos.' || column_name || ' ' || data_type
       || case when is_nullable = 'NO' then ' not null' else '' end
from information_schema.columns
where table_schema = 'public' and table_name = 'work_photos'
order by ordinal_position;
\o
