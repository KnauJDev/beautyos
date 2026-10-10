-- CONTROL 250: Cerrar una sede sin borrar nada (paso 9.65, D-328, hallazgo CQ).
--
-- Que valida, transaccionalmente:
--   1. La sede principal no se cierra.
--   2. Con una cita próxima no se cierra; la lista de citas la ve el dueño
--      con el nombre de la clienta y la plataforma sin él.
--   3. Sin citas, el dueño la cierra: queda inactiva, su suscripción
--      `cancelled` y el rastro `sede_cerrada` escrito.
--   4. Cerrada: la app no la lista, la reserva en línea no la usa, y no se
--      cierra dos veces.
--   5. Su historial sigue: el Dashboard la cuenta, su reporte se puede pedir
--      y el reporte del negocio la suma y la marca `cerrada`.
--   6. El dueño la reabre: activa y como estaba (en mora), con su rastro.
--   7. La plataforma la cierra y la reabre: queda como estaba.
--   (6 y 7 cambiaron con D-329, el 10-oct: antes esperaban `pending` y
--   `active`; ahora una sede reabierta vuelve como estaba al cerrarse. Lo
--   nuevo lo prueba a fondo el CONTROL 251.)
--   8. Un administrador no la cierra, y sin sesión no se puede.
--
-- COMO SE EJECUTA (despues de aplicar 20261010100000_cerrar_una_sede_sin_borrar_nada_d328.sql)
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\250_test_cerrar_una_sede.sql"
--
-- TERMINA EN ROLLBACK.
--
-- Datos de prueba copiados de controles que ya pasaron (regla 25d): el
-- negocio, el dueño y la clienta con su cita del 248; la segunda sede del
-- 236; el operador de la plataforma del 247.

set client_encoding = 'UTF8';

begin;

do $ctrl$
declare
  v_plan      uuid;
  v_operador  uuid;
  v_tenant    uuid;
  v_principal uuid;
  v_sede      uuid;
  v_memb      uuid;
  v_dueno     uuid := gen_random_uuid();
  v_admin     uuid := gen_random_uuid();
  v_stylist   uuid;
  v_corte     uuid;
  v_ana       uuid;
  v_cita      uuid;
  v_n         integer;
  v_texto     text;
  v_capturo   boolean;
  v_error     text;
  r           record;
