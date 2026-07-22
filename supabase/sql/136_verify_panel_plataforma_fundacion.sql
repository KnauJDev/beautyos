-- BeautyOS - Panel de plataforma.
-- Prueba de contrato contra el esquema sintetico + fundacion de
-- suscripciones + esta migracion. El UID del platform_owner sembrado
-- (dbee91f0-36e0-4bd8-9303-fe173418ba55) debe existir en auth.users antes
-- de correr esta prueba (se inserta aparte porque en el proyecto real ya
-- lo creo el propietario; aqui se simula igual).

do $$
declare
  v_owner_id uuid := 'dbee91f0-36e0-4bd8-9303-fe173418ba55';
  v_random_user_id uuid := gen_random_uuid();
  v_tenant_a uuid := gen_random_uuid();
  v_tenant_b uuid := gen_random_uuid();
  v_plan_id uuid;
  v_role text;
  v_row_count integer;
  v_status text;
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
  ) values (
    '00000000-0000-0000-0000-000000000000', v_random_user_id, 'authenticated', 'authenticated',
    'nadie-especial@synth.test', crypt('x', gen_salt('bf')), now(), '{}', '{}', now(), now()
  );

  select id into v_plan_id from public.plans where code = 'profesional';

  insert into public.tenants (id, name, contact_email, whatsapp) values
    (v_tenant_a, 'Salon A', 'a@synth.test', '3000000001'),
    (v_tenant_b, 'Salon B', 'b@synth.test', '3000000002');

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, trial_ends_at, current_period_start)
  values
    (v_tenant_a, v_plan_id, 'trialing', now() + interval '21 days', now()),
    (v_tenant_b, v_plan_id, 'active', null, now());

  -- 1. Un usuario sin rol de plataforma no puede listar tenants.
  perform set_config('request.jwt.claim.sub', v_random_user_id::text, true);
  begin
    perform public.platform_list_tenants();
    raise exception 'FALLA 1: un usuario sin rol de plataforma no debio listar tenants.';
  exception
    when others then
      if sqlerrm not ilike '%rol de plataforma%' then
        raise;
      end if;
  end;

  -- 2. get_my_platform_role() es null para un usuario sin rol.
  if (select public.get_my_platform_role()) is not null then
    raise exception 'FALLA 2: get_my_platform_role debio ser null.';
  end if;

  -- 3. El platform_owner si puede listar y ve ambos tenants.
  perform set_config('request.jwt.claim.sub', v_owner_id::text, true);
  if (select public.get_my_platform_role()) is distinct from 'platform_owner' then
    raise exception 'FALLA 3: get_my_platform_role debio ser platform_owner.';
  end if;

  select count(*) into v_row_count from public.platform_list_tenants();
  if v_row_count <> 2 then
    raise exception 'FALLA 4: platform_list_tenants debio devolver 2 tenants (obtuvo %).', v_row_count;
  end if;

  -- 4. Suspender sin motivo falla.
  begin
    perform public.platform_suspend_tenant(v_tenant_b, '');
    raise exception 'FALLA 5: no debio permitir suspender sin motivo.';
  exception
    when others then
      if sqlerrm not ilike '%motivo es obligatorio%' then
        raise;
      end if;
  end;

  -- 5. Suspender con motivo funciona y queda auditado.
  perform public.platform_suspend_tenant(v_tenant_b, 'Cliente reporto fraude, en investigacion.');

  select status into v_status from public.tenant_subscriptions where tenant_id = v_tenant_b;
  if v_status is distinct from 'suspended' then
    raise exception 'FALLA 6: el tenant B debio quedar suspended (obtuvo %).', v_status;
  end if;

  if (select count(*) from public.subscription_events where tenant_id = v_tenant_b and event_type = 'suspended_by_platform') <> 1 then
    raise exception 'FALLA 7: debio quedar registrado el evento suspended_by_platform.';
  end if;

  -- 6. Reactivar funciona.
  perform public.platform_reactivate_tenant(v_tenant_b, 'Se aclaro el malentendido con el cliente.');
  select status into v_status from public.tenant_subscriptions where tenant_id = v_tenant_b;
  if v_status is distinct from 'active' then
    raise exception 'FALLA 8: el tenant B debio volver a active (obtuvo %).', v_status;
  end if;

  -- 7. Extender prueba solo aplica a tenants en trialing (B ya no lo esta).
  begin
    perform public.platform_extend_trial(v_tenant_b, now() + interval '30 days', 'Prueba de bloqueo.');
    raise exception 'FALLA 9: no debio poder extender la prueba de un tenant activo (no trialing).';
  exception
    when others then
      if sqlerrm not ilike '%no se encontro una suscripcion en periodo de prueba%' then
        raise;
      end if;
  end;

  -- 8. Extender prueba si funciona sobre el tenant A (trialing).
  perform public.platform_extend_trial(v_tenant_a, now() + interval '35 days', 'Negociacion comercial especial.');
  select trial_ends_at into v_status from public.tenant_subscriptions where tenant_id = v_tenant_a;
  -- reutilizo v_status como texto no es ideal pero solo validamos existencia:
  if (select trial_ends_at from public.tenant_subscriptions where tenant_id = v_tenant_a) < now() + interval '34 days' then
    raise exception 'FALLA 10: la prueba del tenant A debio extenderse.';
  end if;

  -- 9. Un usuario "platform_operator" (no owner) puede listar pero no suspender.
  insert into public.platform_operators (user_id, role) values (v_random_user_id, 'platform_operator');
  perform set_config('request.jwt.claim.sub', v_random_user_id::text, true);

  select count(*) into v_row_count from public.platform_list_tenants();
  if v_row_count <> 2 then
    raise exception 'FALLA 11: platform_operator tambien debio poder listar tenants.';
  end if;

  begin
    perform public.platform_suspend_tenant(v_tenant_a, 'Intento no autorizado.');
    raise exception 'FALLA 12: platform_operator no debio poder suspender un tenant.';
  exception
    when others then
      if sqlerrm not ilike '%solo platform_owner%' then
        raise;
      end if;
  end;

  raise notice 'Panel de plataforma: 12 de 12 verificaciones de contrato aprobadas.';
end;
$$;
