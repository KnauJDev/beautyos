-- BeautyOS - Punto 8 de BENCHMARKING_2026-07-28.md: marca de producto +
-- alarma de stock por correo.
--
-- Alcance acordado con el propietario:
-- - Marca: campo de texto en el catalogo del producto (tenant), mismo nivel
--   que category. No incluye IVA ni comision de venta de producto (fuera de
--   alcance de este bloque, ver fila de la tabla resumen del benchmarking).
-- - Alarma de stock: se dispara al registrar un consumo interno (no revision
--   diaria programada, para no introducir pg_cron/Scheduled Functions).
--   Reutiliza exactamente el patron de D-065 (Edge Function con
--   auth: "user" + RPC security definer que entrega el contexto + Resend).
--   Destino: tenants.contact_email, sin campo nuevo.

begin;

-- ============================================================
-- 1. Marca de producto.
-- ============================================================

alter table public.products
  add column if not exists brand text;

comment on column public.products.brand
  is 'Marca del producto (ej. Loreal, Wella). Null si no se ha registrado.';

drop function if exists public.get_products_for_management(uuid);
drop function if exists public.create_product(uuid, text, text, text, text, text, numeric, numeric, numeric, boolean);
drop function if exists public.update_product(uuid, uuid, text, text, text, text, text, numeric, numeric, numeric, boolean);

create or replace function public.get_products_for_management(p_branch_id uuid)
returns table (
  product_id uuid,
  name text,
  category text,
  brand text,
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
    p.brand,
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
  p_visible_for_sale boolean default false,
  p_brand text default null
)
returns table (product_id uuid, branch_product_id uuid)
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

  perform private.beautyos_require_entitlement(
    v_tenant_id, 'inventory',
    'Tu plan actual no incluye inventario. Mejora tu plan para agregar productos nuevos.'
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
    tenant_id, name, category, product_type, unit, sku, brand
  ) values (
    v_tenant_id,
    trim(p_name),
    nullif(trim(coalesce(p_category, '')), ''),
    p_product_type,
    coalesce(nullif(trim(coalesce(p_unit, '')), ''), 'unidad'),
    nullif(trim(coalesce(p_sku, '')), ''),
    nullif(trim(coalesce(p_brand, '')), '')
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
  p_visible_for_sale boolean,
  p_brand text default null
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
         sku = nullif(trim(coalesce(p_sku, '')), ''),
         brand = nullif(trim(coalesce(p_brand, '')), '')
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

revoke all on function public.get_products_for_management(uuid) from public, anon;
revoke all on function public.create_product(uuid, text, text, text, text, text, numeric, numeric, numeric, boolean, text) from public, anon;
revoke all on function public.update_product(uuid, uuid, text, text, text, text, text, numeric, numeric, numeric, boolean, text) from public, anon;

grant execute on function public.get_products_for_management(uuid) to authenticated, service_role;
grant execute on function public.create_product(uuid, text, text, text, text, text, numeric, numeric, numeric, boolean, text) to authenticated, service_role;
grant execute on function public.update_product(uuid, uuid, text, text, text, text, text, numeric, numeric, numeric, boolean, text) to authenticated, service_role;

-- ============================================================
-- 2. Alarma de stock por correo (disparada al registrar un consumo).
-- ============================================================

-- Solo entrega datos (y por tanto solo se envia correo) si el producto
-- realmente esta en el minimo o por debajo, hay correo de contacto, y quien
-- llama tiene acceso de owner/admin a esa sede -- mismo criterio de
-- autorizacion que create_stock_consumption. Si no se cumple, no hay fila:
-- la Edge Function simplemente no envia nada, sin distinguir el motivo.
create or replace function public.get_low_stock_alert_context(
  p_branch_id uuid,
  p_product_id uuid
)
returns table (
  contact_email text,
  business_name text,
  branch_name text,
  product_name text,
  brand text,
  current_stock numeric,
  minimum_stock numeric,
  unit text
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
    t.contact_email,
    t.name,
    b.name,
    p.name,
    p.brand,
    bp.current_stock,
    bp.minimum_stock,
    p.unit
  from public.branch_products bp
  join public.products p
    on p.tenant_id = bp.tenant_id
   and p.id = bp.product_id
  join public.branches b
    on b.id = bp.branch_id
  join public.tenants t
    on t.id = bp.tenant_id
  where bp.tenant_id = v_tenant_id
    and bp.branch_id = p_branch_id
    and bp.product_id = p_product_id
    and bp.current_stock <= bp.minimum_stock
    and t.contact_email is not null;
end;
$$;

revoke all on function public.get_low_stock_alert_context(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.get_low_stock_alert_context(uuid, uuid)
  to authenticated;

comment on function public.get_low_stock_alert_context(uuid, uuid)
  is 'Contexto para el correo de alarma de stock bajo (Edge Function send-low-stock-alert). Solo devuelve una fila si el producto esta realmente en el minimo o por debajo y hay correo de contacto configurado.';

commit;
