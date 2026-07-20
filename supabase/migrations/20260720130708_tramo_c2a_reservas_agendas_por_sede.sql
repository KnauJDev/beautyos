-- BeautyOS - Tramo C2a: recorrido principal consciente de sede.
--
-- Todas las RPC son aditivas. Las firmas heredadas permanecen intactas hasta
-- completar C4 y la aplicacion debe enviar siempre p_branch_id.

begin;

-- Tramo B ya creo los indices unicos correctos por sede. Se retiran las dos
-- restricciones antiguas por tenant que impedirian configurar A1 y A2.
alter table public.business_hours
  drop constraint if exists business_hours_tenant_id_day_of_week_key;
alter table public.appointment_policies
  drop constraint if exists appointment_policies_tenant_id_key;

create or replace function public.get_ticket_service_options_v2(
  p_branch_id uuid
)
returns table (
  service_id uuid,
  service_name text,
  category text,
  price numeric,
  duration_minutes integer,
  stylist_id uuid,
  stylist_name text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select r.tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id,
    array['tenant_owner', 'admin', 'assistant'],
    true
  ) r;

  return query
  select
    s.id,
    s.name,
    coalesce(s.category, 'Sin categoria'),
    bs.price,
    bs.duration_minutes,
    st.id,
    st.name
  from public.branch_services bs
  join public.services s
    on s.tenant_id = bs.tenant_id
   and s.id = bs.service_id
   and s.active
  left join (
    public.branch_stylist_services bss
    join public.branch_stylists bst
      on bst.tenant_id = bss.tenant_id
     and bst.branch_id = bss.branch_id
     and bst.id = bss.branch_stylist_id
     and bst.active
     and bst.starts_at <= now()
     and (bst.ends_at is null or bst.ends_at > now())
    join public.stylists st
      on st.tenant_id = bst.tenant_id
     and st.id = bst.stylist_id
     and st.active
  )
    on bss.tenant_id = bs.tenant_id
   and bss.branch_id = bs.branch_id
   and bss.branch_service_id = bs.id
   and bss.active
  where bs.tenant_id = v_tenant_id
    and bs.branch_id = p_branch_id
    and bs.active
  order by s.name, st.name nulls last;
end;
$$;

