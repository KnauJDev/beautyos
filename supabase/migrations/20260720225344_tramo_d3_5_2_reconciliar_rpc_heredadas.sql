-- BeautyOS - Tramo D3.5.2
-- Reconciliacion local de privilegios para las 46 RPC heredadas restantes.
--
-- Regla:
-- - No se eliminan funciones.
-- - Las 24 rutas operativas retirables y las 6 implementaciones internas
--   quedan cerradas para clientes externos.
-- - Las 13 rutas tenant/catalogo y los 3 helpers conservan authenticated
--   mientras exista consumo Flutter o dependencia heredada.
-- - anon y PUBLIC quedan cerrados en todo el conjunto.

-- 24 RPC operativas heredadas sin consumidor activo.
revoke all on function public.add_ticket_service(uuid, uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.create_scheduled_ticket_with_service(uuid, uuid, uuid, timestamp with time zone, text, text)
  from public, anon, authenticated;
revoke all on function public.create_ticket(uuid, timestamp with time zone, text, text)
  from public, anon, authenticated;
revoke all on function public.get_agenda_summary()
  from public, anon, authenticated;
revoke all on function public.get_available_appointment_slots(uuid, uuid, date)
  from public, anon, authenticated;
revoke all on function public.get_commission_summary(timestamp with time zone, timestamp with time zone)
  from public, anon, authenticated;
revoke all on function public.get_daily_close(date, timestamp with time zone, timestamp with time zone)
  from public, anon, authenticated;
revoke all on function public.get_expenses_summary()
  from public, anon, authenticated;
revoke all on function public.get_financial_summary()
  from public, anon, authenticated;
revoke all on function public.get_inventory_movements_summary()
  from public, anon, authenticated;
revoke all on function public.get_my_stylist_agenda()
  from public, anon, authenticated;
revoke all on function public.get_my_stylist_agenda_by_date(date)
  from public, anon, authenticated;
revoke all on function public.get_products_summary()
  from public, anon, authenticated;
revoke all on function public.get_purchase_items_summary()
  from public, anon, authenticated;
revoke all on function public.get_purchases_summary()
  from public, anon, authenticated;
revoke all on function public.get_sales_report_summary()
  from public, anon, authenticated;
revoke all on function public.get_ticket_payment_summary(uuid)
  from public, anon, authenticated;
revoke all on function public.get_ticket_payments(uuid)
  from public, anon, authenticated;
revoke all on function public.get_ticket_service_options()
  from public, anon, authenticated;
revoke all on function public.get_ticket_services_for_correction(uuid)
  from public, anon, authenticated;
revoke all on function public.get_ticket_services_for_management(uuid)
  from public, anon, authenticated;
revoke all on function public.get_tickets_summary()
  from public, anon, authenticated;
revoke all on function public.reschedule_ticket(uuid, timestamp with time zone, text)
  from public, anon, authenticated;
revoke all on function public.update_ticket_service_assignment(uuid, uuid, uuid, text)
  from public, anon, authenticated;

-- 6 implementaciones internas usadas por wrappers _v2.
revoke all on function public.change_ticket_service_status(uuid, text)
  from public, anon, authenticated;
revoke all on function public.change_ticket_status(uuid, text, text)
  from public, anon, authenticated;
revoke all on function public.register_ticket_payment(uuid, numeric, text, text, text)
  from public, anon, authenticated;
revoke all on function public.remove_ticket_service(uuid, text)
  from public, anon, authenticated;
revoke all on function public.reopen_finished_ticket_service(uuid, text)
  from public, anon, authenticated;
revoke all on function public.void_ticket_payment(uuid, text)
  from public, anon, authenticated;

-- 13 RPC tenant/catalogo con consumidor Flutter actual.
revoke all on function public.create_client(text, text, text, text)
  from public, anon;
revoke all on function public.get_business_settings()
  from public, anon;
revoke all on function public.get_clients_management_summary()
  from public, anon;
revoke all on function public.get_clients_summary()
  from public, anon;
revoke all on function public.get_commission_policy()
  from public, anon;
revoke all on function public.get_my_profile()
  from public, anon;
revoke all on function public.get_stylist_service_options(uuid)
  from public, anon;
revoke all on function public.get_stylist_services_summary()
  from public, anon;
revoke all on function public.get_stylists_summary()
  from public, anon;
revoke all on function public.get_tenant_users()
  from public, anon;
revoke all on function public.set_stylist_services(uuid, uuid[])
  from public, anon;
revoke all on function public.update_client(uuid, text, text, text, text, boolean)
  from public, anon;
revoke all on function public.update_tenant_user_access(uuid, text, boolean)
  from public, anon;

-- 3 helpers heredados. Se conservan para authenticated hasta migrar dependencias
-- a memberships; se cierra anon/PUBLIC.
revoke all on function public.get_my_role()
  from public, anon;
revoke all on function public.get_my_tenant_id()
  from public, anon;
revoke all on function public.is_owner_or_admin()
  from public, anon;

-- Grants explicitos de reversibilidad y continuidad.
grant execute on function public.add_ticket_service(uuid, uuid, uuid)
  to service_role;
grant execute on function public.create_scheduled_ticket_with_service(uuid, uuid, uuid, timestamp with time zone, text, text)
  to service_role;
grant execute on function public.create_ticket(uuid, timestamp with time zone, text, text)
  to service_role;
grant execute on function public.get_agenda_summary()
  to service_role;
grant execute on function public.get_available_appointment_slots(uuid, uuid, date)
  to service_role;
grant execute on function public.get_commission_summary(timestamp with time zone, timestamp with time zone)
  to service_role;
grant execute on function public.get_daily_close(date, timestamp with time zone, timestamp with time zone)
  to service_role;
grant execute on function public.get_expenses_summary()
  to service_role;
grant execute on function public.get_financial_summary()
  to service_role;
grant execute on function public.get_inventory_movements_summary()
  to service_role;
grant execute on function public.get_my_stylist_agenda()
  to service_role;
grant execute on function public.get_my_stylist_agenda_by_date(date)
  to service_role;
grant execute on function public.get_products_summary()
  to service_role;
grant execute on function public.get_purchase_items_summary()
  to service_role;
grant execute on function public.get_purchases_summary()
  to service_role;
grant execute on function public.get_sales_report_summary()
  to service_role;
grant execute on function public.get_ticket_payment_summary(uuid)
  to service_role;
grant execute on function public.get_ticket_payments(uuid)
  to service_role;
grant execute on function public.get_ticket_service_options()
  to service_role;
grant execute on function public.get_ticket_services_for_correction(uuid)
  to service_role;
grant execute on function public.get_ticket_services_for_management(uuid)
  to service_role;
grant execute on function public.get_tickets_summary()
  to service_role;
grant execute on function public.reschedule_ticket(uuid, timestamp with time zone, text)
  to service_role;
grant execute on function public.update_ticket_service_assignment(uuid, uuid, uuid, text)
  to service_role;

grant execute on function public.change_ticket_service_status(uuid, text)
  to service_role;
grant execute on function public.change_ticket_status(uuid, text, text)
  to service_role;
grant execute on function public.register_ticket_payment(uuid, numeric, text, text, text)
  to service_role;
grant execute on function public.remove_ticket_service(uuid, text)
  to service_role;
grant execute on function public.reopen_finished_ticket_service(uuid, text)
  to service_role;
grant execute on function public.void_ticket_payment(uuid, text)
  to service_role;

grant execute on function public.create_client(text, text, text, text)
  to authenticated, service_role;
grant execute on function public.get_business_settings()
  to authenticated, service_role;
grant execute on function public.get_clients_management_summary()
  to authenticated, service_role;
grant execute on function public.get_clients_summary()
  to authenticated, service_role;
grant execute on function public.get_commission_policy()
  to authenticated, service_role;
grant execute on function public.get_my_profile()
  to authenticated, service_role;
grant execute on function public.get_stylist_service_options(uuid)
  to authenticated, service_role;
grant execute on function public.get_stylist_services_summary()
  to authenticated, service_role;
grant execute on function public.get_stylists_summary()
  to authenticated, service_role;
grant execute on function public.get_tenant_users()
  to authenticated, service_role;
grant execute on function public.set_stylist_services(uuid, uuid[])
  to authenticated, service_role;
grant execute on function public.update_client(uuid, text, text, text, text, boolean)
  to authenticated, service_role;
grant execute on function public.update_tenant_user_access(uuid, text, boolean)
  to authenticated, service_role;

grant execute on function public.get_my_role()
  to authenticated, service_role;
grant execute on function public.get_my_tenant_id()
  to authenticated, service_role;
grant execute on function public.is_owner_or_admin()
  to authenticated, service_role;
