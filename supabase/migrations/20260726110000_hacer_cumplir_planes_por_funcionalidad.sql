-- BeautyOS - Hacer cumplir los planes por funcionalidad (bloque 2 de
-- "hacer cumplir los planes", punto 2.2 de RUTA_GENERAL_2026-07-25.md).
--
-- Regla acordada con el propietario: solo se bloquean las acciones que
-- CREAN una instancia nueva de una funcionalidad de plan superior
-- (producto, compra, gasto, consumo, foto de trabajo, resena). Editar,
-- desactivar, anular o aprobar algo que ya existe sigue funcionando igual
-- sin importar el plan -- mismo criterio que "cerrar lo que ya esta
-- abierto" usado en D-068 para la prueba vencida: nunca se quita gestion
-- de datos ya existentes.
--
-- Excepcion: "financial_reports" no tiene ninguna accion de crear (es
-- 100% de lectura), asi que ahi se bloquea la lectura misma
-- (get_sales_report_summary_v2 / get_branch_financial_summary_v2); de lo
-- contrario la diferenciacion comercial de esa funcionalidad no existiria.
--
-- Nota: hoy ningun tenant real esta en plan Basico (todos quedaron en
-- Profesional desde D-044) y no existe pantalla para cambiar de plan, asi
-- que este bloqueo queda construido y probado con datos simulados, sin
-- efecto visible todavia en el proyecto real.

begin;

