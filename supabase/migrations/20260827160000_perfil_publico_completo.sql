-- ============================================================================
-- MIGRACIÓN: 20260827160000_perfil_publico_completo.sql
-- DESCRIPCIÓN: Fase 5, paso 5.5 (D-165). La página pública del negocio deja
--              de ser solo el encabezado de D-164 y gana servicios,
--              portafolio, equipo, reseñas, horarios y el botón de reserva:
--              `get_public_salon_by_slug` gana `primary_branch_id` (lo
--              necesita el botón "Agendar Cita") y `business_hours`; se
--              agregan cuatro RPC públicas nuevas, todas sin sesión, todas
--              filtradas por tenant activo.
--
--              Dos campos que pedía el encargo no existen en el esquema real
--              (verificado en el código antes de escribir la función, regla
--              8.1 del Plan Maestro): `stylists.color_code` y
--              `services.description`. Se sustituyen por columnas reales
--              con el mismo propósito -- `stylists.photo_url`/`bio` (D-084,
--              ya pensadas para verse en público) y `services.category` --
--              en vez de inventar columnas nuevas para esto.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- 1. get_public_salon_by_slug: gana `primary_branch_id` (botón "Agendar
--    Cita") y `business_hours` (sección "Horarios y Ubicación"). Cambia la
--    tabla de retorno -- `drop function` primero, mismo motivo que D-162 y
--    D-164 con otras funciones: `create or replace` no admite cambiar la
--    forma de lo que devuelve.
-- ----------------------------------------------------------------------------

drop function if exists public.get_public_salon_by_slug(text);

create or replace function public.get_public_salon_by_slug(p_slug text)
returns table (
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
  business_hours jsonb
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
    )
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
  'Perfil comercial público de un negocio por su slug, sin sesión (D-098, D-164, D-165). Solo datos de vitrina, nunca correo ni información operativa.';

-- ----------------------------------------------------------------------------
-- 2. get_public_salon_services: catálogo público, a nivel de tenant (no de
--    sede -- la Fase 5 sigue siendo un perfil por negocio, no por sede,
--    igual que D-164). `description` no existe en `services`: se devuelve
--    `category` con ese nombre de columna porque cumple el mismo papel
--    (una línea de contexto bajo el nombre del servicio) y sí es un dato
--    real.
-- ----------------------------------------------------------------------------

create or replace function public.get_public_salon_services(p_tenant_id uuid)
returns table (
  id uuid,
  name text,
  description text,
  duration_minutes integer,
  price_cop numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  select
    s.id,
    s.name,
    s.category,
    s.duration_minutes,
    s.price
  from public.services s
  join public.tenants t
    on t.id = s.tenant_id
   and t.active = true
  where s.tenant_id = p_tenant_id
    and s.active = true
    and s.visible_to_customer = true
  order by s.name;
end;
$$;

revoke all on function public.get_public_salon_services(uuid) from public;
grant execute on function public.get_public_salon_services(uuid) to anon, authenticated;

comment on function public.get_public_salon_services(uuid) is
  'Catálogo público de servicios activos y visibles de un negocio, sin sesión (D-165). "description" viaja como category: services no tiene descripción propia.';

-- ----------------------------------------------------------------------------
-- 3. get_public_salon_portfolio: solo fotos aprobadas para vitrina Y
--    visibles al cliente -- las dos banderas son intencionalmente
--    independientes desde D-119 (una foto puede estar aprobada para el
--    perfil del ticket del cliente pero no para el portafolio público, o
--    viceversa).
-- ----------------------------------------------------------------------------

create or replace function public.get_public_salon_portfolio(p_tenant_id uuid)
returns table (
  id uuid,
  photo_url text,
  photo_type text,
  caption text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  select
    wp.id,
    wp.photo_url,
    wp.photo_type,
    wp.caption,
    wp.created_at
  from public.work_photos wp
  join public.tenants t
    on t.id = wp.tenant_id
   and t.active = true
  where wp.tenant_id = p_tenant_id
    and wp.approved_for_portfolio = true
    and wp.visible_to_customer = true
  order by wp.created_at desc
  limit 24;
end;
$$;

revoke all on function public.get_public_salon_portfolio(uuid) from public;
grant execute on function public.get_public_salon_portfolio(uuid) to anon, authenticated;

comment on function public.get_public_salon_portfolio(uuid) is
  'Últimas 24 fotos de trabajo aprobadas para portafolio público, sin sesión (D-165).';

-- ----------------------------------------------------------------------------
-- 4. get_public_salon_team: estilistas activos. `color_code` no existe en
--    `stylists`: se devuelven `photo_url` y `bio` (D-084), pensadas desde
--    su creación para verse en superficies públicas.
-- ----------------------------------------------------------------------------

create or replace function public.get_public_salon_team(p_tenant_id uuid)
returns table (
  id uuid,
  name text,
  photo_url text,
  bio text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  select
    st.id,
    st.name,
    st.photo_url,
    st.bio
  from public.stylists st
  join public.tenants t
    on t.id = st.tenant_id
   and t.active = true
  where st.tenant_id = p_tenant_id
    and st.active = true
  order by st.name;
end;
$$;

revoke all on function public.get_public_salon_team(uuid) from public;
grant execute on function public.get_public_salon_team(uuid) to anon, authenticated;

comment on function public.get_public_salon_team(uuid) is
  'Equipo activo de un negocio para su página pública, sin sesión (D-165). "color_code" no existe en stylists: viajan photo_url y bio (D-084) en su lugar.';

-- ----------------------------------------------------------------------------
-- 5. get_public_salon_reviews: promedio y total repetidos en cada fila
--    (calculados aparte, sin el límite de la lista) junto a las últimas 10
--    reseñas públicas. Si el negocio no tiene reseñas visibles, la RPC
--    devuelve cero filas -- Flutter interpreta "sin filas" como
--    promedio 0 / total 0, no hace falta una segunda función solo para el
--    resumen.
-- ----------------------------------------------------------------------------

create or replace function public.get_public_salon_reviews(p_tenant_id uuid)
returns table (
  avg_rating numeric,
  total_reviews integer,
  client_name text,
  rating integer,
  comment text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_avg numeric;
  v_total integer;
begin
  select coalesce(avg(r.rating), 0)::numeric(3, 2), count(*)::integer
    into v_avg, v_total
  from public.reviews r
  join public.tenants t
    on t.id = r.tenant_id
   and t.active = true
  where r.tenant_id = p_tenant_id
    and r.visible_to_public = true
    and r.active = true;

  return query
  select
    v_avg,
    v_total,
    c.name,
    r.rating,
    r.comment,
    r.created_at
  from public.reviews r
  join public.clients c
    on c.tenant_id = r.tenant_id
   and c.id = r.client_id
  where r.tenant_id = p_tenant_id
    and r.visible_to_public = true
    and r.active = true
  order by r.created_at desc
  limit 10;
end;
$$;

revoke all on function public.get_public_salon_reviews(uuid) from public;
grant execute on function public.get_public_salon_reviews(uuid) to anon, authenticated;

comment on function public.get_public_salon_reviews(uuid) is
  'Promedio, total y últimas 10 reseñas públicas de un negocio, sin sesión (D-165). Cero filas si no hay reseñas visibles: el promedio/total van repetidos en cada fila que sí llega.';

commit;
