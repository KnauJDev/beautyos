-- Salon y Mas - Horas vendidas (tarea 2.5b, D-110).
--
-- QUE ES Y POR QUE NO ES "OCUPACION"
--
-- En un negocio de servicios **el tiempo es inventario**: una silla vacia dos
-- horas es inventario que se perdio y no vuelve. La forma natural de medirlo
-- seria un porcentaje de ocupacion, y fue lo primero que se penso.
--
-- Se descarto, y esta es la razon: el porcentaje necesita un denominador --
-- cuantas horas habia disponibles -- y **ese dato no existe**. El horario se
-- guarda por negocio, no por profesional, y no hay registro de horas
-- trabajadas ni fichaje. Con lo que hay, un estilista de medio tiempo saldria
-- al 40 % de ocupacion aunque no hubiera tenido un solo hueco libre. Decirle a
-- un dueno que desaprovecho la mitad de su dia cuando trabajo completo no es
-- un error de calculo: es una mentira que arrastra la confianza en todo el
-- tablero.
--
-- Lo que si es cierto sin discusion posible es **el numerador**. Cuantas horas
-- de trabajo se vendieron es un hecho. Y comparadas contra el periodo anterior
-- ya responden la pregunta de fondo: si el negocio se esta llenando o
-- vaciando. Eso es 2.5b. El porcentaje llega cuando existan los horarios por
-- profesional, y entonces este mismo numero pasa a ser su numerador sin
-- rehacer nada.
--
-- DEFINICION EXACTA: suma de la duracion de los servicios no cancelados de los
-- tickets que **se cobraron** dentro del periodo. Se ata al cobro y no al
-- servicio para que cuadre con "Ventas", que tambien es dinero cobrado: si una
-- se contara por lo agendado y la otra por lo cobrado, el ticket promedio por
-- hora daria cifras imposibles.

begin;

-- ---------------------------------------------------------------------------
-- 1. Horas vendidas en el resumen comparado.
-- ---------------------------------------------------------------------------

drop function if exists public.get_dashboard_overview(uuid[], date, date, date, date);

