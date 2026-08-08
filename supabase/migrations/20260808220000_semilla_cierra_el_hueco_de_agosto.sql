-- Salon y Mas - Cerrar el hueco del 21 de julio al 7 de agosto (D-112).
--
-- POR QUE FALTABA
--
-- La semilla anterior se detuvo el 20 de julio para no chocar con las citas
-- reales del negocio, que empiezan el 27. Efecto secundario: **agosto solo
-- tiene datos en la sede principal**, porque las 30 citas reales viven todas
-- ahi. Al elegir "Unas Naguara" y el periodo "Este mes", el Dashboard mostraba
-- ceros y un -100 % -- correcto, pero parecia un fallo.
--
-- Este archivo siembra ese tramo para las dos sedes, de modo que el mes en
-- curso tenga movimiento en ambas y el selector de sedes se pueda comparar de
-- verdad.
--
-- COMO CONVIVE CON LAS CITAS REALES
--
-- A partir del 27 de julio hay citas de verdad, y algunas caen justo en las
-- horas de la rejilla. En vez de adivinar cuales, **cada cita nueva se inserta
-- solo si ese estilista no tiene ya algo encima a esa hora** -- da igual si es
-- real o sembrado, y da igual en que sede, porque la regla de choque cruza
-- sedes. Es la misma comprobacion que hace la base, hecha antes de intentarlo:
-- asi la migracion no depende de que el disparador la rechace.
--
-- Todo queda marcado `SEMILLA_DEMO` y se borra con
-- `supabase/sql/160_borrar_semilla_demo.sql`.

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
    raise notice 'Falta sede o propietario. No se hace nada.';
    return;
  end if;

  -- Si el tramo ya tiene semilla, no se duplica.
  if exists (
    select 1 from public.tickets
    where tenant_id = v_tenant
      and notes = 'SEMILLA_DEMO'
      and scheduled_at >= timestamptz '2026-07-21 00:00:00-05'
  ) then
    raise notice 'El tramo ya estaba sembrado. No se duplica.';
    return;
  end if;

  create temp table hueco_plan on commit drop as
  with dias as (
    select d::date as dia
    from generate_series(date '2026-07-21', date '2026-08-07', interval '1 day') d
    where extract(dow from d) <> 0
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
  ),
  candidatas as (
    select
      gen_random_uuid() as ticket_id,
      r.dia,
      r.stylist_id,
      ((r.dia + (r.hora || ' hours')::interval) at time zone 'America/Bogota') as cuando,
      c.id as service_id,
      c.price,
      c.duration_minutes,
      -- Misma regla que la semilla anterior: cada estilista pasa el dia entero
      -- en una sola sede, asi es imposible que quede en dos sitios a la vez.
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
      45
      + case extract(dow from r.dia)::int when 5 then 18 when 6 then 26 else 0 end
    )
  )
  select k.*
  from candidatas k
  -- **La guarda que hace posible este archivo.** Solo pasa si ese estilista
  -- tiene libre esa franja. Se mira contra TODO lo que ya existe -- citas
  -- reales incluidas y en cualquier sede -- porque la regla de choque cruza
  -- sedes.
  where not exists (
    select 1
    from public.ticket_services ts
    join public.tickets t on t.id = ts.ticket_id
    where ts.tenant_id = v_tenant
      and ts.stylist_id = k.stylist_id
      and ts.status <> 'cancelado'
      and t.status <> 'cancelado'
      and t.scheduled_at is not null
      and t.scheduled_at < k.cuando + (k.duration_minutes || ' minutes')::interval
      and k.cuando < t.scheduled_at + (ts.duration_minutes || ' minutes')::interval
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
  from hueco_plan p;

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
  from hueco_plan p;

  insert into public.ticket_payments
    (tenant_id, ticket_id, amount, method, notes, status, received_at, created_by, created_at, branch_id)
  select
    v_tenant, p.ticket_id, p.price, p.metodo, 'SEMILLA_DEMO', 'registrado',
    p.cuando + (p.duration_minutes || ' minutes')::interval,
    v_creador,
    p.cuando + (p.duration_minutes || ' minutes')::interval,
    p.branch_id
  from hueco_plan p
  where p.estado = 'cerrado';

  select count(*), count(*) filter (where branch_id = v_segunda)
    into v_total, v_en_segunda
  from hueco_plan;

  raise notice 'Hueco cerrado: % citas, % en la sede nueva.', v_total, v_en_segunda;
end;
$$;

commit;
