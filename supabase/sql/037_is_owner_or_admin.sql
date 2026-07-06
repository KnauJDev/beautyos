create or replace function public.is_owner_or_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_profiles up
    where up.user_id = auth.uid()
      and up.active = true
      and up.role in ('owner', 'admin')
  );
$$;

revoke execute on function public.is_owner_or_admin() from anon;
revoke execute on function public.is_owner_or_admin() from public;

grant execute on function public.is_owner_or_admin() to authenticated;