create or replace function public.get_dashboard_overview(
  p_branch_ids uuid[],
  p_from date,
  p_to date,
  p_prev_from date,
  p_prev_to date
)
returns table (
  sales numeric,
  appointments integer,
  clients_served integer,
  paid_tickets integer,
  minutes_sold integer,
  prev_sales numeric,
  prev_appointments integer,
  prev_clients_served integer,
  prev_paid_tickets integer,
  prev_minutes_sold integer,
  first_activity_on date,
  today_on date,
  branches_included integer
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_branches integer;
begin
  if not public.is_owner_or_admin() then
    raise exception 'No autorizado. El Dashboard es de owner o admin.';
  end if;

  if p_from is null or p_to is null
     or p_prev_from is null or p_prev_to is null then
    raise exception 'Los dos rangos del Dashboard son obligatorios.';
  end if;

  if p_to < p_from or p_prev_to < p_prev_from then
    raise exception 'Un rango no puede terminar antes de empezar.';
  end if;

  if (p_to - p_from) > 3660 or (p_prev_to - p_prev_from) > 3660 then
    raise exception 'El rango del Dashboard no puede superar los 10 anos.';
  end if;

  select count(*) into v_branches
  from private.beautyos_dashboard_branches(p_branch_ids);

  if v_branches = 0 then
    raise exception 'No tienes sedes que consultar con ese filtro.';
  end if;

  return query
  with sedes as (
    select * from private.beautyos_dashboard_branches(p_branch_ids)
  ),

  pagos as (
    select
      tp.amount,
      tp.ticket_id,
      tk.client_id,
      (tp.received_at at time zone s.timezone)::date as dia
    from public.ticket_payments tp
    join public.tickets tk
      on tk.id = tp.ticket_id
     and tk.tenant_id = tp.tenant_id
    join sedes s
      on s.branch_id = tk.branch_id
    where tp.status = 'registrado'
  ),

  -- Los tickets cobrados en cada tramo, sin repetir: un ticket con dos abonos
  -- se cobro una vez, y sus horas se venden una vez.
  cobrados_actual as (
    select distinct p.ticket_id from pagos p
    where p.dia between p_from and p_to
  ),
  cobrados_anterior as (
    select distinct p.ticket_id from pagos p
    where p.dia between p_prev_from and p_prev_to
  ),

  minutos_actual as (
    select coalesce(sum(ts.duration_minutes), 0)::integer as m
    from public.ticket_services ts
    join cobrados_actual c on c.ticket_id = ts.ticket_id
    where lower(ts.status) <> 'cancelado'
  ),
  minutos_anterior as (
    select coalesce(sum(ts.duration_minutes), 0)::integer as m
    from public.ticket_services ts
    join cobrados_anterior c on c.ticket_id = ts.ticket_id
    where lower(ts.status) <> 'cancelado'
  ),

  citas as (
    select
      tk.id,
      (tk.scheduled_at at time zone s.timezone)::date as dia
    from public.tickets tk
    join sedes s
      on s.branch_id = tk.branch_id
    where tk.scheduled_at is not null
      and lower(tk.status) <> 'cancelado'
  ),

  actual as (
    select
      coalesce(sum(p.amount), 0)::numeric as sales,
      count(distinct p.ticket_id)::integer as paid_tickets,
      count(distinct p.client_id)::integer as clients_served
    from pagos p
    where p.dia between p_from and p_to
  ),
  actual_citas as (
    select count(distinct c.id)::integer as n
    from citas c
    where c.dia between p_from and p_to
  ),

  anterior as (
    select
      coalesce(sum(p.amount), 0)::numeric as sales,
      count(distinct p.ticket_id)::integer as paid_tickets,
      count(distinct p.client_id)::integer as clients_served
    from pagos p
    where p.dia between p_prev_from and p_prev_to
  ),
  anterior_citas as (
    select count(distinct c.id)::integer as n
    from citas c
    where c.dia between p_prev_from and p_prev_to
  ),

  historia as (
    select least(
      (select min(c.dia) from citas c),
      (select min(p.dia) from pagos p)
    ) as desde
  ),

  reloj as (
    select (now() at time zone s.timezone)::date as hoy
    from sedes s
    order by s.is_primary desc, s.branch_id
    limit 1
  )

  select
    a.sales, ac.n, a.clients_served, a.paid_tickets, ma.m,
    b.sales, bc.n, b.clients_served, b.paid_tickets, mb.m,
    h.desde, r.hoy, v_branches
  from actual a
  cross join actual_citas ac
  cross join minutos_actual ma
  cross join anterior b
  cross join anterior_citas bc
  cross join minutos_anterior mb
  cross join historia h
  cross join reloj r;
end;
$$;

revoke all on function public.get_dashboard_overview(uuid[], date, date, date, date)
  from public, anon, authenticated;
grant execute on function public.get_dashboard_overview(uuid[], date, date, date, date)
  to authenticated;

comment on function public.get_dashboard_overview(uuid[], date, date, date, date)
  is 'Vista 1 del Dashboard: indicadores del periodo y del anterior en un solo viaje, incluidas las horas vendidas. Venta = cobro registrado; cita excluye cancelados; cliente atendido = con cobro; horas vendidas = duracion de los servicios de tickets cobrados.';

-- ---------------------------------------------------------------------------
-- 2. Horas vendidas tambien en la serie del grafico, para que el selector
--    pueda dibujarlas como cualquier otro indicador.
-- ---------------------------------------------------------------------------

drop function if exists public.get_dashboard_series(uuid[], date, date);

create or replace function public.get_dashboard_series(
  p_branch_ids uuid[],
  p_from date,
  p_to date
)
returns table (
  bucket_on date,
  granularity text,
  sales numeric,
  appointments integer,
  clients_served integer,
  paid_tickets integer,
  minutes_sold integer
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_dias integer;
  v_grano text;
begin
  if not public.is_owner_or_admin() then
    raise exception 'No autorizado. El Dashboard es de owner o admin.';
  end if;

  if p_from is null or p_to is null then
    raise exception 'El rango del grafico es obligatorio.';
  end if;

  if p_to < p_from then
    raise exception 'Un rango no puede terminar antes de empezar.';
  end if;

  v_dias := (p_to - p_from) + 1;

  if v_dias > 3660 then
    raise exception 'El rango del Dashboard no puede superar los 10 anos.';
  end if;

  if not exists (
    select 1 from private.beautyos_dashboard_branches(p_branch_ids)
  ) then
    raise exception 'No tienes sedes que consultar con ese filtro.';
  end if;

  v_grano := case
    when v_dias <= 62 then 'day'
    when v_dias <= 366 then 'week'
    else 'month'
  end;

  return query
  with sedes as (
    select * from private.beautyos_dashboard_branches(p_branch_ids)
  ),

  pagos as (
    select
      tp.amount,
      tp.ticket_id,
      tk.client_id,
      date_trunc(v_grano, (tp.received_at at time zone s.timezone))::date as bucket
    from public.ticket_payments tp
    join public.tickets tk
      on tk.id = tp.ticket_id
     and tk.tenant_id = tp.tenant_id
    join sedes s
      on s.branch_id = tk.branch_id
    where tp.status = 'registrado'
      and (tp.received_at at time zone s.timezone)::date between p_from and p_to
  ),

  -- Un ticket con dos abonos en el mismo tramo cuenta sus horas una sola vez.
  cobrados as (
    select distinct p.ticket_id, p.bucket from pagos p
  ),

  minutos as (
    select c.bucket, coalesce(sum(ts.duration_minutes), 0)::integer as m
    from cobrados c
    join public.ticket_services ts on ts.ticket_id = c.ticket_id
    where lower(ts.status) <> 'cancelado'
    group by c.bucket
  ),

  citas as (
    select
      tk.id,
      date_trunc(v_grano, (tk.scheduled_at at time zone s.timezone))::date as bucket
    from public.tickets tk
    join sedes s
      on s.branch_id = tk.branch_id
    where tk.scheduled_at is not null
      and lower(tk.status) <> 'cancelado'
      and (tk.scheduled_at at time zone s.timezone)::date between p_from and p_to
  ),

  huecos as (
    select generate_series(
      date_trunc(v_grano, p_from::timestamp)::date,
      date_trunc(v_grano, p_to::timestamp)::date,
      ('1 ' || v_grano)::interval
    )::date as bucket
  ),

  ventas as (
    select
      p.bucket,
      sum(p.amount)::numeric as sales,
      count(distinct p.ticket_id)::integer as paid_tickets,
      count(distinct p.client_id)::integer as clients_served
    from pagos p
    group by p.bucket
  ),

  conteo_citas as (
    select c.bucket, count(distinct c.id)::integer as n
    from citas c
    group by c.bucket
  )

  select
    h.bucket,
    v_grano,
    coalesce(v.sales, 0)::numeric,
    coalesce(cc.n, 0),
    coalesce(v.clients_served, 0),
    coalesce(v.paid_tickets, 0),
    coalesce(m.m, 0)
  from huecos h
  left join ventas v on v.bucket = h.bucket
  left join conteo_citas cc on cc.bucket = h.bucket
  left join minutos m on m.bucket = h.bucket
  order by h.bucket;
end;
$$;

revoke all on function public.get_dashboard_series(uuid[], date, date)
  from public, anon, authenticated;
grant execute on function public.get_dashboard_series(uuid[], date, date)
  to authenticated;

comment on function public.get_dashboard_series(uuid[], date, date)
  is 'Serie del grafico del Dashboard con los cinco indicadores a la vez, horas vendidas incluidas. Rellena con cero los periodos sin movimiento y agrupa por dia, semana o mes segun el largo del rango.';

commit;
