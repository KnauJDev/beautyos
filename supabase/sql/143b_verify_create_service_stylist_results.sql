begin;

select set_config(
  'request.jwt.claim.sub',
  '915b2d28-abd3-49d5-a0cf-bd105ce5a9bf',
  true
);

select * from public.create_service(
  'c8cdbb05-f406-4fb4-a9b4-edd8362ee936',
  'Corte clasico',
  'Cabello',
  30,
  35000
);

select * from public.create_stylist(
  'c8cdbb05-f406-4fb4-a9b4-edd8362ee936',
  'Ana Estilista',
  '3001112233',
  'Color'
);

select
  s.name as service_name,
  s.duration_minutes,
  s.price,
  s.visible_to_customer,
  bs.branch_id as service_branch_id,
  bs.price as branch_price,
  st.name as stylist_name,
  bst.branch_id as stylist_branch_id
from public.services s
join public.branch_services bs on bs.service_id = s.id
cross join public.stylists st
join public.branch_stylists bst on bst.stylist_id = st.id
where s.name = 'Corte clasico'
  and st.name = 'Ana Estilista';

rollback;
