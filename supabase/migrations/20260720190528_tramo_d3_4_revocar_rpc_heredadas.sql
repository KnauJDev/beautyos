-- BeautyOS - Tramo D3.4: cierre reversible de acceso externo heredado.
--
-- Mantiene las firmas para reversión, pero impide su uso por PUBLIC, anon y
-- authenticated. service_role conserva acceso temporal para una transición
-- controlada. No elimina funciones, datos ni triggers.

begin;

revoke all on function public.get_appointment_policy()
  from public, anon, authenticated;
revoke all on function public.get_business_hours()
  from public, anon, authenticated;
revoke all on function public.get_dashboard_metrics()
  from public, anon, authenticated;
revoke all on function public.get_my_stylist_work_photos()
  from public, anon, authenticated;
revoke all on function public.get_reviews_summary()
  from public, anon, authenticated;
revoke all on function public.get_work_photos_summary()
  from public, anon, authenticated;

grant execute on function public.get_appointment_policy() to service_role;
grant execute on function public.get_business_hours() to service_role;
grant execute on function public.get_dashboard_metrics() to service_role;
grant execute on function public.get_my_stylist_work_photos() to service_role;
grant execute on function public.get_reviews_summary() to service_role;
grant execute on function public.get_work_photos_summary() to service_role;

comment on function public.get_appointment_policy()
  is 'Compatibilidad heredada: solo service_role durante la transición D3.4.';
comment on function public.get_business_hours()
  is 'Compatibilidad heredada: solo service_role durante la transición D3.4.';
comment on function public.get_dashboard_metrics()
  is 'Compatibilidad heredada: solo service_role durante la transición D3.4.';
comment on function public.get_my_stylist_work_photos()
  is 'Compatibilidad heredada: solo service_role durante la transición D3.4.';
comment on function public.get_reviews_summary()
  is 'Compatibilidad heredada: solo service_role durante la transición D3.4.';
comment on function public.get_work_photos_summary()
  is 'Compatibilidad heredada: solo service_role durante la transición D3.4.';

commit;
