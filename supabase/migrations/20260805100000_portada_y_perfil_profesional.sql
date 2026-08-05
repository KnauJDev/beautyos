-- BeautyOS - Punto 6 de BENCHMARKING_2026-07-28.md: portada del negocio +
-- foto/bio del profesional en reserva publica.
--
-- Alcance acordado con el propietario:
-- - Portada a nivel de negocio completo (tenant), mismo patron que el logo
--   de D-077, no por sede.
-- - Foto y biografia del profesional: solo tenant_owner/admin puede
--   subirla/editarla (mismo criterio que create_stylist/update_stylist ya
--   usan hoy), sin autogestion del propio estilista en este bloque.

begin;

-- ============================================================
-- 1. Portada del negocio (banner), igual patron que logo_url (D-077).
-- ============================================================

alter table public.tenants
  add column if not exists cover_photo_url text;

comment on column public.tenants.cover_photo_url
  is 'URL publica de la foto de portada del negocio en el bucket tenant-covers. Null si no ha subido portada.';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'tenant-covers',
  'tenant-covers',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

-- Reutiliza la misma autorizacion de D-077 (tenant_owner del tenant exacto
-- de la carpeta); la funcion no es especifica de un bucket, solo valida rol.
create policy "tenant_covers_insert_owner"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'tenant-covers'
  and array_length(storage.foldername(name), 1) = 1
  and private.beautyos_can_upload_tenant_logo(
    (storage.foldername(name))[1]::uuid
  )
);

comment on function private.beautyos_can_upload_tenant_logo(uuid)
  is 'Autoriza subida a storage.objects en tenant-logos y tenant-covers: exclusivo de tenant_owner del tenant exacto de la carpeta.';

create or replace function public.update_tenant_cover_photo(
  p_cover_photo_url text
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
    raise exception 'Solo el propietario del negocio puede cambiar la portada.';
  end if;

  if p_cover_photo_url is null or trim(p_cover_photo_url) = '' then
    raise exception 'La URL de la portada no puede estar vacia.';
  end if;

  update public.tenants
  set cover_photo_url = trim(p_cover_photo_url)
  where id = v_tenant_id;
end;
$$;

revoke all on function public.update_tenant_cover_photo(text)
  from public, anon, authenticated;
grant execute on function public.update_tenant_cover_photo(text)
  to authenticated;

comment on function public.update_tenant_cover_photo(text)
  is 'Guarda la URL publica de la portada del negocio ya subida a tenant-covers. Exclusivo de tenant_owner.';

-- Extender get_business_settings (Configuracion) con cover_photo_url.
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
  cover_photo_url text
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
    t.cover_photo_url
  from public.tenants t
  where t.id = current_tenant_id
    and t.active = true
  limit 1;
end;
$$;

revoke execute on function public.get_business_settings() from anon;
revoke execute on function public.get_business_settings() from public;
grant execute on function public.get_business_settings() to authenticated;

-- Extender public_get_branch_booking_info (reserva publica) con cover_photo_url.
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
  cover_photo_url text
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
    t.cover_photo_url
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
  is 'Datos publicos de la sede para la pagina de reserva. Sin sesion. Incluye logo_url y cover_photo_url del tenant.';

-- ============================================================
-- 2. Foto y biografia del profesional.
-- ============================================================

alter table public.stylists
  add column if not exists photo_url text,
  add column if not exists bio text;

comment on column public.stylists.photo_url
  is 'URL publica de la foto del profesional en el bucket stylist-photos. Null si no ha subido foto.';
comment on column public.stylists.bio
  is 'Biografia corta del profesional, visible en la reserva publica. Null si no se ha escrito.';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'stylist-photos',
  'stylist-photos',
  true,
  2097152,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

-- Ruta esperada: {tenant_id}/{stylist_id}/archivo.ext
create or replace function private.beautyos_can_manage_stylist_photo(
  p_tenant_id uuid,
  p_stylist_id uuid
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
    join public.stylists st
      on st.tenant_id = tm.tenant_id
     and st.id = p_stylist_id
    where tm.tenant_id = p_tenant_id
      and tm.user_id = auth.uid()
      and tm.active
      and tm.starts_at <= now()
      and (tm.ends_at is null or tm.ends_at > now())
      and tm.role in ('tenant_owner', 'admin')
  );
$$;

revoke all on function private.beautyos_can_manage_stylist_photo(uuid, uuid)
  from public, anon, authenticated;
grant execute on function private.beautyos_can_manage_stylist_photo(uuid, uuid)
  to authenticated;

comment on function private.beautyos_can_manage_stylist_photo(uuid, uuid)
  is 'Autoriza subida a storage.objects en stylist-photos: tenant_owner o admin del tenant exacto de la carpeta, y el estilista debe pertenecer a ese tenant.';

create policy "stylist_photos_insert_owner_admin"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'stylist-photos'
  and array_length(storage.foldername(name), 1) = 2
  and private.beautyos_can_manage_stylist_photo(
    (storage.foldername(name))[1]::uuid,
    (storage.foldername(name))[2]::uuid
  )
);

-- create_stylist gana p_bio. El tipo de retorno no cambia, pero la lista de
-- parametros si (identidad de la funcion en Postgres) -- se elimina la firma
-- vieja primero para no dejar dos funciones sobrecargadas coexistiendo, lo
-- que confundiria a PostgREST al resolver la llamada desde Flutter.
drop function if exists public.create_stylist(uuid, text, text, text);

create or replace function public.create_stylist(
  p_branch_id uuid,
  p_name text,
  p_phone text default null,
  p_specialty text default null,
  p_bio text default null
)
returns table (stylist_id uuid, branch_stylist_id uuid)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_stylist_id uuid;
  v_branch_stylist_id uuid;
