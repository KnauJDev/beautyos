-- Salon y Mas - Historia de ensayo para el negocio de pruebas (D-112).
--
-- POR QUE EXISTE ESTE ARCHIVO
--
-- El Dashboard de 2.5a se apoya entero en comparar contra el periodo anterior,
-- y "Naguara de Unas" solo tiene historia desde el 27 de julio. Con eso, todos
-- los rangos de mas de un mes responden "faltan N meses de historia": correcto,
-- pero **no se puede ver funcionar lo que se acaba de construir**. Esta
-- semilla da cinco meses y medio hacia atras para poder probarlo de verdad.
--
-- CUATRO GUARDAS, PORQUE ESTO ESCRIBE EN UNA BASE REAL
--
-- 1. Solo corre en el negocio de pruebas, identificado por su correo. En
--    cualquier otro proyecto no hace absolutamente nada. Asi, si algun dia se
--    crea un proyecto limpio para un cliente real, esta migracion pasa de
--    largo en vez de inyectarle citas inventadas.
-- 2. Solo corre una vez. Si ya hay semilla, se sale.
-- 3. **Solo toca del 1 de febrero al 20 de julio de 2026.** Las citas reales
--    empiezan el 27 de julio y llegan hasta diciembre: no se pisa ninguna.
-- 4. Todo queda marcado con `SEMILLA_DEMO` en las notas, para poder borrarlo
--    de un golpe el dia que estorbe.
--
-- SIN CHOQUES DE AGENDA
--
-- `enforce_ticket_service_schedule_conflict` rechaza dos citas superpuestas del
-- mismo estilista. Por eso las citas se colocan en una rejilla de horas fijas
-- --9, 11, 13, 15 y 17-- que deja dos horas por hueco: el servicio mas largo
-- del catalogo dura 90 minutos, asi que nunca se solapan.
--
-- LO QUE ESTA SEMILLA NO HACE, Y HAY QUE SABERLO
--
-- No genera comisiones ni movimientos de inventario, porque inserta directo en
-- las tablas en vez de pasar por las funciones de negocio. Los cuatro
-- indicadores del Dashboard no las usan, pero **el "Resultado estimado" de la
-- vista de Negocio saldra alto** para este periodo: le faltara restar
-- comisiones. Es aceptable en un negocio de ensayo y queda advertido aqui.

begin;

do $$
declare
  v_tenant uuid;
  v_branch uuid;
  v_creador uuid;
  v_creadas integer;
