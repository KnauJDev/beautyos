-- BeautyOS - Prueba real (con rollback) de la correccion de
-- set_stylist_services contra el tenant real "Cortes y Barbas".

begin;

select set_config(
  'request.jwt.claim.sub',
  '54403360-f1e3-4475-95c5-607368f3e8a7',
  true
);

-- Reafirma la misma asignacion que ya existia (Corte de Pelo -> Nicolas).
select * from public.set_stylist_services(
  'db2bbd57-0b7c-4818-95b7-f578f231c5e6',
  array['a4dc68f3-51c5-4cdc-bb2f-598ed65127a7']::uuid[]
);

-- Ahora si debe existir la fila de sede.
select count(*) as filas_branch_stylist_services
from public.branch_stylist_services bss
join public.branch_services bs on bs.id = bss.branch_service_id
join public.branch_stylists bst on bst.id = bss.branch_stylist_id
where bs.service_id = 'a4dc68f3-51c5-4cdc-bb2f-598ed65127a7'
  and bst.stylist_id = 'db2bbd57-0b7c-4818-95b7-f578f231c5e6'
  and bss.active = true;

-- Y ahora si debe haber horarios disponibles para manana.
select count(*) as horarios_disponibles
from public.get_available_appointment_slots_v2(
  p_branch_id := 'a12dcc83-c6fd-4f87-a824-2c4e98e11f33',
  p_service_id := 'a4dc68f3-51c5-4cdc-bb2f-598ed65127a7',
  p_stylist_id := 'db2bbd57-0b7c-4818-95b7-f578f231c5e6',
  p_date := (current_date + 1)
);

rollback;
