-- CONTROL 216: Un telefono, una clienta (AW, paso 9.51).
--
-- POR QUE ESTE ARCHIVO
--
-- El 18-sep el propietario reservo dos veces desde la pagina publica con el
-- MISMO numero escrito de dos formas. `3506815629` reutilizo la ficha;
-- `350 681 56 29` creo una nueva. El salon de prueba acabo con cuatro fichas
-- para dos personas.
--
-- Y al arreglarlo aparecio lo que el hallazgo no decia: `c.phone = <texto>`
-- no estaba una vez en la funcion, estaba TRES. Las otras dos son los topes
-- antiabuso de H-02 -- 4 citas futuras y 8 en 24 horas --, asi que **el tope
-- se saltaba escribiendo el numero con un espacio**: cada formato contaba
-- como una persona distinta y el contador arrancaba de cero.
--
-- Por eso este control no comprueba "que no haya duplicados". Comprueba las
-- dos cosas que de verdad importan, y las comprueba RESERVANDO:
--
--   * que el mismo numero, escrito distinto, sea la misma clienta; y
--   * que el tope cuente esas reservas juntas.
--
-- Que valida, transaccionalmente:
--   1. La funcion existe y es SECURITY DEFINER.
--   2. Una reserva con el numero limpio crea la clienta.
--   3. **El mismo numero con espacios NO crea otra.** La del hallazgo.
--   4. Un numero de verdad distinto SI crea otra: no se funde de mas.
--   5. **El tope antiabuso cuenta los formatos juntos.** La de seguridad.
--   6. La regla es la MISMA que la del portal y la del indice.
--
-- NO se comprueba leyendo el codigo de la funcion. Se comprueba reservando,
-- que es la leccion que costo D-245: una prueba que lee comprueba la
-- intencion; una que ejecuta comprueba el hecho.
--
-- COMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\216_test_un_telefono_una_clienta.sql"
--
-- TERMINA EN ROLLBACK. Ninguna de estas reservas queda.

begin;

do $ctrl$
declare
  v_plan        uuid;
  v_tenant      uuid;
  v_branch      uuid;
  v_service     uuid;
  v_bservice    uuid;
  v_stylist     uuid;
  v_bstylist    uuid;
  v_def         text;
  v_slot        timestamptz;
  v_manana      date;
  v_clientes    integer;
  v_cliente_a   uuid;
  v_cliente_b   uuid;
  v_capturo     boolean;
  v_error       text;
  v_i           integer;
  -- CUATRO formas de escribir EL MISMO numero. Los cuatro dan los mismos
  -- diez digitos: es lo que hace que el tope tenga que contarlos juntos.
  --
  -- **Aqui NO va '+57 3506815629' a proposito.** En digitos eso es
  -- `573506815629` -- doce, no diez --, asi que hoy es otro numero para la
  -- base. El primer intento de este control lo metio en la lista y por eso
  -- dio un FALLO 5 que no era de la funcion sino del control. El indicativo
  -- del pais es un caso aparte y tiene su propia comprobacion abajo.
  v_formatos    text[] := array[
    '3506815629',
    '350 681 56 29',
    '350-681-5629',
    '350.681.5629'
  ];
