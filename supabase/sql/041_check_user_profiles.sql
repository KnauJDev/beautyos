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
order by up.created_at;
