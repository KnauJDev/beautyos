-- Verificacion de la accion A4: fotos privadas hasta aprobar (H-09).
--
-- Se ejecuta DESPUES de aplicar
-- supabase/migrations/20260809180000_fotos_privadas_hasta_aprobar.sql
--
-- Es de SOLO LECTURA. No crea, no borra, no mueve nada.
--
-- Lo que NO puede comprobar y hay que decirlo: subir, aprobar y retirar una
-- foto pasan por funciones que resuelven quien eres con la sesion del
-- navegador (`auth.uid()`), y aqui no hay sesion. **Eso lo prueba el
-- propietario en produccion**, que es el metodo acordado. Este script
-- comprueba lo que si es comprobable sin sesion: que los almacenes y las
-- politicas quedaron como deben, y que ningun dato quedo incoherente.

-- ---------------------------------------------------------------------------
-- 1. Los dos almacenes, con la privacidad correcta.
--    work-photos debe ser publico; work-photos-private, privado.
-- ---------------------------------------------------------------------------
select
  id as almacen,
  public as es_publico,
  file_size_limit as limite_bytes,
  case
    when id = 'work-photos' and public then 'correcto'
    when id = 'work-photos-private' and not public then 'correcto'
    else 'REVISAR'
  end as veredicto
from storage.buckets
where id in ('work-photos', 'work-photos-private')
order by id;

-- ---------------------------------------------------------------------------
-- 2. Las politicas nuevas. Deben aparecer las 9.
--
--    3 del almacen privado (insertar, leer, borrar), 3 del publico (insertar
--    solo dueno/admin, leer y borrar, que son las que permiten el movimiento)
--    y 3 de borrado para logo, portada y foto del profesional -- la otra
--    mitad de H-09, los archivos huerfanos que nunca se podian limpiar.
-- ---------------------------------------------------------------------------
select policyname as politica, cmd as operacion
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
  and policyname in (
    'work_photos_private_insert_staff',
    'work_photos_private_select_staff',
    'work_photos_private_delete_staff',
    'work_photos_insert_owner_admin',
    'work_photos_select_staff',
    'work_photos_delete_staff',
    'tenant_logos_delete_owner',
    'tenant_covers_delete_owner',
    'stylist_photos_delete_owner_admin'
  )
order by policyname;

-- ---------------------------------------------------------------------------
-- 2b. La politica vieja de insercion en el almacen publico debe haber
--     DESAPARECIDO: dejaba a un estilista escribir directamente ahi, que es
--     justo el agujero que cierra este bloque. Debe devolver 0 filas.
-- ---------------------------------------------------------------------------
select policyname
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
  and policyname = 'work_photos_insert_staff';

-- ---------------------------------------------------------------------------
-- 3. Ninguna foto VIVA se quedo sin ruta de archivo. Debe devolver 0.
--    Las eliminadas si tienen la ruta nula a proposito: su archivo ya no
--    existe y se comprueban aparte, en el punto 7.
-- ---------------------------------------------------------------------------
select count(*) as fotos_sin_ruta
from public.work_photos
where active
  and (storage_path is null or btrim(storage_path) = '');

-- ---------------------------------------------------------------------------
-- 4. LA COMPROBACION QUE IMPORTA: aprobada y publicada son lo mismo.
--
--    Debe devolver 0 filas. Cada fila que salga es una incoherencia real:
--
--    * "publicada sin aprobar" es una FUGA: el archivo esta en el almacen
--      publico y alcanzable, pero el negocio no lo aprobo.
--    * "aprobada sin publicar" solo es molesto: la foto no se ve en el
--      portafolio aunque deberia.
-- ---------------------------------------------------------------------------
select
  id,
  approved_for_portfolio as aprobada,
  storage_bucket as almacen,
  (photo_url is not null) as tiene_direccion_publica,
  case
    when not approved_for_portfolio
     and (storage_bucket = 'work-photos' or photo_url is not null)
      then 'FUGA: publicada sin aprobar'
    else 'aprobada sin publicar'
  end as problema
from public.work_photos
where active
  and (
    (approved_for_portfolio
      and (storage_bucket <> 'work-photos' or photo_url is null))
    or
    (not approved_for_portfolio
      and (storage_bucket <> 'work-photos-private' or photo_url is not null))
  );

-- ---------------------------------------------------------------------------
-- 5. Foto por foto, para mirarlo con los ojos.
-- ---------------------------------------------------------------------------
select
  wp.id,
  t.name as negocio,
  wp.photo_type as tipo,
  wp.approved_for_portfolio as aprobada,
  wp.visible_to_customer as visible_al_cliente,
  wp.storage_bucket as almacen,
  wp.storage_path as ruta,
  case
    when wp.approved_for_portfolio then 'publicada, direccion permanente'
    else 'privada, solo se ve dentro de la app'
  end as estado
from public.work_photos wp
join public.tenants t on t.id = wp.tenant_id
where wp.active
order by wp.created_at desc;

-- ---------------------------------------------------------------------------
-- 6. Que el archivo este donde la base dice que esta.
--
--    Compara contra storage.objects, que es la lista real de archivos. Debe
--    devolver 0 filas: una fila aqui significa que la base y el almacen no
--    se pusieron de acuerdo -- por ejemplo, un movimiento que fallo a mitad.
-- ---------------------------------------------------------------------------
select
  wp.id,
  wp.storage_bucket as dice_la_base,
  o.bucket_id as donde_esta_de_verdad,
  wp.storage_path as ruta
from public.work_photos wp
left join storage.objects o
  on o.name = wp.storage_path
 and o.bucket_id in ('work-photos', 'work-photos-private')
where wp.active
  and (o.bucket_id is null or o.bucket_id <> wp.storage_bucket);

-- ---------------------------------------------------------------------------
-- 7. Fotos ya eliminadas: no deben conservar ni ruta ni direccion.
--    Debe devolver 0 filas. Una fila aqui es un apuntador a un archivo que ya
--    no existe -- o peor, a uno que si existe y deberia haberse borrado.
-- ---------------------------------------------------------------------------
select id, storage_path, photo_url
from public.work_photos
where not active
  and (storage_path is not null or photo_url is not null);

-- ---------------------------------------------------------------------------
-- 8. Que las politicas se puedan EVALUAR, no solo que existan.
--
--    Agregado el 09-ago despues de un fallo real: el ayudante
--    `beautyos_can_delete_work_photo` existia, las politicas lo usaban, y
--    subir una foto reventaba con "permission denied for function" porque
--    `authenticated` no podia ejecutarlo.
--
--    Una politica se evalua con los permisos de quien hace la operacion. Si
--    llama a una funcion y ese usuario no puede ejecutarla, la operacion
--    falla aunque la politica este perfectamente escrita.
--
--    Las dos deben decir 'correcto'.
-- ---------------------------------------------------------------------------
select
  p.proname as ayudante,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') as puede_authenticated,
  has_function_privilege('anon', p.oid, 'EXECUTE') as puede_anon,
  case
    when not has_function_privilege('authenticated', p.oid, 'EXECUTE')
      then 'REVISAR: authenticated no puede ejecutarlo, las politicas fallaran'
    when has_function_privilege('anon', p.oid, 'EXECUTE')
      then 'REVISAR: anon no deberia poder ejecutarlo (H-11)'
    else 'correcto'
  end as veredicto
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'private'
  and p.proname in (
    'beautyos_can_upload_work_photo',
    'beautyos_can_delete_work_photo'
  )
order by p.proname;
