-- Permite corregir la hora desde solicitado o cotizado sin debilitar
-- la proteccion central contra choques de agenda.

create or replace function public.reschedule_ticket(
  p_ticket_id uuid,
  p_new_scheduled_at timestamptz,
  p_reason text
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
  v_reason text;
  v_conflicting_stylist_names text;
begin
  select up.tenant_id, up.role
    into v_tenant_id, v_role
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.active = true
  limit 1;

  if v_tenant_id is null or v_role not in ('owner', 'admin', 'assistant') then
    raise exception 'No autorizado para reprogramar tickets.';
  end if;

  if p_new_scheduled_at is null then
    raise exception 'Selecciona la nueva fecha y hora.';
  end if;

  v_reason := nullif(trim(coalesce(p_reason, '')), '');

  if v_reason is null then
    raise exception 'Indica el motivo de la reprogramacion.';
  end if;

  select *
    into v_ticket
  from public.tickets t
  where t.id = p_ticket_id
    and t.tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'Ticket no encontrado o no pertenece al centro actual.';
  end if;

  if v_ticket.status not in (
    'solicitado', 'cotizado', 'apartado', 'confirmado', 'en_espera'
  ) then
    raise exception 'Solo se puede reprogramar un ticket pendiente de atencion.';
  end if;

  if v_ticket.scheduled_at is null then
    raise exception 'El ticket no tiene una fecha actual para reprogramar.';
  end if;

  if p_new_scheduled_at = v_ticket.scheduled_at then
    raise exception 'La nueva fecha y hora debe ser distinta de la actual.';
  end if;

  if p_new_scheduled_at <= now() then
    raise exception 'La nueva fecha y hora debe estar en el futuro.';
  end if;

  with target_assignments as (
    select
      ts.stylist_id,
      sum(ts.duration_minutes)::integer as duration_minutes
    from public.ticket_services ts
    where ts.ticket_id = v_ticket.id
      and ts.tenant_id = v_tenant_id
      and ts.stylist_id is not null
      and ts.status in ('pendiente', 'en_proceso')
    group by ts.stylist_id
  ),
  occupied_assignments as (
    select
      other_ts.stylist_id,
      other_t.scheduled_at,
      sum(other_ts.duration_minutes)::integer as duration_minutes
    from public.ticket_services other_ts
    join public.tickets other_t
      on other_t.id = other_ts.ticket_id
     and other_t.tenant_id = other_ts.tenant_id
    where other_ts.tenant_id = v_tenant_id
      and other_ts.ticket_id <> v_ticket.id
      and other_ts.stylist_id is not null
      and other_ts.status in ('pendiente', 'en_proceso')
      and other_t.status in (
        'solicitado', 'cotizado', 'apartado',
        'confirmado', 'en_espera', 'en_proceso'
      )
      and other_t.scheduled_at is not null
    group by other_ts.stylist_id, other_t.id, other_t.scheduled_at
  ),
  conflicts as (
    select distinct ta.stylist_id
    from target_assignments ta
    join occupied_assignments oa
      on oa.stylist_id = ta.stylist_id
     and p_new_scheduled_at
           < oa.scheduled_at + (oa.duration_minutes * interval '1 minute')
     and p_new_scheduled_at
           + (ta.duration_minutes * interval '1 minute') > oa.scheduled_at
  )
  select string_agg(st.name, ', ' order by st.name)
    into v_conflicting_stylist_names
  from conflicts c
  join public.stylists st
    on st.id = c.stylist_id
   and st.tenant_id = v_tenant_id;

  if v_conflicting_stylist_names is not null then
    raise exception 'La nueva hora presenta un choque de agenda para: %.',
      v_conflicting_stylist_names;
  end if;

  update public.tickets
     set scheduled_at = p_new_scheduled_at
   where id = v_ticket.id
     and tenant_id = v_tenant_id;

  insert into public.ticket_history (
    tenant_id,
    ticket_id,
    event_type,
    previous_status,
    new_status,
    previous_scheduled_at,
    new_scheduled_at,
    reason,
    created_by
  ) values (
    v_tenant_id,
    v_ticket.id,
    'rescheduled',
    v_ticket.status,
    v_ticket.status,
    v_ticket.scheduled_at,
    p_new_scheduled_at,
    v_reason,
    auth.uid()
  );

  return query
  select t.*
  from public.tickets t
  where t.id = v_ticket.id;
end;
$$;

revoke all on function public.reschedule_ticket(uuid, timestamptz, text) from public;
revoke all on function public.reschedule_ticket(uuid, timestamptz, text) from anon;
grant execute on function public.reschedule_ticket(uuid, timestamptz, text) to authenticated;
