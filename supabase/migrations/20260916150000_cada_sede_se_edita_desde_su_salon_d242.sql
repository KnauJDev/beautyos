-- ============================================================================
-- MIGRACIÓN: 20260916150000_cada_sede_se_edita_desde_su_salon_d242.sql
-- DESCRIPCIÓN: El salón edita los datos de la sede en la que está parado
--              (D-242, paso 9.43).
--
-- POR QUÉ EXISTE, Y NO ES UNA FUNCIÓN QUE FALTA SINO UN DATO QUE SE PISA
--
-- D-241 le dio al dueño de plataforma una puerta para escribir los datos de
-- una sede. Pero esos datos **no los debe teclear él**: los teclea el salón,
-- desde su propia Configuración, para la sede en la que está trabajando.
--
-- Y al ir a construir esa puerta apareció un fallo vivo. Las dos funciones de
-- Configuración **no miran en qué sede estás**:
--
--     get_business_settings():        left join branches ... is_primary = true
--     update_tenant_contact_info():   update branches ... is_primary = true
--
-- El propietario lo demostró con dos capturas. Estando dentro de la sede
-- "Uñas Naguara", Configuración le enseñaba `Calle 79 # 114-42` -- que es la
-- dirección de **la sede principal**-- mientras el Panel mostraba que la
-- dirección real de esa sede es `Calle de las peluquerias No. 14-70`.
--
-- **Es peor que enseñar el dato equivocado: es escribirlo.** Quien cambiara
-- esa casilla creyendo que edita la sede en la que está, habría sobrescrito la
-- dirección de otra sede, sin aviso y sin rastro. Con un solo local nunca se
-- nota; con dos, se corrompe en silencio.
--
-- QUÉ HACE
--
-- 1. `get_branch_info` y `update_branch_info`: la puerta del salón, protegida
--    **por sede**. Escriben las mismas siete columnas que la puerta del Panel
--    (D-241), así que no hay dos verdades.
--
-- 2. **La dirección sale de "Datos del negocio".** Es la parte que arregla el
--    fallo: mientras dos casillas distintas escriban `branches.address`, una
--    seguirá pisando a la otra. La dirección es de la sede, y solo de la sede.
--
-- EL GUARDIÁN ES POR SEDE, NO POR NEGOCIO
--
-- `beautyos_resolve_branch_access(sede, roles)` -- el mismo que usa casi toda
-- la app-- y no `is_owner_or_admin()`, que solo pregunta "¿mandas en ALGÚN
-- sitio de este negocio?". Con esa pregunta, un admin de la sede A podría
-- editar la sede B. La pregunta correcta es "¿mandas en ESTA sede?".
--
-- Lanza excepción por su cuenta cuando no, así que aquí no hay que
-- comprobar nada después: si la llamada vuelve, es que se puede.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- 1. Leer los datos de UNA sede, desde el propio salón
-- ----------------------------------------------------------------------------

create or replace function public.get_branch_info(
  p_branch_id uuid
)
returns table (
  branch_id uuid,
  branch_name text,
  is_primary boolean,
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
declare
  v_tenant_id uuid;
begin
  -- Por SEDE, no por negocio. Si no manda aqui, esto lanza y no devuelve nada.
  select r.tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id,
    array['tenant_owner', 'admin'],
    true
  ) r;

  return query
  select
    b.id,
    b.name,
    b.is_primary,
    b.manager_name,
    b.contact_email,
    b.contact_phone,
    b.whatsapp,
    b.address,
    b.city,
    b.department
  from public.branches b
  where b.id = p_branch_id
    and b.tenant_id = v_tenant_id;
end;
$$;

revoke all on function public.get_branch_info(uuid) from public, anon;
grant execute on function public.get_branch_info(uuid) to authenticated;

comment on function public.get_branch_info(uuid) is
  'Los datos propios de UNA sede, para su propio salón (D-242). Protegida por '
  'sede y no por negocio: un admin de la sede A no puede leer la B. '
  'Hermana de platform_get_tenant_branches, que hace lo mismo para el dueño de '
  'plataforma. NO ELIMINAR.';

-- ----------------------------------------------------------------------------
-- 2. Escribirlos
--
-- Escribe SIEMPRE los siete campos y no tiene valores por defecto, igual que
-- su hermana del Panel (D-241): vacio significa vacio, sin semantica de "null
-- conserva" -- que es lo que en D-237 dejaba una funcion capaz de poner y
-- cambiar pero no de quitar-- y sin defaults que permitan llamarla a medias y
-- borrar sin querer lo que no se menciono.
-- ----------------------------------------------------------------------------

create or replace function public.update_branch_info(
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
  v_tenant_id uuid;
  v_correo text := nullif(btrim(coalesce(p_contact_email, '')), '');
begin
  select r.tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id,
    array['tenant_owner', 'admin'],
    true
  ) r;

  -- Misma regla que la puerta del Panel (D-241): un correo sin arroba no es un
  -- correo, y roto no se nota hasta el dia que hace falta usarlo.
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
  where id = p_branch_id
    and tenant_id = v_tenant_id;

  if not found then
    raise exception 'No existe la sede % en este negocio', p_branch_id;
  end if;
end;
$$;

revoke all on function public.update_branch_info(
  uuid, text, text, text, text, text, text, text
) from public, anon;

grant execute on function public.update_branch_info(
  uuid, text, text, text, text, text, text, text
) to authenticated;

