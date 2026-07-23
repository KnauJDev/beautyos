-- BeautyOS - Prueba real (con rollback) de editar horario, politica de
-- citas y politica de comision, contra el tenant real "Cortes y Barbas".

begin;

do $$
declare
  v_branch_id uuid := 'a12dcc83-c6fd-4f87-a824-2c4e98e11f33';
  v_owner_id uuid := '54403360-f1e3-4475-95c5-607368f3e8a7'; -- amanteperfumes@gmail.com
  v_other_user_id uuid := '2975e198-2f33-4cd3-a3f2-4d93eb517118';
  v_hours jsonb;
  v_row_count integer;
  v_opens time;
  v_closes time;
  v_deposit numeric;
  v_cancel_hours integer;
  v_commission_type text;
  v_commission_pct numeric;
begin
  perform set_config('request.jwt.claim.sub', v_owner_id::text, true);

  -- 1. Editar el horario de los 7 dias (domingo pasa a abrir medio dia).
  v_hours := '[
    {"day_of_week":1,"opens_at":"09:00","closes_at":"19:00","is_open":true},
    {"day_of_week":2,"opens_at":"09:00","closes_at":"19:00","is_open":true},
    {"day_of_week":3,"opens_at":"09:00","closes_at":"19:00","is_open":true},
    {"day_of_week":4,"opens_at":"09:00","closes_at":"19:00","is_open":true},
    {"day_of_week":5,"opens_at":"09:00","closes_at":"19:00","is_open":true},
    {"day_of_week":6,"opens_at":"09:00","closes_at":"14:00","is_open":true},
    {"day_of_week":7,"opens_at":"09:00","closes_at":"12:00","is_open":true}
  ]'::jsonb;

  perform public.update_business_hours(v_branch_id, v_hours);

  select opens_at, closes_at into v_opens, v_closes
  from public.business_hours
  where branch_id = v_branch_id and day_of_week = 7;

  if v_opens <> '09:00' or v_closes <> '12:00' then
    raise exception 'FALLA 1: domingo no quedo actualizado (% - %)', v_opens, v_closes;
  end if;

  -- 2. Enviar solo 6 dias debe fallar (exige los 7).
  begin
    perform public.update_business_hours(v_branch_id, v_hours - 6);
    raise exception 'FALLA 2: debio exigir los 7 dias.';
  exception
    when others then
      if sqlerrm not ilike '%7 dias%' then raise; end if;
  end;

  -- 3. Apertura despues del cierre debe fallar.
  begin
    perform public.update_business_hours(
      v_branch_id,
      '[{"day_of_week":1,"opens_at":"20:00","closes_at":"09:00","is_open":true},
        {"day_of_week":2,"opens_at":"09:00","closes_at":"19:00","is_open":true},
        {"day_of_week":3,"opens_at":"09:00","closes_at":"19:00","is_open":true},
        {"day_of_week":4,"opens_at":"09:00","closes_at":"19:00","is_open":true},
        {"day_of_week":5,"opens_at":"09:00","closes_at":"19:00","is_open":true},
        {"day_of_week":6,"opens_at":"09:00","closes_at":"14:00","is_open":true},
        {"day_of_week":7,"opens_at":"09:00","closes_at":"12:00","is_open":true}]'::jsonb
    );
    raise exception 'FALLA 3: debio rechazar apertura despues del cierre.';
  exception
    when others then
      if sqlerrm not ilike '%apertura antes que cierre%' then raise; end if;
  end;

  -- 4. Editar la politica de citas.
  perform public.update_appointment_policy(
    v_branch_id, true, 30, 12, 12, false, true
  );

  select deposit_percentage, cancellation_hours into v_deposit, v_cancel_hours
  from public.appointment_policies
  where branch_id = v_branch_id and active = true;

  if v_deposit <> 30 or v_cancel_hours <> 12 then
    raise exception 'FALLA 4: la politica de citas no quedo actualizada (% %)', v_deposit, v_cancel_hours;
  end if;

  -- 5. Porcentaje de anticipo fuera de rango debe fallar.
  begin
    perform public.update_appointment_policy(v_branch_id, true, 150, 12, 12, false, true);
    raise exception 'FALLA 5: debio rechazar porcentaje fuera de rango.';
  exception
    when others then
      if sqlerrm not ilike '%entre 0 y 100%' then raise; end if;
  end;

  -- 6. Editar la politica de comision.
  perform public.update_commission_policy(
    v_branch_id, 'percentage', 50, 0, true, 'Ajustado en prueba'
  );

  select commission_type, commission_percentage into v_commission_type, v_commission_pct
  from public.commission_policies
  where tenant_id = (select tenant_id from public.branches where id = v_branch_id)
    and active = true;

  if v_commission_type <> 'percentage' or v_commission_pct <> 50 then
    raise exception 'FALLA 6: la politica de comision no quedo actualizada (% %)', v_commission_type, v_commission_pct;
  end if;

  -- 7. Tipo de comision invalido debe fallar.
  begin
    perform public.update_commission_policy(v_branch_id, 'salario', 50, 0, true, null);
    raise exception 'FALLA 7: debio rechazar un tipo de comision invalido.';
  exception
    when others then
      if sqlerrm not ilike '%tipo de comision no valido%' then raise; end if;
  end;

  -- 8. Un usuario de otro tenant no puede editar nada aqui.
  perform set_config('request.jwt.claim.sub', v_other_user_id::text, true);

  begin
    perform public.update_commission_policy(v_branch_id, 'percentage', 10, 0, true, null);
    raise exception 'FALLA 8: un usuario de otro tenant no debio poder editar aqui.';
  exception
    when others then
      if sqlerrm not ilike '%contexto de sede no esta disponible%' then raise; end if;
  end;

  raise notice 'Editar horario y politicas: 8 de 8 verificaciones aprobadas.';
end;
$$;

rollback;
