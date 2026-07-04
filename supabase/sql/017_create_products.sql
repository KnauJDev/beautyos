create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  name text not null,
  category text,
  product_type text not null default 'consumable'
    check (product_type in ('consumable', 'sale')),
  sku text,
  unit text not null default 'unidad',
  current_stock numeric not null default 0
    check (current_stock >= 0),
  minimum_stock numeric not null default 0
    check (minimum_stock >= 0),
  purchase_price numeric not null default 0
    check (purchase_price >= 0),
  sale_price numeric not null default 0
    check (sale_price >= 0),
  visible_for_sale boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.products enable row level security;

create or replace function public.get_products_summary()
returns table (
  id uuid,
  name text,
  category text,
  product_type text,
  unit text,
  current_stock numeric,
  minimum_stock numeric,
  purchase_price numeric,
  sale_price numeric,
  visible_for_sale boolean
)
language sql
security definer
set search_path = public
as $$
  select
    products.id,
    products.name,
    products.category,
    products.product_type,
    products.unit,
    products.current_stock,
    products.minimum_stock,
    products.purchase_price,
    products.sale_price,
    products.visible_for_sale
  from public.products
  join public.tenants
    on tenants.id = products.tenant_id
  where tenants.active = true
    and products.active = true
  order by products.name asc;
$$;

grant execute on function public.get_products_summary() to anon, authenticated;
