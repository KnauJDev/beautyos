select
  column_name,
  data_type,
  is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name = 'stylists'
order by ordinal_position;

select *
from public.stylists
order by created_at
limit 20;
