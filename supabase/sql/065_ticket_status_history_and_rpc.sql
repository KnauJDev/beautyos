-- Paso 1026B: historial y transiciones seguras para tickets.
-- La reprogramación usará esta misma bitácora en el paso siguiente.

create table if not exists public.ticket_history (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  ticket_id uuid not null references public.tickets(id) on delete restrict,
  event_type text not null check (event_type in ('status_changed', 'rescheduled')),
  previous_status text,
  new_status text,
  previous_scheduled_at timestamptz,
  new_scheduled_at timestamptz,
  reason text,
  created_by uuid not null,
  created_at timestamptz not null default now()
);

alter table public.ticket_history enable row level security;

create index if not exists ticket_history_tenant_ticket_created_at_idx
  on public.ticket_history (tenant_id, ticket_id, created_at desc);

revoke all on table public.ticket_history from public;
revoke all on table public.ticket_history from anon;
revoke all on table public.ticket_history from authenticated;

create or replace function public.change_ticket_status(
  p_ticket_id uuid,
  p_new_status text,
  p_reason text default null
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
  v_new_status text;
  v_reason text;
begin
  select up.tenant_id, up.role
    into v_tenant_id, v_role
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.active = true
  limit 1;

  if v_tenant_id is null or v_role not in ('owner', 'admin', 'assistant') then
    raise exception 'No autorizado para cambiar el estado del ticket.';
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

  v_new_status := lower(trim(coalesce(p_new_status, '')));
  v_reason := nullif(trim(coalesce(p_reason, '')), '');

  if v_new_status not in (
    'solicitado', 'cotizado', 'apartado', 'confirmado', 'en_espera',
    'en_proceso', 'finalizado', 'cerrado', 'cancelado', 'no_asistio'
  ) then
    raise exception 'Estado de ticket no válido.';
  end if;

  if v_new_status = v_ticket.status then
    return query select t.* from public.tickets t where t.id = v_ticket.id;
    return;
  end if;

  if v_new_status = 'cerrado' then
    raise exception 'Un ticket solo podrá cerrarse cuando exista el registro de pago.';
  end if;

  if v_new_status in ('apartado', 'confirmado', 'en_espera', 'en_proceso')
     and v_ticket.scheduled_at is null then
    raise exception 'Programa fecha y hora antes de llevar el ticket a ese estado.';
  end if;

  if not (
    (v_ticket.status = 'solicitado' and v_new_status in ('cotizado', 'apartado', 'confirmado', 'cancelado'))
    or (v_ticket.status = 'cotizado' and v_new_status in ('apartado', 'confirmado', 'cancelado'))
    or (v_ticket.status = 'apartado' and v_new_status in ('confirmado', 'cancelado'))
    or (v_ticket.status = 'confirmado' and v_new_status in ('en_espera', 'en_proceso', 'cancelado', 'no_asistio'))
    or (v_ticket.status = 'en_espera' and v_new_status in ('en_proceso', 'cancelado', 'no_asistio'))
    or (v_ticket.status = 'en_proceso' and v_new_status = 'finalizado')
  ) then
    raise exception 'La transición de % a % no está permitida.', v_ticket.status, v_new_status;
  end if;

  if v_new_status in ('cancelado', 'no_asistio')
     and exists (
       select 1
       from public.ticket_services ts
       where ts.ticket_id = v_ticket.id
         and ts.tenant_id = v_tenant_id
         and ts.status = 'finalizado'
     ) then
    raise exception 'No se puede % un ticket con servicios finalizados.', v_new_status;
  end if;

  if v_new_status = 'en_proceso'
     and not exists (
       select 1
       from public.ticket_services ts
       where ts.ticket_id = v_ticket.id
         and ts.tenant_id = v_tenant_id
         and ts.status in ('pendiente', 'en_proceso')
     ) then
    raise exception 'El ticket necesita al menos un servicio activo para iniciar atención.';
  end if;

  if v_new_status = 'finalizado'
     and (
       not exists (
         select 1
         from public.ticket_services ts
         where ts.ticket_id = v_ticket.id
           and ts.tenant_id = v_tenant_id
           and ts.status = 'finalizado'
       )
       or exists (
         select 1
         from public.ticket_services ts
         where ts.ticket_id = v_ticket.id
           and ts.tenant_id = v_tenant_id
           and ts.status in ('pendiente', 'en_proceso')
       )
     ) then
    raise exception 'Finaliza todos los servicios activos antes de finalizar el ticket.';
  end if;

  if v_new_status in ('cancelado', 'no_asistio') then
    update public.ticket_services
       set status = 'cancelado'
     where ticket_id = v_ticket.id
       and tenant_id = v_tenant_id
       and status in ('pendiente', 'en_proceso');
  end if;

  update public.tickets
     set status = v_new_status
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
    v_ticket.status,
    v_new_status,
    v_reason,
    auth.uid()
  );

  return query
  select t.*
  from public.tickets t
  where t.id = v_ticket.id;
end;
$$;

revoke all on function public.change_ticket_status(uuid, text, text) from public;
revoke all on function public.change_ticket_status(uuid, text, text) from anon;
grant execute on function public.change_ticket_status(uuid, text, text) to authenticated;
