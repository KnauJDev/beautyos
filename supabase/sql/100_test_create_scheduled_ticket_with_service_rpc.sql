begin;

select set_config(
  'request.jwt.claim.sub',
  (
    select up.user_id::text
    from public.user_profiles up
    where up.active = true
      and up.role in ('owner', 'admin')
    order by case up.role when 'owner' then 0 else 1 end
    limit 1
  ),
  true
);

do $$
declare
  v_tenant_id uuid;
  v_client_id uuid;
  v_service_id uuid;
  v_stylist_id uuid;
  v_ticket public.tickets%rowtype;
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
  order by c.created_at
  limit 1;

  select ss.service_id, ss.stylist_id
    into v_service_id, v_stylist_id
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
  order by ss.service_id, ss.stylist_id
  limit 1;

  select *
    into v_ticket
  from public.create_scheduled_ticket_with_service(
    v_client_id,
    v_service_id,
    v_stylist_id,
    '2031-01-01 10:00:00-05',
    'manual',
    'Prueba transaccional de reserva guiada.'
  );

  if v_ticket.id is null or not exists (
    select 1
    from public.ticket_services ts
    where ts.ticket_id = v_ticket.id
      and ts.tenant_id = v_tenant_id
      and ts.service_id = v_service_id
      and ts.stylist_id = v_stylist_id
      and ts.status = 'pendiente'
  ) then
    raise exception 'La reserva no creo ticket y servicio asignado.';
  end if;
end;
$$;

-- La segunda reserva para el mismo intervalo debe fallar y no dejar un
-- ticket incompleto, porque toda la operacion es atomica.
do $$
declare
  v_tenant_id uuid;
  v_client_id uuid;
  v_service_id uuid;
  v_stylist_id uuid;
  v_before_count integer;
  v_after_count integer;
begin
  select up.tenant_id into v_tenant_id
  from public.user_profiles up
  where up.user_id = auth.uid() and up.active = true;

  select c.id into v_client_id
  from public.clients c
  where c.tenant_id = v_tenant_id and c.active = true
  limit 1;

  select ss.service_id, ss.stylist_id into v_service_id, v_stylist_id
  from public.stylist_services ss
  join public.services s
    on s.id = ss.service_id and s.tenant_id = ss.tenant_id and s.active
  join public.stylists st
    on st.id = ss.stylist_id and st.tenant_id = ss.tenant_id and st.active
  where ss.tenant_id = v_tenant_id and ss.active
  limit 1;

  perform 1
  from public.create_scheduled_ticket_with_service(
    v_client_id, v_service_id, v_stylist_id,
    '2032-01-01 10:00:00-05', 'manual', 'Prueba de choque A'
  );

  select count(*) into v_before_count
  from public.tickets t
  where t.tenant_id = v_tenant_id;

  begin
    perform 1
    from public.create_scheduled_ticket_with_service(
      v_client_id, v_service_id, v_stylist_id,
      '2032-01-01 10:00:00-05', 'manual', 'Prueba de choque B'
    );
    raise exception 'La segunda reserva debia ser rechazada por choque.';
  exception
    when others then
      if position('Choque de agenda' in sqlerrm) = 0 then
        raise;
      end if;
  end;

  select count(*) into v_after_count
  from public.tickets t
  where t.tenant_id = v_tenant_id;

  if v_after_count <> v_before_count then
    raise exception 'Una reserva rechazada dejo un ticket incompleto.';
  end if;
end;
$$;

rollback;
