-- BeautyOS - Paso 8.3 (H-11): alinea el permiso suelto de Storage.
--
-- POR QUÉ
--
-- `private.beautyos_can_upload_work_photo(uuid)` nació en
-- "20260725170000_simplificar_ruta_storage_fotos.sql" con una firma nueva
-- (un solo argumento; antes eran dos). En PostgreSQL cambiar la firma crea
-- un objeto distinto, con privilegios por defecto -- PUBLIC tiene EXECUTE
-- de fábrica --, y esa migración nunca repitió el `revoke`/`grant` que sí
-- tienen sus dos hermanas (`beautyos_can_upload_tenant_logo`,
-- `beautyos_can_manage_stylist_photo`). El esquema `private` sigue cerrado
-- a `anon`/`authenticated` desde D-024 (tramo A), así que hoy nadie externo
-- la alcanza por la API -- pero el candado de la función en sí quedó
-- suelto. Se alinea con sus dos hermanas, sin tocar una sola línea de la
-- lógica de autorización.

begin;

revoke all on function private.beautyos_can_upload_work_photo(uuid)
  from public, anon, authenticated;

grant execute on function private.beautyos_can_upload_work_photo(uuid)
  to authenticated;

commit;
