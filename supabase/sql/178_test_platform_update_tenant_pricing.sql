-- ============================================================================
-- CONTROL 178: TEST PLATFORM UPDATE TENANT PRICING & HISTORY (D-158)
-- ============================================================================

begin;

do $$
declare
  v_owner_user_id uuid := '00000000-0000-0000-0000-000000000001';
  v_tenant_id uuid;
  v_plan_id uuid;
  v_sub public.tenant_subscriptions%rowtype;
  v_effective_price bigint;
  v_history_count int;
begin
  raise notice 'Control 178: Iniciando pruebas de modificación de tarifa especial e historial...';

  -- 1. Setup de usuario de auth y operador de plataforma
  insert into auth.users (id, email)
  values (v_owner_user_id, 'platform_owner_test178@salonymas.com')
  on conflict (id) do nothing;

  insert into public.platform_operators (user_id, role, active)
  values (v_owner_user_id, 'platform_owner', true)
  on conflict (user_id) do update set role = 'platform_owner', active = true;

  perform set_config('request.jwt.claim.sub', v_owner_user_id::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', v_owner_user_id::text)::text, true);

  -- 2. Crear tenant de prueba
  insert into public.tenants (name, business_type, contact_email, whatsapp, is_demo, active)
  values ('Peluqueria Especial Amigo', 'peluqueria', 'amigo@gmail.com', '3001234567', false, true)
  returning id into v_tenant_id;

  select id into v_plan_id from public.plans where code = 'basico';

  insert into public.tenant_subscriptions (
    tenant_id,
    plan_id,
    status,
    is_founder,
    trial_ends_at
  ) values (
    v_tenant_id,
    v_plan_id,
    'trialing',
    false,
    now() + interval '21 days'
  );

  -- 3. Probar modificar a precio especial personalizado de $30.000 COP
  v_sub := public.platform_update_tenant_pricing(
    p_tenant_id => v_tenant_id,
    p_plan_code => 'basico',
    p_is_founder => false,
    p_price_cop => 30000,
    p_price_reason => 'Convenio amigo especial'
  );

  if v_sub.price_cop != 30000 then
    raise exception 'Fallo prueba 1: el precio especial no se guardó como 30000 COP (quedó %)', v_sub.price_cop;
  end if;

  -- 4. Verificar que beautyos_precio_efectivo retorne $30.000 COP
  v_effective_price := private.beautyos_precio_efectivo(v_tenant_id);
  if v_effective_price != 30000 then
    raise exception 'Fallo prueba 2: beautyos_precio_efectivo devolvió % en vez de 30000', v_effective_price;
  end if;

  -- 5. Probar modificar a precio especial de $70.000 COP con plan Business
  v_sub := public.platform_update_tenant_pricing(
    p_tenant_id => v_tenant_id,
    p_plan_code => 'business',
    p_is_founder => false,
    p_price_cop => 70000,
    p_price_reason => 'Tarifa acordada de 70k'
  );

  if v_sub.price_cop != 70000 then
    raise exception 'Fallo prueba 3: el precio no se actualizó a 70000 COP';
  end if;

  -- 6. Verificar historial de eventos
  select count(*) into v_history_count
  from public.platform_get_tenant_subscription_history(v_tenant_id);

  if v_history_count < 2 then
    raise exception 'Fallo prueba 4: se esperaban al menos 2 eventos en el historial, hay %', v_history_count;
  end if;

  raise notice 'Control 178: Todas las 4 comprobaciones de modificación de tarifa pasaron exitosamente en VERDE.';
end $$;

rollback;
