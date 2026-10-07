-- ==============================================================================
-- TikTok en las redes del salón. (D-319)
-- ==============================================================================
--
-- QUÉ PASA
--
-- David, el primer cliente real (D-308), pidió poner su TikTok junto a
-- Instagram y Facebook; el propietario lo pidió el 07-oct. El salón lo
-- escribe en Configuración y sale como botón en su página pública.
--
-- CÓMO SE ESCRIBIÓ (regla 10)
--
-- Desde la lectura viva `intervenciones/extraer_redes_tiktok.sql` (07-oct).
-- Las redes viven en `tenants.instagram` y `tenants.facebook`, sin
-- restricciones, y las nombran CUATRO funciones: las tres de abajo y
-- `platform_list_tenants` (el Panel), **que no se toca**: el Panel no necesita
-- TikTok, y así no se reescribe lo que no hace falta.
--
-- Cada función se copia del texto VIVO y solo se le agrega TikTok. Cambiar la
-- lista de parámetros o lo que devuelve exige DROP (D-237), igual que hicieron
-- D-166 y D-242 con estas mismas funciones; los permisos se vuelven a dar
-- iguales a los vivos.
--
--   1. `tenants.tiktok`: columna nueva, vacía en los 3 salones de hoy.
--   2. `update_tenant_contact_info`: gana `p_tiktok`, **con default null y
--      null = no lo toques**. Una app vieja abierta en un celular (antes de
--      pulsar "Actualizar") manda los seis de siempre: si null borrara, al
--      guardar sus datos borraría el TikTok que el salón ya había puesto
--      desde la app nueva. La app nueva manda siempre texto ('' lo borra).
--   3. `get_business_settings`: devuelve también `tiktok` (Configuración).
--   4. `get_public_salon_by_slug`: devuelve también `tiktok` (la página).
--      `functions/[slug].js` (D-316) lee otras columnas por su nombre: una
--      columna más no le cambia nada.
--
-- ORDEN: primero esta migración, después se publica la app. Al revés, la app
-- nueva mandaría `p_tiktok` a una función que todavía no lo acepta y guardar
-- los datos del negocio fallaría.
--
-- Lo prueba el CONTROL 246.
-- ==============================================================================

set client_encoding = 'UTF8';

begin;

-- ----------------------------------------------------------------------------
-- 1. La columna
-- ----------------------------------------------------------------------------

alter table public.tenants add column if not exists tiktok text;

comment on column public.tenants.tiktok is
  'TikTok del salón: usuario (@salon) o dirección completa, como lo escriba (D-319).';

-- ----------------------------------------------------------------------------
-- 2. Guardarla: copia de la viva + p_tiktok (null = no tocar)
-- ----------------------------------------------------------------------------

drop function if exists public.update_tenant_contact_info(
  text, text, text, text, text, text
);

create or replace function public.update_tenant_contact_info(
  p_full_name text,
  p_business_type text,
  p_contact_phone text,
  p_whatsapp text,
  p_instagram text,
  p_facebook text,
  p_tiktok text default null
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
    facebook = nullif(trim(coalesce(p_facebook, '')), ''),
    -- D-319: null = no lo toques (una app vieja no lo manda); '' lo borra.
    tiktok = case
      when p_tiktok is null then tiktok
      else nullif(trim(p_tiktok), '')
    end
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
  text, text, text, text, text, text, text
) from anon, public;
grant execute on function public.update_tenant_contact_info(
  text, text, text, text, text, text, text
) to authenticated;

comment on function public.update_tenant_contact_info(
  text, text, text, text, text, text, text
) is
  'Autoservicio: el owner o admin edita los datos del NEGOCIO -- titular, tipo, '
  'teléfono, WhatsApp, redes (D-161, D-166, D-319). p_tiktok null no lo toca '
  '(una app vieja no lo manda); vacío lo borra. **No toca la dirección**: esa '
  'es de la sede y se escribe con update_branch_info (D-242).';

-- ----------------------------------------------------------------------------
-- 3. Configuración la lee: copia de la viva + tiktok al final
-- ----------------------------------------------------------------------------

drop function if exists public.get_business_settings();

create or replace function public.get_business_settings()
returns table(
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
  slug text,
  tiktok text
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
    t.slug,
    t.tiktok
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
  'dirección se lee con get_branch_info, por sede. Devuelve también el TikTok (D-319).';

-- ----------------------------------------------------------------------------
-- 4. La página pública lo enseña: copia de la viva + tiktok al final
-- ----------------------------------------------------------------------------

drop function if exists public.get_public_salon_by_slug(text);

create or replace function public.get_public_salon_by_slug(p_slug text)
returns table(
  tenant_id uuid,
  name text,
  slug text,
  business_type text,
  logo_url text,
  cover_photo_url text,
  theme_key text,
  brand_color text,
  city text,
  address text,
  whatsapp text,
  contact_phone text,
  instagram text,
  facebook text,
  primary_branch_id uuid,
  business_hours jsonb,
  tiktok text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_slug text := lower(trim(coalesce(p_slug, '')));
begin
  if v_slug = '' then
    return;
  end if;

  return query
  select
    t.id,
    t.name,
    t.slug,
    t.business_type,
    t.logo_url,
    t.cover_photo_url,
    t.theme_key,
    t.brand_color,
    t.city,
    b.address,
    t.whatsapp,
    t.contact_phone,
    t.instagram,
    t.facebook,
    b.id,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'day_of_week', bh.day_of_week,
            'opens_at', bh.opens_at,
            'closes_at', bh.closes_at,
            'is_open', bh.is_open
          )
          order by bh.day_of_week
        )
        from public.business_hours bh
        where bh.tenant_id = t.id
          and bh.branch_id = b.id
      ),
      '[]'::jsonb
    ),
    t.tiktok
  from public.tenants t
  left join public.branches b
    on b.tenant_id = t.id
   and b.is_primary = true
   and b.active = true
  where t.slug = v_slug
    and t.active = true;
end;
$$;

revoke all on function public.get_public_salon_by_slug(text) from public;
grant execute on function public.get_public_salon_by_slug(text) to anon, authenticated;

comment on function public.get_public_salon_by_slug(text) is
  'Perfil comercial público de un negocio por su slug, sin sesión (D-098, D-164, '
  'D-165). Solo datos de vitrina, nunca correo ni información operativa. '
  'Devuelve también el TikTok (D-319).';

commit;
