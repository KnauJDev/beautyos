-- ============================================================================
-- MIGRACIÓN: 20260926130000_que_ella_autorice_9_48.sql
-- Paso 9.48 del Plan Maestro, Bloque 1 (servidor). Cierra la mitad de base de
-- datos de los hallazgos AQ y AU, y prepara el terreno para Ñ.
--
-- QUÉ CAMBIA: hoy quien sube la foto marca la casilla de `client_consent` en
-- nombre de la clienta (AQ), y la reseña se publica con su nombre real sin
-- pedírselo. Esta migración no toca esas dos escrituras -- las deja donde
-- están, protegidas por lo que ya existía -- sino que agrega el camino para
-- que sea ELLA quien decida, desde el portal (D-167) o desde un enlace
-- directo nuevo, sin sesión de Supabase Auth. El botón que genera y manda
-- ese enlace, y las pantallas que consumen esto, van en bloques aparte.
--
-- DOS CAMINOS PARA IDENTIFICARLA, UNA SOLA RESOLUCIÓN:
--   - El token de sesión del portal (`clients.portal_session_token`, D-167),
--     que ya existe y expira a los 60 días.
--   - Un token nuevo, `clients.consent_link_token`: a diferencia del de
--     sesión, este NO expira -- es un enlace que el salón puede reenviar por
--     WhatsApp cada vez que haya algo nuevo, sin que la clienta tenga que
--     volver a autenticarse con su PIN (decisión del propietario, 26-sep).
--   Un solo helper privado resuelve cualquiera de los dos a la misma fila de
--   `clients`, para no repetir la lógica de resolución en cada función
--   pública nueva.
--
-- POR QUÉ "PENDIENTE" NO ES "NUNCA SE LE PREGUNTÓ": se agrega
-- `client_consent_decided_at` (fotos) y `client_name_consent_decided_at`
-- (reseñas). Sin esto, una foto que ella rechazó (consent = false, que ya
-- era el valor por defecto) sería indistinguible de una que todavía no ha
-- visto, y volvería a aparecer como pendiente para siempre.
--
-- LA FOTO PRIVADA: para decidir, ella tiene que VER la foto, y una foto
-- recién subida vive en `work-photos-private` sin dirección pública
-- permanente -- el mismo hueco que `get_client_portal_data` (D-167) dejó
-- escrito a propósito: "generar URLs firmadas... es infraestructura nueva...
-- se deja fuera y se documenta, no se inventa a medias". Esta migración
-- agrega la función que AUTORIZA leer la ruta de una foto puntual con su
-- token; la Edge Function `client-consent-photo-url` (en el mismo bloque)
-- es la que de verdad firma la URL, porque eso requiere hablar con Storage
-- con `service_role`, que SQL no puede hacer.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- 1. `clients`: el enlace directo, permanente y reutilizable.
-- ----------------------------------------------------------------------------

alter table public.clients
  add column if not exists consent_link_token text;

-- Índice único parcial, no un `add constraint unique`: es el mismo patrón
-- que ya usa `clients_tenant_phone_uidx` (D-249) porque SÍ admite
-- `if not exists`, y una migración de este proyecto tiene que poder
-- releerse sin reventar si alguna vez se corre dos veces.
create unique index if not exists clients_consent_link_token_uidx
  on public.clients (consent_link_token)
  where consent_link_token is not null;

comment on column public.clients.consent_link_token is
  'Token opaco y permanente para el enlace directo de autorización (paso 9.48). A diferencia de portal_session_token, no expira: el salón lo reenvía por WhatsApp cada vez que haya algo nuevo por aprobar. Null hasta que el salón lo pide la primera vez.';

-- ----------------------------------------------------------------------------
-- 2. `work_photos`: distinguir "nunca se le preguntó" de "dijo que no".
-- ----------------------------------------------------------------------------

alter table public.work_photos
  add column if not exists client_consent_decided_at timestamptz;

comment on column public.work_photos.client_consent_decided_at is
  'Momento en que ELLA respondió (sí o no) desde el portal o el enlace directo (paso 9.48). Null significa que todavía está pendiente de preguntarle -- distinto de client_consent = false, que también es el valor por defecto antes de preguntar.';

-- ----------------------------------------------------------------------------
-- 3. `reviews`: el nombre es un consentimiento aparte del comentario.
--    Decisión del propietario, 26-sep: mientras no autorice, se publica el
--    comentario y la calificación igual que hoy -- lo único que cambia es
--    que el nombre real no sale hasta que ella lo autorice.
-- ----------------------------------------------------------------------------

alter table public.reviews
  add column if not exists client_name_consent boolean not null default false,
  add column if not exists client_name_consent_decided_at timestamptz;

