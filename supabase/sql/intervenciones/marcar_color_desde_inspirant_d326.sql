-- MARCA la categoría Color de Inspirant (David) con precios "desde" (D-326).
-- SÍ MODIFICA: solo la lista de categorías "desde" de su negocio.
--
-- Va DESPUÉS de la migración 20261009100000 y del control 249. Es lo mismo
-- que hará el interruptor de Servicios cuando la app esté publicada; se hace
-- aquí porque el propietario no entra a la cuenta de David.
-- Comprueba antes que David tenga los 4 servicios de Color (D-324).
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\marcar_color_desde_inspirant_d326.sql"

set client_encoding = 'UTF8';

begin;

do $marcar$
declare
  v_n integer;
begin
  select count(*) into v_n
  from public.services s
  join public.tenants t on t.id = s.tenant_id
  where t.slug = 'inspirant-salon'
    and s.active
    and lower(trim(s.category)) = 'color';
  if v_n <> 4 then
    raise exception 'Se esperaban los 4 servicios de Color de Inspirant y hay %. No se cambio nada.', v_n;
  end if;

  update public.tenants t
     set price_from_categories = (
       select array_agg(distinct x order by x)
       from unnest(array_append(t.price_from_categories, 'color')) x
     )
   where t.slug = 'inspirant-salon';

  get diagnostics v_n = row_count;
  if v_n <> 1 then
    raise exception 'No encontre el salon inspirant-salon. No se cambio nada.';
  end if;

  raise notice 'OK: Inspirant tiene precios "desde" en Color (4 servicios)';
end
$marcar$;

commit;

select t.name as salon, t.price_from_categories as categorias_desde
from public.tenants t
where t.slug = 'inspirant-salon';
