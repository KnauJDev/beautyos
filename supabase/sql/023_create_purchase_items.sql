create table if not exists public.purchase_items (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  purchase_id uuid not null references public.purchases(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  quantity numeric not null check (quantity > 0),
  unit_cost numeric not null default 0 check (unit_cost >= 0),
  line_total numeric generated always as (quantity * unit_cost) stored,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.purchase_items enable row level security;

create or replace function public.get_purchase_items_summary()
returns table (
  id uuid,
  purchase_id uuid,
  supplier_name text,
  purchase_date date,
  invoice_number text,
  product_name text,
  product_category text,
  quantity numeric,
  unit text,
  unit_cost numeric,
  line_total numeric,
  notes text
)
language sql
security definer
set search_path = public
as $$
  select
    purchase_items.id,
    purchases.id as purchase_id,
    purchases.supplier_name,
    purchases.purchase_date,
    purchases.invoice_number,
    products.name as product_name,
    products.category as product_category,
    purchase_items.quantity,
    products.unit,
    purchase_items.unit_cost,
    purchase_items.line_total,
    purchase_items.notes
  from public.purchase_items
  join public.purchases
    on purchases.id = purchase_items.purchase_id
  join public.products
    on products.id = purchase_items.product_id
  join public.tenants
    on tenants.id = purchase_items.tenant_id
  where tenants.active = true
    and purchases.active = true
    and products.active = true
  order by purchases.purchase_date desc, purchase_items.created_at desc;
$$;

grant execute on function public.get_purchase_items_summary() to anon, authenticated;
