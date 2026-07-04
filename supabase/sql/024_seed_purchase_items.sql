insert into public.purchase_items (
  tenant_id,
  purchase_id,
  product_id,
  quantity,
  unit_cost,
  notes
)
select
  tenants.id,
  purchases.id,
  products.id,
  item.quantity,
  item.unit_cost,
  item.notes
from public.tenants
join public.purchases
  on purchases.tenant_id = tenants.id
join (
  values
    (
      'FAC-001-BM',
      'INS-SHAMPOO-HID',
      2500,
      14,
      'Detalle demo: compra de 2500 ml de shampoo hidratante profesional.'
    ),
    (
      'FAC-001-BM',
      'INS-TINTE-RC',
      12,
      1500,
      'Detalle demo: compra de 12 unidades de tinte rubio claro.'
    ),
    (
      'FAC-002-BM',
      'VEN-ACEITE-REP',
      1,
      22000,
      'Detalle demo: compra de aceite capilar reparador para venta.'
    ),
    (
      'FAC-002-BM',
      'VEN-CREMA-PEINAR',
      1,
      16000,
      'Detalle demo: compra de crema para peinar para venta.'
    )
) as item(
  invoice_number,
  product_sku,
  quantity,
  unit_cost,
  notes
)
  on item.invoice_number = purchases.invoice_number
join public.products
  on products.tenant_id = tenants.id
  and products.sku = item.product_sku
where tenants.name = 'Bella Mujer'
  and not exists (
    select 1
    from public.purchase_items existing_items
    where existing_items.purchase_id = purchases.id
      and existing_items.product_id = products.id
  );
