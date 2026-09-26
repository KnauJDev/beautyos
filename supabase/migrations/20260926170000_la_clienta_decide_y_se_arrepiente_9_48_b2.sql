-- ============================================================================
-- MIGRACIÓN: 20260926170000_la_clienta_decide_y_se_arrepiente_9_48_b2.sql
-- Paso 9.48, Bloque 2 (D-282). Sobre el Bloque 1 (D-281), ya aplicado.
--
-- CUATRO DECISIONES DEL PROPIETARIO (26-sep), que esta migración cumple:
--   1. La clienta PUEDE ARREPENTIRSE (Ley 1581: revocar la autorización).
--      Retirar una foto ya publicada exige sacarla de internet PRIMERO, y
--      eso es mover el archivo de almacén, que SQL no puede hacer: lo hace
--      la Edge Function `client-consent-revoke-photo`. Por eso aquí
--      `client_consent_set_photo` SE NIEGA a retirar una foto publicada, y
--      la única escritura que la retira (`client_consent_finish_revoke`) la
--      puede llamar solo `service_role` -- nadie más puede dejar la base
--      diciendo "privada" con el archivo todavía en el almacén público.
--   2. La reseña puede aparecer de tres formas: "Clienta verificada", su
--      nombre real, o UN NOMBRE QUE ELLA ESCRIBE (`client_display_name`).
--   3. Ese nombre escrito por ella VUELVE A MODERACIÓN: la reseña pasa a
--      `pending` y sale de la página, que es el estado en que nace y el que
--      el salón ya sabe aprobar con `moderate_review`. Nada nuevo que
--      aprender del lado del salón.
--   4. El salón tiene que VER lo que modera: `get_reviews_summary_v2` gana
--      `public_name`, el nombre con el que la reseña sale en público.
--
-- TODO SE GENERÓ DESDE EL TEXTO VIVO (extraer_resenas_del_salon_9_48_b2,
-- 26-sep), no desde el repositorio -- la primera migración del 9.48 falló
-- justo por eso (D-281).
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- 1. El nombre que ella escribe. Mismos topes que la pantalla: 2 a 40.
-- ----------------------------------------------------------------------------

alter table public.reviews
  add column if not exists client_display_name text
    constraint reviews_client_display_name_len
    check (client_display_name is null
           or char_length(client_display_name) between 2 and 40);

comment on column public.reviews.client_display_name is
  'Nombre con el que la clienta eligió aparecer en su reseña (paso 9.48). Solo cuenta si client_name_consent = true; si es null, sale su nombre real. Escribirlo devuelve la reseña a moderación (D-282).';

-- ----------------------------------------------------------------------------
-- 2. client_consent_get_pending: además de lo pendiente, lo que YA respondió
--    (para poder cambiarlo) y los datos del salón (para la pantalla del
--    enlace directo, que no sabe de qué negocio viene). Mismo nombre y mismo
--    tipo de retorno (jsonb) -- create or replace basta.
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
  v_business_name text;
  v_business_whatsapp text;
