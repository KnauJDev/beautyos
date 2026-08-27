-- ============================================================================
-- MIGRACIÓN: 20260827140000_slugs_publicos_y_perfil_comercial.sql
-- DESCRIPCIÓN: Fase 5, Bloque 1 (pasos 5.1 a 5.4, D-164). El enlace propio de
--              cada negocio: `salonymas.com/<slug>`, decidido en D-098 y
--              construido ahora. Cada tenant recibe un identificador único
--              sin eñes ni tildes (columna `slug`), una función pública que
--              lo resuelve sin sesión, y el propio salón puede modificarlo
--              desde Configuración.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- 1. Columna `slug` en `public.tenants`
-- ----------------------------------------------------------------------------

alter table public.tenants
  add column if not exists slug text;

comment on column public.tenants.slug is
  'Identificador único del negocio en su enlace público (salonymas.com/<slug>). Sin eñes, tildes ni espacios (D-098, D-164).';

-- ----------------------------------------------------------------------------
-- 2. `private.beautyos_slugify`: nombre de negocio -> texto de enlace
--
-- Minúsculas, sin acentos/tildes/eñe (mapeo explícito con `translate`, sin
-- depender de la extensión `unaccent`), y cualquier tramo de caracteres que
-- no sea letra/número se colapsa en un solo guion, sin guion al principio ni
-- al final. Es una transformación pura: no valida longitud, unicidad ni
-- palabras reservadas -- eso lo hace quien la llama.
-- ----------------------------------------------------------------------------

create or replace function private.beautyos_slugify(p_text text)
returns text
language sql
immutable
set search_path = pg_catalog
as $$
  select nullif(
    trim(both '-' from
      regexp_replace(
        translate(
          lower(trim(coalesce(p_text, ''))),
          'áàâãäéèêëíìîïóòôõöúùûüñç',
          'aaaaaeeeeiiiiooooouuuunc'
        ),
        '[^a-z0-9]+', '-', 'g'
      )
    ),
    ''
  );
$$;

revoke all on function private.beautyos_slugify(text)
  from public, anon, authenticated;
grant execute on function private.beautyos_slugify(text)
  to service_role;

comment on function private.beautyos_slugify(text) is
  'Convierte un nombre de negocio en el texto base de su enlace público: minúsculas, sin acentos ni eñe, separadores colapsados en guiones (D-164).';

-- ----------------------------------------------------------------------------
-- 3. Formato, longitud y palabras reservadas
--
-- Lista negra de rutas del sistema (D-164). Vive repetida, a propósito, en
-- este CHECK y en las tres funciones de más abajo: un CHECK no admite
-- subconsultas contra otra tabla, así que no hay forma de compartir una
-- única fuente de verdad en SQL puro. Si se agrega una ruta reservada nueva,
-- hay que tocar los 4 sitios (buscar 'login', 'register', 'auth' en este
-- archivo para encontrarlos todos) y el equivalente en `lib/main.dart`.
-- ----------------------------------------------------------------------------

alter table public.tenants
  drop constraint if exists tenants_slug_format_check;

alter table public.tenants
  add constraint tenants_slug_format_check
  check (
    slug is null or (
      length(slug) between 3 and 50
      and slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'
      and slug not in (
        'login', 'register', 'auth', 'planes', 'pricing', 'terminos',
        'privacidad', 'terms', 'privacy', 'admin', 'dashboard', 'settings',
        'soporte', 'api'
      )
    )
  );

alter table public.tenants
  drop constraint if exists tenants_slug_key;

alter table public.tenants
  add constraint tenants_slug_key unique (slug);

-- ----------------------------------------------------------------------------
-- 4. `private.beautyos_generate_unique_tenant_slug`: slug listo para
--    guardar -- resuelve el nombre corto/reservado/largo y la colisión con
--    un sufijo numérico. La usan tanto `register_tenant` (tenant nuevo) como
--    el backfill de abajo (tenants existentes sin slug).
-- ----------------------------------------------------------------------------

