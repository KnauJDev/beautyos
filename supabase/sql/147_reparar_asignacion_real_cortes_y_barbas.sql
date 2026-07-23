-- BeautyOS - Reparacion real (sin rollback) de la asignacion existente
-- Nicolas Alonso -> Corte de Pelo en el tenant real "Cortes y Barbas",
-- para que quede utilizable de inmediato sin que el propietario tenga que
-- volver a guardarla manualmente.

select set_config(
  'request.jwt.claim.sub',
  '54403360-f1e3-4475-95c5-607368f3e8a7',
  true
);

select * from public.set_stylist_services(
  'db2bbd57-0b7c-4818-95b7-f578f231c5e6',
  array['a4dc68f3-51c5-4cdc-bb2f-598ed65127a7']::uuid[]
);
