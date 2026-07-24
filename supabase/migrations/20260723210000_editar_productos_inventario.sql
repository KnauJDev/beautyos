-- BeautyOS - Editar productos de inventario (sub-bloque 1 de 3: inventario/compras/gastos).
--
-- Hasta ahora InventarioPage era 100% de solo lectura (get_products_summary_v2).
-- No existia forma de dar de alta un producto, corregirlo o desactivarlo salvo
-- por SQL a mano. Mismo patron ya validado con servicios/estilistas
-- (create_service/update_service/set_service_active): toda escritura
-- sincroniza el catalogo del tenant (products) y la fila de sede
-- (branch_products), porque get_products_summary_v2 solo lee stock/costo/
-- precio/visibilidad desde branch_products.
--
-- Limpieza: se confirmo contra el esquema real que products.current_stock,
-- minimum_stock, purchase_price, sale_price y visible_for_sale son columnas
-- muertas -- ninguna funcion, vista ni politica RLS las lee (todo el modulo
-- usa las equivalentes en branch_products); la tabla no tenia filas. Se
-- retiran en vez de mantenerlas sincronizadas sin uso real.

begin;

alter table public.products
  drop column current_stock,
  drop column minimum_stock,
  drop column purchase_price,
  drop column sale_price,
  drop column visible_for_sale;

create or replace function public.get_products_for_management(p_branch_id uuid)
returns table (
  product_id uuid,
  name text,
  category text,
  product_type text,
  unit text,
  sku text,
  current_stock numeric,
  minimum_stock numeric,
  purchase_price numeric,
  sale_price numeric,
  visible_for_sale boolean,
  active boolean
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner', 'admin'], true
  );

  return query
  select
    p.id,
    p.name,
    coalesce(p.category, 'Sin categoria'),
    p.product_type,
    p.unit,
    p.sku,
    coalesce(bp.current_stock, 0),
    coalesce(bp.minimum_stock, 0),
    coalesce(bp.average_cost, 0),
    coalesce(bp.sale_price, 0),
    coalesce(bp.visible_for_sale, false),
    p.active and coalesce(bp.active, false)
  from public.products p
  left join public.branch_products bp
    on bp.tenant_id = v_tenant_id
   and bp.branch_id = p_branch_id
   and bp.product_id = p.id
  where p.tenant_id = v_tenant_id
  order by lower(p.name);
end;
$$;

create or replace function public.create_product(
  p_branch_id uuid,
  p_name text,
  p_category text,
  p_product_type text default 'consumable',
  p_unit text default 'unidad',
  p_sku text default null,
  p_minimum_stock numeric default 0,
  p_purchase_price numeric default 0,
  p_sale_price numeric default 0,
  p_visible_for_sale boolean default false
)
returns table (
  product_id uuid,
  branch_product_id uuid
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_product_id uuid;
  v_branch_product_id uuid;
begin
  select tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner', 'admin'], true
  );

  if length(trim(coalesce(p_name, ''))) = 0 then
    raise exception 'El nombre del producto es obligatorio.';
  end if;

  if p_product_type is null or p_product_type not in ('consumable', 'sale') then
    raise exception 'El tipo de producto debe ser insumo interno o para venta.';
  end if;

  if p_minimum_stock is null or p_minimum_stock < 0 then
    raise exception 'El stock minimo no puede ser negativo.';
  end if;

  if p_purchase_price is null or p_purchase_price < 0 then
    raise exception 'El costo de compra no puede ser negativo.';
  end if;

  if p_sale_price is null or p_sale_price < 0 then
    raise exception 'El precio de venta no puede ser negativo.';
  end if;

  insert into public.products (
    tenant_id, name, category, product_type, unit, sku
  ) values (
    v_tenant_id,
    trim(p_name),
    nullif(trim(coalesce(p_category, '')), ''),
    p_product_type,
    coalesce(nullif(trim(coalesce(p_unit, '')), ''), 'unidad'),
    nullif(trim(coalesce(p_sku, '')), '')
  )
  returning id into v_product_id;

  insert into public.branch_products (
    tenant_id, branch_id, product_id, current_stock, minimum_stock,
    average_cost, sale_price, visible_for_sale
  ) values (
    v_tenant_id,
    p_branch_id,
    v_product_id,
    0,
    p_minimum_stock,
    p_purchase_price,
    p_sale_price,
    p_visible_for_sale
  )
  returning id into v_branch_product_id;

  return query select v_product_id, v_branch_product_id;
