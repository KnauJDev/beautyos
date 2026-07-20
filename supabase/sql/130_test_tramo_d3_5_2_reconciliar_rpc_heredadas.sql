-- BeautyOS - Tramo D3.5.2
-- Prueba transaccional de la matriz de privilegios de 46 RPC heredadas.

begin;

create temp table tramo_d3_5_2_expected (
  grupo text not null,
  signature regprocedure not null,
  anon_expected boolean not null,
  authenticated_expected boolean not null,
  public_expected boolean not null,
  service_role_expected boolean not null
) on commit drop;

insert into tramo_d3_5_2_expected values
  ('retirar', 'public.add_ticket_service(uuid, uuid, uuid)'::regprocedure, false, false, false, true),
  ('retirar', 'public.create_scheduled_ticket_with_service(uuid, uuid, uuid, timestamp with time zone, text, text)'::regprocedure, false, false, false, true),
  ('retirar', 'public.create_ticket(uuid, timestamp with time zone, text, text)'::regprocedure, false, false, false, true),
  ('retirar', 'public.get_agenda_summary()'::regprocedure, false, false, false, true),
  ('retirar', 'public.get_available_appointment_slots(uuid, uuid, date)'::regprocedure, false, false, false, true),
  ('retirar', 'public.get_commission_summary(timestamp with time zone, timestamp with time zone)'::regprocedure, false, false, false, true),
  ('retirar', 'public.get_daily_close(date, timestamp with time zone, timestamp with time zone)'::regprocedure, false, false, false, true),
  ('retirar', 'public.get_expenses_summary()'::regprocedure, false, false, false, true),
  ('retirar', 'public.get_financial_summary()'::regprocedure, false, false, false, true),
  ('retirar', 'public.get_inventory_movements_summary()'::regprocedure, false, false, false, true),
  ('retirar', 'public.get_my_stylist_agenda()'::regprocedure, false, false, false, true),
  ('retirar', 'public.get_my_stylist_agenda_by_date(date)'::regprocedure, false, false, false, true),
  ('retirar', 'public.get_products_summary()'::regprocedure, false, false, false, true),
  ('retirar', 'public.get_purchase_items_summary()'::regprocedure, false, false, false, true),
  ('retirar', 'public.get_purchases_summary()'::regprocedure, false, false, false, true),
  ('retirar', 'public.get_sales_report_summary()'::regprocedure, false, false, false, true),
  ('retirar', 'public.get_ticket_payment_summary(uuid)'::regprocedure, false, false, false, true),
  ('retirar', 'public.get_ticket_payments(uuid)'::regprocedure, false, false, false, true),
  ('retirar', 'public.get_ticket_service_options()'::regprocedure, false, false, false, true),
  ('retirar', 'public.get_ticket_services_for_correction(uuid)'::regprocedure, false, false, false, true),
  ('retirar', 'public.get_ticket_services_for_management(uuid)'::regprocedure, false, false, false, true),
  ('retirar', 'public.get_tickets_summary()'::regprocedure, false, false, false, true),
  ('retirar', 'public.reschedule_ticket(uuid, timestamp with time zone, text)'::regprocedure, false, false, false, true),
  ('retirar', 'public.update_ticket_service_assignment(uuid, uuid, uuid, text)'::regprocedure, false, false, false, true),
  ('interna', 'public.change_ticket_service_status(uuid, text)'::regprocedure, false, false, false, true),
  ('interna', 'public.change_ticket_status(uuid, text, text)'::regprocedure, false, false, false, true),
  ('interna', 'public.register_ticket_payment(uuid, numeric, text, text, text)'::regprocedure, false, false, false, true),
  ('interna', 'public.remove_ticket_service(uuid, text)'::regprocedure, false, false, false, true),
  ('interna', 'public.reopen_finished_ticket_service(uuid, text)'::regprocedure, false, false, false, true),
  ('interna', 'public.void_ticket_payment(uuid, text)'::regprocedure, false, false, false, true),
  ('tenant', 'public.create_client(text, text, text, text)'::regprocedure, false, true, false, true),
  ('tenant', 'public.get_business_settings()'::regprocedure, false, true, false, true),
  ('tenant', 'public.get_clients_management_summary()'::regprocedure, false, true, false, true),
  ('tenant', 'public.get_clients_summary()'::regprocedure, false, true, false, true),
  ('tenant', 'public.get_commission_policy()'::regprocedure, false, true, false, true),
  ('tenant', 'public.get_my_profile()'::regprocedure, false, true, false, true),
  ('tenant', 'public.get_stylist_service_options(uuid)'::regprocedure, false, true, false, true),
  ('tenant', 'public.get_stylist_services_summary()'::regprocedure, false, true, false, true),
  ('tenant', 'public.get_stylists_summary()'::regprocedure, false, true, false, true),
  ('tenant', 'public.get_tenant_users()'::regprocedure, false, true, false, true),
  ('tenant', 'public.set_stylist_services(uuid, uuid[])'::regprocedure, false, true, false, true),
  ('tenant', 'public.update_client(uuid, text, text, text, text, boolean)'::regprocedure, false, true, false, true),
  ('tenant', 'public.update_tenant_user_access(uuid, text, boolean)'::regprocedure, false, true, false, true),
  ('helper', 'public.get_my_role()'::regprocedure, false, true, false, true),
  ('helper', 'public.get_my_tenant_id()'::regprocedure, false, true, false, true),
  ('helper', 'public.is_owner_or_admin()'::regprocedure, false, true, false, true);

do $$
declare
  v_mismatch_count integer;
begin
  select count(*)
  into v_mismatch_count
  from tramo_d3_5_2_expected e
  where has_function_privilege('anon', e.signature, 'execute') is distinct from e.anon_expected
     or has_function_privilege('authenticated', e.signature, 'execute') is distinct from e.authenticated_expected
     or has_function_privilege('public', e.signature, 'execute') is distinct from e.public_expected
     or has_function_privilege('service_role', e.signature, 'execute') is distinct from e.service_role_expected;

  if v_mismatch_count <> 0 then
    raise exception 'D3.5.2 privilege matrix mismatch count: %', v_mismatch_count;
  end if;
end $$;

select
  grupo,
  count(*) as funciones,
  count(*) filter (where has_function_privilege('anon', signature, 'execute')) as anon_execute,
  count(*) filter (where has_function_privilege('authenticated', signature, 'execute')) as authenticated_execute,
  count(*) filter (where has_function_privilege('public', signature, 'execute')) as public_execute,
  count(*) filter (where has_function_privilege('service_role', signature, 'execute')) as service_role_execute
from tramo_d3_5_2_expected
group by grupo
order by grupo;

rollback;
