-- BeautyOS - Tramo D3.2: reemplazos de lectura conscientes de sede.
--
-- Alcance aditivo y reversible:
-- 1. Crear seis RPC _v2 con p_branch_id obligatorio.
-- 2. Autorizar nuevamente tenant, rol y sede en el backend.
-- 3. Mantener intactas las seis firmas heredadas durante la transición.

begin;

create or replace function public.get_appointment_policy_v2(
  p_branch_id uuid
)
returns table (
  id uuid,
  requires_deposit boolean,
  deposit_percentage numeric,
  cancellation_hours integer,
  reschedule_hours integer,
  manual_confirmation_required boolean,
  customer_reschedule_allowed boolean
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
    ap.id,
    ap.requires_deposit,
    ap.deposit_percentage,
    ap.cancellation_hours,
    ap.reschedule_hours,
    ap.manual_confirmation_required,
    ap.customer_reschedule_allowed
  from public.appointment_policies ap
  where ap.tenant_id = v_access.tenant_id
    and ap.branch_id = v_access.branch_id
    and ap.active
  order by ap.created_at desc, ap.id
  limit 1;
end;
$$;

create or replace function public.get_business_hours_v2(
  p_branch_id uuid
)
returns table (
  id uuid,
  day_of_week integer,
  opens_at time,
  closes_at time,
  is_open boolean
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
    bh.id,
    bh.day_of_week,
    bh.opens_at,
    bh.closes_at,
    bh.is_open
  from public.business_hours bh
  where bh.tenant_id = v_access.tenant_id
    and bh.branch_id = v_access.branch_id
    and bh.active
  order by bh.day_of_week, bh.id;
end;
$$;

create or replace function public.get_dashboard_metrics_v2(
  p_branch_id uuid
)
returns table (
  active_services_count integer,
  clients_count integer,
  confirmed_tickets_count integer,
  today_tickets_count integer,
  active_stylists_count integer,
  active_stylist_services_count integer
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
    (
      select count(*)::integer
      from public.branch_services bs
      join public.services s
        on s.tenant_id = bs.tenant_id
       and s.id = bs.service_id
      where bs.tenant_id = v_access.tenant_id
        and bs.branch_id = v_access.branch_id
        and bs.active
        and bs.visible_to_customer
        and s.active
        and s.visible_to_customer
    ) as active_services_count,
    (
      select count(*)::integer
      from public.clients c
      where c.tenant_id = v_access.tenant_id
        and c.active
    ) as clients_count,
    (
      select count(*)::integer
      from public.tickets tk
      where tk.tenant_id = v_access.tenant_id
        and tk.branch_id = v_access.branch_id
        and lower(tk.status) = 'confirmado'
    ) as confirmed_tickets_count,
    (
      select count(*)::integer
      from public.tickets tk
      where tk.tenant_id = v_access.tenant_id
        and tk.branch_id = v_access.branch_id
        and pg_catalog.timezone(v_access.timezone, tk.scheduled_at)::date =
            pg_catalog.timezone(v_access.timezone, now())::date
    ) as today_tickets_count,
    (
      select count(*)::integer
      from public.branch_stylists bst
      join public.stylists st
        on st.tenant_id = bst.tenant_id
       and st.id = bst.stylist_id
      where bst.tenant_id = v_access.tenant_id
        and bst.branch_id = v_access.branch_id
        and bst.active
        and bst.starts_at <= now()
        and (bst.ends_at is null or bst.ends_at > now())
        and st.active
    ) as active_stylists_count,
    (
      select count(*)::integer
      from public.branch_stylist_services bss
      join public.branch_stylists bst
        on bst.tenant_id = bss.tenant_id
       and bst.branch_id = bss.branch_id
       and bst.id = bss.branch_stylist_id
      join public.branch_services bs
        on bs.tenant_id = bss.tenant_id
       and bs.branch_id = bss.branch_id
       and bs.id = bss.branch_service_id
      join public.stylists st
        on st.tenant_id = bst.tenant_id
       and st.id = bst.stylist_id
      join public.services s
        on s.tenant_id = bs.tenant_id
       and s.id = bs.service_id
      where bss.tenant_id = v_access.tenant_id
        and bss.branch_id = v_access.branch_id
        and bss.active
        and bst.active
        and bst.starts_at <= now()
        and (bst.ends_at is null or bst.ends_at > now())
        and bs.active
        and st.active
        and s.active
    ) as active_stylist_services_count;
end;
$$;

create or replace function public.get_my_stylist_work_photos_v2(
  p_branch_id uuid
)
returns table (
  id uuid,
  ticket_id uuid,
  client_name text,
  service_name text,
  photo_url text,
  photo_type text,
  caption text,
  ai_status text,
  visible_to_customer boolean,
  approved_for_portfolio boolean,
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
    array['stylist']::text[],
    true
  );

  return query
  select
    wp.id,
    wp.ticket_id,
    c.name as client_name,
    svc.service_name,
    wp.photo_url,
    wp.photo_type,
    wp.caption,
    wp.ai_status,
    wp.visible_to_customer,
    wp.approved_for_portfolio,
    wp.created_at
  from public.work_photos wp
  left join public.clients c
    on c.tenant_id = wp.tenant_id
   and c.id = wp.client_id
  left join lateral (
    select s.name as service_name
    from public.ticket_services ts
    join public.services s
      on s.tenant_id = ts.tenant_id
     and s.id = ts.service_id
    where ts.tenant_id = wp.tenant_id
      and ts.branch_id = wp.branch_id
      and ts.ticket_id = wp.ticket_id
      and ts.stylist_id = wp.stylist_id
    order by ts.created_at desc, ts.id
    limit 1
  ) svc on true
  where wp.tenant_id = v_access.tenant_id
    and wp.branch_id = v_access.branch_id
    and wp.stylist_id = v_access.stylist_id
    and wp.active
  order by wp.created_at desc, wp.id
  limit 100;
end;
$$;

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

create or replace function public.get_work_photos_summary_v2(
  p_branch_id uuid
)
returns table (
  id uuid,
  ticket_id uuid,
  client_name text,
  stylist_name text,
  photo_url text,
  photo_type text,
  caption text,
  ai_status text,
  visible_to_customer boolean,
  approved_for_portfolio boolean,
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
    wp.id,
    wp.ticket_id,
    coalesce(c.name, 'Cliente no asociado') as client_name,
    coalesce(st.name, 'Estilista no asociado') as stylist_name,
    wp.photo_url,
    wp.photo_type,
    wp.caption,
    wp.ai_status,
    wp.visible_to_customer,
    wp.approved_for_portfolio,
    wp.created_at
  from public.work_photos wp
  left join public.clients c
    on c.tenant_id = wp.tenant_id
   and c.id = wp.client_id
  left join public.stylists st
    on st.tenant_id = wp.tenant_id
   and st.id = wp.stylist_id
  where wp.tenant_id = v_access.tenant_id
    and wp.branch_id = v_access.branch_id
    and wp.active
  order by wp.created_at desc, wp.id;
end;
$$;

revoke all on function public.get_appointment_policy_v2(uuid)
  from public, anon, authenticated;
revoke all on function public.get_business_hours_v2(uuid)
  from public, anon, authenticated;
revoke all on function public.get_dashboard_metrics_v2(uuid)
  from public, anon, authenticated;
revoke all on function public.get_my_stylist_work_photos_v2(uuid)
  from public, anon, authenticated;
revoke all on function public.get_reviews_summary_v2(uuid)
  from public, anon, authenticated;
revoke all on function public.get_work_photos_summary_v2(uuid)
  from public, anon, authenticated;

grant execute on function public.get_appointment_policy_v2(uuid)
  to authenticated, service_role;
grant execute on function public.get_business_hours_v2(uuid)
  to authenticated, service_role;
grant execute on function public.get_dashboard_metrics_v2(uuid)
  to authenticated, service_role;
grant execute on function public.get_my_stylist_work_photos_v2(uuid)
  to authenticated, service_role;
grant execute on function public.get_reviews_summary_v2(uuid)
  to authenticated, service_role;
grant execute on function public.get_work_photos_summary_v2(uuid)
  to authenticated, service_role;

comment on function public.get_appointment_policy_v2(uuid)
  is 'Consulta la politica activa de una sede autorizada.';
comment on function public.get_business_hours_v2(uuid)
  is 'Consulta los horarios activos de una sede autorizada.';
comment on function public.get_dashboard_metrics_v2(uuid)
  is 'Resume la sede autorizada; clients_count conserva alcance tenant.';
comment on function public.get_my_stylist_work_photos_v2(uuid)
  is 'Lista las fotos propias del estilista en una sede autorizada.';
comment on function public.get_reviews_summary_v2(uuid)
  is 'Lista las resenas activas de una sede autorizada.';
comment on function public.get_work_photos_summary_v2(uuid)
  is 'Lista las fotos activas de una sede autorizada.';

commit;
