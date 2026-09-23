-- CONTROL 225: "Corregir un servicio finalizado" escribe bien sus tildes.
--              Hallazgo BL.
--
-- POR QUE ESTE ARCHIVO
--
-- La funcion que hay debajo de "Corregir un servicio finalizado" guardaba en
-- el historial del ticket "CorrecciÃ³n administrativa: <motivo>", y sus
-- mensajes de error decian "finalizaciÃ³n" y "no estÃ¡". No estaba en el
-- repositorio (nacio antes de las migraciones); se leyo viva y se corrigio en
-- `20260923170000_las_tildes_de_corregir_servicio_bl.sql`.
--
-- No basta con leer el texto de la funcion: este control **corrige de verdad
-- un servicio finalizado** y mira la fila que queda en el historial (D-245:
-- los controles ejecutan el camino). Los fixtures se copiaron del control
-- 218, que ya finaliza servicios con exito (regla 25 d).
--
-- Las tildes se comparan por codigo de letra (U&'\00F3' es la o con tilde),
-- no con una tilde escrita en este archivo: si la codificacion estuviera mal,
-- las dos se danyarian igual y la comparacion pasaria sin probar nada.
--
-- Que valida, transaccionalmente:
--   1. Sin motivo, se niega, y el mensaje lleva su tilde.
--   2. Con motivo, corrige: el servicio vuelve a en_proceso.
--   3. La fila del historial dice "Correccion administrativa" CON su tilde.
--   4. Barrido: ninguna funcion de la base tiene ya texto danado.
--   5. Cuenta (sin tocarlas) las filas del historial que ya se guardaron
--      danadas: corregirlas es decision del propietario.
--
-- COMO SE EJECUTA (despues de aplicar la migracion)
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\225_test_las_tildes_de_corregir_servicio.sql"
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
  v_memb       uuid;
  v_cliente    uuid;
  v_ticket     uuid;
  v_ts         uuid;
  v_slot       timestamptz;
  v_manana     date;
  v_estado     text;
  v_motivo     text;
  v_capturo    boolean;
  v_error      text;
  v_danadas    text;
  v_filas      integer;
