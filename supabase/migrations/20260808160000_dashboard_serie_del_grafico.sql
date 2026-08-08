-- Salon y Mas - Serie del grafico protagonista del Dashboard (2.5a, D-110).
--
-- El Dashboard tiene **un solo grafico** que hace el trabajo de cuatro: el
-- propietario elige si mira Ventas, Citas, Clientes o Ticket promedio y la
-- linea cambia. Por eso esta consulta devuelve **los cuatro a la vez**: cambiar
-- de indicador tiene que ser instantaneo, no un viaje al servidor.
--
-- DOS DECISIONES QUE NO SON OBVIAS:
--
-- 1. **Los dias sin movimiento devuelven cero, no se saltan.** Sin esto, una
--    semana con ventas el lunes y el viernes dibujaria una linea recta entre
--    los dos, escondiendo que el resto de la semana no se vendio nada. Un
--    grafico que oculta los huecos miente mas que no tener grafico. Por eso el
--    `generate_series` y el `left join`.
--
-- 2. **El agrupamiento se decide aqui, segun el largo del rango.** Un ano en
--    dias son 365 puntos apretujados en el ancho de un telefono, ilegibles.
--    Hasta dos meses se agrupa por dia, hasta un ano por semana, y mas alla por
--    mes. La respuesta dice cual uso, para poder escribirlo en pantalla.
--
-- Las definiciones son las mismas de `get_dashboard_overview` y del apartado 3
-- de la especificacion: venta es cobro registrado, cita excluye canceladas,
-- cliente atendido es el que tiene un cobro. Si cambian alli, cambian aqui.

begin;

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
  paid_tickets integer
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

  -- Los cortes salen de cuantos puntos caben legibles en el ancho de un
  -- telefono, no de una regla de calendario: hasta ~62 puntos se leen, mas
  -- alla se convierten en una mancha.
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

  -- El esqueleto completo del rango. Es lo que garantiza que un dia sin
  -- movimiento salga en cero y no desaparezca del grafico.
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
    coalesce(v.paid_tickets, 0)
  from huecos h
  left join ventas v on v.bucket = h.bucket
  left join conteo_citas cc on cc.bucket = h.bucket
  order by h.bucket;
end;
$$;

revoke all on function public.get_dashboard_series(uuid[], date, date)
  from public, anon, authenticated;
grant execute on function public.get_dashboard_series(uuid[], date, date)
  to authenticated;

comment on function public.get_dashboard_series(uuid[], date, date)
  is 'Serie del grafico del Dashboard, con los cuatro indicadores a la vez para que cambiar de uno a otro no vuelva al servidor. Rellena con cero los periodos sin movimiento y agrupa por dia, semana o mes segun el largo del rango.';

commit;
