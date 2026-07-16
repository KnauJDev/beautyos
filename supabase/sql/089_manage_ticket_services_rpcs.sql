-- Paso 1041: gestion segura y auditada de servicios dentro de tickets.

create table if not exists public.ticket_service_change_history (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  ticket_id uuid not null references public.tickets(id) on delete restrict,
  ticket_service_id uuid not null references public.ticket_services(id) on delete restrict,
  event_type text not null check (event_type in ('added', 'updated', 'removed')),
  previous_service_id uuid,
  previous_service_name text,
  new_service_id uuid,
  new_service_name text,
  previous_stylist_id uuid,
  previous_stylist_name text,
  new_stylist_id uuid,
  new_stylist_name text,
  previous_price numeric(12, 2),
  new_price numeric(12, 2),
  previous_duration_minutes integer,
  new_duration_minutes integer,
  previous_status text,
  new_status text,
  reason text,
  created_by uuid not null,
  created_at timestamptz not null default now()
);

alter table public.ticket_service_change_history enable row level security;

create index if not exists ticket_service_change_history_tenant_created_idx
  on public.ticket_service_change_history (tenant_id, created_at desc);

create index if not exists ticket_service_change_history_ticket_idx
  on public.ticket_service_change_history (ticket_id);

create index if not exists ticket_service_change_history_service_idx
  on public.ticket_service_change_history (ticket_service_id);

revoke all on table public.ticket_service_change_history from public;
revoke all on table public.ticket_service_change_history from anon;
revoke all on table public.ticket_service_change_history from authenticated;

