-- Prueba aislamiento por usuario estilista, fecha y estado. No deja datos.

begin;

do $$
declare
  v_tenant_id uuid;
  v_stylist_id uuid;
  v_stylist_user_id uuid;
  v_client_id uuid;
  v_service_id uuid;
  v_price numeric;
  v_duration integer;
  v_visible_ticket_id uuid;
  v_other_date_ticket_id uuid;
begin
  select up.tenant_id, up.stylist_id, up.user_id
    into v_tenant_id, v_stylist_id, v_stylist_user_id
  from public.user_profiles up
  where up.active = true
    and up.role = 'stylist'
    and up.stylist_id is not null
  limit 1;

  select c.id
    into v_client_id
  from public.clients c
  where c.tenant_id = v_tenant_id
    and c.active = true
  limit 1;

  select s.id, s.price, s.duration_minutes
    into v_service_id, v_price, v_duration
  from public.stylist_services ss
  join public.services s
    on s.id = ss.service_id
   and s.tenant_id = ss.tenant_id
   and s.active = true
  where ss.tenant_id = v_tenant_id
    and ss.stylist_id = v_stylist_id
    and ss.active = true
  limit 1;

  insert into public.tickets (
    tenant_id, client_id, scheduled_at, status, channel, notes
  ) values (
    v_tenant_id, v_client_id, '2099-10-01 15:00:00+00',
    'confirmado', 'manual', 'Agenda diaria fecha seleccionada'
  ) returning id into v_visible_ticket_id;

  insert into public.ticket_services (
    tenant_id, ticket_id, service_id, stylist_id,
    price, duration_minutes, status
  ) values (
    v_tenant_id, v_visible_ticket_id, v_service_id, v_stylist_id,
    v_price, v_duration, 'pendiente'
  );

  insert into public.tickets (
    tenant_id, client_id, scheduled_at, status, channel, notes
  ) values (
    v_tenant_id, v_client_id, '2099-10-02 15:00:00+00',
    'confirmado', 'manual', 'Agenda diaria otra fecha'
  ) returning id into v_other_date_ticket_id;

  insert into public.ticket_services (
    tenant_id, ticket_id, service_id, stylist_id,
    price, duration_minutes, status
  ) values (
    v_tenant_id, v_other_date_ticket_id, v_service_id, v_stylist_id,
    v_price, v_duration, 'pendiente'
  );

  perform set_config(
    'request.jwt.claim.sub',
    v_stylist_user_id::text,
    true
  );

  if not exists (
    select 1
    from public.get_my_stylist_agenda_by_date('2099-10-01') agenda
    where agenda.ticket_id = v_visible_ticket_id
  ) then
    raise exception 'La cita de la fecha elegida no aparecio.';
  end if;

  if exists (
    select 1
    from public.get_my_stylist_agenda_by_date('2099-10-01') agenda
    where agenda.ticket_id = v_other_date_ticket_id
  ) then
    raise exception 'La consulta mezclo citas de otra fecha.';
  end if;
end;
$$;

rollback;
