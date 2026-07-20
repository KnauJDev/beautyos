-- BeautyOS - Tramo C2b: operacion del ticket consciente de sede.
--
-- Alcance:
-- 1. La ultima barrera de choques se serializa y compara por sede.
-- 2. Gestion, estados, correcciones y pagos reciben p_branch_id obligatorio.
-- 3. Precio, duracion y capacidad profesional se resuelven desde la sede.
-- 4. Las firmas heredadas permanecen disponibles durante C4.

begin;

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
      hashtextextended('beautyos:agenda:' || v_branch_id::text, 0)
    );

    if exists (
      select 1
      from (
        select other_t.scheduled_at,
               sum(other_ts.duration_minutes)::integer as duration_minutes
        from public.ticket_services other_ts
        join public.tickets other_t
          on other_t.id = other_ts.ticket_id
         and other_t.tenant_id = other_ts.tenant_id
         and other_t.branch_id = other_ts.branch_id
        where other_ts.tenant_id = v_tenant_id
          and other_ts.branch_id = v_branch_id
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
      where v_scheduled_at < occupied.scheduled_at
              + occupied.duration_minutes * interval '1 minute'
        and v_scheduled_at + v_duration_minutes * interval '1 minute'
              > occupied.scheduled_at
    ) then
      select st.name into v_stylist_name
      from public.stylists st
      where st.id = v_stylist_id and st.tenant_id = v_tenant_id;

      raise exception 'Choque de agenda: % ya tiene una cita que se cruza con este horario.',
        coalesce(v_stylist_name, 'el estilista seleccionado');
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

    perform pg_advisory_xact_lock(
      hashtextextended('beautyos:agenda:' || v_branch_id::text, 0)
    );

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
      if exists (
        select 1
        from (
          select other_t.scheduled_at,
                 sum(other_ts.duration_minutes)::integer as duration_minutes
          from public.ticket_services other_ts
          join public.tickets other_t
            on other_t.id = other_ts.ticket_id
           and other_t.tenant_id = other_ts.tenant_id
           and other_t.branch_id = other_ts.branch_id
          where other_ts.tenant_id = v_tenant_id
            and other_ts.branch_id = v_branch_id
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
        where v_scheduled_at < occupied.scheduled_at
                + occupied.duration_minutes * interval '1 minute'
          and v_scheduled_at + v_assignment.duration_minutes * interval '1 minute'
                > occupied.scheduled_at
      ) then
        select st.name into v_stylist_name
        from public.stylists st
        where st.id = v_assignment.stylist_id and st.tenant_id = v_tenant_id;

        raise exception 'Choque de agenda: % ya tiene una cita que se cruza con este horario.',
          coalesce(v_stylist_name, 'el estilista seleccionado');
      end if;
    end loop;

    return new;
  end if;

  return new;
end;
$$;

create or replace function public.remove_ticket_service_v2(
  p_branch_id uuid,
  p_ticket_service_id uuid,
  p_reason text
)
returns setof public.ticket_services
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select c.tenant_id into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner','admin','assistant'], true
  ) c;

  if not exists (
    select 1 from public.ticket_services ts
    where ts.id = p_ticket_service_id
      and ts.tenant_id = v_tenant_id
      and ts.branch_id = p_branch_id
  ) then
    raise exception 'El recurso no esta disponible para esta sede.';
  end if;

  return query
  select * from public.remove_ticket_service(p_ticket_service_id, p_reason);
end;
$$;

create or replace function public.change_ticket_status_v2(
  p_branch_id uuid,
  p_ticket_id uuid,
  p_new_status text,
  p_reason text default null
)
returns setof public.tickets
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select c.tenant_id into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner','admin','assistant'], true
  ) c;

  if not exists (
    select 1 from public.tickets t
    where t.id = p_ticket_id
      and t.tenant_id = v_tenant_id
      and t.branch_id = p_branch_id
  ) then
    raise exception 'El recurso no esta disponible para esta sede.';
  end if;

  return query
  select * from public.change_ticket_status(p_ticket_id, p_new_status, p_reason);
