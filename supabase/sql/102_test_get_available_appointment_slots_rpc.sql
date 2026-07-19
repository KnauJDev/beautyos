begin;

select set_config(
  'request.jwt.claim.sub',
  (
    select up.user_id::text
    from public.user_profiles up
    where up.active = true
      and up.role in ('owner', 'admin')
    order by case up.role when 'owner' then 0 else 1 end
    limit 1
  ),
  true
);

select *
from public.get_available_appointment_slots(
  (
    select ss.service_id
    from public.stylist_services ss
    where ss.active = true
      and ss.tenant_id = (
        select up.tenant_id
        from public.user_profiles up
        where up.user_id = auth.uid()
          and up.active = true
        limit 1
      )
    limit 1
  ),
  (
    select ss.stylist_id
    from public.stylist_services ss
    where ss.active = true
      and ss.tenant_id = (
        select up.tenant_id
        from public.user_profiles up
        where up.user_id = auth.uid()
          and up.active = true
        limit 1
      )
    limit 1
  ),
  ((now() at time zone 'America/Bogota')::date + 1)
)
limit 5;

rollback;
