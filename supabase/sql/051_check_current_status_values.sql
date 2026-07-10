select
  'tickets.status' as source,
  status,
  count(*) as total
from public.tickets
group by status

union all

select
  'ticket_services.status' as source,
  status,
  count(*) as total
from public.ticket_services
group by status

order by source, status;
