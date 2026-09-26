-- ==============================================================================
-- Verificacion puntual, 26-sep: tras borrar la segunda Naguara de Uñas con
-- AS, sigue viendose un archivo en work-photos-private. Antes de darlo por
-- bueno, se comprueba de quien es -- si es de OTRO negocio (activo, no
-- borrado), es exactamente el comportamiento esperado: AS solo debe tocar
-- los archivos del negocio que se borra, ninguno mas.
--
-- NO MODIFICA NADA. Solo lectura.
-- ==============================================================================

select o.bucket_id, o.name, b.name as sede, t.name as negocio, t.is_demo
from storage.objects o
join public.branches b on b.id::text = (storage.foldername(o.name))[1]
join public.tenants t on t.id = b.tenant_id
where o.bucket_id = 'work-photos-private'
  and o.name like '%6eafecc5-a3e3-45f3-80dd-b5c81d4a34b3.jfif%';
