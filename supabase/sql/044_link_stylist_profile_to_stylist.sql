alter table public.user_profiles
add column if not exists stylist_id uuid null;

do $$
begin
  if not exists (
    select 1
    from information_schema.table_constraints
    where constraint_schema = 'public'
      and table_name = 'user_profiles'
      and constraint_name = 'user_profiles_stylist_id_fkey'
  ) then
    alter table public.user_profiles
    add constraint user_profiles_stylist_id_fkey
    foreign key (stylist_id)
    references public.stylists(id)
    on delete set null;
  end if;
end $$;

create index if not exists user_profiles_stylist_id_idx
on public.user_profiles (stylist_id);

update public.user_profiles
set
  stylist_id = 'a6bef6b5-5473-40bb-a18b-16a88b312a0c',
  updated_at = now()
where user_id = '067dd2e6-9a10-4965-a804-4601c60d724f'
  and tenant_id = 'd338021b-1aed-4d4c-8462-0fc571867798';

select
  up.id,
  up.user_id,
  up.full_name,
  up.role,
  up.active,
  up.tenant_id,
  t.name as tenant_name,
  up.stylist_id,
  s.name as stylist_name,
  s.specialty as stylist_specialty
from public.user_profiles up
left join public.tenants t
  on t.id = up.tenant_id
left join public.stylists s
  on s.id = up.stylist_id
where up.user_id = '067dd2e6-9a10-4965-a804-4601c60d724f';
