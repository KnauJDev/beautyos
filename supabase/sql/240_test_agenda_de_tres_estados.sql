-- CONTROL 240: Agenda de tres estados para los negocios con la caja apagada.
--              Paso 2 del plan del primer cliente real (D-308), D-312.
--
-- POR QUE ESTE ARCHIVO
--
-- El propietario decidio que a un negocio al que la plataforma le apago la
-- caja (David) **toda cita le nazca confirmada**, por el enlace o desde el
-- salon, y que su agenda vaya Confirmado -> En proceso -> Cerrado, con
-- Cancelar y No asistio como botones. Hay DOS puertas por las que nace una
-- cita --la agenda interna y la reserva publica-- y la leccion de D-252 es
-- que se arregla una y se olvida la otra: aqui se recorren las dos, y las
-- recurrentes, que entran por la interna.
--
-- Y lo que NO debe pasar: que a los demas negocios les cambie algo, y que
-- "Cerrado" sin cobro haga nacer un pago, una comision o un numero de venta.
--
-- Que valida, transaccionalmente:
--   1. Con la caja encendida, las dos puertas siguen naciendo en
--      'solicitado' (a los demas negocios no les cambia nada).
--   2. La pregunta en un sitio: con la caja apagada desde el Panel,
--      `beautyos_agenda_de_tres_estados` dice que si; a un negocio sin
--      suscripcion operativa (caja negada por OTRO motivo) le dice que no.
--   3. Caja apagada: la cita que crea el salon nace 'confirmado'.
--   4. Caja apagada: las recurrentes nacen 'confirmado'.
--   5. Caja apagada: la reserva por el enlace nace 'confirmado', y eso es lo
--      que le devuelve a la pagina publica.
--   6. Iniciar y terminar: el ticket pasa a en_proceso y luego, solo, a
--      'finalizado' ("Cerrado" para este negocio). **Sin pago, sin comision,
--      sin numero de venta, y sin llegar a 'cerrado'**, aunque el salon tenga
--      politica de comision.
--   7. Una cita que nacio 'solicitado' antes de apagar la caja se puede
--      confirmar, iniciar y terminar: es el camino que hace la app con las
--      citas viejas.
--   8. Cancelar y No asistio desde Confirmado, con su motivo.
--   9. El tope de reservas por celular (H-02) sigue contando las citas que
--      ya nacen confirmadas: la quinta se niega.
--
-- COMO SE EJECUTA (despues de aplicar 20261003100000_agenda_de_tres_estados_d312.sql)
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\240_test_agenda_de_tres_estados.sql"
--
-- TERMINA EN ROLLBACK.
--
-- Datos de prueba copiados de controles que pasaron (regla 25d): el negocio,
-- su sede, su horario, el duenyo, el servicio, el estilista y la politica de
-- comision, del 218 (20-sep); las dos puertas, del 224 (23-sep); el
-- operador de plataforma que apaga la caja, del 239 (02-oct).

set client_encoding = 'UTF8';

begin;

