-- ==============================================================================
-- AS: fotos huerfanas al borrar un negocio -- lectura previa (regla 10)
--
-- POR QUE: la funcion de servidor que se va a escribir necesita leer, sin
-- adivinar, de donde saca cada archivo por negocio en los cinco almacenes
-- (work-photos, work-photos-private, tenant-logos, tenant-covers,
-- stylist-photos). Las migraciones del repo dicen que las columnas se
-- llaman de cierta forma, pero el repo no es la fuente de verdad del
-- esquema (hallazgo AI) -- puede haber cambiado algo despues sin que quede
-- claro leyendo migraciones sueltas.
--
-- QUE LEE: nombres y tipos de columna de las tablas involucradas, si
-- get_my_platform_role() existe y a quien esta concedida, y el texto exacto
-- de platform_delete_demo_tenant (para confirmar que el seguro is_demo
-- sigue ahi tal como quedo en D-246).
--
-- NO MODIFICA NADA. Solo lecturas.
-- ==============================================================================

\echo '--- 1. Columnas de work_photos relacionadas con almacenamiento ---'
select column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name = 'work_photos'
  and column_name in ('storage_bucket', 'storage_path', 'photo_url', 'active', 'tenant_id', 'branch_id')
order by column_name;

\echo '--- 2. Columnas de tenants relacionadas con logo/portada ---'
select column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name = 'tenants'
  and column_name in ('logo_url', 'cover_photo_url', 'is_demo', 'id')
order by column_name;

\echo '--- 3. Columnas de stylists relacionadas con foto ---'
select column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name = 'stylists'
  and column_name in ('photo_url', 'tenant_id', 'id')
order by column_name;

\echo '--- 4. get_my_platform_role(): existe y a quien esta concedida ---'
select routine_name, grantee, privilege_type
from information_schema.routine_privileges
where routine_schema = 'public'
  and routine_name = 'get_my_platform_role'
order by grantee;

\echo '--- 5. Texto vivo de platform_delete_demo_tenant (solo para confirmar el seguro is_demo) ---'
select pg_get_functiondef(p.oid)
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'platform_delete_demo_tenant';

\echo '--- 6. Los cinco buckets existen tal como se espera ---'
select id, public, file_size_limit
from storage.buckets
where id in ('work-photos', 'work-photos-private', 'tenant-logos', 'tenant-covers', 'stylist-photos')
order by id;

\echo '--- 7. Diagnostico: negocios de prueba hoy, y si ya tienen archivos que limpiar ---'
select
  t.id,
  t.name,
  t.is_demo,
  t.logo_url is not null as tiene_logo,
  t.cover_photo_url is not null as tiene_portada,
  (select count(*) from public.work_photos wp where wp.tenant_id = t.id and wp.active) as fotos_activas,
  (select count(*) from public.stylists st where st.tenant_id = t.id and st.photo_url is not null) as estilistas_con_foto
from public.tenants t
where t.is_demo = true
order by t.name;
