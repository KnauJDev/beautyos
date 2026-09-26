-- ==============================================================================
-- Barrido de archivos huerfanos en Storage, tras el borrado (sin AS todavia
-- desplegado) de Naguara de Unas.
--
-- POR QUE: Naguara se borro con el codigo viejo -- sus filas de la base ya
-- no existen (tenants, branches, work_photos, todo), pero sus archivos en
-- Storage siguen ahi porque esa parte del arreglo (AS) aun no estaba
-- publicada cuando se borro. Ahora esos archivos no tienen ninguna fila que
-- diga de quien eran. Esta lectura los encuentra comparando cada carpeta de
-- cada almacen contra los tenants/branches que SI existen hoy: lo que
-- sobra, es huerfano.
--
-- work-photos y work-photos-private usan {branch_id}/archivo como ruta;
-- tenant-logos, tenant-covers y stylist-photos usan {tenant_id}/... .
-- Se compara como texto, no como uuid, para no reventar si alguna carpeta
-- tuviera un nombre raro -- que entonces tambien cuenta como huerfana.
--
-- NO MODIFICA NADA. Solo lecturas.
-- ==============================================================================

\echo '--- 1. Huerfanos en work-photos y work-photos-private (carpeta = branch_id que ya no existe) ---'
select o.bucket_id, o.name, o.created_at
from storage.objects o
where o.bucket_id in ('work-photos', 'work-photos-private')
  and not exists (
    select 1 from public.branches b
    where b.id::text = (storage.foldername(o.name))[1]
  )
order by o.bucket_id, o.name;

\echo '--- 2. Huerfanos en tenant-logos, tenant-covers y stylist-photos (carpeta = tenant_id que ya no existe) ---'
select o.bucket_id, o.name, o.created_at
from storage.objects o
where o.bucket_id in ('tenant-logos', 'tenant-covers', 'stylist-photos')
  and not exists (
    select 1 from public.tenants t
    where t.id::text = (storage.foldername(o.name))[1]
  )
order by o.bucket_id, o.name;
