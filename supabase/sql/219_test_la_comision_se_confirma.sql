-- CONTROL 219: La comision nace sin confirmar, y se nota. Hallazgo AJ.
--
-- POR QUE ESTE ARCHIVO
--
-- Un salon nacia con una comision del 40% que nadie le pedia confirmar, y esa
-- cifra decide lo que gana una persona. No es una cifra en un default de
-- tabla: el 18-sep se cobro un servicio de $18.000 y en el panel del estilista
-- aparecieron **$7.200**. Una cuenta por pagar, generada sin que nadie la
-- aprobara nunca.
--
-- Lo que se midio antes de tocar nada: **3 politicas en la base, las 3 en el
-- 40%, 0 tocadas desde que nacieron**.
--
-- **La decision fue avisar, no bloquear.** Se descarto que naciera en 0%: eso
-- tambien es un numero inventado, solo que mas barato para el salon y igual de
-- silencioso para el estilista. Asi que este control comprueba las dos cosas a
-- la vez -- **que avise, y que NO bloquee**.
--
-- Que valida, transaccionalmente:
--   1. La columna y las tres funciones existen.
--   2. **Un salon recien registrado nace con la comision sin confirmar.**
--   3. Y aun asi **cobra y paga comision igual**: AJ no rompe la operacion.
--   4. *Primeros pasos* son **cinco**, y el quinto esta sin marcar.
--   5. El lector del duenyo dice que no esta confirmada.
--   6. **El estilista tambien puede saberlo**, sin ver el porcentaje.
--   7. Guardar la comision la confirma, aunque no se cambie ni un numero.
--   8. Ya confirmada, el quinto paso se marca y la lista se termina.
--   9. La recepcion NO puede confirmarla: es de duenyo y admin.
--
-- COMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\219_test_la_comision_se_confirma.sql"
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
  v_elestilista uuid := gen_random_uuid();
  v_memb       uuid;
  v_cliente    uuid;
  v_ticket     uuid;
  v_ts         uuid;
  v_slot       timestamptz;
  v_manana     date;
  v_precio     numeric := 30000;
  v_confirmada timestamptz;
  v_marcado    boolean;
  v_totales    integer;
  v_completos  integer;
  v_comisiones integer;
  v_valor      numeric;
  v_capturo    boolean;
  v_error      text;
