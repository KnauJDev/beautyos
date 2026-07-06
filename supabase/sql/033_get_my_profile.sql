create or replace function public.get_my_profile()
returns table (
  id uuid,
  tenant_id uuid,
  tenant_name text,
  user_id uuid,
  full_name text,
  role text,
  active boolean
)
language sql
security definer
set search_path = public
as $$
  select
    up.id,
    up.tenant_id,
    t.name as tenant_name,
    up.user_id,
    up.full_name,
    up.role,
    up.active
  from public.user_profiles up
  left join public.tenants t
    on t.id = up.tenant_id
  where up.user_id = auth.uid()
    and up.active = true
  limit 1;
$$;

revoke execute on function public.get_my_profile() from anon;
revoke execute on function public.get_my_profile() from public;

grant execute on function public.get_my_profile() to authenticated;
