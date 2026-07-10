begin;

select set_config(
  'request.jwt.claim.sub',
  '7661e1c7-798e-41f0-b2a4-9244e277570b',
  true
);

select
  id,
  tenant_id,
  client_id,
  scheduled_at,
  status,
  channel,
  notes
from public.create_ticket(
  '874db3df-aead-4b99-b521-9b4fe36ead88',
  '2026-07-15 15:00:00-05',
  'manual',
  'Prueba con rollback para validar create_ticket.'
);

rollback;