begin
  -- 1. Existe lo que AJ crea
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'commission_policies'
      and column_name = 'confirmed_at'
  ) then
    raise exception 'FALLO 1: falta la columna commission_policies.confirmed_at';
  end if;
  if to_regprocedure('public.my_commission_policy_is_confirmed()') is null then
    raise exception 'FALLO 1b: falta my_commission_policy_is_confirmed';
  end if;
  raise notice 'OK 1   la columna y la funcion del estilista existen';

  -- ---------------------------------------------------------------- fixtures
  select id into v_plan from public.plans where status = 'active' limit 1;
  if v_plan is null then
    raise exception 'FALLO: no hay ningun plan activo con el que probar';
  end if;

  insert into auth.users (id, email) values (v_dueno, 'dueno_test219@salonymas.com')
  on conflict (id) do nothing;
  insert into auth.users (id, email) values (v_recepcion, 'recepcion_test219@salonymas.com')
  on conflict (id) do nothing;
  insert into auth.users (id, email) values (v_elestilista, 'estilista_test219@salonymas.com')
  on conflict (id) do nothing;

  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 219', 'spa', 'c219@salonymas.com', '3000000219', true)
  returning id into v_tenant;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_tenant, v_plan, 'active', now() + interval '30 days');

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C219 sede', 'c219-sede', true, true)
  returning id into v_branch;

  insert into public.business_hours (tenant_id, branch_id, day_of_week, opens_at, closes_at, is_open)
  select v_tenant, v_branch, d, time '06:00', time '22:00', true from generate_series(1, 7) d;

  -- EL CASO DEL HALLAZGO: se inserta como lo hace `register_tenant`, con una
  -- sola columna. Todo lo demas -- incluido el 40 -- lo pone el default.
  insert into public.commission_policies (tenant_id) values (v_tenant);

  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_dueno, 'tenant_owner', true) returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);
  insert into public.user_profiles (tenant_id, user_id, full_name, role, active)
  values (v_tenant, v_dueno, 'C219 duenyo', 'owner', true);

  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_recepcion, 'assistant', true) returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);
  insert into public.user_profiles (tenant_id, user_id, full_name, role, active)
  values (v_tenant, v_recepcion, 'C219 recepcion', 'assistant', true);

  insert into public.services (tenant_id, name, category, duration_minutes, price, visible_to_customer)
  values (v_tenant, 'C219 masaje', 'Spa', 60, v_precio, true) returning id into v_service;
  insert into public.branch_services (
    tenant_id, branch_id, service_id, price, duration_minutes, visible_to_customer, active
  ) values (v_tenant, v_branch, v_service, v_precio, 60, true, true)
  returning id into v_bservice;

  insert into public.stylists (tenant_id, name, phone, specialty)
  values (v_tenant, 'C219 estilista', '3000000219', 'Spa') returning id into v_stylist;
  insert into public.branch_stylists (tenant_id, branch_id, stylist_id, active, starts_at)
  values (v_tenant, v_branch, v_stylist, true, now() - interval '1 day')
  returning id into v_bstylist;
  insert into public.branch_stylist_services (
    tenant_id, branch_id, branch_stylist_id, branch_service_id, active
  ) values (v_tenant, v_branch, v_bstylist, v_bservice, true);

  -- El estilista con cuenta, para la comprobacion 6.
  --
  -- `stylist_id` es OBLIGATORIO aqui: `tenant_memberships_stylist_role_check`
  -- exige que una membresia de rol `stylist` apunte a su ficha del catalogo.
  -- **La primera pasada de este control se cayo justo ahi, y el candado tenia
  -- razon**: una membresia de estilista sin estilista no significa nada.
  -- El control 218 no lo toco porque su estilista era, a proposito, uno SIN
  -- cuenta.
  insert into public.tenant_memberships (tenant_id, user_id, role, stylist_id, active)
  values (v_tenant, v_elestilista, 'stylist', v_stylist, true) returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);
  insert into public.user_profiles (tenant_id, user_id, full_name, role, stylist_id, active)
  values (v_tenant, v_elestilista, 'C219 estilista', 'stylist', v_stylist, true);

  -- 2. Nace sin confirmar, y con el 40 heredado
  select cp.confirmed_at into v_confirmada
  from public.commission_policies cp where cp.tenant_id = v_tenant;

  if v_confirmada is not null then
    raise exception 'FALLO 2: la politica nacio ya confirmada. Entonces nadie la mira nunca, que es el hallazgo entero.';
  end if;
  if not exists (
    select 1 from public.commission_policies cp
    where cp.tenant_id = v_tenant
      and cp.commission_type = 'percentage' and cp.commission_percentage = 40
  ) then
    raise exception 'FALLO 2b: el default de la tabla ya no es 40%%. Si cambio, hay que actualizar el texto que ve el duenyo.';
  end if;
  raise notice 'OK 2   la politica nace sin confirmar, con el 40%% heredado del default';

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);

  -- 3. Y aun asi cobra y paga comision: AJ avisa, no bloquea
  select c.id into v_cliente from public.create_client('C219 Clienta', '3191112233') c;

  v_manana := ((now() at time zone 'America/Bogota')::date + 1);
  select s.starts_at into v_slot
  from public.public_get_available_slots(v_branch, v_service, v_stylist, v_manana) s
  order by s.starts_at limit 1;

  select t.id into v_ticket
  from public.create_scheduled_ticket_with_service_v2(
    v_branch, v_cliente, v_service, v_stylist, v_slot, 'manual', 'control 219') t;
  perform 1 from public.change_ticket_status_v2(v_branch, v_ticket, 'confirmado', null);

  select m.ticket_service_id into v_ts
  from public.get_ticket_services_for_management_v2(v_branch, v_ticket) m limit 1;

  perform 1 from public.change_ticket_service_status_v2(v_branch, v_ts, 'en_proceso');
  perform 1 from public.change_ticket_service_status_v2(v_branch, v_ts, 'finalizado');
  perform 1 from public.register_ticket_payment_v2(
    v_branch, v_ticket, v_precio, 'efectivo', null, 'control 219');

  select count(*), coalesce(max(sc.commission_amount), 0)
    into v_comisiones, v_valor
  from public.stylist_commissions sc where sc.ticket_id = v_ticket;

  if v_comisiones <> 1 then
    raise exception
      'FALLO 3: con la comision sin confirmar no nacio ninguna. AJ se decidio para AVISAR, no para bloquear: si esto falla, se rompio la operacion de todos los salones.';
  end if;
  if v_valor <> round(v_precio * 40 / 100) then
    raise exception 'FALLO 3b: la comision quedo en % y el 40%% de % es %.',
      v_valor, v_precio, round(v_precio * 40 / 100);
  end if;
  raise notice 'OK 3   sin confirmar SI se cobra y SI nace comision: avisa, no bloquea';

  -- 4. Primeros pasos son cinco, y el quinto esta sin marcar
  select o.tiene_comision, o.pasos_totales, o.pasos_completos
    into v_marcado, v_totales, v_completos
  from public.get_onboarding_progress(v_branch) o;

  if v_totales <> 5 then
    raise exception 'FALLO 4: Primeros pasos tiene % pasos y deberia tener 5.', v_totales;
  end if;
  if v_marcado then
    raise exception 'FALLO 4b: el quinto paso sale marcado sin que nadie confirmara nada.';
  end if;
  raise notice 'OK 4   Primeros pasos son cinco, y el de la comision esta sin marcar (% de 5)', v_completos;

  -- 5. El lector del duenyo lo dice
  select p.confirmed_at into v_confirmada from public.get_commission_policy() p;
  if v_confirmada is not null then
    raise exception 'FALLO 5: get_commission_policy dice que esta confirmada y no lo esta.';
  end if;
  raise notice 'OK 5   el lector del duenyo devuelve confirmed_at nulo';

  -- 6. El estilista tambien puede saberlo, sin ver el porcentaje
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_elestilista::text, 'role', 'authenticated')::text, true);

  if public.my_commission_policy_is_confirmed() then
    raise exception 'FALLO 6: el estilista ve la comision como confirmada. Es quien tiene el dinero en juego y el unico que veia la cifra.';
  end if;

  -- Y no puede leer el porcentaje: eso es de duenyo y admin.
  v_capturo := false;
  begin
    perform 1 from public.get_commission_policy();
  exception when others then
    v_capturo := true;
  end;
  if not v_capturo then
    raise exception 'FALLO 6b: el estilista pudo leer la politica entera del salon. Solo le corresponde saber SI la aprobaron, no cuanto es.';
  end if;
  raise notice 'OK 6   el estilista sabe que no esta confirmada, y no ve el porcentaje';

  -- 7. Guardar la confirma, aunque no cambie ningun numero
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);

  perform public.update_commission_policy(
    v_branch, 'percentage', 40, 0, true, null);

  select cp.confirmed_at into v_confirmada
  from public.commission_policies cp where cp.tenant_id = v_tenant;

  if v_confirmada is null then
    raise exception
      'FALLO 7: se guardo la comision y sigue sin confirmar. Volver a mirar la cifra y dejarla igual TAMBIEN es aprobarla; exigir un cambio obligaria a inventarlo.';
  end if;
  raise notice 'OK 7   guardar la comision la confirma, aunque no cambie ningun numero';

  -- 8. Ya confirmada, el quinto paso se marca
  select o.tiene_comision, o.pasos_completos
    into v_marcado, v_completos
  from public.get_onboarding_progress(v_branch) o;

  if not v_marcado then
    raise exception 'FALLO 8: confirmada y el quinto paso sigue sin marcar.';
  end if;
  if v_completos <> 5 then
    raise exception 'FALLO 8b: con todo hecho el conteo dice % de 5.', v_completos;
  end if;
  raise notice 'OK 8   confirmada, el quinto paso se marca y la lista se termina (5 de 5)';

  -- 9. La recepcion no puede confirmarla
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_recepcion::text, 'role', 'authenticated')::text, true);

  v_capturo := false;
  begin
    perform public.update_commission_policy(v_branch, 'percentage', 90, 0, true, null);
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;

  if not v_capturo then
    raise exception 'FALLO 9: la recepcion cambio la comision del salon. Cobrar es suyo (D-092); decidir sueldos no.';
  end if;
  raise notice 'OK 9   la recepcion no puede tocar la comision';

  raise notice ' ';
  raise notice 'CONTROL 219: 9 de 9 en verde';
end
$ctrl$;

rollback;
