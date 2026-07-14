begin;

select set_config(
  'request.jwt.claim.sub',
  '7661e1c7-798e-41f0-b2a4-9244e277570b',
  true
);

-- Ticket confirmado de prueba: confirmado -> en_espera.
select id, status
from public.change_ticket_status(
  '59a72637-42fc-4558-a2c0-c5135f5e7676',
  'en_espera',
  'Prueba controlada de transición'
);

select event_type, previous_status, new_status, reason, created_by
from public.ticket_history
where ticket_id = '59a72637-42fc-4558-a2c0-c5135f5e7676'
order by created_at desc
limit 1;

rollback;
