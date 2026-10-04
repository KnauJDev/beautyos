-- ==============================================================================
-- Paso 3 del plan de David (D-308): el tema "INSPIRANT", para todos los salones.
-- ==============================================================================
--
-- QUÉ SE DECIDIÓ (03-oct)
--
-- David mandó su logo (monograma "DM", café sobre champán) y una foto del local:
-- el rosa es el de las flores del techo, el dorado el de las grecas y la
-- recepción, el negro el del mostrador. El propietario eligió, entre dos
-- combinaciones dibujadas, la de **barra dorada, títulos negros y fondos con el
-- rosa de las flores**, como un SEXTO TEMA PARA TODOS los salones, con el
-- nombre "Inspirant", por el negocio de David.
--
-- QUÉ TOCA: SOLO LA LISTA DE TEMAS PERMITIDOS
--
-- La lectura viva (`intervenciones/extraer_tema_inspirant_paso3.sql`) mostró
-- que la lista vive en DOS sitios, y en ningún otro: la restricción
-- `tenants_theme_key_valido` y el cuerpo de `update_tenant_theme`. Los dos
-- reciben 'inspirant'. Los colores NO se guardan en la base (D-093b): viven en
-- la app (`AppBrand.inspirant`), donde las pruebas comprueban que el texto se
-- lea sobre la barra y sobre los fondos.
--
-- La función se copió del texto vivo y tiene **un solo cambio**, marcado.
-- Ningún negocio cambia de tema: solo se agrega una opción.
--
-- Lo prueba el **control 243**.
-- ==============================================================================

set client_encoding = 'UTF8';

begin;

alter table public.tenants
  drop constraint tenants_theme_key_valido;
alter table public.tenants
  add constraint tenants_theme_key_valido
  check (theme_key = any (array[
    'morado', 'barberia', 'spa_unas', 'clasica', 'canina', 'inspirant',
    'personalizado'
  ]));

CREATE OR REPLACE FUNCTION public.update_tenant_theme(p_theme_key text, p_brand_color text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
declare
  v_tenant_id uuid;
  v_theme_key text;
  v_brand_color text;
begin
  v_tenant_id := public.get_my_tenant_id();

  if v_tenant_id is null or public.get_my_role() <> 'tenant_owner' then
    raise exception 'Solo el propietario del negocio puede cambiar el tema.';
  end if;

  v_theme_key := lower(trim(coalesce(p_theme_key, '')));

  -- Paso 3 de David (03-oct): EL UNICO CAMBIO, 'inspirant'.
  if v_theme_key not in (
    'morado', 'barberia', 'spa_unas', 'clasica', 'canina', 'inspirant',
    'personalizado'
  ) then
    raise exception 'El tema "%" no existe.', p_theme_key;
  end if;

  if v_theme_key = 'personalizado' then
    v_brand_color := upper(trim(coalesce(p_brand_color, '')));

    if v_brand_color !~ '^#[0-9A-F]{6}$' then
      raise exception 'El color personalizado debe venir en formato #RRGGBB.';
    end if;
  else
    -- Se descarta a proposito el color que venga: si el negocio vuelve a un
    -- tema predefinido, dejar el hex guardado lo reviviria sin querer la
    -- proxima vez que alguien toque esta fila.
    v_brand_color := null;
  end if;

  update public.tenants
  set theme_key = v_theme_key,
      brand_color = v_brand_color
  where id = v_tenant_id;
end;
$function$;

commit;
