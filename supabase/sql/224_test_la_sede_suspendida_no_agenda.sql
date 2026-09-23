-- CONTROL 224: La sede suspendida no agenda, y el candado dice la verdad.
--              Hallazgo BI, decision del propietario del 23-sep (D-260).
--
-- POR QUE ESTE ARCHIVO
--
-- El propietario decidio que **una sede suspendida por no pago no puede
-- agendar citas nuevas ni recibir reservas en linea; lo ya agendado se
-- atiende y se cobra, y las demas sedes siguen normales**. Hay DOS puertas por
-- las que nace una cita -- la agenda interna y la reserva publica --, y la
-- leccion de D-252 es que se arregla una y se olvida la otra. Este control las
-- recorre las dos, y tambien lo que NO debe bloquearse.
--
-- Los fixtures se copiaron del control 218, que ya crea citas con exito, en
-- vez de escribirlos de memoria (regla 25 d).
--
-- Que valida, transaccionalmente:
--   1. Con las dos sedes al dia, las dos agendan (el fixture funciona).
--   2. Sede suspendida: la agenda interna se niega, y dice por que.
--   3. Sede suspendida: la reserva en linea se niega, SIN decirle a la
--      clienta que el salon debe dinero.
--   4. La otra sede, al dia, sigue agendando por las dos puertas.
--   5. Lo ya agendado en la sede suspendida se sigue atendiendo.
--   6. Una sede `pending` (recien creada, sin pagar) NO se bloquea: eso no lo
--      decidio nadie.
--   7. El candado del negocio ya no dice "prueba gratis" a quien pago: dice
--      el motivo segun el estado (prueba terminada, periodo vencido,
--      suspendido).
--   8. Los mensajes quedaron guardados con sus tildes (no "estÃ¡").
--   9. Barrido: ninguna funcion de la base tiene texto danado por la
--      codificacion. Si alguna lo tiene, NO falla: avisa, porque es de antes.
--
-- COMO SE EJECUTA (despues de aplicar 20260923150000_la_sede_suspendida_no_agenda_bi.sql)
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\224_test_la_sede_suspendida_no_agenda.sql"
--
-- TERMINA EN ROLLBACK.

begin;

do $ctrl$
declare
  v_plan       uuid;
  v_tenant     uuid;
  v_sede_a     uuid;
  v_sede_b     uuid;
  v_service    uuid;
  v_bserv_a    uuid;
  v_bserv_b    uuid;
  v_sty_a      uuid;
  v_sty_b      uuid;
  v_bsty_a     uuid;
  v_bsty_b     uuid;
  v_dueno      uuid := gen_random_uuid();
  v_memb       uuid;
  v_cliente    uuid;
  v_ticket_b   uuid;
  v_ticket     uuid;
  v_ts         uuid;
  v_slot       timestamptz;
  v_manana     date;
  v_estado     text;
  v_capturo    boolean;
  v_error      text;
  v_danadas    text;