comment on column public.reviews.client_name_consent is
  'La clienta autorizó mostrar su nombre real junto a su reseña (paso 9.48). Sin esto, la reseña se sigue publicando -- solo el nombre se sustituye por una etiqueta genérica.';
comment on column public.reviews.client_name_consent_decided_at is
  'Momento en que ELLA respondió sobre su nombre. Null significa pendiente de preguntarle.';

-- ----------------------------------------------------------------------------
-- 4. Helper privado: resuelve la clienta desde cualquiera de los dos tokens.
--    No es una RPC pública -- PostgREST solo expone `public`, así que esto
--    solo lo pueden llamar otras funciones de este archivo.
-- ----------------------------------------------------------------------------

create or replace function private.beautyos_resolve_consent_client(
  p_portal_token text,
  p_consent_token text
)
returns public.clients
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_client public.clients%rowtype;
begin
  if coalesce(btrim(p_portal_token), '') <> '' then
    select * into v_client
    from public.clients c
    where c.portal_session_token = p_portal_token
      and c.portal_session_expires_at is not null
      and c.portal_session_expires_at > now()
      and c.active;

    if found then
      return v_client;
    end if;

    raise exception 'Tu sesión expiró. Vuelve a ingresar con tu celular y tu PIN.';
  end if;

  if coalesce(btrim(p_consent_token), '') <> '' then
    select * into v_client
    from public.clients c
    where c.consent_link_token = p_consent_token
      and c.active;

    if found then
      return v_client;
    end if;

    raise exception 'Este enlace no es válido.';
  end if;

  raise exception 'Falta el token de acceso.';
end;
$$;

-- ----------------------------------------------------------------------------
-- 5. get_or_create_client_consent_link: la usa el salón (owner/admin) para
--    conseguir el enlace que le va a mandar por WhatsApp. Lo crea la
--    primera vez que se pide; después siempre devuelve el mismo.
-- ----------------------------------------------------------------------------

create or replace function public.get_or_create_client_consent_link(
  p_client_id uuid
)
returns text
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid := public.get_my_tenant_id();
  v_token text;
begin
  if v_tenant_id is null then
    raise exception 'No existe un perfil activo asociado al usuario actual.';
  end if;

  if not public.is_owner_or_admin() then
    raise exception 'No autorizado. Solo owner o admin puede generar este enlace.';
  end if;

  select consent_link_token into v_token
  from public.clients
  where id = p_client_id
    and tenant_id = v_tenant_id;

  if not found then
    raise exception 'El cliente no existe o no pertenece a este negocio.';
  end if;

  if v_token is not null then
    return v_token;
  end if;

  -- Reintento simple ante una colisión de la lotería (gen_random_uuid tiene
  -- 122 bits al azar; esto es una red, no una expectativa real).
  loop
    v_token := replace(gen_random_uuid()::text, '-', '');
    begin
      update public.clients
      set consent_link_token = v_token
      where id = p_client_id
        and tenant_id = v_tenant_id;
      exit;
    exception when unique_violation then
      continue;
    end;
  end loop;

  return v_token;
end;
$$;

revoke all on function public.get_or_create_client_consent_link(uuid)
  from public, anon;
grant execute on function public.get_or_create_client_consent_link(uuid)
  to authenticated;

comment on function public.get_or_create_client_consent_link(uuid) is
  'Devuelve el enlace directo y permanente de autorización de una clienta (paso 9.48), creándolo si es la primera vez. Exclusivo owner/admin del tenant.';

-- ----------------------------------------------------------------------------
-- 6. client_consent_get_pending: lo que a ELLA le falta autorizar. Sin
--    sesión de Supabase Auth -- se identifica con el token, igual que el
--    resto del portal (D-167).
-- ----------------------------------------------------------------------------

