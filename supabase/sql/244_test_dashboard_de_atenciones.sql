-- CONTROL 244: el Dashboard de atenciones y su interruptor propio (D-317,
-- paso 5 del plan de David).
--
-- Que valida, transaccionalmente, con un negocio de prueba y una semana de
-- citas escritas a mano (hoy, en la hora de Bogota):
--   1. La capacidad `dashboard` existe, encendida en todos los planes, y un
--      negocio la recibe del plan.
--   2. Sin filtros: 3 atendidas (cerrado y finalizado cuentan), 2 clientas,
--      1 nueva, 1 cancelada, 1 que no llego, 1 en linea, 165 minutos; el
--      periodo anterior, 1 atendida y 45 minutos.
--   3. La serie: 7 dias con 3 atendidas; la anterior, 1.
--   4. El mapa de calor pone cada cita en su dia y su hora.
--   5. Servicios y equipo: corte 1, unas 2; Paola 1 cita con 5 estrellas
--      (la resena de una cita del periodo anterior NO cuenta); Juliana 2 y
--      120 minutos.
--   6. Filtrar por estilista: solo sus citas y sus minutos; la lista de
--      servicios se filtra, la del equipo no.
--   7. Filtrar por servicio: al reves.
--   8. Hoy, Invitar a volver y lo perdido: hoy 2 citas (1 en proceso, 1 por
--      atender); 2 invitaciones y 1 agendo despues; los 2 motivos, el mas
--      reciente primero, tal cual se escribieron.
--   9. El Panel puede apagarle el Dashboard a un negocio.
--  10. La estilista no lo ve, sin sesion no se puede, y un rango al reves se
--      niega.
--
-- COMO SE EJECUTA (despues de aplicar 20261004100000_dashboard_de_atenciones_paso5.sql)
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\244_test_dashboard_de_atenciones.sql"
--
-- TERMINA EN ROLLBACK.
--
-- Datos de prueba copiados del control 242 (03-oct), que ya paso (regla 25d):
-- el negocio, su sede, el dueno, la estilista con cuenta, los servicios y las
-- citas escritas directo en las tablas; el cambio de rol para "sin sesion",
-- tambien del 242. La resena, del 232; el historial, del 108; la excepcion
-- del Panel, del 206.

set client_encoding = 'UTF8';

begin;

