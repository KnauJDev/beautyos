-- ============================================================================
-- Paso 9.48, Bloque 4 (D-288): la llave es de ella. Cierra AQ.
--
-- DECISIONES DEL PROPIETARIO (28-sep):
--   * La casilla de "autorización" al subir la foto SE QUITA, y el servidor
--     deja de aceptar el permiso por esa vía. Publicar solo lo autoriza ella
--     (D-260), desde su portal o su enlace (D-281, D-287).
--   * Las fotos que ya tienen el permiso de la casilla vieja SE RESPETAN: esta
--     migración no toca ni una fila.
--   * El salón le pide la autorización por WhatsApp con su enlace, desde tres
--     sitios: al subir la foto, en la galería (solo en las fotos que ella aún
--     no ha respondido) y en su ficha. Solo dueño o administrador: el
--     estilista no (se conserva la regla del control 229, caso 4).
--
-- QUÉ CAMBIA, todo contra el texto VIVO (`extraer_bloque_4_9_48.sql`, 28-sep):
--   1. create_work_photo: ignora `p_client_consent` (dos líneas, `diff`).
--   2. get_work_photos_summary_v2: gana `client_id` y
--      `client_consent_decided_at` al final. Cambiar las columnas de una
--      función `returns table` exige borrarla y crearla; la lectura no
--      encontró otra función que la use. Permisos como vivían:
--      authenticated y service_role, no anon.
--   3. client_consent_whatsapp_data (NUEVA): en una llamada, lo que el botón
--      necesita para armar el WhatsApp -- el enlace de ella, su nombre, su
--      celular y el nombre del salón. El permiso lo decide
--      get_or_create_client_consent_link, que llama primero: dueño o
--      administrador, y solo clientas de su negocio.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- 1. create_work_photo: el permiso ya no nace al subir la foto.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.create_work_photo(p_branch_id uuid, p_ticket_id uuid, p_storage_path text, p_photo_type text, p_caption text DEFAULT NULL::text, p_stylist_id uuid DEFAULT NULL::uuid, p_client_consent boolean DEFAULT false)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
declare
  v_access record;
  v_tenant_id uuid;
  v_client_id uuid;
  v_ticket_status text;
  v_stylist_id uuid;
  v_photo_id uuid;
begin
  select * into strict v_access
  from private.beautyos_resolve_branch_access(
    p_branch_id,
    array['tenant_owner', 'admin', 'stylist']::text[],
    true
  );

  -- Se conserva intacta la verificacion de plan de D-069: el portafolio es
  -- una funcionalidad diferenciada y un plan Basico no puede agregar fotos
  -- nuevas. Reescribir una funcion no es excusa para perder lo que ya hacia.
  perform private.beautyos_require_entitlement(
    v_access.tenant_id, 'portfolio',
    'Tu plan actual no incluye fotos de trabajo. Mejora tu plan para agregar fotos nuevas.'
  );

  select tk.tenant_id, tk.client_id, tk.status
    into v_tenant_id, v_client_id, v_ticket_status
  from public.tickets tk
  where tk.id = p_ticket_id
    and tk.tenant_id = v_access.tenant_id
    and tk.branch_id = v_access.branch_id;

  if not found then
    raise exception 'El ticket no existe o no pertenece a esta sede.';
  end if;

  if v_ticket_status in ('cancelado', 'no_asistio') then
    raise exception 'No se pueden agregar fotos a un ticket cancelado o no asistido.';
  end if;

  if p_photo_type not in ('before', 'after', 'final', 'portfolio') then
    raise exception 'Tipo de foto invalido.';
  end if;

  if p_storage_path is null or btrim(p_storage_path) = '' then
    raise exception 'La foto no trae ruta de archivo.';
  end if;

  -- Comprobacion nueva, que la version anterior no podia hacer porque recibia
  -- una direccion completa escrita por el cliente: la ruta tiene que estar
  -- dentro de la carpeta de ESTA sede.
  if split_part(btrim(p_storage_path), '/', 1) <> p_branch_id::text then
    raise exception 'La ruta del archivo no corresponde a esta sede.';
  end if;

  -- Un estilista siempre se autoatribuye la foto (D-061): no puede atribuirla
  -- a otra persona aunque lo intente por parametro.
  if v_access.role = 'stylist' then
    v_stylist_id := v_access.stylist_id;
  elsif p_stylist_id is not null then
    if not exists (
      select 1
      from public.ticket_services ts
      where ts.ticket_id = p_ticket_id
        and ts.stylist_id = p_stylist_id
    ) then
      raise exception 'El estilista seleccionado no corresponde a este ticket.';
    end if;
    v_stylist_id := p_stylist_id;
  else
    v_stylist_id := null;
  end if;

  insert into public.work_photos (
    tenant_id, branch_id, ticket_id, client_id, stylist_id,
    storage_bucket, storage_path, photo_url,
    photo_type, caption,
    visible_to_customer, approved_for_portfolio,
    client_consent, client_consent_at
  )
  values (
    v_tenant_id, p_branch_id, p_ticket_id, v_client_id, v_stylist_id,
    -- Nace privada y sin direccion publica. Publicarla es una decision
    -- explicita, no el estado por defecto (H-09).
    'work-photos-private', btrim(p_storage_path), null,
    p_photo_type,
    nullif(trim(coalesce(p_caption, '')), ''),
    false, false,
    -- D-288 (AQ): el permiso de publicar NUNCA nace aquí. Lo daba quien
    -- subía la foto marcando una casilla -- la parte interesada firmando por
    -- la clienta. Ahora solo lo da ella, desde su portal o su enlace
    -- (client_consent_set_photo, D-281; decisión del propietario, D-260).
    -- `p_client_consent` se conserva para no romper a quien aún lo mande,
    -- pero se ignora.
    false,
    null
  )
  returning id into v_photo_id;

  return v_photo_id;
