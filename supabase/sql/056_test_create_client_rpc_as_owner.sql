begin;

select set_config(
  'request.jwt.claim.sub',
  '7661e1c7-798e-41f0-b2a4-9244e277570b',
  true
);

select
  id,
  tenant_id,
  name,
  phone,
  email,
  notes,
  active
from public.create_client(
  'Cliente Prueba RPC',
  '3000000000',
  'cliente.prueba@example.com',
  'Prueba con rollback para validar create_client.'
);

rollback;
