insert into public.commission_policies (
  tenant_id,
  commission_type,
  commission_percentage,
  fixed_commission_amount,
  applies_after_discount,
  notes,
  active
)
select
  tenants.id,
  'percentage',
  40,
  0,
  true,
  'Comisión demo: el estilista recibe el 40% del valor del servicio después de descuentos.',
  true
from public.tenants
where tenants.name = 'Bella Mujer'
on conflict (tenant_id)
do update set
  commission_type = excluded.commission_type,
  commission_percentage = excluded.commission_percentage,
  fixed_commission_amount = excluded.fixed_commission_amount,
  applies_after_discount = excluded.applies_after_discount,
  notes = excluded.notes,
  active = true,
  updated_at = now();
