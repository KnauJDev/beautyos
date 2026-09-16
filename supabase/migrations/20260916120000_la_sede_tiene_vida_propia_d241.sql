-- ============================================================================
-- MIGRACIÓN: 20260916120000_la_sede_tiene_vida_propia_d241.sql
-- DESCRIPCIÓN: Una sede deja de ser un nombre con un precio y pasa a tener sus
--              propios datos: encargado, contacto y dirección (D-241, paso 9.42).
--
-- POR QUÉ EXISTE
--
-- El propietario, viendo el Panel partido en dos: *"volvemos a la falta de
-- maniobrabilidad y ajuste de la sede, que es precisamente lo que deseo
-- separar, pues tendrá en la realidad datos diferentes: contacto, mail,
-- dirección, plan..."*.
--
-- Y aquí está lo incómodo: **esas columnas existen desde el 20 de julio**.
-- `branches` nació con `contact_email`, `contact_phone`, `whatsapp`, `address`,
-- `city` y `department` en el Tramo A. Llevan dos meses vacías porque **nadie
-- las escribe**. Lo único que toca los datos de una sede hoy es
-- `update_tenant_contact_info`, que escribe `address` y solo
-- `where is_primary = true`: una sede secundaria no tiene forma de existir con
-- datos propios.
--
-- **Es la cuarta vez que aparece el mismo patrón**: capacidad construida sin
-- puerta. Antes fueron `is_demo` (D-225), el lector de sedes (D-235) y
-- `platform_set_branch_subscription` (D-236, que llevaba una semana sin que
-- nadie la llamara). Una columna que nadie escribe envejece igual que una
-- función que nadie llama: parece que está y no está.
--
-- QUÉ HACE
--
-- 1. Añade `manager_name`. Es lo único que de verdad no existía. El dueño del
--    negocio **puede no ser el encargado de ninguna sede** --lo dijo el
--    propietario al decidir D-239-- así que el nombre de quien lleva la sede
--    es un dato de la sede, no del negocio.
--
-- 2. El lector del Panel devuelve esos siete campos.
--
-- 3. Nace `platform_update_branch_info`, la puerta que faltaba.
--
-- UNA DECISIÓN SOBRE `null` QUE NO SE REPITE
--
-- `platform_update_branch_info` **no tiene valores por defecto y escribe
-- siempre los siete campos**. No hay semántica de "null conserva": el
-- formulario enseña todo y guarda todo, así que vacío significa vacío.
--
-- Es a propósito, y viene de D-237: allí `coalesce(p_price_cop, price_cop)`
-- hacía que `null` conservara, y por eso la función sabía poner y cambiar pero
-- **nunca quitar**. Aquí no se le da a `null` ningún significado escondido, y
-- al no haber valores por defecto **nadie puede llamarla a medias y borrar sin
-- querer los campos que no mencionó**.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- 1. Quién lleva esta sede
-- ----------------------------------------------------------------------------

alter table public.branches
  add column if not exists manager_name text;

comment on column public.branches.manager_name is
  'Nombre de quien lleva ESTA sede (D-241). El dueño del negocio puede no ser '
  'el encargado de ninguna de sus sedes: son personas distintas, y por eso es '
  'columna de la sede y no del negocio.';

-- ----------------------------------------------------------------------------
-- 2. El lector del Panel, con los datos propios de la sede
--
-- DROP obligatorio: cambia el tipo de retorno. Es la misma regla que costó una
-- corrida entera el 09-sep en D-237 -- `create or replace` no basta.
--
-- El cuerpo se extrae del de D-237 y solo se le añaden columnas al `select`.
-- No se reteclea: es la regla de comparar línea por línea al reescribir una
-- función (D-119, D-122, D-123).
-- ----------------------------------------------------------------------------

drop function if exists public.platform_get_tenant_branches(uuid);