create or replace function public.get_available_appointment_slots_v2(
  p_branch_id uuid,
  p_service_id uuid,
  p_stylist_id uuid,
  p_date date
)
returns table (
  starts_at timestamptz,
  ends_at timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_timezone text;
  v_duration_minutes integer;
  v_interval_minutes integer;
  v_opens_at time;
  v_closes_at time;
  v_day_of_week integer;
  v_day_start timestamptz;
  v_day_end timestamptz;
begin
  select r.tenant_id, r.timezone
    into v_tenant_id, v_timezone
  from private.beautyos_resolve_branch_access(
    p_branch_id,
    array['tenant_owner', 'admin', 'assistant'],
    true
  ) r;

  if p_date is null then
    raise exception 'Selecciona una fecha para consultar disponibilidad.';
  end if;

  select bs.duration_minutes, bs.booking_interval_minutes
    into v_duration_minutes, v_interval_minutes
  from public.branch_services bs
  join public.services s
    on s.tenant_id = bs.tenant_id
   and s.id = bs.service_id
   and s.active
  where bs.tenant_id = v_tenant_id
    and bs.branch_id = p_branch_id
    and bs.service_id = p_service_id
    and bs.active;

  if not found then
    raise exception 'El recurso no esta disponible para esta sede.';
  end if;

  if not exists (
    select 1
    from public.branch_services bs
    join public.branch_stylist_services bss
      on bss.tenant_id = bs.tenant_id
     and bss.branch_id = bs.branch_id
     and bss.branch_service_id = bs.id
     and bss.active
    join public.branch_stylists bst
      on bst.tenant_id = bss.tenant_id
     and bst.branch_id = bss.branch_id
     and bst.id = bss.branch_stylist_id
     and bst.stylist_id = p_stylist_id
     and bst.active
     and bst.starts_at <= now()
     and (bst.ends_at is null or bst.ends_at > now())
    join public.stylists st
      on st.tenant_id = bst.tenant_id
     and st.id = bst.stylist_id
     and st.active
    where bs.tenant_id = v_tenant_id
      and bs.branch_id = p_branch_id
      and bs.service_id = p_service_id
      and bs.active
  ) then
    raise exception 'El recurso no esta disponible para esta sede.';
  end if;

  v_day_of_week := extract(isodow from p_date)::integer;

  select bh.opens_at, bh.closes_at
    into v_opens_at, v_closes_at
  from public.business_hours bh
  where bh.tenant_id = v_tenant_id
    and bh.branch_id = p_branch_id
    and bh.day_of_week = v_day_of_week
    and bh.active
    and bh.is_open
  order by bh.opens_at
  limit 1;

  if v_opens_at is null
     or v_closes_at is null
     or v_closes_at <= v_opens_at then
    return;
  end if;

  v_day_start := p_date::timestamp at time zone v_timezone;
  v_day_end := (p_date + 1)::timestamp at time zone v_timezone;

  return query
  with candidate_slots as (
    select
      candidate_start as starts_at,
      candidate_start + (v_duration_minutes * interval '1 minute') as ends_at
    from generate_series(
      (p_date + v_opens_at)::timestamp at time zone v_timezone,
      ((p_date + v_closes_at)::timestamp at time zone v_timezone)
        - (v_duration_minutes * interval '1 minute'),
      v_interval_minutes * interval '1 minute'
    ) candidate_start
  ),
  occupied as (
    select
      t.id as ticket_id,
      t.scheduled_at,
      sum(ts.duration_minutes)::integer as duration_minutes
    from public.ticket_services ts
    join public.tickets t
      on t.tenant_id = ts.tenant_id
     and t.branch_id = ts.branch_id
     and t.id = ts.ticket_id
    where ts.tenant_id = v_tenant_id
      and ts.branch_id = p_branch_id
      and ts.stylist_id = p_stylist_id
      and ts.status in ('pendiente', 'en_proceso')
      and t.status in (
        'solicitado', 'cotizado', 'apartado',
        'confirmado', 'en_espera', 'en_proceso'
      )
      and t.scheduled_at >= v_day_start
      and t.scheduled_at < v_day_end
    group by t.id, t.scheduled_at
  )
  select cs.starts_at, cs.ends_at
  from candidate_slots cs
  where cs.starts_at > now()
    and not exists (
      select 1
      from occupied o
      where cs.starts_at
              < o.scheduled_at + (o.duration_minutes * interval '1 minute')
        and cs.ends_at > o.scheduled_at
    )
  order by cs.starts_at;
end;
$$;

create or replace function public.create_scheduled_ticket_with_service_v2(
  p_branch_id uuid,
  p_client_id uuid,
  p_service_id uuid,
  p_stylist_id uuid,
  p_scheduled_at timestamptz,
  p_channel text default 'manual',
  p_notes text default null
)
returns setof public.tickets
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_ticket public.tickets%rowtype;
  v_service_price numeric;
  v_service_duration integer;
begin
  select r.tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id,
    array['tenant_owner', 'admin', 'assistant'],
    true
  ) r;

  if p_scheduled_at is null then
    raise exception 'La fecha y hora son obligatorias para una reserva.';
  end if;

  perform 1
  from public.clients c
  where c.id = p_client_id
    and c.tenant_id = v_tenant_id
    and c.active;

  if not found then
    raise exception 'El recurso no esta disponible para esta sede.';
  end if;

  select bs.price, bs.duration_minutes
    into v_service_price, v_service_duration
  from public.branch_services bs
  join public.branch_stylist_services bss
    on bss.tenant_id = bs.tenant_id
   and bss.branch_id = bs.branch_id
   and bss.branch_service_id = bs.id
   and bss.active
  join public.branch_stylists bst
    on bst.tenant_id = bss.tenant_id
   and bst.branch_id = bss.branch_id
   and bst.id = bss.branch_stylist_id
   and bst.stylist_id = p_stylist_id
   and bst.active
   and bst.starts_at <= now()
   and (bst.ends_at is null or bst.ends_at > now())
  join public.services s
    on s.tenant_id = bs.tenant_id
   and s.id = bs.service_id
   and s.active
  join public.stylists st
    on st.tenant_id = bst.tenant_id
   and st.id = bst.stylist_id
   and st.active
  where bs.tenant_id = v_tenant_id
    and bs.branch_id = p_branch_id
    and bs.service_id = p_service_id
    and bs.active;

  if not found then
    raise exception 'El recurso no esta disponible para esta sede.';
  end if;

  if not exists (
    select 1
    from public.get_available_appointment_slots_v2(
      p_branch_id,
      p_service_id,
      p_stylist_id,
      (p_scheduled_at at time zone (
        select b.timezone
        from public.branches b
        where b.tenant_id = v_tenant_id
          and b.id = p_branch_id
      ))::date
    ) slots
    where slots.starts_at = p_scheduled_at
  ) then
    raise exception 'El horario seleccionado ya no esta disponible.';
  end if;

  insert into public.tickets (
    tenant_id,
    branch_id,
    client_id,
    scheduled_at,
    status,
    channel,
    notes
  ) values (
    v_tenant_id,
    p_branch_id,
    p_client_id,
    p_scheduled_at,
    'solicitado',
    nullif(trim(coalesce(p_channel, 'manual')), ''),
    nullif(trim(coalesce(p_notes, '')), '')
  )
  returning * into v_ticket;

  insert into public.ticket_services (
    tenant_id,
    branch_id,
    ticket_id,
    service_id,
    stylist_id,
    price,
    duration_minutes,
    status
  ) values (
    v_tenant_id,
    p_branch_id,
    v_ticket.id,
    p_service_id,
    p_stylist_id,
    v_service_price,
    v_service_duration,
    'pendiente'
  );

  return next v_ticket;