begin
  select tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner', 'admin'], true
  );

  if length(trim(coalesce(p_name, ''))) = 0 then
    raise exception 'El nombre del estilista es obligatorio.';
  end if;

  insert into public.stylists (tenant_id, name, phone, specialty, bio)
  values (
    v_tenant_id,
    trim(p_name),
    nullif(trim(coalesce(p_phone, '')), ''),
    nullif(trim(coalesce(p_specialty, '')), ''),
    nullif(trim(coalesce(p_bio, '')), '')
  )
  returning id into v_stylist_id;

  insert into public.branch_stylists (tenant_id, branch_id, stylist_id)
  values (v_tenant_id, p_branch_id, v_stylist_id)
  returning id into v_branch_stylist_id;

  return query select v_stylist_id, v_branch_stylist_id;
end;
$$;

revoke all on function public.create_stylist(uuid, text, text, text, text)
  from public, anon;
grant execute on function public.create_stylist(uuid, text, text, text, text)
  to authenticated, service_role;

-- update_stylist gana p_photo_url y p_bio, mismo motivo de drop que arriba.
drop function if exists public.update_stylist(uuid, uuid, text, text, text);

create or replace function public.update_stylist(
  p_branch_id uuid,
  p_stylist_id uuid,
  p_name text,
  p_phone text default null,
  p_specialty text default null,
  p_photo_url text default null,
  p_bio text default null
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner', 'admin'], true
  );

  if length(trim(coalesce(p_name, ''))) = 0 then
    raise exception 'El nombre del estilista es obligatorio.';
  end if;

  update public.stylists
     set name = trim(p_name),
         phone = nullif(trim(coalesce(p_phone, '')), ''),
         specialty = nullif(trim(coalesce(p_specialty, '')), ''),
         photo_url = nullif(trim(coalesce(p_photo_url, '')), ''),
         bio = nullif(trim(coalesce(p_bio, '')), '')
   where id = p_stylist_id
     and tenant_id = v_tenant_id;

  if not found then
    raise exception 'El estilista no existe o pertenece a otro negocio.';
  end if;
end;
$$;

revoke all on function public.update_stylist(uuid, uuid, text, text, text, text, text)
  from public, anon;
grant execute on function public.update_stylist(uuid, uuid, text, text, text, text, text)
  to authenticated, service_role;

-- get_stylists_for_management gana photo_url y bio (sin coalesce a texto de
-- relleno: se necesitan crudos para precargar el formulario de edicion).
drop function if exists public.get_stylists_for_management(uuid);

create or replace function public.get_stylists_for_management(
  p_branch_id uuid
)
returns table (
  stylist_id uuid,
  name text,
  phone text,
  specialty text,
  active boolean,
  photo_url text,
  bio text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner', 'admin'], true
  );

  return query
  select
    st.id,
    st.name,
    coalesce(st.phone, 'Sin telefono'),
    coalesce(st.specialty, 'Sin especialidad'),
    st.active and coalesce(bst.active, false),
    st.photo_url,
    st.bio
  from public.stylists st
  left join public.branch_stylists bst
    on bst.tenant_id = v_tenant_id
   and bst.branch_id = p_branch_id
   and bst.stylist_id = st.id
  where st.tenant_id = v_tenant_id
  order by lower(st.name);
end;
$$;

revoke all on function public.get_stylists_for_management(uuid)
  from public, anon, authenticated;
grant execute on function public.get_stylists_for_management(uuid)
  to authenticated;

-- public_get_bookable_services gana stylist_photo_url y stylist_bio.
drop function if exists public.public_get_bookable_services(uuid);

create or replace function public.public_get_bookable_services(
  p_branch_id uuid
)
returns table (
  service_id uuid,
  service_name text,
  category text,
  price numeric,
  duration_minutes integer,
  stylist_id uuid,
  stylist_name text,
  stylist_photo_url text,
  stylist_bio text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select t.id
    into v_tenant_id
  from public.branches b
  join public.tenants t
    on t.id = b.tenant_id
  where b.id = p_branch_id
    and t.active
    and b.active;

  if not found then
    raise exception 'Este negocio no esta disponible para reservas en este momento.';
  end if;

  return query
  select
    s.id,
    s.name,
    coalesce(s.category, 'Sin categoria'),
    bs.price,
    bs.duration_minutes,
    st.id,
    st.name,
    st.photo_url,
    st.bio
  from public.branch_services bs
  join public.services s
    on s.tenant_id = bs.tenant_id
   and s.id = bs.service_id
   and s.active
  join public.branch_stylist_services bss
    on bss.tenant_id = bs.tenant_id
   and bss.branch_id = bs.branch_id
   and bss.branch_service_id = bs.id
   and bss.active
  join public.branch_stylists bst
    on bst.tenant_id = bss.tenant_id
   and bst.branch_id = bss.branch_id
   and bst.id = bss.branch_stylist_id
   and bst.active
   and bst.starts_at <= now()
   and (bst.ends_at is null or bst.ends_at > now())
  join public.stylists st
    on st.tenant_id = bst.tenant_id
   and st.id = bst.stylist_id
   and st.active
  where bs.tenant_id = v_tenant_id
    and bs.branch_id = p_branch_id
    and bs.active
    and s.visible_to_customer
    and bs.visible_to_customer
  order by s.name, st.name;
end;
$$;

revoke all on function public.public_get_bookable_services(uuid)
  from public, authenticated;
grant execute on function public.public_get_bookable_services(uuid)
  to anon, service_role;

comment on function public.public_get_bookable_services(uuid)
  is 'Servicios reservables de una sede, con foto y bio del profesional para la reserva publica.';

commit;