end;
$$;

create or replace function public.change_ticket_service_status_v2(
  p_branch_id uuid,
  p_ticket_service_id uuid,
  p_new_status text
)
returns setof public.ticket_services
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_role text;
  v_stylist_id uuid;
  v_assigned_stylist uuid;
begin
  select c.tenant_id, c.role, c.stylist_id
    into v_tenant_id, v_role, v_stylist_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner','admin','assistant','stylist'], true
  ) c;

  select ts.stylist_id into v_assigned_stylist
  from public.ticket_services ts
  where ts.id = p_ticket_service_id
    and ts.tenant_id = v_tenant_id
    and ts.branch_id = p_branch_id;

  if not found or (v_role = 'stylist' and v_assigned_stylist is distinct from v_stylist_id) then
    raise exception 'El recurso no esta disponible para esta sede.';
  end if;

  return query
  select * from public.change_ticket_service_status(p_ticket_service_id, p_new_status);
end;
$$;

create or replace function public.get_ticket_services_for_correction_v2(
  p_branch_id uuid,
  p_ticket_id uuid
)
returns table(
  ticket_service_id uuid,
  service_name text,
  stylist_name text,
  service_status text,
  finalized_at timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select c.tenant_id into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner','admin'], true
  ) c;

  if not exists (
    select 1 from public.tickets t
    where t.id = p_ticket_id
      and t.tenant_id = v_tenant_id
      and t.branch_id = p_branch_id
      and t.status in ('en_proceso','finalizado')
  ) then
    raise exception 'El recurso no esta disponible para esta sede.';
  end if;

  return query
  select ts.id, s.name, coalesce(st.name, 'Sin estilista'), ts.status,
         last_finish.created_at
  from public.ticket_services ts
  join public.services s
    on s.id = ts.service_id and s.tenant_id = v_tenant_id
  left join public.stylists st
    on st.id = ts.stylist_id and st.tenant_id = v_tenant_id
  left join lateral (
    select h.created_at
    from public.ticket_service_history h
    where h.ticket_service_id = ts.id
      and h.tenant_id = v_tenant_id
      and h.branch_id = p_branch_id
      and h.new_status = 'finalizado'
    order by h.created_at desc
    limit 1
  ) last_finish on true
  where ts.ticket_id = p_ticket_id
    and ts.tenant_id = v_tenant_id
    and ts.branch_id = p_branch_id
    and ts.status = 'finalizado'
  order by last_finish.created_at desc nulls last, s.name, ts.id;
end;
$$;

create or replace function public.reopen_finished_ticket_service_v2(
  p_branch_id uuid,
  p_ticket_service_id uuid,
  p_reason text
)
returns setof public.ticket_services
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select c.tenant_id into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner','admin'], true
  ) c;

  if not exists (
    select 1 from public.ticket_services ts
    where ts.id = p_ticket_service_id
      and ts.tenant_id = v_tenant_id
      and ts.branch_id = p_branch_id
  ) then
    raise exception 'El recurso no esta disponible para esta sede.';
  end if;

  return query
  select * from public.reopen_finished_ticket_service(p_ticket_service_id, p_reason);
end;
$$;

create or replace function public.register_ticket_payment_v2(
  p_branch_id uuid,
  p_ticket_id uuid,
  p_amount numeric,
  p_method text,
  p_reference text default null,
  p_notes text default null
)
returns setof public.ticket_payments
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select c.tenant_id into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner','admin','assistant'], true
  ) c;

  if not exists (
    select 1 from public.tickets t
    where t.id = p_ticket_id
      and t.tenant_id = v_tenant_id
      and t.branch_id = p_branch_id
  ) then
    raise exception 'El recurso no esta disponible para esta sede.';
  end if;

  return query
  select * from public.register_ticket_payment(
    p_ticket_id, p_amount, p_method, p_reference, p_notes
  );
