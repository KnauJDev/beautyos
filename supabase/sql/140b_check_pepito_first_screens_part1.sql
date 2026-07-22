select set_config(
  'request.jwt.claim.sub',
  '2975e198-2f33-4cd3-a3f2-4d93eb517118',
  true
);

select 'get_my_profile' as rpc, count(*) as filas from public.get_my_profile()
union all
select 'get_my_branch_context_v2', count(*) from public.get_my_branch_context_v2()
union all
select 'get_business_settings', count(*) from public.get_business_settings()
union all
select 'get_commission_policy', count(*) from public.get_commission_policy();
