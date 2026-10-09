-- ORDENA el catálogo de Inspirant (David) en 8 categorías y corrige la
-- ortografía de los nombres (D-324). SÍ MODIFICA: 28 servicios, solo su
-- nombre y su categoría. Ni precios, ni duraciones, ni nada más.
--
-- POR QUÉ. El 09-oct el propietario pidió ordenarlo, y David ya lo aprobó
-- (antes, D-322, se había decidido que lo corrigiera él). Las categorías
-- estaban repetidas por la tilde (peluquería / peluqueria, barbería /
-- barberia), casi todo caía en "peluquería", y había una categoría "solo David
-- marin" que no es una categoría: quién hace un servicio se dice en
-- Estilistas.
--
-- CÓMO SE ESCRIBIÓ (regla 10). Desde la lectura viva
-- (`extraer_servicios_de_inspirant.sql`, 09-oct): los 28 servicios por su id,
-- y `update_service`, que para el nombre y la categoría solo hace
-- `trim(nombre)` y `nullif(trim(categoria), '')` (no hay disparadores ni
-- restricciones de nombre en `services`). Cada servicio se cambia SOLO si
-- todavía tiene el nombre y la categoría que se leyeron: si David tocó alguno
-- entre tanto, no coinciden los 28 y no se cambia NADA.
--
--   powershell -ExecutionPolicy Bypass -File "scripts\respaldo_supabase.ps1"
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\ordenar_servicios_de_inspirant_d324.sql"
--
-- Al final lista el catálogo como quedó.

set client_encoding = 'UTF8';

begin;

do $orden$
declare
  v_tenant uuid;
  v_n integer;