end;
$$;

create or replace function public.void_ticket_payment_v2(
  p_branch_id uuid,
  p_payment_id uuid,
  p_reason text
)
returns setof public.ticket_payments
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select c.tenant_id into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner','admin'], true
  ) c;

  if not exists (
    select 1 from public.ticket_payments tp
    where tp.id = p_payment_id
      and tp.tenant_id = v_tenant_id
      and tp.branch_id = p_branch_id
  ) then
    raise exception 'El recurso no esta disponible para esta sede.';
  end if;

  return query
  select * from public.void_ticket_payment(p_payment_id, p_reason);
end;
$$;

create or replace function public.add_ticket_service_v2(
  p_branch_id uuid,
  p_ticket_id uuid,
  p_service_id uuid,
  p_stylist_id uuid default null
)
returns setof public.ticket_services
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_ticket public.tickets%rowtype;
  v_added public.ticket_services%rowtype;
  v_service_name text;
  v_price numeric;
  v_duration integer;
  v_stylist_name text;
begin
  select c.tenant_id into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner','admin','assistant'], true
  ) c;

  select * into v_ticket
  from public.tickets t
  where t.id = p_ticket_id
    and t.tenant_id = v_tenant_id
    and t.branch_id = p_branch_id
  for update;

  if not found then
    raise exception 'El recurso no esta disponible para esta sede.';
  end if;

  if v_ticket.status not in ('solicitado','cotizado','apartado','confirmado','en_espera') then
    raise exception 'No se pueden agregar servicios cuando la atencion ya inicio o el ticket termino.';
  end if;

  if exists (
    select 1 from public.ticket_payments tp
    where tp.ticket_id = v_ticket.id
      and tp.tenant_id = v_tenant_id
      and tp.branch_id = p_branch_id
      and tp.status = 'registrado'
  ) then
    raise exception 'No se pueden modificar servicios de un ticket con pagos registrados.';
  end if;

  select s.name, bs.price, bs.duration_minutes
    into v_service_name, v_price, v_duration
  from public.branch_services bs
  join public.services s
    on s.id = bs.service_id and s.tenant_id = bs.tenant_id and s.active
  where bs.tenant_id = v_tenant_id
    and bs.branch_id = p_branch_id
    and bs.service_id = p_service_id
    and bs.active;

  if not found then
    raise exception 'El servicio no esta disponible para esta sede.';
  end if;

  if p_stylist_id is not null then
    select st.name into v_stylist_name
    from public.branch_stylist_services bss
    join public.branch_stylists bst
      on bst.id = bss.branch_stylist_id
     and bst.tenant_id = bss.tenant_id
     and bst.branch_id = bss.branch_id
     and bst.active
     and bst.starts_at <= now()
     and (bst.ends_at is null or bst.ends_at > now())
    join public.branch_services bs
      on bs.id = bss.branch_service_id
     and bs.tenant_id = bss.tenant_id
     and bs.branch_id = bss.branch_id
     and bs.active
    join public.stylists st
      on st.id = bst.stylist_id and st.tenant_id = bst.tenant_id and st.active
    where bss.tenant_id = v_tenant_id
      and bss.branch_id = p_branch_id
      and bst.stylist_id = p_stylist_id
      and bs.service_id = p_service_id
      and bss.active;

    if not found then
      raise exception 'El profesional no esta habilitado para este servicio en la sede.';
    end if;
  end if;

  insert into public.ticket_services (
    tenant_id, branch_id, ticket_id, service_id, stylist_id,
    price, duration_minutes, status
  ) values (
    v_tenant_id, p_branch_id, v_ticket.id, p_service_id, p_stylist_id,
    v_price, v_duration, 'pendiente'
  ) returning * into v_added;

  insert into public.ticket_service_change_history (
    tenant_id, branch_id, ticket_id, ticket_service_id, event_type,
    new_service_id, new_service_name, new_stylist_id, new_stylist_name,
    new_price, new_duration_minutes, new_status, reason, created_by
  ) values (
    v_tenant_id, p_branch_id, v_ticket.id, v_added.id, 'added',
    v_added.service_id, v_service_name, v_added.stylist_id, v_stylist_name,
    v_added.price, v_added.duration_minutes, v_added.status,
    'Servicio agregado al ticket', auth.uid()
  );

  return next v_added;
