-- BeautyOS - Infraestructura de Storage para fotos de trabajo.
-- Sub-bloque 2 de 3 de "Resenas y fotos de trabajo" (D-058/D-059).
--
-- Primera vez que el proyecto usa Supabase Storage: hasta ahora toda
-- escritura pasaba por RPC SECURITY DEFINER, nunca directo a una tabla.
-- La subida de Storage es distinta por diseno (va directo del cliente al
-- bucket), asi que la autorizacion vive en una politica RLS sobre
-- storage.objects, replicando la misma regla ya usada en
-- beautyos_resolve_branch_access: tenant_owner tiene acceso a todas sus
-- sedes; admin/stylist necesitan una branch_membership activa para esa
-- sede exacta.
--
-- Decision del propietario (2026-07-25): bucket publico (URL directa y
-- permanente, coherente con como work_photos.photo_url ya se lee hoy en
-- get_work_photos_summary_v2), no privado con URLs firmadas. Suben fotos
-- solo tenant_owner/admin/stylist -- nunca el cliente.
--
-- Este sub-bloque NO crea la fila en work_photos todavia (eso es el
-- sub-bloque 3); solo deja lista la infraestructura para subir un
-- archivo y obtener su URL publica.

begin;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'work-photos',
  'work-photos',
  true,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

create or replace function private.beautyos_can_upload_work_photo(
  p_tenant_id uuid,
  p_branch_id uuid
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
      and tm.role in ('tenant_owner', 'admin', 'stylist')
      and (
        tm.role = 'tenant_owner'
        or exists (
          select 1
          from public.branch_memberships bm
          where bm.tenant_id = tm.tenant_id
            and bm.branch_id = p_branch_id
            and bm.tenant_membership_id = tm.id
            and bm.active
            and bm.starts_at <= now()
            and (bm.ends_at is null or bm.ends_at > now())
        )
      )
  );
$$;

revoke all on function private.beautyos_can_upload_work_photo(uuid, uuid)
  from public, anon, authenticated;
grant execute on function private.beautyos_can_upload_work_photo(uuid, uuid)
  to authenticated;

comment on function private.beautyos_can_upload_work_photo(uuid, uuid)
  is 'Autoriza subida a storage.objects en work-photos: tenant_owner de cualquier sede propia, admin/stylist solo con branch_membership activa para esa sede exacta.';

-- Ruta esperada del archivo: {tenant_id}/{branch_id}/{uuid}.{ext}
create policy "work_photos_insert_staff"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'work-photos'
  and array_length(storage.foldername(name), 1) = 2
  and private.beautyos_can_upload_work_photo(
    (storage.foldername(name))[1]::uuid,
    (storage.foldername(name))[2]::uuid
  )
);

commit;
