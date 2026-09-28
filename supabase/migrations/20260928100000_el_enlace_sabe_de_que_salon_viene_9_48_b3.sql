-- ============================================================================
-- Paso 9.48, Bloque 3 (D-287): la página del enlace directo sabe de qué salón
-- viene.
--
-- La clienta abre `salonymas.com/?autorizar=<su enlace>` sin sesión y sin
-- PIN. La página solo tiene su token; para pintar los colores del salón y
-- ofrecerle "Ver la página de [Salón]" (decisiones del propietario, 28-sep)
-- necesita el slug del negocio. Los colores los sigue sacando la app de
-- `get_public_salon_by_slug`, la misma que usa la página pública del salón:
-- aquí no se añade nada más.
--
-- QUÉ CAMBIA, contra el texto VIVO (`extraer_pendientes_bloque_3_9_48.sql`,
-- 28-sep, comparado con `diff`: el vivo es idéntico al de la migración
-- 20260926170000): tres líneas -- una variable, el `select` que la llena y
-- `business_slug` en la respuesta. Nada más.
--
-- El slug no es secreto: es la dirección pública del salón. Y solo lo recibe
-- quien ya tiene un token válido de una clienta de ese salón.
--
-- Mismo nombre, mismos parámetros, mismo tipo de retorno (jsonb): basta
-- `create or replace`, y los permisos vivos (anon, authenticated) se
-- conservan. La lectura del 28-sep: 2 negocios activos, ninguno sin slug.
-- ============================================================================

begin;

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
  v_business_slug text;
begin
  v_client := private.beautyos_resolve_consent_client(p_portal_token, p_consent_token);
  select t.name, t.whatsapp, t.slug
    into v_business_name, v_business_whatsapp, v_business_slug
  from public.tenants t
  where t.id = v_client.tenant_id;
  return jsonb_build_object(
    'client_name', v_client.name,
    'business_name', v_business_name,
    'business_whatsapp', v_business_whatsapp,
    -- Bloque 3 (D-287): la página del enlace directo no sabe de qué salón
    -- viene; con el slug pinta sus colores y ofrece ir a su página.
    'business_slug', v_business_slug,
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

commit;
