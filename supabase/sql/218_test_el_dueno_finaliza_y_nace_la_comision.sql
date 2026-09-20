-- CONTROL 218: El duenyo termina el servicio, y ahi nace la comision.
--              Hallazgo AP.
--
-- POR QUE ESTE ARCHIVO
--
-- Un salon crea estilistas en el catalogo sin invitarlos, porque no todo el
-- mundo quiere dar cuentas a todos: es el paso 9 del recorrido y es lo
-- normal. Hasta el 20-sep, el unico sitio de toda la aplicacion que movia un
-- servicio a `finalizado` era **Mi agenda**, la pantalla privada del
-- estilista -- que no existe si el estilista no tiene cuenta.
--
-- El resultado era silencioso, que es lo peor: el ticket se dejaba cobrar
-- (D-163), la clienta pagaba, y **la comision no nacia nunca**, porque
-- `private.beautyos_close_ticket_if_fully_paid` se sale de vacio si el ticket
-- no esta `finalizado`.
--
-- **Por que un control y no solo pruebas de Dart.** Las pruebas de Dart miran
-- la tabla de estados de la pantalla. Este recorre el camino entero del
-- producto con un estilista **sin cuenta de usuario**, que es el caso real, y
-- termina mirando la fila de dinero. Es la leccion de D-247: ejecutar una
-- funcion comprueba la funcion; recorrer el camino comprueba el producto.
--
-- Que valida, transaccionalmente:
--   1. El duenyo inicia un servicio de un estilista que NO tiene cuenta.
--   2. Al iniciarlo, el ticket pasa solo a `en_proceso`.
--   3. **La enfermedad:** con el servicio a medias, pagar el ticket entero
--      NO lo cierra y NO genera comision. Es lo que pasaba antes de AP.
--   4. El duenyo lo finaliza, y el ticket pasa a `finalizado` (Por cobrar).
--   5. **Nace la comision**, y por el valor que dice la politica del salon.
--   6. El ticket queda `cerrado`.
--   7. La recepcion (`assistant`) tambien puede: no es accion de duenyo.
--   8. El lector que alimenta la ventana ensenya el estado de cada servicio.
--
-- COMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\218_test_el_dueno_finaliza_y_nace_la_comision.sql"
--
-- TERMINA EN ROLLBACK.

begin;

do $ctrl$
declare
  v_plan       uuid;
  v_tenant     uuid;
  v_branch     uuid;
  v_service    uuid;
  v_bservice   uuid;
  v_stylist    uuid;
  v_bstylist   uuid;
  v_dueno      uuid := gen_random_uuid();
  v_recepcion  uuid := gen_random_uuid();
  v_memb       uuid;
  v_cliente    uuid;
  v_ticket     uuid;
  v_ts1        uuid;
  v_ts2        uuid;
  v_slot       timestamptz;
  v_manana     date;
  v_estado     text;
  v_comisiones integer;
  v_valor      numeric;
  v_precio     numeric := 20000;
  v_capturo    boolean;
  v_error      text;
