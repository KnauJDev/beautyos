insert into public.purchases (
  tenant_id,
  supplier_name,
  purchase_date,
  invoice_number,
  total_amount,
  payment_method,
  notes,
  active
)
select
  tenants.id,
  purchase.supplier_name,
  purchase.purchase_date,
  purchase.invoice_number,
  purchase.total_amount,
  purchase.payment_method,
  purchase.notes,
  true
from public.tenants
cross join (
  values
    (
      'Distribuidora Belleza Pro',
      current_date,
      'FAC-001-BM',
      53000,
      'transfer',
      'Compra demo de shampoo hidratante profesional y tintes.'
    ),
    (
      'Cosméticos Premium SAS',
      current_date,
      'FAC-002-BM',
      38000,
      'cash',
      'Compra demo de productos capilares para venta.'
    )
) as purchase(
  supplier_name,
  purchase_date,
  invoice_number,
  total_amount,
  payment_method,
  notes
)
where tenants.name = 'Bella Mujer'
  and not exists (
    select 1
    from public.purchases existing_purchases
    where existing_purchases.tenant_id = tenants.id
      and existing_purchases.invoice_number = purchase.invoice_number
  );
