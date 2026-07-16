-- Pruebas transaccionales: no dejan datos ni configuraciones de prueba.

begin;

select set_config(
  'request.jwt.claim.sub',
  (
    select up.user_id::text
    from public.user_profiles up
    where up.active = true
      and up.role = 'owner'
    limit 1
  ),
  true
);

do $$
declare
  v_tenant_id uuid;
  v_client_id uuid;
  v_stylist_id uuid;
  v_service_id uuid;
  v_first_ticket_id uuid;
  v_second_ticket_id uuid;
  v_service_ids uuid[];
begin
  select up.tenant_id
    into v_tenant_id
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.active = true;

  select c.id
    into v_client_id
  from public.clients c
  where c.tenant_id = v_tenant_id
    and c.active = true
  limit 1;

  select st.id
    into v_stylist_id
  from public.stylists st
  where st.tenant_id = v_tenant_id
    and st.active = true
  limit 1;

  select array_agg(s.id order by s.id)
    into v_service_ids
  from public.services s
  where s.tenant_id = v_tenant_id
    and s.active = true;

  select s.id
    into v_service_id
  from public.services s
  where s.tenant_id = v_tenant_id
    and s.active = true
  order by s.id
  limit 1;

  perform public.set_stylist_services(v_stylist_id, v_service_ids);

  if not exists (
    select 1
    from public.get_stylist_service_options(v_stylist_id) option_row
    where option_row.assigned = true
  ) then
    raise exception 'La prueba no pudo asignar servicios al estilista.';
  end if;

  insert into public.tickets (
    tenant_id, client_id, scheduled_at, status, channel, notes
  ) values (
    v_tenant_id,
    v_client_id,
    '2099-08-21 15:00:00+00',
    'solicitado',
    'manual',
    'Prueba de proteccion de agenda A'
  ) returning id into v_first_ticket_id;

  insert into public.ticket_services (
    tenant_id, ticket_id, service_id, stylist_id,
    price, duration_minutes, status
  )
  select
    v_tenant_id,
    v_first_ticket_id,
    s.id,
    v_stylist_id,
    s.price,
    s.duration_minutes,
    'pendiente'
  from public.services s
  where s.id = v_service_id;

  insert into public.tickets (
    tenant_id, client_id, scheduled_at, status, channel, notes
  ) values (
    v_tenant_id,
    v_client_id,
    '2099-08-21 15:00:00+00',
    'solicitado',
    'manual',
    'Prueba de proteccion de agenda B'
  ) returning id into v_second_ticket_id;

  begin
    insert into public.ticket_services (
      tenant_id, ticket_id, service_id, stylist_id,
      price, duration_minutes, status
    )
    select
      v_tenant_id,
      v_second_ticket_id,
      s.id,
      v_stylist_id,
      s.price,
      s.duration_minutes,
      'pendiente'
    from public.services s
    where s.id = v_service_id;

    raise exception 'La prueba debia rechazar el choque de agenda.';
  exception
    when others then
      if position('Choque de agenda' in sqlerrm) = 0 then
        raise;
      end if;
  end;
end;
$$;

rollback;
