-- BeautyOS - Registrar compras de inventario (sub-bloque 2 de 3:
-- inventario/compras/gastos editables).
--
-- ComprasPage era 100% de solo lectura. Se agrega:
--
-- - create_purchase: crea la compra + sus items + un movimiento de
--   inventario 'purchase' por item + actualiza current_stock y
--   average_cost (costo promedio ponderado, redondeado a pesos) en
--   branch_products, todo en una sola transaccion. Disponible para
--   tenant_owner y admin, igual que el resto del catalogo operativo.
-- - update_purchase_header: edita solo encabezado (proveedor, fecha,
--   factura, forma de pago, notas); nunca toca cantidades, costos ni
--   stock. Solo tenant_owner -- decision explicita del propietario: los
--   errores de digitacion los corrige unicamente el dueno, no admin,
--   asistente ni estilista.
-- - void_purchase: anula la compra completa (active = false) y revierte
--   el stock y costo promedio que genero, pero SOLO si ninguna compra
--   posterior del mismo producto ya recalculo el promedio encima de esta
--   -- si no es seguro, se bloquea con un mensaje claro en vez de
--   descuadrar el costo. Solo tenant_owner. No hay borrado fisico: la
--   compra y sus movimientos de inventario quedan como historial
--   (coherente con AGENTS.md: no alterar historial financiero sin
--   trazabilidad).
-- - get_purchases_for_management: muestra tambien las compras anuladas.
--
-- inventory_movements no tenia forma de saber que compra genero cada
-- movimiento; sin eso, anular con seguridad no es posible. Se agrega
-- inventory_movements.source_purchase_id (nullable; solo se llena para
-- movement_type = 'purchase').

begin;

alter table public.inventory_movements
  add column source_purchase_id uuid references public.purchases(id);

create or replace function public.create_purchase(
  p_branch_id uuid,
  p_supplier_name text,
  p_items jsonb,
  p_purchase_date date default current_date,
  p_invoice_number text default null,
  p_payment_method text default 'cash',
  p_notes text default null
)
returns table (purchase_id uuid)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_purchase_id uuid;
  v_total_amount numeric := 0;
  v_item record;
  v_current_stock numeric;
  v_current_avg numeric;
  v_new_stock numeric;
  v_new_avg numeric;
  v_item_count integer;
