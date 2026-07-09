insert into public.user_profiles (
  tenant_id,
  user_id,
  full_name,
  role,
  active
)
values (
  'd338021b-1aed-4d4c-8462-0fc571867798',
  '067dd2e6-9a10-4965-a804-4601c60d724f',
  'Estilista Bella Mujer',
  'stylist',
  true
)
on conflict (user_id)
do update set
  tenant_id = excluded.tenant_id,
  full_name = excluded.full_name,
  role = excluded.role,
  active = excluded.active,
  updated_at = now();

select
  up.id,
  up.user_id,
  up.full_name,
  up.role,
  up.active,
  up.tenant_id,
  t.name as tenant_name
from public.user_profiles up
left join public.tenants t
  on t.id = up.tenant_id
where up.user_id = '067dd2e6-9a10-4965-a804-4601c60d724f';
