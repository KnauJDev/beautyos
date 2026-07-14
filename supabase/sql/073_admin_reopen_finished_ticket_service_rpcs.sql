-- Paso 1029: corrección administrativa auditada de finalizaciones accidentales.

create or replace function public.get_ticket_services_for_correction(
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

  if v_tenant_id is null or v_role not in ('owner', 'admin') then
    raise exception 'Solo owner o admin puede corregir una finalización.';
  end if;

  if not exists (
    select 1
    from public.tickets t
    where t.id = p_ticket_id
      and t.tenant_id = v_tenant_id
      and t.status in ('en_proceso', 'finalizado')
  ) then
    raise exception 'Ticket no encontrado o no admite corrección.';
  end if;

  return query
  select
    ts.id,
    s.name,
    coalesce(st.name, 'Sin estilista'),
    ts.status,
    last_finish.created_at
  from public.ticket_services ts
  join public.services s
    on s.id = ts.service_id
   and s.tenant_id = v_tenant_id
  left join public.stylists st
    on st.id = ts.stylist_id
   and st.tenant_id = v_tenant_id
  left join lateral (
    select h.created_at
    from public.ticket_service_history h
    where h.ticket_service_id = ts.id
      and h.tenant_id = v_tenant_id
      and h.new_status = 'finalizado'
    order by h.created_at desc
    limit 1
  ) last_finish on true
  where ts.ticket_id = p_ticket_id
    and ts.tenant_id = v_tenant_id
    and ts.status = 'finalizado'
  order by last_finish.created_at desc nulls last, s.name;
end;
$$;

create or replace function public.reopen_finished_ticket_service(
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
  v_reason text;
  v_service public.ticket_services%rowtype;
  v_ticket public.tickets%rowtype;
begin
  select up.tenant_id, up.role
    into v_tenant_id, v_role
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.active = true
  limit 1;

  if v_tenant_id is null or v_role not in ('owner', 'admin') then
    raise exception 'Solo owner o admin puede corregir una finalización.';
  end if;

  v_reason := nullif(trim(coalesce(p_reason, '')), '');

  if v_reason is null then
    raise exception 'Indica el motivo de la corrección.';
  end if;

  select *
    into v_service
  from public.ticket_services ts
  where ts.id = p_ticket_service_id
    and ts.tenant_id = v_tenant_id
  for update;

  if not found or v_service.status <> 'finalizado' then
    raise exception 'El servicio no está finalizado o no pertenece al centro actual.';
  end if;

  select *
    into v_ticket
  from public.tickets t
  where t.id = v_service.ticket_id
    and t.tenant_id = v_tenant_id
  for update;

  if not found or v_ticket.status not in ('en_proceso', 'finalizado') then
    raise exception 'El ticket ya no admite esta corrección.';
  end if;

  update public.ticket_services
     set status = 'en_proceso'
   where id = v_service.id
     and tenant_id = v_tenant_id;

  insert into public.ticket_service_history (
    tenant_id,
    ticket_id,
    ticket_service_id,
    previous_status,
    new_status,
    reason,
    created_by
  ) values (
    v_tenant_id,
    v_ticket.id,
    v_service.id,
    'finalizado',
    'en_proceso',
    v_reason,
    auth.uid()
  );

  if v_ticket.status = 'finalizado' then
    update public.tickets
       set status = 'en_proceso'
     where id = v_ticket.id
       and tenant_id = v_tenant_id;

    insert into public.ticket_history (
      tenant_id,
      ticket_id,
      event_type,
      previous_status,
      new_status,
      reason,
      created_by
    ) values (
      v_tenant_id,
      v_ticket.id,
      'status_changed',
      'finalizado',
      'en_proceso',
      'Corrección administrativa: ' || v_reason,
      auth.uid()
    );
  end if;

  return query
  select ts.*
  from public.ticket_services ts
  where ts.id = v_service.id;
end;
$$;

revoke all on function public.get_ticket_services_for_correction(uuid) from public;
revoke all on function public.get_ticket_services_for_correction(uuid) from anon;
grant execute on function public.get_ticket_services_for_correction(uuid) to authenticated;

revoke all on function public.reopen_finished_ticket_service(uuid, text) from public;
revoke all on function public.reopen_finished_ticket_service(uuid, text) from anon;
grant execute on function public.reopen_finished_ticket_service(uuid, text) to authenticated;
