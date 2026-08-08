-- Salon y Mas - Poner en marcha "Unas Naguara" y repartir la semilla (D-112).
--
-- HALLAZGO QUE ORIGINA ESTE ARCHIVO
--
-- El propietario pregunto si la semilla habia llegado tambien a su segunda
-- sede. No, y al mirar por que aparecio algo mas util: **"Unas Naguara" se creo
-- el 27 de julio y nunca se configuro**. Cero estilistas, cero servicios, cero
-- citas. Un local con la puerta abierta y sin nadie adentro: no se podia
-- agendar nada ahi, ni desde el panel ni desde el enlace publico.
--
-- POR QUE SE REHACE LA SEMILLA EN VEZ DE MOVERLA
--
-- El primer intento trataba de mudar un tercio de las citas a la otra sede. La
-- base lo rechazo: *"La sede de un registro operacional existente no puede
-- cambiarse directamente"*. **Es una proteccion deliberada y correcta** -- un
-- cobro que cambia de sede quedaria contado donde nunca se atendio, y ningun
-- cierre de caja cuadraria despues.
--
-- Asi que la semilla anterior se borra entera y se vuelve a sembrar con la
-- sede decidida desde el nacimiento de cada cita. Se puede borrar porque esta
-- marcada `SEMILLA_DEMO`: las 30 citas reales no llevan esa marca y no se
-- tocan.
--
-- COMO SE EVITA QUE UN ESTILISTA ESTE EN DOS SITIOS A LA VEZ
--
-- Hay una regla que impide agendar al mismo estilista en dos sedes al mismo
-- tiempo. En vez de pelear con ella, la semilla la respeta por diseno: **cada
-- estilista trabaja en UNA sola sede cada dia**, repartiendo la semana entre
-- las dos. Es ademas como funciona de verdad quien tiene dos locales.
--
-- A la segunda sede le toca alrededor de un tercio del movimiento, no la
-- mitad: dos sedes identicas no ensenan nada, y lo que de verdad quiere saber
-- un dueno de dos locales es cual va mejor.

begin;

do $$
declare
  v_tenant uuid;
  v_principal uuid;
  v_segunda uuid;
  v_creador uuid;
  v_total integer;
  v_en_segunda integer;