end;
$$;

create or replace function public.get_tickets_summary_v2(
  p_branch_id uuid
)
returns table (
  id uuid,
  client_name text,
  scheduled_at timestamptz,
  status text,
  channel text,
  service_names text,
  stylist_names text,
  total_price numeric,
  total_duration_minutes integer,
  paid_amount numeric,
  balance_amount numeric,
  payment_status text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select r.tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id,
    array['tenant_owner', 'admin'],
    true
  ) r;

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
  )
  select
    tk.id,
    coalesce(c.name, 'Cliente sin nombre'),
    tk.scheduled_at,
    tk.status,
    tk.channel,
    coalesce(ss.service_names, 'Sin servicios'),
    coalesce(ss.stylist_names, 'Sin estilista'),
    coalesce(ss.total_price, 0)::numeric,
    coalesce(ss.total_duration_minutes, 0)::integer,
    coalesce(ps.paid_amount, 0)::numeric,
    greatest(
      coalesce(ss.total_price, 0) - coalesce(ps.paid_amount, 0),
      0
    )::numeric,
    case
      when coalesce(ps.paid_amount, 0) = 0 then 'sin_pago'
      when coalesce(ps.paid_amount, 0) < coalesce(ss.total_price, 0)
        then 'parcial'
      else 'pagado'
    end
  from public.tickets tk
  left join public.clients c
    on c.tenant_id = tk.tenant_id
   and c.id = tk.client_id
   and c.active
  left join service_summary ss on ss.ticket_id = tk.id
  left join payment_summary ps on ps.ticket_id = tk.id
  where tk.tenant_id = v_tenant_id
    and tk.branch_id = p_branch_id
  order by tk.scheduled_at desc nulls last, tk.created_at desc;
end;
$$;

create or replace function public.get_agenda_summary_v2(
  p_branch_id uuid
)
returns table (
  id uuid,
  client_name text,
  scheduled_at timestamptz,
  status text,
  service_names text,
  stylist_names text,
  total_price numeric,
  total_duration_minutes integer
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select r.tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id,
    array['tenant_owner', 'admin'],
    true
  ) r;

  return query
  select
    tk.id,
    coalesce(c.name, 'Cliente sin nombre'),
    tk.scheduled_at,
    tk.status,
    coalesce(
      string_agg(distinct s.name, ', ' order by s.name),
      'Sin servicios'
    ),
    coalesce(
      string_agg(distinct st.name, ', ' order by st.name),
      'Sin estilista'
    ),
    coalesce(sum(ts.price), 0)::numeric,
    coalesce(sum(ts.duration_minutes), 0)::integer
  from public.tickets tk
  left join public.clients c
    on c.tenant_id = tk.tenant_id
   and c.id = tk.client_id
   and c.active
  left join public.ticket_services ts
    on ts.tenant_id = tk.tenant_id
   and ts.branch_id = tk.branch_id
   and ts.ticket_id = tk.id
   and lower(ts.status) <> 'cancelado'
  left join public.services s
    on s.tenant_id = ts.tenant_id
   and s.id = ts.service_id
   and s.active
  left join public.stylists st
    on st.tenant_id = ts.tenant_id
   and st.id = ts.stylist_id
   and st.active
  where tk.tenant_id = v_tenant_id
    and tk.branch_id = p_branch_id
    and tk.scheduled_at is not null
    and lower(tk.status) in ('confirmado', 'en_espera', 'en_proceso')
  group by tk.id, c.name, tk.scheduled_at, tk.status
  order by tk.scheduled_at;
