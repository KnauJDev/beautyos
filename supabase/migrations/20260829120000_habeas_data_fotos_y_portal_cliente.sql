-- ============================================================================
-- MIGRACIÓN: 20260829120000_habeas_data_fotos_y_portal_cliente.sql
-- DESCRIPCIÓN: D-167. Cierre de la Fase 5. Paso 5.7: ninguna foto se publica
--              en el portafolio sin el consentimiento explícito de la
--              clienta (Ley 1581 de 2012, Habeas Data). Paso 5.6: portal
--              seguro de la clienta ("Mis citas y fotos") con PIN de 4
--              dígitos, sin sesión de Salón y Más.
--
--              DECISIÓN DE SEGURIDAD, confirmada con el propietario antes de
--              escribir código: el diseño original pedía que "si la clienta
--              aún no tiene PIN, el primer que lo intente lo define". Eso es
--              un hueco de apropiación de cuenta -- cualquiera que sepa el
--              celular de una clienta real podría reclamar su cuenta antes
--              que ella y ver su historial y sus fotos. Se eligió la opción
--              segura: **solo el salón asigna el PIN** (Ficha del
--              cliente, botón "Restablecer PIN del portal", misma RPC sirve
--              para asignar la primera vez y para restablecer). La RPC de
--              autenticación SOLO verifica; si no hay PIN, responde "pide tu
--              PIN al salón" en vez de crear uno.
--
--              Dos refuerzos que no pidió el encargo, agregados porque un
--              PIN de 4 dígitos (10.000 combinaciones) es indefendible sin
--              ellos: el hash lleva sal por cliente (SHA-256 sin sal se
--              revierte con una tabla de 10.000 entradas precalculada) y hay
--              bloqueo tras intentos fallidos (5 intentos, 15 minutos) --
--              sin esto, la RPC pública sería fuerza-bruteable en segundos.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- 1. Habeas Data: `work_photos` gana el consentimiento de la clienta
-- ----------------------------------------------------------------------------

alter table public.work_photos
  add column if not exists client_consent boolean not null default false,
  add column if not exists client_consent_at timestamptz;

comment on column public.work_photos.client_consent is
  'La clienta autorizó publicar esta foto en portafolio y redes (Ley 1581 de 2012). Sin esto, no se puede aprobar para portafolio (D-167).';
comment on column public.work_photos.client_consent_at is
  'Momento en que se marcó el consentimiento, para trazabilidad legal.';

-- ----------------------------------------------------------------------------
-- 2. create_work_photo: gana `p_client_consent` (parámetro nuevo con
--    default al final -- no cambia el orden de los que ya existían, no hace
--    falta `drop function`).
-- ----------------------------------------------------------------------------

create or replace function public.create_work_photo(
  p_branch_id uuid,
  p_ticket_id uuid,
  p_storage_path text,
  p_photo_type text,
  p_caption text default null,
  p_stylist_id uuid default null,
  p_client_consent boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog
as $$
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
    coalesce(p_client_consent, false),
    case when coalesce(p_client_consent, false) then now() else null end
  )
  returning id into v_photo_id;

  return v_photo_id;
end;
$$;

revoke all on function public.create_work_photo(uuid, uuid, text, text, text, uuid, boolean)
  from public, anon, authenticated;
grant execute on function public.create_work_photo(uuid, uuid, text, text, text, uuid, boolean)
  to authenticated;

-- ----------------------------------------------------------------------------
-- 3. set_work_photo_portfolio_approval: rechaza aprobar sin consentimiento.
--    Misma firma que antes (4 parámetros) -- solo se agrega la validación.
-- ----------------------------------------------------------------------------

