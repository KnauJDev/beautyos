-- BeautyOS - Paso 8.1 (H-05): purga las 30 funciones heredadas sin dueño.
--
-- POR QUÉ
--
-- D-024 revocó EXECUTE de 6 funciones mono-sede (get_appointment_policy,
-- get_business_hours, get_dashboard_metrics, get_my_stylist_work_photos,
-- get_reviews_summary, get_work_photos_summary) dejando solo service_role.
-- D-040 hizo lo mismo con 24 rutas operativas reemplazadas por sus
-- versiones `_v2` (add_ticket_service, create_ticket, get_agenda_summary,
-- etc.). Ambos grupos llevan desde julio sin una sola llamada real: cero
-- referencias en Flutter, cero referencias en SQL vigente -- se verificó
-- con grep sobre todo `lib/` y `supabase/migrations/` antes de escribir
-- este archivo, no se asumió nada (regla 8.1). Las únicas menciones que
-- quedaban eran en controles históricos de un solo uso
-- (`supabase/sql/0NN_test_*`, `1NN_*`), que no se vuelven a ejecutar.
--
-- Las 6 que D-040 marcó como "implementaciones internas" NO se tocan:
-- `change_ticket_service_status_v2`, `register_ticket_payment_v2` y sus
-- hermanas delegan en ellas con un `select * from public.xxx(...)`
-- directo (verificado línea por línea en
-- `20260720135200_tramo_c2b_operacion_ticket_por_sede.sql`). Absorber su
-- lógica dentro de cada wrapper reescribiría seis funciones que hoy
-- funcionan en producción sin ganar nada en seguridad -- ya están
-- cerradas a `anon`/`authenticated` desde D-040, solo las alcanza el
-- dueño del esquema (los wrappers). Se les deja en su lugar un
-- `COMMENT ON FUNCTION` explícito para que una purga futura no tenga que
-- volver a investigar esto.

begin;

-- -----------------------------------------------------------------------
-- 1. Las 6 de D-024: mono-sede, sin reemplazo, sin consumidor.
-- -----------------------------------------------------------------------
drop function if exists public.get_appointment_policy();
drop function if exists public.get_business_hours();
drop function if exists public.get_dashboard_metrics();
drop function if exists public.get_my_stylist_work_photos();
drop function if exists public.get_reviews_summary();
drop function if exists public.get_work_photos_summary();

-- -----------------------------------------------------------------------
-- 2. Las 24 de D-040: reemplazadas por `_v2`, sin consumidor.
-- -----------------------------------------------------------------------
drop function if exists public.add_ticket_service(uuid, uuid, uuid);
drop function if exists public.create_scheduled_ticket_with_service(uuid, uuid, uuid, timestamp with time zone, text, text);
drop function if exists public.create_ticket(uuid, timestamp with time zone, text, text);
drop function if exists public.get_agenda_summary();
drop function if exists public.get_available_appointment_slots(uuid, uuid, date);
drop function if exists public.get_commission_summary(timestamp with time zone, timestamp with time zone);
drop function if exists public.get_daily_close(date, timestamp with time zone, timestamp with time zone);
drop function if exists public.get_expenses_summary();
drop function if exists public.get_financial_summary();
drop function if exists public.get_inventory_movements_summary();
drop function if exists public.get_my_stylist_agenda();
drop function if exists public.get_my_stylist_agenda_by_date(date);
drop function if exists public.get_products_summary();
drop function if exists public.get_purchase_items_summary();
drop function if exists public.get_purchases_summary();
drop function if exists public.get_sales_report_summary();
drop function if exists public.get_ticket_payment_summary(uuid);
drop function if exists public.get_ticket_payments(uuid);
drop function if exists public.get_ticket_service_options();
drop function if exists public.get_ticket_services_for_correction(uuid);
drop function if exists public.get_ticket_services_for_management(uuid);
drop function if exists public.get_tickets_summary();
drop function if exists public.reschedule_ticket(uuid, timestamp with time zone, text);
drop function if exists public.update_ticket_service_assignment(uuid, uuid, uuid, text);

-- -----------------------------------------------------------------------
-- 3. Las 6 internas: se conservan intactas, solo se documentan para que
--    nadie vuelva a proponerlas para retiro sin mirar esto primero.
-- -----------------------------------------------------------------------
comment on function public.change_ticket_service_status(uuid, text)
  is 'NO ELIMINAR: llamada internamente por change_ticket_service_status_v2 (D-040, Paso 8.1). Sin EXECUTE directo para anon/authenticated desde D-040; solo el dueño del esquema (el wrapper) puede invocarla.';

comment on function public.change_ticket_status(uuid, text, text)
  is 'NO ELIMINAR: llamada internamente por change_ticket_status_v2 (D-040, Paso 8.1). Sin EXECUTE directo para anon/authenticated desde D-040; solo el dueño del esquema (el wrapper) puede invocarla.';

comment on function public.register_ticket_payment(uuid, numeric, text, text, text)
  is 'NO ELIMINAR: llamada internamente por register_ticket_payment_v2 (D-040, Paso 8.1). Sin EXECUTE directo para anon/authenticated desde D-040; solo el dueño del esquema (el wrapper) puede invocarla.';

comment on function public.remove_ticket_service(uuid, text)
  is 'NO ELIMINAR: llamada internamente por remove_ticket_service_v2 (D-040, Paso 8.1). Sin EXECUTE directo para anon/authenticated desde D-040; solo el dueño del esquema (el wrapper) puede invocarla.';

comment on function public.reopen_finished_ticket_service(uuid, text)
  is 'NO ELIMINAR: llamada internamente por reopen_finished_ticket_service_v2 (D-040, Paso 8.1). Sin EXECUTE directo para anon/authenticated desde D-040; solo el dueño del esquema (el wrapper) puede invocarla.';

comment on function public.void_ticket_payment(uuid, text)
  is 'NO ELIMINAR: llamada internamente por void_ticket_payment_v2 (D-040, Paso 8.1). Sin EXECUTE directo para anon/authenticated desde D-040; solo el dueño del esquema (el wrapper) puede invocarla.';

commit;