end;
$$;

create or replace function public.update_ticket_service_assignment_v2(
  p_branch_id uuid,
  p_ticket_service_id uuid,
  p_service_id uuid,
  p_stylist_id uuid,
  p_reason text
)
returns setof public.ticket_services
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_ticket public.tickets%rowtype;
  v_current public.ticket_services%rowtype;
  v_updated public.ticket_services%rowtype;
  v_reason text;
  v_old_service_name text;
  v_old_stylist_name text;
  v_new_service_name text;
  v_new_stylist_name text;
  v_new_price numeric;
  v_new_duration integer;
begin
  select c.tenant_id into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner','admin','assistant'], true
  ) c;

  v_reason := nullif(trim(coalesce(p_reason, '')), '');
  if v_reason is null then
    raise exception 'Indica el motivo del cambio.';
  end if;

  select * into v_current
  from public.ticket_services ts
  where ts.id = p_ticket_service_id
    and ts.tenant_id = v_tenant_id
    and ts.branch_id = p_branch_id
  for update;

  if not found then
    raise exception 'El recurso no esta disponible para esta sede.';
  end if;

  select * into v_ticket
  from public.tickets t
  where t.id = v_current.ticket_id
    and t.tenant_id = v_tenant_id
    and t.branch_id = p_branch_id
  for update;

  if not found then
    raise exception 'El recurso no esta disponible para esta sede.';
  end if;

  if v_ticket.status not in ('solicitado','cotizado','apartado','confirmado','en_espera')
     or v_current.status <> 'pendiente' then
    raise exception 'Solo se pueden cambiar servicios pendientes antes de iniciar la atencion.';
  end if;

  if exists (
    select 1 from public.ticket_payments tp
    where tp.ticket_id = v_ticket.id
      and tp.tenant_id = v_tenant_id
      and tp.branch_id = p_branch_id
      and tp.status = 'registrado'
  ) then
    raise exception 'No se pueden modificar servicios de un ticket con pagos registrados.';
  end if;

  select s.name, bs.price, bs.duration_minutes
    into v_new_service_name, v_new_price, v_new_duration
  from public.branch_services bs
  join public.services s
    on s.id = bs.service_id and s.tenant_id = bs.tenant_id and s.active
  where bs.tenant_id = v_tenant_id
    and bs.branch_id = p_branch_id
    and bs.service_id = p_service_id
    and bs.active;

  if not found then
    raise exception 'El servicio no esta disponible para esta sede.';
  end if;

  select s.name, st.name into v_old_service_name, v_old_stylist_name
  from public.services s
  left join public.stylists st
    on st.id = v_current.stylist_id and st.tenant_id = v_tenant_id
  where s.id = v_current.service_id and s.tenant_id = v_tenant_id;

  if p_stylist_id is not null then
    select st.name into v_new_stylist_name
    from public.branch_stylist_services bss
    join public.branch_stylists bst
      on bst.id = bss.branch_stylist_id
     and bst.tenant_id = bss.tenant_id
     and bst.branch_id = bss.branch_id
     and bst.active
     and bst.starts_at <= now()
     and (bst.ends_at is null or bst.ends_at > now())
    join public.branch_services bs
      on bs.id = bss.branch_service_id
     and bs.tenant_id = bss.tenant_id
     and bs.branch_id = bss.branch_id
     and bs.active
    join public.stylists st
      on st.id = bst.stylist_id and st.tenant_id = bst.tenant_id and st.active
    where bss.tenant_id = v_tenant_id
      and bss.branch_id = p_branch_id
      and bst.stylist_id = p_stylist_id
      and bs.service_id = p_service_id
      and bss.active;

    if not found then
      raise exception 'El profesional no esta habilitado para este servicio en la sede.';
    end if;
  end if;

  if v_current.service_id = p_service_id
     and v_current.stylist_id is not distinct from p_stylist_id then
    raise exception 'Selecciona un servicio o profesional diferente.';
  end if;

  update public.ticket_services ts
     set service_id = p_service_id,
         stylist_id = p_stylist_id,
         price = v_new_price,
         duration_minutes = v_new_duration
   where ts.id = v_current.id
     and ts.tenant_id = v_tenant_id
     and ts.branch_id = p_branch_id
  returning * into v_updated;

  insert into public.ticket_service_change_history (
    tenant_id, branch_id, ticket_id, ticket_service_id, event_type,
    previous_service_id, previous_service_name, new_service_id, new_service_name,
    previous_stylist_id, previous_stylist_name, new_stylist_id, new_stylist_name,
    previous_price, new_price, previous_duration_minutes, new_duration_minutes,
    previous_status, new_status, reason, created_by
  ) values (
    v_tenant_id, p_branch_id, v_ticket.id, v_current.id, 'updated',
    v_current.service_id, v_old_service_name, v_updated.service_id, v_new_service_name,
    v_current.stylist_id, v_old_stylist_name, v_updated.stylist_id, v_new_stylist_name,
    v_current.price, v_updated.price, v_current.duration_minutes, v_updated.duration_minutes,
    v_current.status, v_updated.status, v_reason, auth.uid()
  );

  return next v_updated;