create or replace function private.beautyos_generate_unique_tenant_slug(p_business_name text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reserved constant text[] := array[
    'login', 'register', 'auth', 'planes', 'pricing', 'terminos',
    'privacidad', 'terms', 'privacy', 'admin', 'dashboard', 'settings',
    'soporte', 'api'
  ];
  v_base text;
  v_slug text;
  v_suffix int;
  v_suffix_text text;
begin
  v_base := private.beautyos_slugify(p_business_name);

  -- Nombre que no deja nada aprovechable (solo símbolos/emoji) o demasiado
  -- corto: se cae a un identificador corto y único en vez de fallar el
  -- registro por esto.
  if v_base is null or length(v_base) < 3 then
    v_base := 'salon-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);
  end if;

  if length(v_base) > 50 then
    v_base := trim(both '-' from substr(v_base, 1, 50));
  end if;

  if v_base = any(v_reserved) then
    v_base := v_base || '-salon';
  end if;

  v_slug := v_base;
  v_suffix := 1;
  while exists (select 1 from public.tenants where slug = v_slug) loop
    v_suffix := v_suffix + 1;
    v_suffix_text := '-' || v_suffix;
    if length(v_base) + length(v_suffix_text) > 50 then
      v_slug := substr(v_base, 1, 50 - length(v_suffix_text)) || v_suffix_text;
    else
      v_slug := v_base || v_suffix_text;
    end if;
  end loop;

  return v_slug;
end;
$$;

revoke all on function private.beautyos_generate_unique_tenant_slug(text)
  from public, anon, authenticated;
grant execute on function private.beautyos_generate_unique_tenant_slug(text)
  to service_role;

comment on function private.beautyos_generate_unique_tenant_slug(text) is
  'Genera un slug de tenant listo para guardar: aplica beautyos_slugify, resuelve corto/reservado/largo y le agrega un sufijo numérico si ya existe (D-164).';

-- ----------------------------------------------------------------------------
-- 5. Backfill: cada tenant existente sin slug recibe uno
-- ----------------------------------------------------------------------------

do $$
declare
  r record;
begin
  for r in
    select id, name
    from public.tenants
    where slug is null
    order by created_at
  loop
    update public.tenants
    set slug = private.beautyos_generate_unique_tenant_slug(r.name)
    where id = r.id;
  end loop;
end;
$$;

-- ----------------------------------------------------------------------------
-- 6. `register_tenant`: el tenant nuevo nace con su slug (D-098: "automática
--    para todos desde el registro, sin configurar nada por negocio"). Misma
--    firma que tenía (8 parámetros, misma tabla de retorno) -- no hace falta
--    `drop function`, solo agrega la generación y la columna al insert.
-- ----------------------------------------------------------------------------

create or replace function public.register_tenant(
  p_business_name text,
  p_owner_full_name text,
  p_whatsapp text,
  p_business_type text default null,
  p_city text default null,
  p_estimated_branches integer default 1,
  p_estimated_team_size integer default 1,
  p_referral_source text default null
)
returns table (
  tenant_id uuid,
  branch_id uuid,
  status text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_email text;
  v_tenant_id uuid;
  v_branch_id uuid;
  v_tenant_membership_id uuid;
  v_plan_id uuid;
  v_subscription_id uuid;
  v_slug text;
begin
  if v_user_id is null then
    raise exception 'Se requiere una sesion autenticada para registrar un negocio.';
  end if;

  if exists (
    select 1 from public.tenant_memberships where user_id = v_user_id
  ) then
    raise exception 'Este usuario ya pertenece a un negocio.';
  end if;

  if length(trim(coalesce(p_business_name, ''))) = 0 then
    raise exception 'El nombre del negocio es obligatorio.';
  end if;

  if length(trim(coalesce(p_owner_full_name, ''))) = 0 then
    raise exception 'Tu nombre completo es obligatorio.';
  end if;

  if length(trim(coalesce(p_whatsapp, ''))) = 0 then
    raise exception 'El WhatsApp de contacto es obligatorio.';
  end if;

  select email into v_email from auth.users where id = v_user_id;
  if v_email is null then
    raise exception 'No se encontro un correo asociado a esta sesion.';
  end if;

  select p.id into v_plan_id
  from public.plans p
  where p.code = 'profesional' and p.status = 'active';

  if v_plan_id is null then
    raise exception 'No hay un plan disponible para registrar la solicitud.';
  end if;

  v_slug := private.beautyos_generate_unique_tenant_slug(p_business_name);

  insert into public.tenants (
    name,
    slug,
    business_type,
    contact_email,
    whatsapp,
    city,
    estimated_branches,
    estimated_team_size,
    referral_source,
    active
  ) values (
    trim(p_business_name),
    v_slug,
    nullif(trim(coalesce(p_business_type, '')), ''),
    v_email,
    trim(p_whatsapp),
    nullif(trim(coalesce(p_city, '')), ''),
    greatest(1, coalesce(p_estimated_branches, 1)),
    greatest(1, coalesce(p_estimated_team_size, 1)),
    nullif(trim(coalesce(p_referral_source, '')), ''),
    true
  )
  returning id into v_tenant_id;

  insert into public.branches (tenant_id, name, slug, is_primary)
  values (v_tenant_id, trim(p_business_name), 'principal', true)
  returning id into v_branch_id;

  insert into public.user_profiles (tenant_id, user_id, full_name, role, active)
  values (v_tenant_id, v_user_id, trim(p_owner_full_name), 'owner', true);

  insert into public.tenant_memberships (tenant_id, user_id, role, active, starts_at)
  values (v_tenant_id, v_user_id, 'tenant_owner', true, now())
  returning id into v_tenant_membership_id;

  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (
    v_tenant_id, v_branch_id, v_tenant_membership_id, true, now(), v_user_id
  );

  insert into public.business_hours (
    tenant_id, branch_id, day_of_week, opens_at, closes_at, is_open
  )
  select
    v_tenant_id,
    v_branch_id,
    schedule.day_of_week,
    schedule.opens_at,
    schedule.closes_at,
    schedule.is_open
  from (
    values
      (1, time '08:00', time '20:00', true),
      (2, time '08:00', time '20:00', true),
      (3, time '08:00', time '20:00', true),
      (4, time '08:00', time '20:00', true),
      (5, time '08:00', time '20:00', true),
      (6, time '08:00', time '20:00', true),
      (7, null::time, null::time, false)
  ) as schedule(day_of_week, opens_at, closes_at, is_open);

  insert into public.appointment_policies (tenant_id, branch_id)
  values (v_tenant_id, v_branch_id);

  insert into public.commission_policies (tenant_id)
  values (v_tenant_id);

  -- Filtro de Aceptación (D-125): el negocio nace en estado 'pending'.
  -- La prueba gratis NO arranca aquí (trial_ends_at = NULL).
  insert into public.tenant_subscriptions (
    tenant_id, plan_id, status, trial_ends_at, current_period_start
  ) values (
    v_tenant_id, v_plan_id, 'pending', null, null
  )
  returning id into v_subscription_id;

  insert into public.subscription_events (
    tenant_id, tenant_subscription_id, event_type, payload, created_by
  ) values (
    v_tenant_id,
    v_subscription_id,
    'registration_requested',
    jsonb_build_object(
      'business_name', trim(p_business_name),
      'owner_full_name', trim(p_owner_full_name),
      'city', nullif(trim(coalesce(p_city, '')), ''),
      'business_type', nullif(trim(coalesce(p_business_type, '')), ''),
      'estimated_branches', p_estimated_branches,
      'estimated_team_size', p_estimated_team_size,
      'referral_source', nullif(trim(coalesce(p_referral_source, '')), '')
    ),
    v_user_id
  );

  return query select v_tenant_id, v_branch_id, 'pending'::text;
end;
$$;

revoke all on function public.register_tenant(text, text, text, text, text, integer, integer, text) from public, anon;
grant execute on function public.register_tenant(text, text, text, text, text, integer, integer, text) to authenticated;

comment on function public.register_tenant(text, text, text, text, text, integer, integer, text)
  is 'Registra una solicitud de nuevo negocio en estado pendiente de aprobacion (D-125), con su slug público generado desde el nombre (D-164).';

-- ----------------------------------------------------------------------------
-- 7. `get_business_settings`: gana `slug` para que Configuración muestre el
--    enlace actual. Cambia la tabla de retorno -- `drop function` primero
--    (mismo motivo que D-162 con `update_tenant_contact_info`: `create or
--    replace` no admite cambiar la forma de lo que devuelve).
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

revoke execute on function public.get_business_settings() from anon;
revoke execute on function public.get_business_settings() from public;
grant execute on function public.get_business_settings() to authenticated;

-- ----------------------------------------------------------------------------
-- 8. `get_public_salon_by_slug`: la página pública, sin sesión. Solo datos
--    comerciales -- nada de correo, membresías ni información operativa.
--    `address` no vive en `tenants` (solo `city`): se toma de la sede
--    principal activa, que es la única dirección física que tiene sentido
--    mostrar en la página de un negocio hoy (Fase 5 aún es de un solo
--    perfil público por tenant, no por sede).
-- ----------------------------------------------------------------------------

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
  facebook text
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
    t.facebook
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
  'Perfil comercial público de un negocio por su slug, sin sesión (D-098, D-164). Solo datos de vitrina, nunca correo ni información operativa.';

-- ----------------------------------------------------------------------------
-- 9. `check_slug_availability`: para el diálogo "Modificar enlace" en vivo
-- ----------------------------------------------------------------------------

create or replace function public.check_slug_availability(p_slug text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_slug text := lower(trim(coalesce(p_slug, '')));
  v_reserved constant text[] := array[
    'login', 'register', 'auth', 'planes', 'pricing', 'terminos',
    'privacidad', 'terms', 'privacy', 'admin', 'dashboard', 'settings',
    'soporte', 'api'
  ];
begin
  if v_slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$'
     or length(v_slug) < 3
     or length(v_slug) > 50
     or v_slug = any(v_reserved) then
    return false;
  end if;

  return not exists (select 1 from public.tenants where slug = v_slug);
end;
$$;

revoke all on function public.check_slug_availability(text) from public, anon;
grant execute on function public.check_slug_availability(text) to authenticated;

comment on function public.check_slug_availability(text) is
  'Comprueba formato, palabras reservadas y disponibilidad de un slug candidato, sin reservarlo (D-164).';

-- ----------------------------------------------------------------------------
-- 10. `update_tenant_slug`: autoservicio, exclusivo de owner/admin del
--     propio negocio (mismo criterio que `update_tenant_contact_info`,
--     D-162).
-- ----------------------------------------------------------------------------

create or replace function public.update_tenant_slug(p_new_slug text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_slug text := lower(trim(coalesce(p_new_slug, '')));
  v_reserved constant text[] := array[
    'login', 'register', 'auth', 'planes', 'pricing', 'terminos',
    'privacidad', 'terms', 'privacy', 'admin', 'dashboard', 'settings',
    'soporte', 'api'
  ];
begin
  v_tenant_id := public.get_my_tenant_id();

  if v_tenant_id is null then
    raise exception 'No existe un perfil activo asociado al usuario actual.';
  end if;

  if not public.is_owner_or_admin() then
    raise exception 'No autorizado. Solo el propietario o un administrador puede cambiar el enlace del negocio.';
  end if;

  if v_slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$' or length(v_slug) < 3 or length(v_slug) > 50 then
    raise exception 'El enlace debe tener entre 3 y 50 caracteres: solo minusculas, numeros y guiones, sin empezar ni terminar en guion.';
  end if;

  if v_slug = any(v_reserved) then
    raise exception 'Ese enlace esta reservado por el sistema. Elige otro.';
  end if;

  if exists (select 1 from public.tenants where slug = v_slug and id <> v_tenant_id) then
    raise exception 'Ese enlace ya esta en uso por otro negocio.';
  end if;

  update public.tenants set slug = v_slug where id = v_tenant_id;

  return v_slug;
end;
$$;

revoke all on function public.update_tenant_slug(text) from public, anon;
grant execute on function public.update_tenant_slug(text) to authenticated;

comment on function public.update_tenant_slug(text) is
  'Cambia el slug público del negocio propio, validando formato, reservas y disponibilidad (D-164). Exclusivo de owner/admin.';

commit;
