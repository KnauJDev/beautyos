begin;

select set_config(
  'request.jwt.claim.sub',
  '7661e1c7-798e-41f0-b2a4-9244e277570b',
  true
);

-- Reprogramación controlada de un ticket confirmado. El rollback deja todo intacto.
select id, status, scheduled_at
from public.reschedule_ticket(
  '59a72637-42fc-4558-a2c0-c5135f5e7676',
  '2026-08-20 15:00:00+00',
  'Prueba controlada de reprogramación'
);

select
  event_type,
  previous_status,
  new_status,
  previous_scheduled_at,
  new_scheduled_at,
  reason,
  created_by
from public.ticket_history
where ticket_id = '59a72637-42fc-4558-a2c0-c5135f5e7676'
order by created_at desc
limit 1;

rollback;
