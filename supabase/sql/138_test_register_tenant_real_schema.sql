-- BeautyOS - Prueba real (con rollback) de register_tenant() contra el
-- esquema vivo, usando el UID real de la cuenta de prueba del propietario
-- (elboga000@gmail.com). No persiste nada: termina en rollback.

begin;

select set_config(
  'request.jwt.claim.sub',
  '2975e198-2f33-4cd3-a3f2-4d93eb517118',
  true
);

select *
from public.register_tenant(
  'Pepito Pelos y Uñas',
  'Pepito Prueba Probon',
  '3017049225'
);

rollback;