begin
  -- ---------------------------------------------------------------- fixtures
  select id into v_plan from public.plans where status = 'active' limit 1;
  if v_plan is null then
    raise exception 'FALLO: no hay ningun plan activo con el que probar';
  end if;
  select po.user_id into v_operador
  from public.platform_operators po
  where po.active and po.role = 'platform_owner'
  limit 1;
  if v_operador is null then
    raise exception 'FALLO: no hay ningun platform_owner activo con el que probar';
  end if;

  insert into auth.users (id, email) values
    (v_dueno, 'dueno_test250@salonymas.com'),
    (v_admin, 'admin_test250@salonymas.com')
  on conflict (id) do nothing;

  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 250', 'peluqueria', 'c250@salonymas.com', '3000000250', true)
  returning id into v_tenant;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_tenant, v_plan, 'active', now() + interval '30 days');

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C250 principal', 'c250-principal', true, true)
  returning id into v_principal;
  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C250 norte', 'c250-norte', false, true)
  returning id into v_sede;
  update public.branch_subscriptions set status = 'past_due' where branch_id = v_sede;

  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_dueno, 'tenant_owner', true)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values
    (v_tenant, v_principal, v_memb, true, now() - interval '1 day', v_dueno),
    (v_tenant, v_sede, v_memb, true, now() - interval '1 day', v_dueno);
  insert into public.user_profiles (tenant_id, user_id, full_name, role, active)
  values (v_tenant, v_dueno, 'C250 dueno', 'owner', true);

  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_admin, 'admin', true)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_sede, v_memb, true, now() - interval '1 day', v_dueno);

  insert into public.services (tenant_id, name, category, duration_minutes, price, visible_to_customer)
  values (v_tenant, 'C250 corte', 'Cabello', 30, 25000, true) returning id into v_corte;
  insert into public.branch_services (
    tenant_id, branch_id, service_id, price, duration_minutes, visible_to_customer, active
  ) values (v_tenant, v_sede, v_corte, 25000, 30, true, true);

  insert into public.stylists (tenant_id, name, phone, specialty)
  values (v_tenant, 'C250 estilista', '3000000251', 'Cortes')
  returning id into v_stylist;
  insert into public.branch_stylists (tenant_id, branch_id, stylist_id, active, starts_at)
  values (v_tenant, v_sede, v_stylist, true, now() - interval '1 day');

  insert into public.clients (tenant_id, name, phone, active)
  values (v_tenant, 'C250 Ana', '3010000501', true) returning id into v_ana;

  -- Una cita pasada (historial) y una próxima, las dos en la sede norte.
  insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at)
  values (v_tenant, v_sede, v_ana, 'cerrado', 'manual', now() - interval '10 days')
  returning id into v_cita;
  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant, v_sede, v_cita, v_corte, v_stylist, 25000, 30, 'finalizado');

  insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at)
  values (v_tenant, v_sede, v_ana, 'confirmado', 'manual', now() + interval '2 days')
  returning id into v_cita;
  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant, v_sede, v_cita, v_corte, v_stylist, 25000, 30, 'pendiente');

  -- ---------------------------------------------------------------- 1
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);
  v_capturo := false;
  begin
    perform public.close_branch(v_principal);
  exception when others then v_capturo := true; v_error := sqlerrm;
  end;
  if not v_capturo then
    raise exception 'FALLO 1: se cerro la sede principal';
  end if;
  raise notice 'OK 1   la sede principal no se cierra (%)', v_error;

  -- ---------------------------------------------------------------- 2
  v_capturo := false;
  begin
    perform public.close_branch(v_sede);
  exception when others then v_capturo := true; v_error := sqlerrm;
  end;
  if not v_capturo or v_error not like '%1 citas próximas%' then
    raise exception 'FALLO 2: con una cita proxima la respuesta fue % (%)', v_capturo, v_error;
  end if;
  select * into r from public.get_branch_upcoming_appointments(v_sede);
  if r.client_name is distinct from 'C250 Ana' or r.service_names is distinct from 'C250 corte' then
    raise exception 'FALLO 2b: el dueno vio la cita como % / %', r.client_name, r.service_names;
  end if;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_operador::text, 'role', 'authenticated')::text, true);
  select * into r from public.get_branch_upcoming_appointments(v_sede);
  if r.client_name is not null or r.service_names is distinct from 'C250 corte' then
    raise exception 'FALLO 2c: la plataforma vio la cita como % / %', r.client_name, r.service_names;
  end if;
  raise notice 'OK 2   con una cita proxima no se cierra (%); el dueno ve la clienta, la plataforma no', v_error;

  -- ---------------------------------------------------------------- 3
  update public.tickets set status = 'cancelado' where id = v_cita;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);
  perform public.close_branch(v_sede);

  if exists (select 1 from public.branches b where b.id = v_sede and b.active) then
    raise exception 'FALLO 3: la sede sigue activa despues de cerrarla';
  end if;
  select bs.status into v_texto from public.branch_subscriptions bs where bs.branch_id = v_sede;
  if v_texto is distinct from 'cancelled' then
    raise exception 'FALLO 3b: la suscripcion quedo en %', v_texto;
  end if;
  if not exists (
    select 1 from public.subscription_events e
    where e.tenant_id = v_tenant and e.event_type = 'sede_cerrada'
      and e.provider = 'tenant_owner' and e.payload ->> 'estado_anterior' = 'past_due'
  ) then
    raise exception 'FALLO 3c: no quedo el rastro sede_cerrada';
  end if;
  raise notice 'OK 3   el dueno la cierra: inactiva, cancelled, y el rastro escrito';

  -- ---------------------------------------------------------------- 4
  if exists (select 1 from public.get_my_branch_context_v2() c where c.branch_id = v_sede) then
    raise exception 'FALLO 4: la app sigue listando la sede cerrada';
  end if;
  v_capturo := false;
  begin
    perform 1 from public.public_get_branch_booking_info(v_sede);
  exception when others then v_capturo := true;
  end;
  if not v_capturo then
    raise exception 'FALLO 4b: la reserva en linea sigue usando la sede cerrada';
  end if;
  v_capturo := false;
  begin
    perform public.close_branch(v_sede);
  exception when others then v_capturo := true;
  end;
  if not v_capturo then
    raise exception 'FALLO 4c: se cerro dos veces';
  end if;
  raise notice 'OK 4   cerrada: la app no la lista, la reserva no la usa, y no se cierra dos veces';

  -- ---------------------------------------------------------------- 5
  if not exists (select 1 from private.beautyos_dashboard_branches(null) d where d.branch_id = v_sede) then
    raise exception 'FALLO 5: el Dashboard dejo de contar la sede cerrada';
  end if;
  perform 1 from public.get_branch_reports_v3(v_sede, (now() - interval '30 days')::date, now()::date);
  select * into r from public.get_tenant_reports_v3((now() - interval '30 days')::date, now()::date);
  if r.branches_count <> 2 or not exists (
    select 1 from jsonb_array_elements(r.by_branch) e
    where e ->> 'branch_id' = v_sede::text and (e ->> 'cerrada')::boolean
  ) then
    raise exception 'FALLO 5b: el reporte del negocio dio % sedes y %', r.branches_count, r.by_branch;
  end if;
  raise notice 'OK 5   su historial sigue: Dashboard, su reporte y el del negocio (marcada cerrada)';

  -- ---------------------------------------------------------------- 6
  perform public.reopen_branch(v_sede);
  select bs.status into v_texto from public.branch_subscriptions bs where bs.branch_id = v_sede;
  if not exists (select 1 from public.branches b where b.id = v_sede and b.active)
     or v_texto is distinct from 'past_due' then
    raise exception 'FALLO 6: al reabrirla el dueno quedo activa=% estado=%',
      exists (select 1 from public.branches b where b.id = v_sede and b.active), v_texto;
  end if;
  if not exists (
    select 1 from public.subscription_events e
    where e.tenant_id = v_tenant and e.event_type = 'sede_reabierta' and e.provider = 'tenant_owner'
  ) then
    raise exception 'FALLO 6b: no quedo el rastro sede_reabierta';
  end if;
  raise notice 'OK 6   el dueno la reabre: activa y como estaba (en mora), con su rastro';

  -- ---------------------------------------------------------------- 7
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_operador::text, 'role', 'authenticated')::text, true);
  perform public.platform_close_branch(v_sede);
  perform public.platform_reopen_branch(v_sede);
  select bs.status into v_texto from public.branch_subscriptions bs where bs.branch_id = v_sede;
  if v_texto is distinct from 'past_due'
     or not exists (select 1 from public.branches b where b.id = v_sede and b.active) then
    raise exception 'FALLO 7: tras cerrar y reabrir desde el Panel quedo %', v_texto;
  end if;
  raise notice 'OK 7   la plataforma la cierra y la reabre: queda como estaba';

  -- ---------------------------------------------------------------- 8
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_admin::text, 'role', 'authenticated')::text, true);
  v_capturo := false;
  begin
    perform public.close_branch(v_sede);
  exception when others then v_capturo := true;
  end;
  if not v_capturo then
    raise exception 'FALLO 8: un administrador cerro la sede';
  end if;

  v_capturo := false;
  begin
    perform set_config('request.jwt.claims', '{"role":"anon"}', true);
    execute 'set local role anon';
    perform public.close_branch(v_sede);
    execute 'reset role';
  exception when others then
    v_capturo := true; v_error := sqlerrm;
    execute 'reset role';
  end;
  if not v_capturo then
    raise exception 'FALLO 8b: sin sesion se pudo cerrar una sede';
  end if;
  raise notice 'OK 8   un administrador no la cierra, y sin sesion no se puede (%)', v_error;

  perform set_config('request.jwt.claims', '{}', true);
  raise notice '--- CONTROL 250: 8/8 ---';
end
$ctrl$;

rollback;
