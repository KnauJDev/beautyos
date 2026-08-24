-- ============================================================================
-- CONTROL 181: TEST CONTACTO TITULAR Y HISTORIAL COMPLETO
-- Valida platform_update_tenant_contact, update_tenant_contact_info (y su
-- aislamiento entre tenants), el contact_name expuesto por
-- platform_list_tenants/get_business_settings, y el period_start/period_end/
-- payment_detail nuevos de platform_get_tenant_subscription_history.
-- ============================================================================

begin;

do $$
declare
  v_platform_owner_id uuid := '00000000-0000-0000-0000-000000000181';
  v_owner_a_id uuid := '00000000-0000-0000-0000-000000000182';
  v_owner_b_id uuid := '00000000-0000-0000-0000-000000000183';
  v_tenant_a uuid;
  v_tenant_b uuid;
  v_plan_id uuid;
  v_contact_name text;
  v_contact_email text;
  v_whatsapp text;
  v_business_type text;
  v_city text;
  v_processed boolean;
  v_prev text;
  v_new text;
  v_msg text;
  v_x_ref text := 'TEST181_REF_' || floor(random()*1000000)::text;
  v_history record;
  v_found_tenant_approved boolean := false;
  v_found_epayco boolean := false;
begin
  raise notice 'Control 181: Iniciando pruebas de contacto titular e historial completo...';

  -- 1. Setup: platform_owner de prueba.
  insert into auth.users (id, email)
  values (v_platform_owner_id, 'platform_owner_test181@salonymas.com')
  on conflict (id) do nothing;

  insert into public.platform_operators (user_id, role, active)
  values (v_platform_owner_id, 'platform_owner', true)
  on conflict (user_id) do update set role = 'platform_owner', active = true;

  select id into v_plan_id from public.plans where code = 'profesional' and status = 'active';
  if v_plan_id is null then
    raise exception 'No se encontró el plan profesional activo.';
  end if;

  -- 2. Tenant A: para probar edición de plataforma e historial.
  insert into public.tenants (name, business_type, contact_email, whatsapp, is_demo, active)
  values ('Salon Prueba Contacto A', 'peluqueria', 'viejo_a@gmail.com', '3000000001', false, true)
  returning id into v_tenant_a;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, is_founder, trial_ends_at)
  values (v_tenant_a, v_plan_id, 'trialing', false, now() + interval '15 days');

  insert into auth.users (id, email)
  values (v_owner_a_id, 'owner_a_test181@salonymas.com')
  on conflict (id) do nothing;

  insert into public.user_profiles (tenant_id, user_id, full_name, role, active)
  values (v_tenant_a, v_owner_a_id, 'elboga002', 'owner', true)
  on conflict (user_id) do update set tenant_id = v_tenant_a, full_name = 'elboga002', active = true;

  -- get_my_tenant_id()/is_owner_or_admin() (D-Tramo D3.5.3) leen de
  -- tenant_memberships, no de user_profiles: hace falta esta fila paralela
  -- para que get_business_settings/update_tenant_contact_info autoricen al
  -- owner de prueba, igual que hace register_tenant en el registro real.
  insert into public.tenant_memberships (tenant_id, user_id, role, active, starts_at)
  values (v_tenant_a, v_owner_a_id, 'tenant_owner', true, now());

  -- 3. Tenant B: solo para probar que update_tenant_contact_info NUNCA toca
  -- un tenant que no es el propio del usuario autenticado.
  insert into public.tenants (name, business_type, contact_email, whatsapp, is_demo, active)
  values ('Salon Prueba Contacto B', 'barberia', 'viejo_b@gmail.com', '3000000002', false, true)
  returning id into v_tenant_b;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, is_founder, trial_ends_at)
  values (v_tenant_b, v_plan_id, 'trialing', false, now() + interval '15 days');

  insert into auth.users (id, email)
  values (v_owner_b_id, 'owner_b_test181@salonymas.com')
  on conflict (id) do nothing;

  insert into public.user_profiles (tenant_id, user_id, full_name, role, active)
  values (v_tenant_b, v_owner_b_id, 'usuario_b_viejo', 'owner', true)
  on conflict (user_id) do update set tenant_id = v_tenant_b, full_name = 'usuario_b_viejo', active = true;

  insert into public.tenant_memberships (tenant_id, user_id, role, active, starts_at)
  values (v_tenant_b, v_owner_b_id, 'tenant_owner', true, now());

  -- 4. Registrar en subscription_events un 'tenant_approved' manual (misma
  -- forma en la que lo deja platform_approve_tenant) para probar el período
  -- de prueba en el historial.
  insert into public.subscription_events (tenant_id, tenant_subscription_id, event_type, payload)
  select
    v_tenant_a,
    ts.id,
    'tenant_approved',
    jsonb_build_object('plan_code', 'profesional', 'trial_ends_at', ts.trial_ends_at)
  from public.tenant_subscriptions ts
  where ts.tenant_id = v_tenant_a;

  -- 5. Simular un pago de ePayco aceptado sobre el tenant A, para que
  -- platform_get_tenant_subscription_history tenga un evento con
  -- periodo_inicio/periodo_fin/monto/referencia reales.
  select processed, previous_status, new_status, message
  into v_processed, v_prev, v_new, v_msg
  from private.beautyos_procesar_evento_epayco(
    v_tenant_a, v_x_ref, 'TX181', 'Aceptada', '1',
    240000, 'COP',
    jsonb_build_object('x_franchise', 'PSE', 'x_bank_name', 'Bancolombia'),
    'profesional'
  );

  if v_new != 'active' then
    raise exception 'Fallo setup pago ePayco: se esperaba active, resultado %', v_new;
  end if;

  -- ---------------------------------------------------------------------
  -- PRUEBA 1: platform_update_tenant_contact corrige nombre/correo/whatsapp/
  -- tipo/ciudad del tenant A, y actualiza user_profiles.full_name del owner.
  -- ---------------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', v_platform_owner_id::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', v_platform_owner_id::text)::text, true);

  perform public.platform_update_tenant_contact(
    v_tenant_a, 'Yelimar Rodriguez', 'yelimar@gmail.com', '3009999999', 'salon de belleza', 'Bogotá'
  );

  select business_type, city, contact_email, whatsapp
  into v_business_type, v_city, v_contact_email, v_whatsapp
  from public.tenants where id = v_tenant_a;

  if v_contact_email is distinct from 'yelimar@gmail.com' or v_whatsapp is distinct from '3009999999'
     or v_business_type is distinct from 'salon de belleza' or v_city is distinct from 'Bogotá' then
    raise exception 'Fallo PRUEBA 1: tenants no quedó con los datos nuevos (email=%, whatsapp=%, tipo=%, ciudad=%)',
      v_contact_email, v_whatsapp, v_business_type, v_city;
  end if;

  select full_name into v_contact_name
  from public.user_profiles where tenant_id = v_tenant_a and role = 'owner';

  if v_contact_name is distinct from 'Yelimar Rodriguez' then
    raise exception 'Fallo PRUEBA 1: user_profiles.full_name no quedó en Yelimar Rodriguez (quedó %)', v_contact_name;
  end if;

  raise notice 'Control 181: PRUEBA 1 (platform_update_tenant_contact) EXITOSA.';

  -- ---------------------------------------------------------------------
  -- PRUEBA 2: platform_list_tenants y get_business_settings exponen el
  -- contact_name real (ya no la parte del correo antes de la @).
  -- ---------------------------------------------------------------------
  select contact_name into v_contact_name
  from public.platform_list_tenants()
  where tenant_id = v_tenant_a;

  if v_contact_name is distinct from 'Yelimar Rodriguez' then
    raise exception 'Fallo PRUEBA 2a: platform_list_tenants no devolvió contact_name correcto (%)', v_contact_name;
  end if;

  perform set_config('request.jwt.claim.sub', v_owner_a_id::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', v_owner_a_id::text)::text, true);

  select contact_name into v_contact_name from public.get_business_settings();

  if v_contact_name is distinct from 'Yelimar Rodriguez' then
    raise exception 'Fallo PRUEBA 2b: get_business_settings no devolvió contact_name correcto (%)', v_contact_name;
  end if;

  raise notice 'Control 181: PRUEBA 2 (contact_name en list/get) EXITOSA.';

  -- ---------------------------------------------------------------------
  -- PRUEBA 3: update_tenant_contact_info (autoservicio) actualiza SOLO el
  -- tenant propio del usuario autenticado (tenant B), y el tenant A queda
  -- intacto.
  -- ---------------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', v_owner_b_id::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', v_owner_b_id::text)::text, true);

  perform public.update_tenant_contact_info(
    'Carlos Perez', 'barberia premium', '3018888888', '3018888889'
  );

  select business_type, contact_phone, whatsapp into v_business_type, v_city, v_whatsapp
  from public.tenants where id = v_tenant_b;

  if v_business_type is distinct from 'barberia premium' or v_whatsapp is distinct from '3018888889' then
    raise exception 'Fallo PRUEBA 3: tenant B no quedó actualizado (tipo=%, whatsapp=%)', v_business_type, v_whatsapp;
  end if;

  select full_name into v_contact_name
  from public.user_profiles where tenant_id = v_tenant_b and role = 'owner';

  if v_contact_name is distinct from 'Carlos Perez' then
    raise exception 'Fallo PRUEBA 3: user_profiles del owner B no quedó en Carlos Perez (%)', v_contact_name;
  end if;

  -- Aislamiento: el tenant A no debió tocarse por esta llamada.
  select contact_email into v_contact_email from public.tenants where id = v_tenant_a;
  if v_contact_email is distinct from 'yelimar@gmail.com' then
    raise exception 'Fallo PRUEBA 3 (aislamiento): update_tenant_contact_info alteró el tenant A (email quedó %)', v_contact_email;
  end if;

  raise notice 'Control 181: PRUEBA 3 (update_tenant_contact_info + aislamiento) EXITOSA.';

  -- ---------------------------------------------------------------------
  -- PRUEBA 4: platform_get_tenant_subscription_history trae período
  -- comprometido y medio de pago/referencia reales.
  -- ---------------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', v_platform_owner_id::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', v_platform_owner_id::text)::text, true);

  for v_history in
    select * from public.platform_get_tenant_subscription_history(v_tenant_a)
  loop
    if v_history.event_type = 'tenant_approved' then
      v_found_tenant_approved := true;
      if v_history.period_end is null or v_history.payment_detail is distinct from 'Período de prueba' then
        raise exception 'Fallo PRUEBA 4a: fila tenant_approved sin period_end o payment_detail incorrecto (%, %)',
          v_history.period_end, v_history.payment_detail;
      end if;
    end if;

    if v_history.event_type like 'epayco_%' and v_history.amount_cop = 240000 then
      v_found_epayco := true;
      if v_history.period_start is null or v_history.period_end is null then
        raise exception 'Fallo PRUEBA 4b: fila de pago ePayco sin período comprometido.';
      end if;
      if v_history.payment_detail is null or v_history.payment_detail not like '%Ref:%' then
        raise exception 'Fallo PRUEBA 4b: payment_detail sin referencia (%)', v_history.payment_detail;
      end if;
      if v_history.payment_detail not like '%PSE%' or v_history.payment_detail not like '%Bancolombia%' then
        raise exception 'Fallo PRUEBA 4b: payment_detail no trae franquicia/banco (%)', v_history.payment_detail;
      end if;
      if v_history.plan_name is null then
        raise exception 'Fallo PRUEBA 4b: plan_name vino nulo.';
      end if;
    end if;
  end loop;

  if not v_found_tenant_approved then
    raise exception 'Fallo PRUEBA 4: no se encontró la fila tenant_approved en el historial.';
  end if;
  if not v_found_epayco then
    raise exception 'Fallo PRUEBA 4: no se encontró la fila de pago ePayco aceptado en el historial.';
  end if;

  raise notice 'Control 181: PRUEBA 4 (historial completo) EXITOSA.';

  raise notice 'Control 181: Todas las pruebas pasaron exitosamente en VERDE.';
end $$;

rollback;