begin
  v_client := private.beautyos_resolve_consent_client(p_portal_token, p_consent_token);

  select t.name, t.whatsapp
    into v_business_name, v_business_whatsapp
  from public.tenants t
  where t.id = v_client.tenant_id;

  return jsonb_build_object(
    'client_name', v_client.name,
    'business_name', v_business_name,
    'business_whatsapp', v_business_whatsapp,
    'pending_photos', (
      select coalesce(jsonb_agg(
        jsonb_build_object(
          'id', wp.id,
          'photo_type', wp.photo_type,
          'caption', wp.caption,
          'created_at', wp.created_at,
          'is_published', wp.approved_for_portfolio,
          'photo_url', wp.photo_url
        )
        order by wp.created_at desc
      ), '[]'::jsonb)
      from public.work_photos wp
      where wp.tenant_id = v_client.tenant_id
        and wp.client_id = v_client.id
        and wp.active
        and wp.client_consent_decided_at is null
    ),
    'answered_photos', (
      select coalesce(jsonb_agg(
        jsonb_build_object(
          'id', wp.id,
          'photo_type', wp.photo_type,
          'caption', wp.caption,
          'created_at', wp.created_at,
          'authorized', wp.client_consent,
          'is_published', wp.approved_for_portfolio,
          'photo_url', wp.photo_url
        )
        order by wp.client_consent_decided_at desc
      ), '[]'::jsonb)
      from public.work_photos wp
      where wp.tenant_id = v_client.tenant_id
        and wp.client_id = v_client.id
        and wp.active
        and wp.client_consent_decided_at is not null
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
    ),
    'answered_reviews', (
      select coalesce(jsonb_agg(
        jsonb_build_object(
          'id', r.id,
          'rating', r.rating,
          'comment', r.comment,
          'created_at', r.created_at,
          'name_consent', r.client_name_consent,
          'display_name', r.client_display_name,
          'moderation_status', r.moderation_status
        )
        order by r.client_name_consent_decided_at desc
      ), '[]'::jsonb)
      from public.reviews r
      where r.tenant_id = v_client.tenant_id
        and r.client_id = v_client.id
        and r.active
        and r.client_name_consent_decided_at is not null
    )
  );
end;
$$;

comment on function public.client_consent_get_pending(text, text) is
  'Lo que la clienta tiene pendiente de autorizar Y lo que ya respondió (para poder cambiarlo), más el nombre y WhatsApp del salón (pasos 9.48, D-281 y D-282). No trae URL firmada de las fotos privadas: eso lo hace client-consent-photo-url.';

-- ----------------------------------------------------------------------------
-- 3. client_consent_set_photo: ya no puede retirar una foto PUBLICADA.
--    Contra el texto vivo cambia solo el bloque del `if` nuevo: el `update`
--    es el mismo, línea por línea.
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
  v_published boolean;
begin
  v_client := private.beautyos_resolve_consent_client(p_portal_token, p_consent_token);

  select wp.approved_for_portfolio into v_published
  from public.work_photos wp
  where wp.id = p_photo_id
    and wp.tenant_id = v_client.tenant_id
    and wp.client_id = v_client.id
    and wp.active;

  if not found then
    raise exception 'Esta foto no existe o no es tuya.';
  end if;

  -- D-282: una foto publicada no se "desautoriza" con un update -- el
  -- archivo seguiría en internet con la base diciendo lo contrario. Se
  -- retira por la Edge Function client-consent-revoke-photo, que primero
  -- la saca del almacén público y después lo anota.
  if not coalesce(p_authorized, false) and coalesce(v_published, false) then
    raise exception 'Esta foto ya está publicada: para retirarla hay que sacarla de internet primero.';
  end if;

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

comment on function public.client_consent_set_photo(uuid, boolean, text, text) is
  'La clienta autoriza o rechaza publicar una foto suya (paso 9.48, cierra AQ). Desde D-282 se niega a retirar una foto ya publicada: eso va por la Edge Function client-consent-revoke-photo, que la saca de internet primero.';

-- ----------------------------------------------------------------------------
-- 4. Retirar una foto publicada, en dos piezas.
--
--    client_consent_get_published_photo_path: la autorización, entera en
--    SQL. La llama la Edge Function con la clave PÚBLICA. Devuelve la ruta
--    de una foto que ya es pública -- no revela nada que no esté en
--    internet.
-- ----------------------------------------------------------------------------

