revoke execute on function public.get_agenda_summary() from anon;
revoke execute on function public.get_agenda_summary() from public;
grant execute on function public.get_agenda_summary() to authenticated;

revoke execute on function public.get_appointment_policy() from anon;
revoke execute on function public.get_appointment_policy() from public;
grant execute on function public.get_appointment_policy() to authenticated;

revoke execute on function public.get_business_hours() from anon;
revoke execute on function public.get_business_hours() from public;
grant execute on function public.get_business_hours() to authenticated;

revoke execute on function public.get_business_settings() from anon;
revoke execute on function public.get_business_settings() from public;
grant execute on function public.get_business_settings() to authenticated;

revoke execute on function public.get_clients_summary() from anon;
revoke execute on function public.get_clients_summary() from public;
grant execute on function public.get_clients_summary() to authenticated;

revoke execute on function public.get_commission_policy() from anon;
revoke execute on function public.get_commission_policy() from public;
grant execute on function public.get_commission_policy() to authenticated;

revoke execute on function public.get_dashboard_metrics() from anon;
revoke execute on function public.get_dashboard_metrics() from public;
grant execute on function public.get_dashboard_metrics() to authenticated;

revoke execute on function public.get_expenses_summary() from anon;
revoke execute on function public.get_expenses_summary() from public;
grant execute on function public.get_expenses_summary() to authenticated;

revoke execute on function public.get_financial_summary() from anon;
revoke execute on function public.get_financial_summary() from public;
grant execute on function public.get_financial_summary() to authenticated;

revoke execute on function public.get_inventory_movements_summary() from anon;
revoke execute on function public.get_inventory_movements_summary() from public;
grant execute on function public.get_inventory_movements_summary() to authenticated;

revoke execute on function public.get_products_summary() from anon;
revoke execute on function public.get_products_summary() from public;
grant execute on function public.get_products_summary() to authenticated;

revoke execute on function public.get_purchase_items_summary() from anon;
revoke execute on function public.get_purchase_items_summary() from public;
grant execute on function public.get_purchase_items_summary() to authenticated;

revoke execute on function public.get_purchases_summary() from anon;
revoke execute on function public.get_purchases_summary() from public;
grant execute on function public.get_purchases_summary() to authenticated;

revoke execute on function public.get_reviews_summary() from anon;
revoke execute on function public.get_reviews_summary() from public;
grant execute on function public.get_reviews_summary() to authenticated;

revoke execute on function public.get_sales_report_summary() from anon;
revoke execute on function public.get_sales_report_summary() from public;
grant execute on function public.get_sales_report_summary() to authenticated;

revoke execute on function public.get_stylist_services_summary() from anon;
revoke execute on function public.get_stylist_services_summary() from public;
grant execute on function public.get_stylist_services_summary() to authenticated;

revoke execute on function public.get_stylists_summary() from anon;
revoke execute on function public.get_stylists_summary() from public;
grant execute on function public.get_stylists_summary() to authenticated;

revoke execute on function public.get_tickets_summary() from anon;
revoke execute on function public.get_tickets_summary() from public;
grant execute on function public.get_tickets_summary() to authenticated;

revoke execute on function public.get_work_photos_summary() from anon;
revoke execute on function public.get_work_photos_summary() from public;
grant execute on function public.get_work_photos_summary() to authenticated;
