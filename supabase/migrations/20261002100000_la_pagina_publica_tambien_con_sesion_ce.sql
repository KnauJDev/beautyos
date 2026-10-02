-- ==============================================================================
-- HALLAZGO CE: la pagina publica de un salon tambien funciona con una sesion
-- abierta. (D-307)
-- ==============================================================================
--
-- QUE PASABA
--
-- El 02-oct el propietario abrio la pagina publica de un salon en su celular,
-- con su sesion de Salon y Mas abierta, y al ir a reservar le salio
-- "permission denied for function public_get_branch_booking_info". En una
-- ventana de incognito, sin sesion, funcionaba.
--
-- La lectura viva (intervenciones/extraer_permisos_de_la_pagina_publica_ce.sql)
-- lo confirmo: estas seis funciones se conceden SOLO a `anon` desde el 23-jul y
-- el 07-ago. Con una sesion abierta la llamada viaja como `authenticated` y se
-- niega. Le pasa a todo el que haya entrado a la app en ese navegador: la duena
-- probando su enlace, la estilista que comparte el suyo (D-267) y el equipo.
--
-- QUE CAMBIA, Y QUE NO
--
-- Se les da `execute` tambien a `authenticated`. NO abre nada nuevo: son las
-- mismas que ya puede usar cualquier visitante de internet sin cuenta, y la
-- lectura confirmo que ninguna mira quien llama (ni auth.uid, ni auth.role, ni
-- el jwt): se comportan igual con sesion o sin ella. `anon` las conserva.
-- No se reescribe ninguna funcion. Las firmas salen de la lectura viva.
--
-- El resto de lo publico (portal de la clienta, enlace de autorizacion, pagina
-- del salon, planes) ya estaba concedido a los dos.
--
-- COMO SE APLICA (lo aplica el propietario, regla 16)
--
--   0. El respaldo (regla 15): scripts\respaldo_supabase.ps1
--   1. Esta migracion con scripts\aplicar_sql.ps1
--   2. El control: supabase\sql\238_test_la_pagina_publica_tambien_con_sesion_ce.sql
--   3. En pantalla (regla 21): en el celular, CON la sesion abierta, abrir la
--      pagina publica de un salon y llegar hasta las horas disponibles.
-- ==============================================================================

begin;

grant execute on function public.public_create_booking(p_branch_id uuid, p_service_id uuid, p_stylist_id uuid, p_scheduled_at timestamp with time zone, p_client_name text, p_client_phone text, p_client_email text, p_notes text)
  to authenticated;
grant execute on function public.public_create_review(p_ticket_id uuid, p_rating integer, p_comment text, p_stylist_id uuid, p_service_id uuid)
  to authenticated;
grant execute on function public.public_get_available_slots(p_branch_id uuid, p_service_id uuid, p_stylist_id uuid, p_date date)
  to authenticated;
grant execute on function public.public_get_bookable_services(p_branch_id uuid)
  to authenticated;
grant execute on function public.public_get_branch_booking_info(p_branch_id uuid)
  to authenticated;
grant execute on function public.public_get_ticket_for_review(p_ticket_id uuid)
  to authenticated;

commit;