create or replace function public.client_consent_get_pending(
  p_portal_token text default null,
  p_consent_token text default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_client public.clients%rowtype;
begin
  v_client := private.beautyos_resolve_consent_client(p_portal_token, p_consent_token);

  return jsonb_build_object(
    'client_name', v_client.name,
    'pending_photos', (
      select coalesce(jsonb_agg(
        jsonb_build_object(
          'id', wp.id,
          'photo_type', wp.photo_type,
          'caption', wp.caption,
          'created_at', wp.created_at
        )
        order by wp.created_at desc
      ), '[]'::jsonb)
      from public.work_photos wp
      where wp.tenant_id = v_client.tenant_id
        and wp.client_id = v_client.id
        and wp.active
        and wp.client_consent_decided_at is null
    ),
    'pending_reviews', (
      select coalesce(jsonb_agg(
        jsonb_build_object(
          'id', r.id,
          'rating', r.rating,
          'comment', r.comment,
          'created_at', r.created_at
        )
        order by r.created_at desc
      ), '[]'::jsonb)
      from public.reviews r
      where r.tenant_id = v_client.tenant_id
        and r.client_id = v_client.id
        and r.active
        and r.client_name_consent_decided_at is null
    )
  );
end;
$$;

revoke all on function public.client_consent_get_pending(text, text)
  from public;
grant execute on function public.client_consent_get_pending(text, text)
  to anon, authenticated;

comment on function public.client_consent_get_pending(text, text) is
  'Fotos y reseñas que la clienta todavía no ha autorizado (paso 9.48). No trae la URL de la foto -- eso lo resuelve client_consent_get_photo_path + la Edge Function que firma la ruta, porque la foto pendiente vive en el almacén privado.';

-- ----------------------------------------------------------------------------
-- 7. client_consent_get_photo_path: la mitad SQL de ver la foto privada. La
--    Edge Function `client-consent-photo-url` llama a esto primero (con la
--    clave pública, sin privilegio ninguno) para que toda la autorización
--    viva en un solo sitio, y solo después firma la ruta con `service_role`.
-- ----------------------------------------------------------------------------

create or replace function public.client_consent_get_photo_path(
  p_photo_id uuid,
  p_portal_token text default null,
  p_consent_token text default null
)
returns text
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_client public.clients%rowtype;
  v_path text;
  v_bucket text;
begin
  v_client := private.beautyos_resolve_consent_client(p_portal_token, p_consent_token);

  select wp.storage_path, wp.storage_bucket
    into v_path, v_bucket
  from public.work_photos wp
  where wp.id = p_photo_id
    and wp.tenant_id = v_client.tenant_id
    and wp.client_id = v_client.id
    and wp.active;

  if not found then
    raise exception 'Esta foto no existe o no es tuya.';
  end if;

  if v_bucket <> 'work-photos-private' then
    raise exception 'Esta foto no está en el almacén privado.';
  end if;

  return v_path;
end;
$$;

revoke all on function public.client_consent_get_photo_path(uuid, text, text)
  from public;
grant execute on function public.client_consent_get_photo_path(uuid, text, text)
  to anon, authenticated;

comment on function public.client_consent_get_photo_path(uuid, text, text) is
  'Autoriza y devuelve la ruta de una foto privada suya, para que la Edge Function client-consent-photo-url la firme (paso 9.48). No devuelve nada de una foto que no sea de esta clienta.';

-- ----------------------------------------------------------------------------
-- 8. client_consent_set_photo: ella decide, de verdad.
-- ----------------------------------------------------------------------------

create or replace function public.client_consent_set_photo(
  p_photo_id uuid,
  p_authorized boolean,
  p_portal_token text default null,
  p_consent_token text default null
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_client public.clients%rowtype;
begin
  v_client := private.beautyos_resolve_consent_client(p_portal_token, p_consent_token);

  update public.work_photos
  set client_consent = coalesce(p_authorized, false),
      client_consent_at = case when coalesce(p_authorized, false) then now() else null end,
      client_consent_decided_at = now()
  where id = p_photo_id
    and tenant_id = v_client.tenant_id
    and client_id = v_client.id
    and active;

  if not found then
    raise exception 'Esta foto no existe o no es tuya.';
  end if;
end;
$$;

revoke all on function public.client_consent_set_photo(uuid, boolean, text, text)
  from public;
grant execute on function public.client_consent_set_photo(uuid, boolean, text, text)
  to anon, authenticated;

comment on function public.client_consent_set_photo(uuid, boolean, text, text) is
  'La clienta autoriza o rechaza publicar una foto suya (paso 9.48, cierra AQ). Reemplaza la casilla que hoy marca quien sube la foto: esta es la única escritura que de verdad representa su decisión.';

-- ----------------------------------------------------------------------------
-- 9. client_consent_set_review_name: igual, para el nombre de su reseña.
-- ----------------------------------------------------------------------------

create or replace function public.client_consent_set_review_name(
  p_review_id uuid,
  p_authorized boolean,
  p_portal_token text default null,
  p_consent_token text default null
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_client public.clients%rowtype;
begin
  v_client := private.beautyos_resolve_consent_client(p_portal_token, p_consent_token);

  update public.reviews
  set client_name_consent = coalesce(p_authorized, false),
      client_name_consent_decided_at = now()
  where id = p_review_id
    and tenant_id = v_client.tenant_id
    and client_id = v_client.id
    and active;

  if not found then
    raise exception 'Esta reseña no existe o no es tuya.';
  end if;
end;
$$;

revoke all on function public.client_consent_set_review_name(uuid, boolean, text, text)
  from public;
grant execute on function public.client_consent_set_review_name(uuid, boolean, text, text)
  to anon, authenticated;

comment on function public.client_consent_set_review_name(uuid, boolean, text, text) is
  'La clienta autoriza o rechaza mostrar su nombre real junto a su reseña (paso 9.48). El comentario y la calificación se publican igual en los dos casos -- decisión del propietario, 26-sep.';

-- ----------------------------------------------------------------------------
-- 10. get_public_salon_reviews: sin nombre autorizado, sale una etiqueta
--     genérica. Misma firma, mismas columnas -- create or replace basta.
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
    case when r.client_name_consent then c.name else 'Clienta verificada' end,
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
  'Promedio, total y últimas 10 reseñas públicas de un negocio, sin sesión (D-165). Desde el paso 9.48, el nombre real solo sale si la clienta lo autorizó (client_name_consent) -- si no, "Clienta verificada".';

-- ----------------------------------------------------------------------------
-- 11. get_publication_studio_data: la pieza de Instagram respeta lo mismo.
--     Misma firma (uuid, uuid) -- create or replace basta.
-- ----------------------------------------------------------------------------

create or replace function public.get_publication_studio_data(
  p_branch_id uuid,
  p_photo_id uuid
)
returns table (
  photo_url text,
  service_names text,
  review_rating integer,
  review_comment text,
  review_client_name text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_access record;
  v_ticket_id uuid;
  v_photo_url text;
  v_approved boolean;
  v_consent boolean;
  v_service_names text;
  v_review_rating integer;
  v_review_comment text;
  v_review_client_name text;
  v_review_name_consent boolean;
begin
  select * into strict v_access
  from private.beautyos_resolve_branch_access(
    p_branch_id,
    array['tenant_owner', 'admin']::text[],
    true
  );

  select wp.ticket_id, wp.photo_url, wp.approved_for_portfolio, wp.client_consent
    into v_ticket_id, v_photo_url, v_approved, v_consent
  from public.work_photos wp
  where wp.id = p_photo_id
    and wp.tenant_id = v_access.tenant_id
    and wp.branch_id = v_access.branch_id
    and wp.active;

  if not found then
    raise exception 'Esta foto no existe o no pertenece a esta sede.';
  end if;

  -- Misma condicion que ya exige el portafolio publico (D-167): una foto
  -- que no puede salir al portafolio tampoco puede usarse en una pieza de
  -- marketing armada a partir de ella.
  if not coalesce(v_approved, false) or not coalesce(v_consent, false) then
    raise exception 'Esta foto no esta aprobada para portafolio o no tiene consentimiento de la clienta -- no se puede usar en una publicacion.';
  end if;

  select string_agg(s.name, ', ' order by s.name)
    into v_service_names
  from public.ticket_services ts
  join public.services s
    on s.id = ts.service_id
  where ts.ticket_id = v_ticket_id
    and ts.tenant_id = v_access.tenant_id
    and ts.status <> 'cancelado';

  -- Solo una reseña con buena calificación tiene sentido en una pieza de
  -- marketing -- una de 1-3 estrellas no se ofrece, aunque exista.
  select r.rating, r.comment, c.name, r.client_name_consent
    into v_review_rating, v_review_comment, v_review_client_name, v_review_name_consent
  from public.reviews r
  join public.clients c
    on c.tenant_id = r.tenant_id
   and c.id = r.client_id
  where r.ticket_id = v_ticket_id
    and r.tenant_id = v_access.tenant_id
    and r.active = true
    and r.visible_to_public = true
    and r.rating >= 4
  order by r.created_at desc
  limit 1;

  -- Paso 9.48: el comentario se puede seguir usando en la pieza; el nombre
  -- solo si ella lo autorizó. Mismo criterio que get_public_salon_reviews.
  if not coalesce(v_review_name_consent, false) then
    v_review_client_name := null;
  end if;

  return query
  select
    v_photo_url,
    v_service_names,
    v_review_rating,
    v_review_comment,
    v_review_client_name;
end;
$$;

revoke all on function public.get_publication_studio_data(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.get_publication_studio_data(uuid, uuid)
  to authenticated;

comment on function public.get_publication_studio_data(uuid, uuid) is
  'Datos para componer la tarjeta del Estudio de publicacion (paso 6.2, D-169): exige que la foto ya este aprobada para portafolio y con consentimiento de la clienta. Desde el paso 9.48, el nombre de la reseña solo viaja si ella autorizó mostrarlo.';

commit;
