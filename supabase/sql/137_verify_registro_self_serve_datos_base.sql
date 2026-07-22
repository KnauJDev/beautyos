-- BeautyOS - Registro self-serve: datos base.
-- Verifica que register_tenant() ahora deja la sede lista para operar
-- desde el primer momento (horario, politica de citas, comision), sin
-- filas faltantes que rompan Configuracion/Horarios/Politica de citas.

do $$
declare
  v_user_id uuid := gen_random_uuid();
  v_tenant_id uuid;
  v_branch_id uuid;
  v_hours_count integer;
  v_open_days integer;
  v_closed_days integer;
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
  ) values (
    '00000000-0000-0000-0000-000000000000', v_user_id, 'authenticated', 'authenticated',
    'nuevo-negocio@synth.test', crypt('x', gen_salt('bf')), now(), '{}', '{}', now(), now()
  );

  perform set_config('request.jwt.claim.sub', v_user_id::text, true);

  select tenant_id, branch_id
    into v_tenant_id, v_branch_id
  from public.register_tenant('Salon Datos Base', 'Duena Prueba', '3001112222');

  -- 1. business_hours: exactamente 7 filas, todas para la sede nueva.
  select count(*) into v_hours_count
  from public.business_hours
  where tenant_id = v_tenant_id and branch_id = v_branch_id;
  if v_hours_count <> 7 then
    raise exception 'FALLA 1: debieron crearse 7 filas de horario (obtuvo %).', v_hours_count;
  end if;

  select count(*) into v_open_days
  from public.business_hours
  where tenant_id = v_tenant_id and branch_id = v_branch_id and is_open;
  if v_open_days <> 6 then
    raise exception 'FALLA 2: debieron quedar 6 dias abiertos (obtuvo %).', v_open_days;
  end if;

  select count(*) into v_closed_days
  from public.business_hours
  where tenant_id = v_tenant_id and branch_id = v_branch_id and not is_open;
  if v_closed_days <> 1 then
    raise exception 'FALLA 3: debio quedar exactamente 1 dia cerrado (domingo).';
  end if;

  -- 2. appointment_policies: exactamente 1 fila para la sede.
  if (select count(*) from public.appointment_policies where tenant_id = v_tenant_id and branch_id = v_branch_id) <> 1 then
    raise exception 'FALLA 4: debio crearse exactamente 1 politica de citas.';
  end if;

  -- 3. commission_policies: exactamente 1 fila para el tenant.
  if (select count(*) from public.commission_policies where tenant_id = v_tenant_id) <> 1 then
    raise exception 'FALLA 5: debio crearse exactamente 1 politica de comision.';
  end if;

  -- 4. Lo que ya probaba 135 sigue intacto: tenant, sede, membresia,
  --    suscripcion trialing.
  if (select count(*) from public.tenant_memberships where tenant_id = v_tenant_id and user_id = v_user_id and role = 'tenant_owner') <> 1 then
    raise exception 'FALLA 6: la membresia tenant_owner debio seguir creandose.';
  end if;

  if (select status from public.tenant_subscriptions where tenant_id = v_tenant_id) is distinct from 'trialing' then
    raise exception 'FALLA 7: la suscripcion debio seguir en trialing.';
  end if;

  raise notice 'Registro self-serve (datos base): 7 de 7 verificaciones de contrato aprobadas.';
end;
$$;