create or replace function private.beautyos_require_entitlement(
  p_tenant_id uuid,
  p_feature_key text,
  p_error_message text
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_result record;
begin
  select *
    into v_result
  from private.beautyos_resolve_entitlement(p_tenant_id, p_feature_key);

  if not coalesce(v_result.entitled, false) then
    raise exception '%', p_error_message;
  end if;
end;
$$;

revoke all on function private.beautyos_require_entitlement(uuid, text, text)
  from public, anon, authenticated;
grant execute on function private.beautyos_require_entitlement(uuid, text, text)
  to service_role;

comment on function private.beautyos_require_entitlement(uuid, text, text)
  is 'Lanza p_error_message si el tenant no tiene la funcionalidad p_feature_key incluida en su plan (ni por override).';

-- inventory: crear producto, compra, gasto o consumo interno.

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

create or replace function public.create_purchase(
  p_branch_id uuid,
  p_supplier_name text,
  p_items jsonb,
  p_purchase_date date default current_date,
  p_invoice_number text default null,
  p_payment_method text default 'cash',
  p_notes text default null
)
returns table (
  purchase_id uuid
)
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

  perform private.beautyos_require_entitlement(
    v_tenant_id, 'inventory',
    'Tu plan actual no incluye compras. Mejora tu plan para registrar compras nuevas.'
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

create or replace function public.create_expense(
  p_branch_id uuid,
  p_category text,
  p_description text,
  p_amount numeric,
  p_expense_date date default current_date,
  p_payment_method text default 'cash',
  p_notes text default null
)
returns table (
  expense_id uuid
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_expense_id uuid;
begin
  select tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner', 'admin'], true
  );

  perform private.beautyos_require_entitlement(
    v_tenant_id, 'inventory',
    'Tu plan actual no incluye gastos. Mejora tu plan para registrar gastos nuevos.'
  );

  if length(trim(coalesce(p_category, ''))) = 0 then
    raise exception 'La categoria es obligatoria.';
  end if;

  if length(trim(coalesce(p_description, ''))) = 0 then
    raise exception 'La descripcion es obligatoria.';
  end if;

  if p_amount is null or p_amount < 0 then
    raise exception 'El valor no puede ser negativo.';
  end if;

  if p_payment_method is null
     or p_payment_method not in ('cash', 'transfer', 'card', 'credit', 'other') then
    raise exception 'La forma de pago no es valida.';
  end if;

  insert into public.expenses (
    tenant_id, branch_id, expense_date, category, description, amount,
    payment_method, notes
  ) values (
    v_tenant_id,
    p_branch_id,
    coalesce(p_expense_date, current_date),
    trim(p_category),
    trim(p_description),
    p_amount,
    p_payment_method,
    nullif(trim(coalesce(p_notes, '')), '')
  )
  returning id into v_expense_id;

  return query select v_expense_id;
end;
$$;

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

  perform private.beautyos_require_entitlement(
    v_tenant_id, 'inventory',
    'Tu plan actual no incluye inventario. Mejora tu plan para registrar consumo interno.'
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

-- financial_reports: sin accion de crear, se bloquea la lectura misma.

create or replace function public.get_sales_report_summary_v2(
  p_branch_id uuid
)
returns table (
  service_name text,
  stylist_name text,
  tickets_count integer,
  total_sales numeric,
  total_duration_minutes integer
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select c.tenant_id into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner','admin'], true
  ) c;

  perform private.beautyos_require_entitlement(
    v_tenant_id, 'financial_reports',
    'Tu plan actual no incluye reportes financieros ampliados.'
  );

  return query
  select
    coalesce(s.name, 'Sin servicio'),
    coalesce(st.name, 'Sin estilista'),
    count(distinct t.id)::integer,
    coalesce(sum(ts.price), 0)::numeric,
    coalesce(sum(ts.duration_minutes), 0)::integer
  from public.tickets t
  join public.ticket_services ts
    on ts.ticket_id = t.id
   and ts.tenant_id = v_tenant_id
   and ts.branch_id = p_branch_id
   and ts.status = 'finalizado'
  join public.services s
    on s.id = ts.service_id
   and s.tenant_id = v_tenant_id
  left join public.stylists st
    on st.id = ts.stylist_id
   and st.tenant_id = v_tenant_id
  where t.tenant_id = v_tenant_id
    and t.branch_id = p_branch_id
    and t.status = 'cerrado'
  group by s.name, st.name
  order by total_sales desc, service_name asc;
end;
$$;

create or replace function public.get_branch_financial_summary_v2(
  p_branch_id uuid
)
returns table (
  total_sales numeric,
  total_purchases numeric,
  total_expenses numeric,
  total_commissions numeric,
  net_result numeric
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select c.tenant_id into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner','admin'], true
  ) c;

  perform private.beautyos_require_entitlement(
    v_tenant_id, 'financial_reports',
    'Tu plan actual no incluye reportes financieros ampliados.'
  );

  return query
  with totals as (
    select
      coalesce((
        select sum(tp.amount)
        from public.ticket_payments tp
        where tp.tenant_id = v_tenant_id
          and tp.branch_id = p_branch_id
          and tp.status = 'registrado'
      ), 0)::numeric as sales,
      coalesce((
        select sum(p.total_amount)
        from public.purchases p
        where p.tenant_id = v_tenant_id
          and p.branch_id = p_branch_id
          and p.active
      ), 0)::numeric as purchases,
      coalesce((
        select sum(e.amount)
        from public.expenses e
        where e.tenant_id = v_tenant_id
          and e.branch_id = p_branch_id
          and e.active
      ), 0)::numeric as expenses,
      coalesce((
        select sum(sc.commission_amount)
        from public.stylist_commissions sc
        where sc.tenant_id = v_tenant_id
          and sc.branch_id = p_branch_id
          and sc.status = 'generada'
      ), 0)::numeric as commissions
  )
  select
    t.sales,
    t.purchases,
    t.expenses,
    t.commissions,
    (t.sales - t.purchases - t.expenses - t.commissions)::numeric
  from totals t;
end;
$$;

-- portfolio: crear una foto de trabajo nueva.

create or replace function public.create_work_photo(
  p_branch_id uuid,
  p_ticket_id uuid,
  p_photo_url text,
  p_photo_type text,
  p_caption text default null,
  p_stylist_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_access record;
  v_tenant_id uuid;
  v_client_id uuid;
  v_ticket_status text;
  v_stylist_id uuid;
  v_photo_id uuid;
begin
  select * into strict v_access
  from private.beautyos_resolve_branch_access(
    p_branch_id,
    array['tenant_owner', 'admin', 'stylist']::text[],
    true
  );

  perform private.beautyos_require_entitlement(
    v_access.tenant_id, 'portfolio',
    'Tu plan actual no incluye fotos de trabajo. Mejora tu plan para agregar fotos nuevas.'
  );

  select tk.tenant_id, tk.client_id, tk.status
    into v_tenant_id, v_client_id, v_ticket_status
  from public.tickets tk
  where tk.id = p_ticket_id
    and tk.tenant_id = v_access.tenant_id
    and tk.branch_id = v_access.branch_id;

  if not found then
    raise exception 'El ticket no existe o no pertenece a esta sede.';
  end if;

  if v_ticket_status in ('cancelado', 'no_asistio') then
    raise exception 'No se pueden agregar fotos a un ticket cancelado o no asistido.';
  end if;

  if p_photo_type not in ('before', 'after', 'final', 'portfolio') then
    raise exception 'Tipo de foto invalido.';
  end if;

  if p_photo_url is null or trim(p_photo_url) = '' then
    raise exception 'Falta la URL de la foto.';
  end if;

  if v_access.role = 'stylist' then
    v_stylist_id := v_access.stylist_id;
  elsif p_stylist_id is not null then
    if not exists (
      select 1
      from public.ticket_services ts
      where ts.ticket_id = p_ticket_id
        and ts.stylist_id = p_stylist_id
    ) then
      raise exception 'El estilista seleccionado no corresponde a este ticket.';
    end if;
    v_stylist_id := p_stylist_id;
  else
    v_stylist_id := null;
  end if;

  insert into public.work_photos (
    tenant_id, branch_id, ticket_id, client_id, stylist_id,
    photo_url, photo_type, caption
  ) values (
    v_tenant_id,
    p_branch_id,
    p_ticket_id,
    v_client_id,
    v_stylist_id,
    trim(p_photo_url),
    p_photo_type,
    nullif(trim(coalesce(p_caption, '')), '')
  )
  returning id into v_photo_id;

  return v_photo_id;
end;
$$;

-- reviews: un cliente dejando una resena nueva. Mensaje generico porque
-- quien llama es anonimo, sin exponer detalles de facturacion.

create or replace function public.public_create_review(
  p_ticket_id uuid,
  p_rating integer,
  p_comment text default null,
  p_stylist_id uuid default null,
  p_service_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_branch_id uuid;
  v_client_id uuid;
  v_status text;
  v_review_id uuid;
begin
  select tk.tenant_id, tk.branch_id, tk.client_id, tk.status
    into v_tenant_id, v_branch_id, v_client_id, v_status
  from public.tickets tk
  where tk.id = p_ticket_id;

  if not found then
    raise exception 'Este enlace de resena no es valido.';
  end if;

  perform private.beautyos_require_entitlement(
    v_tenant_id, 'reviews',
    'Este negocio no tiene disponible dejar resenas en este momento.'
  );

  if v_status not in ('finalizado', 'cerrado') then
    raise exception 'Esta visita todavia no ha finalizado, no se puede calificar todavia.';
  end if;

  if exists (
    select 1
    from public.reviews r
    where r.ticket_id = p_ticket_id
      and r.active
  ) then
    raise exception 'Ya se registro una resena para esta visita.';
  end if;

  if p_rating is null or p_rating < 1 or p_rating > 5 then
    raise exception 'La calificacion debe ser entre 1 y 5 estrellas.';
  end if;

  if p_stylist_id is not null and p_service_id is not null then
    if not exists (
      select 1
      from public.ticket_services ts
      where ts.ticket_id = p_ticket_id
        and ts.stylist_id = p_stylist_id
        and ts.service_id = p_service_id
    ) then
      raise exception 'El estilista o servicio seleccionado no corresponde a esta visita.';
    end if;
  elsif p_stylist_id is not null or p_service_id is not null then
    raise exception 'Selecciona estilista y servicio juntos, o ninguno de los dos.';
  end if;

  insert into public.reviews (
    tenant_id, branch_id, ticket_id, client_id, stylist_id, service_id,
    rating, comment, moderation_status, visible_to_public
  ) values (
    v_tenant_id,
    v_branch_id,
    p_ticket_id,
    v_client_id,
    p_stylist_id,
    p_service_id,
    p_rating,
    nullif(trim(coalesce(p_comment, '')), ''),
    'pending',
    false
  )
  returning id into v_review_id;

  return v_review_id;
end;
$$;

commit;
