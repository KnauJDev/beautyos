-- BeautyOS - Auditoria de solo lectura del Tramo C2a.

do $$
declare
  v_signature text;
begin
  foreach v_signature in array array[
    'public.get_ticket_service_options_v2(uuid)',
    'public.get_available_appointment_slots_v2(uuid,uuid,uuid,date)',
    'public.create_scheduled_ticket_with_service_v2(uuid,uuid,uuid,uuid,timestamptz,text,text)',
    'public.get_tickets_summary_v2(uuid)',
    'public.get_agenda_summary_v2(uuid)',
    'public.get_my_stylist_agenda_by_date_v2(uuid,date)'
  ] loop
    if to_regprocedure(v_signature) is null then
      raise exception 'Falta la funcion C2a %.', v_signature;
    end if;

    if has_function_privilege('anon', v_signature, 'EXECUTE') then
      raise exception 'Anon no debe ejecutar %.', v_signature;
    end if;

    if not has_function_privilege('authenticated', v_signature, 'EXECUTE') then
      raise exception 'Authenticated debe ejecutar %.', v_signature;
    end if;
  end loop;

  if exists (
    select 1
    from pg_constraint
    where conrelid = 'public.business_hours'::regclass
      and conname = 'business_hours_tenant_id_day_of_week_key'
  ) then
    raise exception 'La unicidad antigua de horarios por tenant sigue activa.';
  end if;

  if exists (
    select 1
    from pg_constraint
    where conrelid = 'public.appointment_policies'::regclass
      and conname = 'appointment_policies_tenant_id_key'
  ) then
    raise exception 'La unicidad antigua de politicas por tenant sigue activa.';
  end if;

  if to_regclass('public.business_hours_branch_day_uidx') is null
     or to_regclass('public.appointment_policies_branch_uidx') is null then
    raise exception 'Faltan los indices unicos correctos por sede creados en Tramo B.';
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
  and p.proname in (
    'get_ticket_service_options_v2',
    'get_available_appointment_slots_v2',
    'create_scheduled_ticket_with_service_v2',
    'get_tickets_summary_v2',
    'get_agenda_summary_v2',
    'get_my_stylist_agenda_by_date_v2'
  )
order by function_signature;
