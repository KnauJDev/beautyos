-- Paso 1042: prueba transaccional de cambios, reasignacion, retiro y permisos.

begin;

select set_config(
  'request.jwt.claim.sub',
  '7661e1c7-798e-41f0-b2a4-9244e277570b',
  true
);

do $$
declare
  v_client_id uuid;
  v_ticket public.tickets%rowtype;
  v_first record;
  v_second record;
  v_added public.ticket_services%rowtype;
  v_updated public.ticket_services%rowtype;
  v_removed public.ticket_services%rowtype;
  v_visible_count integer;
  v_history_count integer;
begin
  select c.id
    into v_client_id
  from public.clients c
  where c.tenant_id = 'd338021b-1aed-4d4c-8462-0fc571867798'
    and c.active = true
  order by c.created_at
  limit 1;

  select s.id as service_id, ss.stylist_id
    into v_first
  from public.services s
  join public.stylist_services ss
    on ss.service_id = s.id
   and ss.tenant_id = s.tenant_id
   and ss.active = true
  join public.stylists st
    on st.id = ss.stylist_id
   and st.tenant_id = s.tenant_id
   and st.active = true
  where s.tenant_id = 'd338021b-1aed-4d4c-8462-0fc571867798'
    and s.active = true
  order by s.name, st.name
  limit 1;

  select s.id as service_id, ss.stylist_id
    into v_second
  from public.services s
  join public.stylist_services ss
    on ss.service_id = s.id
   and ss.tenant_id = s.tenant_id
   and ss.active = true
  join public.stylists st
    on st.id = ss.stylist_id
   and st.tenant_id = s.tenant_id
   and st.active = true
  where s.tenant_id = 'd338021b-1aed-4d4c-8462-0fc571867798'
    and s.active = true
    and s.id <> v_first.service_id
  order by s.name, st.name
  limit 1;

  if v_client_id is null or v_first.service_id is null or v_second.service_id is null then
    raise exception 'No existen datos suficientes para probar la gestion de servicios.';
  end if;

  select *
    into v_ticket
  from public.create_ticket(
    v_client_id,
    null,
    'manual',
    'Prueba transaccional de gestion de servicios.'
  );

  select *
    into v_added
  from public.add_ticket_service(
    v_ticket.id,
    v_first.service_id,
    v_first.stylist_id
  );

  select count(*)
    into v_visible_count
  from public.get_ticket_services_for_management(v_ticket.id);

  if v_added.status <> 'pendiente' or v_visible_count <> 1 then
    raise exception 'El servicio agregado no quedo disponible para gestion.';
  end if;

  select *
    into v_updated
  from public.update_ticket_service_assignment(
    v_added.id,
    v_second.service_id,
    v_second.stylist_id,
    'Cambio validado por prueba automatica.'
  );

  select count(*)
    into v_history_count
  from public.ticket_service_change_history h
  where h.ticket_service_id = v_added.id
    and h.event_type in ('added', 'updated');

  if v_updated.service_id <> v_second.service_id
     or v_updated.stylist_id is distinct from v_second.stylist_id
     or v_history_count <> 2 then
    raise exception 'El cambio de servicio o estilista no se registro correctamente.';
  end if;

  select *
    into v_removed
  from public.remove_ticket_service(
    v_added.id,
    'Retiro validado por prueba automatica.'
  );

  select count(*)
    into v_visible_count
  from public.get_ticket_services_for_management(v_ticket.id);

  select count(*)
    into v_history_count
  from public.ticket_service_change_history h
  where h.ticket_service_id = v_added.id
    and h.event_type = 'removed';

  if v_removed.status <> 'cancelado'
     or v_visible_count <> 0
     or v_history_count <> 1 then
    raise exception 'El retiro seguro del servicio no se registro correctamente.';
  end if;

  begin
    perform *
    from public.update_ticket_service_assignment(
      v_added.id,
      v_first.service_id,
      v_first.stylist_id,
      'Intento invalido despues del retiro.'
    );
    raise exception 'No debia permitirse modificar un servicio retirado.';
  exception
    when others then
      if position('Solo se pueden cambiar servicios pendientes' in sqlerrm) = 0 then
        raise;
      end if;
  end;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '067dd2e6-9a10-4965-a804-4601c60d724f',
  true
);

do $$
begin
  begin
    perform * from public.get_ticket_services_for_management(
      '00000000-0000-0000-0000-000000000000'
    );
    raise exception 'La gestion debia ser rechazada para un estilista.';
  exception
    when others then
      if position('No autorizado para gestionar servicios del ticket' in sqlerrm) = 0 then
        raise;
      end if;
  end;
end;
$$;

rollback;