end;
$$;

create or replace function public.reschedule_ticket_v2(
  p_branch_id uuid,
  p_ticket_id uuid,
  p_new_scheduled_at timestamptz,
  p_reason text
)
returns setof public.tickets
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_timezone text;
  v_ticket public.tickets%rowtype;
  v_reason text;
  v_local_date date;
  v_local_time time;
  v_day integer;
begin
  select c.tenant_id, c.timezone into v_tenant_id, v_timezone
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner','admin','assistant'], true
  ) c;

  if p_new_scheduled_at is null or p_new_scheduled_at <= now() then
    raise exception 'Selecciona una nueva fecha y hora futura.';
  end if;

  v_reason := nullif(trim(coalesce(p_reason, '')), '');
  if v_reason is null then
    raise exception 'Indica el motivo de la reprogramacion.';
  end if;

  select * into v_ticket
  from public.tickets t
  where t.id = p_ticket_id
    and t.tenant_id = v_tenant_id
    and t.branch_id = p_branch_id
  for update;

  if not found then
    raise exception 'El recurso no esta disponible para esta sede.';
  end if;

  if v_ticket.status not in ('solicitado','cotizado','apartado','confirmado','en_espera') then
    raise exception 'Solo se puede reprogramar un ticket pendiente de atencion.';
  end if;
  if v_ticket.scheduled_at is null then
    raise exception 'El ticket no tiene una fecha actual para reprogramar.';
  end if;
  if p_new_scheduled_at = v_ticket.scheduled_at then
    raise exception 'La nueva fecha y hora debe ser distinta de la actual.';
  end if;

  v_local_date := (p_new_scheduled_at at time zone v_timezone)::date;
  v_local_time := (p_new_scheduled_at at time zone v_timezone)::time;
  v_day := extract(dow from v_local_date)::integer;

  if not exists (
    select 1
    from public.business_hours bh
    where bh.tenant_id = v_tenant_id
      and bh.branch_id = p_branch_id
      and bh.day_of_week = v_day
      and bh.is_open
      and v_local_time >= bh.opens_at
      and v_local_time + (
        select coalesce(sum(ts.duration_minutes), 0) * interval '1 minute'
        from public.ticket_services ts
        where ts.ticket_id = v_ticket.id
          and ts.tenant_id = v_tenant_id
          and ts.branch_id = p_branch_id
          and ts.status in ('pendiente','en_proceso')
      ) <= bh.closes_at
  ) then
    raise exception 'La nueva hora esta fuera del horario operativo de la sede.';
  end if;

  update public.tickets t
     set scheduled_at = p_new_scheduled_at
   where t.id = v_ticket.id
     and t.tenant_id = v_tenant_id
     and t.branch_id = p_branch_id;

  insert into public.ticket_history (
    tenant_id, branch_id, ticket_id, event_type, previous_status, new_status,
    previous_scheduled_at, new_scheduled_at, reason, created_by
  ) values (
    v_tenant_id, p_branch_id, v_ticket.id, 'rescheduled',
    v_ticket.status, v_ticket.status, v_ticket.scheduled_at,
    p_new_scheduled_at, v_reason, auth.uid()
  );

  return query
  select t.* from public.tickets t
  where t.id = v_ticket.id
    and t.tenant_id = v_tenant_id
    and t.branch_id = p_branch_id;
