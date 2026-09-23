-- CONTROL 227: Cada administrador ve y paga solo su sede; el dueno, todas.
--              Hallazgo BP (D-268, D-273).
--
-- POR QUE ESTE ARCHIVO
--
-- Hasta el 23-sep cualquier administrador veia en "Tus sedes" todas las sedes
-- del negocio, con sus precios, y el servidor le dejaba abrir el pago de
-- cualquiera. El propietario decidio: *el dueno ve todas y paga cualquiera;
-- cada administrador, solo la suya*.
--
-- Este control entra como cada persona -- dueno, administrador de una sede,
-- recepcion, el dueno de OTRO negocio y nadie -- y mira lo que ve y lo que
-- puede pagar cada una. Fixtures copiados de los controles 218 y 224, que ya
-- funcionan (regla 25 d).
--
-- Que valida, transaccionalmente:
--   1. El dueno ve las dos sedes y puede pagar las dos. Como antes.
--   2. El administrador de la sede A ve SOLO la A.
--   3. Y puede pagar la A, pero NO la B.
--   4. Recepcion no paga ninguna, y "Tus sedes" le sigue diciendo que no.
--   5. El dueno de otro negocio no puede pagar una sede ajena.
--   6. Sin sesion, nadie paga nada.
--
-- COMO SE EJECUTA (despues de aplicar 20260923210000_cada_administrador_su_sede_bp.sql)
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\227_test_cada_administrador_su_sede.sql"
--
-- TERMINA EN ROLLBACK.

begin;

do $ctrl$
declare
  v_plan       uuid;
  v_tenant     uuid;
  v_otro       uuid;
  v_sede_a     uuid;
  v_sede_b     uuid;
  v_dueno      uuid := gen_random_uuid();
  v_admin      uuid := gen_random_uuid();
  v_recepcion  uuid := gen_random_uuid();
  v_ajeno      uuid := gen_random_uuid();
  v_memb       uuid;
  v_cuantas    integer;
  v_la_suya    uuid;
  v_capturo    boolean;
  v_error      text;
begin
  select id into v_plan from public.plans where status = 'active' limit 1;
  if v_plan is null then
    raise exception 'FALLO: no hay ningun plan activo con el que probar';
  end if;

  insert into auth.users (id, email) values
    (v_dueno, 'dueno_test227@salonymas.com'),
    (v_admin, 'admin_test227@salonymas.com'),
    (v_recepcion, 'recepcion_test227@salonymas.com'),
    (v_ajeno, 'ajeno_test227@salonymas.com')
  on conflict (id) do nothing;

  -- El negocio, con dos sedes.
  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 227', 'peluqueria', 'c227@salonymas.com', '3000000231', true)
  returning id into v_tenant;
  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_tenant, v_plan, 'active', now() + interval '30 days');
  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C227 sede A', 'c227-sede-a', true, true)
  returning id into v_sede_a;
  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C227 sede B', 'c227-sede-b', false, true)
  returning id into v_sede_b;

  -- El dueno.
  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_dueno, 'tenant_owner', true);

  -- El administrador, asignado SOLO a la sede A.
  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_admin, 'admin', true)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_sede_a, v_memb, true, now() - interval '1 day', v_dueno);

  -- Recepcion, tambien en la sede A.
  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_recepcion, 'assistant', true)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_sede_a, v_memb, true, now() - interval '1 day', v_dueno);

  -- Otro negocio, con su dueno.
  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 227 otro', 'peluqueria', 'c227b@salonymas.com', '3000000232', true)
  returning id into v_otro;
  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_otro, v_plan, 'active', now() + interval '30 days');
  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_otro, v_ajeno, 'tenant_owner', true);

  -- 1. El dueno: las dos, y paga las dos
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);
  select count(*) into v_cuantas from public.get_branch_subscriptions();
  if v_cuantas <> 2 then
    raise exception 'FALLO 1: el dueno ve % sede(s) y tiene dos. Tenia que quedar como antes.', v_cuantas;
  end if;
  if not (public.beautyos_puedo_pagar_sede(v_sede_a) and public.beautyos_puedo_pagar_sede(v_sede_b)) then
    raise exception 'FALLO 1b: el dueno no puede pagar alguna de sus sedes.';
  end if;
  raise notice 'OK 1   el dueno ve sus dos sedes y puede pagar las dos, como antes';

  -- 2 y 3. El administrador de la A
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_admin::text, 'role', 'authenticated')::text, true);
  select count(*), min(s.branch_id::text)::uuid into v_cuantas, v_la_suya
  from public.get_branch_subscriptions() s;
  if v_cuantas <> 1 or v_la_suya is distinct from v_sede_a then
    raise exception 'FALLO 2: el administrador de la sede A ve % sede(s). Tiene que ver solo la suya.', v_cuantas;
  end if;
  raise notice 'OK 2   el administrador de la sede A ve solo la A';

  if not public.beautyos_puedo_pagar_sede(v_sede_a) then
    raise exception 'FALLO 3: el administrador no puede pagar su propia sede.';
  end if;
  if public.beautyos_puedo_pagar_sede(v_sede_b) then
    raise exception 'FALLO 3b: el administrador de la A puede pagar la B. Es lo que BP quita.';
  end if;
  raise notice 'OK 3   el administrador paga la suya, y no la otra';

  -- 4. Recepcion
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_recepcion::text, 'role', 'authenticated')::text, true);
  if public.beautyos_puedo_pagar_sede(v_sede_a) then
    raise exception 'FALLO 4: recepcion puede pagar una sede.';
  end if;
  v_capturo := false;
  begin
    perform 1 from public.get_branch_subscriptions();
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;
  if not v_capturo then
    raise exception 'FALLO 4b: recepcion ve el estado de pago de las sedes.';
  end if;
  raise notice 'OK 4   recepcion no paga ninguna sede, y Tus sedes le sigue diciendo que no';

  -- 5. El dueno de otro negocio
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_ajeno::text, 'role', 'authenticated')::text, true);
  if public.beautyos_puedo_pagar_sede(v_sede_a) then
    raise exception 'FALLO 5: el dueno de otro negocio puede pagar una sede ajena.';
  end if;
  raise notice 'OK 5   el dueno de otro negocio no puede pagar una sede ajena';

  -- 6. Sin sesion
  perform set_config('request.jwt.claims', '{}', true);
  if public.beautyos_puedo_pagar_sede(v_sede_a) then
    raise exception 'FALLO 6: sin sesion se puede pagar una sede.';
  end if;
  raise notice 'OK 6   sin sesion nadie paga nada';

  raise notice '--- CONTROL 227: 6/6 ---';
end
$ctrl$;

rollback;
