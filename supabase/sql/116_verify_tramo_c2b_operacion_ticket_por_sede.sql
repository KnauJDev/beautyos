-- BeautyOS - Auditoria de solo lectura del Tramo C2b.

do $$
declare
  v_signature text;
  v_trigger_definition text;
begin
  foreach v_signature in array array[
    'public.get_ticket_services_for_management_v2(uuid,uuid)',
    'public.add_ticket_service_v2(uuid,uuid,uuid,uuid)',
    'public.update_ticket_service_assignment_v2(uuid,uuid,uuid,uuid,text)',
    'public.remove_ticket_service_v2(uuid,uuid,text)',
    'public.reschedule_ticket_v2(uuid,uuid,timestamptz,text)',
    'public.change_ticket_status_v2(uuid,uuid,text,text)',
    'public.change_ticket_service_status_v2(uuid,uuid,text)',
    'public.get_ticket_services_for_correction_v2(uuid,uuid)',
    'public.reopen_finished_ticket_service_v2(uuid,uuid,text)',
    'public.get_ticket_payment_summary_v2(uuid,uuid)',
    'public.get_ticket_payments_v2(uuid,uuid)',
    'public.register_ticket_payment_v2(uuid,uuid,numeric,text,text,text)',
    'public.void_ticket_payment_v2(uuid,uuid,text)'
  ] loop
    if to_regprocedure(v_signature) is null then
      raise exception 'Falta la funcion C2b %.', v_signature;
    end if;
    if has_function_privilege('anon', v_signature, 'EXECUTE') then
      raise exception 'Anon no debe ejecutar %.', v_signature;
    end if;
    if not has_function_privilege('authenticated', v_signature, 'EXECUTE') then
      raise exception 'Authenticated debe ejecutar %.', v_signature;
    end if;
  end loop;

  select pg_get_functiondef('public.enforce_stylist_schedule_conflict()'::regprocedure)
    into v_trigger_definition;

  if position('other_ts.branch_id = v_branch_id' in v_trigger_definition) = 0
     or position('beautyos:agenda:' in v_trigger_definition) = 0
     or position('v_branch_id::text' in v_trigger_definition) = 0 then
    raise exception 'La barrera final de agenda no quedo aislada y serializada por sede.';
  end if;

  if has_function_privilege(
       'authenticated',
       'public.enforce_stylist_schedule_conflict()',
       'EXECUTE'
     ) then
    raise exception 'Authenticated no debe ejecutar directamente el trigger de agenda.';
  end if;
end;
$$;

select
  p.oid::regprocedure::text as function_signature,
  p.prosecdef as security_definer,
  p.proconfig as function_settings
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname like '%\_v2' escape '\'
  and p.proname in (
    'get_ticket_services_for_management_v2',
    'add_ticket_service_v2',
    'update_ticket_service_assignment_v2',
    'remove_ticket_service_v2',
    'reschedule_ticket_v2',
    'change_ticket_status_v2',
    'change_ticket_service_status_v2',
    'get_ticket_services_for_correction_v2',
    'reopen_finished_ticket_service_v2',
    'get_ticket_payment_summary_v2',
    'get_ticket_payments_v2',
    'register_ticket_payment_v2',
    'void_ticket_payment_v2'
  )
order by function_signature;
