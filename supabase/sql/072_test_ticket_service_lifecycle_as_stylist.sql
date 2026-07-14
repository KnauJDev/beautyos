begin;

-- Sandra inicia y finaliza su propio servicio. El rollback deja todo intacto.
select set_config(
  'request.jwt.claim.sub',
  '067dd2e6-9a10-4965-a804-4601c60d724f',
  true
);

select id, status
from public.change_ticket_service_status(
  'bbba030e-10d1-4310-b2b0-c1fbfb26991c',
  'en_proceso'
);

select id, status
from public.tickets
where id = '59a72637-42fc-4558-a2c0-c5135f5e7676';

select id, status
from public.change_ticket_service_status(
  'bbba030e-10d1-4310-b2b0-c1fbfb26991c',
  'finalizado'
);

select id, status
from public.tickets
where id = '59a72637-42fc-4558-a2c0-c5135f5e7676';

select previous_status, new_status, created_by
from public.ticket_service_history
where ticket_service_id = 'bbba030e-10d1-4310-b2b0-c1fbfb26991c'
order by created_at;

rollback;