do $ctrl$
declare
  v_plan       uuid;
  v_operador   uuid;
  v_tenant     uuid;
  v_sin_susc   uuid;
  v_branch     uuid;
  v_service    uuid;
  v_bservice   uuid;
  v_stylist    uuid;
  v_bstylist   uuid;
  v_dueno      uuid := gen_random_uuid();
  v_memb       uuid;
  v_cliente    uuid;
  v_viejo      uuid;
  v_ticket     uuid;
  v_ts         uuid;
  v_slot       timestamptz;
  v_manana     date;
  v_estado     text;
  v_n          integer;
  v_capturo    boolean;
  v_error      text;
  v_precio     numeric := 20000;
  r            record;
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

  insert into auth.users (id, email) values (v_dueno, 'dueno_test240@salonymas.com')
  on conflict (id) do nothing;

  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 240', 'peluqueria', 'c240@salonymas.com', '3000000240', true)
  returning id into v_tenant;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_tenant, v_plan, 'active', now() + interval '30 days');

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C240 sede', 'c240-sede', true, true)
  returning id into v_branch;

  update public.branch_subscriptions
  set status = 'active', current_period_end = now() + interval '30 days',
      activated_at = now() - interval '1 day'
  where branch_id = v_branch;

  insert into public.business_hours (tenant_id, branch_id, day_of_week, opens_at, closes_at, is_open)
  select v_tenant, v_branch, d, time '06:00', time '22:00', true from generate_series(1, 7) d;

  -- Con politica de comision: si "Cerrado" sin cobro hiciera nacer una
  -- comision, aqui se veria.
  insert into public.commission_policies (
    tenant_id, commission_type, commission_percentage,
    fixed_commission_amount, applies_after_discount, active
  ) values (v_tenant, 'percentage', 40, 0, true, true);

  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_dueno, 'tenant_owner', true)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);
  insert into public.user_profiles (tenant_id, user_id, full_name, role, active)
  values (v_tenant, v_dueno, 'C240 duenyo', 'owner', true);

  insert into public.services (tenant_id, name, category, duration_minutes, price, visible_to_customer)
  values (v_tenant, 'C240 corte', 'Corte', 30, v_precio, true) returning id into v_service;
  insert into public.branch_services (
    tenant_id, branch_id, service_id, price, duration_minutes, visible_to_customer, active
  ) values (v_tenant, v_branch, v_service, v_precio, 30, true, true)
  returning id into v_bservice;

  insert into public.stylists (tenant_id, name, phone, specialty)
  values (v_tenant, 'C240 estilista', '3000000241', 'Corte')
  returning id into v_stylist;
  insert into public.branch_stylists (tenant_id, branch_id, stylist_id, active, starts_at)
  values (v_tenant, v_branch, v_stylist, true, now() - interval '1 day')
  returning id into v_bstylist;
  insert into public.branch_stylist_services (
    tenant_id, branch_id, branch_stylist_id, branch_service_id, active
  ) values (v_tenant, v_branch, v_bstylist, v_bservice, true);

  -- Un negocio sin suscripcion: su caja sale negada, pero no por el Panel.
  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 240 sin suscripcion', 'peluqueria', 'c240b@salonymas.com', '3000000242', true)
  returning id into v_sin_susc;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);

  select c.id into v_cliente from public.create_client('C240 Clienta', '3181112400') c;
  v_manana := ((now() at time zone 'America/Bogota')::date + 1);

  -- 1. Con la caja encendida, nada cambia
  if private.beautyos_agenda_de_tres_estados(v_tenant) then
    raise exception 'FALLO 1: con la caja encendida, el negocio ya tiene la agenda de tres estados';
  end if;

  select s.starts_at into v_slot
  from public.public_get_available_slots(v_branch, v_service, v_stylist, v_manana) s
  order by s.starts_at limit 1;
  select t.id, t.status into v_viejo, v_estado
  from public.create_scheduled_ticket_with_service_v2(
    v_branch, v_cliente, v_service, v_stylist, v_slot, 'manual', 'control 240 caja encendida') t;
  if v_estado <> 'solicitado' then
    raise exception 'FALLO 1b: con la caja encendida, la cita del salon nacio "%"', v_estado;
  end if;

  select s.starts_at into v_slot
  from public.public_get_available_slots(v_branch, v_service, v_stylist, v_manana) s
  order by s.starts_at limit 1;
  select b.status into v_estado
  from public.public_create_booking(
    v_branch, v_service, v_stylist, v_slot, 'C240 Reserva', '3181112401', null, null) b;
  if v_estado <> 'solicitado' then
    raise exception 'FALLO 1c: con la caja encendida, la reserva en linea nacio "%"', v_estado;
  end if;
  raise notice 'OK 1   con la caja encendida, las dos puertas siguen naciendo en solicitado';

  -- 2. El operador le apaga la caja desde el Panel
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_operador::text, 'role', 'authenticated')::text, true);
  perform 1 from public.platform_set_tenant_feature_override(
    v_tenant, 'cash_register', false, null, 'Control 240: apagada desde el Panel', null);
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);

  if not private.beautyos_agenda_de_tres_estados(v_tenant) then
    raise exception 'FALLO 2: con la caja apagada desde el Panel, el negocio no tiene la agenda de tres estados';
  end if;
  select * into r from private.beautyos_resolve_entitlement(v_sin_susc, 'cash_register');
  if r.entitled then
    raise exception 'FALLO 2b: el negocio sin suscripcion tiene la caja permitida; el caso no se reproduce';
  end if;
  if private.beautyos_agenda_de_tres_estados(v_sin_susc) then
    raise exception 'FALLO 2c: un negocio con la caja negada por % (no por el Panel) quedo con la agenda de tres estados', r.source;
  end if;
  raise notice 'OK 2   tres estados solo si la caja la apago el Panel (no si se niega por %)', r.source;

  -- 3. La cita del salon nace confirmada
  select s.starts_at into v_slot
  from public.public_get_available_slots(v_branch, v_service, v_stylist, v_manana) s
  order by s.starts_at limit 1;
  select t.id, t.status into v_ticket, v_estado
  from public.create_scheduled_ticket_with_service_v2(
    v_branch, v_cliente, v_service, v_stylist, v_slot, 'manual', 'control 240 caja apagada') t;
  if v_estado <> 'confirmado' then
    raise exception 'FALLO 3: con la caja apagada, la cita del salon nacio "%"', v_estado;
  end if;
  raise notice 'OK 3   la cita que crea el salon nace confirmada';

  -- 4. Las recurrentes tambien
  select s.starts_at into v_slot
  from public.public_get_available_slots(v_branch, v_service, v_stylist, v_manana) s
  order by s.starts_at limit 1;
  select count(*) filter (where x.success)
    into v_n
  from public.create_recurring_scheduled_tickets_v2(
    v_branch, v_cliente, v_service, v_stylist, v_slot, 'weekly', v_manana + 7,
    'manual', 'control 240 recurrente') x;
  if v_n <> 2 then
    raise exception 'FALLO 4: la serie semanal debia crear 2 citas y creo %', v_n;
  end if;
  select count(*) into v_n
  from public.tickets t
  where t.tenant_id = v_tenant and t.notes = 'control 240 recurrente' and t.status <> 'confirmado';
  if v_n > 0 then
    raise exception 'FALLO 4b: % citas recurrentes no nacieron confirmadas', v_n;
  end if;
  raise notice 'OK 4   las citas recurrentes nacen confirmadas';

  -- 5. La reserva por el enlace nace confirmada, y asi se lo dice a la pagina
  select s.starts_at into v_slot
  from public.public_get_available_slots(v_branch, v_service, v_stylist, v_manana) s
  order by s.starts_at limit 1;
  select b.status into v_estado
  from public.public_create_booking(
    v_branch, v_service, v_stylist, v_slot, 'C240 Reserva 2', '3181112402', null, null) b;
  if v_estado <> 'confirmado' then
    raise exception 'FALLO 5: con la caja apagada, la reserva en linea nacio "%"', v_estado;
  end if;
  raise notice 'OK 5   la reserva por el enlace nace confirmada, y asi se lo devuelve a la pagina';

  -- 6. Iniciar y terminar, sin dinero
  select m.ticket_service_id into v_ts
  from public.get_ticket_services_for_management_v2(v_branch, v_ticket) m
  limit 1;
  perform 1 from public.change_ticket_service_status_v2(v_branch, v_ts, 'en_proceso');
  select t.status into v_estado from public.tickets t where t.id = v_ticket;
  if v_estado <> 'en_proceso' then
    raise exception 'FALLO 6: al iniciar, la cita quedo en "%"', v_estado;
  end if;
  perform 1 from public.change_ticket_service_status_v2(v_branch, v_ts, 'finalizado');
  select t.status into v_estado from public.tickets t where t.id = v_ticket;
  if v_estado <> 'finalizado' then
    raise exception 'FALLO 6b: al terminar, la cita quedo en "%" y no en finalizado', v_estado;
  end if;
  if exists (select 1 from public.ticket_payments where ticket_id = v_ticket) then
    raise exception 'FALLO 6c: terminar la cita hizo nacer un pago';
  end if;
  if exists (select 1 from public.stylist_commissions where ticket_id = v_ticket) then
    raise exception 'FALLO 6d: terminar la cita sin cobro hizo nacer una comision';
  end if;
  if exists (select 1 from public.tickets where id = v_ticket and sale_number is not null) then
    raise exception 'FALLO 6e: terminar la cita sin cobro le dio numero de venta';
  end if;
  raise notice 'OK 6   iniciar y terminar: queda finalizada, sin pago, sin comision y sin numero de venta';

  -- 7. La cita vieja (nacio solicitada) tambien sale adelante
  perform 1 from public.change_ticket_status_v2(v_branch, v_viejo, 'confirmado', null);
  select m.ticket_service_id into v_ts
  from public.get_ticket_services_for_management_v2(v_branch, v_viejo) m
  limit 1;
  perform 1 from public.change_ticket_service_status_v2(v_branch, v_ts, 'en_proceso');
  perform 1 from public.change_ticket_service_status_v2(v_branch, v_ts, 'finalizado');
  select t.status into v_estado from public.tickets t where t.id = v_viejo;
  if v_estado <> 'finalizado' then
    raise exception 'FALLO 7: la cita que nacio solicitada quedo en "%"', v_estado;
  end if;
  raise notice 'OK 7   una cita que nacio solicitada se confirma, se inicia y se termina';

  -- 8. Cancelar y No asistio desde Confirmado, con motivo
  select t.id into v_ticket
  from public.tickets t
  where t.tenant_id = v_tenant and t.notes = 'control 240 recurrente'
  order by t.scheduled_at limit 1;
  perform 1 from public.change_ticket_status_v2(v_branch, v_ticket, 'cancelado', 'La clienta avisó que no puede');
  select t.status into v_estado from public.tickets t where t.id = v_ticket;
  if v_estado <> 'cancelado' then
    raise exception 'FALLO 8: cancelar dejo la cita en "%"', v_estado;
  end if;

  select t.id into v_ticket
  from public.tickets t
  where t.tenant_id = v_tenant and t.notes = 'control 240 recurrente' and t.status = 'confirmado'
  order by t.scheduled_at limit 1;
  perform 1 from public.change_ticket_status_v2(v_branch, v_ticket, 'no_asistio', 'No llegó');
  select t.status into v_estado from public.tickets t where t.id = v_ticket;
  if v_estado <> 'no_asistio' then
    raise exception 'FALLO 8b: no asistio dejo la cita en "%"', v_estado;
  end if;
  raise notice 'OK 8   cancelar y no asistio funcionan desde Confirmado, con su motivo';

  -- 9. El tope de reservas por celular sigue contando las confirmadas
  for i in 1..3 loop
    select s.starts_at into v_slot
    from public.public_get_available_slots(v_branch, v_service, v_stylist, v_manana) s
    order by s.starts_at limit 1;
    perform 1 from public.public_create_booking(
      v_branch, v_service, v_stylist, v_slot, 'C240 Reserva 2', '3181112402', null, null);
  end loop;
  select s.starts_at into v_slot
  from public.public_get_available_slots(v_branch, v_service, v_stylist, v_manana) s
  order by s.starts_at limit 1;
  v_capturo := false;
  begin
    perform 1 from public.public_create_booking(
      v_branch, v_service, v_stylist, v_slot, 'C240 Reserva 2', '3181112402', null, null);
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;
  if not v_capturo then
    raise exception 'FALLO 9: con 4 citas confirmadas, el mismo celular reservo una quinta';
  end if;
  if v_error not ilike '%4 citas pendientes%' then
    raise exception 'FALLO 9b: se nego, pero por otra razon: %', v_error;
  end if;
  raise notice 'OK 9   el tope por celular cuenta las citas que nacen confirmadas';

  perform set_config('request.jwt.claims', '{}', true);

  raise notice '--- CONTROL 240: 9/9 ---';
end
$ctrl$;

rollback;
