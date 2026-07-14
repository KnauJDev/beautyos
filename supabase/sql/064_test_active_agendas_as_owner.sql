begin;

-- Propietario de prueba del tenant BeautyOS.
select set_config(
  'request.jwt.claim.sub',
  '7661e1c7-798e-41f0-b2a4-9244e277570b',
  true
);

-- Debe mostrar solo tickets programados en confirmado, en_espera o en_proceso.
select
  id,
  client_name,
  scheduled_at,
  status,
  service_names,
  stylist_names,
  total_price,
  total_duration_minutes
from public.get_agenda_summary();

rollback;
