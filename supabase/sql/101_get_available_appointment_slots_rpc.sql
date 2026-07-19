-- Devuelve horas realmente disponibles para una reserva interna. La zona
-- horaria comercial de BeautyOS es America/Bogota y las franjas avanzan cada
-- quince minutos.

create or replace function public.get_available_appointment_slots(
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
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_duration_minutes integer;
  v_opens_at time;
  v_closes_at time;
  v_day_of_week integer;
  v_day_start timestamptz;
  v_day_end timestamptz;
  v_now timestamptz := now();
begin
  select up.tenant_id
    into v_tenant_id
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.active = true
    and up.role in ('owner', 'admin', 'assistant')
  limit 1;

  if v_tenant_id is null then
    raise exception 'No tienes permisos para consultar disponibilidad.';
  end if;

  if p_date is null then
    raise exception 'Selecciona una fecha para consultar disponibilidad.';
  end if;

  select s.duration_minutes
    into v_duration_minutes
  from public.services s
  where s.id = p_service_id
    and s.tenant_id = v_tenant_id
    and s.active = true;

  if not found then
    raise exception 'El servicio no existe, esta inactivo o pertenece a otro negocio.';
  end if;

  if not exists (
    select 1
    from public.stylists st
    join public.stylist_services ss
      on ss.stylist_id = st.id
     and ss.tenant_id = st.tenant_id
     and ss.service_id = p_service_id
     and ss.active = true
    where st.id = p_stylist_id
      and st.tenant_id = v_tenant_id
      and st.active = true
  ) then
    raise exception 'El estilista no esta activo o no tiene asignado este servicio.';
  end if;

  v_day_of_week := extract(isodow from p_date)::integer;

  select bh.opens_at, bh.closes_at
    into v_opens_at, v_closes_at
  from public.business_hours bh
  where bh.tenant_id = v_tenant_id
    and bh.day_of_week = v_day_of_week
    and bh.active = true
    and bh.is_open = true;

  if v_opens_at is null or v_closes_at is null or v_closes_at <= v_opens_at then
    return;
  end if;

  v_day_start := (p_date::timestamp at time zone 'America/Bogota');
  v_day_end := ((p_date + 1)::timestamp at time zone 'America/Bogota');

  return query
  with candidate_slots as (
    select candidate_start as starts_at,
           candidate_start + (v_duration_minutes * interval '1 minute') as ends_at
    from generate_series(
      (p_date + v_opens_at)::timestamp at time zone 'America/Bogota',
      ((p_date + v_closes_at)::timestamp at time zone 'America/Bogota')
        - (v_duration_minutes * interval '1 minute'),
      interval '15 minutes'
    ) candidate_start
  ),
  occupied as (
    select
      t.scheduled_at,
      sum(ts.duration_minutes)::integer as duration_minutes
    from public.ticket_services ts
    join public.tickets t
      on t.id = ts.ticket_id
     and t.tenant_id = ts.tenant_id
    where ts.tenant_id = v_tenant_id
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
  where cs.starts_at > v_now
    and not exists (
      select 1
      from occupied o
      where cs.starts_at < o.scheduled_at + (o.duration_minutes * interval '1 minute')
        and cs.ends_at > o.scheduled_at
    )
  order by cs.starts_at;
end;
$$;

revoke all on function public.get_available_appointment_slots(uuid, uuid, date) from public;
revoke all on function public.get_available_appointment_slots(uuid, uuid, date) from anon;
grant execute on function public.get_available_appointment_slots(uuid, uuid, date) to authenticated;