begin
  select tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner', 'admin'], true
  );

  if length(trim(coalesce(p_supplier_name, ''))) = 0 then
    raise exception 'El proveedor es obligatorio.';
  end if;

  if p_payment_method is null
     or p_payment_method not in ('cash', 'transfer', 'card', 'credit', 'other') then
    raise exception 'La forma de pago no es valida.';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'La compra debe tener al menos un producto.';
  end if;

  select count(*) into v_item_count from jsonb_array_elements(p_items);
  if v_item_count = 0 then
    raise exception 'La compra debe tener al menos un producto.';
  end if;

  -- Validar cada item y calcular el total antes de insertar nada.
  for v_item in
    select
      (elem->>'product_id')::uuid as product_id,
      (elem->>'quantity')::numeric as quantity,
      (elem->>'unit_cost')::numeric as unit_cost
    from jsonb_array_elements(p_items) as elem
  loop
    if v_item.product_id is null then
      raise exception 'Cada producto de la compra debe tener un id valido.';
    end if;

    if v_item.quantity is null or v_item.quantity <= 0 then
      raise exception 'La cantidad debe ser mayor a cero.';
    end if;

    if v_item.unit_cost is null or v_item.unit_cost < 0 then
      raise exception 'El costo unitario no puede ser negativo.';
    end if;

    if not exists (
      select 1 from public.branch_products bp
      where bp.tenant_id = v_tenant_id
        and bp.branch_id = p_branch_id
        and bp.product_id = v_item.product_id
    ) then
      raise exception 'Uno de los productos no existe en esta sede.';
    end if;

    v_total_amount := v_total_amount + round(v_item.quantity * v_item.unit_cost);
  end loop;

  insert into public.purchases (
    tenant_id, branch_id, supplier_name, purchase_date, invoice_number,
    total_amount, payment_method, notes
  ) values (
    v_tenant_id,
    p_branch_id,
    trim(p_supplier_name),
    coalesce(p_purchase_date, current_date),
    nullif(trim(coalesce(p_invoice_number, '')), ''),
    v_total_amount,
    p_payment_method,
    nullif(trim(coalesce(p_notes, '')), '')
  )
  returning id into v_purchase_id;

  for v_item in
    select
      (elem->>'product_id')::uuid as product_id,
      (elem->>'quantity')::numeric as quantity,
      (elem->>'unit_cost')::numeric as unit_cost,
      nullif(trim(coalesce(elem->>'notes', '')), '') as notes
    from jsonb_array_elements(p_items) as elem
  loop
    insert into public.purchase_items (
      tenant_id, branch_id, purchase_id, product_id, quantity, unit_cost,
      notes
    ) values (
      v_tenant_id, p_branch_id, v_purchase_id, v_item.product_id,
      v_item.quantity, v_item.unit_cost, v_item.notes
    );

    insert into public.inventory_movements (
      tenant_id, branch_id, product_id, movement_type, quantity, unit_cost,
      notes, source_purchase_id
    ) values (
      v_tenant_id, p_branch_id, v_item.product_id, 'purchase', v_item.quantity,
      v_item.unit_cost, v_item.notes, v_purchase_id
    );

    select current_stock, average_cost
      into v_current_stock, v_current_avg
    from public.branch_products
    where tenant_id = v_tenant_id
      and branch_id = p_branch_id
      and product_id = v_item.product_id
    for update;

    v_new_stock := v_current_stock + v_item.quantity;
    v_new_avg := case
      when v_current_stock = 0 then v_item.unit_cost
      else round(
        (v_current_stock * v_current_avg + v_item.quantity * v_item.unit_cost)
        / v_new_stock
      )
    end;

    update public.branch_products
       set current_stock = v_new_stock,
           average_cost = v_new_avg,
           updated_at = now()
     where tenant_id = v_tenant_id
       and branch_id = p_branch_id
       and product_id = v_item.product_id;
  end loop;

  return query select v_purchase_id;
end;
$$;

create or replace function public.update_purchase_header(
  p_branch_id uuid,
  p_purchase_id uuid,
  p_supplier_name text,
  p_purchase_date date,
  p_invoice_number text,
  p_payment_method text,
  p_notes text
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
    p_branch_id, array['tenant_owner'], true
  );

  if length(trim(coalesce(p_supplier_name, ''))) = 0 then
    raise exception 'El proveedor es obligatorio.';
  end if;

  if p_payment_method is null
     or p_payment_method not in ('cash', 'transfer', 'card', 'credit', 'other') then
    raise exception 'La forma de pago no es valida.';
  end if;

  update public.purchases
     set supplier_name = trim(p_supplier_name),
         purchase_date = coalesce(p_purchase_date, purchase_date),
         invoice_number = nullif(trim(coalesce(p_invoice_number, '')), ''),
         payment_method = p_payment_method,
         notes = nullif(trim(coalesce(p_notes, '')), ''),
         updated_at = now()
   where id = p_purchase_id
     and tenant_id = v_tenant_id
     and branch_id = p_branch_id
     and active;

  if not found then
    raise exception 'La compra no existe, ya esta anulada o pertenece a otro negocio.';
  end if;
end;
$$;

