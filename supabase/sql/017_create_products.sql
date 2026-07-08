-- ============================================================
-- 017_create_products.sql
-- BeautyOS AI
-- Propósito:
-- Crear la tabla de productos y una función segura
-- para consultar productos del tenant del usuario autenticado.
--
-- Versión endurecida:
-- - Usa tenant del usuario conectado.
-- - Requiere rol owner/admin.
-- - No permite acceso anon.
-- - Evita leer productos, stock y precios de otros negocios.
-- ============================================================

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
    raise exception 'No autorizado. Solo owner o admin puede ver productos e inventario.';
  end if;

  return query
  select
    p.id,
    p.name,
    p.category,
    p.product_type,
    p.unit,
    p.current_stock,
    p.minimum_stock,
    p.purchase_price,
    p.sale_price,
    p.visible_for_sale
  from public.products p
  join public.tenants t
    on t.id = p.tenant_id
  where p.tenant_id = current_tenant_id
    and p.active = true
    and t.active = true
  order by p.name asc;
end;
$$;

revoke execute on function public.get_products_summary() from anon;
revoke execute on function public.get_products_summary() from public;

grant execute on function public.get_products_summary() to authenticated;
