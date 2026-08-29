-- Paso 6.3 del Plan Maestro (D-170): "Respuestas a reseñas asistidas" --
-- version determinista (decision del propietario, mismo criterio que 6.1 y
-- 6.2: empezar sin IA externa). El salon escribe una respuesta publica a
-- cada reseña; "asistida" es una plantilla por franja de calificacion que
-- Flutter arma en el cliente (sin llamada al servidor) y el salon edita
-- antes de guardar -- esta migracion solo agrega donde vive la respuesta y
-- quien puede escribirla, la redaccion del borrador no toca la base.

begin;

alter table public.reviews
  add column if not exists business_reply text,
  add column if not exists business_reply_at timestamptz;

comment on column public.reviews.business_reply is
  'Respuesta publica del salon a la reseña (paso 6.3, D-170). Null si todavia no respondio.';
comment on column public.reviews.business_reply_at is
  'Cuando se guardo la respuesta actual. Se limpia junto con business_reply.';

-- ----------------------------------------------------------------------------
-- 1. set_review_reply: guarda, edita o quita la respuesta. Sin restringir a
--    reseñas ya aprobadas -- el salon puede redactar la respuesta antes de
--    terminar de moderar, igual la respuesta solo se ve en publico si la
--    reseña misma es visible (get_public_salon_reviews ya filtra por eso).
-- ----------------------------------------------------------------------------

create or replace function public.set_review_reply(
  p_branch_id uuid,
  p_review_id uuid,
  p_reply text
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_access record;
  v_reply text;
begin
  select * into strict v_access
  from private.beautyos_resolve_branch_access(
    p_branch_id,
    array['tenant_owner', 'admin']::text[],
    true
  );

  v_reply := nullif(trim(p_reply), '');

  update public.reviews
  set business_reply = v_reply,
      business_reply_at = case when v_reply is null then null else now() end
  where id = p_review_id
    and tenant_id = v_access.tenant_id
    and branch_id = v_access.branch_id
    and active;

  if not found then
    raise exception 'Esta reseña no existe o no pertenece a esta sede.';
  end if;
end;
$$;

revoke all on function public.set_review_reply(uuid, uuid, text)
  from public, anon, authenticated;
grant execute on function public.set_review_reply(uuid, uuid, text)
  to authenticated;

comment on function public.set_review_reply(uuid, uuid, text) is
  'Guarda, edita o quita (texto vacio/null) la respuesta del salon a una reseña. Solo tenant_owner/admin de la sede (paso 6.3, D-170).';

-- ----------------------------------------------------------------------------
-- 2. get_reviews_summary_v2 gana business_reply/business_reply_at -- cambia
--    la tabla de retorno, exige drop function primero (mismo motivo que
--    D-162/D-164/D-165/D-166).
-- ----------------------------------------------------------------------------

drop function if exists public.get_reviews_summary_v2(uuid);

create or replace function public.get_reviews_summary_v2(
  p_branch_id uuid
)
returns table (
  id uuid,
  ticket_id uuid,
  client_name text,
  stylist_name text,
  service_name text,
  rating integer,
  comment text,
  moderation_status text,
  visible_to_public boolean,
  business_reply text,
  business_reply_at timestamptz,
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
    r.id,
    r.ticket_id,
    coalesce(c.name, 'Cliente no asociado') as client_name,
    coalesce(st.name, 'Estilista no asociado') as stylist_name,
    coalesce(s.name, 'Servicio no asociado') as service_name,
    r.rating,
    r.comment,
    r.moderation_status,
    r.visible_to_public,
    r.business_reply,
    r.business_reply_at,
    r.created_at
  from public.reviews r
  left join public.clients c
    on c.tenant_id = r.tenant_id
   and c.id = r.client_id
  left join public.stylists st
    on st.tenant_id = r.tenant_id
   and st.id = r.stylist_id
  left join public.services s
    on s.tenant_id = r.tenant_id
   and s.id = r.service_id
  where r.tenant_id = v_access.tenant_id
    and r.branch_id = v_access.branch_id
    and r.active
  order by r.created_at desc, r.id;
end;
$$;

revoke all on function public.get_reviews_summary_v2(uuid)
  from public, anon, authenticated;
grant execute on function public.get_reviews_summary_v2(uuid)
  to authenticated;

comment on function public.get_reviews_summary_v2(uuid) is
  'Cola de reseñas del panel del salon, con la respuesta del negocio si existe (paso 6.3, D-170).';

-- ----------------------------------------------------------------------------
-- 3. get_public_salon_reviews gana business_reply -- para que la pagina
--    publica del negocio (D-165) muestre la respuesta bajo cada reseña.
--    Cambia la tabla de retorno, exige drop function primero.
-- ----------------------------------------------------------------------------

drop function if exists public.get_public_salon_reviews(uuid);

create or replace function public.get_public_salon_reviews(p_tenant_id uuid)
returns table (
  avg_rating numeric,
  total_reviews integer,
  client_name text,
  rating integer,
  comment text,
  business_reply text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_avg numeric;
  v_total integer;
begin
  select coalesce(avg(r.rating), 0)::numeric(3, 2), count(*)::integer
    into v_avg, v_total
  from public.reviews r
  join public.tenants t
    on t.id = r.tenant_id
   and t.active = true
  where r.tenant_id = p_tenant_id
    and r.visible_to_public = true
    and r.active = true;

  return query
  select
    v_avg,
    v_total,
    c.name,
    r.rating,
    r.comment,
    r.business_reply,
    r.created_at
  from public.reviews r
  join public.clients c
    on c.tenant_id = r.tenant_id
   and c.id = r.client_id
  where r.tenant_id = p_tenant_id
    and r.visible_to_public = true
    and r.active = true
  order by r.created_at desc
  limit 10;
end;
$$;

revoke all on function public.get_public_salon_reviews(uuid) from public;
grant execute on function public.get_public_salon_reviews(uuid) to anon, authenticated;

comment on function public.get_public_salon_reviews(uuid) is
  'Promedio, total y ultimas 10 reseñas publicas del negocio, con la respuesta del salon si existe (D-165, D-170). Sin sesion.';

commit;
