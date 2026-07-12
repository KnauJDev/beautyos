begin;

select set_config(
  'request.jwt.claim.sub',
  '7661e1c7-798e-41f0-b2a4-9244e277570b',
  true
);

select
  id,
  tenant_id,
  ticket_id,
  service_id,
  stylist_id,
  price,
  duration_minutes,
  status
from public.add_ticket_service(
  'e8f8794d-adec-4d5e-8657-5a385a0720e2',
  'b2cf56ac-c077-43be-96f3-78a9ccfccddb',
  'c92f36af-1969-47a2-a605-5993ee39a6e7'
);

rollback;