create or replace function public.void_purchase(
  p_branch_id uuid,
  p_purchase_id uuid
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_movement record;
  v_current_stock numeric;
  v_current_avg numeric;
  v_old_stock_before numeric;
  v_new_avg numeric;
  v_blocking_product text;
begin
  select tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner'], true
  );

  if not exists (
    select 1 from public.purchases
    where id = p_purchase_id
      and tenant_id = v_tenant_id
      and branch_id = p_branch_id
      and active
  ) then
    raise exception 'La compra no existe, ya esta anulada o pertenece a otro negocio.';
  end if;

  -- Bloquear si algun producto de esta compra ya tiene una compra
  -- posterior que recalculo el costo promedio encima de esta.
  select p.name
    into v_blocking_product
  from public.inventory_movements im
  join public.products p on p.id = im.product_id
  where im.source_purchase_id = p_purchase_id
    and exists (
      select 1
      from public.inventory_movements im2
      join public.purchases p2 on p2.id = im2.source_purchase_id
      where im2.tenant_id = im.tenant_id
        and im2.branch_id = im.branch_id
        and im2.product_id = im.product_id
        and im2.movement_type = 'purchase'
        and im2.source_purchase_id is distinct from p_purchase_id
        and im2.created_at > im.created_at
        and p2.active
    )
  limit 1;

  if v_blocking_product is not null then
    raise exception 'No se puede anular: ya hay una compra posterior de "%" que recalculo el costo promedio.', v_blocking_product;
  end if;

  for v_movement in
    select im.product_id, im.quantity, im.unit_cost
    from public.inventory_movements im
    where im.source_purchase_id = p_purchase_id
      and im.tenant_id = v_tenant_id
  loop
    select current_stock, average_cost
      into v_current_stock, v_current_avg
    from public.branch_products
    where tenant_id = v_tenant_id
      and branch_id = p_branch_id
      and product_id = v_movement.product_id
    for update;

    if v_current_stock < v_movement.quantity then
      raise exception 'No se puede anular: el stock actual ya es menor a lo que agrego esta compra.';
    end if;

    v_old_stock_before := v_current_stock - v_movement.quantity;

    if v_old_stock_before = 0 then
      v_new_avg := 0;
    else
      v_new_avg := round(
        (v_current_stock * v_current_avg - v_movement.quantity * v_movement.unit_cost)
        / v_old_stock_before
      );
    end if;

    update public.branch_products
       set current_stock = v_old_stock_before,
           average_cost = v_new_avg,
           updated_at = now()
     where tenant_id = v_tenant_id
       and branch_id = p_branch_id
       and product_id = v_movement.product_id;
  end loop;

  update public.purchases
     set active = false, updated_at = now()
   where id = p_purchase_id
     and tenant_id = v_tenant_id
     and branch_id = p_branch_id;
end;
$$;

create or replace function public.get_purchases_for_management(p_branch_id uuid)
returns table (
  purchase_id uuid,
  supplier_name text,
  purchase_date date,
  invoice_number text,
  total_amount numeric,
  payment_method text,
  notes text,
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
  select p.id, p.supplier_name, p.purchase_date, p.invoice_number,
         p.total_amount, p.payment_method, p.notes, p.active
  from public.purchases p
  where p.tenant_id = v_tenant_id
    and p.branch_id = p_branch_id
  order by p.purchase_date desc, p.created_at desc;
end;
$$;

revoke all on function public.create_purchase(uuid, text, jsonb, date, text, text, text) from public, anon;
revoke all on function public.update_purchase_header(uuid, uuid, text, date, text, text, text) from public, anon;
revoke all on function public.void_purchase(uuid, uuid) from public, anon;
revoke all on function public.get_purchases_for_management(uuid) from public, anon;

grant execute on function public.create_purchase(uuid, text, jsonb, date, text, text, text) to authenticated, service_role;
grant execute on function public.update_purchase_header(uuid, uuid, text, date, text, text, text) to authenticated, service_role;
grant execute on function public.void_purchase(uuid, uuid) to authenticated, service_role;
grant execute on function public.get_purchases_for_management(uuid) to authenticated, service_role;

commit;