create or replace function public.client_consent_get_published_photo_path(
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
  v_published boolean;
begin
  v_client := private.beautyos_resolve_consent_client(p_portal_token, p_consent_token);

  select wp.storage_path, wp.storage_bucket, wp.approved_for_portfolio
    into v_path, v_bucket, v_published
  from public.work_photos wp
  where wp.id = p_photo_id
    and wp.tenant_id = v_client.tenant_id
    and wp.client_id = v_client.id
    and wp.active;

  if not found then
    raise exception 'Esta foto no existe o no es tuya.';
  end if;

  if not coalesce(v_published, false) or v_bucket <> 'work-photos' or v_path is null then
    raise exception 'Esta foto no está publicada.';
  end if;

  return v_path;
end;
$$;

revoke all on function public.client_consent_get_published_photo_path(uuid, text, text)
  from public;
grant execute on function public.client_consent_get_published_photo_path(uuid, text, text)
  to anon, authenticated;

comment on function public.client_consent_get_published_photo_path(uuid, text, text) is
  'Autoriza retirar una foto publicada de la clienta y devuelve su ruta en el almacén público (D-282). La llama client-consent-revoke-photo ANTES de mover el archivo.';

-- ----------------------------------------------------------------------------
--    client_consent_finish_revoke: lo anota, DESPUÉS de que el archivo ya
--    salió del almacén público. SOLO service_role: si la pudiera llamar
--    cualquiera, bastaría llamarla sin mover el archivo para dejar la foto
--    en internet con la base diciendo que es privada. Vuelve a resolver a
--    la clienta con su token -- no se fía de quien la llama.
--    Las columnas que toca son las mismas que set_work_photo_portfolio_
--    approval(false) (D-167), más las del consentimiento.
-- ----------------------------------------------------------------------------

create or replace function public.client_consent_finish_revoke(
  p_photo_id uuid,
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
  set approved_for_portfolio = false,
      storage_bucket = 'work-photos-private',
      photo_url = null,
      client_consent = false,
      client_consent_at = null,
      client_consent_decided_at = now(),
      updated_at = now()
  where id = p_photo_id
    and tenant_id = v_client.tenant_id
    and client_id = v_client.id
    and active;

  if not found then
    raise exception 'Esta foto no existe o no es tuya.';
  end if;
end;
$$;

revoke all on function public.client_consent_finish_revoke(uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.client_consent_finish_revoke(uuid, text, text)
  to service_role;

comment on function public.client_consent_finish_revoke(uuid, text, text) is
  'Anota que la clienta retiró una foto publicada, DESPUÉS de que client-consent-revoke-photo la sacó del almacén público (D-282). Solo service_role.';

-- ----------------------------------------------------------------------------
-- 5. client_consent_set_review_name: "verificada" (false) o "mi nombre
--    real" (true). Contra el texto vivo cambia UNA línea: borra el nombre
--    escrito, para que elegir "mi nombre real" después de uno propio no
--    deje el propio pegado.
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
      client_display_name = null,
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

-- ----------------------------------------------------------------------------
-- 6. client_consent_set_review_alias: el nombre que ella escribe.
--    Vuelve a moderación SOLO si la reseña estaba aprobada y el nombre
--    cambió: una rechazada sigue rechazada (escribir un nombre no la
--    resucita), una pendiente sigue pendiente, y reescribir el mismo
--    nombre no la saca de la página.
-- ----------------------------------------------------------------------------

create or replace function public.client_consent_set_review_alias(
  p_review_id uuid,
  p_alias text,
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
  v_alias text := btrim(coalesce(p_alias, ''));
  v_actual text;
  v_estado text;
begin
  v_client := private.beautyos_resolve_consent_client(p_portal_token, p_consent_token);

  if char_length(v_alias) < 2 or char_length(v_alias) > 40 then
    raise exception 'El nombre tiene que tener entre 2 y 40 letras.';
  end if;

  select r.client_display_name, r.moderation_status
    into v_actual, v_estado
  from public.reviews r
  where r.id = p_review_id
    and r.tenant_id = v_client.tenant_id
    and r.client_id = v_client.id
    and r.active;

  if not found then
    raise exception 'Esta reseña no existe o no es tuya.';
  end if;

  update public.reviews
  set client_name_consent = true,
      client_display_name = v_alias,
      client_name_consent_decided_at = now(),
      moderation_status = case
        when v_estado = 'approved' and v_actual is distinct from v_alias then 'pending'
        else moderation_status
      end,
      visible_to_public = case
        when v_estado = 'approved' and v_actual is distinct from v_alias then false
        else visible_to_public
      end,
      updated_at = now()
  where id = p_review_id
    and tenant_id = v_client.tenant_id
    and client_id = v_client.id
    and active;
end;
$$;

revoke all on function public.client_consent_set_review_alias(uuid, text, text, text)
  from public;
grant execute on function public.client_consent_set_review_alias(uuid, text, text, text)
  to anon, authenticated;

comment on function public.client_consent_set_review_alias(uuid, text, text, text) is
  'La clienta elige un nombre propio para su reseña (D-282). Si la reseña estaba aprobada y el nombre cambia, vuelve a moderación: el salón la aprueba otra vez con moderate_review.';

-- ----------------------------------------------------------------------------
-- 7. get_public_salon_reviews: el nombre que ella eligió, si eligió uno.
--    Contra el texto vivo cambia UNA línea (el `case`). Mismas 7 columnas.
-- ----------------------------------------------------------------------------

create or replace function public.get_public_salon_reviews(p_tenant_id uuid)
returns table (
  avg_rating numeric,
  total_reviews integer,
  client_name text,
  rating integer,
  comment text,
  business_reply text,
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
    case when r.client_name_consent then coalesce(r.client_display_name, c.name) else 'Clienta verificada' end,
    r.rating,
    r.comment,
    r.business_reply,
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

-- ----------------------------------------------------------------------------
-- 8. get_publication_studio_data: lo mismo en la pieza de Instagram.
--    Contra el texto vivo cambia UNA línea (`c.name` del select).
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
  select r.rating, r.comment, coalesce(r.client_display_name, c.name), r.client_name_consent
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

-- ----------------------------------------------------------------------------
-- 9. get_reviews_summary_v2: el salón ve CON QUÉ NOMBRE sale cada reseña.
--    Sin esto aprobaría un nombre escrito por la clienta sin verlo.
--    Contra el texto vivo: una columna nueva (`public_name`) al final de
--    la lista y su valor al final del select. Cambia la tabla de retorno:
--    drop primero (mismo motivo que D-170), y los mismos permisos que D-170.
-- ----------------------------------------------------------------------------

drop function if exists public.get_reviews_summary_v2(uuid);

create or replace function public.get_reviews_summary_v2(
  p_branch_id uuid
)
returns table (
  id uuid,
  ticket_id uuid,
  client_name text,
  stylist_name text,
  service_name text,
  rating integer,
  comment text,
  moderation_status text,
  visible_to_public boolean,
  business_reply text,
  business_reply_at timestamptz,
  created_at timestamptz,
  public_name text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_access record;
begin
  select * into strict v_access
  from private.beautyos_resolve_branch_access(
    p_branch_id,
    array['tenant_owner', 'admin']::text[],
    true
  );

  return query
  select
    r.id,
    r.ticket_id,
    coalesce(c.name, 'Cliente no asociado') as client_name,
    coalesce(st.name, 'Estilista no asociado') as stylist_name,
    coalesce(s.name, 'Servicio no asociado') as service_name,
    r.rating,
    r.comment,
    r.moderation_status,
    r.visible_to_public,
    r.business_reply,
    r.business_reply_at,
    r.created_at,
    case
      when r.client_name_consent then coalesce(r.client_display_name, c.name, 'Clienta verificada')
      else 'Clienta verificada'
    end as public_name
  from public.reviews r
  left join public.clients c
    on c.tenant_id = r.tenant_id
   and c.id = r.client_id
  left join public.stylists st
    on st.tenant_id = r.tenant_id
   and st.id = r.stylist_id
  left join public.services s
    on s.tenant_id = r.tenant_id
   and s.id = r.service_id
  where r.tenant_id = v_access.tenant_id
    and r.branch_id = v_access.branch_id
    and r.active
  order by r.created_at desc, r.id;
end;
$$;

revoke all on function public.get_reviews_summary_v2(uuid)
  from public, anon, authenticated;
grant execute on function public.get_reviews_summary_v2(uuid)
  to authenticated;

comment on function public.get_reviews_summary_v2(uuid) is
  'Cola de reseñas del panel del salon, con la respuesta del negocio si existe (paso 6.3, D-170) y el nombre con el que la reseña sale en público (public_name, D-282).';

commit;
