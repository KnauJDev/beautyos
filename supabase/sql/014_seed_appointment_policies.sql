insert into public.appointment_policies (
  tenant_id,
  requires_deposit,
  deposit_percentage,
  cancellation_hours,
  reschedule_hours,
  manual_confirmation_required,
  customer_reschedule_allowed,
  active
)
select
  tenants.id,
  true,
  30,
  24,
  24,
  true,
  true,
  true
from public.tenants
where tenants.name = 'Bella Mujer'
on conflict (tenant_id)
do update set
  requires_deposit = excluded.requires_deposit,
  deposit_percentage = excluded.deposit_percentage,
  cancellation_hours = excluded.cancellation_hours,
  reschedule_hours = excluded.reschedule_hours,
  manual_confirmation_required = excluded.manual_confirmation_required,
  customer_reschedule_allowed = excluded.customer_reschedule_allowed,
  active = true,
  updated_at = now();
