-- CONTROL 248: Cuándo vuelve cada clienta (paso 9.63, D-323).
--
-- POR QUÉ ESTE ARCHIVO
--
-- David lo explicó así: varias clientas se hacen el mismo servicio, pero no
-- todas vuelven con la misma frecuencia. Este control recorre el caso de Ana
-- (tinte y corte en la misma cita, hace 50 días) y comprueba quién puede y
-- quién no.
--
-- Que valida, transaccionalmente:
--   1. Al cerrar se pregunta lo de cada servicio: sin número propio, con el
--      del servicio (tinte 60) y el del salón (45).
--   2. Con el número de la clienta: el tinte de Ana NO tocaba (50 < 60); la
--      recepción le pone 20 al cerrar y ahora sí toca, con 20.
--   3. El interruptor apagado ("esta vez no") saca el corte de la lista y NO
--      borra su número (30, puesto antes en la ficha).
--   4. Cuando vuelve a hacerse el corte, la marca deja de valer sola: vuelve
--      a la lista con su número (30).
--   5. "Usar el del servicio" en la ficha le quita su número: vuelve el 45.
--   6. La estilista ve y responde SOLO sus servicios; no ve la ficha (D-266).
--   7. Un servicio sin terminar no se responde; fuera de rango se niega.
--   8. Sin sesión no se puede, y la tabla no se lee directo.
--
-- COMO SE EJECUTA (despues de aplicar 20261008200000_cuando_vuelve_cada_clienta_9_63.sql)
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\248_test_cuando_vuelve_cada_clienta.sql"
--
-- TERMINA EN ROLLBACK.
--
-- Datos de prueba copiados del control 242 (03-oct), que ya pasó (regla
-- 25d): el negocio, su sede, el dueño, la recepción, la estilista CON cuenta,
-- y las citas pasadas escritas directo en las tablas.

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
  v_stylist2    uuid;
  v_tinte       uuid;
  v_corte       uuid;
  v_ana         uuid;
  v_bea         uuid;
  v_ticket_ana  uuid;
  v_ticket_bea  uuid;
  v_ts_tinte    uuid;
  v_ts_corte    uuid;
  v_ts_bea      uuid;
  v_ticket      uuid;
  v_n           integer;
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
    (v_dueno, 'dueno_test248@salonymas.com'),
    (v_asistente, 'asistente_test248@salonymas.com'),
    (v_estilista_cuenta, 'estilista_test248@salonymas.com')
  on conflict (id) do nothing;

  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 248', 'peluqueria', 'c248@salonymas.com', '3000000248', true)
  returning id into v_tenant;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_tenant, v_plan, 'active', now() + interval '30 days');

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C248 sede', 'c248-sede', true, true)
  returning id into v_branch;

  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_dueno, 'tenant_owner', true)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);
  insert into public.user_profiles (tenant_id, user_id, full_name, role, active)
  values (v_tenant, v_dueno, 'C248 dueno', 'owner', true);

  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_asistente, 'assistant', true)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);

  insert into public.services (tenant_id, name, category, duration_minutes, price, visible_to_customer, return_after_days)
  values (v_tenant, 'C248 tinte', 'Cabello', 90, 120000, true, 60) returning id into v_tinte;
  insert into public.services (tenant_id, name, category, duration_minutes, price, visible_to_customer)
  values (v_tenant, 'C248 corte', 'Cabello', 30, 25000, true) returning id into v_corte;
  insert into public.branch_services (
    tenant_id, branch_id, service_id, price, duration_minutes, visible_to_customer, active
  ) values
    (v_tenant, v_branch, v_tinte, 120000, 90, true, true),
    (v_tenant, v_branch, v_corte, 25000, 30, true, true);

  -- La estilista con cuenta (hace el tinte) y otra sin cuenta (hace el corte).
  insert into public.stylists (tenant_id, name, phone, specialty)
  values (v_tenant, 'C248 estilista', '3000000249', 'Color')
  returning id into v_stylist;
  insert into public.branch_stylists (tenant_id, branch_id, stylist_id, active, starts_at)
  values (v_tenant, v_branch, v_stylist, true, now() - interval '1 day');
  insert into public.stylists (tenant_id, name, phone, specialty)
  values (v_tenant, 'C248 estilista dos', '3000000250', 'Cortes')
  returning id into v_stylist2;
  insert into public.branch_stylists (tenant_id, branch_id, stylist_id, active, starts_at)
  values (v_tenant, v_branch, v_stylist2, true, now() - interval '1 day');

  insert into public.tenant_memberships (tenant_id, user_id, role, active, stylist_id)
  values (v_tenant, v_estilista_cuenta, 'stylist', true, v_stylist)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);
  insert into public.user_profiles (tenant_id, user_id, full_name, role, active, stylist_id)
  values (v_tenant, v_estilista_cuenta, 'C248 estilista cuenta', 'stylist', true, v_stylist);

  insert into public.clients (tenant_id, name, phone, active)
  values (v_tenant, 'C248 Ana', '3010000481', true) returning id into v_ana;
  insert into public.clients (tenant_id, name, phone, active)
  values (v_tenant, 'C248 Bea', '3010000482', true) returning id into v_bea;

  -- Ana: tinte (la estilista con cuenta) y corte (la otra), hace 50 días,
  -- atendida sin cobrar (como David).
  insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at)
  values (v_tenant, v_branch, v_ana, 'cerrado', 'manual', now() - interval '50 days')
  returning id into v_ticket_ana;
  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant, v_branch, v_ticket_ana, v_tinte, v_stylist, 120000, 90, 'finalizado')
  returning id into v_ts_tinte;
  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant, v_branch, v_ticket_ana, v_corte, v_stylist2, 25000, 30, 'finalizado')
  returning id into v_ts_corte;

  -- Bea: un tinte que todavía está en proceso.
  insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at)
  values (v_tenant, v_branch, v_bea, 'en_proceso', 'manual', now() - interval '1 hour')
  returning id into v_ticket_bea;
  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant, v_branch, v_ticket_bea, v_tinte, v_stylist, 120000, 90, 'en_proceso')
  returning id into v_ts_bea;

  -- ---------------------------------------------------------------- 1
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);

  select count(*) into v_n
  from public.get_return_days_for_ticket(v_branch, v_ticket_ana) d
  where d.client_days is null and d.default_days = 45
    and ((d.service_id = v_tinte and d.service_days = 60)
      or (d.service_id = v_corte and d.service_days is null));
  if v_n <> 2 then
    raise exception 'FALLO 1: al cerrar no salen los dos servicios con el del servicio y el del salon (% de 2)', v_n;
  end if;
  raise notice 'OK 1   al cerrar se pregunta cada servicio: tinte 60 del servicio, corte 45 del salon';

  -- ---------------------------------------------------------------- 2
  if exists (select 1 from public.get_return_invitations(v_branch) x
             where x.client_id = v_ana and x.service_id = v_tinte) then
    raise exception 'FALLO 2: el tinte de Ana (50 dias, servicio 60) aparece antes de tiempo';
  end if;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_asistente::text, 'role', 'authenticated')::text, true);
  perform public.set_client_return_after_close(v_branch, v_ts_tinte, 20, true);

  select * into r from public.get_return_invitations(v_branch) x
  where x.client_id = v_ana and x.service_id = v_tinte;
  if r.return_days is distinct from 20 or not r.toca_hoy then
    raise exception 'FALLO 2b: con 20 dias de Ana, su tinte dio return_days=% toca_hoy=%', r.return_days, r.toca_hoy;
  end if;
  raise notice 'OK 2   la recepcion le pone 20 al tinte de Ana al cerrar y ahora toca, con 20';

  -- ---------------------------------------------------------------- 3
  -- Antes, en la ficha, el corte de Ana quedó en 30 (50 > 30: toca).
  perform public.set_client_return_days(v_branch, v_ana, v_corte, 30);
  if not exists (select 1 from public.get_return_invitations(v_branch) x
                 where x.client_id = v_ana and x.service_id = v_corte and x.return_days = 30) then
    raise exception 'FALLO 3: el corte de Ana con 30 de la ficha no aparece';
  end if;

  perform public.set_client_return_after_close(v_branch, v_ts_corte, null, false);
  if exists (select 1 from public.get_return_invitations(v_branch) x
             where x.client_id = v_ana and x.service_id = v_corte) then
    raise exception 'FALLO 3b: con "esta vez no", el corte de Ana sigue en la lista';
  end if;
  select * into r from public.get_client_return_days(v_branch, v_ana) f
  where f.service_id = v_corte;
  if r.client_days is distinct from 30 or not r.skipped then
    raise exception 'FALLO 3c: tras "esta vez no", la ficha dio client_days=% skipped=%', r.client_days, r.skipped;
  end if;
  if not exists (select 1 from public.get_return_invitations(v_branch) x
                 where x.client_id = v_ana and x.service_id = v_tinte) then
    raise exception 'FALLO 3d: apagar el corte saco tambien el tinte';
  end if;
  raise notice 'OK 3   "esta vez no" saca el corte, no borra su 30 y no toca el tinte';

  -- ---------------------------------------------------------------- 4
  insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at)
  values (v_tenant, v_branch, v_ana, 'cerrado', 'manual', now() - interval '40 days')
  returning id into v_ticket;
  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant, v_branch, v_ticket, v_corte, v_stylist2, 25000, 30, 'finalizado');

  if not exists (select 1 from public.get_return_invitations(v_branch) x
                 where x.client_id = v_ana and x.service_id = v_corte and x.return_days = 30) then
    raise exception 'FALLO 4: Ana volvio a hacerse el corte (hace 40, su 30) y no vuelve a la lista';
  end if;
  select * into r from public.get_client_return_days(v_branch, v_ana) f
  where f.service_id = v_corte;
  if r.skipped then
    raise exception 'FALLO 4b: la marca de "esta vez no" sigue valiendo despues de la cita nueva';
  end if;
  raise notice 'OK 4   al volver a hacerse el corte, la marca deja de valer sola y vuelve con su 30';

  -- ---------------------------------------------------------------- 5
  perform public.set_client_return_days(v_branch, v_ana, v_corte, null);
  if exists (select 1 from public.get_return_invitations(v_branch) x
             where x.client_id = v_ana and x.service_id = v_corte) then
    raise exception 'FALLO 5: con "Usar el del servicio" (45), el corte de hace 40 dias sigue en la lista';
  end if;
  select * into r from public.get_client_return_days(v_branch, v_ana) f
  where f.service_id = v_corte;
  if r.client_days is not null then
    raise exception 'FALLO 5b: "Usar el del servicio" no le quito su numero (%)', r.client_days;
  end if;
  raise notice 'OK 5   "Usar el del servicio" le quita su numero y vuelve el 45 del salon';

  -- ---------------------------------------------------------------- 6
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_estilista_cuenta::text, 'role', 'authenticated')::text, true);
  select count(*) into v_n from public.get_return_days_for_ticket(v_branch, v_ticket_ana);
  if v_n <> 1 or not exists (
    select 1 from public.get_return_days_for_ticket(v_branch, v_ticket_ana) d
    where d.service_id = v_tinte and d.client_days = 20
  ) then
    raise exception 'FALLO 6: la estilista no ve solo su tinte (con el 20 de Ana) al cerrar (% filas)', v_n;
  end if;
  perform public.set_client_return_after_close(v_branch, v_ts_tinte, 25, true);

  v_capturo := false;
  begin
    perform public.set_client_return_after_close(v_branch, v_ts_corte, 15, true);
  exception when others then v_capturo := true;
  end;
  if not v_capturo then
    raise exception 'FALLO 6b: la estilista respondio el corte de otra estilista';
  end if;
  v_capturo := false;
  begin
    perform 1 from public.get_client_return_days(v_branch, v_ana);
  exception when others then v_capturo := true;
  end;
  if not v_capturo then
    raise exception 'FALLO 6c: la estilista pudo ver la ficha de la clienta';
  end if;
  v_capturo := false;
  begin
    perform public.set_client_return_days(v_branch, v_ana, v_tinte, 10);
  exception when others then v_capturo := true;
  end;
  if not v_capturo then
    raise exception 'FALLO 6d: la estilista pudo cambiar la ficha de la clienta';
  end if;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);
  select * into r from public.get_client_return_days(v_branch, v_ana) f
  where f.service_id = v_tinte;
  if r.client_days is distinct from 25 then
    raise exception 'FALLO 6e: lo que puso la estilista (25) no quedo en la ficha (%)', r.client_days;
  end if;
  raise notice 'OK 6   la estilista ve y responde solo sus servicios (25 quedo), y no ve la ficha (D-266)';

  -- ---------------------------------------------------------------- 7
  v_capturo := false;
  begin
    perform public.set_client_return_after_close(v_branch, v_ts_bea, 30, true);
  exception when others then v_capturo := true; v_error := sqlerrm;
  end;
  if not v_capturo then
    raise exception 'FALLO 7: se respondio un servicio que no se ha terminado';
  end if;
  v_capturo := false;
  begin
    perform public.set_client_return_after_close(v_branch, v_ts_tinte, 0, true);
  exception when others then v_capturo := true;
  end;
  if not v_capturo then
    raise exception 'FALLO 7b: se acepto un tiempo de volver de 0 dias al cerrar';
  end if;
  v_capturo := false;
  begin
    perform public.set_client_return_days(v_branch, v_ana, v_tinte, 400);
  exception when others then v_capturo := true;
  end;
  if not v_capturo then
    raise exception 'FALLO 7c: se acepto un tiempo de volver de 400 dias en la ficha';
  end if;
  raise notice 'OK 7   sin terminar no se responde (%); fuera de rango se niega', v_error;

  -- ---------------------------------------------------------------- 8
  v_capturo := false;
  begin
    perform set_config('request.jwt.claims', '{"role":"anon"}', true);
    execute 'set local role anon';
    perform 1 from public.get_return_days_for_ticket(v_branch, v_ticket_ana);
    execute 'reset role';
  exception when others then
    v_capturo := true; v_error := sqlerrm;
    execute 'reset role';
  end;
  if not v_capturo then
    raise exception 'FALLO 8: sin sesion se pudo pedir lo de cerrar';
  end if;

  v_capturo := false;
  begin
    perform set_config('request.jwt.claims',
      json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    select count(*) into v_n from public.client_service_return_days;
    execute 'reset role';
  exception when others then
    v_capturo := true; v_error := sqlerrm;
    execute 'reset role';
  end;
  if not v_capturo then
    raise exception 'FALLO 8b: con sesion se leyo la tabla directamente (% filas)', v_n;
  end if;
  raise notice 'OK 8   sin sesion no se puede, y la tabla no se lee directo (%)', v_error;

  perform set_config('request.jwt.claims', '{}', true);
  raise notice '--- CONTROL 248: 8/8 ---';
end
$ctrl$;

rollback;
