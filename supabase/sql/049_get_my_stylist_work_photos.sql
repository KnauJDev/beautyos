create or replace function public.get_my_stylist_work_photos()
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
language sql
security definer
set search_path = public
as $$
  with my_profile as (
    select
      up.tenant_id,
      up.stylist_id
    from public.user_profiles up
    where up.user_id = auth.uid()
      and up.active = true
      and up.role = 'stylist'
      and up.stylist_id is not null
    limit 1
  )
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
  from my_profile mp
  join public.work_photos wp
    on wp.tenant_id = mp.tenant_id
   and wp.stylist_id = mp.stylist_id
   and wp.active = true
  left join public.clients c
    on c.id = wp.client_id
   and c.tenant_id = mp.tenant_id
  left join lateral (
    select s.name as service_name
    from public.ticket_services ts
    join public.services s
      on s.id = ts.service_id
     and s.tenant_id = ts.tenant_id
    where ts.ticket_id = wp.ticket_id
      and ts.stylist_id = wp.stylist_id
      and ts.tenant_id = mp.tenant_id
    order by ts.created_at desc
    limit 1
  ) svc on true
  order by wp.created_at desc
  limit 100;
$$;

revoke all on function public.get_my_stylist_work_photos() from public;
revoke all on function public.get_my_stylist_work_photos() from anon;
grant execute on function public.get_my_stylist_work_photos() to authenticated;

select
  routine_schema,
  routine_name,
  security_type
from information_schema.routines
where routine_schema = 'public'
  and routine_name = 'get_my_stylist_work_photos';
