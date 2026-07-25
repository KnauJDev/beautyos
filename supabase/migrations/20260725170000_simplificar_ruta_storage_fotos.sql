-- BeautyOS - Simplifica la ruta de Storage de fotos de trabajo.
--
-- El sub-bloque 2 uso {tenant_id}/{branch_id}/archivo.ext, lo que obligaba
-- a llevar tenant_id hasta cada pantalla de Flutter (TicketsPage y
-- "Mi agenda" solo reciben branchId hoy). tenant_id se resuelve del lado
-- servidor a partir de branch_id (igual que en toda RPC del proyecto), asi
-- que la ruta se simplifica a {branch_id}/archivo.ext. Nadie subio
-- todavia ningun archivo real con la convencion anterior (WorkPhotosUploadService
-- no se habia conectado a ninguna pantalla), asi que no hay datos que migrar.

begin;

drop policy if exists "work_photos_insert_staff" on storage.objects;
drop function if exists private.beautyos_can_upload_work_photo(uuid, uuid);

create or replace function private.beautyos_can_upload_work_photo(
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
    from public.branches b
    join public.tenant_memberships tm
      on tm.tenant_id = b.tenant_id
    where b.id = p_branch_id
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

comment on function private.beautyos_can_upload_work_photo(uuid)
  is 'Autoriza subida a storage.objects en work-photos por sede: tenant_owner de cualquier sede propia, admin/stylist solo con branch_membership activa para esa sede exacta.';

-- Ruta esperada del archivo: {branch_id}/{uuid}.{ext}
create policy "work_photos_insert_staff"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'work-photos'
  and array_length(storage.foldername(name), 1) = 1
  and private.beautyos_can_upload_work_photo(
    (storage.foldername(name))[1]::uuid
  )
);

commit;
