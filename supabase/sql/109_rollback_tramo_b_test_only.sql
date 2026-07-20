-- BeautyOS - Reversion del Tramo B EXCLUSIVAMENTE para ensayo desechable.
-- Falla salvo que la sesion defina:
--   SET beautyos.allow_destructive_test_rollback = 'yes';

begin;

do $$
declare
  v_count bigint;
begin
  if coalesce(current_setting('beautyos.allow_destructive_test_rollback', true), '') <> 'yes' then
    raise exception 'Rollback bloqueado: solo se permite en ensayo con autorizacion explicita.';
  end if;

  select count(*) into v_count
  from information_schema.columns
  where table_schema='public'
    and column_name='branch_id'
    and table_name in (
      'business_hours','appointment_policies','tickets','ticket_services',
      'ticket_history','ticket_service_history','ticket_service_change_history',
      'ticket_payments','stylist_commissions','inventory_movements','purchases',
      'purchase_items','expenses','work_photos','reviews'
    )
    and is_nullable='NO';
  if v_count <> 0 then
    raise exception 'Rollback bloqueado: Tramo C/D ya endurecio % columna(s) branch_id.', v_count;
  end if;

  select count(*) into v_count
  from (
    select tenant_id, branch_id from public.business_hours union all
    select tenant_id, branch_id from public.appointment_policies union all
    select tenant_id, branch_id from public.tickets union all
    select tenant_id, branch_id from public.ticket_services union all
    select tenant_id, branch_id from public.ticket_history union all
    select tenant_id, branch_id from public.ticket_service_history union all
    select tenant_id, branch_id from public.ticket_service_change_history union all
    select tenant_id, branch_id from public.ticket_payments union all
    select tenant_id, branch_id from public.stylist_commissions union all
    select tenant_id, branch_id from public.inventory_movements union all
    select tenant_id, branch_id from public.purchases union all
    select tenant_id, branch_id from public.purchase_items union all
    select tenant_id, branch_id from public.expenses union all
    select tenant_id, branch_id from public.work_photos union all
    select tenant_id, branch_id from public.reviews
  ) x
  join public.branches b on b.id=x.branch_id and b.tenant_id=x.tenant_id
  where not b.is_primary;
  if v_count <> 0 then
    raise exception 'Rollback bloqueado: existen % registro(s) operacionales en sedes no principales.', v_count;
  end if;
end;
$$;

drop trigger business_hours_set_branch on public.business_hours;
drop trigger appointment_policies_set_branch on public.appointment_policies;
drop trigger tickets_set_branch on public.tickets;
drop trigger inventory_movements_set_branch on public.inventory_movements;
drop trigger purchases_set_branch on public.purchases;
drop trigger expenses_set_branch on public.expenses;
drop trigger ticket_services_set_branch on public.ticket_services;
drop trigger ticket_history_set_branch on public.ticket_history;
drop trigger ticket_service_history_set_branch on public.ticket_service_history;
drop trigger ticket_service_change_history_set_branch on public.ticket_service_change_history;
drop trigger ticket_payments_set_branch on public.ticket_payments;
drop trigger stylist_commissions_set_branch on public.stylist_commissions;
drop trigger purchase_items_set_branch on public.purchase_items;
drop trigger work_photos_set_branch on public.work_photos;
drop trigger reviews_set_branch on public.reviews;

drop function private.beautyos_set_optional_ticket_branch();
drop function private.beautyos_set_purchase_branch();
drop function private.beautyos_set_ticket_branch();
drop function private.beautyos_set_root_branch();
drop function private.beautyos_resolve_branch(uuid, uuid);

alter table public.business_hours drop constraint business_hours_tenant_branch_fkey;
alter table public.appointment_policies drop constraint appointment_policies_tenant_branch_fkey;
alter table public.tickets drop constraint tickets_tenant_branch_fkey, drop constraint tickets_tenant_client_fkey;
alter table public.ticket_services
  drop constraint ticket_services_tenant_branch_fkey,
  drop constraint ticket_services_tenant_branch_ticket_fkey,
  drop constraint ticket_services_branch_service_fkey,
  drop constraint ticket_services_branch_stylist_fkey;
alter table public.ticket_history
  drop constraint ticket_history_tenant_branch_fkey,
  drop constraint ticket_history_branch_ticket_fkey;
alter table public.ticket_service_history
  drop constraint ticket_service_history_tenant_branch_fkey,
  drop constraint ticket_service_history_branch_ticket_fkey,
  drop constraint ticket_service_history_branch_service_fkey;
alter table public.ticket_service_change_history
  drop constraint ticket_service_change_tenant_branch_fkey,
  drop constraint ticket_service_change_branch_ticket_fkey,
  drop constraint ticket_service_change_branch_service_fkey;
alter table public.ticket_payments
  drop constraint ticket_payments_tenant_branch_fkey,
  drop constraint ticket_payments_branch_ticket_fkey;
alter table public.stylist_commissions
  drop constraint stylist_commissions_tenant_branch_fkey,
  drop constraint stylist_commissions_branch_ticket_fkey,
  drop constraint stylist_commissions_branch_service_fkey,
  drop constraint stylist_commissions_branch_stylist_fkey;