do $ctrl$
declare
  v_plan        uuid;
  v_tenant      uuid;
  v_branch      uuid;
  v_memb        uuid;
  v_dueno       uuid := gen_random_uuid();
  v_estilista_cuenta uuid := gen_random_uuid();
  v_paola       uuid;
  v_juliana     uuid;
  v_corte       uuid;
  v_unas        uuid;
  v_ana         uuid;
  v_bea         uuid;
  v_cata        uuid;
  v_t           uuid;
  v_p1          uuid;
  v_t1          uuid;
  v_t4          uuid;
  v_t5          uuid;
  v_feature     uuid;
  v_hoy         date := (now() at time zone 'America/Bogota')::date;
  v_d           jsonb;
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
    (v_dueno, 'dueno_test244@salonymas.com'),
    (v_estilista_cuenta, 'estilista_test244@salonymas.com')
  on conflict (id) do nothing;

  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 244', 'peluqueria', 'c244@salonymas.com', '3000000244', true)
  returning id into v_tenant;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_tenant, v_plan, 'active', now() + interval '30 days');

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C244 sede', 'c244-sede', true, true)
  returning id into v_branch;

  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_dueno, 'tenant_owner', true)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);
  insert into public.user_profiles (tenant_id, user_id, full_name, role, active)
  values (v_tenant, v_dueno, 'C244 dueno', 'owner', true);

  insert into public.services (tenant_id, name, category, duration_minutes, price, visible_to_customer)
  values (v_tenant, 'C244 corte', 'Cabello', 45, 30000, true) returning id into v_corte;
  insert into public.services (tenant_id, name, category, duration_minutes, price, visible_to_customer)
  values (v_tenant, 'C244 unas', 'Unas', 60, 40000, true) returning id into v_unas;
  insert into public.branch_services (
    tenant_id, branch_id, service_id, price, duration_minutes, visible_to_customer, active
  ) values
    (v_tenant, v_branch, v_corte, 30000, 45, true, true),
    (v_tenant, v_branch, v_unas, 40000, 60, true, true);

  insert into public.stylists (tenant_id, name, phone, specialty)
  values (v_tenant, 'C244 Paola', '3000000245', 'Cabello') returning id into v_paola;
  insert into public.stylists (tenant_id, name, phone, specialty)
  values (v_tenant, 'C244 Juliana', '3000000246', 'Unas') returning id into v_juliana;
  insert into public.branch_stylists (tenant_id, branch_id, stylist_id, active, starts_at)
  values
    (v_tenant, v_branch, v_paola, true, now() - interval '1 day'),
    (v_tenant, v_branch, v_juliana, true, now() - interval '1 day');

  insert into public.tenant_memberships (tenant_id, user_id, role, active, stylist_id)
  values (v_tenant, v_estilista_cuenta, 'stylist', true, v_paola)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);
  insert into public.user_profiles (tenant_id, user_id, full_name, role, active, stylist_id)
  values (v_tenant, v_estilista_cuenta, 'C244 estilista cuenta', 'stylist', true, v_paola);

  insert into public.clients (tenant_id, name, phone, active)
  values (v_tenant, 'C244 Ana', '3010000441', true) returning id into v_ana;
  insert into public.clients (tenant_id, name, phone, active)
  values (v_tenant, 'C244 Bea', '3010000442', true) returning id into v_bea;
  insert into public.clients (tenant_id, name, phone, active)
  values (v_tenant, 'C244 Cata', '3010000443', true) returning id into v_cata;

  -- Periodo anterior: Ana, su primera visita (hace 10 dias), corte con Paola.
  insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at)
  values (v_tenant, v_branch, v_ana, 'cerrado', 'manual',
          ((v_hoy - 10) + time '10:00') at time zone 'America/Bogota')
  returning id into v_p1;
  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant, v_branch, v_p1, v_corte, v_paola, 30000, 45, 'finalizado');

  -- T1: Ana vuelve (hace 2 dias, 10 a. m.), en linea, corte con Paola.
  insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at)
  values (v_tenant, v_branch, v_ana, 'cerrado', 'web_publico',
          ((v_hoy - 2) + time '10:00') at time zone 'America/Bogota')
  returning id into v_t1;
  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant, v_branch, v_t1, v_corte, v_paola, 30000, 45, 'finalizado');

  -- T2: Bea, nueva (ayer, 3 p. m.), unas con Juliana.
  insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at)
  values (v_tenant, v_branch, v_bea, 'cerrado', 'manual',
          ((v_hoy - 1) + time '15:00') at time zone 'America/Bogota')
  returning id into v_t;
  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant, v_branch, v_t, v_unas, v_juliana, 40000, 60, 'finalizado');

  -- T3: Ana (hace 3 dias, 10 a. m.), atendida y por cobrar: 'finalizado' tambien cuenta.
  insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at)
  values (v_tenant, v_branch, v_ana, 'finalizado', 'manual',
          ((v_hoy - 3) + time '10:00') at time zone 'America/Bogota')
  returning id into v_t;
  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant, v_branch, v_t, v_unas, v_juliana, 40000, 60, 'finalizado');

  -- T4: Cata cancelo (hace 4 dias), habia llegado en linea, corte con Paola.
  -- T5: Cata no llego (hace 5 dias), unas con Juliana. Las dos se agendaron
  -- hace 6 dias, ANTES de invitarla.
  insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at, created_at)
  values (v_tenant, v_branch, v_cata, 'cancelado', 'web_publico',
          ((v_hoy - 4) + time '11:00') at time zone 'America/Bogota', now() - interval '6 days')
  returning id into v_t4;
  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant, v_branch, v_t4, v_corte, v_paola, 30000, 45, 'cancelado');
  insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at, created_at)
  values (v_tenant, v_branch, v_cata, 'no_asistio', 'manual',
          ((v_hoy - 5) + time '09:00') at time zone 'America/Bogota', now() - interval '6 days')
  returning id into v_t5;
  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant, v_branch, v_t5, v_unas, v_juliana, 40000, 60, 'cancelado');

  insert into public.ticket_history (tenant_id, branch_id, ticket_id, event_type, previous_status, new_status, reason, created_by, created_at)
  values
    (v_tenant, v_branch, v_t4, 'status_changed', 'confirmado', 'cancelado', 'C244 aviso que no podia venir', v_dueno, now() - interval '4 days'),
    (v_tenant, v_branch, v_t5, 'status_changed', 'confirmado', 'no_asistio', 'C244 no llego', v_dueno, now() - interval '5 days');

  -- Hoy: Ana confirmada (Paola) y Bea en proceso (Juliana).
  insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at)
  values (v_tenant, v_branch, v_ana, 'confirmado', 'manual',
          (v_hoy + time '12:00') at time zone 'America/Bogota')
  returning id into v_t;
  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant, v_branch, v_t, v_corte, v_paola, 30000, 45, 'pendiente');
  insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at)
  values (v_tenant, v_branch, v_bea, 'en_proceso', 'manual',
          (v_hoy + time '12:00') at time zone 'America/Bogota')
  returning id into v_t;
  insert into public.ticket_services (tenant_id, branch_id, ticket_id, service_id, stylist_id, price, duration_minutes, status)
  values (v_tenant, v_branch, v_t, v_unas, v_juliana, 40000, 60, 'en_proceso');

  -- Resenas: 5 estrellas a Paola por T1 (cuenta); 3 por la cita del periodo
  -- anterior (NO cuenta en este periodo).
  insert into public.reviews (tenant_id, branch_id, ticket_id, client_id, stylist_id, rating, comment, moderation_status, visible_to_public, active)
  values
    (v_tenant, v_branch, v_t1, v_ana, v_paola, 5, 'C244 resena actual', 'approved', true, true),
    (v_tenant, v_branch, v_p1, v_ana, v_paola, 3, 'C244 resena anterior', 'pending', false, true);

  -- Invitar a volver: Ana hace 4 dias (agendo despues: sus citas se crearon
  -- ahora); Cata hace 2 dias (sus citas se crearon hace 6: no agendo despues).
  insert into public.client_return_invitations (tenant_id, branch_id, client_id, service_id, invited_at, invited_by)
  values
    (v_tenant, v_branch, v_ana, v_corte, now() - interval '4 days', v_dueno),
    (v_tenant, v_branch, v_cata, v_corte, now() - interval '2 days', v_dueno);

  -- ---------------------------------------------------------------- 1
  select id into v_feature from public.features where key = 'dashboard';
  if v_feature is null then
    raise exception 'FALLO 1: no existe la capacidad dashboard';
  end if;
  select count(*) into v_n from public.plan_features pf
  where pf.feature_id = v_feature and pf.enabled;
  if v_n <> (select count(*) from public.plans) then
    raise exception 'FALLO 1b: dashboard encendida en % planes de %', v_n, (select count(*) from public.plans);
  end if;
  select * into r from private.beautyos_resolve_entitlement(v_tenant, 'dashboard');
  if not r.entitled or r.source <> 'plan' then
    raise exception 'FALLO 1c: el negocio recibe dashboard=% desde %', r.entitled, r.source;
  end if;
  raise notice 'OK 1   la capacidad dashboard existe, encendida en todos los planes';

  -- ---------------------------------------------------------------- 2
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);

  v_d := public.get_dashboard_atenciones(array[v_branch], v_hoy - 6, v_hoy, v_hoy - 13, v_hoy - 7);

  if (v_d->'actual'->>'atendidas')::int <> 3 or (v_d->'actual'->>'clientas')::int <> 2
     or (v_d->'actual'->>'nuevas')::int <> 1 or (v_d->'actual'->>'canceladas')::int <> 1
     or (v_d->'actual'->>'no_llegaron')::int <> 1 or (v_d->'actual'->>'en_linea')::int <> 1
     or (v_d->'actual'->>'minutos')::int <> 165 then
    raise exception 'FALLO 2: el periodo actual dio %', v_d->'actual';
  end if;
  if (v_d->'anterior'->>'atendidas')::int <> 1 or (v_d->'anterior'->>'nuevas')::int <> 1
     or (v_d->'anterior'->>'minutos')::int <> 45 then
    raise exception 'FALLO 2b: el periodo anterior dio %', v_d->'anterior';
  end if;
  raise notice 'OK 2   3 atendidas, 2 clientas, 1 nueva, 1 cancelada, 1 no llego, 1 en linea, 165 min; antes 1 y 45';

  -- ---------------------------------------------------------------- 3
  if v_d->>'granularidad' <> 'day' or jsonb_array_length(v_d->'serie') <> 7
     or (select sum((x->>'atendidas')::int) from jsonb_array_elements(v_d->'serie') x) <> 3
     or (select sum((x->>'atendidas')::int) from jsonb_array_elements(v_d->'serie_anterior') x) <> 1 then
    raise exception 'FALLO 3: la serie dio % / anterior %', v_d->'serie', v_d->'serie_anterior';
  end if;
  raise notice 'OK 3   la serie: 7 dias con 3 atendidas; la anterior, 1';

  -- ---------------------------------------------------------------- 4
  if (select sum((x->>'atendidas')::int) from jsonb_array_elements(v_d->'calor') x) <> 3
     or not exists (
       select 1 from jsonb_array_elements(v_d->'calor') x
       where (x->>'dia_semana')::int = extract(isodow from v_hoy - 1)::int
         and (x->>'hora')::int = 15 and (x->>'atendidas')::int = 1
     ) then
    raise exception 'FALLO 4: el mapa de calor dio %', v_d->'calor';
  end if;
  raise notice 'OK 4   el mapa de calor pone cada cita en su dia y su hora';

  -- ---------------------------------------------------------------- 5
  if not exists (select 1 from jsonb_array_elements(v_d->'servicios') x
                 where x->>'nombre' = 'C244 corte' and (x->>'atenciones')::int = 1)
     or not exists (select 1 from jsonb_array_elements(v_d->'servicios') x
                    where x->>'nombre' = 'C244 unas' and (x->>'atenciones')::int = 2) then
    raise exception 'FALLO 5: los servicios dieron %', v_d->'servicios';
  end if;
  if not exists (select 1 from jsonb_array_elements(v_d->'equipo') x
                 where x->>'nombre' = 'C244 Paola' and (x->>'citas')::int = 1
                   and (x->>'calificacion')::numeric = 5 and (x->>'resenas')::int = 1)
     or not exists (select 1 from jsonb_array_elements(v_d->'equipo') x
                    where x->>'nombre' = 'C244 Juliana' and (x->>'citas')::int = 2
                      and (x->>'minutos')::int = 120) then
    raise exception 'FALLO 5b: el equipo dio %', v_d->'equipo';
  end if;
  raise notice 'OK 5   corte 1 y unas 2; Paola 1 cita con 5 estrellas (la resena vieja no cuenta); Juliana 2 y 120 min';

  -- ---------------------------------------------------------------- 6
  v_d := public.get_dashboard_atenciones(array[v_branch], v_hoy - 6, v_hoy, v_hoy - 13, v_hoy - 7, v_paola, null);
  if (v_d->'actual'->>'atendidas')::int <> 1 or (v_d->'actual'->>'minutos')::int <> 45
     or (v_d->'actual'->>'canceladas')::int <> 1 or (v_d->'actual'->>'no_llegaron')::int <> 0
     or jsonb_array_length(v_d->'servicios') <> 1
     or jsonb_array_length(v_d->'equipo') <> 2 then
    raise exception 'FALLO 6: filtrando por Paola dio actual=% servicios=% equipo=%',
      v_d->'actual', v_d->'servicios', v_d->'equipo';
  end if;
  raise notice 'OK 6   filtrar por estilista: solo sus citas y minutos; servicios se filtra, equipo no';

  -- ---------------------------------------------------------------- 7
  v_d := public.get_dashboard_atenciones(array[v_branch], v_hoy - 6, v_hoy, v_hoy - 13, v_hoy - 7, null, v_unas);
  if (v_d->'actual'->>'atendidas')::int <> 2 or (v_d->'actual'->>'minutos')::int <> 120
     or (v_d->'actual'->>'canceladas')::int <> 0 or (v_d->'actual'->>'no_llegaron')::int <> 1
     or jsonb_array_length(v_d->'servicios') <> 2
     or jsonb_array_length(v_d->'equipo') <> 1 then
    raise exception 'FALLO 7: filtrando por unas dio actual=% servicios=% equipo=%',
      v_d->'actual', v_d->'servicios', v_d->'equipo';
  end if;
  raise notice 'OK 7   filtrar por servicio: al reves';

  -- ---------------------------------------------------------------- 8
  v_d := public.get_dashboard_atenciones(array[v_branch], v_hoy - 6, v_hoy, v_hoy - 13, v_hoy - 7);
  if (v_d->'hoy'->>'citas')::int <> 2 or (v_d->'hoy'->>'en_proceso')::int <> 1
     or (v_d->'hoy'->>'por_atender')::int <> 1 or (v_d->'hoy'->>'cerradas')::int <> 0 then
    raise exception 'FALLO 8: hoy dio %', v_d->'hoy';
  end if;
  if (v_d->'invitaciones'->>'enviadas')::int <> 2 or (v_d->'invitaciones'->>'agendaron')::int <> 1 then
    raise exception 'FALLO 8b: las invitaciones dieron %', v_d->'invitaciones';
  end if;
  if jsonb_array_length(v_d->'motivos') <> 2
     or v_d->'motivos'->0->>'motivo' <> 'C244 aviso que no podia venir'
     or v_d->'motivos'->0->>'estado' <> 'cancelado'
     or (v_d->>'perdidas_en_linea')::int <> 1 then
    raise exception 'FALLO 8c: lo perdido dio motivos=% en linea=%', v_d->'motivos', v_d->'perdidas_en_linea';
  end if;
  if (select sum((x->>'nuevas')::int) from jsonb_array_elements(v_d->'semanas') x) <> 1 then
    raise exception 'FALLO 8d: las semanas dieron %', v_d->'semanas';
  end if;
  raise notice 'OK 8   hoy 2 (1 en proceso, 1 por atender); 2 invitadas y 1 agendo; los 2 motivos, el mas reciente primero';

  -- ---------------------------------------------------------------- 9
  insert into public.tenant_feature_overrides (
    tenant_id, feature_id, enabled, limit_value, reason, created_by
  ) values (
    v_tenant, v_feature, false, null, 'Control 244: apagar el Dashboard', v_dueno
  );
  select * into r from public.get_my_entitlements() e where e.feature_key = 'dashboard';
  if r.entitled or r.source <> 'override' then
    raise exception 'FALLO 9: con la excepcion, dashboard=% desde %', r.entitled, r.source;
  end if;
  raise notice 'OK 9   el Panel puede apagarle el Dashboard a un negocio';

  -- ---------------------------------------------------------------- 10
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_estilista_cuenta::text, 'role', 'authenticated')::text, true);
  v_capturo := false;
  begin
    perform public.get_dashboard_atenciones(array[v_branch], v_hoy - 6, v_hoy, v_hoy - 13, v_hoy - 7);
  exception when others then v_capturo := true;
  end;
  if not v_capturo then
    raise exception 'FALLO 10: la estilista pudo ver el Dashboard';
  end if;

  v_capturo := false;
  begin
    perform set_config('request.jwt.claims', '{"role":"anon"}', true);
    execute 'set local role anon';
    perform public.get_dashboard_atenciones(array[v_branch], v_hoy - 6, v_hoy, v_hoy - 13, v_hoy - 7);
    execute 'reset role';
  exception when others then
    v_capturo := true; v_error := sqlerrm;
    execute 'reset role';
  end;
  if not v_capturo then
    raise exception 'FALLO 10b: sin sesion se pudo pedir el Dashboard';
  end if;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);
  v_capturo := false;
  begin
    perform public.get_dashboard_atenciones(array[v_branch], v_hoy, v_hoy - 6, v_hoy - 13, v_hoy - 7);
  exception when others then v_capturo := true;
  end;
  if not v_capturo then
    raise exception 'FALLO 10c: se acepto un rango al reves';
  end if;
  raise notice 'OK 10  la estilista no lo ve, sin sesion no se puede (%), y un rango al reves se niega', v_error;

  perform set_config('request.jwt.claims', '{}', true);
  raise notice '--- CONTROL 244: 10/10 ---';
end
$ctrl$;

rollback;
