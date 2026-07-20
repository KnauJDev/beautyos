-- BeautyOS - Tramo D4.0: cliente heredado y reversión de permisos.
-- Simula un cliente autenticado antiguo dentro de una transacción reversible.

begin;

do $$
declare
  v_signature text;
  v_v2_signature text;
  v_blocked boolean;
begin
  foreach v_signature in array array[
    'public.get_appointment_policy()',
    'public.get_business_hours()',
    'public.get_dashboard_metrics()',
    'public.get_my_stylist_work_photos()',
    'public.get_reviews_summary()',
    'public.get_work_photos_summary()'
  ] loop
    if has_function_privilege('authenticated', v_signature, 'EXECUTE') then
      raise exception 'D4.0: el cliente heredado no está bloqueado en %.', v_signature;
    end if;

    execute format('grant execute on function %s to authenticated', v_signature);
    if not has_function_privilege('authenticated', v_signature, 'EXECUTE') then
      raise exception 'D4.0: no se pudo ensayar la reversión de %.', v_signature;
    end if;
    if has_function_privilege('anon', v_signature, 'EXECUTE') then
      raise exception 'D4.0: anon obtuvo acceso durante la reversión de %.', v_signature;
    end if;
    if not has_function_privilege('service_role', v_signature, 'EXECUTE') then
      raise exception 'D4.0: service_role perdió acceso durante la reversión de %.', v_signature;
    end if;

    execute 'set local role authenticated';
    v_blocked := false;
    begin
      execute format('select 1 from %s', v_signature);
    exception when insufficient_privilege then
      v_blocked := true;
    when others then
      null;
    end;
    execute 'reset role';
    if v_blocked then
      raise exception 'D4.0: el cliente heredado sigue bloqueado tras reotorgar %.',
        v_signature;
    end if;

    execute format('revoke all on function %s from authenticated', v_signature);
    if has_function_privilege('authenticated', v_signature, 'EXECUTE') then
      raise exception 'D4.0: no se pudo reaplicar la revocación de %.', v_signature;
    end if;
  end loop;

  foreach v_v2_signature in array array[
    'public.get_appointment_policy_v2(uuid)',
    'public.get_business_hours_v2(uuid)',
    'public.get_dashboard_metrics_v2(uuid)',
    'public.get_my_stylist_work_photos_v2(uuid)',
    'public.get_reviews_summary_v2(uuid)',
    'public.get_work_photos_summary_v2(uuid)'
  ] loop
    if not has_function_privilege('authenticated', v_v2_signature, 'EXECUTE')
       or has_function_privilege('anon', v_v2_signature, 'EXECUTE') then
      raise exception 'D4.0: la matriz de permisos _v2 cambió en %.', v_v2_signature;
    end if;
  end loop;
end;
$$;

rollback;
