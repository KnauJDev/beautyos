-- BeautyOS - Registrar consumo interno de inventario.
--
-- Hueco detectado tras cerrar inventario/compras/gastos: no habia forma
-- de sacar stock cuando un producto (para venta o insumo) se usa dentro
-- del negocio en vez de venderse. inventory_movements ya preveia
-- movement_type = 'consumption' desde antes de esta sesion, pero ninguna
-- funcion lo escribia.
--
-- Decision del propietario: el consumo interno SOLO resta stock y queda
-- en el historial de movimientos. No toca get_branch_financial_summary_v2
-- (neto = ventas - compras - gastos - comisiones) porque esa plata ya se
-- resto del neto en el momento de la compra; restarla otra vez al
-- consumir seria contarla doble. Si mas adelante se quiere un modelo
-- contable por costo-de-lo-realmente-usado, es un cambio aparte y mas
-- grande sobre ese RPC (no incluido aqui).
--
-- No cambia average_cost: consumir no altera el costo del stock que
-- queda, solo comprar lo cambia.

begin;

create or replace function public.create_stock_consumption(
  p_branch_id uuid,
  p_product_id uuid,
  p_quantity numeric,
  p_notes text default null
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_current_stock numeric;
  v_current_avg numeric;
begin
  select tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner', 'admin'], true
  );

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'La cantidad debe ser mayor a cero.';
  end if;

  select current_stock, average_cost
    into v_current_stock, v_current_avg
  from public.branch_products
  where tenant_id = v_tenant_id
    and branch_id = p_branch_id
    and product_id = p_product_id
  for update;

  if not found then
    raise exception 'El producto no existe en esta sede.';
  end if;

  if v_current_stock < p_quantity then
    raise exception 'No hay stock suficiente: quedan % unidades.', v_current_stock;
  end if;

  insert into public.inventory_movements (
    tenant_id, branch_id, product_id, movement_type, quantity, unit_cost,
    notes
  ) values (
    v_tenant_id, p_branch_id, p_product_id, 'consumption', p_quantity,
    v_current_avg, nullif(trim(coalesce(p_notes, '')), '')
  );

  update public.branch_products
     set current_stock = v_current_stock - p_quantity,
         updated_at = now()
   where tenant_id = v_tenant_id
     and branch_id = p_branch_id
     and product_id = p_product_id;
end;
$$;

revoke all on function public.create_stock_consumption(uuid, uuid, numeric, text) from public, anon;
grant execute on function public.create_stock_consumption(uuid, uuid, numeric, text) to authenticated, service_role;

commit;
