create table if not exists public.business_hours (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  day_of_week integer not null check (day_of_week between 1 and 7),
  opens_at time,
  closes_at time,
  is_open boolean not null default true,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, day_of_week)
);

alter table public.business_hours enable row level security;

create or replace function public.get_business_hours()
returns table (
  id uuid,
  day_of_week integer,
  opens_at time,
  closes_at time,
  is_open boolean
)
language sql
security definer
set search_path = public
as $$
  select
    business_hours.id,
    business_hours.day_of_week,
    business_hours.opens_at,
    business_hours.closes_at,
    business_hours.is_open
  from public.business_hours
  join public.tenants
    on tenants.id = business_hours.tenant_id
  where tenants.active = true
    and business_hours.active = true
  order by business_hours.day_of_week asc;
$$;

grant execute on function public.get_business_hours() to anon, authenticated;
