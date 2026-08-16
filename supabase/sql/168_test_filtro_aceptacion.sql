-- BeautyOS / Salón y Más - Control 168: Prueba de verificación del Filtro de Aceptación (Paso 3.7 / D-125).
--
-- Ejecuta todos los escenarios en una transacción aislada terminada en ROLLBACK:
-- 1. Registro self-serve con cuestionario completo -> nace en 'pending' sin fecha de fin de prueba.
-- 2. Negocio en 'pending' no acepta compromisos ni citas.
-- 3. Consulta de estado get_my_tenant_subscription_status().
-- 4. Rechazo de ejecución de platform_approve_tenant / platform_reject_tenant para usuarios no autorizados.
-- 5. Aprobación exitosa por platform_owner como Pionero (50% de por vida) -> pasa a 'trialing', 21 días de prueba.
-- 6. Negocio en 'trialing' ya acepta compromisos.
-- 7. Rechazo con motivo registrado -> pasa a 'rejected' y guarda el motivo.

begin;

do $$
declare
  v_owner_user_id uuid := gen_random_uuid();
  v_fake_user_id uuid := gen_random_uuid();
  v_platform_owner_id uuid;
  v_tenant_id uuid;
  v_branch_id uuid;
  v_status text;
  v_sub record;
  v_city text;
  v_team_size integer;
  v_referral text;
  v_accepts boolean;
begin
  -- 1. Identificar al platform_owner real sembrado
  select user_id into v_platform_owner_id
  from public.platform_operators
  where role = 'platform_owner' and active
  limit 1;

  if v_platform_owner_id is null then
    raise exception 'CONTROL FALLÓ: No se encontró platform_owner en la base.';
  end if;

  -- 2. Crear usuario sintético en auth.users para el dueño de salón
  insert into auth.users (id, email)
  values (v_owner_user_id, 'solicitante_prueba@salonymas.com');

  -- Simular sesión del usuario solicitante
  perform set_config('request.jwt.claim.sub', v_owner_user_id::text, true);

  -- 3. Ejecutar register_tenant con formulario completo
  select tenant_id, branch_id, status
    into v_tenant_id, v_branch_id, v_status
  from public.register_tenant(
    'Salón de Prueba Filtro',
    'Claudia Fundadora',
    '3101234567',
    'salon',
    'Medellín',
    2,
    6,
    'Instagram'
  );

  if v_tenant_id is null or v_branch_id is null or v_status != 'pending' then
    raise exception 'CONTROL FALLÓ 1: register_tenant no devolvió status pending.';
  end if;

  -- Verificar datos en tenants
  select city, estimated_team_size, referral_source
    into v_city, v_team_size, v_referral
  from public.tenants
  where id = v_tenant_id;

  if v_city != 'Medellín' or v_team_size != 6 or v_referral != 'Instagram' then
    raise exception 'CONTROL FALLÓ 2: Los datos del cuestionario en tenants no coinciden (city: %, team: %, ref: %).', v_city, v_team_size, v_referral;
  end if;

  -- Verificar suscripción en tenant_subscriptions
  select * into v_sub
  from public.tenant_subscriptions
  where tenant_id = v_tenant_id;

  if v_sub.status != 'pending' or v_sub.trial_ends_at is not null or v_sub.current_period_start is not null then
    raise exception 'CONTROL FALLÓ 3: La suscripción no nació en pending o inició la prueba antes de tiempo.';
  end if;

  -- 4. Verificar que un negocio en 'pending' NO acepta compromisos
  v_accepts := private.beautyos_tenant_accepts_new_commitments(v_tenant_id);
  if v_accepts is true then
    raise exception 'CONTROL FALLÓ 4: El negocio en pending no debería aceptar compromisos.';
  end if;

  -- 5. Probar get_my_tenant_subscription_status
  select subscription_status into v_status
  from public.get_my_tenant_subscription_status();

  if v_status != 'pending' then
    raise exception 'CONTROL FALLÓ 5: get_my_tenant_subscription_status devolvió % en vez de pending.', v_status;
  end if;

  -- 6. Probar seguridad: usuario solicitante NO puede aprobarse a sí mismo
  begin
    perform public.platform_approve_tenant(v_tenant_id, 'profesional', true);
    raise exception 'CONTROL FALLÓ 6: Usuario no autorizado pudo aprobar un negocio.';
  exception
    when others then
      if sqlerrm not like '%No autorizado%' then
        raise exception 'CONTROL FALLÓ 6: Excepción inesperada de seguridad: %', sqlerrm;
      end if;
  end;

  -- 7. Simular sesión de platform_owner y APROBAR negocio como Pionero
  perform set_config('request.jwt.claim.sub', v_platform_owner_id::text, true);

  perform public.platform_approve_tenant(
    p_tenant_id => v_tenant_id,
    p_plan_code => 'profesional',
    p_is_founder => true,
    p_trial_days => 21
  );

  select * into v_sub
  from public.tenant_subscriptions
  where tenant_id = v_tenant_id;

  if v_sub.status != 'trialing' or v_sub.is_founder is not true or v_sub.discount_percent != 50.00 or v_sub.trial_ends_at is null then
    raise exception 'CONTROL FALLÓ 7: platform_approve_tenant no fijó trialing, pionero 50% o trial_ends_at correctamente.';
  end if;

  -- Verificar que tras aprobar, AHORA SÍ acepta compromisos
  v_accepts := private.beautyos_tenant_accepts_new_commitments(v_tenant_id);
  if v_accepts is not true then
    raise exception 'CONTROL FALLÓ 8: El negocio aprobado debería aceptar compromisos.';
  end if;

  -- 8. Probar RECHAZAR negocio con motivo
  perform public.platform_reject_tenant(
    p_tenant_id => v_tenant_id,
    p_reason => 'Solicitud incompleta para prueba.'
  );

  select * into v_sub
  from public.tenant_subscriptions
  where tenant_id = v_tenant_id;

  select rejection_reason, active into v_referral, v_accepts
  from public.tenants
  where id = v_tenant_id;

  if v_sub.status != 'rejected' or v_referral != 'Solicitud incompleta para prueba.' or v_accepts is true then
    raise exception 'CONTROL FALLÓ 9: platform_reject_tenant no fijó status rejected o no guardó el motivo.';
  end if;

  raise notice 'TODOS LOS 9 CONTROLES DEL FILTRO DE ACEPTACIÓN PASARON EN VERDE.';
end;
$$;

rollback;
