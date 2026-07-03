insert into public.business_hours (
  tenant_id,
  day_of_week,
  opens_at,
  closes_at,
  is_open,
  active
)
select
  tenants.id,
  schedule.day_of_week,
  schedule.opens_at,
  schedule.closes_at,
  schedule.is_open,
  true
from public.tenants
cross join (
  values
    (1, time '08:00', time '20:00', true),
    (2, time '08:00', time '20:00', true),
    (3, time '08:00', time '20:00', true),
    (4, time '08:00', time '20:00', true),
    (5, time '08:00', time '20:00', true),
    (6, time '08:00', time '20:00', true),
    (7, null::time, null::time, false)
) as schedule(day_of_week, opens_at, closes_at, is_open)
where tenants.name = 'Bella Mujer'
on conflict (tenant_id, day_of_week)
do update set
  opens_at = excluded.opens_at,
  closes_at = excluded.closes_at,
  is_open = excluded.is_open,
  active = true,
  updated_at = now();
