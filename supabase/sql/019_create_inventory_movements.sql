create table if not exists public.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  movement_type text not null
    check (movement_type in ('purchase', 'consumption', 'sale', 'gift', 'package', 'adjustment')),
  quantity numeric not null check (quantity > 0),
  unit_cost numeric not null default 0 check (unit_cost >= 0),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.inventory_movements enable row level security;

create or replace function public.get_inventory_movements_summary()
returns table (
  id uuid,
  product_name text,
  product_category text,
  movement_type text,
  quantity numeric,
  unit text,
  unit_cost numeric,
  notes text,
  created_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    inventory_movements.id,
    products.name as product_name,
    products.category as product_category,
    inventory_movements.movement_type,
    inventory_movements.quantity,
    products.unit,
    inventory_movements.unit_cost,
    inventory_movements.notes,
    inventory_movements.created_at
  from public.inventory_movements
  join public.products
    on products.id = inventory_movements.product_id
  join public.tenants
    on tenants.id = inventory_movements.tenant_id
  where tenants.active = true
  order by inventory_movements.created_at desc
  limit 50;
$$;

grant execute on function public.get_inventory_movements_summary() to anon, authenticated;
