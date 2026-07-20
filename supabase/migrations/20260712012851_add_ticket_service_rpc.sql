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
  v_service_price numeric;
  v_service_duration integer;
begin
  select up.tenant_id
    into v_tenant_id
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.active = true
    and up.role in ('owner', 'admin', 'assistant')
  limit 1;

  if v_tenant_id is null then
    raise exception 'No tienes permisos para agregar servicios al ticket.';
  end if;

  if not exists (
    select 1
    from public.tickets t
    where t.id = p_ticket_id
      and t.tenant_id = v_tenant_id
      and t.status not in ('finalizado', 'cerrado', 'cancelado', 'no_asistio')
  ) then
    raise exception 'El ticket no existe, pertenece a otro negocio o ya está cerrado.';
  end if;

  select s.price, s.duration_minutes
    into v_service_price, v_service_duration
  from public.services s
  where s.id = p_service_id
    and s.tenant_id = v_tenant_id
    and s.active = true
  limit 1;

  if not found then
    raise exception 'El servicio no existe, está inactivo o pertenece a otro negocio.';
  end if;

  if p_stylist_id is not null then
    if not exists (
      select 1
      from public.stylists st
      where st.id = p_stylist_id
        and st.tenant_id = v_tenant_id
        and st.active = true
    ) then
      raise exception 'El estilista no existe, está inactivo o pertenece a otro negocio.';
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

  return query
  insert into public.ticket_services (
    tenant_id,
    ticket_id,
    service_id,
    stylist_id,
    price,
    duration_minutes,
    status
  )
  values (
    v_tenant_id,
    p_ticket_id,
    p_service_id,
    p_stylist_id,
    v_service_price,
    v_service_duration,
    'pendiente'
  )
  returning *;
end;
$$;

revoke all on function public.add_ticket_service(uuid, uuid, uuid) from public;
revoke all on function public.add_ticket_service(uuid, uuid, uuid) from anon;
grant execute on function public.add_ticket_service(uuid, uuid, uuid) to authenticated;

select
  routine_schema,
  routine_name,
  security_type
from information_schema.routines
where routine_schema = 'public'
  and routine_name = 'add_ticket_service';