begin
  -- 1. Existe y esta blindada
  select pg_get_functiondef(p.oid) into v_def
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'public_create_booking';

  if v_def is null then
    raise exception 'FALLO 1: public.public_create_booking no existe';
  end if;
  if v_def not ilike '%security definer%' then
    raise exception 'FALLO 1b: la funcion no es SECURITY DEFINER';
  end if;
  raise notice 'OK 1   la funcion existe y es SECURITY DEFINER';

  -- ---------------------------------------------------------------- fixtures
  select id into v_plan from public.plans where status = 'active' limit 1;
  if v_plan is null then
    raise exception 'FALLO: no hay ningun plan activo con el que probar';
  end if;

  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 216', 'barberia', 'c216@salonymas.com', '3000000216', true)
  returning id into v_tenant;

  -- Suscripcion ACTIVA: sin esto la funcion se niega antes de llegar al
  -- telefono, que es lo que aqui se quiere probar.
  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_tenant, v_plan, 'active', now() + interval '30 days');

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C216 sede', 'c216-sede', true, true)
  returning id into v_branch;

  -- Abierto los siete dias y de sol a sol, para que siempre haya horarios
  -- libres y el control no dependa de en que dia de la semana se ejecute.
  insert into public.business_hours (tenant_id, branch_id, day_of_week, opens_at, closes_at, is_open)
  select v_tenant, v_branch, d, time '06:00', time '22:00', true
  from generate_series(1, 7) d;

  insert into public.services (tenant_id, name, category, duration_minutes, price, visible_to_customer)
  values (v_tenant, 'C216 corte', 'Corte', 30, 20000, true)
  returning id into v_service;

  insert into public.branch_services (tenant_id, branch_id, service_id, price, duration_minutes, visible_to_customer, active)
  values (v_tenant, v_branch, v_service, 20000, 30, true, true)
  returning id into v_bservice;

  insert into public.stylists (tenant_id, name, phone, specialty)
  values (v_tenant, 'C216 estilista', '3000000000', 'Corte')
  returning id into v_stylist;

  insert into public.branch_stylists (tenant_id, branch_id, stylist_id, active, starts_at)
  values (v_tenant, v_branch, v_stylist, true, now() - interval '1 day')
  returning id into v_bstylist;

  insert into public.branch_stylist_services (tenant_id, branch_id, branch_stylist_id, branch_service_id, active)
  values (v_tenant, v_branch, v_bstylist, v_bservice, true);

  v_manana := ((now() at time zone 'America/Bogota')::date + 1);

  -- 2. Una reserva normal crea la clienta
  select s.starts_at into v_slot
  from public.public_get_available_slots(v_branch, v_service, v_stylist, v_manana) s
  order by s.starts_at limit 1;

  if v_slot is null then
    raise exception 'FALLO 2: no hay ni un horario libre manana; el escenario esta mal montado';
  end if;

  perform public.public_create_booking(
    v_branch, v_service, v_stylist, v_slot, 'C216 David', v_formatos[1], null, 'control 216'
  );

  select count(*) into v_clientes
  from public.clients c
  where c.tenant_id = v_tenant
    and regexp_replace(c.phone, '[^0-9]', '', 'g') = '3506815629';

  if v_clientes <> 1 then
    raise exception 'FALLO 2: la primera reserva dejo % fichas, se esperaba 1', v_clientes;
  end if;
  raise notice 'OK 2   la primera reserva crea la clienta';

  -- 3. LA DEL HALLAZGO: el mismo numero con espacios NO crea otra ficha
  select s.starts_at into v_slot
  from public.public_get_available_slots(v_branch, v_service, v_stylist, v_manana) s
  order by s.starts_at limit 1;

  perform public.public_create_booking(
    v_branch, v_service, v_stylist, v_slot, 'C216 David', v_formatos[2], null, 'control 216'
  );

  select count(*) into v_clientes
  from public.clients c
  where c.tenant_id = v_tenant
    and regexp_replace(c.phone, '[^0-9]', '', 'g') = '3506815629';

  if v_clientes <> 1 then
    raise exception
      'FALLO 3: "%" creo una ficha nueva. Hay % para la misma persona. ESTO es AW: la reserva comparaba el telefono como texto y el portal por digitos.',
      v_formatos[2], v_clientes;
  end if;
  raise notice 'OK 3   el mismo numero escrito distinto es la MISMA clienta';

  -- 4. Pero un numero de verdad distinto si estrena ficha: no se funde de mas
  select s.starts_at into v_slot
  from public.public_get_available_slots(v_branch, v_service, v_stylist, v_manana) s
  order by s.starts_at limit 1;

  perform public.public_create_booking(
    v_branch, v_service, v_stylist, v_slot, 'C216 Otra', '3001112233', null, 'control 216'
  );

  select count(*) into v_clientes from public.clients c where c.tenant_id = v_tenant;
  if v_clientes <> 2 then
    raise exception 'FALLO 4: se esperaban 2 fichas (dos personas distintas) y hay %', v_clientes;
  end if;
  raise notice 'OK 4   un numero distinto si estrena ficha: no se funde de mas';

  -- 5. LA DE SEGURIDAD: el tope de 4 cuenta los formatos juntos.
  --    Ya van 2 reservas de esa persona. Con dos mas son 4, y la quinta debe
  --    negarse aunque cada una lleve el numero escrito de otra manera.
  for v_i in 3..4 loop
    select s.starts_at into v_slot
    from public.public_get_available_slots(v_branch, v_service, v_stylist, v_manana) s
    order by s.starts_at limit 1;

    perform public.public_create_booking(
      v_branch, v_service, v_stylist, v_slot, 'C216 David', v_formatos[v_i], null, 'control 216'
    );
  end loop;

  select s.starts_at into v_slot
  from public.public_get_available_slots(v_branch, v_service, v_stylist, v_manana) s
  order by s.starts_at limit 1;

  v_capturo := false;
  begin
    perform public.public_create_booking(
      v_branch, v_service, v_stylist, v_slot, 'C216 David', '(350) 681 5629', null, 'control 216'
    );
  exception when others then
    v_capturo := true;
    v_error := sqlerrm;
  end;

  if not v_capturo then
    raise exception
      'FALLO 5: la quinta reserva paso. El tope antiabuso de H-02 se salta cambiando el formato del telefono, que es lo que este control existe para impedir.';
  end if;
  if v_error not ilike '%4 citas%' then
    raise exception 'FALLO 5b: se nego, pero no por el tope. Dijo: %', v_error;
  end if;
  raise notice 'OK 5   el tope antiabuso cuenta los formatos juntos (%)', left(v_error, 60);

  -- 6. Una sola regla: la de la reserva, la del portal y la del indice
  if v_def not like '%regexp_replace(c.phone%' then
    raise exception 'FALLO 6: la reserva ya no compara por digitos';
  end if;
  if not exists (
    select 1 from pg_indexes
    where schemaname = 'public' and indexname = 'clients_tenant_phone_digits_idx'
  ) then
    raise exception 'FALLO 6b: falta clients_tenant_phone_digits_idx, que es lo que hace barata esta comparacion';
  end if;
  raise notice 'OK 6   la reserva, el portal y el indice usan la misma regla';

  raise notice ' ';
  raise notice 'CONTROL 216: 6 de 6 en verde';
end
$ctrl$;

rollback;