end;
$$;

create or replace function public.update_product(
  p_branch_id uuid,
  p_product_id uuid,
  p_name text,
  p_category text,
  p_product_type text,
  p_unit text,
  p_sku text,
  p_minimum_stock numeric,
  p_purchase_price numeric,
  p_sale_price numeric,
  p_visible_for_sale boolean
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner', 'admin'], true
  );

  if length(trim(coalesce(p_name, ''))) = 0 then
    raise exception 'El nombre del producto es obligatorio.';
  end if;

  if p_product_type is null or p_product_type not in ('consumable', 'sale') then
    raise exception 'El tipo de producto debe ser insumo interno o para venta.';
  end if;

  if p_minimum_stock is null or p_minimum_stock < 0 then
    raise exception 'El stock minimo no puede ser negativo.';
  end if;

  if p_purchase_price is null or p_purchase_price < 0 then
    raise exception 'El costo de compra no puede ser negativo.';
  end if;

  if p_sale_price is null or p_sale_price < 0 then
    raise exception 'El precio de venta no puede ser negativo.';
  end if;

  update public.products
     set name = trim(p_name),
         category = nullif(trim(coalesce(p_category, '')), ''),
         product_type = p_product_type,
         unit = coalesce(nullif(trim(coalesce(p_unit, '')), ''), 'unidad'),
         sku = nullif(trim(coalesce(p_sku, '')), '')
   where id = p_product_id
     and tenant_id = v_tenant_id;

  if not found then
    raise exception 'El producto no existe o pertenece a otro negocio.';
  end if;

  update public.branch_products
     set minimum_stock = p_minimum_stock,
         average_cost = p_purchase_price,
         sale_price = p_sale_price,
         visible_for_sale = p_visible_for_sale,
         updated_at = now()
   where tenant_id = v_tenant_id
     and branch_id = p_branch_id
     and product_id = p_product_id;

  if not found then
    raise exception 'El producto no tiene fila de sede; contacta soporte.';
  end if;
end;
$$;

create or replace function public.set_product_active(
  p_branch_id uuid,
  p_product_id uuid,
  p_active boolean
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner', 'admin'], true
  );

  update public.products
     set active = p_active
   where id = p_product_id
     and tenant_id = v_tenant_id;

  if not found then
    raise exception 'El producto no existe o pertenece a otro negocio.';
  end if;

  update public.branch_products
     set active = p_active, updated_at = now()
   where tenant_id = v_tenant_id
     and branch_id = p_branch_id
     and product_id = p_product_id;
end;
$$;

revoke all on function public.get_products_for_management(uuid) from public, anon;
revoke all on function public.create_product(uuid, text, text, text, text, text, numeric, numeric, numeric, boolean) from public, anon;
revoke all on function public.update_product(uuid, uuid, text, text, text, text, text, numeric, numeric, numeric, boolean) from public, anon;
revoke all on function public.set_product_active(uuid, uuid, boolean) from public, anon;

grant execute on function public.get_products_for_management(uuid) to authenticated, service_role;
grant execute on function public.create_product(uuid, text, text, text, text, text, numeric, numeric, numeric, boolean) to authenticated, service_role;
grant execute on function public.update_product(uuid, uuid, text, text, text, text, text, numeric, numeric, numeric, boolean) to authenticated, service_role;
grant execute on function public.set_product_active(uuid, uuid, boolean) to authenticated, service_role;

commit;