end;
$$;

revoke all on function public.enforce_stylist_schedule_conflict()
  from public, anon, authenticated;

create or replace function public.get_ticket_services_for_management_v2(
  p_branch_id uuid,
  p_ticket_id uuid
)
returns table (
  ticket_service_id uuid,
  service_id uuid,
  service_name text,
  stylist_id uuid,
  stylist_name text,
  price numeric,
  duration_minutes integer,
  service_status text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select c.tenant_id into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner','admin','assistant'], true
  ) c;

  if not exists (
    select 1 from public.tickets t
    where t.id = p_ticket_id
      and t.tenant_id = v_tenant_id
      and t.branch_id = p_branch_id
  ) then
    raise exception 'El recurso no esta disponible para esta sede.';
  end if;

  return query
  select ts.id, ts.service_id, s.name, ts.stylist_id, st.name,
         ts.price, ts.duration_minutes, ts.status
  from public.ticket_services ts
  join public.services s
    on s.id = ts.service_id and s.tenant_id = v_tenant_id
  left join public.stylists st
    on st.id = ts.stylist_id and st.tenant_id = v_tenant_id
  where ts.ticket_id = p_ticket_id
    and ts.tenant_id = v_tenant_id
    and ts.branch_id = p_branch_id
    and ts.status <> 'cancelado'
  order by ts.created_at, s.name, ts.id;
end;
$$;

create or replace function public.get_ticket_payment_summary_v2(
  p_branch_id uuid,
  p_ticket_id uuid
)
returns table (
  ticket_id uuid,
  ticket_status text,
  total_amount numeric,
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
  select c.tenant_id into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner','admin','assistant'], true
  ) c;

  if not exists (
    select 1 from public.tickets t
    where t.id = p_ticket_id
      and t.tenant_id = v_tenant_id
      and t.branch_id = p_branch_id
  ) then
    raise exception 'El recurso no esta disponible para esta sede.';
  end if;

  return query
  with service_total as (
    select coalesce(sum(ts.price) filter (where ts.status <> 'cancelado'), 0)::numeric as amount
    from public.ticket_services ts
    where ts.ticket_id = p_ticket_id
      and ts.tenant_id = v_tenant_id
      and ts.branch_id = p_branch_id
  ), payment_total as (
    select coalesce(sum(tp.amount) filter (where tp.status = 'registrado'), 0)::numeric as amount
    from public.ticket_payments tp
    where tp.ticket_id = p_ticket_id
      and tp.tenant_id = v_tenant_id
      and tp.branch_id = p_branch_id
  )
  select t.id, t.status, st.amount, pt.amount,
         greatest(st.amount - pt.amount, 0)::numeric,
         case when pt.amount = 0 then 'sin_pago'
              when pt.amount < st.amount then 'parcial'
              else 'pagado' end
  from public.tickets t
  cross join service_total st
  cross join payment_total pt
  where t.id = p_ticket_id
    and t.tenant_id = v_tenant_id
    and t.branch_id = p_branch_id;
