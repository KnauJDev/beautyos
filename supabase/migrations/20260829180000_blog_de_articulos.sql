-- Paso 6.6 del Plan Maestro (D-171): "Blog de artículos de belleza y
-- estética" -- blog POR CADA SALÓN (decisión confirmada con el
-- propietario antes de construir, `AskUserQuestion`): cada negocio escribe
-- sus propios artículos y aparecen en su página pública, junto al
-- portafolio y las reseñas -- coherente con el resto de la Fase 6, que son
-- todo funciones que cada salón usa para su propio marketing.
--
-- Alcance de esta primera versión, también confirmado con el propietario:
-- SIN url propia por articulo todavia. Se navega solo desde dentro de la
-- página pública del negocio (Navigator.push, mismo patrón que la reserva
-- y las reseñas de D-165); un enlace directo a un artículo queda para un
-- bloque futuro si hace falta.
--
-- A nivel de TENANT, no de sede -- mismo criterio que D-165 (portafolio,
-- reseñas, equipo): la Fase 5/6 sigue siendo un perfil por negocio.

begin;

-- ----------------------------------------------------------------------------
-- 1. Tabla. Contenido en texto plano por párrafos (sin editor de texto
--    enriquecido, coherente con el resto de la app, que no usa ninguno).
-- ----------------------------------------------------------------------------

create table public.blog_posts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  title text not null,
  content text not null,
  cover_photo_url text,
  published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index blog_posts_tenant_created_idx
  on public.blog_posts (tenant_id, created_at desc);

-- Sin políticas de authenticated/anon a propósito -- mismo criterio que
-- reviews/work_photos: todo el acceso pasa por RPC security definer, la
-- tabla en sí queda cerrada por RLS sin excepciones.
alter table public.blog_posts enable row level security;

comment on table public.blog_posts is
  'Artículos del blog de cada negocio (paso 6.6, D-171). A nivel de tenant, no de sede.';

-- ----------------------------------------------------------------------------
-- 2. Storage: bucket público `blog-covers`, mismo patrón que
--    tenant-covers/stylist-photos (D-084/D-086/D-119).
-- ----------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'blog-covers',
  'blog-covers',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

-- Ruta esperada: {tenant_id}/archivo.ext -- un solo nivel de carpeta, igual
-- que tenant-covers.
create or replace function private.beautyos_can_manage_blog_post(
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
      and tm.role in ('tenant_owner', 'admin')
  );
$$;

revoke all on function private.beautyos_can_manage_blog_post(uuid)
  from public, anon, authenticated;
grant execute on function private.beautyos_can_manage_blog_post(uuid)
  to authenticated;

comment on function private.beautyos_can_manage_blog_post(uuid) is
  'Autoriza subir/borrar portadas de blog en blog-covers y escribir en blog_posts: tenant_owner o admin del tenant exacto (paso 6.6, D-171).';

create policy blog_covers_insert_owner_admin
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'blog-covers'
    and array_length(storage.foldername(name), 1) = 1
    and private.beautyos_can_manage_blog_post(
      (storage.foldername(name))[1]::uuid
    )
  );

create policy blog_covers_delete_owner_admin
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'blog-covers'
    and array_length(storage.foldername(name), 1) = 1
    and private.beautyos_can_manage_blog_post(
      (storage.foldername(name))[1]::uuid
    )
  );

-- ----------------------------------------------------------------------------
-- 3. RPC de administración -- autoservicio, sin p_branch_id (mismo criterio
--    que update_tenant_contact_info/update_tenant_slug: dato de tenant, no
--    de sede).
-- ----------------------------------------------------------------------------

