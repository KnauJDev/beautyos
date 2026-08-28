-- ============================================================================
-- MIGRACIÓN: 20260828180000_direccion_sede_y_ajustes_reserva.sql
-- DESCRIPCIÓN: D-166. El salón puede editar la dirección física de su sede
--              principal desde Configuración (para que "Ver en Google Maps"
--              de la página pública, D-165, tenga algo que mostrar) y esa
--              dirección viaja de vuelta a la pantalla de edición.
--
--              El resto del bloque D-166 (dropdown de servicio/profesional
--              en dos pasos, "Cualquiera disponible", botones de la
--              pantalla de éxito) es solo Flutter: no toca RPC ni tablas,
--              usa datos que ya viajaban (`public_get_bookable_services`,
--              `PublicBookingResult`, `PublicBranchInfo`).
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- 1. update_tenant_contact_info: gana `p_address` (parámetro nuevo con
--    default al final -- no cambia el orden ni el tipo de los que ya
--    existían, así que no hace falta `drop function`). Actualiza la
--    dirección de la sede PRINCIPAL activa del tenant, igual que
--    `get_public_salon_by_slug` (D-164) la lee de ahí.
-- ----------------------------------------------------------------------------

create or replace function public.update_tenant_contact_info(
  p_full_name text,
  p_business_type text,
  p_contact_phone text,
  p_whatsapp text,
  p_instagram text,
  p_facebook text,
  p_address text default null
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

  update public.branches
  set address = nullif(trim(coalesce(p_address, '')), '')
  where tenant_id = v_tenant_id
    and is_primary = true
    and active = true;
end;
$$;

revoke execute on function public.update_tenant_contact_info(text, text, text, text, text, text, text) from anon;
revoke execute on function public.update_tenant_contact_info(text, text, text, text, text, text, text) from public;
grant execute on function public.update_tenant_contact_info(text, text, text, text, text, text, text) to authenticated;

comment on function public.update_tenant_contact_info(text, text, text, text, text, text, text)
  is 'Autoservicio: el owner o admin del propio negocio actualiza nombre del titular, tipo de negocio, teléfono, WhatsApp, Instagram, Facebook y la dirección de la sede principal (D-161, D-166).';

-- ----------------------------------------------------------------------------
-- 2. get_business_settings: gana `address` (de la sede principal activa),
--    para que la pantalla de Configuración pueda precargar el campo nuevo.
--    Cambia la tabla de retorno -- `drop function` primero, mismo motivo
--    que D-162/D-164/D-165 con otras funciones.
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
  slug text,
  address text
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
    b.address
  from public.tenants t
  left join public.user_profiles up
    on up.tenant_id = t.id
   and up.role = 'owner'
   and up.active = true
  left join public.branches b
    on b.tenant_id = t.id
   and b.is_primary = true
   and b.active = true
  where t.id = current_tenant_id
    and t.active = true
  limit 1;
end;
$$;

revoke execute on function public.get_business_settings() from anon;
revoke execute on function public.get_business_settings() from public;
grant execute on function public.get_business_settings() to authenticated;

commit;
