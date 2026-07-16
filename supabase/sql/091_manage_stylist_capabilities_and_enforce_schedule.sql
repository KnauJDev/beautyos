-- Gestion administrativa de los servicios que puede realizar cada estilista
-- y proteccion central contra choques de agenda desde el estado solicitado.

create or replace function public.get_stylist_service_options(
  p_stylist_id uuid
)
returns table (
  service_id uuid,
  service_name text,
  category text,
  price numeric,
  duration_minutes integer,
  assigned boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_role text;
begin
  select up.tenant_id, up.role
    into v_tenant_id, v_role
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.active = true
  limit 1;

  if v_tenant_id is null or v_role not in ('owner', 'admin') then
    raise exception 'Solo el propietario o un administrador puede gestionar servicios de estilistas.';
  end if;

  if not exists (
    select 1
    from public.stylists st
    where st.id = p_stylist_id
      and st.tenant_id = v_tenant_id
      and st.active = true
  ) then
    raise exception 'El estilista no existe, esta inactivo o pertenece a otro negocio.';
  end if;

  return query
  select
    s.id,
    s.name,
    coalesce(s.category, 'Sin categoria'),
    s.price,
    s.duration_minutes,
    coalesce(ss.active, false)
  from public.services s
  left join public.stylist_services ss
    on ss.tenant_id = s.tenant_id
   and ss.stylist_id = p_stylist_id
   and ss.service_id = s.id
  where s.tenant_id = v_tenant_id
    and s.active = true
  order by lower(s.name), s.id;
end;
$$;

create or replace function public.set_stylist_services(
  p_stylist_id uuid,
  p_service_ids uuid[]
)
returns table (
  service_id uuid,
  service_name text,
  category text,
  price numeric,
  duration_minutes integer,
  assigned boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_role text;
  v_service_ids uuid[] := coalesce(p_service_ids, array[]::uuid[]);
begin
  select up.tenant_id, up.role
    into v_tenant_id, v_role
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.active = true
  limit 1;

  if v_tenant_id is null or v_role not in ('owner', 'admin') then
    raise exception 'Solo el propietario o un administrador puede gestionar servicios de estilistas.';
  end if;

  perform 1
  from public.stylists st
  where st.id = p_stylist_id
    and st.tenant_id = v_tenant_id
    and st.active = true
  for update;

  if not found then
    raise exception 'El estilista no existe, esta inactivo o pertenece a otro negocio.';
  end if;

  if exists (
    select 1
    from unnest(v_service_ids) requested(service_id)
    left join public.services s
      on s.id = requested.service_id
     and s.tenant_id = v_tenant_id
     and s.active = true
    where s.id is null
  ) then
    raise exception 'Uno de los servicios seleccionados no existe, esta inactivo o pertenece a otro negocio.';
  end if;

  update public.stylist_services ss
     set active = false
   where ss.tenant_id = v_tenant_id
     and ss.stylist_id = p_stylist_id
     and ss.active = true
     and not (ss.service_id = any(v_service_ids));

  insert into public.stylist_services (
    tenant_id,
    stylist_id,
    service_id,
    active
  )
  select
    v_tenant_id,
    p_stylist_id,
    requested.service_id,
    true
  from (
    select distinct unnest(v_service_ids) as service_id
  ) requested
  on conflict on constraint stylist_services_stylist_id_service_id_key
  do update set active = excluded.active;

  return query
  select
    s.id,
    s.name,
    coalesce(s.category, 'Sin categoria'),
    s.price,
    s.duration_minutes,
    coalesce(ss.active, false)
  from public.services s
  left join public.stylist_services ss
    on ss.tenant_id = s.tenant_id
   and ss.stylist_id = p_stylist_id
   and ss.service_id = s.id
  where s.tenant_id = v_tenant_id
    and s.active = true
  order by lower(s.name), s.id;
end;
$$;

-- Esta funcion se ejecuta como trigger y constituye la ultima barrera de
-- seguridad. Serializa brevemente las escrituras de agenda de cada centro
-- para impedir que dos solicitudes simultaneas reserven el mismo intervalo.
create or replace function public.enforce_stylist_schedule_conflict()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_ticket_id uuid;
  v_stylist_id uuid;
  v_scheduled_at timestamptz;
  v_duration_minutes integer;
  v_stylist_name text;
  v_assignment record;
  v_previous_ticket_service_id uuid;
begin
  if tg_table_name = 'ticket_services' then
    if new.stylist_id is null
       or new.status not in ('pendiente', 'en_proceso') then
      return new;
    end if;

    select t.tenant_id, t.id, t.scheduled_at
      into v_tenant_id, v_ticket_id, v_scheduled_at
    from public.tickets t
    where t.id = new.ticket_id
      and t.tenant_id = new.tenant_id
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

    select (
      coalesce(sum(ts.duration_minutes), 0) + new.duration_minutes
    )::integer
      into v_duration_minutes
    from public.ticket_services ts
    where ts.ticket_id = new.ticket_id
      and ts.tenant_id = new.tenant_id
      and ts.stylist_id = new.stylist_id
      and ts.status in ('pendiente', 'en_proceso')
      and (
        v_previous_ticket_service_id is null
        or ts.id <> v_previous_ticket_service_id
      );

    perform pg_advisory_xact_lock(
      hashtextextended('beautyos:agenda:' || v_tenant_id::text, 0)
    );

    if exists (
      select 1
      from (
        select
          other_t.scheduled_at,
          sum(other_ts.duration_minutes)::integer as duration_minutes
        from public.ticket_services other_ts
        join public.tickets other_t
          on other_t.id = other_ts.ticket_id
         and other_t.tenant_id = other_ts.tenant_id
        where other_ts.tenant_id = v_tenant_id
          and other_ts.ticket_id <> v_ticket_id
          and other_ts.stylist_id = v_stylist_id
          and other_ts.status in ('pendiente', 'en_proceso')
          and other_t.status in (
            'solicitado', 'cotizado', 'apartado',
            'confirmado', 'en_espera', 'en_proceso'
          )
          and other_t.scheduled_at is not null
        group by other_t.id, other_t.scheduled_at
      ) occupied
      where v_scheduled_at
              < occupied.scheduled_at
                + (occupied.duration_minutes * interval '1 minute')
        and v_scheduled_at
              + (v_duration_minutes * interval '1 minute')
                > occupied.scheduled_at
    ) then
      select st.name
        into v_stylist_name
      from public.stylists st
      where st.id = v_stylist_id
        and st.tenant_id = v_tenant_id;

      raise exception
        'Choque de agenda: % ya tiene una cita que se cruza con este horario.',
        coalesce(v_stylist_name, 'el estilista seleccionado');
    end if;

    return new;
  end if;

  -- Cambiar fecha u activar nuevamente un ticket tambien debe pasar por la
  -- misma proteccion, incluso si la RPC que origino el cambio no la conoce.
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
    v_ticket_id := new.id;
    v_scheduled_at := new.scheduled_at;

    perform pg_advisory_xact_lock(
      hashtextextended('beautyos:agenda:' || v_tenant_id::text, 0)
    );

    for v_assignment in
      select
        ts.stylist_id,
        sum(ts.duration_minutes)::integer as duration_minutes
      from public.ticket_services ts
      where ts.ticket_id = v_ticket_id
        and ts.tenant_id = v_tenant_id
        and ts.stylist_id is not null
        and ts.status in ('pendiente', 'en_proceso')
      group by ts.stylist_id
      order by ts.stylist_id
    loop
      if exists (
        select 1
        from (
          select
            other_t.scheduled_at,
            sum(other_ts.duration_minutes)::integer as duration_minutes
          from public.ticket_services other_ts
          join public.tickets other_t
            on other_t.id = other_ts.ticket_id
           and other_t.tenant_id = other_ts.tenant_id
          where other_ts.tenant_id = v_tenant_id
            and other_ts.ticket_id <> v_ticket_id
            and other_ts.stylist_id = v_assignment.stylist_id
            and other_ts.status in ('pendiente', 'en_proceso')
            and other_t.status in (
              'solicitado', 'cotizado', 'apartado',
              'confirmado', 'en_espera', 'en_proceso'
            )
            and other_t.scheduled_at is not null
          group by other_t.id, other_t.scheduled_at
        ) occupied
        where v_scheduled_at
                < occupied.scheduled_at
                  + (occupied.duration_minutes * interval '1 minute')
          and v_scheduled_at
                + (v_assignment.duration_minutes * interval '1 minute')
                  > occupied.scheduled_at
      ) then
        select st.name
          into v_stylist_name
        from public.stylists st
        where st.id = v_assignment.stylist_id
          and st.tenant_id = v_tenant_id;

        raise exception
          'Choque de agenda: % ya tiene una cita que se cruza con este horario.',
          coalesce(v_stylist_name, 'el estilista seleccionado');
      end if;
    end loop;

    return new;
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_ticket_service_schedule_conflict
  on public.ticket_services;

create trigger enforce_ticket_service_schedule_conflict
before insert or update of ticket_id, stylist_id, duration_minutes, status
on public.ticket_services
for each row
execute function public.enforce_stylist_schedule_conflict();

drop trigger if exists enforce_ticket_schedule_conflict
  on public.tickets;

create trigger enforce_ticket_schedule_conflict
before update of scheduled_at, status
on public.tickets
for each row
execute function public.enforce_stylist_schedule_conflict();

revoke all on function public.get_stylist_service_options(uuid) from public;
revoke all on function public.get_stylist_service_options(uuid) from anon;
grant execute on function public.get_stylist_service_options(uuid) to authenticated;

revoke all on function public.set_stylist_services(uuid, uuid[]) from public;
revoke all on function public.set_stylist_services(uuid, uuid[]) from anon;
grant execute on function public.set_stylist_services(uuid, uuid[]) to authenticated;

revoke all on function public.enforce_stylist_schedule_conflict() from public;
revoke all on function public.enforce_stylist_schedule_conflict() from anon;
revoke all on function public.enforce_stylist_schedule_conflict() from authenticated;
