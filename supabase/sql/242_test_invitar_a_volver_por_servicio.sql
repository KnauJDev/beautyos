-- CONTROL 242: Invitar a volver, por servicio (D-314, paso 4B).
--
-- POR QUÉ ESTE ARCHIVO
--
-- El propietario lo explicó con un ejemplo: una clienta se hace un rubber en
-- las uñas (20 días) y un tinte (60 días). Invitarla por el rubber no puede
-- borrar el recordatorio del tinte. Este control recorre ese caso y los que
-- salen de él, y comprueba quién puede y quién no.
--
-- Que valida, transaccionalmente:
--   1. El negocio nace con 45 días por defecto; cada servicio puede tener el
--      suyo (1 a 365), y fuera de rango se niega.
--   2. La lista: el rubber de Ana toca (25 días > 20); su tinte NO (25 < 60);
--      el corte de Bea toca por el valor del salón (50 > 45); el rubber de
--      Cata NO, porque ya tiene una cita próxima con ese servicio.
--   3. Invitar a Ana por el rubber (la recepción puede): queda "invitada sin
--      volver", con 1 invitación, y no toca hoy. **El tinte sigue aparte.**
--   4. Pasado otra vez el tiempo del servicio, la invitada vuelve a tocar.
--   5. Si Ana vuelve a hacerse el rubber, sale de la lista.
--   6. Cambiar el valor del salón a 60 saca a Bea; fuera de rango se niega.
--   7. La estilista NO puede ver la lista ni invitar (D-266).
--   8. Sin sesión no se puede, y la tabla de invitaciones no se lee directo.
--
-- COMO SE EJECUTA (despues de aplicar 20261003200000_invitar_a_volver_por_servicio_d314.sql)
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\242_test_invitar_a_volver_por_servicio.sql"
--
-- TERMINA EN ROLLBACK.
--
-- Datos de prueba copiados del control 235 (29-sep), que ya pasó (regla
-- 25d): el negocio, su sede, el dueño, la recepción, la estilista CON cuenta,
-- y las citas pasadas escritas directo en las tablas. El cambio de rol, del
-- 231 (30-sep).

set client_encoding = 'UTF8';

begin;

do $ctrl$
declare
  v_plan        uuid;
  v_tenant      uuid;
  v_branch      uuid;
  v_memb        uuid;
  v_dueno       uuid := gen_random_uuid();
  v_asistente   uuid := gen_random_uuid();
  v_estilista_cuenta uuid := gen_random_uuid();
  v_stylist     uuid;
  v_rubber      uuid;
  v_tinte       uuid;
  v_corte       uuid;
  v_ana         uuid;
  v_bea         uuid;
  v_cata        uuid;
  v_ticket      uuid;
  v_n           integer;
  v_at          timestamptz;
  v_capturo     boolean;
  v_error       text;
  r             record;
