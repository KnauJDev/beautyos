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
language plpgsql
security definer
set search_path = public
as $$
declare
  current_tenant_id uuid;
begin
  current_tenant_id := public.get_my_tenant_id();

  if current_tenant_id is null then
    raise exception 'No existe un perfil activo asociado al usuario actual.';
  end if;

  if not public.is_owner_or_admin() then
    raise exception 'No autorizado. Solo owner o admin puede ver detalle de compras.';
  end if;

  return query
  select
    pi.id,
    p.id as purchase_id,
    p.supplier_name,
    p.purchase_date,
    p.invoice_number,
    pr.name as product_name,
    pr.category as product_category,
    pi.quantity,
    pr.unit,
    pi.unit_cost,
    pi.line_total,
    pi.notes
  from public.purchase_items pi
  join public.purchases p
    on p.id = pi.purchase_id
  join public.products pr
    on pr.id = pi.product_id
  where pi.tenant_id = current_tenant_id
    and p.tenant_id = current_tenant_id
    and pr.tenant_id = current_tenant_id
    and p.active = true
    and pr.active = true
  order by p.purchase_date desc, pi.created_at desc;
end;
$$;

revoke execute on function public.get_purchase_items_summary() from anon;
revoke execute on function public.get_purchase_items_summary() from public;

grant execute on function public.get_purchase_items_summary() to authenticated;
