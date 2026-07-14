-- Paso 1028: inicio y finalización seguros de servicios asignados.

create table if not exists public.ticket_service_history (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  ticket_id uuid not null references public.tickets(id) on delete restrict,
  ticket_service_id uuid not null references public.ticket_services(id) on delete restrict,
  previous_status text not null,
  new_status text not null,
  created_by uuid not null,
  created_at timestamptz not null default now()
);

alter table public.ticket_service_history enable row level security;

create index if not exists ticket_service_history_tenant_service_created_at_idx
  on public.ticket_service_history (tenant_id, ticket_service_id, created_at desc);

revoke all on table public.ticket_service_history from public;
revoke all on table public.ticket_service_history from anon;
revoke all on table public.ticket_service_history from authenticated;

create or replace function public.change_ticket_service_status(
  p_ticket_service_id uuid,
  p_new_status text
)
returns setof public.ticket_services
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_role text;
  v_stylist_id uuid;
  v_service public.ticket_services%rowtype;
  v_ticket public.tickets%rowtype;
  v_new_status text;
begin
  select up.tenant_id, up.role, up.stylist_id
    into v_tenant_id, v_role, v_stylist_id
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.active = true
  limit 1;

  if v_tenant_id is null or v_role not in ('owner', 'admin', 'assistant', 'stylist') then
    raise exception 'No autorizado para actualizar servicios del ticket.';
  end if;

  select *
    into v_service
  from public.ticket_services ts
  where ts.id = p_ticket_service_id
    and ts.tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'Servicio del ticket no encontrado o no pertenece al centro actual.';
  end if;

  select *
    into v_ticket
  from public.tickets t
  where t.id = v_service.ticket_id
    and t.tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'El ticket asociado no está disponible.';
  end if;

  if v_role = 'stylist' and v_service.stylist_id is distinct from v_stylist_id then
    raise exception 'Solo puedes actualizar servicios asignados a tu agenda.';
  end if;

  v_new_status := lower(trim(coalesce(p_new_status, '')));

  if v_new_status not in ('pendiente', 'en_proceso', 'finalizado', 'cancelado') then
    raise exception 'Estado de servicio no válido.';
  end if;

  if v_new_status = v_service.status then
    return query select ts.* from public.ticket_services ts where ts.id = v_service.id;
    return;
  end if;

  if v_role = 'stylist' and v_new_status not in ('en_proceso', 'finalizado') then
    raise exception 'Un estilista solo puede iniciar o finalizar sus servicios asignados.';
  end if;

  if v_service.status = 'pendiente' and v_new_status = 'en_proceso' then
    if v_ticket.status not in ('confirmado', 'en_espera', 'en_proceso') then
      raise exception 'El ticket debe estar confirmado o en espera para iniciar el servicio.';
    end if;
  elsif v_service.status = 'en_proceso' and v_new_status = 'finalizado' then
    if v_ticket.status <> 'en_proceso' then
      raise exception 'El ticket debe estar en proceso para finalizar el servicio.';
    end if;
  elsif v_role in ('owner', 'admin', 'assistant')
        and v_service.status in ('pendiente', 'en_proceso')
        and v_new_status = 'cancelado' then
    null;
  else
    raise exception 'La transición de servicio de % a % no está permitida.',
      v_service.status, v_new_status;
  end if;

  update public.ticket_services
     set status = v_new_status
   where id = v_service.id
     and tenant_id = v_tenant_id;

  insert into public.ticket_service_history (
    tenant_id,
    ticket_id,
    ticket_service_id,
    previous_status,
    new_status,
    created_by
  ) values (
    v_tenant_id,
    v_ticket.id,
    v_service.id,
    v_service.status,
    v_new_status,
    auth.uid()
  );

  if v_new_status = 'en_proceso' and v_ticket.status <> 'en_proceso' then
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
      v_ticket.status,
      'en_proceso',
      'Inicio de servicio asignado',
      auth.uid()
    );
  end if;

  if v_new_status = 'finalizado'
     and not exists (
       select 1
       from public.ticket_services ts
       where ts.ticket_id = v_ticket.id
         and ts.tenant_id = v_tenant_id
         and ts.status in ('pendiente', 'en_proceso')
     )
     and exists (
       select 1
       from public.ticket_services ts
       where ts.ticket_id = v_ticket.id
         and ts.tenant_id = v_tenant_id
         and ts.status = 'finalizado'
     ) then
    update public.tickets
       set status = 'finalizado'
     where id = v_ticket.id
       and tenant_id = v_tenant_id
       and status = 'en_proceso';

    if found then
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
        'en_proceso',
        'finalizado',
        'Todos los servicios del ticket finalizaron',
        auth.uid()
      );
    end if;
  end if;

  return query
  select ts.*
  from public.ticket_services ts
  where ts.id = v_service.id;
end;
$$;

revoke all on function public.change_ticket_service_status(uuid, text) from public;
revoke all on function public.change_ticket_service_status(uuid, text) from anon;
grant execute on function public.change_ticket_service_status(uuid, text) to authenticated;
