create table if not exists public.commission_policies (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  commission_type text not null default 'percentage'
    check (commission_type in ('percentage', 'fixed')),
  commission_percentage numeric not null default 40
    check (commission_percentage >= 0 and commission_percentage <= 100),
  fixed_commission_amount numeric not null default 0
    check (fixed_commission_amount >= 0),
  applies_after_discount boolean not null default true,
  notes text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id)
);

alter table public.commission_policies enable row level security;

create or replace function public.get_commission_policy()
returns table (
  id uuid,
  commission_type text,
  commission_percentage numeric,
  fixed_commission_amount numeric,
  applies_after_discount boolean,
  notes text
)
language sql
security definer
set search_path = public
as $$
  select
    commission_policies.id,
    commission_policies.commission_type,
    commission_policies.commission_percentage,
    commission_policies.fixed_commission_amount,
    commission_policies.applies_after_discount,
    commission_policies.notes
  from public.commission_policies
  join public.tenants
    on tenants.id = commission_policies.tenant_id
  where tenants.active = true
    and commission_policies.active = true
  order by commission_policies.created_at asc
  limit 1;
$$;

grant execute on function public.get_commission_policy() to anon, authenticated;