create or replace function public.get_ticket_services_for_management(
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

  if v_tenant_id is null or v_role not in ('owner', 'admin', 'assistant') then
    raise exception 'No autorizado para gestionar servicios del ticket.';
  end if;

  if not exists (
    select 1
    from public.tickets t
    where t.id = p_ticket_id
      and t.tenant_id = v_tenant_id
  ) then
    raise exception 'Ticket no encontrado o no pertenece al centro actual.';
  end if;

  return query
  select
    ts.id,
    ts.service_id,
    s.name,
    ts.stylist_id,
    st.name,
    ts.price,
    ts.duration_minutes,
    ts.status
  from public.ticket_services ts
  join public.services s
    on s.id = ts.service_id
   and s.tenant_id = v_tenant_id
  left join public.stylists st
    on st.id = ts.stylist_id
   and st.tenant_id = v_tenant_id
  where ts.ticket_id = p_ticket_id
    and ts.tenant_id = v_tenant_id
    and ts.status <> 'cancelado'
  order by ts.created_at, s.name;
end;
$$;

create or replace function public.update_ticket_service_assignment(
  p_ticket_service_id uuid,
  p_service_id uuid,
  p_stylist_id uuid,
  p_reason text
)
returns setof public.ticket_services
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_role text;
  v_ticket_id uuid;
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
  v_has_conflict boolean;
begin
  select up.tenant_id, up.role
    into v_tenant_id, v_role
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.active = true
  limit 1;

  if v_tenant_id is null or v_role not in ('owner', 'admin', 'assistant') then
    raise exception 'No autorizado para modificar servicios del ticket.';
  end if;

  v_reason := nullif(trim(coalesce(p_reason, '')), '');

  if v_reason is null then
    raise exception 'Indica el motivo del cambio.';
  end if;

  select ts.ticket_id
    into v_ticket_id
  from public.ticket_services ts
  where ts.id = p_ticket_service_id
    and ts.tenant_id = v_tenant_id;

  if not found then
    raise exception 'Servicio del ticket no encontrado o no pertenece al centro actual.';
  end if;

  select *
    into v_ticket
  from public.tickets t
  where t.id = v_ticket_id
    and t.tenant_id = v_tenant_id
  for update;

  select *
    into v_current
  from public.ticket_services ts
  where ts.id = p_ticket_service_id
    and ts.tenant_id = v_tenant_id
    and ts.ticket_id = v_ticket.id
  for update;

  if not found then
    raise exception 'Servicio del ticket no disponible.';
  end if;

  if v_ticket.status not in ('solicitado', 'cotizado', 'apartado', 'confirmado', 'en_espera')
     or v_current.status <> 'pendiente' then
    raise exception 'Solo se pueden cambiar servicios pendientes antes de iniciar la atencion.';
  end if;

  if exists (
    select 1
    from public.ticket_payments tp
    where tp.ticket_id = v_ticket.id
      and tp.tenant_id = v_tenant_id
      and tp.status = 'registrado'
  ) then
    raise exception 'No se pueden modificar servicios de un ticket con pagos registrados.';
  end if;

  select s.name, s.price, s.duration_minutes
    into v_new_service_name, v_new_price, v_new_duration
  from public.services s
  where s.id = p_service_id
    and s.tenant_id = v_tenant_id
    and s.active = true;

  if not found then
    raise exception 'El servicio seleccionado no existe, esta inactivo o pertenece a otro negocio.';
  end if;

  select s.name, st.name
    into v_old_service_name, v_old_stylist_name
  from public.services s
  left join public.stylists st
    on st.id = v_current.stylist_id
   and st.tenant_id = v_tenant_id
  where s.id = v_current.service_id
    and s.tenant_id = v_tenant_id;

  if p_stylist_id is not null then
    select st.name
      into v_new_stylist_name
    from public.stylists st
    where st.id = p_stylist_id
      and st.tenant_id = v_tenant_id
      and st.active = true;

    if not found then
      raise exception 'El estilista seleccionado no existe, esta inactivo o pertenece a otro negocio.';
    end if;

    if not exists (
      select 1
      from public.stylist_services ss
      where ss.tenant_id = v_tenant_id
        and ss.stylist_id = p_stylist_id
        and ss.service_id = p_service_id
        and ss.active = true
    ) then
      raise exception 'El estilista seleccionado no tiene asignado este servicio.';
    end if;
  end if;

  if v_current.service_id = p_service_id
     and v_current.stylist_id is not distinct from p_stylist_id then
    raise exception 'Selecciona un servicio o estilista diferente.';
  end if;

  if v_ticket.scheduled_at is not null
     and v_ticket.status in ('apartado', 'confirmado', 'en_espera')
     and p_stylist_id is not null then
    with target_duration as (
      select (
        coalesce(sum(ts.duration_minutes), 0) + v_new_duration
      )::integer as duration_minutes
      from public.ticket_services ts
      where ts.ticket_id = v_ticket.id
        and ts.tenant_id = v_tenant_id
        and ts.id <> v_current.id
        and ts.stylist_id = p_stylist_id
        and ts.status in ('pendiente', 'en_proceso')
    ),
    occupied_assignments as (
      select
        other_t.scheduled_at,
        sum(other_ts.duration_minutes)::integer as duration_minutes
      from public.ticket_services other_ts
      join public.tickets other_t
        on other_t.id = other_ts.ticket_id
       and other_t.tenant_id = other_ts.tenant_id
      where other_ts.tenant_id = v_tenant_id
        and other_ts.ticket_id <> v_ticket.id
        and other_ts.stylist_id = p_stylist_id
        and other_ts.status in ('pendiente', 'en_proceso')
        and other_t.status in ('apartado', 'confirmado', 'en_espera', 'en_proceso')
        and other_t.scheduled_at is not null
      group by other_t.id, other_t.scheduled_at
    )
    select exists (
      select 1
      from occupied_assignments oa
      cross join target_duration td
      where v_ticket.scheduled_at
              < oa.scheduled_at + (oa.duration_minutes * interval '1 minute')
        and v_ticket.scheduled_at
              + (td.duration_minutes * interval '1 minute') > oa.scheduled_at
    )
      into v_has_conflict;

    if v_has_conflict then
      raise exception 'El cambio presenta un choque de agenda para %.', v_new_stylist_name;
    end if;
  end if;

  update public.ticket_services ts
     set service_id = p_service_id,
         stylist_id = p_stylist_id,
         price = v_new_price,
         duration_minutes = v_new_duration
   where ts.id = v_current.id
     and ts.tenant_id = v_tenant_id
  returning * into v_updated;

  insert into public.ticket_service_change_history (
    tenant_id,
    ticket_id,
    ticket_service_id,
    event_type,
    previous_service_id,
    previous_service_name,
    new_service_id,
    new_service_name,
    previous_stylist_id,
    previous_stylist_name,
    new_stylist_id,
    new_stylist_name,
    previous_price,
    new_price,
    previous_duration_minutes,
    new_duration_minutes,
    previous_status,
    new_status,
    reason,
    created_by
  ) values (
    v_tenant_id,
    v_ticket.id,
    v_current.id,
    'updated',
    v_current.service_id,
    v_old_service_name,
    v_updated.service_id,
    v_new_service_name,
    v_current.stylist_id,
    v_old_stylist_name,
    v_updated.stylist_id,
    v_new_stylist_name,
    v_current.price,
    v_updated.price,
    v_current.duration_minutes,
    v_updated.duration_minutes,
    v_current.status,
    v_updated.status,
    v_reason,
    auth.uid()
  );

  return next v_updated;
end;
$$;

create or replace function public.remove_ticket_service(
  p_ticket_service_id uuid,
  p_reason text
)
returns setof public.ticket_services
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_role text;
  v_ticket_id uuid;
  v_ticket public.tickets%rowtype;
  v_current public.ticket_services%rowtype;
  v_removed public.ticket_services%rowtype;
  v_reason text;
  v_service_name text;
  v_stylist_name text;
begin
  select up.tenant_id, up.role
    into v_tenant_id, v_role
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.active = true
  limit 1;

  if v_tenant_id is null or v_role not in ('owner', 'admin', 'assistant') then
    raise exception 'No autorizado para retirar servicios del ticket.';
  end if;

  v_reason := nullif(trim(coalesce(p_reason, '')), '');

  if v_reason is null then
    raise exception 'Indica el motivo para retirar el servicio.';
  end if;

  select ts.ticket_id
    into v_ticket_id
  from public.ticket_services ts
  where ts.id = p_ticket_service_id
    and ts.tenant_id = v_tenant_id;

  if not found then
    raise exception 'Servicio del ticket no encontrado o no pertenece al centro actual.';
  end if;

  select *
    into v_ticket
  from public.tickets t
  where t.id = v_ticket_id
    and t.tenant_id = v_tenant_id
  for update;

  select *
    into v_current
  from public.ticket_services ts
  where ts.id = p_ticket_service_id
    and ts.tenant_id = v_tenant_id
    and ts.ticket_id = v_ticket.id
  for update;

  if not found then
    raise exception 'Servicio del ticket no disponible.';
  end if;

  if v_ticket.status not in ('solicitado', 'cotizado', 'apartado', 'confirmado', 'en_espera')
     or v_current.status <> 'pendiente' then
    raise exception 'Solo se pueden retirar servicios pendientes antes de iniciar la atencion.';
  end if;

  if exists (
    select 1
    from public.ticket_payments tp
    where tp.ticket_id = v_ticket.id
      and tp.tenant_id = v_tenant_id
      and tp.status = 'registrado'
  ) then
    raise exception 'No se pueden modificar servicios de un ticket con pagos registrados.';
  end if;

  if v_ticket.status in ('apartado', 'confirmado', 'en_espera')
     and not exists (
       select 1
       from public.ticket_services ts
       where ts.ticket_id = v_ticket.id
         and ts.tenant_id = v_tenant_id
         and ts.id <> v_current.id
         and ts.status in ('pendiente', 'en_proceso')
     ) then
    raise exception 'Cambia el servicio o agrega otro antes de retirar el ultimo de un ticket programado.';
  end if;

  select s.name, st.name
    into v_service_name, v_stylist_name
  from public.services s
  left join public.stylists st
    on st.id = v_current.stylist_id
   and st.tenant_id = v_tenant_id
  where s.id = v_current.service_id
    and s.tenant_id = v_tenant_id;

  update public.ticket_services ts
     set status = 'cancelado'
   where ts.id = v_current.id
     and ts.tenant_id = v_tenant_id
  returning * into v_removed;

  insert into public.ticket_service_change_history (
    tenant_id,
    ticket_id,
    ticket_service_id,
    event_type,
    previous_service_id,
    previous_service_name,
    new_service_id,
    new_service_name,
    previous_stylist_id,
    previous_stylist_name,
    new_stylist_id,
    new_stylist_name,
    previous_price,
    new_price,
    previous_duration_minutes,
    new_duration_minutes,
    previous_status,
    new_status,
    reason,
    created_by
  ) values (
    v_tenant_id,
    v_ticket.id,
    v_current.id,
    'removed',
    v_current.service_id,
    v_service_name,
    v_current.service_id,
    v_service_name,
    v_current.stylist_id,
    v_stylist_name,
    v_current.stylist_id,
    v_stylist_name,
    v_current.price,
    v_current.price,
    v_current.duration_minutes,
    v_current.duration_minutes,
    v_current.status,
    v_removed.status,
    v_reason,
    auth.uid()
  );

  return next v_removed;
end;
$$;

create or replace function public.add_ticket_service(
  p_ticket_id uuid,
  p_service_id uuid,
  p_stylist_id uuid default null
)
returns setof public.ticket_services
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_role text;
  v_ticket public.tickets%rowtype;
  v_added public.ticket_services%rowtype;
  v_service_price numeric;
  v_service_duration integer;
  v_service_name text;
  v_stylist_name text;
  v_has_conflict boolean;
begin
  select up.tenant_id, up.role
    into v_tenant_id, v_role
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.active = true
  limit 1;

  if v_tenant_id is null or v_role not in ('owner', 'admin', 'assistant') then
    raise exception 'No tienes permisos para agregar servicios al ticket.';
  end if;

  select *
    into v_ticket
  from public.tickets t
  where t.id = p_ticket_id
    and t.tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'El ticket no existe o pertenece a otro negocio.';
  end if;

  if v_ticket.status not in ('solicitado', 'cotizado', 'apartado', 'confirmado', 'en_espera') then
    raise exception 'No se pueden agregar servicios cuando la atencion ya inicio o el ticket termino.';
  end if;

  if exists (
    select 1
    from public.ticket_payments tp
    where tp.ticket_id = v_ticket.id
      and tp.tenant_id = v_tenant_id
      and tp.status = 'registrado'
  ) then
    raise exception 'No se pueden modificar servicios de un ticket con pagos registrados.';
  end if;

  select s.price, s.duration_minutes, s.name
    into v_service_price, v_service_duration, v_service_name
  from public.services s
  where s.id = p_service_id
    and s.tenant_id = v_tenant_id
    and s.active = true
  limit 1;

  if not found then
    raise exception 'El servicio no existe, esta inactivo o pertenece a otro negocio.';
  end if;

  if p_stylist_id is not null then
    select st.name
      into v_stylist_name
    from public.stylists st
    where st.id = p_stylist_id
      and st.tenant_id = v_tenant_id
      and st.active = true;

    if not found then
      raise exception 'El estilista no existe, esta inactivo o pertenece a otro negocio.';
    end if;

    if not exists (
      select 1
      from public.stylist_services ss
      where ss.tenant_id = v_tenant_id
        and ss.stylist_id = p_stylist_id
        and ss.service_id = p_service_id
        and ss.active = true
    ) then
      raise exception 'El estilista seleccionado no tiene asignado este servicio.';
    end if;
  end if;

  if v_ticket.scheduled_at is not null
     and v_ticket.status in ('apartado', 'confirmado', 'en_espera')
     and p_stylist_id is not null then
    with target_duration as (
      select (
        coalesce(sum(ts.duration_minutes), 0) + v_service_duration
      )::integer as duration_minutes
      from public.ticket_services ts
      where ts.ticket_id = v_ticket.id
        and ts.tenant_id = v_tenant_id
        and ts.stylist_id = p_stylist_id
        and ts.status in ('pendiente', 'en_proceso')
    ),
    occupied_assignments as (
      select
        other_t.scheduled_at,
        sum(other_ts.duration_minutes)::integer as duration_minutes
      from public.ticket_services other_ts
      join public.tickets other_t
        on other_t.id = other_ts.ticket_id
       and other_t.tenant_id = other_ts.tenant_id
      where other_ts.tenant_id = v_tenant_id
        and other_ts.ticket_id <> v_ticket.id
        and other_ts.stylist_id = p_stylist_id
        and other_ts.status in ('pendiente', 'en_proceso')
        and other_t.status in ('apartado', 'confirmado', 'en_espera', 'en_proceso')
        and other_t.scheduled_at is not null
      group by other_t.id, other_t.scheduled_at
    )
    select exists (
      select 1
      from occupied_assignments oa
      cross join target_duration td
      where v_ticket.scheduled_at
              < oa.scheduled_at + (oa.duration_minutes * interval '1 minute')
        and v_ticket.scheduled_at
              + (td.duration_minutes * interval '1 minute') > oa.scheduled_at
    )
      into v_has_conflict;

    if v_has_conflict then
      raise exception 'El cambio presenta un choque de agenda para %.', v_stylist_name;
    end if;
  end if;

  insert into public.ticket_services (
    tenant_id,
    ticket_id,
    service_id,
    stylist_id,
    price,
    duration_minutes,
    status
  ) values (
    v_tenant_id,
    v_ticket.id,
    p_service_id,
    p_stylist_id,
    v_service_price,
    v_service_duration,
    'pendiente'
  )
  returning * into v_added;

  insert into public.ticket_service_change_history (
    tenant_id,
    ticket_id,
    ticket_service_id,
    event_type,
    new_service_id,
    new_service_name,
    new_stylist_id,
    new_stylist_name,
    new_price,
    new_duration_minutes,
    new_status,
    reason,
    created_by
  ) values (
    v_tenant_id,
    v_ticket.id,
    v_added.id,
    'added',
    v_added.service_id,
    v_service_name,
    v_added.stylist_id,
    v_stylist_name,
    v_added.price,
    v_added.duration_minutes,
    v_added.status,
    'Servicio agregado al ticket',
    auth.uid()
  );

  return next v_added;
end;
$$;

revoke all on function public.get_ticket_services_for_management(uuid) from public;
revoke all on function public.get_ticket_services_for_management(uuid) from anon;
grant execute on function public.get_ticket_services_for_management(uuid) to authenticated;

revoke all on function public.add_ticket_service(uuid, uuid, uuid) from public;
revoke all on function public.add_ticket_service(uuid, uuid, uuid) from anon;
grant execute on function public.add_ticket_service(uuid, uuid, uuid) to authenticated;

revoke all on function public.update_ticket_service_assignment(uuid, uuid, uuid, text) from public;
revoke all on function public.update_ticket_service_assignment(uuid, uuid, uuid, text) from anon;
grant execute on function public.update_ticket_service_assignment(uuid, uuid, uuid, text) to authenticated;

revoke all on function public.remove_ticket_service(uuid, text) from public;
revoke all on function public.remove_ticket_service(uuid, text) from anon;
grant execute on function public.remove_ticket_service(uuid, text) to authenticated;
