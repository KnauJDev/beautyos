-- BeautyOS - Registro self-serve de un negocio nuevo.
-- Prueba de contrato contra el esquema sintetico (132 + branches/
-- branch_memberships reales + D3.5.3 + fundacion de suscripciones).

do $$
declare
  v_user_id uuid := gen_random_uuid();
  v_second_user_id uuid := gen_random_uuid();
  v_tenant_id uuid;
  v_branch_id uuid;
  v_trial_ends_at timestamptz;
  v_row_count integer;
  v_status text;
  v_is_primary boolean;
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
  ) values
    ('00000000-0000-0000-0000-000000000000', v_user_id, 'authenticated', 'authenticated',
     'nuevo-dueno@synth.test', crypt('x', gen_salt('bf')), now(), '{}', '{}', now(), now()),
    ('00000000-0000-0000-0000-000000000000', v_second_user_id, 'authenticated', 'authenticated',
     'ya-tiene-negocio@synth.test', crypt('x', gen_salt('bf')), now(), '{}', '{}', now(), now());

  -- 1. Sin sesion (auth.uid() null): debe rechazar.
  perform set_config('request.jwt.claim.sub', '', true);
  begin
    perform public.register_tenant('Salon sin sesion', 'Nadie', '3000000000');
    raise exception 'FALLA 1: no debio permitir registrar sin sesion.';
  exception
    when others then
      if sqlerrm not like '%sesion autenticada%' then
        raise;
      end if;
  end;

  -- 2. Registro exitoso con sesion real.
  perform set_config('request.jwt.claim.sub', v_user_id::text, true);
  select tenant_id, branch_id, trial_ends_at
    into v_tenant_id, v_branch_id, v_trial_ends_at
  from public.register_tenant('Salon Sintetico', 'Ana Duena', '3001234567', 'salon');

  if v_tenant_id is null or v_branch_id is null then
    raise exception 'FALLA 2: register_tenant debio devolver tenant_id y branch_id.';
  end if;

  if v_trial_ends_at - now() < interval '20 days 23 hours' or v_trial_ends_at - now() > interval '21 days 1 hour' then
    raise exception 'FALLA 3: el periodo de prueba debio ser de 21 dias (obtuvo %).', (v_trial_ends_at - now());
  end if;

  -- 3. tenants, branches, user_profiles, tenant_memberships,
  --    branch_memberships y tenant_subscriptions quedaron consistentes.
  select count(*) into v_row_count from public.tenants where id = v_tenant_id;
  if v_row_count <> 1 then
    raise exception 'FALLA 4: debio existir exactamente un tenant.';
  end if;

  select is_primary into v_is_primary from public.branches where id = v_branch_id and tenant_id = v_tenant_id;
  if v_is_primary is distinct from true then
    raise exception 'FALLA 5: la sede creada debio quedar marcada como principal.';
  end if;

  if (select count(*) from public.user_profiles where tenant_id = v_tenant_id and user_id = v_user_id and role = 'owner') <> 1 then
    raise exception 'FALLA 6: debio crearse el perfil de owner en user_profiles.';
  end if;

  if (select count(*) from public.tenant_memberships where tenant_id = v_tenant_id and user_id = v_user_id and role = 'tenant_owner' and active) <> 1 then
    raise exception 'FALLA 7: debio crearse la membresia tenant_owner activa.';
  end if;

  if (select count(*) from public.branch_memberships bm join public.tenant_memberships tm on tm.id = bm.tenant_membership_id where bm.branch_id = v_branch_id and tm.user_id = v_user_id and bm.active) <> 1 then
    raise exception 'FALLA 8: debio crearse la membresia de sede activa para el owner.';
  end if;

  select status into v_status from public.tenant_subscriptions where tenant_id = v_tenant_id;
  if v_status is distinct from 'trialing' then
    raise exception 'FALLA 9: la suscripcion debio quedar en trialing (obtuvo %).', v_status;
  end if;

  if (select p.code from public.tenant_subscriptions ts join public.plans p on p.id = ts.plan_id where ts.tenant_id = v_tenant_id) is distinct from 'profesional' then
    raise exception 'FALLA 10: el plan de prueba debio ser profesional.';
  end if;

  if (select count(*) from public.subscription_events where tenant_id = v_tenant_id and event_type = 'trial_started') <> 1 then
    raise exception 'FALLA 11: debio quedar registrado el evento trial_started.';
  end if;

  -- 4. Ahora el owner tiene entitlements reales via get_my_entitlements().
  if (select count(*) from public.get_my_entitlements() where entitled) < 3 then
    raise exception 'FALLA 12: el plan Profesional en prueba debio habilitar todas las funcionalidades.';
  end if;

  -- 5. El mismo usuario no puede registrar un segundo negocio.
  begin
    perform public.register_tenant('Segundo salon', 'Ana Duena', '3001234567');
    raise exception 'FALLA 13: no debio permitir un segundo registro para el mismo usuario.';
  exception
    when others then
      if sqlerrm not like '%ya pertenece a un negocio%' then
        raise;
      end if;
  end;

  -- 6. Un usuario distinto sin membresias si puede registrar el suyo.
  perform set_config('request.jwt.claim.sub', v_second_user_id::text, true);
  perform public.register_tenant('Barberia Otro Dueno', 'Carlos Otro', '3009876543');

  if (select count(*) from public.tenants) <> 2 then
    raise exception 'FALLA 14: debieron existir exactamente dos tenants distintos.';
  end if;

  raise notice 'Registro self-serve: 14 de 14 verificaciones de contrato aprobadas.';
end;
$$;
