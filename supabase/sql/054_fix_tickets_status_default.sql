alter table public.tickets
alter column status set default 'solicitado';

select
  table_name,
  column_name,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'tickets'
  and column_name = 'status';