begin
  -- ---------------------------------------------------------------- fixtures
  select id into v_plan from public.plans where status = 'active' limit 1;
  if v_plan is null then
    raise exception 'FALLO: no hay ningun plan activo con el que probar';
  end if;

  insert into auth.users (id, email) values (v_dueno, 'dueno_test224@salonymas.com')
  on conflict (id) do nothing;

  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 224', 'peluqueria', 'c224@salonymas.com', '3000000224', true)
  returning id into v_tenant;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_tenant, v_plan, 'active', now() + interval '30 days');

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C224 sede A', 'c224-sede-a', true, true)
  returning id into v_sede_a;
  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C224 sede B', 'c224-sede-b', false, true)
  returning id into v_sede_b;

  -- Las dos sedes, al dia.
  update public.branch_subscriptions
  set status = 'active', current_period_end = now() + interval '30 days',
      activated_at = now() - interval '1 day'
  where branch_id in (v_sede_a, v_sede_b);

  insert into public.business_hours (tenant_id, branch_id, day_of_week, opens_at, closes_at, is_open)
  select v_tenant, b, d, time '06:00', time '22:00', true
  from generate_series(1, 7) d, unnest(array[v_sede_a, v_sede_b]) b;

  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_dueno, 'tenant_owner', true)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  )
  select v_tenant, b, v_memb, true, now() - interval '1 day', v_dueno
  from unnest(array[v_sede_a, v_sede_b]) b;
  insert into public.user_profiles (tenant_id, user_id, full_name, role, active)
  values (v_tenant, v_dueno, 'C224 duenyo', 'owner', true);

  insert into public.services (tenant_id, name, category, duration_minutes, price, visible_to_customer)
  values (v_tenant, 'C224 corte', 'Corte', 30, 20000, true) returning id into v_service;
  insert into public.branch_services (
    tenant_id, branch_id, service_id, price, duration_minutes, visible_to_customer, active
  ) values (v_tenant, v_sede_a, v_service, 20000, 30, true, true)
  returning id into v_bserv_a;
  insert into public.branch_services (
    tenant_id, branch_id, service_id, price, duration_minutes, visible_to_customer, active
  ) values (v_tenant, v_sede_b, v_service, 20000, 30, true, true)
  returning id into v_bserv_b;

  -- Un estilista por sede, para que el choque de horario entre sedes no se
  -- meta en lo que se prueba.
  insert into public.stylists (tenant_id, name, phone, specialty)
  values (v_tenant, 'C224 estilista A', '3000000225', 'Corte')
  returning id into v_sty_a;
  insert into public.stylists (tenant_id, name, phone, specialty)
  values (v_tenant, 'C224 estilista B', '3000000226', 'Corte')
  returning id into v_sty_b;
  insert into public.branch_stylists (tenant_id, branch_id, stylist_id, active, starts_at)
  values (v_tenant, v_sede_a, v_sty_a, true, now() - interval '1 day')
  returning id into v_bsty_a;
  insert into public.branch_stylists (tenant_id, branch_id, stylist_id, active, starts_at)
  values (v_tenant, v_sede_b, v_sty_b, true, now() - interval '1 day')
  returning id into v_bsty_b;
  insert into public.branch_stylist_services (
    tenant_id, branch_id, branch_stylist_id, branch_service_id, active
  ) values
    (v_tenant, v_sede_a, v_bsty_a, v_bserv_a, true),
    (v_tenant, v_sede_b, v_bsty_b, v_bserv_b, true);

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);

  select c.id into v_cliente from public.create_client('C224 Clienta', '3181112244') c;

  v_manana := ((now() at time zone 'America/Bogota')::date + 1);

  -- 1. Con las dos al dia, las dos agendan
  select s.starts_at into v_slot
  from public.public_get_available_slots(v_sede_b, v_service, v_sty_b, v_manana) s
  order by s.starts_at limit 1;
  select t.id into v_ticket_b
  from public.create_scheduled_ticket_with_service_v2(
    v_sede_b, v_cliente, v_service, v_sty_b, v_slot, 'manual', 'control 224 antes') t;

  select s.starts_at into v_slot
  from public.public_get_available_slots(v_sede_a, v_service, v_sty_a, v_manana) s
  order by s.starts_at limit 1;
  select t.id into v_ticket
  from public.create_scheduled_ticket_with_service_v2(
    v_sede_a, v_cliente, v_service, v_sty_a, v_slot, 'manual', 'control 224 A') t;

  if v_ticket_b is null or v_ticket is null then
    raise exception 'FALLO 1: con las dos sedes al dia no se pudo agendar. El fixture no reproduce el caso.';
  end if;
  raise notice 'OK 1   con las dos sedes al dia, las dos agendan';

  -- La sede B deja de pagar y se suspende.
  update public.branch_subscriptions
  set status = 'suspended', current_period_end = now() - interval '10 days',
      grace_ends_at = now() - interval '5 days'
  where branch_id = v_sede_b;

  -- 2. La agenda interna se niega en B, y dice por que
  select s.starts_at into v_slot
  from public.public_get_available_slots(v_sede_b, v_service, v_sty_b, v_manana) s
  order by s.starts_at limit 1;
  v_capturo := false;
  begin
    perform 1 from public.create_scheduled_ticket_with_service_v2(
      v_sede_b, v_cliente, v_service, v_sty_b, v_slot, 'manual', 'control 224 suspendida');
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;
  if not v_capturo then
    raise exception 'FALLO 2: la sede suspendida agendo una cita nueva por la agenda interna.';
  end if;
  if v_error not ilike '%suspendida por falta de pago%' then
    raise exception 'FALLO 2b: se nego, pero sin decir por que. Dijo: %', v_error;
  end if;
  raise notice 'OK 2   la agenda interna de la sede suspendida se niega, y dice por que';

  -- 3. La reserva en linea se niega en B, sin contar la deuda
  v_capturo := false;
  begin
    perform 1 from public.public_create_booking(
      v_sede_b, v_service, v_sty_b, v_slot, 'C224 Reserva', '3181112245', null, null);
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;
  if not v_capturo then
    raise exception 'FALLO 3: la sede suspendida recibio una reserva en linea.';
  end if;
  if v_error ilike '%pago%' or v_error ilike '%deuda%' then
    raise exception 'FALLO 3b: a la clienta se le conto que el salon no ha pagado. Dijo: %', v_error;
  end if;
  raise notice 'OK 3   la reserva en linea de la sede suspendida se niega, sin contarle la deuda a la clienta';

  -- 4. La sede A sigue por las dos puertas
  select s.starts_at into v_slot
  from public.public_get_available_slots(v_sede_a, v_service, v_sty_a, v_manana) s
  order by s.starts_at limit 1;
  perform 1 from public.create_scheduled_ticket_with_service_v2(
    v_sede_a, v_cliente, v_service, v_sty_a, v_slot, 'manual', 'control 224 A sigue');

  select s.starts_at into v_slot
  from public.public_get_available_slots(v_sede_a, v_service, v_sty_a, v_manana) s
  order by s.starts_at limit 1;
  perform 1 from public.public_create_booking(
    v_sede_a, v_service, v_sty_a, v_slot, 'C224 Reserva A', '3181112246', null, null);
  raise notice 'OK 4   la sede al dia sigue agendando por las dos puertas';

  -- 5. Lo ya agendado en B se atiende
  perform 1 from public.change_ticket_status_v2(v_sede_b, v_ticket_b, 'confirmado', null);
  select m.ticket_service_id into v_ts
  from public.get_ticket_services_for_management_v2(v_sede_b, v_ticket_b) m
  limit 1;
  perform 1 from public.change_ticket_service_status_v2(v_sede_b, v_ts, 'en_proceso');

  select t.status into v_estado from public.tickets t where t.id = v_ticket_b;
  if v_estado <> 'en_proceso' then
    raise exception 'FALLO 5: la cita que ya existia en la sede suspendida no se pudo atender (quedo en %).', v_estado;
  end if;
  raise notice 'OK 5   lo ya agendado en la sede suspendida se sigue atendiendo';

  -- 6. Una sede pending no se bloquea
  update public.branch_subscriptions
  set status = 'pending', current_period_end = null, grace_ends_at = null
  where branch_id = v_sede_b;
  select s.starts_at into v_slot
  from public.public_get_available_slots(v_sede_b, v_service, v_sty_b, v_manana) s
  order by s.starts_at limit 1;
  perform 1 from public.create_scheduled_ticket_with_service_v2(
    v_sede_b, v_cliente, v_service, v_sty_b, v_slot, 'manual', 'control 224 pending');
  raise notice 'OK 6   una sede pending (sin pagar todavia) no se bloquea: eso no lo decidio nadie';

  -- 7. El candado del negocio dice el motivo segun el estado
  select s.starts_at into v_slot
  from public.public_get_available_slots(v_sede_a, v_service, v_sty_a, v_manana) s
  order by s.starts_at limit 1;

  update public.tenant_subscriptions
  set status = 'active', current_period_end = now() - interval '1 hour'
  where tenant_id = v_tenant;
  v_capturo := false;
  begin
    perform 1 from public.create_scheduled_ticket_with_service_v2(
      v_sede_a, v_cliente, v_service, v_sty_a, v_slot, 'manual', 'c224 vencido');
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;
  if not v_capturo or v_error ilike '%prueba gratis%' or v_error not ilike '%pagado%' then
    raise exception 'FALLO 7a: a un negocio con el periodo pagado vencido se le dijo: %', coalesce(v_error, 'nada, y agendo');
  end if;

  update public.tenant_subscriptions
  set status = 'suspended', grace_ends_at = now() - interval '1 day'
  where tenant_id = v_tenant;
  v_capturo := false;
  begin
    perform 1 from public.create_scheduled_ticket_with_service_v2(
      v_sede_a, v_cliente, v_service, v_sty_a, v_slot, 'manual', 'c224 suspendido');
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;
  if not v_capturo or v_error ilike '%prueba gratis%' or v_error not ilike '%falta de pago%' then
    raise exception 'FALLO 7b: a un negocio suspendido se le dijo: %', coalesce(v_error, 'nada, y agendo');
  end if;

  update public.tenant_subscriptions
  set status = 'trialing', trial_ends_at = now() - interval '1 day'
  where tenant_id = v_tenant;
  v_capturo := false;
  begin
    perform 1 from public.create_scheduled_ticket_with_service_v2(
      v_sede_a, v_cliente, v_service, v_sty_a, v_slot, 'manual', 'c224 prueba');
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;
  if not v_capturo or v_error not ilike '%prueba gratis%' then
    raise exception 'FALLO 7c: a un negocio con la prueba terminada se le dijo: %', coalesce(v_error, 'nada, y agendo');
  end if;
  raise notice 'OK 7   el candado del negocio dice el motivo real: periodo vencido, suspendido o prueba terminada';

  -- 8. Las tildes quedaron bien guardadas. Se compara por codigo de letra
  -- (U&'\00E1' es la a con tilde), no con una tilde escrita en este archivo:
  -- si la codificacion estuviera mal, las dos se danyarian igual y la
  -- comparacion pasaria sin probar nada.
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'create_scheduled_ticket_with_service_v2'
      and position(U&'est\00E1 suspendida' in pg_get_functiondef(p.oid)) > 0
  ) then
    raise exception 'FALLO 8: el mensaje de la sede suspendida no quedo guardado con su tilde. Revisar la codificacion al aplicar.';
  end if;
  raise notice 'OK 8   los mensajes nuevos quedaron guardados con sus tildes';

  -- 9. Barrido de texto danado por la codificacion (aviso, no fallo)
  select string_agg(n.nspname || '.' || p.proname, ', ' order by p.proname)
    into v_danadas
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname in ('public', 'private')
    and p.prokind = 'f'
    and pg_get_functiondef(p.oid) ~ U&'\00C3[\00A0-\00BF]';

  if v_danadas is null then
    raise notice 'OK 9   ninguna funcion tiene texto danado por la codificacion';
  else
    raise notice 'AVISO 9  estas funciones tienen tildes danadas (de migraciones anteriores): %', v_danadas;
  end if;

  raise notice '--- CONTROL 224: 9/9 ---';
end
$ctrl$;

rollback;
