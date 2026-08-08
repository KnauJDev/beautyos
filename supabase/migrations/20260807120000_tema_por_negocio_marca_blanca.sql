-- Salon y Mas - Tema por negocio (marca blanca por colores, tarea 2.4).
--
-- Cierra la mitad que faltaba de D-093: el logo por negocio existe desde D-062
-- (20260727140000), los colores no. Esta migracion agrega el "que" -- el dato
-- guardado --; el "como se pinta" vive en lib/theme/app_brand.dart.
--
-- Decisiones que gobiernan este archivo:
--
-- * D-093b: se guarda el **nombre** del tema, no los codigos de color. Asi, al
--   afinar un tema, mejoran solos todos los negocios que lo usan. Guardar el
--   hex los congelaria con los errores del dia que lo eligieron.
-- * D-093c: el tema es del **negocio**, no de la sede. Por eso vive en
--   `tenants` y no en `branches`.
-- * D-109: ademas de los cinco temas verificados a mano se admite
--   `personalizado`, donde el propietario elige **un** color y la aplicacion
--   deriva los otros cinco tonos. Solo en ese caso se guarda un hex, en
--   `brand_color`. El argumento original de D-093a (un dueno puede elegir una
--   combinacion ilegible) dejo de aplicar cuando D-097 saco los colores de
--   estado de la marca blanca y D-100d encerro el color de marca en la barra,
--   los titulos, los botones y las selecciones.
-- * D-097: los colores de estado quedan FUERA. Ninguna columna de aqui los
--   toca: el ambar significa "pendiente" en todos los negocios.
--
-- Se reutiliza el patron ya probado del logo: columna en tenants + RPC
-- exclusiva de tenant_owner + extender las tres funciones de lectura que ya
-- transportan logo_url (Configuracion, contexto de sede, reserva publica).

begin;

-- ---------------------------------------------------------------------------
-- 1. Columnas nuevas en tenants.
-- ---------------------------------------------------------------------------

alter table public.tenants
  add column if not exists theme_key text not null default 'morado';

alter table public.tenants
  add column if not exists brand_color text;

comment on column public.tenants.theme_key
  is 'Nombre del tema de marca blanca del negocio (D-093b). Uno de los cinco verificados o "personalizado". Nunca guarda colores: los hex viven en la aplicacion.';

comment on column public.tenants.brand_color
  is 'Color de marca elegido por el propietario, en #RRGGBB. Solo se usa cuando theme_key = personalizado (D-109); null en los cinco temas predefinidos.';

-- Los cinco nombres tienen que coincidir exactamente con las claves de
-- AppBrand en lib/theme/app_brand.dart. Si algun dia se agrega un tema, se
-- agrega en los dos sitios o el negocio se queda con el morado por defecto.
alter table public.tenants
  drop constraint if exists tenants_theme_key_valido;

alter table public.tenants
  add constraint tenants_theme_key_valido
  check (
    theme_key in (
      'morado',
      'barberia',
      'spa_unas',
      'clasica',
      'canina',
      'personalizado'
    )
  );

-- El hex se valida aqui y no solo en la pantalla: la RPC es la unica puerta,
-- pero una columna que acepta basura acaba con basura dentro tarde o temprano.
alter table public.tenants
  drop constraint if exists tenants_brand_color_valido;

alter table public.tenants
  add constraint tenants_brand_color_valido
  check (brand_color is null or brand_color ~ '^#[0-9A-Fa-f]{6}$');

-- Un tema personalizado sin color es un negocio sin barra superior. Y al
-- reves: un tema predefinido con hex guardado seria justo lo que D-093b
-- prohibe, un negocio congelado con colores viejos.
alter table public.tenants
  drop constraint if exists tenants_brand_color_solo_personalizado;

alter table public.tenants
  add constraint tenants_brand_color_solo_personalizado
  check (
    (theme_key = 'personalizado' and brand_color is not null)
    or (theme_key <> 'personalizado' and brand_color is null)
  );

