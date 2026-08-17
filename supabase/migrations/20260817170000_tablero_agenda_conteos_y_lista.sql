-- ==============================================================================
-- Migracion: Funciones RPC del Tablero de Agenda (Fase 4, Paso 4.2 / D-147)
-- ==============================================================================
-- En Salón y Más la Agenda es un Tablero de Control de Tickets (D-101 / D-116),
-- no un calendario tradicional:
--   Nivel 1: Conteo de tickets agrupados por tiempo y estado (Día, Semana, Mes).
--   Nivel 2: Lista ampliada de tickets al tocar cualquier casilla del tablero.
--   Nivel 3: Detalle del ticket y acciones operativas.
--
-- Ambas funciones operan según la zona horaria de la sede (coalesce 'America/Bogota')
-- y validan acceso mediante private.beautyos_resolve_branch_access (D-095/D-131).
-- ==============================================================================

-- 1. get_ticket_board_counts_v2: Conteo y saldos agregados para el Tablero (Nivel 1)
create or replace function public.get_ticket_board_counts_v2(
  p_branch_id uuid,
  p_start_date date,
  p_end_date date,
  p_granularity text default '15min'
)
returns table (
  bucket text,
  status text,
  ticket_count integer,
  total_price numeric,
  total_pending_balance numeric
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_timezone text;
begin
  -- 1. Validar permisos de sede y obtener zona horaria configurada
  select r.tenant_id, coalesce(r.timezone, 'America/Bogota')
    into v_tenant_id, v_timezone
  from private.beautyos_resolve_branch_access(
    p_branch_id,
    array['tenant_owner', 'admin', 'assistant'],
    true
  ) r;

  -- 2. Validar parámetros
  if p_start_date is null or p_end_date is null or p_start_date > p_end_date then
    raise exception 'Rango de fechas invalido.';
  end if;

  if p_granularity not in ('15min', '30min', 'hour', 'day') then
    raise exception 'Granularidad invalida. Valores permitidos: 15min, 30min, hour, day.';
  end if;

  return query
  with ticket_finances as (
    select
      tk.id,
      tk.status,
      tk.scheduled_at,
      case
        when p_granularity = '15min' then
          to_char(
            date_trunc('hour', tk.scheduled_at at time zone v_timezone) +
            (floor(extract(minute from (tk.scheduled_at at time zone v_timezone)) / 15) * interval '15 minute'),
            'HH24:MI'
          )
        when p_granularity = '30min' then
          to_char(
            date_trunc('hour', tk.scheduled_at at time zone v_timezone) +
            (floor(extract(minute from (tk.scheduled_at at time zone v_timezone)) / 30) * interval '30 minute'),
            'HH24:MI'
          )
        when p_granularity = 'hour' then
          to_char(
            date_trunc('hour', tk.scheduled_at at time zone v_timezone),
            'HH24:00'
          )
        else -- 'day'
          to_char((tk.scheduled_at at time zone v_timezone)::date, 'YYYY-MM-DD')
      end as bucket_val,
      coalesce(sum(ts.price) filter (where ts.status <> 'cancelado'), 0)::numeric as ticket_price,
      greatest(
        coalesce(sum(ts.price) filter (where ts.status <> 'cancelado'), 0) -
        coalesce(
          (select sum(tp.amount) from public.ticket_payments tp
           where tp.tenant_id = v_tenant_id and tp.branch_id = p_branch_id
             and tp.ticket_id = tk.id and tp.status = 'registrado'),
          0
        ),
        0
      )::numeric as ticket_pending_balance
    from public.tickets tk
    left join public.ticket_services ts
      on ts.tenant_id = tk.tenant_id
     and ts.branch_id = tk.branch_id
     and ts.ticket_id = tk.id
    where tk.tenant_id = v_tenant_id
      and tk.branch_id = p_branch_id
      and tk.scheduled_at is not null
      and (tk.scheduled_at at time zone v_timezone)::date >= p_start_date
      and (tk.scheduled_at at time zone v_timezone)::date <= p_end_date
    group by tk.id, tk.status, tk.scheduled_at
  )
  select
    tf.bucket_val as bucket,
    tf.status,
    count(*)::integer as ticket_count,
    sum(tf.ticket_price)::numeric as total_price,
    sum(tf.ticket_pending_balance)::numeric as total_pending_balance
  from ticket_finances tf
  group by tf.bucket_val, tf.status
  order by tf.bucket_val asc, tf.status asc;
end;
$$;

-- 2. get_ticket_board_list_v2: Lista ampliada de tickets (Nivel 2)
create or replace function public.get_ticket_board_list_v2(
  p_branch_id uuid,
  p_start_date date,
  p_end_date date,
  p_statuses text[] default null,
  p_bucket text default null,
  p_granularity text default null
)
returns table (
  id uuid,
  ticket_number bigint,
  ticket_code text,
  client_id uuid,
  client_name text,
  client_phone text,
  scheduled_at timestamptz,
  status text,
  channel text,
  service_names text,
  stylist_names text,
  total_price numeric,
  total_duration_minutes integer,
  paid_amount numeric,
  pending_balance numeric,
  payment_status text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_timezone text;
begin
  -- 1. Validar permisos de sede y obtener zona horaria configurada
  select r.tenant_id, coalesce(r.timezone, 'America/Bogota')
    into v_tenant_id, v_timezone
  from private.beautyos_resolve_branch_access(
    p_branch_id,
    array['tenant_owner', 'admin', 'assistant'],
    true
  ) r;

  -- 2. Validar parámetros
  if p_start_date is null or p_end_date is null or p_start_date > p_end_date then
    raise exception 'Rango de fechas invalido.';
  end if;

  if p_granularity is not null and p_granularity not in ('15min', '30min', 'hour', 'day') then
    raise exception 'Granularidad invalida. Valores permitidos: 15min, 30min, hour, day.';
  end if;

  if p_bucket is not null and p_bucket <> '' and p_granularity is null then
    raise exception 'Debe especificar p_granularity cuando filtra por p_bucket.';
  end if;

  return query
  with service_summary as (
    select
      ts.ticket_id,
      coalesce(
        string_agg(distinct s.name, ', ' order by s.name)
          filter (where ts.status <> 'cancelado'),
        'Sin servicios'
      ) as service_names,
      coalesce(
        string_agg(distinct st.name, ', ' order by st.name)
          filter (where ts.status <> 'cancelado'),
        'Sin estilista'
      ) as stylist_names,
      coalesce(
        sum(ts.price) filter (where ts.status <> 'cancelado'),
        0
      )::numeric as total_price,
      coalesce(
        sum(ts.duration_minutes) filter (where ts.status <> 'cancelado'),
        0
      )::integer as total_duration_minutes
    from public.ticket_services ts
    left join public.services s
      on s.tenant_id = ts.tenant_id
     and s.id = ts.service_id
    left join public.stylists st
      on st.tenant_id = ts.tenant_id
     and st.id = ts.stylist_id
    where ts.tenant_id = v_tenant_id
      and ts.branch_id = p_branch_id
    group by ts.ticket_id
  ),
  payment_summary as (
    select
      tp.ticket_id,
      coalesce(sum(tp.amount), 0)::numeric as paid_amount
    from public.ticket_payments tp
    where tp.tenant_id = v_tenant_id
      and tp.branch_id = p_branch_id
      and tp.status = 'registrado'
    group by tp.ticket_id
  ),
  ticket_rows as (
    select
      tk.id,
      tk.ticket_number,
      tk.ticket_code,
      c.id as client_id,
      coalesce(c.name, 'Cliente sin nombre') as client_name,
      coalesce(c.phone, '') as client_phone,
      tk.scheduled_at,
      tk.status,
      tk.channel,
      coalesce(ss.service_names, 'Sin servicios') as service_names,
      coalesce(ss.stylist_names, 'Sin estilista') as stylist_names,
      coalesce(ss.total_price, 0)::numeric as total_price,
      coalesce(ss.total_duration_minutes, 0)::integer as total_duration_minutes,
      coalesce(ps.paid_amount, 0)::numeric as paid_amount,
      greatest(
        coalesce(ss.total_price, 0) - coalesce(ps.paid_amount, 0),
        0
      )::numeric as pending_balance,
      case
        when coalesce(ps.paid_amount, 0) = 0 then 'sin_pago'
        when coalesce(ps.paid_amount, 0) < coalesce(ss.total_price, 0) then 'parcial'
        else 'pagado'
      end as payment_status,
      case
        when p_granularity = '15min' then
          to_char(
            date_trunc('hour', tk.scheduled_at at time zone v_timezone) +
            (floor(extract(minute from (tk.scheduled_at at time zone v_timezone)) / 15) * interval '15 minute'),
            'HH24:MI'
          )
        when p_granularity = '30min' then
          to_char(
            date_trunc('hour', tk.scheduled_at at time zone v_timezone) +
            (floor(extract(minute from (tk.scheduled_at at time zone v_timezone)) / 30) * interval '30 minute'),
            'HH24:MI'
          )
        when p_granularity = 'hour' then
          to_char(
            date_trunc('hour', tk.scheduled_at at time zone v_timezone),
            'HH24:00'
          )
        else
          to_char((tk.scheduled_at at time zone v_timezone)::date, 'YYYY-MM-DD')
      end as bucket_val
    from public.tickets tk
    left join public.clients c
      on c.tenant_id = tk.tenant_id
     and c.id = tk.client_id
     and c.active
    left join service_summary ss on ss.ticket_id = tk.id
    left join payment_summary ps on ps.ticket_id = tk.id
    where tk.tenant_id = v_tenant_id
      and tk.branch_id = p_branch_id
      and tk.scheduled_at is not null
      and (tk.scheduled_at at time zone v_timezone)::date >= p_start_date
      and (tk.scheduled_at at time zone v_timezone)::date <= p_end_date
      and (p_statuses is null or cardinality(p_statuses) = 0 or tk.status = any(p_statuses))
  )
  select
    tr.id,
    tr.ticket_number,
    tr.ticket_code,
    tr.client_id,
    tr.client_name,
    tr.client_phone,
    tr.scheduled_at,
    tr.status,
    tr.channel,
    tr.service_names,
    tr.stylist_names,
    tr.total_price,
    tr.total_duration_minutes,
    tr.paid_amount,
    tr.pending_balance,
    tr.payment_status
  from ticket_rows tr
  where (p_bucket is null or p_bucket = '' or tr.bucket_val = p_bucket)
  order by tr.scheduled_at asc, tr.ticket_number asc;
end;
$$;

-- Permisos y Comentarios
revoke all on function public.get_ticket_board_counts_v2(uuid, date, date, text) from public, anon;
grant execute on function public.get_ticket_board_counts_v2(uuid, date, date, text) to authenticated, service_role;

revoke all on function public.get_ticket_board_list_v2(uuid, date, date, text[], text, text) from public, anon;
grant execute on function public.get_ticket_board_list_v2(uuid, date, date, text[], text, text) to authenticated, service_role;

comment on function public.get_ticket_board_counts_v2 is
  'Conteo agrupado de tickets por tramos de tiempo y estado para el Tablero de Agenda (D-101/D-147).';

comment on function public.get_ticket_board_list_v2 is
  'Listado detallado de tickets para el Nivel 2 del Tablero de Agenda al tocar una casilla (D-101/D-116/D-147).';
