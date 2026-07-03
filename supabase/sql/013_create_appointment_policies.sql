create table if not exists public.appointment_policies (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  requires_deposit boolean not null default false,
  deposit_percentage numeric not null default 0 check (deposit_percentage >= 0 and deposit_percentage <= 100),
  cancellation_hours integer not null default 24 check (cancellation_hours >= 0),
  reschedule_hours integer not null default 24 check (reschedule_hours >= 0),
  manual_confirmation_required boolean not null default true,
  customer_reschedule_allowed boolean not null default true,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id)
);

alter table public.appointment_policies enable row level security;

create or replace function public.get_appointment_policy()
returns table (
  id uuid,
  requires_deposit boolean,
  deposit_percentage numeric,
  cancellation_hours integer,
  reschedule_hours integer,
  manual_confirmation_required boolean,
  customer_reschedule_allowed boolean
)
language sql
security definer
set search_path = public
as $$
  select
    appointment_policies.id,
    appointment_policies.requires_deposit,
    appointment_policies.deposit_percentage,
    appointment_policies.cancellation_hours,
    appointment_policies.reschedule_hours,
    appointment_policies.manual_confirmation_required,
    appointment_policies.customer_reschedule_allowed
  from public.appointment_policies
  join public.tenants
    on tenants.id = appointment_policies.tenant_id
  where tenants.active = true
    and appointment_policies.active = true
  order by appointment_policies.created_at asc
  limit 1;
$$;

grant execute on function public.get_appointment_policy() to anon, authenticated;
