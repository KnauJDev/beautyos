insert into public.inventory_movements (
  tenant_id,
  product_id,
  movement_type,
  quantity,
  unit_cost,
  notes
)
select
  tenants.id,
  products.id,
  movement.movement_type,
  movement.quantity,
  movement.unit_cost,
  movement.notes
from public.tenants
join public.products
  on products.tenant_id = tenants.id
join (
  values
    (
      'INS-SHAMPOO-HID',
      'purchase',
      2500,
      35000,
      'Entrada demo inicial de shampoo hidratante profesional.'
    ),
    (
      'INS-SHAMPOO-HID',
      'consumption',
      120,
      0,
      'Consumo demo en servicio de lavado y cepillado.'
    ),
    (
      'INS-TINTE-RC',
      'purchase',
      12,
      18000,
      'Entrada demo inicial de tintes rubio claro.'
    ),
    (
      'VEN-ACEITE-REP',
      'sale',
      1,
      22000,
      'Venta demo de aceite capilar reparador.'
    ),
    (
      'VEN-CREMA-PEINAR',
      'gift',
      1,
      16000,
      'Obsequio demo para cliente frecuente.'
    )
) as movement(
  product_sku,
  movement_type,
  quantity,
  unit_cost,
  notes
)
  on products.sku = movement.product_sku
where tenants.name = 'Bella Mujer'
  and not exists (
    select 1
    from public.inventory_movements existing_movements
    where existing_movements.product_id = products.id
      and existing_movements.movement_type = movement.movement_type
      and existing_movements.notes = movement.notes
  );
