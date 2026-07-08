-- ============================================================
-- 019_create_inventory_movements.sql
-- BeautyOS AI
-- Propósito:
-- Crear la tabla de movimientos de inventario y una función segura
-- para consultar movimientos del tenant del usuario autenticado.
--
-- Versión endurecida:
-- - Usa tenant del usuario conectado.
-- - Requiere rol owner/admin.
-- - No permite acceso anon.
-- - Evita leer movimientos, costos y notas de otros negocios.
-- ============================================================

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
    raise exception 'No autorizado. Solo owner o admin puede ver movimientos de inventario.';
  end if;

  return query
  select
    im.id,
    p.name as product_name,
    p.category as product_category,
    im.movement_type,
    im.quantity,
    p.unit,
    im.unit_cost,
    im.notes,
    im.created_at
  from public.inventory_movements im
  join public.products p
    on p.id = im.product_id
   and p.tenant_id = current_tenant_id
  join public.tenants t
    on t.id = im.tenant_id
  where im.tenant_id = current_tenant_id
    and p.active = true
    and t.active = true
  order by im.created_at desc
  limit 50;
end;
$$;

revoke execute on function public.get_inventory_movements_summary() from anon;
revoke execute on function public.get_inventory_movements_summary() from public;

grant execute on function public.get_inventory_movements_summary() to authenticated;
