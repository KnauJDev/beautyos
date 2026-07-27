-- BeautyOS - Panel personal del estilista: sus resenas y sus comisiones
-- (candidato 2 de AUDITORIA_ROLES_Y_BRECHAS: "ver sus resenas" nunca se
-- construyo; comisiones por servicio con rango de fechas es una peticion
-- nueva del propietario, 2026-07-25).
--
-- Ambas funciones reutilizan private.beautyos_resolve_branch_access con
-- array['stylist'] (mismo patron que get_my_stylist_work_photos_v2) para
-- resolver el stylist_id propio del usuario autenticado; nunca reciben el
-- stylist_id como parametro para no permitir que alguien consulte los
-- datos de otro.

begin;

create or replace function public.get_my_stylist_reviews(
  p_branch_id uuid
)
returns table (
  id uuid,
  client_name text,
  service_name text,
  rating integer,
  comment text,
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
    p_branch_id, array['stylist']::text[], true
  );

  return query
  select
    r.id,
    coalesce(c.name, 'Cliente no asociado'),
    coalesce(s.name, 'Servicio no asociado'),
    r.rating,
    r.comment,
    r.created_at
  from public.reviews r
  left join public.clients c
    on c.tenant_id = r.tenant_id
   and c.id = r.client_id
  left join public.services s
    on s.tenant_id = r.tenant_id
   and s.id = r.service_id
  where r.tenant_id = v_access.tenant_id
    and r.branch_id = v_access.branch_id
    and r.stylist_id = v_access.stylist_id
    and r.moderation_status = 'approved'
    and r.active
  order by r.created_at desc, r.id;
end;
$$;

revoke all on function public.get_my_stylist_reviews(uuid) from public, anon;
grant execute on function public.get_my_stylist_reviews(uuid) to authenticated;

comment on function public.get_my_stylist_reviews(uuid)
  is 'Lista las resenas aprobadas del estilista autenticado en una sede autorizada.';

create or replace function public.get_my_commission_summary(
  p_branch_id uuid,
  p_start_date date,
  p_end_date date
)
returns table (
  service_id uuid,
  service_name text,
  services_count integer,
  commission_total numeric
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_access record;
  v_start_at timestamptz;
  v_end_at timestamptz;
begin
  select * into strict v_access
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['stylist']::text[], true
  );

  if p_start_date is null or p_end_date is null then
    raise exception 'El rango de fechas es obligatorio.';
  end if;

  if p_start_date > p_end_date then
    raise exception 'La fecha inicial no puede ser posterior a la final.';
  end if;

  v_start_at := p_start_date::timestamp at time zone v_access.timezone;
  v_end_at := (p_end_date + 1)::timestamp at time zone v_access.timezone;

  return query
  select
    svc.id,
    svc.name,
    count(*)::integer,
    coalesce(sum(sc.commission_amount), 0)::numeric
  from public.stylist_commissions sc
  join public.ticket_services ts on ts.id = sc.ticket_service_id
  join public.services svc on svc.id = ts.service_id
  where sc.tenant_id = v_access.tenant_id
    and sc.branch_id = v_access.branch_id
    and sc.stylist_id = v_access.stylist_id
    and sc.status = 'generada'
    and sc.generated_at >= v_start_at
    and sc.generated_at < v_end_at
  group by svc.id, svc.name
  order by commission_total desc, svc.name asc;
end;
$$;

revoke all on function public.get_my_commission_summary(uuid, date, date) from public, anon;
grant execute on function public.get_my_commission_summary(uuid, date, date) to authenticated;

comment on function public.get_my_commission_summary(uuid, date, date)
  is 'Resume, por servicio, las comisiones generadas del estilista autenticado en un rango de fechas.';

commit;
