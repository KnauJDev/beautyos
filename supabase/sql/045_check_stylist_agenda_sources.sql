select
  'columns:tickets' as section,
  jsonb_agg(
    jsonb_build_object(
      'column', column_name,
      'type', data_type,
      'nullable', is_nullable
    )
    order by ordinal_position
  ) as data
from information_schema.columns
where table_schema = 'public'
  and table_name = 'tickets'

union all

select
  'columns:ticket_services' as section,
  jsonb_agg(
    jsonb_build_object(
      'column', column_name,
      'type', data_type,
      'nullable', is_nullable
    )
    order by ordinal_position
  ) as data
from information_schema.columns
where table_schema = 'public'
  and table_name = 'ticket_services'

union all

select
  'columns:clients' as section,
  jsonb_agg(
    jsonb_build_object(
      'column', column_name,
      'type', data_type,
      'nullable', is_nullable
    )
    order by ordinal_position
  ) as data
from information_schema.columns
where table_schema = 'public'
  and table_name = 'clients'

union all

select
  'sample:tickets' as section,
  coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) as data
from (
  select *
  from public.tickets
  limit 5
) x

union all

select
  'sample:ticket_services' as section,
  coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) as data
from (
  select *
  from public.ticket_services
  limit 5
) x;