begin
  -- ---------------------------------------------------------------- fixtures
  select id into v_plan from public.plans where status = 'active' limit 1;
  if v_plan is null then
    raise exception 'FALLO: no hay ningun plan activo con el que probar';
  end if;

  insert into auth.users (id, email) values (v_dueno, 'dueno_test218@salonymas.com')
  on conflict (id) do nothing;
  insert into auth.users (id, email) values (v_recepcion, 'recepcion_test218@salonymas.com')
  on conflict (id) do nothing;

  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 218', 'peluqueria', 'c218@salonymas.com', '3000000218', true)
  returning id into v_tenant;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_tenant, v_plan, 'active', now() + interval '30 days');

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C218 sede', 'c218-sede', true, true)
  returning id into v_branch;

  insert into public.business_hours (tenant_id, branch_id, day_of_week, opens_at, closes_at, is_open)
  select v_tenant, v_branch, d, time '06:00', time '22:00', true from generate_series(1, 7) d;

  -- La politica de comision del salon: sin ella no hay fila que mirar.
  insert into public.commission_policies (
    tenant_id, commission_type, commission_percentage,
    fixed_commission_amount, applies_after_discount, active
  ) values (v_tenant, 'percentage', 40, 0, true, true);

  -- El duenyo.
  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_dueno, 'tenant_owner', true)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);
  insert into public.user_profiles (tenant_id, user_id, full_name, role, active)
  values (v_tenant, v_dueno, 'C218 duenyo', 'owner', true);

  -- La recepcion.
  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_recepcion, 'assistant', true)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);
  insert into public.user_profiles (tenant_id, user_id, full_name, role, active)
  values (v_tenant, v_recepcion, 'C218 recepcion', 'assistant', true);

  insert into public.services (tenant_id, name, category, duration_minutes, price, visible_to_customer)
  values (v_tenant, 'C218 corte', 'Corte', 30, v_precio, true) returning id into v_service;
  insert into public.branch_services (
    tenant_id, branch_id, service_id, price, duration_minutes, visible_to_customer, active
  ) values (v_tenant, v_branch, v_service, v_precio, 30, true, true)
  returning id into v_bservice;

  -- EL CASO DEL HALLAZGO: el estilista existe en el catalogo y **no tiene
  -- cuenta**. No hay ninguna fila suya en auth.users ni en user_profiles, asi
  -- que nadie puede entrar a Mi agenda por el.
  insert into public.stylists (tenant_id, name, phone, specialty)
  values (v_tenant, 'C218 Erick sin cuenta', '3000000218', 'Corte')
  returning id into v_stylist;
  insert into public.branch_stylists (tenant_id, branch_id, stylist_id, active, starts_at)
  values (v_tenant, v_branch, v_stylist, true, now() - interval '1 day')
  returning id into v_bstylist;
  insert into public.branch_stylist_services (
    tenant_id, branch_id, branch_stylist_id, branch_service_id, active
  ) values (v_tenant, v_branch, v_bstylist, v_bservice, true);

  if exists (
    select 1 from public.user_profiles up
    where up.tenant_id = v_tenant and up.stylist_id = v_stylist
  ) then
    raise exception 'FALLO 0: el estilista de prueba tiene cuenta. Entonces este control no prueba el caso del hallazgo AP.';
  end if;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);

  select c.id into v_cliente from public.create_client('C218 Clienta', '3181112233') c;

  v_manana := ((now() at time zone 'America/Bogota')::date + 1);
  select s.starts_at into v_slot
  from public.public_get_available_slots(v_branch, v_service, v_stylist, v_manana) s
  order by s.starts_at limit 1;

  select t.id into v_ticket
  from public.create_scheduled_ticket_with_service_v2(
    v_branch, v_cliente, v_service, v_stylist, v_slot, 'manual', 'control 218') t;

  perform 1 from public.change_ticket_status_v2(v_branch, v_ticket, 'confirmado', null);

  select m.ticket_service_id into v_ts1
  from public.get_ticket_services_for_management_v2(v_branch, v_ticket) m
  limit 1;

  if v_ts1 is null then
    raise exception 'FALLO: el ticket de prueba nacio sin servicios';
  end if;

  -- 1 y 2. El duenyo inicia, y el ticket se mueve solo
  perform 1 from public.change_ticket_service_status_v2(v_branch, v_ts1, 'en_proceso');

  select t.status into v_estado from public.tickets t where t.id = v_ticket;
  if v_estado <> 'en_proceso' then
    raise exception 'FALLO 1: tras iniciar, el ticket quedo en "%" y no en "en_proceso".', v_estado;
  end if;
  raise notice 'OK 1   el duenyo inicia el servicio de un estilista sin cuenta';
  raise notice 'OK 2   al iniciarlo, el ticket pasa solo a en_proceso';

  -- 3. LA ENFERMEDAD: pagarlo entero a medias no cierra ni paga comision
  perform 1 from public.register_ticket_payment_v2(
    v_branch, v_ticket, v_precio, 'efectivo', null, 'control 218 pago a medias');

  select t.status into v_estado from public.tickets t where t.id = v_ticket;
  if v_estado = 'cerrado' then
    raise exception 'FALLO 3: el ticket se cerro con el servicio a medias. El cierre debe exigir que el servicio este terminado.';
  end if;

  select count(*) into v_comisiones
  from public.stylist_commissions sc where sc.ticket_id = v_ticket;
  if v_comisiones <> 0 then
    raise exception 'FALLO 3b: nacio una comision (%) sin haber terminado el servicio.', v_comisiones;
  end if;
  raise notice 'OK 3   con el servicio a medias, la clienta paga y NO nace comision. Esta es la enfermedad que AP cierra.';

  -- 4. El duenyo finaliza
  perform 1 from public.change_ticket_service_status_v2(v_branch, v_ts1, 'finalizado');

  -- 5 y 6. Nace la comision, y por el valor de la politica
  select count(*), coalesce(max(sc.commission_amount), 0)
    into v_comisiones, v_valor
  from public.stylist_commissions sc where sc.ticket_id = v_ticket;

  if v_comisiones <> 1 then
    raise exception
      'FALLO 5: tras finalizar y con el ticket pagado hay % comisiones, y deberia haber 1. Esto es exactamente el hallazgo AP: la clienta paga y el estilista no cobra.',
      v_comisiones;
  end if;
  if v_valor <> round(v_precio * 40 / 100) then
    raise exception 'FALLO 5b: la comision quedo en % y la politica del salon dice 40%% de % (= %).',
      v_valor, v_precio, round(v_precio * 40 / 100);
  end if;
  raise notice 'OK 4   el duenyo finaliza el servicio desde la sede';
  raise notice 'OK 5   nace la comision, y por el 40%% que dice la politica';

  select t.status into v_estado from public.tickets t where t.id = v_ticket;
  if v_estado <> 'cerrado' then
    raise exception 'FALLO 6: con todo terminado y pagado el ticket quedo en "%" y no en "cerrado".', v_estado;
  end if;
  raise notice 'OK 6   el ticket queda cerrado';

  -- 7. La recepcion tambien puede: no es accion de duenyo
  select s.starts_at into v_slot
  from public.public_get_available_slots(v_branch, v_service, v_stylist, v_manana) s
  order by s.starts_at limit 1;

  select t.id into v_ticket
  from public.create_scheduled_ticket_with_service_v2(
    v_branch, v_cliente, v_service, v_stylist, v_slot, 'manual', 'control 218 recepcion') t;
  perform 1 from public.change_ticket_status_v2(v_branch, v_ticket, 'confirmado', null);

  select m.ticket_service_id into v_ts2
  from public.get_ticket_services_for_management_v2(v_branch, v_ticket) m
  limit 1;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_recepcion::text, 'role', 'authenticated')::text, true);

  v_capturo := false;
  begin
    perform 1 from public.change_ticket_service_status_v2(v_branch, v_ts2, 'en_proceso');
    perform 1 from public.change_ticket_service_status_v2(v_branch, v_ts2, 'finalizado');
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;

  if v_capturo then
    raise exception
      'FALLO 7: la recepcion no pudo atender el servicio, y en un salon es quien esta en el mostrador. Dijo: %',
      v_error;
  end if;

  select t.status into v_estado from public.tickets t where t.id = v_ticket;
  if v_estado <> 'finalizado' then
    raise exception 'FALLO 7b: tras atenderlo la recepcion, el ticket quedo en "%" y no en "finalizado".', v_estado;
  end if;
  raise notice 'OK 7   la recepcion tambien puede atender el servicio';

  -- 8. El lector que alimenta la ventana ensenya el estado de cada servicio
  select m.service_status into v_estado
  from public.get_ticket_services_for_management_v2(v_branch, v_ticket) m
  where m.ticket_service_id = v_ts2;

  if v_estado <> 'finalizado' then
    raise exception
      'FALLO 8: el lector de la ventana dice "%" para un servicio ya terminado. La pantalla ensenyaria el boton equivocado.',
      v_estado;
  end if;
  raise notice 'OK 8   el lector devuelve el estado real de cada servicio';

  raise notice ' ';
  raise notice 'CONTROL 218: 8 de 8 en verde';
end
$ctrl$;

rollback;
