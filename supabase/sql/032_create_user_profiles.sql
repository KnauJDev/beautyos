create table if not exists public.user_profiles (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references public.tenants(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  full_name text not null,
  role text not null default 'client',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint user_profiles_user_id_unique unique (user_id),

  constraint user_profiles_role_check check (
    role in ('owner', 'admin', 'stylist', 'assistant', 'client')
  )
);

alter table public.user_profiles enable row level security;

create index if not exists user_profiles_tenant_id_idx
on public.user_profiles (tenant_id);

create index if not exists user_profiles_user_id_idx
on public.user_profiles (user_id);

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_profiles'
      and policyname = 'Users can read their own profile'
  ) then
    create policy "Users can read their own profile"
    on public.user_profiles
    for select
    to authenticated
    using (
      auth.uid() = user_id
      and active = true
    );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_profiles'
      and policyname = 'Users can update their own name'
  ) then
    create policy "Users can update their own name"
    on public.user_profiles
    for update
    to authenticated
    using (
      auth.uid() = user_id
      and active = true
    )
    with check (
      auth.uid() = user_id
      and active = true
    );
  end if;
end $$;

grant select on public.user_profiles to authenticated;
grant update (full_name, updated_at) on public.user_profiles to authenticated;
