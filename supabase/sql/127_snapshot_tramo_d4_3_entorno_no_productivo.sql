-- BeautyOS - Tramo D4.3: fotografia SQL de solo lectura.
-- Ejecutar unicamente despues de validar que el destino es no productivo.
-- No contiene DDL, DML, GRANT, REVOKE ni invocaciones a RPC de negocio.

begin read only;

select
  current_database() as database_name,
  current_user as execution_user,
  current_setting('server_version') as server_version,
  current_setting('transaction_read_only') as transaction_read_only,
  now() as captured_at;

with expected_functions(signature, family, expected_result) as (
  values
    (
      'public.get_appointment_policy()',
      'legacy',
      'TABLE(id uuid, requires_deposit boolean, deposit_percentage numeric, cancellation_hours integer, reschedule_hours integer, manual_confirmation_required boolean, customer_reschedule_allowed boolean)'
    ),
    (
      'public.get_business_hours()',
      'legacy',
      'TABLE(id uuid, day_of_week integer, opens_at time without time zone, closes_at time without time zone, is_open boolean)'
    ),
    (
      'public.get_dashboard_metrics()',
      'legacy',
      'TABLE(active_services_count integer, clients_count integer, confirmed_tickets_count integer, today_tickets_count integer, active_stylists_count integer, active_stylist_services_count integer)'
    ),
    (
      'public.get_my_stylist_work_photos()',
      'legacy',
      'TABLE(id uuid, ticket_id uuid, client_name text, service_name text, photo_url text, photo_type text, caption text, ai_status text, visible_to_customer boolean, approved_for_portfolio boolean, created_at timestamp with time zone)'
    ),
    (
      'public.get_reviews_summary()',
      'legacy',
      'TABLE(id uuid, ticket_id uuid, client_name text, stylist_name text, service_name text, rating integer, comment text, moderation_status text, visible_to_public boolean, created_at timestamp with time zone)'
    ),
    (
      'public.get_work_photos_summary()',
      'legacy',
      'TABLE(id uuid, ticket_id uuid, client_name text, stylist_name text, photo_url text, photo_type text, caption text, ai_status text, visible_to_customer boolean, approved_for_portfolio boolean, created_at timestamp with time zone)'
    ),
    (
      'public.get_appointment_policy_v2(uuid)',
      'v2',
      'TABLE(id uuid, requires_deposit boolean, deposit_percentage numeric, cancellation_hours integer, reschedule_hours integer, manual_confirmation_required boolean, customer_reschedule_allowed boolean)'
    ),
    (
      'public.get_business_hours_v2(uuid)',
      'v2',
      'TABLE(id uuid, day_of_week integer, opens_at time without time zone, closes_at time without time zone, is_open boolean)'
    ),
    (
      'public.get_dashboard_metrics_v2(uuid)',
      'v2',
      'TABLE(active_services_count integer, clients_count integer, confirmed_tickets_count integer, today_tickets_count integer, active_stylists_count integer, active_stylist_services_count integer)'
    ),
    (
      'public.get_my_stylist_work_photos_v2(uuid)',
      'v2',
      'TABLE(id uuid, ticket_id uuid, client_name text, service_name text, photo_url text, photo_type text, caption text, ai_status text, visible_to_customer boolean, approved_for_portfolio boolean, created_at timestamp with time zone)'
    ),
    (
      'public.get_reviews_summary_v2(uuid)',
      'v2',
      'TABLE(id uuid, ticket_id uuid, client_name text, stylist_name text, service_name text, rating integer, comment text, moderation_status text, visible_to_public boolean, created_at timestamp with time zone)'
    ),
    (
      'public.get_work_photos_summary_v2(uuid)',
      'v2',
      'TABLE(id uuid, ticket_id uuid, client_name text, stylist_name text, photo_url text, photo_type text, caption text, ai_status text, visible_to_customer boolean, approved_for_portfolio boolean, created_at timestamp with time zone)'
    )
),
resolved_functions as (
  select
    signature,
    family,
    expected_result,
    to_regprocedure(signature)::oid as function_oid
  from expected_functions
)
select
  r.signature,
  r.family,
  p.oid is not null as function_exists,
  case
    when p.oid is null then null
    else pg_get_function_result(p.oid)
  end as actual_result,
  case
    when p.oid is null then false
    else pg_get_function_result(p.oid) = r.expected_result
  end as result_matches_expected,
  coalesce(p.prosecdef, false) as security_definer,
  coalesce(
    'search_path=pg_catalog' = any(coalesce(p.proconfig, array[]::text[])),
    false
  ) as search_path_pg_catalog,
  case
    when p.oid is null then null
    else exists (
      select 1
      from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
      where acl.grantee = 0
        and acl.privilege_type = 'EXECUTE'
    )
  end as public_execute,
  case
    when p.oid is null then null
    else has_function_privilege('anon', p.oid, 'EXECUTE')
  end as anon_execute,
  case
    when p.oid is null then null
    else has_function_privilege('authenticated', p.oid, 'EXECUTE')
  end as authenticated_execute,
  case
    when p.oid is null then null
    else has_function_privilege('service_role', p.oid, 'EXECUTE')
  end as service_role_execute,
  case
    when p.oid is null then null
    else position('beautyos_resolve_branch_access' in pg_get_functiondef(p.oid)) > 0
  end as uses_branch_access_helper,
  case
    when p.oid is null then null
    else position('user_profiles' in pg_get_functiondef(p.oid)) > 0
  end as references_user_profiles