begin
  -- ---------------------------------------------------------------- fixtures
  select id into v_plan from public.plans where status = 'active' limit 1;
  if v_plan is null then
    raise exception 'FALLO: no hay ningun plan activo con el que probar';
  end if;

  insert into auth.users (id, email) values
    (v_dueno, 'dueno_test242@salonymas.com'),
    (v_asistente, 'asistente_test242@salonymas.com'),
    (v_estilista_cuenta, 'estilista_test242@salonymas.com')
  on conflict (id) do nothing;

  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 242', 'peluqueria', 'c242@salonymas.com', '3000000242', true)
  returning id into v_tenant;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_tenant, v_plan, 'active', now() + interval '30 days');

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C242 sede', 'c242-sede', true, true)
  returning id into v_branch;

  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_dueno, 'tenant_owner', true)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);
  insert into public.user_profiles (tenant_id, user_id, full_name, role, active)
  values (v_tenant, v_dueno, 'C242 dueno', 'owner', true);

  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_asistente, 'assistant', true)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);

  insert into public.services (tenant_id, name, category, duration_minutes, price, visible_to_customer)
  values (v_tenant, 'C242 rubber', 'Unas', 60, 40000, true) returning id into v_rubber;
  insert into public.services (tenant_id, name, category, duration_minutes, price, visible_to_customer)
  values (v_tenant, 'C242 tinte', 'Cabello', 90, 120000, true) returning id into v_tinte;
  insert into public.services (tenant_id, name, category, duration_minutes, price, visible_to_customer)
  values (v_tenant, 'C242 corte', 'Cabello', 30, 25000, true) returning id into v_corte;
  insert into public.branch_services (
    tenant_id, branch_id, service_id, price, duration_minutes, visible_to_customer, active
  ) values
    (v_tenant, v_branch, v_rubber, 40000, 60, true, true),
    (v_tenant, v_branch, v_tinte, 120000, 90, true, true),
    (v_tenant, v_branch, v_corte, 25000, 30, true, true);

  insert into public.stylists (tenant_id, name, phone, specialty)
  values (v_tenant, 'C242 estilista', '3000000243', 'Todo')
  returning id into v_stylist;
  insert into public.branch_stylists (tenant_id, branch_id, stylist_id, active, starts_at)
  values (v_tenant, v_branch, v_stylist, true, now() - interval '1 day');

  insert into public.tenant_memberships (tenant_id, user_id, role, active, stylist_id)
  values (v_tenant, v_estilista_cuenta, 'stylist', true, v_stylist)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);
  insert into public.user_profiles (tenant_id, user_id, full_name, role, active, stylist_id)
  values (v_tenant, v_estilista_cuenta, 'C242 estilista cuenta', 'stylist', true, v_stylist);

  insert into public.clients (tenant_id, name, phone, active)
  values (v_tenant, 'C242 Ana', '3010000421', true) returning id into v_ana;
  insert into public.clients (tenant_id, name, phone, active)
  values (v_tenant, 'C242 Bea', '3010000422', true) returning id into v_bea;
  insert into public.clients (tenant_id, name, phone, active)
  values (v_tenant, 'C242 Cata', '3010000423', true) returning id into v_cata;

  -- Ana: rubber y tinte, hace 25 días, atendida sin cobrar (como David).
  insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at)
  values (v_tenant, v_branch, v_ana, 'finalizado', 'manual', now() - interval '25 days')
  returning id into v_ticket;
  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values
    (v_tenant, v_branch, v_ticket, v_rubber, v_stylist, 40000, 60, 'finalizado'),
    (v_tenant, v_branch, v_ticket, v_tinte, v_stylist, 120000, 90, 'finalizado');

  -- Bea: corte hace 50 días (el corte no tiene tiempo propio: manda el salón).
  insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at)
  values (v_tenant, v_branch, v_bea, 'cerrado', 'manual', now() - interval '50 days')
  returning id into v_ticket;
  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant, v_branch, v_ticket, v_corte, v_stylist, 25000, 30, 'finalizado');

  -- Cata: rubber hace 25 días, y ya tiene otro rubber agendado para dentro de 3.
  insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at)
  values (v_tenant, v_branch, v_cata, 'finalizado', 'manual', now() - interval '25 days')
  returning id into v_ticket;
  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant, v_branch, v_ticket, v_rubber, v_stylist, 40000, 60, 'finalizado');
  insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at)
  values (v_tenant, v_branch, v_cata, 'confirmado', 'manual', now() + interval '3 days')
  returning id into v_ticket;
  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant, v_branch, v_ticket, v_rubber, v_stylist, 40000, 60, 'pendiente');

  -- ---------------------------------------------------------------- 1
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);

  select count(*) into v_n
  from public.get_return_days(v_branch) d
  where d.default_days = 45 and d.return_after_days is null;
  if v_n <> 3 then
    raise exception 'FALLO 1: el negocio no nacio con 45 por defecto y servicios sin tiempo propio (% de 3)', v_n;
  end if;

  perform public.set_service_return_days(v_branch, v_rubber, 20);
  perform public.set_service_return_days(v_branch, v_tinte, 60);

  v_capturo := false;
  begin
    perform public.set_service_return_days(v_branch, v_corte, 0);
  exception when others then v_capturo := true;
  end;
  if not v_capturo then
    raise exception 'FALLO 1b: se acepto un tiempo de volver de 0 dias';
  end if;
  raise notice 'OK 1   45 dias por defecto; rubber 20 y tinte 60; fuera de rango se niega';

  -- ---------------------------------------------------------------- 2
  select count(*) into v_n
  from public.get_return_invitations(v_branch) x
  where x.client_id = v_ana and x.service_id = v_rubber
    and x.estado = 'por_invitar' and x.toca_hoy and x.return_days = 20;
  if v_n <> 1 then
    raise exception 'FALLO 2: el rubber de Ana (25 dias, tiempo 20) no aparece por invitar';
  end if;
  if exists (select 1 from public.get_return_invitations(v_branch) x
             where x.client_id = v_ana and x.service_id = v_tinte) then
    raise exception 'FALLO 2b: el tinte de Ana (25 dias, tiempo 60) aparece antes de tiempo';
  end if;
  if not exists (select 1 from public.get_return_invitations(v_branch) x
                 where x.client_id = v_bea and x.service_id = v_corte
                   and x.return_days = 45 and x.toca_hoy) then
    raise exception 'FALLO 2c: el corte de Bea (50 dias, valor del salon 45) no aparece';
  end if;
  if exists (select 1 from public.get_return_invitations(v_branch) x
             where x.client_id = v_cata) then
    raise exception 'FALLO 2d: Cata ya tiene un rubber agendado y se le sugiere invitar';
  end if;
  raise notice 'OK 2   toca el rubber de Ana y el corte de Bea; ni el tinte de Ana ni Cata, que ya agendo';

  -- ---------------------------------------------------------------- 3
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_asistente::text, 'role', 'authenticated')::text, true);
  v_at := public.register_return_invitation(v_branch, v_ana, v_rubber);
  if v_at is null then
    raise exception 'FALLO 3: la recepcion no pudo registrar la invitacion';
  end if;

  select * into r from public.get_return_invitations(v_branch) x
  where x.client_id = v_ana and x.service_id = v_rubber;
  if r.estado <> 'invitada_sin_volver' or r.times_invited <> 1 or r.toca_hoy then
    raise exception 'FALLO 3b: tras invitar, el rubber de Ana dio estado=% veces=% toca_hoy=%', r.estado, r.times_invited, r.toca_hoy;
  end if;
  if exists (select 1 from public.get_return_invitations(v_branch) x
             where x.client_id = v_ana and x.service_id = v_tinte) then
    raise exception 'FALLO 3c: invitar por el rubber movio el tinte';
  end if;
  raise notice 'OK 3   la recepcion invita; el rubber queda "invitada sin volver" (1) y el tinte sigue aparte';

  -- ---------------------------------------------------------------- 4
  update public.client_return_invitations
     set invited_at = now() - interval '21 days'
   where tenant_id = v_tenant and client_id = v_ana and service_id = v_rubber;
  select * into r from public.get_return_invitations(v_branch) x
  where x.client_id = v_ana and x.service_id = v_rubber;
  if not r.toca_hoy or r.estado <> 'invitada_sin_volver' then
    raise exception 'FALLO 4: pasados 21 dias de la invitacion (tiempo 20), no vuelve a tocar';
  end if;
  raise notice 'OK 4   pasado otra vez el tiempo del servicio, la invitada vuelve a tocar';

  -- ---------------------------------------------------------------- 5
  insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at)
  values (v_tenant, v_branch, v_ana, 'finalizado', 'manual', now() - interval '1 day')
  returning id into v_ticket;
  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant, v_branch, v_ticket, v_rubber, v_stylist, 40000, 60, 'finalizado');
  if exists (select 1 from public.get_return_invitations(v_branch) x
             where x.client_id = v_ana and x.service_id = v_rubber) then
    raise exception 'FALLO 5: Ana volvio a hacerse el rubber y sigue en la lista';
  end if;
  raise notice 'OK 5   si vuelve a hacerse el servicio, sale de la lista';

  -- ---------------------------------------------------------------- 6
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);
  perform public.set_return_default_days(v_branch, 60);
  if exists (select 1 from public.get_return_invitations(v_branch) x
             where x.client_id = v_bea) then
    raise exception 'FALLO 6: con 60 por defecto, el corte de Bea (50 dias) sigue en la lista';
  end if;
  v_capturo := false;
  begin
    perform public.set_return_default_days(v_branch, 400);
  exception when others then v_capturo := true;
  end;
  if not v_capturo then
    raise exception 'FALLO 6b: se acepto un valor del salon de 400 dias';
  end if;
  raise notice 'OK 6   el valor del salon manda en los servicios sin tiempo propio; fuera de rango se niega';

  -- ---------------------------------------------------------------- 7
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_estilista_cuenta::text, 'role', 'authenticated')::text, true);
  v_capturo := false;
  begin
    perform 1 from public.get_return_invitations(v_branch);
  exception when others then v_capturo := true;
  end;
  if not v_capturo then
    raise exception 'FALLO 7: la estilista pudo ver la lista de clientas para invitar';
  end if;
  v_capturo := false;
  begin
    perform public.register_return_invitation(v_branch, v_bea, v_corte);
  exception when others then v_capturo := true;
  end;
  if not v_capturo then
    raise exception 'FALLO 7b: la estilista pudo registrar una invitacion';
  end if;
  raise notice 'OK 7   la estilista no ve la lista ni invita (D-266)';

  -- ---------------------------------------------------------------- 8
  v_capturo := false;
  begin
    perform set_config('request.jwt.claims', '{"role":"anon"}', true);
    execute 'set local role anon';
    perform 1 from public.get_return_invitations(v_branch);
    execute 'reset role';
  exception when others then
    v_capturo := true; v_error := sqlerrm;
    execute 'reset role';
  end;
  if not v_capturo then
    raise exception 'FALLO 8: sin sesion se pudo pedir la lista';
  end if;

  v_capturo := false;
  begin
    perform set_config('request.jwt.claims',
      json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    select count(*) into v_n from public.client_return_invitations;
    execute 'reset role';
  exception when others then
    v_capturo := true; v_error := sqlerrm;
    execute 'reset role';
  end;
  if not v_capturo then
    raise exception 'FALLO 8b: con sesion se leyo la tabla de invitaciones directamente (% filas)', v_n;
  end if;
  raise notice 'OK 8   sin sesion no se puede, y la tabla no se lee directo (%)', v_error;

  perform set_config('request.jwt.claims', '{}', true);
  raise notice '--- CONTROL 242: 8/8 ---';
end
$ctrl$;

rollback;
