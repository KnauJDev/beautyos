-- BeautyOS - Resenas de cliente: crear (publico, sin sesion) + moderar
-- (admin/tenant_owner). Sub-bloque 1 de 3 de "Resenas y fotos de trabajo"
-- (D-058). Fotos de trabajo quedan para un sub-bloque aparte porque
-- requieren Supabase Storage, que hoy no existe en el proyecto.
--
-- Mismo patron que la reserva publica (D-053, D-005): RPC "anon" sin
-- sesion, enlace via "?resena=<ticket_id>" (el ticket ya encierra
-- tenant_id/branch_id/client_id, el cliente no envia identidad propia).
-- El propietario decidio: acceso por enlace de ticket_id (no verificacion
-- de celular); las fotos de trabajo las sube solo el negocio, no el
-- cliente (quedan fuera de este bloque).
--
-- get_reviews_summary_v2 (D3.2, ya en produccion) es la cola de
-- moderacion del admin; no se toca aqui. Solo falta la RPC que aplique
-- la decision de aprobar/rechazar.

begin;

-- Sin esto un cliente podia dejar dos resenas del mismo ticket.
create unique index reviews_ticket_active_unique
  on public.reviews (ticket_id)
  where active and ticket_id is not null;

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
  services jsonb
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
begin
  select tk.status, c.name, b.name
    into v_status, v_client_name, v_branch_name
  from public.tickets tk
  join public.clients c on c.id = tk.client_id
  join public.branches b on b.id = tk.branch_id
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
    v_services;
end;
$$;

create or replace function public.public_create_review(
  p_ticket_id uuid,
  p_rating integer,
  p_comment text default null,
  p_stylist_id uuid default null,
  p_service_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_branch_id uuid;
  v_client_id uuid;
  v_status text;
  v_review_id uuid;
begin
  select tk.tenant_id, tk.branch_id, tk.client_id, tk.status
    into v_tenant_id, v_branch_id, v_client_id, v_status
  from public.tickets tk
  where tk.id = p_ticket_id;

  if not found then
    raise exception 'Este enlace de resena no es valido.';
  end if;

  if v_status not in ('finalizado', 'cerrado') then
    raise exception 'Esta visita todavia no ha finalizado, no se puede calificar todavia.';
  end if;

  if exists (
    select 1
    from public.reviews r
    where r.ticket_id = p_ticket_id
      and r.active
  ) then
    raise exception 'Ya se registro una resena para esta visita.';
  end if;

  if p_rating is null or p_rating < 1 or p_rating > 5 then
    raise exception 'La calificacion debe ser entre 1 y 5 estrellas.';
  end if;

  if p_stylist_id is not null and p_service_id is not null then
    if not exists (
      select 1
      from public.ticket_services ts
      where ts.ticket_id = p_ticket_id
        and ts.stylist_id = p_stylist_id
        and ts.service_id = p_service_id
    ) then
      raise exception 'El estilista o servicio seleccionado no corresponde a esta visita.';
    end if;
  elsif p_stylist_id is not null or p_service_id is not null then
    raise exception 'Selecciona estilista y servicio juntos, o ninguno de los dos.';
  end if;

  insert into public.reviews (
    tenant_id, branch_id, ticket_id, client_id, stylist_id, service_id,
    rating, comment, moderation_status, visible_to_public
  ) values (
    v_tenant_id,
    v_branch_id,
    p_ticket_id,
    v_client_id,
    p_stylist_id,
    p_service_id,
    p_rating,
    nullif(trim(coalesce(p_comment, '')), ''),
    'pending',
    false
  )
  returning id into v_review_id;

  return v_review_id;
end;
$$;

create or replace function public.moderate_review(
  p_branch_id uuid,
  p_review_id uuid,
  p_approve boolean
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

  update public.reviews r
  set
    moderation_status = case when p_approve then 'approved' else 'rejected' end,
    visible_to_public = p_approve,
    updated_at = now()
  where r.id = p_review_id
    and r.tenant_id = v_access.tenant_id
    and r.branch_id = v_access.branch_id
    and r.active;

  if not found then
    raise exception 'La resena no existe o no pertenece a esta sede.';
  end if;
end;
$$;

revoke all on function public.public_get_ticket_for_review(uuid)
  from public, authenticated;
revoke all on function public.public_create_review(
  uuid, integer, text, uuid, uuid
) from public, authenticated;
revoke all on function public.moderate_review(uuid, uuid, boolean)
  from public, anon;

grant execute on function public.public_get_ticket_for_review(uuid)
  to anon, service_role;
grant execute on function public.public_create_review(
  uuid, integer, text, uuid, uuid
) to anon, service_role;
grant execute on function public.moderate_review(uuid, uuid, boolean)
  to authenticated, service_role;

comment on function public.public_get_ticket_for_review(uuid)
  is 'Datos minimos de un ticket para la pagina publica de resena. Sin sesion.';
comment on function public.public_create_review(
  uuid, integer, text, uuid, uuid
) is 'Crea una resena pendiente de moderacion para un ticket finalizado/cerrado. Sin sesion.';
comment on function public.moderate_review(uuid, uuid, boolean)
  is 'Aprueba o rechaza una resena pendiente; solo tenant_owner/admin de la sede.';

commit;
