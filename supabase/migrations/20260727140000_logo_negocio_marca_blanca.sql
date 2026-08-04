-- BeautyOS - Logo por negocio (marca blanca, punto 4.4 de RUTA_GENERAL_2026-07-25.md).
--
-- Alcance acordado con el propietario: solo logo (sin colores, sin cambio de
-- disposicion visual -- eso queda para el benchmarking del punto 5, "Pulido
-- general"). Solo tenant_owner puede subir/cambiar el logo. Se muestra en:
-- reserva publica, enlace de resena publica, y el panel interno (para todos
-- los roles, via get_my_branch_context_v2 que ya se carga al abrir la app).
--
-- Reutiliza el mismo patron de Storage ya probado en D-060/D-061
-- (work-photos): bucket publico, subida directa cliente->bucket, politica
-- RLS sobre storage.objects. A diferencia de las fotos de trabajo (por
-- sede), el logo es del negocio completo: la ruta es {tenant_id}/archivo.ext.

begin;

-- 1. Columna nueva en tenants.
alter table public.tenants
  add column if not exists logo_url text;

comment on column public.tenants.logo_url
  is 'URL publica del logo del negocio en el bucket tenant-logos. Null si el negocio no ha subido logo.';

-- 2. Bucket de Storage para logos.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'tenant-logos',
  'tenant-logos',
  true,
  2097152,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

-- 3. Autorizacion de subida: solo tenant_owner del tenant exacto de la carpeta.
create or replace function private.beautyos_can_upload_tenant_logo(
  p_tenant_id uuid
)
returns boolean
language sql
security definer
set search_path = pg_catalog
stable
as $$
  select exists (
    select 1
    from public.tenant_memberships tm
    where tm.tenant_id = p_tenant_id
      and tm.user_id = auth.uid()
      and tm.active
      and tm.starts_at <= now()
      and (tm.ends_at is null or tm.ends_at > now())
      and tm.role = 'tenant_owner'
  );
$$;

revoke all on function private.beautyos_can_upload_tenant_logo(uuid)
  from public, anon, authenticated;
grant execute on function private.beautyos_can_upload_tenant_logo(uuid)
  to authenticated;

comment on function private.beautyos_can_upload_tenant_logo(uuid)
  is 'Autoriza subida a storage.objects en tenant-logos: exclusivo de tenant_owner del tenant exacto de la carpeta.';

-- Ruta esperada del archivo: {tenant_id}/{uuid}.{ext}
create policy "tenant_logos_insert_owner"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'tenant-logos'
  and array_length(storage.foldername(name), 1) = 1
  and private.beautyos_can_upload_tenant_logo(
    (storage.foldername(name))[1]::uuid
  )
);

-- 4. RPC para guardar la URL una vez subida (mismo patron que create_branch:
-- get_my_tenant_id + get_my_role, exclusivo de tenant_owner).
create or replace function public.update_tenant_logo(
  p_logo_url text
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  v_tenant_id := public.get_my_tenant_id();

  if v_tenant_id is null or public.get_my_role() <> 'tenant_owner' then
    raise exception 'Solo el propietario del negocio puede cambiar el logo.';
  end if;

  if p_logo_url is null or trim(p_logo_url) = '' then
    raise exception 'La URL del logo no puede estar vacia.';
  end if;

  update public.tenants
  set logo_url = trim(p_logo_url)
  where id = v_tenant_id;
end;
$$;

revoke all on function public.update_tenant_logo(text)
  from public, anon, authenticated;
grant execute on function public.update_tenant_logo(text)
  to authenticated;

comment on function public.update_tenant_logo(text)
  is 'Guarda la URL publica del logo del negocio ya subido a tenant-logos. Exclusivo de tenant_owner.';

-- 5. Extender get_business_settings (pantalla Configuracion) con logo_url.
-- DROP requerido: create or replace no permite agregar columnas a RETURNS TABLE.
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
  logo_url text
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
    t.logo_url
  from public.tenants t
  where t.id = current_tenant_id
    and t.active = true
  limit 1;
end;
$$;

revoke execute on function public.get_business_settings() from anon;
revoke execute on function public.get_business_settings() from public;

grant execute on function public.get_business_settings() to authenticated;

-- 6. Extender get_my_branch_context_v2 (se carga para todos los roles al
-- abrir la app) con logo_url, para pintarlo en el encabezado interno.
drop function if exists public.get_my_branch_context_v2();

create or replace function public.get_my_branch_context_v2()
returns table (
  tenant_id uuid,
  tenant_name text,
  tenant_logo_url text,
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
  is 'Lista exclusivamente las sedes activas que el usuario puede seleccionar. Incluye tenant_logo_url para pintar marca blanca en el panel interno.';

-- 7. Extender public_get_branch_booking_info (reserva publica) con logo_url.
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
  logo_url text
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
    t.logo_url
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
  is 'Datos publicos de la sede para la pagina de reserva. Sin sesion. Incluye logo_url del tenant.';

-- 8. Extender public_get_ticket_for_review (enlace de resena publica) con
-- logo_url -- necesita join nuevo contra tenants via branches.
drop function if exists public.public_get_ticket_for_review(uuid);

create or replace function public.public_get_ticket_for_review(
  p_ticket_id uuid
)
returns table (
  ticket_id uuid,
  branch_name text,
  client_name text,
  ticket_status text,
  reviewable boolean,
  already_reviewed boolean,
  services jsonb,
  logo_url text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_status text;
  v_client_name text;
  v_branch_name text;
  v_already_reviewed boolean;
  v_services jsonb;
  v_logo_url text;
begin
  select tk.status, c.name, b.name, t.logo_url
    into v_status, v_client_name, v_branch_name, v_logo_url
  from public.tickets tk
  join public.clients c on c.id = tk.client_id
  join public.branches b on b.id = tk.branch_id
  join public.tenants t on t.id = b.tenant_id
  where tk.id = p_ticket_id;

  if not found then
    raise exception 'Este enlace de resena no es valido.';
  end if;

  select exists(
    select 1
    from public.reviews r
    where r.ticket_id = p_ticket_id
      and r.active
  ) into v_already_reviewed;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'service_id', s.id,
        'service_name', s.name,
        'stylist_id', st.id,
        'stylist_name', st.name
      )
      order by s.name
    ),
    '[]'::jsonb
  )
    into v_services
  from public.ticket_services ts
  join public.services s
    on s.id = ts.service_id
  left join public.stylists st
    on st.id = ts.stylist_id
  where ts.ticket_id = p_ticket_id;

  return query
  select
    p_ticket_id,
    v_branch_name,
    v_client_name,
    v_status,
    (v_status in ('finalizado', 'cerrado')) and not v_already_reviewed,
    v_already_reviewed,
    v_services,
    v_logo_url;
end;
$$;

revoke all on function public.public_get_ticket_for_review(uuid)
  from public, authenticated;
grant execute on function public.public_get_ticket_for_review(uuid)
  to anon, service_role;

comment on function public.public_get_ticket_for_review(uuid)
  is 'Datos minimos de un ticket para la pagina publica de resena. Sin sesion. Incluye logo_url del tenant.';

commit;