begin
  -- ---------------------------------------------------------------- fixtures
  select id into v_plan from public.plans where status = 'active' limit 1;
  if v_plan is null then
    raise exception 'FALLO: no hay ningun plan activo con el que probar';
  end if;

  insert into auth.users (id, email) values (v_dueno, 'dueno_test225@salonymas.com')
  on conflict (id) do nothing;

  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 225', 'peluqueria', 'c225@salonymas.com', '3000000227', true)
  returning id into v_tenant;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_tenant, v_plan, 'active', now() + interval '30 days');

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C225 sede', 'c225-sede', true, true)
  returning id into v_branch;

  insert into public.business_hours (tenant_id, branch_id, day_of_week, opens_at, closes_at, is_open)
  select v_tenant, v_branch, d, time '06:00', time '22:00', true from generate_series(1, 7) d;

  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_dueno, 'tenant_owner', true)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);
  insert into public.user_profiles (tenant_id, user_id, full_name, role, active)
  values (v_tenant, v_dueno, 'C225 duenyo', 'owner', true);

  insert into public.services (tenant_id, name, category, duration_minutes, price, visible_to_customer)
  values (v_tenant, 'C225 corte', 'Corte', 30, 20000, true) returning id into v_service;
  insert into public.branch_services (
    tenant_id, branch_id, service_id, price, duration_minutes, visible_to_customer, active
  ) values (v_tenant, v_branch, v_service, 20000, 30, true, true)
  returning id into v_bservice;

  insert into public.stylists (tenant_id, name, phone, specialty)
  values (v_tenant, 'C225 estilista', '3000000228', 'Corte')
  returning id into v_stylist;
  insert into public.branch_stylists (tenant_id, branch_id, stylist_id, active, starts_at)
  values (v_tenant, v_branch, v_stylist, true, now() - interval '1 day')
  returning id into v_bstylist;
  insert into public.branch_stylist_services (
    tenant_id, branch_id, branch_stylist_id, branch_service_id, active
  ) values (v_tenant, v_branch, v_bstylist, v_bservice, true);

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);

  select c.id into v_cliente from public.create_client('C225 Clienta', '3181112255') c;

  v_manana := ((now() at time zone 'America/Bogota')::date + 1);
  select s.starts_at into v_slot
  from public.public_get_available_slots(v_branch, v_service, v_stylist, v_manana) s
  order by s.starts_at limit 1;

  select t.id into v_ticket
  from public.create_scheduled_ticket_with_service_v2(
    v_branch, v_cliente, v_service, v_stylist, v_slot, 'manual', 'control 225') t;

  perform 1 from public.change_ticket_status_v2(v_branch, v_ticket, 'confirmado', null);

  select m.ticket_service_id into v_ts
  from public.get_ticket_services_for_management_v2(v_branch, v_ticket) m
  limit 1;

  -- Se atiende y se termina, como en el 218: el ticket queda finalizado.
  perform 1 from public.change_ticket_service_status_v2(v_branch, v_ts, 'en_proceso');
  perform 1 from public.change_ticket_service_status_v2(v_branch, v_ts, 'finalizado');

  select t.status into v_estado from public.tickets t where t.id = v_ticket;
  if v_estado <> 'finalizado' then
    raise exception 'FALLO: el fixture no dejo el ticket finalizado (quedo en %). No se puede probar la correccion.', v_estado;
  end if;

  -- 1. Sin motivo se niega, con su tilde
  v_capturo := false;
  begin
    perform 1 from public.reopen_finished_ticket_service_v2(v_branch, v_ts, '');
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;
  if not v_capturo then
    raise exception 'FALLO 1: se corrigio un servicio finalizado sin motivo.';
  end if;
  if position(U&'correcci\00F3n' in v_error) = 0 then
    raise exception 'FALLO 1b: se nego, pero el mensaje no lleva su tilde: %', v_error;
  end if;
  raise notice 'OK 1   sin motivo se niega, y el mensaje lleva su tilde';

  -- 2. Con motivo, corrige
  perform 1 from public.reopen_finished_ticket_service_v2(v_branch, v_ts, 'control 225: se cobro de mas');

  select ts.status into v_estado from public.ticket_services ts where ts.id = v_ts;
  if v_estado <> 'en_proceso' then
    raise exception 'FALLO 2: el servicio corregido quedo en % y no en en_proceso.', v_estado;
  end if;
  raise notice 'OK 2   con motivo, el servicio vuelve a en_proceso';

  -- 3. El historial, con su tilde
  select th.reason into v_motivo
  from public.ticket_history th
  where th.ticket_id = v_ticket
    and th.previous_status = 'finalizado'
    and th.new_status = 'en_proceso'
  order by th.created_at desc
  limit 1;

  if v_motivo is null then
    raise exception 'FALLO 3: la correccion no dejo fila en el historial del ticket.';
  end if;
  if position(U&'Correcci\00F3n administrativa: ' in v_motivo) <> 1 then
    raise exception 'FALLO 3b: el historial dice "%" y debia empezar por "Correccion administrativa" con su tilde.', v_motivo;
  end if;
  raise notice 'OK 3   el historial del ticket dice "Correccion administrativa" con su tilde';

  -- 4. Ninguna funcion danada
  select string_agg(n.nspname || '.' || p.proname, ', ' order by p.proname)
    into v_danadas
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname in ('public', 'private')
    and p.prokind = 'f'
    and pg_get_functiondef(p.oid) ~ U&'\00C3[\00A0-\00BF]';
  if v_danadas is not null then
    raise exception 'FALLO 4: siguen con tildes danadas: %', v_danadas;
  end if;
  raise notice 'OK 4   ninguna funcion de la base tiene ya texto danado';

  -- 5. Las filas viejas, contadas y sin tocar
  select count(*) into v_filas
  from public.ticket_history th
  where th.reason ~ U&'\00C3[\00A0-\00BF]';
  raise notice 'INFO 5  filas del historial guardadas con tildes danadas antes de hoy: %. No se tocan: es decision del propietario.', v_filas;

  raise notice '--- CONTROL 225: 4/4 y el recuento ---';
end
$ctrl$;

rollback;
