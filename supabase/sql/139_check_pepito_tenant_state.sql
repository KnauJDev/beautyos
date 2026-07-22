select
  t.id as tenant_id,
  t.name as tenant_name,
  t.contact_email,
  t.whatsapp,
  b.id as branch_id,
  b.name as branch_name,
  b.slug,
  tm.role as membership_role,
  ts.status as subscription_status,
  ts.trial_ends_at
from public.tenant_memberships tm
join public.tenants t on t.id = tm.tenant_id
left join public.branches b on b.tenant_id = t.id
left join public.tenant_subscriptions ts on ts.tenant_id = t.id
where tm.user_id = '2975e198-2f33-4cd3-a3f2-4d93eb517118';
