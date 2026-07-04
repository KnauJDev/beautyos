create table if not exists public.purchases (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  supplier_name text not null,
  purchase_date date not null default current_date,
  invoice_number text,
  total_amount numeric not null default 0 check (total_amount >= 0),
  payment_method text not null default 'cash'
    check (payment_method in ('cash', 'transfer', 'card', 'credit', 'other')),
  notes text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.purchases enable row level security;

create or replace function public.get_purchases_summary()
returns table (
  id uuid,
  supplier_name text,
  purchase_date date,
  invoice_number text,
  total_amount numeric,
  payment_method text,
  notes text
)
language sql
security definer
set search_path = public
as $$
  select
    purchases.id,
    purchases.supplier_name,
    purchases.purchase_date,
    purchases.invoice_number,
    purchases.total_amount,
    purchases.payment_method,
    purchases.notes
  from public.purchases
  join public.tenants
    on tenants.id = purchases.tenant_id
  where tenants.active = true
    and purchases.active = true
  order by purchases.purchase_date desc, purchases.created_at desc;
$$;

grant execute on function public.get_purchases_summary() to anon, authenticated;