end;
$$;

create or replace function public.get_my_stylist_agenda_by_date_v2(
  p_branch_id uuid,
  p_date date
)
returns table (
  ticket_service_id uuid,
  ticket_id uuid,
  scheduled_at timestamptz,
  client_name text,
  service_name text,
  ticket_status text,
  service_status text,
  price numeric,
  duration_minutes integer,
  notes text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_stylist_id uuid;
  v_timezone text;
  v_date date;
begin
  select r.tenant_id, r.stylist_id, r.timezone
    into v_tenant_id, v_stylist_id, v_timezone
  from private.beautyos_resolve_branch_access(
    p_branch_id,
    array['stylist'],
    true
  ) r;

  v_date := coalesce(p_date, (now() at time zone v_timezone)::date);

  return query
  select
    ts.id,
    t.id,
    t.scheduled_at,
    c.name,
    s.name,
    t.status,
    ts.status,
    ts.price,
    ts.duration_minutes,
    t.notes
  from public.ticket_services ts
  join public.tickets t
    on t.tenant_id = ts.tenant_id
   and t.branch_id = ts.branch_id
   and t.id = ts.ticket_id
   and t.status in ('solicitado', 'confirmado', 'en_espera', 'en_proceso')
   and (t.scheduled_at at time zone v_timezone)::date = v_date
  join public.clients c
    on c.tenant_id = t.tenant_id
   and c.id = t.client_id
  join public.services s
    on s.tenant_id = ts.tenant_id
   and s.id = ts.service_id
  where ts.tenant_id = v_tenant_id
    and ts.branch_id = p_branch_id
    and ts.stylist_id = v_stylist_id
    and ts.status in ('pendiente', 'en_proceso')
  order by t.scheduled_at, ts.created_at;
end;
$$;

revoke all on function public.get_ticket_service_options_v2(uuid)
  from public, anon, authenticated;
revoke all on function public.get_available_appointment_slots_v2(
  uuid, uuid, uuid, date
) from public, anon, authenticated;
revoke all on function public.create_scheduled_ticket_with_service_v2(
  uuid, uuid, uuid, uuid, timestamptz, text, text
) from public, anon, authenticated;
revoke all on function public.get_tickets_summary_v2(uuid)
  from public, anon, authenticated;
revoke all on function public.get_agenda_summary_v2(uuid)
  from public, anon, authenticated;
revoke all on function public.get_my_stylist_agenda_by_date_v2(uuid, date)
  from public, anon, authenticated;

grant execute on function public.get_ticket_service_options_v2(uuid)
  to authenticated;
grant execute on function public.get_available_appointment_slots_v2(
  uuid, uuid, uuid, date
) to authenticated;
grant execute on function public.create_scheduled_ticket_with_service_v2(
  uuid, uuid, uuid, uuid, timestamptz, text, text
) to authenticated;
grant execute on function public.get_tickets_summary_v2(uuid)
  to authenticated;
grant execute on function public.get_agenda_summary_v2(uuid)
  to authenticated;
grant execute on function public.get_my_stylist_agenda_by_date_v2(uuid, date)
  to authenticated;

comment on function public.get_ticket_service_options_v2(uuid)
  is 'Opciones de servicios y profesionales habilitados en una sede autorizada.';
comment on function public.get_available_appointment_slots_v2(uuid, uuid, uuid, date)
  is 'Disponibilidad futura calculada con configuracion y zona horaria de sede.';
comment on function public.create_scheduled_ticket_with_service_v2(
  uuid, uuid, uuid, uuid, timestamptz, text, text
) is 'Crea atomicamente una reserva interna dentro de una sede autorizada.';
comment on function public.get_tickets_summary_v2(uuid)
  is 'Resumen de tickets, pagos y saldo limitado a una sede autorizada.';
comment on function public.get_agenda_summary_v2(uuid)
  is 'Agenda administrativa activa limitada a una sede autorizada.';
comment on function public.get_my_stylist_agenda_by_date_v2(uuid, date)
  is 'Agenda propia del estilista para una sede y fecha autorizadas.';

commit;
