begin;

select set_config(
  'request.jwt.claim.sub',
  '067dd2e6-9a10-4965-a804-4601c60d724f',
  true
);

select *
from public.get_my_stylist_work_photos();

rollback;
