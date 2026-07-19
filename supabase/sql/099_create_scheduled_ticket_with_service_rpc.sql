-- Reserva interna atomica: crea el ticket y su primer servicio en una sola
-- transaccion. El trigger central de agenda conserva la ultima palabra sobre
-- cualquier choque de horario.

create or replace function public.create_scheduled_ticket_with_service(
  p_client_id uuid,
  p_service_id uuid,
  p_stylist_id uuid,
  p_scheduled_at timestamptz,
  p_channel text default 'manual',
  p_notes text default null
)
returns setof public.tickets
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_role text;
  v_ticket public.tickets%rowtype;
  v_service_price numeric;
  v_service_duration integer;
begin
  select up.tenant_id, up.role
    into v_tenant_id, v_role
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.active = true
  limit 1;

  if v_tenant_id is null or v_role not in ('owner', 'admin', 'assistant') then
    raise exception 'No tienes permisos para crear reservas.';
  end if;

  if p_scheduled_at is null then
    raise exception 'La fecha y hora son obligatorias para una reserva.';
  end if;

  perform 1
  from public.clients c
  where c.id = p_client_id
    and c.tenant_id = v_tenant_id
    and c.active = true;

  if not found then
    raise exception 'El cliente no existe, esta inactivo o pertenece a otro negocio.';
  end if;

  select s.price, s.duration_minutes
    into v_service_price, v_service_duration
  from public.services s
  where s.id = p_service_id
    and s.tenant_id = v_tenant_id
    and s.active = true;

  if not found then
    raise exception 'El servicio no existe, esta inactivo o pertenece a otro negocio.';
  end if;

  perform 1
  from public.stylists st
  join public.stylist_services ss
    on ss.stylist_id = st.id
   and ss.tenant_id = st.tenant_id
   and ss.service_id = p_service_id
   and ss.active = true
  where st.id = p_stylist_id
    and st.tenant_id = v_tenant_id
    and st.active = true;

  if not found then
    raise exception 'El estilista no esta activo o no tiene asignado este servicio.';
  end if;

  insert into public.tickets (
    tenant_id,
    client_id,
    scheduled_at,
    status,
    channel,
    notes
  ) values (
    v_tenant_id,
    p_client_id,
    p_scheduled_at,
    'solicitado',
    nullif(trim(coalesce(p_channel, 'manual')), ''),
    nullif(trim(coalesce(p_notes, '')), '')
  )
  returning * into v_ticket;

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
  );

  return next v_ticket;
end;
$$;

revoke all on function public.create_scheduled_ticket_with_service(uuid, uuid, uuid, timestamptz, text, text) from public;
revoke all on function public.create_scheduled_ticket_with_service(uuid, uuid, uuid, timestamptz, text, text) from anon;
grant execute on function public.create_scheduled_ticket_with_service(uuid, uuid, uuid, timestamptz, text, text) to authenticated;
