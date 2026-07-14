begin;

select set_config(
  'request.jwt.claim.sub',
  '7661e1c7-798e-41f0-b2a4-9244e277570b',
  true
);

select
  id,
  client_name,
  status,
  total_price,
  paid_amount,
  balance_amount,
  payment_status
from public.get_tickets_summary()
order by scheduled_at desc nulls last;

rollback;