create or replace function public.platform_get_tenant_branches(
  p_tenant_id uuid
)
returns table (
  branch_id uuid,
  branch_name text,
  is_primary boolean,
  branch_active boolean,
  status text,
  al_dia boolean,
  precio_cop bigint,
  motivo_precio text,
  tiene_precio_pactado boolean,
  current_period_end timestamptz,
  activated_at timestamptz,
  manager_name text,
  contact_email text,
  contact_phone text,
  whatsapp text,
  address text,
  city text,
  department text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if private.beautyos_current_platform_role() is null then
    raise exception 'No autorizado: se requiere rol de plataforma.';
  end if;

  return query
  select
    b.id,
    b.name,
    b.is_primary,
    b.active,
    bs.status,
    -- Misma regla que ve el salon en su Configuracion (D-190). "Al dia" no es
    -- lo mismo que "activa": una sede puede estar operando y en mora.
    bs.status in ('active', 'trialing'),
    coalesce(bs.price_cop, p.price_cop),
    coalesce(bs.price_reason, 'Precio de lista'),
    bs.price_cop is not null,
    bs.current_period_end,
    bs.activated_at,
    -- D-241: lo que hace que una sede sea una sede y no una fila con precio.
    b.manager_name,
    b.contact_email,
    b.contact_phone,
    b.whatsapp,
    b.address,
    b.city,
    b.department
  from public.branches b
  join public.branch_subscriptions bs on bs.branch_id = b.id
  join public.tenant_subscriptions ts on ts.tenant_id = b.tenant_id
  join public.plans p on p.id = ts.plan_id
  where b.tenant_id = p_tenant_id
  order by b.is_primary desc, b.created_at;
end;
$$;

revoke all on function public.platform_get_tenant_branches(uuid) from public, anon;
grant execute on function public.platform_get_tenant_branches(uuid) to authenticated;

comment on function public.platform_get_tenant_branches(uuid) is
  'Estado de pago Y datos propios de las sedes de un negocio, para el dueño de '
  'plataforma (D-235, D-237, D-241). Desde D-241 devuelve encargado, contacto y '
  'dirección de cada sede: columnas que existían desde julio y no leía nadie. '
  'NO ELIMINAR.';

-- ----------------------------------------------------------------------------
-- 3. La puerta que faltaba: escribir los datos de UNA sede
-- ----------------------------------------------------------------------------

create or replace function public.platform_update_branch_info(
  p_branch_id uuid,
  p_manager_name text,
  p_contact_email text,
  p_contact_phone text,
  p_whatsapp text,
  p_address text,
  p_city text,
  p_department text
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_correo text := nullif(btrim(coalesce(p_contact_email, '')), '');
begin
  if private.beautyos_current_platform_role() is null then
    raise exception 'No autorizado: se requiere rol de plataforma.';
  end if;

  if p_branch_id is null then
    raise exception 'Falta la sede sobre la que escribir.';
  end if;

  -- Un correo sin arroba no es un correo. Se rechaza en vez de guardarlo:
  -- este campo es por donde se le escribe a quien atiende la sede, y un dato
  -- roto aqui no se nota hasta el dia que hace falta usarlo.
  if v_correo is not null and position('@' in v_correo) = 0 then
    raise exception 'El correo de la sede no parece un correo: %', v_correo;
  end if;

  update public.branches
  set
    manager_name  = nullif(btrim(coalesce(p_manager_name, '')), ''),
    contact_email = v_correo,
    contact_phone = nullif(btrim(coalesce(p_contact_phone, '')), ''),
    whatsapp      = nullif(btrim(coalesce(p_whatsapp, '')), ''),
    address       = nullif(btrim(coalesce(p_address, '')), ''),
    city          = nullif(btrim(coalesce(p_city, '')), ''),
    department    = nullif(btrim(coalesce(p_department, '')), ''),
    updated_at    = now()
  where id = p_branch_id;

  if not found then
    raise exception 'No existe la sede %', p_branch_id;
  end if;
end;
$$;

revoke all on function public.platform_update_branch_info(
  uuid, text, text, text, text, text, text, text
) from public, anon;

grant execute on function public.platform_update_branch_info(
  uuid, text, text, text, text, text, text, text
) to authenticated;

comment on function public.platform_update_branch_info(
  uuid, text, text, text, text, text, text, text
) is
  'El dueño de plataforma escribe los datos propios de UNA sede (D-241): '
  'encargado, contacto y dirección. Escribe SIEMPRE los siete campos y no '
  'tiene valores por defecto, a propósito: sin semántica de "null conserva" '
  'no se puede repetir el fallo de D-237, y sin defaults nadie la llama a '
  'medias y borra sin querer lo que no mencionó. NO ELIMINAR.';

commit;
