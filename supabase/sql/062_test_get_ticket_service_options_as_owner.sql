begin;

select set_config(
  'request.jwt.claim.sub',
  '7661e1c7-798e-41f0-b2a4-9244e277570b',
  true
);

select
  service_id,
  service_name,
  category,
  price,
  duration_minutes,
  stylist_id,
  stylist_name
from public.get_ticket_service_options();

rollback;
