-- BeautyOS / Salón y Más - Control 169: Prueba de verificación de Blindaje RLS y Guards de Estado (D-139 / Auditoría Claude).
--
-- Ejecuta todos los escenarios en una transacción aislada terminada en ROLLBACK:
-- 1. Verificar que public.tenants y public.user_profiles tienen RLS habilitado (relrowsecurity = true).
-- 2. Registro de un negocio en 'pending'.
-- 3. Intento de rechazo a un negocio no existente o no pending.
-- 4. Aprobación exitosa por platform_owner -> pasa a 'trialing'.
-- 5. Intento de re-aprobar un negocio que ya está en 'trialing' -> debe ser rechazado por el Guard.
-- 6. Intento de rechazar un negocio que ya está en 'trialing' -> debe ser rechazado por el Guard.
-- 7. Rechazo de un segundo negocio en 'pending' -> pasa a 'rejected'.
-- 8. Re-aprobación exitosa desde 'rejected' a 'trialing' por intervención de soporte -> pasa exitosamente.

begin;

do $$
declare
  v_owner_user_id uuid := gen_random_uuid();
  v_owner2_user_id uuid := gen_random_uuid();
  v_platform_owner_id uuid;
  v_tenant_id uuid;
  v_tenant2_id uuid;
  v_branch_id uuid;
  v_branch2_id uuid;
  v_status text;
  v_rls_tenants boolean;
  v_rls_profiles boolean;
  v_error_caught boolean;
begin
  -- 1. Control 1: RLS habilitado en tenants y user_profiles
  select relrowsecurity into v_rls_tenants
  from pg_class
  where relname = 'tenants' and relnamespace = 'public'::regnamespace;

  if v_rls_tenants is not true then
    raise exception 'CONTROL FALLÓ 1: RLS no está activo en public.tenants.';
  end if;

  select relrowsecurity into v_rls_profiles
  from pg_class
  where relname = 'user_profiles' and relnamespace = 'public'::regnamespace;

  if v_rls_profiles is not true then
    raise exception 'CONTROL FALLÓ 1b: RLS no está activo en public.user_profiles.';
  end if;

  -- 2. Identificar platform_owner
  select user_id into v_platform_owner_id
  from public.platform_operators
  where role = 'platform_owner' and active
  limit 1;

  if v_platform_owner_id is null then
    raise exception 'CONTROL FALLÓ: No se encontró platform_owner en la base.';
  end if;

  -- 3. Crear usuario 1 y registrar negocio 1
  insert into auth.users (id, email)
  values (v_owner_user_id, 'dueña_blindaje1@salonymas.com');

  perform set_config('request.jwt.claim.sub', v_owner_user_id::text, true);

  select tenant_id, branch_id, status
    into v_tenant_id, v_branch_id, v_status
  from public.register_tenant(
    'Spa Blindaje Seguro',
    'Mariana Gómez',
    '3159998888',
    'spa',
    'Cali',
    1,
    3,
    'Recomendación'
  );

  if v_status != 'pending' then
    raise exception 'CONTROL FALLÓ 2: Negocio 1 no quedó en pending.';
  end if;

  -- 4. Control 2: Aprobar negocio 1 como platform_owner
  perform set_config('request.jwt.claim.sub', v_platform_owner_id::text, true);

  perform public.platform_approve_tenant(
    v_tenant_id,
    'profesional',
    21,
    true
  );

  select status into v_status
  from public.tenant_subscriptions
  where tenant_id = v_tenant_id;

  if v_status != 'trialing' then
    raise exception 'CONTROL FALLÓ 3: Negocio 1 no pasó a trialing tras aprobación.';
  end if;

  -- 5. Control 3: Guard contra re-aprobación accidental (ya está en trialing)
  v_error_caught := false;
  begin
    perform public.platform_approve_tenant(
      v_tenant_id,
      'profesional',
      21,
      false
    );
  rescue when others then
    v_error_caught := true;
  end;

  if not v_error_caught then
    raise exception 'CONTROL FALLÓ 4: Guard falló, permitió re-aprobar un tenant en trialing.';
  end if;

  -- 6. Control 4: Guard contra rechazo accidental a cliente en trialing
  v_error_caught := false;
  begin
    perform public.platform_reject_tenant(
      v_tenant_id,
      'Rechazo erróneo'
    );
  rescue when others then
    v_error_caught := true;
  end;

  if not v_error_caught then
    raise exception 'CONTROL FALLÓ 5: Guard falló, permitió rechazar un tenant en trialing.';
  end if;

  -- 7. Crear usuario 2 y registrar negocio 2
  insert into auth.users (id, email)
  values (v_owner2_user_id, 'dueña_blindaje2@salonymas.com');

  perform set_config('request.jwt.claim.sub', v_owner2_user_id::text, true);

  select tenant_id, branch_id, status
    into v_tenant2_id, v_branch2_id, v_status
  from public.register_tenant(
    'Barbería de Prueba 2',
    'Andrés Barbero',
    '3157776666',
    'barberia',
    'Bogotá',
    1,
    2,
    'Google'
  );

  -- 8. Control 5: Rechazar negocio 2
  perform set_config('request.jwt.claim.sub', v_platform_owner_id::text, true);

  perform public.platform_reject_tenant(
    v_tenant2_id,
    'Datos de contacto no verificables'
  );

  select status into v_status
  from public.tenant_subscriptions
  where tenant_id = v_tenant2_id;

  if v_status != 'rejected' then
    raise exception 'CONTROL FALLÓ 6: Negocio 2 no pasó a rejected.';
  end if;

  -- 9. Control 6: Re-aprobar negocio 2 tras corrección con soporte (desde 'rejected' a 'trialing')
  perform public.platform_approve_tenant(
    v_tenant2_id,
    'profesional',
    21,
    true
  );

  select status into v_status
  from public.tenant_subscriptions
  where tenant_id = v_tenant2_id;

  if v_status != 'trialing' then
    raise exception 'CONTROL FALLÓ 7: No permitió re-aprobar negocio desde estado rejected.';
  end if;

  raise notice 'TODOS LOS CONTROLES DE BLINDAJE RLS Y GUARDS DE ESTADO PASARON CON ÉXITO (D-139).';
end;
$$;

rollback;