alter table public.inventory_movements
  drop constraint inventory_movements_tenant_branch_fkey,
  drop constraint inventory_movements_branch_product_fkey;
alter table public.purchases drop constraint purchases_tenant_branch_fkey;
alter table public.purchase_items
  drop constraint purchase_items_tenant_branch_fkey,
  drop constraint purchase_items_branch_purchase_fkey,
  drop constraint purchase_items_branch_product_fkey;
alter table public.expenses drop constraint expenses_tenant_branch_fkey;
alter table public.work_photos
  drop constraint work_photos_tenant_branch_fkey,
  drop constraint work_photos_branch_ticket_fkey,
  drop constraint work_photos_tenant_client_fkey,
  drop constraint work_photos_branch_stylist_fkey;
alter table public.reviews
  drop constraint reviews_tenant_branch_fkey,
  drop constraint reviews_branch_ticket_fkey,
  drop constraint reviews_tenant_client_fkey,
  drop constraint reviews_branch_stylist_fkey,
  drop constraint reviews_branch_service_fkey;

drop index if exists public.business_hours_branch_day_uidx;
drop index if exists public.appointment_policies_branch_uidx;
drop index if exists public.business_hours_tenant_branch_idx;
drop index if exists public.appointment_policies_tenant_branch_idx;
drop index if exists public.tickets_branch_schedule_active_idx;
drop index if exists public.ticket_services_branch_stylist_active_idx;
drop index if exists public.ticket_history_branch_ticket_created_idx;
drop index if exists public.ticket_service_history_branch_ticket_created_idx;
drop index if exists public.ticket_service_change_branch_ticket_created_idx;
drop index if exists public.ticket_payments_branch_received_active_idx;
drop index if exists public.stylist_commissions_branch_generated_active_idx;
drop index if exists public.inventory_movements_branch_created_idx;
drop index if exists public.purchases_branch_date_active_idx;
drop index if exists public.purchase_items_branch_purchase_idx;
drop index if exists public.expenses_branch_date_active_idx;
drop index if exists public.work_photos_branch_created_idx;
drop index if exists public.reviews_branch_created_idx;
drop index if exists public.tickets_client_id_idx;
drop index if exists public.tickets_tenant_client_idx;
drop index if exists public.ticket_services_ticket_id_idx;
drop index if exists public.ticket_services_service_id_idx;
drop index if exists public.ticket_services_stylist_id_idx;
drop index if exists public.ticket_services_branch_ticket_idx;
drop index if exists public.ticket_services_branch_service_idx;
drop index if exists public.ticket_services_branch_stylist_idx;
drop index if exists public.ticket_history_ticket_id_idx;
drop index if exists public.ticket_service_history_ticket_id_idx;
drop index if exists public.ticket_service_history_service_id_idx;
drop index if exists public.ticket_service_history_branch_service_idx;
drop index if exists public.ticket_service_change_branch_service_idx;
drop index if exists public.ticket_payments_branch_ticket_idx;
drop index if exists public.stylist_commissions_branch_ticket_idx;
drop index if exists public.stylist_commissions_branch_service_idx;
drop index if exists public.stylist_commissions_branch_stylist_idx;
drop index if exists public.inventory_movements_product_id_idx;
drop index if exists public.inventory_movements_branch_product_idx;
drop index if exists public.purchase_items_purchase_id_idx;
drop index if exists public.purchase_items_product_id_idx;
drop index if exists public.purchase_items_branch_product_idx;
drop index if exists public.reviews_service_id_idx;
drop index if exists public.reviews_tenant_client_idx;
drop index if exists public.reviews_branch_ticket_idx;
drop index if exists public.reviews_branch_stylist_idx;
drop index if exists public.reviews_branch_service_idx;
drop index if exists public.work_photos_client_id_idx;
drop index if exists public.work_photos_tenant_client_idx;
drop index if exists public.work_photos_branch_ticket_idx;
drop index if exists public.work_photos_branch_stylist_idx;
drop index if exists public.stylist_services_service_id_idx;
drop index if exists public.tickets_tenant_branch_id_uidx;
drop index if exists public.ticket_services_tenant_branch_id_uidx;
drop index if exists public.purchases_tenant_branch_id_uidx;
drop index if exists public.branch_services_tenant_branch_service_uidx;
drop index if exists public.branch_stylists_tenant_branch_stylist_uidx;
drop index if exists public.branch_products_tenant_branch_product_uidx;
drop index if exists public.clients_tenant_id_id_uidx;

alter table public.business_hours drop column branch_id;
alter table public.appointment_policies drop column branch_id;
alter table public.tickets drop column branch_id;
alter table public.ticket_services drop column branch_id;
alter table public.ticket_history drop column branch_id;
alter table public.ticket_service_history drop column branch_id;
alter table public.ticket_service_change_history drop column branch_id;
alter table public.ticket_payments drop column branch_id;
alter table public.stylist_commissions drop column branch_id;
alter table public.inventory_movements drop column branch_id;
alter table public.purchases drop column branch_id;
alter table public.purchase_items drop column branch_id;
alter table public.expenses drop column branch_id;
alter table public.work_photos drop column branch_id;
alter table public.reviews drop column branch_id;

commit;
