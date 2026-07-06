insert into public.user_profiles (
  tenant_id,
  user_id,
  full_name,
  role,
  active
)
select
  t.id,
  '7661e1c7-798e-41f0-b2a4-9244e277570b'::uuid,
  'Administrador Bella Mujer',
  'owner',
  true
from public.tenants t
where t.name = 'Bella Mujer'
on conflict (user_id)
do update set
  tenant_id = excluded.tenant_id,
  full_name = excluded.full_name,
  role = excluded.role,
  active = excluded.active,
  updated_at = now();

select
  up.id,
  up.tenant_id,
  t.name as tenant_name,
  up.user_id,
  up.full_name,
  up.role,
  up.active
from public.user_profiles up
join public.tenants t
  on t.id = up.tenant_id
where up.user_id = '7661e1c7-798e-41f0-b2a4-9244e277570b'::uuid;