begin
  -- Guarda 1: el negocio de pruebas, y solo ese.
  select t.id into v_tenant
  from public.tenants t
  where t.contact_email = 'elboga002@gmail.com'
  limit 1;

  if v_tenant is null then
    raise notice 'No es el proyecto de pruebas. La semilla no hace nada.';
    return;
  end if;

  -- Guarda 2: una sola vez.
  if exists (
    select 1 from public.tickets
    where tenant_id = v_tenant and notes = 'SEMILLA_DEMO'
  ) then
    raise notice 'La semilla ya estaba puesta. No se duplica.';
    return;
  end if;

  select b.id into v_branch
  from public.branches b
  where b.tenant_id = v_tenant and b.active
  order by b.is_primary desc, b.id
  limit 1;

  select up.user_id into v_creador
  from public.user_profiles up
  where up.tenant_id = v_tenant and up.role = 'owner' and up.active
  limit 1;

  if v_branch is null or v_creador is null then
    raise notice 'Falta sede o propietario. La semilla no hace nada.';
    return;
  end if;

  -- -------------------------------------------------------------------------
  -- Clientas. Las fechas de alta se reparten por el periodo para que mas
  -- adelante "clientes nuevos vs recurrentes" tenga con que trabajar.
  -- -------------------------------------------------------------------------
  insert into public.clients (tenant_id, name, phone, notes, active, created_at)
  select
    v_tenant,
    nombre,
    '31' || lpad((6000000 + (i * 7919) % 3999999)::text, 8, '0'),
    'SEMILLA_DEMO',
    true,
    timestamptz '2026-02-01 14:00:00+00' + ((i * 5) || ' days')::interval
  from (
    select row_number() over () as i, nombre
    from unnest(array[
      'Marcela Ospina', 'Carolina Restrepo', 'Diana Valencia',
      'Paola Jimenez', 'Sandra Gomez', 'Natalia Cardenas',
      'Luisa Fernanda Rios', 'Angela Betancur', 'Claudia Mejia',
      'Viviana Arango', 'Johana Zapata', 'Tatiana Correa',
      'Manuela Uribe', 'Catalina Henao', 'Adriana Molina',
      'Yuliana Ceballos', 'Estefania Duque', 'Milena Salazar',
      'Camila Toro', 'Alejandra Vargas', 'Laura Quintero',
      'Sara Castano', 'Valentina Londono', 'Isabela Marin',
      'Juan Esteban Perez', 'Andres Felipe Gil', 'Santiago Ruiz',
      'Mateo Alzate', 'Sebastian Ochoa', 'Nicolas Herrera'
    ]) as nombre
  ) as fuente;

  -- -------------------------------------------------------------------------
  -- El plan de citas. Se arma primero en una tabla temporal porque los mismos
  -- identificadores se necesitan tres veces: ticket, servicio y cobro.
  --
  -- La aleatoriedad es deterministica (`hashtext`): la misma semilla produce
  -- siempre el mismo negocio, asi que si algo se ve raro se puede reproducir.
  -- -------------------------------------------------------------------------
  create temp table semilla_plan on commit drop as
  with dias as (
    select d::date as dia
    from generate_series(date '2026-02-01', date '2026-07-20', interval '1 day') d
    where extract(dow from d) <> 0            -- los domingos no se trabaja
  ),
  estilistas as (
    select s.id, row_number() over (order by s.id) as n
    from public.stylists s
    where s.tenant_id = v_tenant and s.active
  ),
  catalogo as (
    select s.id, s.price, s.duration_minutes,
           row_number() over (order by s.id) - 1 as n,
           count(*) over () as total
    from public.services s
    where s.tenant_id = v_tenant and s.active
  ),
  rejilla as (
    select
      d.dia,
      e.id as stylist_id,
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
    -- Hora local de Bogota (UTC-5) convertida a instante.
    ((r.dia + (r.hora || ' hours')::interval) at time zone 'America/Bogota') as cuando,
    c.id as service_id,
    c.price,
    c.duration_minutes,
    case
      when r.az % 100 < 74 then 'cerrado'      -- atendida y cobrada
      when r.az % 100 < 84 then 'finalizado'   -- atendida, sin cobrar aun
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
  where
    -- Cuantas de las cinco horas de cada estilista se llenan. Sube con los
    -- meses -- un negocio que arranca y se va llenando -- y los viernes y
    -- sabados van mas cargados, que es como se comporta un salon de verdad.
    (r.az % 100) < (
      22
      + (extract(month from r.dia)::int - 2) * 5
      + case extract(dow from r.dia)::int when 5 then 18 when 6 then 26 else 0 end
    );

  -- -------------------------------------------------------------------------
  -- Las tres inserciones. El orden importa: el ticket antes que su servicio, y
  -- el servicio antes que el cobro.
  -- -------------------------------------------------------------------------
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
    v_branch
  from semilla_plan p;

  insert into public.ticket_services
    (tenant_id, ticket_id, service_id, stylist_id, created_at, price, duration_minutes, status, branch_id)
  select
    v_tenant, p.ticket_id, p.service_id, p.stylist_id,
    p.cuando - interval '3 days',
    p.price, p.duration_minutes,
    -- Los estados de un SERVICIO son otros que los del ticket: solo
    -- pendiente, en_proceso, finalizado y cancelado. Un servicio de una cita
    -- que no se atendio queda 'pendiente', no 'finalizado'.
    case
      when p.estado = 'cancelado' then 'cancelado'
      when p.estado = 'no_asistio' then 'pendiente'
      else 'finalizado'
    end,
    v_branch
  from semilla_plan p;

  -- Solo se cobra lo cerrado. Lo "finalizado" queda a proposito sin cobrar:
  -- es el estado "por cobrar" que el Dashboard distingue de las ventas.
  insert into public.ticket_payments
    (tenant_id, ticket_id, amount, method, notes, status, received_at, created_by, created_at, branch_id)
  select
    v_tenant, p.ticket_id, p.price, p.metodo, 'SEMILLA_DEMO', 'registrado',
    p.cuando + (p.duration_minutes || ' minutes')::interval,
    v_creador,
    p.cuando + (p.duration_minutes || ' minutes')::interval,
    v_branch
  from semilla_plan p
  where p.estado = 'cerrado';

  select count(*) into v_creadas from semilla_plan;
  raise notice 'Semilla puesta: % citas entre febrero y julio de 2026.', v_creadas;
end;
$$;

commit;
