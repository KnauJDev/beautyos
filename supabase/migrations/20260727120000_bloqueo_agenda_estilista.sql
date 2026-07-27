-- BeautyOS - Bloqueo de agenda del estilista (punto 4.2 de
-- RUTA_GENERAL_2026-07-25.md).
--
-- El estilista (o el dueno/admin en su nombre) puede marcar un rango de
-- tiempo en el que no puede atender (vacaciones, incapacidad, etc.).
-- Igual que el choque de agenda entre sedes (D-073), el bloqueo es POR
-- TODO EL NEGOCIO, no por sede: si un estilista no puede atender, no
-- puede atender en ninguna de sus sedes.
--
-- De paso se corrige un hueco hermano al de D-073, encontrado al revisar
-- estas mismas funciones: get_available_appointment_slots_v2 y
-- public_get_available_slots calculaban "ocupado" solo dentro de la sede
-- actual. Ya no genera una doble cita real (D-073 la rechaza al
-- confirmar), pero si podia mostrar como "disponible" un horario ya
-- ocupado en otra sede -- confuso para quien reserva. Se corrige en el
-- mismo paso ya que se estan tocando estas funciones de todas formas.

begin;

create table public.stylist_time_off (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  stylist_id uuid not null references public.stylists(id) on delete restrict,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  reason text,
  active boolean not null default true,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint stylist_time_off_range_check check (ends_at > starts_at)
);

create index stylist_time_off_lookup_idx
  on public.stylist_time_off (tenant_id, stylist_id, active, starts_at, ends_at);

create trigger stylist_time_off_set_updated_at
before update on public.stylist_time_off
for each row execute function private.beautyos_set_updated_at();

alter table public.stylist_time_off enable row level security;
revoke all on table public.stylist_time_off from public, anon, authenticated;
grant all on table public.stylist_time_off to service_role;

-- Crear un bloqueo: el propio estilista se autoatribuye; dueno/admin
-- puede crearlo para otro estilista de su negocio (mismo patron de
-- create_work_photo).

