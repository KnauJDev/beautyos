-- BeautyOS - Tramo D3.5.3
-- Prueba de comportamiento contra el esquema sintetico de 132.
-- Requiere haber ejecutado 132 y tener el esquema real de la migracion
-- 20260722175530 ya aplicado (funciones get_my_tenant_id, get_my_role,
-- is_owner_or_admin, get_tenant_users, update_tenant_user_access,
-- create_client).

do $$
declare
  v_tenant_id uuid := gen_random_uuid();
  v_owner_id uuid := gen_random_uuid();
  v_admin_id uuid := gen_random_uuid();
  v_assistant_id uuid := gen_random_uuid();
  v_outsider_id uuid := gen_random_uuid();
  v_assistant_profile_id uuid;
  v_role text;
  v_client_count integer;
  v_membership_role text;
  v_membership_active boolean;
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at
  ) values
    ('00000000-0000-0000-0000-000000000000', v_owner_id, 'authenticated', 'authenticated',
     'owner@synth.test', crypt('x', gen_salt('bf')), now(), '{}', '{}', now(), now()),
    ('00000000-0000-0000-0000-000000000000', v_admin_id, 'authenticated', 'authenticated',
     'admin@synth.test', crypt('x', gen_salt('bf')), now(), '{}', '{}', now(), now()),
    ('00000000-0000-0000-0000-000000000000', v_assistant_id, 'authenticated', 'authenticated',
     'assistant@synth.test', crypt('x', gen_salt('bf')), now(), '{}', '{}', now(), now()),
    ('00000000-0000-0000-0000-000000000000', v_outsider_id, 'authenticated', 'authenticated',
     'outsider@synth.test', crypt('x', gen_salt('bf')), now(), '{}', '{}', now(), now());

  insert into public.tenants (id, name) values (v_tenant_id, 'Centro sintetico D3.5.3');

  insert into public.tenant_memberships (tenant_id, user_id, role, active, starts_at)
  values (v_tenant_id, v_owner_id, 'tenant_owner', true, now() - interval '30 days');

  insert into public.tenant_memberships (tenant_id, user_id, role, active, starts_at, ends_at)
  values (v_tenant_id, v_admin_id, 'admin', true, now() - interval '400 days', now() - interval '1 day');

  insert into public.user_profiles (id, tenant_id, user_id, full_name, role, active)
  values (gen_random_uuid(), v_tenant_id, v_admin_id, 'Admin Vencido', 'admin', true);

  insert into public.user_profiles (id, tenant_id, user_id, full_name, role, active)
  values (gen_random_uuid(), v_tenant_id, v_assistant_id, 'Asistente Nueva', 'assistant', true)
  returning id into v_assistant_profile_id;

  -- 1. get_my_tenant_id / get_my_role / is_owner_or_admin como owner vigente.
  perform set_config('request.jwt.claim.sub', v_owner_id::text, true);

  if public.get_my_tenant_id() is distinct from v_tenant_id then
    raise exception 'FALLA 1: get_my_tenant_id no devolvio el tenant del owner vigente.';
  end if;

  if public.get_my_role() is distinct from 'tenant_owner' then
    raise exception 'FALLA 2: get_my_role no devolvio tenant_owner.';
  end if;

  if public.is_owner_or_admin() is distinct from true then
    raise exception 'FALLA 3: is_owner_or_admin debio ser true para el owner.';
  end if;

  -- 2. Membresia con ends_at vencido no debe autorizar (endurecimiento
  --    nuevo: user_profiles nunca tuvo ventana de vigencia).
  perform set_config('request.jwt.claim.sub', v_admin_id::text, true);

  if public.get_my_tenant_id() is not null then
    raise exception 'FALLA 4: una membresia con ends_at vencido no debe autorizar.';
  end if;

  if public.is_owner_or_admin() is distinct from false then
    raise exception 'FALLA 5: is_owner_or_admin debio ser false con membresia vencida.';
  end if;

  -- 3. Outsider sin membresia no puede crear clientes (sin excepcion,
  --    simplemente cero filas, igual que el comportamiento original).
  perform set_config('request.jwt.claim.sub', v_outsider_id::text, true);
  select count(*) into v_client_count from public.create_client('Cliente fantasma', '3000000001');
  if v_client_count <> 0 then
    raise exception 'FALLA 6: un outsider sin membresia no debe poder crear clientes.';
  end if;

  -- 4. Owner vigente si puede crear clientes.
  perform set_config('request.jwt.claim.sub', v_owner_id::text, true);
  select count(*) into v_client_count from public.create_client('Cliente real', '3000000002');
  if v_client_count <> 1 then
    raise exception 'FALLA 7: el owner vigente debio poder crear exactamente un cliente.';
  end if;

  -- 5. Solo el propietario (no un admin) puede llamar get_tenant_users /
  --    update_tenant_user_access, aunque is_owner_or_admin() sea true.
  --    Reactivamos primero la membresia del admin para esta prueba de rol.
  update public.tenant_memberships
     set ends_at = null
   where tenant_id = v_tenant_id and user_id = v_admin_id;

  perform set_config('request.jwt.claim.sub', v_admin_id::text, true);

  begin
    perform public.get_tenant_users();
    raise exception 'FALLA 8: un admin no debio poder listar usuarios del tenant.';
  exception
    when others then
      if sqlerrm not like '%Solo el propietario%' then
        raise;
      end if;
  end;

  -- 6. El owner promueve a la asistente a admin: debe crear la membresia
  --    (antes no existia) sin tocar starts_at si ya existiera.
  perform set_config('request.jwt.claim.sub', v_owner_id::text, true);
  perform public.update_tenant_user_access(v_assistant_profile_id, 'admin', true);

  select role, active into v_membership_role, v_membership_active
  from public.tenant_memberships
  where tenant_id = v_tenant_id and user_id = v_assistant_id;

  if v_membership_role is distinct from 'admin' or v_membership_active is distinct from true then
    raise exception 'FALLA 9: update_tenant_user_access debio crear la membresia admin activa.';
  end if;

  -- 7. El owner degrada a la (ahora admin) a "client": la membresia se
  --    desactiva pero no se borra (no destruir historial de acceso).
  perform public.update_tenant_user_access(v_assistant_profile_id, 'client', true);

  select role, active into v_membership_role, v_membership_active
  from public.tenant_memberships
  where tenant_id = v_tenant_id and user_id = v_assistant_id;

  if v_membership_active is distinct from false then
    raise exception 'FALLA 10: degradar a client debio desactivar la membresia, no borrarla.';
  end if;

  if (select count(*) from public.tenant_memberships where tenant_id = v_tenant_id and user_id = v_assistant_id) <> 1 then
    raise exception 'FALLA 11: la membresia no debio duplicarse ni eliminarse.';
  end if;

  if (select count(*) from public.user_profile_access_history where target_user_id = v_assistant_id) <> 2 then
    raise exception 'FALLA 12: cada cambio de acceso debio quedar auditado en user_profile_access_history.';
  end if;

  raise notice 'Tramo D3.5.3: 12 de 12 verificaciones de contrato aprobadas.';
end;
$$;