begin
  select t.id into v_tenant
  from public.tenants t
  where t.contact_email = 'elboga002@gmail.com'
  limit 1;

  if v_tenant is null then
    raise notice 'No es el proyecto de pruebas. No se hace nada.';
    return;
  end if;

  select b.id into v_principal
  from public.branches b
  where b.tenant_id = v_tenant and b.active and b.is_primary
  limit 1;

  select b.id into v_segunda
  from public.branches b
  where b.tenant_id = v_tenant and b.active and not b.is_primary
  order by b.created_at
  limit 1;

  select up.user_id into v_creador
  from public.user_profiles up
  where up.tenant_id = v_tenant and up.role = 'owner' and up.active
  limit 1;

  if v_principal is null or v_segunda is null or v_creador is null then
    raise notice 'Falta la segunda sede o el propietario. No se hace nada.';
    return;
  end if;

  -- -------------------------------------------------------------------------
  -- 1. Dejar operativa la segunda sede.
  --
  -- Los servicios se copian de la sede principal y no del catalogo general,
  -- porque `branch_services` admite precio y duracion propios por sede: leer
  -- del catalogo perderia cualquier ajuste que el negocio ya hubiera hecho.
  -- -------------------------------------------------------------------------
  insert into public.branch_services (
    tenant_id, branch_id, service_id, price, duration_minutes,
    booking_interval_minutes, visible_to_customer, active
  )
  select
    bs.tenant_id, v_segunda, bs.service_id, bs.price, bs.duration_minutes,
    bs.booking_interval_minutes, bs.visible_to_customer, true
  from public.branch_services bs
  where bs.tenant_id = v_tenant
    and bs.branch_id = v_principal
    and bs.active
    and not exists (
      select 1 from public.branch_services x
      where x.tenant_id = v_tenant
        and x.branch_id = v_segunda
        and x.service_id = bs.service_id
    );

  -- `starts_at` en febrero y no hoy a proposito: la historia sembrada arranca
  -- ahi, y un estilista que atiende citas de marzo pero figura vinculado en
  -- agosto es una incoherencia que saldria justo al construir la vista de
  -- Equipo.
  insert into public.branch_stylists (
    tenant_id, branch_id, stylist_id, active, starts_at
  )
  select
    v_tenant, v_segunda, bst.stylist_id, true, timestamptz '2026-02-01 00:00:00-05'
  from public.branch_stylists bst
  where bst.tenant_id = v_tenant
    and bst.branch_id = v_principal
    and bst.active
    and not exists (
      select 1 from public.branch_stylists x
      where x.tenant_id = v_tenant
        and x.branch_id = v_segunda
        and x.stylist_id = bst.stylist_id
    );

  insert into public.branch_stylist_services (
    tenant_id, branch_id, branch_stylist_id, branch_service_id, active
  )
  select v_tenant, v_segunda, bst.id, bs.id, true
  from public.branch_stylists bst
  cross join public.branch_services bs
  where bst.tenant_id = v_tenant and bst.branch_id = v_segunda and bst.active
    and bs.tenant_id = v_tenant and bs.branch_id = v_segunda and bs.active
    and not exists (
      select 1 from public.branch_stylist_services x
      where x.branch_stylist_id = bst.id
        and x.branch_service_id = bs.id
    );

  -- -------------------------------------------------------------------------
  -- 2. Borrar la semilla anterior. En orden: cobros, servicios, citas.
  --    Las clientas sembradas se conservan y se reutilizan.
  -- -------------------------------------------------------------------------
  delete from public.ticket_payments tp
  using public.tickets t
  where t.id = tp.ticket_id
    and t.tenant_id = v_tenant
    and t.notes = 'SEMILLA_DEMO';

  delete from public.ticket_services ts
  using public.tickets t
  where t.id = ts.ticket_id
    and t.tenant_id = v_tenant
    and t.notes = 'SEMILLA_DEMO';

  delete from public.tickets
  where tenant_id = v_tenant and notes = 'SEMILLA_DEMO';

  -- -------------------------------------------------------------------------
  -- 3. Volver a sembrar, con la sede decidida de entrada.
  -- -------------------------------------------------------------------------
  create temp table semilla_plan on commit drop as
  with dias as (
    select d::date as dia
    from generate_series(date '2026-02-01', date '2026-07-20', interval '1 day') d
    where extract(dow from d) <> 0            -- los domingos no se trabaja
  ),
  estilistas as (
    select s.id, (row_number() over (order by s.id))::int as n
    from public.stylists s
    where s.tenant_id = v_tenant and s.active
  ),
  catalogo as (
    select s.id, s.price, s.duration_minutes,
           (row_number() over (order by s.id) - 1)::int as n,
           count(*) over () as total
    from public.services s
    where s.tenant_id = v_tenant and s.active
  ),
  rejilla as (
    select
      d.dia,
      e.id as stylist_id,
      e.n as estilista_n,
      h.hora,
      abs(hashtext(d.dia::text || e.id::text || h.hora::text)) as az
    from dias d
    cross join estilistas e
    cross join (values (9), (11), (13), (15), (17)) as h(hora)
  )
  select
    gen_random_uuid() as ticket_id,
    r.dia,
    r.stylist_id,
    ((r.dia + (r.hora || ' hours')::interval) at time zone 'America/Bogota') as cuando,
    c.id as service_id,
    c.price,
    c.duration_minutes,
    -- **La clave de todo el archivo.** La sede depende del dia y del
    -- estilista, nunca del azar de cada cita: asi un estilista pasa el dia
    -- entero en una sola sede y es imposible que quede agendado en dos sitios
    -- a la vez. Uno de cada tres dias va a la sede nueva.
    case
      when (extract(dow from r.dia)::int + r.estilista_n) % 3 = 0
        then v_segunda
      else v_principal
    end as branch_id,
    case
      when r.az % 100 < 74 then 'cerrado'
      when r.az % 100 < 84 then 'finalizado'
      when r.az % 100 < 93 then 'cancelado'
      else 'no_asistio'
    end as estado,
    case when r.az % 5 = 0 then 'web_publico' else 'manual' end as canal,
    case (r.az / 7) % 4
      when 0 then 'efectivo' when 1 then 'tarjeta'
      when 2 then 'transferencia' else 'efectivo'
    end as metodo
  from rejilla r
  join catalogo c on c.n = (r.az / 13) % c.total
  where (r.az % 100) < (
    22
    + (extract(month from r.dia)::int - 2) * 5
    + case extract(dow from r.dia)::int when 5 then 18 when 6 then 26 else 0 end
  );

  insert into public.tickets
    (id, tenant_id, client_id, created_at, scheduled_at, status, channel, notes, branch_id)
  select
    p.ticket_id,
    v_tenant,
    (
      select c.id from public.clients c
      where c.tenant_id = v_tenant and c.notes = 'SEMILLA_DEMO'
      order by md5(c.id::text || p.ticket_id::text)
      limit 1
    ),
    p.cuando - interval '3 days',
    p.cuando,
    p.estado,
    p.canal,
    'SEMILLA_DEMO',
    p.branch_id
  from semilla_plan p;

  insert into public.ticket_services
    (tenant_id, ticket_id, service_id, stylist_id, created_at, price, duration_minutes, status, branch_id)
  select
    v_tenant, p.ticket_id, p.service_id, p.stylist_id,
    p.cuando - interval '3 days',
    p.price, p.duration_minutes,
    case
      when p.estado = 'cancelado' then 'cancelado'
      when p.estado = 'no_asistio' then 'pendiente'
      else 'finalizado'
    end,
    p.branch_id
  from semilla_plan p;

  -- Solo se cobra lo cerrado. Lo "finalizado" queda sin cobrar a proposito:
  -- es el "por cobrar" que el Dashboard distingue de las ventas.
  insert into public.ticket_payments
    (tenant_id, ticket_id, amount, method, notes, status, received_at, created_by, created_at, branch_id)
  select
    v_tenant, p.ticket_id, p.price, p.metodo, 'SEMILLA_DEMO', 'registrado',
    p.cuando + (p.duration_minutes || ' minutes')::interval,
    v_creador,
    p.cuando + (p.duration_minutes || ' minutes')::interval,
    p.branch_id
  from semilla_plan p
  where p.estado = 'cerrado';

  select count(*), count(*) filter (where branch_id = v_segunda)
    into v_total, v_en_segunda
  from semilla_plan;

  raise notice 'Semilla repartida: % citas, % en la sede nueva.',
    v_total, v_en_segunda;
end;
$$;

commit;