create or replace function public.create_stylist_time_off(
  p_branch_id uuid,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_reason text default null,
  p_stylist_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_access record;
  v_stylist_id uuid;
  v_id uuid;
begin
  select * into strict v_access
  from private.beautyos_resolve_branch_access(
    p_branch_id,
    array['tenant_owner', 'admin', 'stylist']::text[],
    true
  );

  if p_starts_at is null or p_ends_at is null then
    raise exception 'El inicio y el fin del bloqueo son obligatorios.';
  end if;

  if p_ends_at <= p_starts_at then
    raise exception 'El fin del bloqueo debe ser posterior al inicio.';
  end if;

  if v_access.role = 'stylist' then
    v_stylist_id := v_access.stylist_id;
  elsif p_stylist_id is not null then
    if not exists (
      select 1 from public.stylists s
      where s.id = p_stylist_id and s.tenant_id = v_access.tenant_id
    ) then
      raise exception 'El estilista seleccionado no pertenece a este negocio.';
    end if;
    v_stylist_id := p_stylist_id;
  else
    raise exception 'Selecciona a que estilista corresponde este bloqueo.';
  end if;

  insert into public.stylist_time_off (
    tenant_id, stylist_id, starts_at, ends_at, reason, created_by
  ) values (
    v_access.tenant_id,
    v_stylist_id,
    p_starts_at,
    p_ends_at,
    nullif(trim(coalesce(p_reason, '')), ''),
    auth.uid()
  )
  returning id into v_id;

  return v_id;
end;
$$;

-- Lista de bloqueos propios del estilista autenticado (para "Mi agenda").

create or replace function public.get_my_stylist_time_off(
  p_branch_id uuid
)
returns table (
  id uuid,
  starts_at timestamptz,
  ends_at timestamptz,
  reason text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_access record;
begin
  select * into strict v_access
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['stylist']::text[], true
  );

  return query
  select sto.id, sto.starts_at, sto.ends_at, sto.reason, sto.created_at
  from public.stylist_time_off sto
  where sto.tenant_id = v_access.tenant_id
    and sto.stylist_id = v_access.stylist_id
    and sto.active
    and sto.ends_at > now()
  order by sto.starts_at;
end;
$$;

-- Cancelar un bloqueo: el propio estilista solo puede cancelar el suyo;
-- dueno/admin puede cancelar cualquiera de su negocio.

create or replace function public.cancel_stylist_time_off(
  p_branch_id uuid,
  p_time_off_id uuid
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_access record;
  v_target public.stylist_time_off%rowtype;
begin
  select * into strict v_access
  from private.beautyos_resolve_branch_access(
    p_branch_id,
    array['tenant_owner', 'admin', 'stylist']::text[],
    true
  );

  select *
    into v_target
  from public.stylist_time_off
  where id = p_time_off_id
    and tenant_id = v_access.tenant_id
    and active;

  if not found then
    raise exception 'El bloqueo no existe o ya fue cancelado.';
  end if;

  if v_access.role = 'stylist' and v_target.stylist_id <> v_access.stylist_id then
    raise exception 'No puedes cancelar el bloqueo de otro estilista.';
  end if;

  update public.stylist_time_off
     set active = false, updated_at = now()
   where id = p_time_off_id;
end;
$$;

revoke all on function public.create_stylist_time_off(uuid, timestamptz, timestamptz, text, uuid) from public, anon;
revoke all on function public.get_my_stylist_time_off(uuid) from public, anon;
revoke all on function public.cancel_stylist_time_off(uuid, uuid) from public, anon;

grant execute on function public.create_stylist_time_off(uuid, timestamptz, timestamptz, text, uuid) to authenticated, service_role;
grant execute on function public.get_my_stylist_time_off(uuid) to authenticated, service_role;
grant execute on function public.cancel_stylist_time_off(uuid, uuid) to authenticated, service_role;

-- Horarios disponibles (agenda manual del negocio): ahora tambien
-- revisa ocupacion en TODAS las sedes del estilista (no solo la sede
-- actual) y excluye bloqueos de agenda activos.

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
      and ts.stylist_id = p_stylist_id
      and ts.status in ('pendiente', 'en_proceso')
      and t.status in (
        'solicitado', 'cotizado', 'apartado',
        'confirmado', 'en_espera', 'en_proceso'
      )
      and t.scheduled_at >= v_day_start
      and t.scheduled_at < v_day_end
    group by t.id, t.scheduled_at
  ),
  blocked as (
    select sto.starts_at, sto.ends_at
    from public.stylist_time_off sto
    where sto.tenant_id = v_tenant_id
      and sto.stylist_id = p_stylist_id
      and sto.active
      and sto.starts_at < v_day_end
      and sto.ends_at > v_day_start
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
    and not exists (
      select 1
      from blocked bl
      where cs.starts_at < bl.ends_at
        and cs.ends_at > bl.starts_at
    )
  order by cs.starts_at;
end;
$$;

-- Horarios disponibles (reserva publica de cliente): mismos dos cambios.

create or replace function public.public_get_available_slots(
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
  select t.id, b.timezone
    into v_tenant_id, v_timezone
  from public.branches b
  join public.tenants t
    on t.id = b.tenant_id
  where b.id = p_branch_id
    and t.active
    and b.active;

  if not found then
    raise exception 'Este negocio no esta disponible para reservas en este momento.';
  end if;

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
    and bs.active
    and s.visible_to_customer
    and bs.visible_to_customer;

  if not found then
    raise exception 'El servicio seleccionado no esta disponible para reservar en esta sede.';
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
      and bs.visible_to_customer
  ) then
    raise exception 'El profesional seleccionado no esta disponible para reservar este servicio en esta sede.';
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
      and ts.stylist_id = p_stylist_id
      and ts.status in ('pendiente', 'en_proceso')
      and t.status in (
        'solicitado', 'cotizado', 'apartado',
        'confirmado', 'en_espera', 'en_proceso'
      )
      and t.scheduled_at >= v_day_start
      and t.scheduled_at < v_day_end
    group by t.id, t.scheduled_at
  ),
  blocked as (
    select sto.starts_at, sto.ends_at
    from public.stylist_time_off sto
    where sto.tenant_id = v_tenant_id
      and sto.stylist_id = p_stylist_id
      and sto.active
      and sto.starts_at < v_day_end
      and sto.ends_at > v_day_start
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
    and not exists (
      select 1
      from blocked bl
      where cs.starts_at < bl.ends_at
        and cs.ends_at > bl.starts_at
    )
  order by cs.starts_at;
end;
$$;

-- Defensa adicional: el trigger de choque de agenda tambien rechaza una
-- cita nueva/reprogramada si cae dentro de un bloqueo de agenda activo,
-- por si algo intenta crearla sin pasar por el buscador de horarios.

create or replace function public.enforce_stylist_schedule_conflict()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_branch_id uuid;
  v_ticket_id uuid;
  v_stylist_id uuid;
  v_scheduled_at timestamptz;
  v_duration_minutes integer;
  v_stylist_name text;
  v_assignment record;
  v_previous_ticket_service_id uuid;
  v_conflict_branch_name text;
  v_blocked boolean;
begin
  if tg_table_name = 'ticket_services' then
    if new.stylist_id is null
       or new.status not in ('pendiente', 'en_proceso') then
      return new;
    end if;

    select t.tenant_id, t.branch_id, t.id, t.scheduled_at
      into v_tenant_id, v_branch_id, v_ticket_id, v_scheduled_at
    from public.tickets t
    where t.id = new.ticket_id
      and t.tenant_id = new.tenant_id
      and t.branch_id = new.branch_id
      and t.status in (
        'solicitado', 'cotizado', 'apartado',
        'confirmado', 'en_espera', 'en_proceso'
      );

    if not found or v_scheduled_at is null then
      return new;
    end if;

    v_stylist_id := new.stylist_id;
    if tg_op = 'UPDATE' then
      v_previous_ticket_service_id := old.id;
    end if;

    select (coalesce(sum(ts.duration_minutes), 0) + new.duration_minutes)::integer
      into v_duration_minutes
    from public.ticket_services ts
    where ts.ticket_id = new.ticket_id
      and ts.tenant_id = new.tenant_id
      and ts.branch_id = new.branch_id
      and ts.stylist_id = new.stylist_id
      and ts.status in ('pendiente', 'en_proceso')
      and (v_previous_ticket_service_id is null or ts.id <> v_previous_ticket_service_id);

    perform pg_advisory_xact_lock(
      hashtextextended('beautyos:agenda:stylist:' || v_stylist_id::text, 0)
    );

    select exists (
      select 1 from public.stylist_time_off sto
      where sto.tenant_id = v_tenant_id
        and sto.stylist_id = v_stylist_id
        and sto.active
        and v_scheduled_at < sto.ends_at
        and (v_scheduled_at + v_duration_minutes * interval '1 minute') > sto.starts_at
    ) into v_blocked;

    if v_blocked then
      select st.name into v_stylist_name
      from public.stylists st
      where st.id = v_stylist_id and st.tenant_id = v_tenant_id;

      raise exception 'Choque de agenda: % tiene bloqueada su agenda en ese horario.',
        coalesce(v_stylist_name, 'el estilista seleccionado');
    end if;

    v_conflict_branch_name := null;

    select ob.name
      into v_conflict_branch_name
    from (
      select other_t.branch_id, other_t.scheduled_at,
             sum(other_ts.duration_minutes)::integer as duration_minutes
      from public.ticket_services other_ts
      join public.tickets other_t
        on other_t.id = other_ts.ticket_id
       and other_t.tenant_id = other_ts.tenant_id
       and other_t.branch_id = other_ts.branch_id
      where other_ts.tenant_id = v_tenant_id
        and other_ts.ticket_id <> v_ticket_id
        and other_ts.stylist_id = v_stylist_id
        and other_ts.status in ('pendiente', 'en_proceso')
        and other_t.status in (
          'solicitado', 'cotizado', 'apartado',
          'confirmado', 'en_espera', 'en_proceso'
        )
        and other_t.scheduled_at is not null
      group by other_t.branch_id, other_t.id, other_t.scheduled_at
    ) occupied
    join public.branches ob on ob.id = occupied.branch_id
    where v_scheduled_at < occupied.scheduled_at
            + occupied.duration_minutes * interval '1 minute'
      and v_scheduled_at + v_duration_minutes * interval '1 minute'
            > occupied.scheduled_at
    limit 1;

    if v_conflict_branch_name is not null then
      select st.name into v_stylist_name
      from public.stylists st
      where st.id = v_stylist_id and st.tenant_id = v_tenant_id;

      raise exception 'Choque de agenda: % ya tiene una cita en "%" que se cruza con este horario.',
        coalesce(v_stylist_name, 'el estilista seleccionado'), v_conflict_branch_name;
    end if;

    return new;
  end if;

  if tg_table_name = 'tickets' then
    if new.scheduled_at is null
       or new.status not in (
         'solicitado', 'cotizado', 'apartado',
         'confirmado', 'en_espera', 'en_proceso'
       ) then
      return new;
    end if;

    if new.scheduled_at is not distinct from old.scheduled_at
       and new.status is not distinct from old.status then
      return new;
    end if;

    v_tenant_id := new.tenant_id;
    v_branch_id := new.branch_id;
    v_ticket_id := new.id;
    v_scheduled_at := new.scheduled_at;

    for v_assignment in
      select ts.stylist_id, sum(ts.duration_minutes)::integer as duration_minutes
      from public.ticket_services ts
      where ts.ticket_id = v_ticket_id
        and ts.tenant_id = v_tenant_id
        and ts.branch_id = v_branch_id
        and ts.stylist_id is not null
        and ts.status in ('pendiente', 'en_proceso')
      group by ts.stylist_id
      order by ts.stylist_id
    loop
      perform pg_advisory_xact_lock(
        hashtextextended('beautyos:agenda:stylist:' || v_assignment.stylist_id::text, 0)
      );

      select exists (
        select 1 from public.stylist_time_off sto
        where sto.tenant_id = v_tenant_id
          and sto.stylist_id = v_assignment.stylist_id
          and sto.active
          and v_scheduled_at < sto.ends_at
          and (v_scheduled_at + v_assignment.duration_minutes * interval '1 minute') > sto.starts_at
      ) into v_blocked;

      if v_blocked then
        select st.name into v_stylist_name
        from public.stylists st
        where st.id = v_assignment.stylist_id and st.tenant_id = v_tenant_id;

        raise exception 'Choque de agenda: % tiene bloqueada su agenda en ese horario.',
          coalesce(v_stylist_name, 'el estilista seleccionado');
      end if;

      v_conflict_branch_name := null;

      select ob.name
        into v_conflict_branch_name
      from (
        select other_t.branch_id, other_t.scheduled_at,
               sum(other_ts.duration_minutes)::integer as duration_minutes
        from public.ticket_services other_ts
        join public.tickets other_t
          on other_t.id = other_ts.ticket_id
         and other_t.tenant_id = other_ts.tenant_id
         and other_t.branch_id = other_ts.branch_id
        where other_ts.tenant_id = v_tenant_id
          and other_ts.ticket_id <> v_ticket_id
          and other_ts.stylist_id = v_assignment.stylist_id
          and other_ts.status in ('pendiente', 'en_proceso')
          and other_t.status in (
            'solicitado', 'cotizado', 'apartado',
            'confirmado', 'en_espera', 'en_proceso'
          )
          and other_t.scheduled_at is not null
        group by other_t.branch_id, other_t.id, other_t.scheduled_at
      ) occupied
      join public.branches ob on ob.id = occupied.branch_id
      where v_scheduled_at < occupied.scheduled_at
              + occupied.duration_minutes * interval '1 minute'
        and v_scheduled_at + v_assignment.duration_minutes * interval '1 minute'
              > occupied.scheduled_at
      limit 1;

      if v_conflict_branch_name is not null then
        select st.name into v_stylist_name
        from public.stylists st
        where st.id = v_assignment.stylist_id and st.tenant_id = v_tenant_id;

        raise exception 'Choque de agenda: % ya tiene una cita en "%" que se cruza con este horario.',
          coalesce(v_stylist_name, 'el estilista seleccionado'), v_conflict_branch_name;
      end if;
    end loop;

    return new;
  end if;

  return new;
end;
$$;

commit;