from resolved_functions r
left join pg_proc p on p.oid = r.function_oid
order by r.family, r.signature;

with scoped_tables(table_name, branch_column) as (
  values
    ('business_hours', true),
    ('appointment_policies', true),
    ('tickets', true),
    ('ticket_services', true),
    ('ticket_history', true),
    ('ticket_service_history', true),
    ('ticket_service_change_history', true),
    ('ticket_payments', true),
    ('stylist_commissions', true),
    ('inventory_movements', true),
    ('purchases', true),
    ('purchase_items', true),
    ('expenses', true),
    ('work_photos', true),
    ('reviews', true),
    ('branches', false),
    ('tenant_memberships', false),
    ('branch_memberships', true)
)
select
  table_name,
  to_regclass(format('public.%I', table_name)) is not null as table_exists,
  case
    when to_regclass(format('public.%I', table_name)) is null then null
    else (
      select count(*)::bigint
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = scoped_tables.table_name
        and c.column_name = 'branch_id'
    )
  end as branch_id_column_count,
  branch_column as branch_id_expected
from scoped_tables
order by table_name;

select 'business_hours' as table_name, count(*) as total_rows, count(*) filter (where branch_id is null) as branch_id_nulls from public.business_hours
union all
select 'appointment_policies', count(*), count(*) filter (where branch_id is null) from public.appointment_policies
union all
select 'tickets', count(*), count(*) filter (where branch_id is null) from public.tickets
union all
select 'ticket_services', count(*), count(*) filter (where branch_id is null) from public.ticket_services
union all
select 'ticket_history', count(*), count(*) filter (where branch_id is null) from public.ticket_history
union all
select 'ticket_service_history', count(*), count(*) filter (where branch_id is null) from public.ticket_service_history
union all
select 'ticket_service_change_history', count(*), count(*) filter (where branch_id is null) from public.ticket_service_change_history
union all
select 'ticket_payments', count(*), count(*) filter (where branch_id is null) from public.ticket_payments
union all
select 'stylist_commissions', count(*), count(*) filter (where branch_id is null) from public.stylist_commissions
union all
select 'inventory_movements', count(*), count(*) filter (where branch_id is null) from public.inventory_movements
union all
select 'purchases', count(*), count(*) filter (where branch_id is null) from public.purchases
union all
select 'purchase_items', count(*), count(*) filter (where branch_id is null) from public.purchase_items
union all
select 'expenses', count(*), count(*) filter (where branch_id is null) from public.expenses
union all
select 'work_photos', count(*), count(*) filter (where branch_id is null) from public.work_photos
union all
select 'reviews', count(*), count(*) filter (where branch_id is null) from public.reviews
order by table_name;

rollback;
