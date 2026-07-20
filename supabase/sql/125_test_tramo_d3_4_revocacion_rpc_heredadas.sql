-- BeautyOS - Prueba reversible del Tramo D3.4.
-- Confirma que anon y authenticated reciben denegación real al invocar las
-- seis firmas heredadas. Todo termina con ROLLBACK.

begin;

do $$
declare
  v_signature text;
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
    execute 'set local role anon';
    v_blocked := false;
    begin
      execute format('select 1 from %s', v_signature);
    exception when insufficient_privilege then
      v_blocked := true;
    end;
    execute 'reset role';
    if not v_blocked then
      raise exception 'D3.4: anon pudo invocar la firma heredada %.', v_signature;
    end if;

    execute 'set local role authenticated';
    v_blocked := false;
    begin
      execute format('select 1 from %s', v_signature);
    exception when insufficient_privilege then
      v_blocked := true;
    end;
    execute 'reset role';
    if not v_blocked then
      raise exception
        'D3.4: authenticated pudo invocar la firma heredada %.', v_signature;
    end if;
  end loop;
end;
$$;

rollback;