create or replace function public.set_work_photo_portfolio_approval(
  p_branch_id uuid,
  p_photo_id uuid,
  p_approved boolean,
  p_public_url text default null
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_access record;
  v_path text;
  v_consent boolean;
begin
  select * into strict v_access
  from private.beautyos_resolve_branch_access(
    p_branch_id,
    array['tenant_owner', 'admin']::text[],
    true
  );

  select wp.storage_path, wp.client_consent
    into v_path, v_consent
  from public.work_photos wp
  where wp.id = p_photo_id
    and wp.tenant_id = v_access.tenant_id
    and wp.branch_id = v_access.branch_id
    and wp.active;

  if not found then
    raise exception 'La foto no existe o no pertenece a esta sede.';
  end if;

  if p_approved then
    if not v_consent then
      raise exception 'No se puede publicar en portafolio sin consentimiento de la clienta (Ley 1581)';
    end if;

    if p_public_url is null or p_public_url !~ '/object/public/work-photos/' then
      raise exception
        'Para publicar una foto hace falta su direccion publica del almacen work-photos.';
    end if;

    -- La direccion tiene que apuntar a ESTE archivo. Sin esto, se podria
    -- guardar la direccion de una foto de otro negocio.
    if split_part(p_public_url, '/object/public/work-photos/', 2) <> v_path then
      raise exception 'La direccion publica no corresponde a esta foto.';
    end if;

    update public.work_photos
    set approved_for_portfolio = true,
        storage_bucket = 'work-photos',
        photo_url = p_public_url,
        updated_at = now()
    where id = p_photo_id;
  else
    update public.work_photos
    set approved_for_portfolio = false,
        storage_bucket = 'work-photos-private',
        photo_url = null,
        updated_at = now()
    where id = p_photo_id;
  end if;
end;
$$;

-- ----------------------------------------------------------------------------
-- 4. get_work_photos_summary_v2: gana `client_consent`/`client_consent_at`
--    para que la galería interna muestre el indicador visual. Cambia la
--    tabla de retorno -- `drop function` primero.
-- ----------------------------------------------------------------------------

drop function if exists public.get_work_photos_summary_v2(uuid);

create or replace function public.get_work_photos_summary_v2(p_branch_id uuid)
returns table (
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
  client_consent_at timestamptz,
  created_at timestamptz
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
    wp.created_at
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
$$;

revoke all on function public.get_work_photos_summary_v2(uuid)
  from public, anon, authenticated;
grant execute on function public.get_work_photos_summary_v2(uuid)
  to authenticated;

-- ----------------------------------------------------------------------------
-- 5. Portal de la clienta: columnas nuevas en `public.clients`.
--
-- Solo `portal_pin_hash` estaba en el encargo. Las otras cinco son el
-- refuerzo de seguridad acordado: `portal_pin_salt` (hash salado, no un
-- SHA-256 plano), `portal_failed_attempts`/`portal_locked_until` (freno de
-- fuerza bruta), `portal_session_token`/`portal_session_expires_at` (sesion
-- temporal, no queda autenticada para siempre).
-- ----------------------------------------------------------------------------

alter table public.clients
  add column if not exists portal_pin_hash text,
  add column if not exists portal_pin_salt text,
  add column if not exists portal_failed_attempts integer not null default 0,
  add column if not exists portal_locked_until timestamptz,
  add column if not exists portal_session_token text,
  add column if not exists portal_session_expires_at timestamptz;

comment on column public.clients.portal_pin_hash is
  'SHA-256 de (PIN + portal_pin_salt), nunca el PIN en texto plano (D-167). Null si el salón todavía no le asignó uno.';
comment on column public.clients.portal_pin_salt is
  'Sal aleatoria por cliente. Sin ella, un SHA-256 de un PIN de 4 dígitos se revierte con una tabla de 10.000 entradas precalculada.';
comment on column public.clients.portal_failed_attempts is
  'Intentos fallidos consecutivos contra el PIN del portal. Se reinicia al entrar bien o al restablecer el PIN.';
comment on column public.clients.portal_locked_until is
  'Bloqueo temporal tras 5 intentos fallidos (D-167). Null si no está bloqueada.';
comment on column public.clients.portal_session_token is
  'Token de sesión del portal, opaco y aleatorio (no un JWT). Se reemplaza en cada ingreso y se invalida al restablecer el PIN.';
comment on column public.clients.portal_session_expires_at is
  'Vigencia del token de sesión del portal (60 días desde el último ingreso).';

-- ----------------------------------------------------------------------------
-- 6. client_portal_authenticate: SOLO verifica. Nunca crea un PIN -- esa es
--    la decisión de seguridad de este bloque (ver cabecera del archivo).
-- ----------------------------------------------------------------------------

create or replace function public.client_portal_authenticate(
  p_tenant_id uuid,
  p_phone text,
  p_pin text
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_phone_digits text := regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g');
  v_pin text := trim(coalesce(p_pin, ''));
  v_client public.clients%rowtype;
  v_token text;
begin
  if v_phone_digits = '' or v_pin !~ '^[0-9]{4}$' then
    raise exception 'Escribe tu celular y un PIN de 4 dígitos.';
  end if;

  -- Se compara solo por dígitos: la clienta puede haber quedado registrada
  -- con o sin "+57" y no tiene por qué saber cuál de las dos formas usa el
  -- salón.
  select *
    into v_client
  from public.clients c
  where c.tenant_id = p_tenant_id
    and c.active = true
    and regexp_replace(c.phone, '[^0-9]', '', 'g') = v_phone_digits
  order by c.created_at
  limit 1
  for update;

  if not found then
    raise exception 'No encontramos ninguna cuenta con ese celular en este negocio.';
  end if;

  if v_client.portal_pin_hash is null or v_client.portal_pin_salt is null then
    raise exception 'Todavía no tienes un PIN de acceso. Pídelo en el salón.';
  end if;

  if v_client.portal_locked_until is not null and v_client.portal_locked_until > now() then
    raise exception 'Demasiados intentos fallidos. Espera unos minutos o pide un PIN nuevo en el salón.';
  end if;

  if encode(sha256((v_pin || v_client.portal_pin_salt)::bytea), 'hex') <> v_client.portal_pin_hash then
    update public.clients
    set portal_failed_attempts = portal_failed_attempts + 1,
        portal_locked_until = case
          when portal_failed_attempts + 1 >= 5 then now() + interval '15 minutes'
          else portal_locked_until
        end
    where id = v_client.id;

    raise exception 'PIN incorrecto.';
  end if;

  v_token := gen_random_uuid()::text;

  update public.clients
  set portal_failed_attempts = 0,
      portal_locked_until = null,
      portal_session_token = v_token,
      portal_session_expires_at = now() + interval '60 days'
  where id = v_client.id;

  return v_token;
end;
$$;

revoke all on function public.client_portal_authenticate(uuid, text, text)
  from public;
grant execute on function public.client_portal_authenticate(uuid, text, text)
  to anon, authenticated;

comment on function public.client_portal_authenticate(uuid, text, text) is
  'Verifica el PIN del portal de la clienta -- NUNCA lo crea (D-167: solo el salón asigna el PIN, ver decisión en la cabecera de la migración). Devuelve un token de sesión de 60 días.';

-- ----------------------------------------------------------------------------
-- 7. get_client_portal_data: perfil, citas próximas/pasadas y fotos, todo
--    en un solo jsonb (varias formas de fila distintas -- no cabe en un
--    unico `returns table`).
-- ----------------------------------------------------------------------------

create or replace function public.get_client_portal_data(
  p_tenant_id uuid,
  p_phone text,
  p_portal_token text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_phone_digits text := regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g');
  v_client public.clients%rowtype;
begin
  select *
    into v_client
  from public.clients c
  where c.tenant_id = p_tenant_id
    and c.active = true
    and regexp_replace(c.phone, '[^0-9]', '', 'g') = v_phone_digits
  order by c.created_at
  limit 1;

  if not found
     or v_client.portal_session_token is null
     or v_client.portal_session_token <> coalesce(p_portal_token, '')
     or v_client.portal_session_expires_at is null
     or v_client.portal_session_expires_at < now()
  then
    raise exception 'Tu sesión expiró. Vuelve a ingresar con tu celular y tu PIN.';
  end if;

  return jsonb_build_object(
    'client_name', v_client.name,
    'upcoming_appointments', (
      select coalesce(jsonb_agg(
        jsonb_build_object(
          'ticket_id', t.id,
          'ticket_code', t.ticket_code,
          'scheduled_at', t.scheduled_at,
          'status', t.status,
          'service_names', coalesce(ss.service_names, 'Sin servicios'),
          'stylist_names', coalesce(ss.stylist_names, 'Sin estilista')
        )
        order by t.scheduled_at asc nulls last
      ), '[]'::jsonb)
      from public.tickets t
      left join lateral (
        select
          string_agg(distinct s.name, ', ' order by s.name) as service_names,
          string_agg(distinct st.name, ', ' order by st.name) as stylist_names
        from public.ticket_services ts
        left join public.services s
          on s.tenant_id = ts.tenant_id and s.id = ts.service_id
        left join public.stylists st
          on st.tenant_id = ts.tenant_id and st.id = ts.stylist_id
        where ts.ticket_id = t.id
          and ts.status <> 'cancelado'
      ) ss on true
      where t.tenant_id = p_tenant_id
        and t.client_id = v_client.id
        and t.status not in ('finalizado', 'cerrado', 'cancelado', 'no_asistio')
    ),
    'past_appointments', (
      select coalesce(jsonb_agg(
        jsonb_build_object(
          'ticket_id', t.id,
          'ticket_code', t.ticket_code,
          'scheduled_at', t.scheduled_at,
          'status', t.status,
          'service_names', coalesce(ss.service_names, 'Sin servicios'),
          'already_reviewed', exists(
            select 1 from public.reviews r
            where r.ticket_id = t.id and r.active
          )
        )
        order by t.scheduled_at desc nulls last
      ), '[]'::jsonb)
      from public.tickets t
      left join lateral (
        select string_agg(distinct s.name, ', ' order by s.name) as service_names
        from public.ticket_services ts
        left join public.services s
          on s.tenant_id = ts.tenant_id and s.id = ts.service_id
        where ts.ticket_id = t.id
          and ts.status <> 'cancelado'
      ) ss on true
      where t.tenant_id = p_tenant_id
        and t.client_id = v_client.id
        and t.status in ('finalizado', 'cerrado')
      limit 50
    ),
    'photos', (
      select coalesce(jsonb_agg(
        jsonb_build_object(
          'id', wp.id,
          'photo_url', wp.photo_url,
          'photo_type', wp.photo_type,
          'caption', wp.caption,
          'created_at', wp.created_at
        )
        order by wp.created_at desc
      ), '[]'::jsonb)
      from public.work_photos wp
      where wp.tenant_id = p_tenant_id
        and wp.client_id = v_client.id
        and wp.visible_to_customer = true
        and wp.active
        -- Una foto puede ser visible_to_customer=true sin estar aprobada
        -- para portafolio (D-119): en ese caso vive en el almacen PRIVADO y
        -- no tiene direccion publica permanente. Mostrarla en el portal
        -- (sin sesion, rol anon) exigiria generar URLs firmadas, que es
        -- infraestructura nueva fuera de este bloque -- se deja fuera y se
        -- documenta, no se inventa a medias.
        and wp.photo_url is not null
    )
  );
end;
$$;

revoke all on function public.get_client_portal_data(uuid, text, text)
  from public;
grant execute on function public.get_client_portal_data(uuid, text, text)
  to anon, authenticated;

comment on function public.get_client_portal_data(uuid, text, text) is
  'Datos del portal de la clienta: citas próximas/pasadas y fotos publicadas, validando el token de sesión (D-167). Las fotos visibles pero aún no aprobadas para portafolio (D-119) no viajan aquí: no tienen URL pública permanente.';

-- ----------------------------------------------------------------------------
-- 8. admin_reset_client_portal_pin: asigna o restablece el PIN. Sin
--    `p_branch_id` -- los clientes son del TENANT, no de una sede (D-011),
--    mismo criterio que ya usa `ClientsService` en Flutter (nunca pasa
--    branchId). El encargo pedía `p_branch_id`; se verificó en el código
--    antes de escribir la función (regla 8.1) y esa sede no existe en
--    ningún punto de la pantalla de Clientes.
-- ----------------------------------------------------------------------------

create or replace function public.admin_reset_client_portal_pin(
  p_client_id uuid,
  p_new_pin text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid := public.get_my_tenant_id();
  v_pin text := trim(coalesce(p_new_pin, ''));
  v_salt text;
begin
  if v_tenant_id is null then
    raise exception 'No existe un perfil activo asociado al usuario actual.';
  end if;

  if not public.is_owner_or_admin() then
    raise exception 'No autorizado. Solo owner o admin puede restablecer el PIN del portal.';
  end if;

  if v_pin !~ '^[0-9]{4}$' then
    raise exception 'El PIN debe tener exactamente 4 dígitos.';
  end if;

  v_salt := replace(gen_random_uuid()::text, '-', '');

  update public.clients
  set portal_pin_hash = encode(sha256((v_pin || v_salt)::bytea), 'hex'),
      portal_pin_salt = v_salt,
      portal_failed_attempts = 0,
      portal_locked_until = null,
      -- Restablecer el PIN cierra cualquier sesion abierta con el PIN
      -- viejo: si alguien mas lo tenia, deja de servirle.
      portal_session_token = null,
      portal_session_expires_at = null
  where id = p_client_id
    and tenant_id = v_tenant_id;

  if not found then
    raise exception 'El cliente no existe o no pertenece a este negocio.';
  end if;
end;
$$;

revoke all on function public.admin_reset_client_portal_pin(uuid, text)
  from public, anon;
grant execute on function public.admin_reset_client_portal_pin(uuid, text)
  to authenticated;

comment on function public.admin_reset_client_portal_pin(uuid, text) is
  'Asigna o restablece el PIN del portal de una clienta. Exclusivo owner/admin del tenant. Misma función sirve para la primera asignación y para restablecer (D-167).';

commit;
