begin;

select set_config(
  'request.jwt.claim.sub',
  '7661e1c7-798e-41f0-b2a4-9244e277570b',
  true
);

select ticket_service_id, service_name, stylist_name, service_status
from public.get_ticket_services_for_correction(
  '59a72637-42fc-4558-a2c0-c5135f5e7676'
);

select id, status
from public.reopen_finished_ticket_service(
  'bbba030e-10d1-4310-b2b0-c1fbfb26991c',
  'Finalización accidental confirmada por administración'
);

select id, status
from public.tickets
where id = '59a72637-42fc-4558-a2c0-c5135f5e7676';

select previous_status, new_status, reason, created_by
from public.ticket_service_history
where ticket_service_id = 'bbba030e-10d1-4310-b2b0-c1fbfb26991c'
order by created_at desc
limit 1;

rollback;
