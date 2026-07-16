-- Comprueba que un solicitado se puede mover a una hora libre y que
-- una hora ocupada sigue siendo rechazada. Rollback evita datos persistentes.

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
  v_price numeric;
  v_duration integer;
  v_first_ticket_id uuid;
  v_second_ticket_id uuid;
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

  select ss.stylist_id, s.id, s.price, s.duration_minutes
    into v_stylist_id, v_service_id, v_price, v_duration
  from public.stylist_services ss
  join public.services s
    on s.id = ss.service_id
   and s.tenant_id = ss.tenant_id
   and s.active = true
  join public.stylists st
    on st.id = ss.stylist_id
   and st.tenant_id = ss.tenant_id
   and st.active = true
  where ss.tenant_id = v_tenant_id
    and ss.active = true
  limit 1;

  insert into public.tickets (
    tenant_id, client_id, scheduled_at, status, channel, notes
  ) values (
    v_tenant_id, v_client_id, '2099-09-10 15:00:00+00',
    'solicitado', 'manual', 'Prueba reprogramacion solicitado A'
  ) returning id into v_first_ticket_id;

  insert into public.ticket_services (
    tenant_id, ticket_id, service_id, stylist_id,
    price, duration_minutes, status
  ) values (
    v_tenant_id, v_first_ticket_id, v_service_id, v_stylist_id,
    v_price, v_duration, 'pendiente'
  );

  insert into public.tickets (
    tenant_id, client_id, scheduled_at, status, channel, notes
  ) values (
    v_tenant_id, v_client_id, '2099-09-10 19:00:00+00',
    'solicitado', 'manual', 'Prueba reprogramacion solicitado B'
  ) returning id into v_second_ticket_id;

  insert into public.ticket_services (
    tenant_id, ticket_id, service_id, stylist_id,
    price, duration_minutes, status
  ) values (
    v_tenant_id, v_second_ticket_id, v_service_id, v_stylist_id,
    v_price, v_duration, 'pendiente'
  );

  begin
    perform public.reschedule_ticket(
      v_second_ticket_id,
      '2099-09-10 15:00:00+00',
      'Prueba controlada de choque'
    );
    raise exception 'La prueba debia rechazar el choque al reprogramar.';
  exception
    when others then
      if position('choque de agenda' in lower(sqlerrm)) = 0 then
        raise;
      end if;
  end;

  perform public.reschedule_ticket(
    v_second_ticket_id,
    '2099-09-10 22:00:00+00',
    'Prueba controlada de hora libre'
  );

  if not exists (
    select 1
    from public.tickets t
    where t.id = v_second_ticket_id
      and t.status = 'solicitado'
      and t.scheduled_at = '2099-09-10 22:00:00+00'
  ) then
    raise exception 'La reprogramacion del solicitado no se guardo.';
  end if;
end;
$$;

rollback;