end;
$function$
;

-- ----------------------------------------------------------------------------
-- 2. get_work_photos_summary_v2: dice de qué clienta es y si ya respondió.
--    Mismo cuerpo que el vivo; solo dos columnas nuevas, al final.
-- ----------------------------------------------------------------------------

drop function public.get_work_photos_summary_v2(uuid);

create function public.get_work_photos_summary_v2(p_branch_id uuid)
returns table(
  id uuid,
  ticket_id uuid,
  client_name text,
  stylist_name text,
  photo_url text,
  storage_bucket text,
  storage_path text,
  photo_type text,
  caption text,
  ai_status text,
  visible_to_customer boolean,
  approved_for_portfolio boolean,
  client_consent boolean,
  client_consent_at timestamp with time zone,
  created_at timestamp with time zone,
  client_id uuid,
  client_consent_decided_at timestamp with time zone
)
language plpgsql
security definer
set search_path = pg_catalog
as $function$
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
    wp.id,
    wp.ticket_id,
    c.name,
    st.name,
    wp.photo_url,
    wp.storage_bucket,
    wp.storage_path,
    wp.photo_type,
    wp.caption,
    wp.ai_status,
    wp.visible_to_customer,
    wp.approved_for_portfolio,
    wp.client_consent,
    wp.client_consent_at,
    wp.created_at,
    -- D-288: para el botón "Pedir autorización" de la galería.
    wp.client_id,
    wp.client_consent_decided_at
  from public.work_photos wp
  left join public.clients c
    on c.tenant_id = wp.tenant_id
   and c.id = wp.client_id
  left join public.stylists st
    on st.tenant_id = wp.tenant_id
   and st.id = wp.stylist_id
  where wp.tenant_id = v_access.tenant_id
    and wp.branch_id = v_access.branch_id
    and wp.active
  order by wp.created_at desc;
end;
$function$;

revoke all on function public.get_work_photos_summary_v2(uuid) from public, anon;
grant execute on function public.get_work_photos_summary_v2(uuid) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 3. client_consent_whatsapp_data: todo lo del WhatsApp, en una llamada.
-- ----------------------------------------------------------------------------

create or replace function public.client_consent_whatsapp_data(p_client_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_token text;
  v_result jsonb;
begin
  -- Primero el permiso, en un solo sitio: dueño o administrador, y la
  -- clienta de su negocio. Si no, esto revienta y no sale nada más.
  v_token := public.get_or_create_client_consent_link(p_client_id);

  select jsonb_build_object(
    'token', v_token,
    'client_name', c.name,
    'client_phone', c.phone,
    'business_name', t.name
  )
    into v_result
  from public.clients c
  join public.tenants t on t.id = c.tenant_id
  where c.id = p_client_id
    and c.tenant_id = public.get_my_tenant_id();

  return v_result;
end;
$$;

revoke all on function public.client_consent_whatsapp_data(uuid) from public, anon;
grant execute on function public.client_consent_whatsapp_data(uuid) to authenticated;

comment on function public.client_consent_whatsapp_data(uuid) is
  'Paso 9.48, Bloque 4 (D-288): el enlace de autorizaciones de una clienta, con su nombre, su celular y el nombre del salón, para armar el WhatsApp. El permiso lo decide get_or_create_client_consent_link (dueño o administrador).';

commit;
