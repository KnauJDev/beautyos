create or replace function public.get_my_tenant_id()
returns uuid
language sql
security definer
set search_path = public
as $$
  select up.tenant_id
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.active = true
  limit 1;
$$;

revoke execute on function public.get_my_tenant_id() from anon;
revoke execute on function public.get_my_tenant_id() from public;

grant execute on function public.get_my_tenant_id() to authenticated;