create or replace function public.create_blog_post(
  p_title text,
  p_content text,
  p_cover_photo_url text default null,
  p_published boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_post_id uuid;
begin
  v_tenant_id := public.get_my_tenant_id();

  if v_tenant_id is null or not public.is_owner_or_admin() then
    raise exception 'No autorizado. Solo owner o admin puede escribir en el blog.';
  end if;

  if p_title is null or trim(p_title) = '' then
    raise exception 'El título no puede estar vacío.';
  end if;

  if p_content is null or trim(p_content) = '' then
    raise exception 'El contenido no puede estar vacío.';
  end if;

  insert into public.blog_posts (tenant_id, title, content, cover_photo_url, published)
  values (v_tenant_id, trim(p_title), trim(p_content), p_cover_photo_url, p_published)
  returning id into v_post_id;

  return v_post_id;
end;
$$;

create or replace function public.update_blog_post(
  p_post_id uuid,
  p_title text,
  p_content text,
  p_cover_photo_url text,
  p_published boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
begin
  v_tenant_id := public.get_my_tenant_id();

  if v_tenant_id is null or not public.is_owner_or_admin() then
    raise exception 'No autorizado. Solo owner o admin puede editar el blog.';
  end if;

  if p_title is null or trim(p_title) = '' then
    raise exception 'El título no puede estar vacío.';
  end if;

  if p_content is null or trim(p_content) = '' then
    raise exception 'El contenido no puede estar vacío.';
  end if;

  update public.blog_posts
  set title = trim(p_title),
      content = trim(p_content),
      cover_photo_url = p_cover_photo_url,
      published = p_published,
      updated_at = now()
  where id = p_post_id
    and tenant_id = v_tenant_id;

  if not found then
    raise exception 'Este artículo no existe o no pertenece a tu negocio.';
  end if;
end;
$$;

create or replace function public.delete_blog_post(
  p_post_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
begin
  v_tenant_id := public.get_my_tenant_id();

  if v_tenant_id is null or not public.is_owner_or_admin() then
    raise exception 'No autorizado. Solo owner o admin puede borrar del blog.';
  end if;

  delete from public.blog_posts
  where id = p_post_id
    and tenant_id = v_tenant_id;

  if not found then
    raise exception 'Este artículo no existe o no pertenece a tu negocio.';
  end if;
end;
$$;

create or replace function public.get_blog_posts_summary()
returns table (
  id uuid,
  title text,
  content text,
  cover_photo_url text,
  published boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
begin
  v_tenant_id := public.get_my_tenant_id();

  if v_tenant_id is null or not public.is_owner_or_admin() then
    raise exception 'No autorizado. Solo owner o admin puede ver el blog.';
  end if;

  return query
  select bp.id, bp.title, bp.content, bp.cover_photo_url, bp.published,
         bp.created_at, bp.updated_at
  from public.blog_posts bp
  where bp.tenant_id = v_tenant_id
  order by bp.created_at desc;
end;
$$;

revoke all on function public.create_blog_post(text, text, text, boolean)
  from public, anon, authenticated;
grant execute on function public.create_blog_post(text, text, text, boolean)
  to authenticated;

revoke all on function public.update_blog_post(uuid, text, text, text, boolean)
  from public, anon, authenticated;
grant execute on function public.update_blog_post(uuid, text, text, text, boolean)
  to authenticated;

revoke all on function public.delete_blog_post(uuid)
  from public, anon, authenticated;
grant execute on function public.delete_blog_post(uuid)
  to authenticated;

revoke all on function public.get_blog_posts_summary()
  from public, anon, authenticated;
grant execute on function public.get_blog_posts_summary()
  to authenticated;

comment on function public.create_blog_post(text, text, text, boolean) is
  'Crea un artículo de blog para el negocio propio. Solo owner o admin (paso 6.6, D-171).';
comment on function public.update_blog_post(uuid, text, text, text, boolean) is
  'Edita un artículo propio (título, contenido, portada, publicado). Solo owner o admin.';
comment on function public.delete_blog_post(uuid) is
  'Borra un artículo propio. Solo owner o admin.';
comment on function public.get_blog_posts_summary() is
  'Lista todos los artículos del negocio propio (publicados y borrador). Solo owner o admin.';

-- ----------------------------------------------------------------------------
-- 4. RPC pública -- sin sesión, solo artículos publicados. Sin url propia
--    por artículo en esta versión: Flutter trae la lista completa (con
--    contenido) para la sección "Blog" de la página del negocio.
-- ----------------------------------------------------------------------------

create or replace function public.get_public_salon_blog_posts(p_tenant_id uuid)
returns table (
  id uuid,
  title text,
  content text,
  cover_photo_url text,
  created_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select bp.id, bp.title, bp.content, bp.cover_photo_url, bp.created_at
  from public.blog_posts bp
  join public.tenants t
    on t.id = bp.tenant_id
   and t.active = true
  where bp.tenant_id = p_tenant_id
    and bp.published = true
  order by bp.created_at desc
  limit 20;
$$;

revoke all on function public.get_public_salon_blog_posts(uuid) from public;
grant execute on function public.get_public_salon_blog_posts(uuid) to anon, authenticated;

comment on function public.get_public_salon_blog_posts(uuid) is
  'Últimos 20 artículos publicados de un negocio, sin sesión (paso 6.6, D-171).';

commit;
