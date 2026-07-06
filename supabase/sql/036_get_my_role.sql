create or replace function public.get_my_role()
returns text
language sql
security definer
set search_path = public
as $$
  select up.role
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.active = true
  limit 1;
$$;

revoke execute on function public.get_my_role() from anon;
revoke execute on function public.get_my_role() from public;

grant execute on function public.get_my_role() to authenticated;