end;
$$;

create or replace function public.get_ticket_payments_v2(
  p_branch_id uuid,
  p_ticket_id uuid
)
returns table (
  payment_id uuid,
  amount numeric,
  method text,
  reference text,
  notes text,
  status text,
  received_at timestamptz,
  created_by uuid
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select c.tenant_id into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner','admin','assistant'], true
  ) c;

  if not exists (
    select 1 from public.tickets t
    where t.id = p_ticket_id
      and t.tenant_id = v_tenant_id
      and t.branch_id = p_branch_id
  ) then
    raise exception 'El recurso no esta disponible para esta sede.';
  end if;

  return query
  select tp.id, tp.amount, tp.method, tp.reference, tp.notes,
         tp.status, tp.received_at, tp.created_by
  from public.ticket_payments tp
  where tp.ticket_id = p_ticket_id
    and tp.tenant_id = v_tenant_id
    and tp.branch_id = p_branch_id
  order by tp.received_at desc, tp.created_at desc, tp.id;
end;
$$;

revoke all on function public.get_ticket_services_for_management_v2(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.add_ticket_service_v2(uuid, uuid, uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.update_ticket_service_assignment_v2(uuid, uuid, uuid, uuid, text)
  from public, anon, authenticated;
revoke all on function public.remove_ticket_service_v2(uuid, uuid, text)
  from public, anon, authenticated;
revoke all on function public.reschedule_ticket_v2(uuid, uuid, timestamptz, text)
  from public, anon, authenticated;
revoke all on function public.change_ticket_status_v2(uuid, uuid, text, text)
  from public, anon, authenticated;
revoke all on function public.change_ticket_service_status_v2(uuid, uuid, text)
  from public, anon, authenticated;
revoke all on function public.get_ticket_services_for_correction_v2(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.reopen_finished_ticket_service_v2(uuid, uuid, text)
  from public, anon, authenticated;
revoke all on function public.get_ticket_payment_summary_v2(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.get_ticket_payments_v2(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.register_ticket_payment_v2(uuid, uuid, numeric, text, text, text)
  from public, anon, authenticated;
revoke all on function public.void_ticket_payment_v2(uuid, uuid, text)
  from public, anon, authenticated;

grant execute on function public.get_ticket_services_for_management_v2(uuid, uuid)
  to authenticated, service_role;
grant execute on function public.add_ticket_service_v2(uuid, uuid, uuid, uuid)
  to authenticated, service_role;
grant execute on function public.update_ticket_service_assignment_v2(uuid, uuid, uuid, uuid, text)
  to authenticated, service_role;
grant execute on function public.remove_ticket_service_v2(uuid, uuid, text)
  to authenticated, service_role;
grant execute on function public.reschedule_ticket_v2(uuid, uuid, timestamptz, text)
  to authenticated, service_role;
grant execute on function public.change_ticket_status_v2(uuid, uuid, text, text)
  to authenticated, service_role;
grant execute on function public.change_ticket_service_status_v2(uuid, uuid, text)
  to authenticated, service_role;
grant execute on function public.get_ticket_services_for_correction_v2(uuid, uuid)
  to authenticated, service_role;
grant execute on function public.reopen_finished_ticket_service_v2(uuid, uuid, text)
  to authenticated, service_role;
grant execute on function public.get_ticket_payment_summary_v2(uuid, uuid)
  to authenticated, service_role;
grant execute on function public.get_ticket_payments_v2(uuid, uuid)
  to authenticated, service_role;
grant execute on function public.register_ticket_payment_v2(uuid, uuid, numeric, text, text, text)
  to authenticated, service_role;
grant execute on function public.void_ticket_payment_v2(uuid, uuid, text)
  to authenticated, service_role;

comment on function public.enforce_stylist_schedule_conflict()
  is 'Barrera final de choque de agenda serializada y aislada por sede.';

commit;
