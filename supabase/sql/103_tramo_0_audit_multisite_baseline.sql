-- BeautyOS - Tramo 0: linea base de solo lectura antes de multisede.
-- Fecha inicial de captura: 2026-07-19.
-- No contiene DDL, DML, datos personales ni identificadores de usuarios.
-- Ejecutar antes y despues de cada tramo y comparar cualquier diferencia.

-- 1. Entorno.
select
  current_database() as database_name,
  current_setting('server_version') as postgres_version,
  current_setting('TimeZone') as server_timezone,
  pg_size_pretty(pg_database_size(current_database())) as database_size;

-- 2. Inventario de objetos publicos.
select
  (select count(*) from information_schema.tables
    where table_schema = 'public' and table_type = 'BASE TABLE') as public_tables,
  (select count(*) from information_schema.views
    where table_schema = 'public') as public_views,
  (select count(*) from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public') as public_functions,
  (select count(*) from information_schema.triggers
    where trigger_schema = 'public') as public_triggers,
  (select count(*) from pg_indexes
    where schemaname = 'public') as public_indexes,
  (select count(*) from information_schema.table_constraints
    where constraint_schema = 'public') as public_constraints,
  (select count(*) from pg_policies
    where schemaname = 'public') as public_rls_policies;

-- 3. Conteo de tablas operativas. No devuelve filas ni datos personales.
select * from (
  select 'appointment_policies' as table_name, count(*) as row_count from public.appointment_policies
  union all select 'business_hours', count(*) from public.business_hours
  union all select 'clients', count(*) from public.clients
  union all select 'commission_policies', count(*) from public.commission_policies
  union all select 'expenses', count(*) from public.expenses
  union all select 'inventory_movements', count(*) from public.inventory_movements
  union all select 'products', count(*) from public.products
  union all select 'purchase_items', count(*) from public.purchase_items
  union all select 'purchases', count(*) from public.purchases
  union all select 'reviews', count(*) from public.reviews
  union all select 'services', count(*) from public.services
  union all select 'stylist_commissions', count(*) from public.stylist_commissions
  union all select 'stylist_services', count(*) from public.stylist_services
  union all select 'stylists', count(*) from public.stylists
  union all select 'tenants', count(*) from public.tenants
  union all select 'ticket_history', count(*) from public.ticket_history
  union all select 'ticket_payments', count(*) from public.ticket_payments
  union all select 'ticket_service_change_history', count(*) from public.ticket_service_change_history
  union all select 'ticket_service_history', count(*) from public.ticket_service_history
  union all select 'ticket_services', count(*) from public.ticket_services
  union all select 'tickets', count(*) from public.tickets
  union all select 'user_profile_access_history', count(*) from public.user_profile_access_history
  union all select 'user_profiles', count(*) from public.user_profiles
  union all select 'work_photos', count(*) from public.work_photos
) counts
order by table_name;

-- 4. Huellas financieras y de inventario.
select 'payments_registered' as metric,
       count(*)::numeric as records,
       coalesce(sum(amount), 0)::numeric as value
from public.ticket_payments where status = 'registrado'
union all
select 'payments_voided', count(*)::numeric, coalesce(sum(amount), 0)::numeric
from public.ticket_payments where status = 'anulado'
union all
select 'commissions_generated', count(*)::numeric, coalesce(sum(commission_amount), 0)::numeric
from public.stylist_commissions where status = 'generada'
union all
select 'commissions_voided', count(*)::numeric, coalesce(sum(commission_amount), 0)::numeric
from public.stylist_commissions where status = 'anulada'
union all
select 'active_purchases', count(*)::numeric, coalesce(sum(total_amount), 0)::numeric
from public.purchases where active
union all
select 'active_expenses', count(*)::numeric, coalesce(sum(amount), 0)::numeric
from public.expenses where active
union all
select 'active_product_stock_units', count(*)::numeric, coalesce(sum(current_stock), 0)::numeric
from public.products where active
union all
select 'active_stock_cost_value', count(*)::numeric,
       coalesce(sum(current_stock * purchase_price), 0)::numeric
from public.products where active
union all
select 'ticket_service_prices', count(*)::numeric, coalesce(sum(price), 0)::numeric
from public.ticket_services
order by metric;

-- 5. Pagos vigentes por medio.
select method, count(*) as records, coalesce(sum(amount), 0)::numeric as amount
from public.ticket_payments
where status = 'registrado'
group by method
order by method;

-- 6. Distribucion de estados.
select 'tickets' as entity, status, count(*) as records
from public.tickets group by status
union all
select 'ticket_services', status, count(*)
from public.ticket_services group by status
union all
select 'ticket_payments', status, count(*)
from public.ticket_payments group by status
union all
select 'stylist_commissions', status, count(*)
from public.stylist_commissions group by status
order by entity, status;

-- 7. Integridad por tenant y referencias. Todos deben devolver cero.
select * from (
  select 'tickets_missing_tenant' as check_name, count(*) as violations
  from public.tickets where tenant_id is null

  union all
  select 'tickets_missing_client', count(*)
  from public.tickets t
  left join public.clients c on c.id = t.client_id
  where c.id is null

  union all
  select 'tickets_client_tenant_mismatch', count(*)
  from public.tickets t
  join public.clients c on c.id = t.client_id
  where c.tenant_id is distinct from t.tenant_id

  union all
  select 'ticket_services_missing_ticket', count(*)
  from public.ticket_services ts
  left join public.tickets t on t.id = ts.ticket_id
  where t.id is null

  union all
  select 'ticket_services_ticket_tenant_mismatch', count(*)
  from public.ticket_services ts
  join public.tickets t on t.id = ts.ticket_id
  where t.tenant_id is distinct from ts.tenant_id

  union all
  select 'ticket_services_service_tenant_mismatch', count(*)
  from public.ticket_services ts
  join public.services s on s.id = ts.service_id
  where s.tenant_id is distinct from ts.tenant_id

  union all
  select 'ticket_services_stylist_tenant_mismatch', count(*)
  from public.ticket_services ts
  join public.stylists st on st.id = ts.stylist_id
  where st.tenant_id is distinct from ts.tenant_id

  union all
  select 'payments_ticket_tenant_mismatch', count(*)
  from public.ticket_payments p
  join public.tickets t on t.id = p.ticket_id
  where t.tenant_id is distinct from p.tenant_id

  union all
  select 'commissions_ticket_tenant_mismatch', count(*)
  from public.stylist_commissions sc
  join public.tickets t on t.id = sc.ticket_id
  where t.tenant_id is distinct from sc.tenant_id

  union all
  select 'commissions_service_tenant_mismatch', count(*)
  from public.stylist_commissions sc
  join public.ticket_services ts on ts.id = sc.ticket_service_id
  where ts.tenant_id is distinct from sc.tenant_id

  union all
  select 'stylist_services_service_tenant_mismatch', count(*)
  from public.stylist_services ss
  join public.services s on s.id = ss.service_id
  where s.tenant_id is distinct from ss.tenant_id

  union all
  select 'stylist_services_stylist_tenant_mismatch', count(*)
  from public.stylist_services ss
  join public.stylists st on st.id = ss.stylist_id
  where st.tenant_id is distinct from ss.tenant_id

  union all
  select 'movement_product_tenant_mismatch', count(*)
  from public.inventory_movements im
  join public.products p on p.id = im.product_id
  where p.tenant_id is distinct from im.tenant_id

  union all
  select 'purchase_item_purchase_tenant_mismatch', count(*)
  from public.purchase_items pi
  join public.purchases p on p.id = pi.purchase_id
  where p.tenant_id is distinct from pi.tenant_id

  union all
  select 'purchase_item_product_tenant_mismatch', count(*)
  from public.purchase_items pi
  join public.products p on p.id = pi.product_id
  where p.tenant_id is distinct from pi.tenant_id

  union all
  select 'review_ticket_tenant_mismatch', count(*)
  from public.reviews r
  join public.tickets t on t.id = r.ticket_id
  where t.tenant_id is distinct from r.tenant_id

  union all
  select 'work_photo_ticket_tenant_mismatch', count(*)
  from public.work_photos wp
  join public.tickets t on t.id = wp.ticket_id
  where t.tenant_id is distinct from wp.tenant_id
) integrity_checks
order by check_name;

-- 8. Superficie de funciones SECURITY DEFINER y permisos de ejecucion.
select
  count(*) filter (where p.prosecdef) as security_definer_functions,
  count(*) filter (
    where p.prosecdef and has_function_privilege('authenticated', p.oid, 'EXECUTE')
  ) as executable_by_authenticated,
  count(*) filter (
    where p.prosecdef and has_function_privilege('anon', p.oid, 'EXECUTE')
  ) as executable_by_anon,
  count(*) filter (
    where p.prosecdef and exists (
      select 1
      from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
      where acl.grantee = 0
        and acl.privilege_type = 'EXECUTE'
    )
  ) as executable_by_public
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public';
