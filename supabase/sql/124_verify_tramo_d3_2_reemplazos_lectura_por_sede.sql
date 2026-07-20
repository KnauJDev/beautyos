-- BeautyOS - Verificacion estructural y de privilegios del Tramo D3.2.

do $$
declare
  v_signature text;
  v_definition text;
  v_result text;
  v_expected_result text;
  v_public_execute boolean;
begin
  foreach v_signature in array array[
    'public.get_appointment_policy_v2(uuid)',
    'public.get_business_hours_v2(uuid)',
    'public.get_dashboard_metrics_v2(uuid)',
    'public.get_my_stylist_work_photos_v2(uuid)',
    'public.get_reviews_summary_v2(uuid)',
    'public.get_work_photos_summary_v2(uuid)'
  ] loop
    if to_regprocedure(v_signature) is null then
      raise exception 'D3.2: falta la RPC %.', v_signature;
    end if;

    if has_function_privilege('anon', v_signature, 'EXECUTE') then
      raise exception 'D3.2: anon conserva EXECUTE sobre %.', v_signature;
    end if;
    if not has_function_privilege('authenticated', v_signature, 'EXECUTE') then
      raise exception 'D3.2: authenticated no puede ejecutar %.', v_signature;
    end if;
    if not has_function_privilege('service_role', v_signature, 'EXECUTE') then
      raise exception 'D3.2: service_role no puede ejecutar %.', v_signature;
    end if;

    select exists (
      select 1
      from pg_proc p
      cross join lateral aclexplode(
        coalesce(p.proacl, acldefault('f', p.proowner))
      ) acl
      where p.oid = to_regprocedure(v_signature)
        and acl.grantee = 0
        and acl.privilege_type = 'EXECUTE'
    ) into v_public_execute;
    if v_public_execute then
      raise exception 'D3.2: PUBLIC conserva EXECUTE sobre %.', v_signature;
    end if;

    select pg_get_functiondef(to_regprocedure(v_signature))
      into v_definition;
    if position('SECURITY DEFINER' in v_definition) = 0
       or position('SET search_path TO ''pg_catalog''' in v_definition) = 0
       or position('beautyos_resolve_branch_access' in v_definition) = 0
       or position('p_branch_id' in v_definition) = 0 then
      raise exception 'D3.2: % no conserva el patron seguro esperado.', v_signature;
    end if;
    if position('user_profiles' in v_definition) > 0 then
      raise exception 'D3.2: % depende de user_profiles.', v_signature;
    end if;

    v_expected_result := case v_signature
      when 'public.get_appointment_policy_v2(uuid)' then
        'TABLE(id uuid, requires_deposit boolean, deposit_percentage numeric, cancellation_hours integer, reschedule_hours integer, manual_confirmation_required boolean, customer_reschedule_allowed boolean)'
      when 'public.get_business_hours_v2(uuid)' then
        'TABLE(id uuid, day_of_week integer, opens_at time without time zone, closes_at time without time zone, is_open boolean)'
      when 'public.get_dashboard_metrics_v2(uuid)' then
        'TABLE(active_services_count integer, clients_count integer, confirmed_tickets_count integer, today_tickets_count integer, active_stylists_count integer, active_stylist_services_count integer)'
      when 'public.get_my_stylist_work_photos_v2(uuid)' then
        'TABLE(id uuid, ticket_id uuid, client_name text, service_name text, photo_url text, photo_type text, caption text, ai_status text, visible_to_customer boolean, approved_for_portfolio boolean, created_at timestamp with time zone)'
      when 'public.get_reviews_summary_v2(uuid)' then
        'TABLE(id uuid, ticket_id uuid, client_name text, stylist_name text, service_name text, rating integer, comment text, moderation_status text, visible_to_public boolean, created_at timestamp with time zone)'
      when 'public.get_work_photos_summary_v2(uuid)' then
        'TABLE(id uuid, ticket_id uuid, client_name text, stylist_name text, photo_url text, photo_type text, caption text, ai_status text, visible_to_customer boolean, approved_for_portfolio boolean, created_at timestamp with time zone)'
    end;
    select pg_get_function_result(to_regprocedure(v_signature))
      into v_result;
    if v_result <> v_expected_result then
      raise exception 'D3.2: forma incompatible para %: %.',
        v_signature, v_result;
    end if;
  end loop;

  foreach v_signature in array array[
    'public.get_appointment_policy()',
    'public.get_business_hours()',
    'public.get_dashboard_metrics()',
    'public.get_my_stylist_work_photos()',
    'public.get_reviews_summary()',
    'public.get_work_photos_summary()'
  ] loop
    if to_regprocedure(v_signature) is null then
      raise exception 'D3.2: se retiro antes de tiempo la firma heredada %.',
        v_signature;
    end if;
  end loop;
end;
$$;

select
  p.oid::regprocedure as signature,
  p.prosecdef as security_definer,
  p.proconfig as function_config,
  has_function_privilege('authenticated', p.oid, 'EXECUTE')
    as authenticated_execute,
  has_function_privilege('anon', p.oid, 'EXECUTE') as anon_execute
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'get_appointment_policy_v2',
    'get_business_hours_v2',
    'get_dashboard_metrics_v2',
    'get_my_stylist_work_photos_v2',
    'get_reviews_summary_v2',
    'get_work_photos_summary_v2'
  )
order by p.proname;