-- ---------------------------------------------------------------------------
-- 2. RPC para cambiarlo. Exclusiva de tenant_owner, igual que el logo y la
--    portada: la identidad visual del negocio no es una preferencia de quien
--    esta en el mostrador.
-- ---------------------------------------------------------------------------

create or replace function public.update_tenant_theme(
  p_theme_key text,
  p_brand_color text default null
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_theme_key text;
  v_brand_color text;
begin
  v_tenant_id := public.get_my_tenant_id();

  if v_tenant_id is null or public.get_my_role() <> 'tenant_owner' then
    raise exception 'Solo el propietario del negocio puede cambiar el tema.';
  end if;

  v_theme_key := lower(trim(coalesce(p_theme_key, '')));

  if v_theme_key not in (
    'morado', 'barberia', 'spa_unas', 'clasica', 'canina', 'personalizado'
  ) then
    raise exception 'El tema "%" no existe.', p_theme_key;
  end if;

  if v_theme_key = 'personalizado' then
    v_brand_color := upper(trim(coalesce(p_brand_color, '')));

    if v_brand_color !~ '^#[0-9A-F]{6}$' then
      raise exception 'El color personalizado debe venir en formato #RRGGBB.';
    end if;
  else
    -- Se descarta a proposito el color que venga: si el negocio vuelve a un
    -- tema predefinido, dejar el hex guardado lo reviviria sin querer la
    -- proxima vez que alguien toque esta fila.
    v_brand_color := null;
  end if;

  update public.tenants
  set theme_key = v_theme_key,
      brand_color = v_brand_color
  where id = v_tenant_id;
end;
$$;

revoke all on function public.update_tenant_theme(text, text)
  from public, anon, authenticated;
grant execute on function public.update_tenant_theme(text, text)
  to authenticated;

comment on function public.update_tenant_theme(text, text)
  is 'Cambia el tema de marca blanca del negocio. Exclusivo de tenant_owner. El color solo se guarda con theme_key = personalizado.';

-- ---------------------------------------------------------------------------
-- 3. Extender get_business_settings (pantalla Configuracion), que es donde
--    vive el selector.
--    DROP requerido: create or replace no permite agregar columnas a
--    RETURNS TABLE.
-- ---------------------------------------------------------------------------

drop function if exists public.get_business_settings();

create or replace function public.get_business_settings()
returns table (
  id uuid,
  name text,
  business_type text,
  contact_email text,
  contact_phone text,
  whatsapp text,
  instagram text,
  facebook text,
  logo_url text,
  cover_photo_url text,
  theme_key text,
  brand_color text
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
    t.business_type,
    t.contact_email,
    t.contact_phone,
    t.whatsapp,
    t.instagram,
    t.facebook,
    t.logo_url,
    t.cover_photo_url,
    t.theme_key,
    t.brand_color
  from public.tenants t
  where t.id = current_tenant_id
    and t.active = true
  limit 1;
end;
$$;

revoke execute on function public.get_business_settings() from anon;
revoke execute on function public.get_business_settings() from public;
grant execute on function public.get_business_settings() to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Extender get_my_branch_context_v2, que se carga para TODOS los roles al
--    abrir la app. Es el mismo transporte que ya usa el logo: si el tema
--    viajara por su propia consulta, la app se pintaria morada y cambiaria de
--    color medio segundo despues.
-- ---------------------------------------------------------------------------

drop function if exists public.get_my_branch_context_v2();

create or replace function public.get_my_branch_context_v2()
returns table (
  tenant_id uuid,
  tenant_name text,
  tenant_logo_url text,
  tenant_theme_key text,
  tenant_brand_color text,
  branch_id uuid,
  branch_name text,
  branch_slug text,
  role text,
  stylist_id uuid,
  timezone text,
  currency_code text,
  is_primary boolean,
  option_count integer
)
language sql
security definer
set search_path = pg_catalog
as $$
  with accessible as (
    select
      tm.tenant_id,
      t.name as tenant_name,
      t.logo_url as tenant_logo_url,
      t.theme_key as tenant_theme_key,
      t.brand_color as tenant_brand_color,
      b.id as branch_id,
      b.name as branch_name,
      b.slug as branch_slug,
      tm.role,
      tm.stylist_id,
      b.timezone,
      b.currency_code,
      b.is_primary
    from public.tenant_memberships tm
    join public.tenants t
      on t.id = tm.tenant_id
     and t.active
    join public.branches b
      on b.tenant_id = tm.tenant_id
     and b.active
    where tm.user_id = auth.uid()
      and tm.active
      and tm.starts_at <= now()
      and (tm.ends_at is null or tm.ends_at > now())
      and (
        tm.role = 'tenant_owner'
        or exists (
          select 1
          from public.branch_memberships bm
          where bm.tenant_id = tm.tenant_id
            and bm.branch_id = b.id
            and bm.tenant_membership_id = tm.id
            and bm.active
            and bm.starts_at <= now()
            and (bm.ends_at is null or bm.ends_at > now())
        )
      )
      and (
        tm.role <> 'stylist'
        or exists (
          select 1
          from public.branch_stylists bst
          where bst.tenant_id = tm.tenant_id
            and bst.branch_id = b.id
            and bst.stylist_id = tm.stylist_id
            and bst.active
            and bst.starts_at <= now()
            and (bst.ends_at is null or bst.ends_at > now())
        )
      )
  )
  select
    a.tenant_id,
    a.tenant_name,
    a.tenant_logo_url,
    a.tenant_theme_key,
    a.tenant_brand_color,
    a.branch_id,
    a.branch_name,
    a.branch_slug,
    a.role,
    a.stylist_id,
    a.timezone,
    a.currency_code,
    a.is_primary,
    count(*) over ()::integer as option_count
  from accessible a
  order by a.tenant_name, a.is_primary desc, a.branch_name, a.branch_id;
$$;

revoke all on function public.get_my_branch_context_v2()
  from public, anon, authenticated;
grant execute on function public.get_my_branch_context_v2()
  to authenticated, service_role;

comment on function public.get_my_branch_context_v2()
  is 'Lista exclusivamente las sedes activas que el usuario puede seleccionar. Incluye logo y tema del negocio para pintar la marca blanca desde el primer fotograma.';

-- ---------------------------------------------------------------------------
-- 5. Extender public_get_branch_booking_info (reserva publica). D-093d: el
--    tema aplica tambien aqui, que es la pagina mas valiosa para el negocio
--    porque la ven sus propios clientes.
-- ---------------------------------------------------------------------------

drop function if exists public.public_get_branch_booking_info(uuid);

create or replace function public.public_get_branch_booking_info(
  p_branch_id uuid
)
returns table (
  branch_id uuid,
  tenant_id uuid,
  business_name text,
  branch_name text,
  address text,
  city text,
  whatsapp text,
  timezone text,
  currency_code text,
  logo_url text,
  cover_photo_url text,
  theme_key text,
  brand_color text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  return query
  select
    b.id,
    t.id,
    t.name,
    b.name,
    b.address,
    b.city,
    coalesce(b.whatsapp, t.whatsapp),
    b.timezone,
    b.currency_code,
    t.logo_url,
    t.cover_photo_url,
    t.theme_key,
    t.brand_color
  from public.branches b
  join public.tenants t
    on t.id = b.tenant_id
  where b.id = p_branch_id
    and t.active
    and b.active;

  if not found then
    raise exception 'Este negocio no esta disponible para reservas en este momento.';
  end if;
end;
$$;

revoke all on function public.public_get_branch_booking_info(uuid)
  from public, authenticated;
grant execute on function public.public_get_branch_booking_info(uuid)
  to anon, service_role;

comment on function public.public_get_branch_booking_info(uuid)
  is 'Datos publicos de la sede para la pagina de reserva. Sin sesion. Incluye logo, portada y tema del negocio.';

commit;