begin
  select t.id into v_tenant from public.tenants t where t.slug = 'inspirant-salon';
  if v_tenant is null then
    raise exception 'No encontre el salon inspirant-salon. No se cambio nada.';
  end if;

  with cambios (id, nombre_antes, categoria_antes, nombre, categoria) as (
    values
      ('d2765424-4df2-41cc-b833-b4f9111d8cda'::uuid, 'corte hombre', 'barberia', 'Corte hombre', 'Barbería'),
      ('0cd48c6d-a5de-4f35-b76f-648c0ff3d7d7'::uuid, 'corte de barba', 'barbería', 'Corte de barba', 'Barbería'),
      ('a9a18d79-bba5-444a-9670-7d6af2c698ae'::uuid, 'corte y barba', 'barbería', 'Corte y barba', 'Barbería'),
      ('fcdd9744-f03b-48ac-9c78-9a3f6f9eac79'::uuid, 'termocut corte', 'peluqueria', 'Termocut corte', 'Cortes'),
      ('db9e5f16-b981-49ef-8926-a898dd4a4dff'::uuid, 'corte mujer', 'peluquería', 'Corte mujer', 'Cortes'),
      ('0418e040-05e4-4872-83e7-ad2f3f4f74f1'::uuid, 'corte personalizado y asesoria', 'solo David marin', 'Corte personalizado y asesoría', 'Cortes'),
      ('3c3f429c-5798-41a2-8964-6955e02ee8ae'::uuid, 'balayage', 'peluqueria', 'Balayage', 'Color'),
      ('41f4d3c7-59f8-4e9b-8b00-7dbd6e5860ce'::uuid, 'base de color unico', 'peluquería', 'Base de color único', 'Color'),
      ('53b3e191-86ad-4899-b729-4a0ff2ad9f5b'::uuid, 'iluminaciones, mechas, rayitos', 'peluquería', 'Iluminaciones, mechas y rayitos', 'Color'),
      ('42727abd-6d40-4bcd-a1d8-42467ca3ab90'::uuid, 'matizacion d color con tintura', 'peluquería', 'Matización de color con tintura', 'Color'),
      ('fdd44e14-207e-4aa4-988d-d5460a26ad5b'::uuid, 'keratina', 'peluquería', 'Keratina', 'Tratamientos capilares'),
      ('b09f5bbd-0860-453f-9c6d-e657e7486a36'::uuid, 'tratamiento kerastase', 'peluquería', 'Tratamiento Kérastase', 'Tratamientos capilares'),
      ('01113810-1dde-4c82-8237-3b24e4e93ffb'::uuid, 'tratamiento loreal,swarkof', 'peluqueria', 'Tratamiento L''Oréal / Schwarzkopf', 'Tratamientos capilares'),
      ('3828c950-98b6-469f-aa20-b394d0ee3d3e'::uuid, 'rik reparación instantánea capilar', 'tratamiento alizador y reconstructor', 'RIK reparación instantánea capilar (alisador y reconstructor)', 'Tratamientos capilares'),
      ('41d82011-6b9d-472e-b8fe-f9c5c3c0b8d9'::uuid, 'lavado y tratamiento sencillo', 'peluquería', 'Lavado y tratamiento sencillo', 'Tratamientos capilares'),
      ('8dea7393-3d79-429b-9f55-f6f79eff0a2d'::uuid, 'cepillado corto', 'peluquería', 'Cepillado corto', 'Cepillados y peinados'),
      ('fd313a77-53a4-4d3d-abe5-42942ae2b8ea'::uuid, 'cepillado cabello medio', 'peluquería', 'Cepillado cabello medio', 'Cepillados y peinados'),
      ('df4303b1-d945-4e67-a4c5-9d0c9ea7df9a'::uuid, 'cepillado cabello largo', 'peluquería', 'Cepillado cabello largo', 'Cepillados y peinados'),
      ('f6573a2b-0c13-4a55-b0c5-d395b6d0e91f'::uuid, 'cepillado y ondas', 'peluquería', 'Cepillado y ondas', 'Cepillados y peinados'),
      ('e864bf32-67dd-4a38-a436-9d2deaf0e729'::uuid, 'peinado para 15 años', 'peluquería', 'Peinado para 15 años', 'Cepillados y peinados'),
      ('bed5693f-6273-4dbe-b936-dc3f60d0acca'::uuid, 'peinado de novia', 'peluquería', 'Peinado de novia', 'Cepillados y peinados'),
      ('7b19e302-2d67-44a7-8086-dd0b3963381f'::uuid, 'maquillaje de oficina', 'peluqueria', 'Maquillaje de oficina', 'Maquillaje'),
      ('bcff65a3-74ae-4fde-8751-1ee020d1f169'::uuid, 'maquillaje para 15 años', 'peluquería', 'Maquillaje para 15 años', 'Maquillaje'),
      ('c60653cf-995e-4d56-bb57-4b5965216f4c'::uuid, 'maquillaje novia', 'peluquería', 'Maquillaje de novia', 'Maquillaje'),
      ('881b13bb-05f0-41fb-b9f7-43138b02059b'::uuid, 'depilación cejas', 'peluquería', 'Depilación de cejas', 'Rostro y cejas'),
      ('560ed7d0-85d6-4bfe-a61b-3ff47d31fbe1'::uuid, 'depilación bigote', 'peluquería', 'Depilación de bigote', 'Rostro y cejas'),
      ('ba5db4dc-3864-4fc7-aa97-441b6c7bf01a'::uuid, 'facial', 'peluquería', 'Facial', 'Rostro y cejas'),
      ('00bacaec-8ab2-463b-ab5e-ff41c6392887'::uuid, 'extenciones de cabello', 'peluquería', 'Extensiones de cabello', 'Extensiones')
  )
  update public.services s
     set name = c.nombre,
         category = c.categoria
    from cambios c
   where s.id = c.id
     and s.tenant_id = v_tenant
     and trim(s.name) = c.nombre_antes
     and trim(coalesce(s.category, '')) = c.categoria_antes;

  get diagnostics v_n = row_count;
  if v_n <> 28 then
    raise exception 'Se esperaban 28 servicios con el nombre y la categoria leidos el 09-oct y coinciden %. No se cambio nada.', v_n;
  end if;

  raise notice 'OK: 28 servicios de Inspirant ordenados en 8 categorias';
end
$orden$;

commit;

\echo ''
\echo 'EL CATALOGO DE INSPIRANT COMO QUEDO:'
select s.category as categoria, s.name as servicio, s.duration_minutes as minutos, s.price as precio
from public.services s
join public.tenants t on t.id = s.tenant_id
where t.slug = 'inspirant-salon'
order by s.category, s.name;
