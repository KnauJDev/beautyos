-- BeautyOS - Crear y aprobar fotos de trabajo.
-- Sub-bloque 3 de 3 de "Resenas y fotos de trabajo" (D-058/D-059/D-060).
--
-- Usa la infraestructura de Storage del sub-bloque 2
-- (bucket "work-photos" + WorkPhotosUploadService en Flutter, que sube
-- el archivo y entrega su URL publica antes de llamar a create_work_photo
-- aqui abajo).
--
-- work_photos no tiene columna service_id (solo ticket_id y stylist_id),
-- asi que la atribucion de estilista se resuelve segun quien sube:
-- - stylist: siempre se autoatribuye (se ignora cualquier p_stylist_id
--   que intente pasar por otra persona -- probado en rollback).
-- - tenant_owner/admin: puede atribuir opcionalmente a un estilista que
--   si tenga un ticket_services para ese ticket, o dejarla sin atribuir.
--
-- Decision del propietario (2026-07-25): boton "Agregar foto" en dos
-- lugares -- TicketsPage (admin/owner) y "Mi agenda" (estilista, sobre
-- sus propios servicios). Aprobacion con dos interruptores
-- independientes en WorkPhotosPage: "visible al cliente" y "aprobada
-- para portafolio" (columnas ya separadas en el esquema real).

begin;

create or replace function public.create_work_photo(
  p_branch_id uuid,
  p_ticket_id uuid,
  p_photo_url text,
  p_photo_type text,
  p_caption text default null,
  p_stylist_id uuid default null
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

  if p_photo_url is null or trim(p_photo_url) = '' then
    raise exception 'Falta la URL de la foto.';
  end if;

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
    photo_url, photo_type, caption
  ) values (
    v_tenant_id,
    p_branch_id,
    p_ticket_id,
    v_client_id,
    v_stylist_id,
    trim(p_photo_url),
    p_photo_type,
    nullif(trim(coalesce(p_caption, '')), '')
  )
  returning id into v_photo_id;

  return v_photo_id;
end;
$$;

create or replace function public.set_work_photo_customer_visibility(
  p_branch_id uuid,
  p_photo_id uuid,
  p_visible boolean
)
returns void
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

  update public.work_photos wp
  set visible_to_customer = p_visible, updated_at = now()
  where wp.id = p_photo_id
    and wp.tenant_id = v_access.tenant_id
    and wp.branch_id = v_access.branch_id
    and wp.active;

  if not found then
    raise exception 'La foto no existe o no pertenece a esta sede.';
  end if;
end;
$$;

create or replace function public.set_work_photo_portfolio_approval(
  p_branch_id uuid,
  p_photo_id uuid,
  p_approved boolean
)
returns void
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

  update public.work_photos wp
  set approved_for_portfolio = p_approved, updated_at = now()
  where wp.id = p_photo_id
    and wp.tenant_id = v_access.tenant_id
    and wp.branch_id = v_access.branch_id
    and wp.active;

  if not found then
    raise exception 'La foto no existe o no pertenece a esta sede.';
  end if;
end;
$$;

revoke all on function public.create_work_photo(uuid, uuid, text, text, text, uuid)
  from public, anon;
revoke all on function public.set_work_photo_customer_visibility(uuid, uuid, boolean)
  from public, anon;
revoke all on function public.set_work_photo_portfolio_approval(uuid, uuid, boolean)
  from public, anon;

grant execute on function public.create_work_photo(uuid, uuid, text, text, text, uuid)
  to authenticated, service_role;
grant execute on function public.set_work_photo_customer_visibility(uuid, uuid, boolean)
  to authenticated, service_role;
grant execute on function public.set_work_photo_portfolio_approval(uuid, uuid, boolean)
  to authenticated, service_role;

comment on function public.create_work_photo(uuid, uuid, text, text, text, uuid)
  is 'Registra una foto de trabajo ya subida a Storage; tenant_owner/admin/stylist con acceso a la sede. Un stylist siempre se autoatribuye.';
comment on function public.set_work_photo_customer_visibility(uuid, uuid, boolean)
  is 'Muestra/oculta una foto al cliente; solo tenant_owner/admin de la sede.';
comment on function public.set_work_photo_portfolio_approval(uuid, uuid, boolean)
  is 'Aprueba/retira una foto del portafolio publico; solo tenant_owner/admin de la sede.';

commit;
