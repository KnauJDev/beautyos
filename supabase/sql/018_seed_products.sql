insert into public.products (
  tenant_id,
  name,
  category,
  product_type,
  sku,
  unit,
  current_stock,
  minimum_stock,
  purchase_price,
  sale_price,
  visible_for_sale,
  active
)
select
  tenants.id,
  product.name,
  product.category,
  product.product_type,
  product.sku,
  product.unit,
  product.current_stock,
  product.minimum_stock,
  product.purchase_price,
  product.sale_price,
  product.visible_for_sale,
  true
from public.tenants
cross join (
  values
    (
      'Shampoo hidratante profesional',
      'Cabello',
      'consumable',
      'INS-SHAMPOO-HID',
      'ml',
      2500,
      500,
      35000,
      0,
      false
    ),
    (
      'Tinte rubio claro',
      'Color',
      'consumable',
      'INS-TINTE-RC',
      'unidad',
      12,
      3,
      18000,
      0,
      false
    ),
    (
      'Aceite capilar reparador',
      'Tratamiento',
      'sale',
      'VEN-ACEITE-REP',
      'unidad',
      8,
      2,
      22000,
      45000,
      true
    ),
    (
      'Crema para peinar',
      'Cabello',
      'sale',
      'VEN-CREMA-PEINAR',
      'unidad',
      10,
      2,
      16000,
      32000,
      true
    )
) as product(
  name,
  category,
  product_type,
  sku,
  unit,
  current_stock,
  minimum_stock,
  purchase_price,
  sale_price,
  visible_for_sale
)
where tenants.name = 'Bella Mujer'
  and not exists (
    select 1
    from public.products existing_products
    where existing_products.tenant_id = tenants.id
      and existing_products.sku = product.sku
  );