comment on function public.update_branch_info(
  uuid, text, text, text, text, text, text, text
) is
  'El propio salón escribe los datos de UNA de sus sedes (D-242). Protegida '
  'por sede: un admin de la sede A no puede escribir la B. Escribe siempre los '
  'siete campos y sin defaults, igual que su hermana del Panel (D-241). '
  'NO ELIMINAR.';

-- ----------------------------------------------------------------------------
-- 3. LA CORRECCIÓN: la dirección sale de "Datos del negocio"
--
-- Mientras dos casillas distintas escriban `branches.address`, una pisa a la
-- otra. Y la que estaba aqui escribia SIEMPRE en la sede principal, mirases
-- donde mirases.
--
-- Se quita el parametro en vez de ignorarlo: un parametro que se acepta y no
-- hace nada es como una funcion que no se llama -- parece que esta y no esta,
-- y el dia que alguien lo mande se quedara esperando un efecto que no llega.
-- Cambiar la lista de parametros exige DROP, igual que cambiar el tipo de
-- retorno (D-237).
-- ----------------------------------------------------------------------------

drop function if exists public.update_tenant_contact_info(
  text, text, text, text, text, text, text
);

create or replace function public.update_tenant_contact_info(
  p_full_name text,
  p_business_type text,
  p_contact_phone text,
  p_whatsapp text,
  p_instagram text,
  p_facebook text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid := public.get_my_tenant_id();
  v_full_name text := nullif(trim(coalesce(p_full_name, '')), '');
begin
  if v_tenant_id is null then
    raise exception 'No existe un perfil activo asociado al usuario actual.';
  end if;

  if not public.is_owner_or_admin() then
    raise exception 'No autorizado. Solo owner o admin puede editar los datos del negocio.';
  end if;

  update public.tenants
  set
    business_type = nullif(trim(coalesce(p_business_type, '')), ''),
    contact_phone = nullif(trim(coalesce(p_contact_phone, '')), ''),
    whatsapp = nullif(trim(coalesce(p_whatsapp, '')), ''),
    instagram = nullif(trim(coalesce(p_instagram, '')), ''),
    facebook = nullif(trim(coalesce(p_facebook, '')), '')
  where id = v_tenant_id
    and active = true;

  if not found then
    raise exception 'No se encontró el negocio activo del usuario actual.';
  end if;

  if v_full_name is not null then
    update public.user_profiles
    set full_name = v_full_name
    where tenant_id = v_tenant_id
      and role = 'owner';
  end if;

  -- Aqui escribia `branches.address where is_primary = true`. Se fue a
  -- `update_branch_info`, que escribe la sede en la que de verdad estas
  -- (D-242).
end;
$$;

revoke execute on function public.update_tenant_contact_info(
  text, text, text, text, text, text
) from anon, public;
grant execute on function public.update_tenant_contact_info(
  text, text, text, text, text, text
) to authenticated;

comment on function public.update_tenant_contact_info(
  text, text, text, text, text, text
) is
  'Autoservicio: el owner o admin edita los datos del NEGOCIO -- titular, tipo, '
  'teléfono, WhatsApp, redes (D-161, D-166). **Ya no toca la dirección**: esa '
  'es de la sede y se escribe con update_branch_info (D-242), porque escribirla '
  'aquí la mandaba siempre a la sede principal.';

-- ----------------------------------------------------------------------------
-- 4. Y deja de devolverla
--
-- Cambia el tipo de retorno: DROP obligatorio. El cuerpo se extrae del de
-- D-166 y solo se le quitan la columna y su `left join`.
-- ----------------------------------------------------------------------------

drop function if exists public.get_business_settings();

create or replace function public.get_business_settings()
returns table (
  id uuid,
  name text,
  contact_name text,
  business_type text,
  contact_email text,
  contact_phone text,
  whatsapp text,
  instagram text,
  facebook text,
  logo_url text,
  cover_photo_url text,
  theme_key text,
  brand_color text,
  slug text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  current_tenant_id uuid;
begin
  current_tenant_id := public.get_my_tenant_id();

  if current_tenant_id is null then
    raise exception 'No existe un perfil activo asociado al usuario actual.';
  end if;

  if not public.is_owner_or_admin() then
    raise exception 'No autorizado. Solo owner o admin puede ver la configuración del negocio.';
  end if;

  return query
  select
    t.id,
    t.name,
    up.full_name,
    t.business_type,
    t.contact_email,
    t.contact_phone,
    t.whatsapp,
    t.instagram,
    t.facebook,
    t.logo_url,
    t.cover_photo_url,
    t.theme_key,
    t.brand_color,
    t.slug
  from public.tenants t
  left join public.user_profiles up
    on up.tenant_id = t.id
   and up.role = 'owner'
   and up.active = true
  where t.id = current_tenant_id
    and t.active = true
  limit 1;
end;
$$;

revoke execute on function public.get_business_settings() from anon, public;
grant execute on function public.get_business_settings() to authenticated;

comment on function public.get_business_settings() is
  'Los datos del NEGOCIO para su propia Configuración. **Ya no devuelve la '
  'dirección** (D-242): devolvía siempre la de la sede principal, mirases la '
  'sede que mirases, y la casilla que la enseñaba escribía en esa misma. La '
  'dirección se lee con get_branch_info, por sede.';

commit;
