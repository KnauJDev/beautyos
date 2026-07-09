create or replace function public.get_my_stylist_agenda()
returns table (
  ticket_service_id uuid,
  ticket_id uuid,
  scheduled_at timestamptz,
  client_name text,
  service_name text,
  ticket_status text,
  service_status text,
  price numeric,
  duration_minutes integer,
  notes text
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
    ts.id as ticket_service_id,
    t.id as ticket_id,
    t.scheduled_at,
    c.name as client_name,
    s.name as service_name,
    t.status as ticket_status,
    ts.status as service_status,
    ts.price,
    ts.duration_minutes,
    t.notes
  from my_profile mp
  join public.ticket_services ts
    on ts.tenant_id = mp.tenant_id
   and ts.stylist_id = mp.stylist_id
  join public.tickets t
    on t.id = ts.ticket_id
   and t.tenant_id = mp.tenant_id
  join public.clients c
    on c.id = t.client_id
   and c.tenant_id = mp.tenant_id
  join public.services s
    on s.id = ts.service_id
   and s.tenant_id = mp.tenant_id
  order by
    t.scheduled_at desc nulls last,
    ts.created_at desc
  limit 100;
$$;

revoke all on function public.get_my_stylist_agenda() from public;
revoke all on function public.get_my_stylist_agenda() from anon;
grant execute on function public.get_my_stylist_agenda() to authenticated;

select
  routine_schema,
  routine_name,
  security_type
from information_schema.routines
where routine_schema = 'public'
  and routine_name = 'get_my_stylist_agenda';
