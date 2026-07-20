-- BeautyOS - Compatibilidad de los RPC usados por Flutter durante Tramo B.
-- Ejecutar solo en ensayo; las escrituras terminan con ROLLBACK.

begin;

do $$
declare
  v_user_id uuid;
  v_tenant_id uuid;
  v_primary_branch uuid;
  v_client_id uuid;
  v_service_id uuid;
  v_stylist_id uuid;
  v_ticket_id uuid;
  v_ticket_service_id uuid;
  v_scheduled_ticket_id uuid;
  v_branch_id uuid;
  v_slot timestamptz;
  v_offset integer;
begin
  select up.user_id, up.tenant_id
    into v_user_id, v_tenant_id
  from public.user_profiles up
  where up.active
    and up.role in ('owner','admin')
  order by case when up.role='owner' then 0 else 1 end
  limit 1;

  select b.id into v_primary_branch
  from public.branches b
  where b.tenant_id=v_tenant_id and b.is_primary and b.active;
  select c.id into v_client_id
  from public.clients c
  where c.tenant_id=v_tenant_id and c.active
  order by c.id limit 1;
  select bs.service_id into v_service_id
  from public.branch_services bs
  where bs.tenant_id=v_tenant_id and bs.branch_id=v_primary_branch and bs.active
  order by bs.id limit 1;
  select bss.stylist_id into v_stylist_id
  from public.branch_stylists bss
  join public.stylist_services ss
    on ss.tenant_id=bss.tenant_id
   and ss.stylist_id=bss.stylist_id
   and ss.service_id=v_service_id
   and ss.active
  where bss.tenant_id=v_tenant_id
    and bss.branch_id=v_primary_branch
    and bss.active
  order by bss.id limit 1;

  if v_user_id is null or v_client_id is null or v_service_id is null or v_stylist_id is null then
    raise exception 'La prueba RPC requiere owner/admin, cliente y capacidad activa.';
  end if;

  perform set_config('request.jwt.claim.sub', v_user_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  select x.id, x.branch_id
    into v_ticket_id, v_branch_id
  from public.create_ticket(v_client_id, null, 'manual', 'Prueba RPC Tramo B') x;
  if v_ticket_id is null or v_branch_id is distinct from v_primary_branch then
    raise exception 'RPC create_ticket no conservo compatibilidad multisede.';
  end if;

  select x.id, x.branch_id
    into v_ticket_service_id, v_branch_id
  from public.add_ticket_service(v_ticket_id, v_service_id, v_stylist_id) x;
  if v_ticket_service_id is null or v_branch_id is distinct from v_primary_branch then
    raise exception 'RPC add_ticket_service no heredo la sede del ticket.';
  end if;

  perform 1 from public.get_tickets_summary() limit 1;
  perform 1 from public.get_ticket_service_options() limit 1;

  for v_offset in 1..14 loop
    select s.starts_at into v_slot
    from public.get_available_appointment_slots(
      v_service_id, v_stylist_id, current_date + v_offset
    ) s
    limit 1;
    exit when v_slot is not null;
  end loop;

  if v_slot is null then
    raise exception 'No se encontro un horario de ensayo en los proximos 14 dias.';
  end if;

  select x.id, x.branch_id
    into v_scheduled_ticket_id, v_branch_id
  from public.create_scheduled_ticket_with_service(
    v_client_id, v_service_id, v_stylist_id, v_slot,
    'manual', 'Prueba reserva atomica Tramo B'
  ) x;
  if v_scheduled_ticket_id is null or v_branch_id is distinct from v_primary_branch then
    raise exception 'RPC de reserva atomica no asigno la sede principal.';
  end if;
  if not exists (
    select 1 from public.ticket_services ts
    where ts.ticket_id=v_scheduled_ticket_id
      and ts.tenant_id=v_tenant_id
      and ts.branch_id=v_primary_branch
  ) then
    raise exception 'RPC de reserva atomica no propago la sede al servicio.';
  end if;
end;
$$;

rollback;
