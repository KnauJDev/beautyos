-- Paso 1030: pagos parciales, saldos y cierre automático del ticket.

create table if not exists public.ticket_payments (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  ticket_id uuid not null references public.tickets(id) on delete restrict,
  amount numeric(12, 2) not null check (amount > 0),
  method text not null check (
    method in ('efectivo', 'tarjeta', 'transferencia', 'otro')
  ),
  reference text,
  notes text,
  status text not null default 'registrado' check (
    status in ('registrado', 'anulado')
  ),
  received_at timestamptz not null default now(),
  created_by uuid not null,
  created_at timestamptz not null default now(),
  voided_at timestamptz,
  voided_by uuid,
  void_reason text,
  check (
    (status = 'registrado' and voided_at is null and voided_by is null and void_reason is null)
    or
    (status = 'anulado' and voided_at is not null and voided_by is not null and void_reason is not null)
  )
);

alter table public.ticket_payments enable row level security;

create index if not exists ticket_payments_ticket_id_idx
  on public.ticket_payments (ticket_id);

create index if not exists ticket_payments_tenant_received_at_idx
  on public.ticket_payments (tenant_id, received_at desc);

create index if not exists ticket_payments_registered_ticket_idx
  on public.ticket_payments (tenant_id, ticket_id)
  where status = 'registrado';

revoke all on table public.ticket_payments from public;
revoke all on table public.ticket_payments from anon;
revoke all on table public.ticket_payments from authenticated;

create or replace function public.get_ticket_payment_summary(
  p_ticket_id uuid
)
returns table(
  total_amount numeric,
  paid_amount numeric,
  balance_amount numeric,
  payment_status text
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

  if v_tenant_id is null or v_role not in ('owner', 'admin', 'assistant') then
    raise exception 'No autorizado para consultar pagos.';
  end if;

  if not exists (
    select 1
    from public.tickets t
    where t.id = p_ticket_id
      and t.tenant_id = v_tenant_id
  ) then
    raise exception 'Ticket no encontrado o no pertenece al centro actual.';
  end if;

  return query
  with service_total as (
    select coalesce(sum(ts.price), 0)::numeric as amount
    from public.ticket_services ts
    where ts.ticket_id = p_ticket_id
      and ts.tenant_id = v_tenant_id
      and ts.status = 'finalizado'
  ),
  payment_total as (
    select coalesce(sum(tp.amount), 0)::numeric as amount
    from public.ticket_payments tp
    where tp.ticket_id = p_ticket_id
      and tp.tenant_id = v_tenant_id
      and tp.status = 'registrado'
  )
  select
    st.amount,
    pt.amount,
    greatest(st.amount - pt.amount, 0)::numeric,
    case
      when pt.amount = 0 then 'sin_pago'
      when pt.amount < st.amount then 'parcial'
      else 'pagado'
    end
  from service_total st
  cross join payment_total pt;
end;
$$;

create or replace function public.get_ticket_payments(
  p_ticket_id uuid
)
returns table(
  payment_id uuid,
  amount numeric,
  method text,
  reference text,
  notes text,
  status text,
  received_at timestamptz,
  created_by uuid
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

  if v_tenant_id is null or v_role not in ('owner', 'admin', 'assistant') then
    raise exception 'No autorizado para consultar pagos.';
  end if;

  if not exists (
    select 1
    from public.tickets t
    where t.id = p_ticket_id
      and t.tenant_id = v_tenant_id
  ) then
    raise exception 'Ticket no encontrado o no pertenece al centro actual.';
  end if;

  return query
  select
    tp.id,
    tp.amount,
    tp.method,
    tp.reference,
    tp.notes,
    tp.status,
    tp.received_at,
    tp.created_by
  from public.ticket_payments tp
  where tp.ticket_id = p_ticket_id
    and tp.tenant_id = v_tenant_id
  order by tp.received_at desc, tp.created_at desc;
end;
$$;

create or replace function public.register_ticket_payment(
  p_ticket_id uuid,
  p_amount numeric,
  p_method text,
  p_reference text default null,
  p_notes text default null
)
returns setof public.ticket_payments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_role text;
  v_ticket public.tickets%rowtype;
  v_total numeric(12, 2);
  v_paid numeric(12, 2);
  v_balance numeric(12, 2);
  v_method text;
  v_payment public.ticket_payments%rowtype;
begin
  select up.tenant_id, up.role
    into v_tenant_id, v_role
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.active = true
  limit 1;

  if v_tenant_id is null or v_role not in ('owner', 'admin', 'assistant') then
    raise exception 'No autorizado para registrar pagos.';
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

  if v_ticket.status <> 'finalizado' then
    raise exception 'Solo se pueden registrar pagos de tickets finalizados.';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'El valor del pago debe ser mayor que cero.';
  end if;

  v_method := lower(trim(coalesce(p_method, '')));

  if v_method not in ('efectivo', 'tarjeta', 'transferencia', 'otro') then
    raise exception 'Método de pago no válido.';
  end if;

  select coalesce(sum(ts.price), 0)::numeric(12, 2)
    into v_total
  from public.ticket_services ts
  where ts.ticket_id = v_ticket.id
    and ts.tenant_id = v_tenant_id
    and ts.status = 'finalizado';

  if v_total <= 0 then
    raise exception 'El ticket no tiene servicios finalizados para cobrar.';
  end if;

  select coalesce(sum(tp.amount), 0)::numeric(12, 2)
    into v_paid
  from public.ticket_payments tp
  where tp.ticket_id = v_ticket.id
    and tp.tenant_id = v_tenant_id
    and tp.status = 'registrado';

  v_balance := v_total - v_paid;

  if v_balance <= 0 then
    raise exception 'El ticket ya está completamente pagado.';
  end if;

  if p_amount > v_balance then
    raise exception 'El pago supera el saldo pendiente de %.', v_balance;
  end if;

  insert into public.ticket_payments (
    tenant_id,
    ticket_id,
    amount,
    method,
    reference,
    notes,
    created_by
  ) values (
    v_tenant_id,
    v_ticket.id,
    p_amount,
    v_method,
    nullif(trim(coalesce(p_reference, '')), ''),
    nullif(trim(coalesce(p_notes, '')), ''),
    auth.uid()
  )
  returning * into v_payment;

  if p_amount = v_balance then
    update public.tickets
       set status = 'cerrado'
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
      'cerrado',
      'Saldo pagado completamente',
      auth.uid()
    );
  end if;

  return next v_payment;
end;
$$;

revoke all on function public.get_ticket_payment_summary(uuid) from public;
revoke all on function public.get_ticket_payment_summary(uuid) from anon;
grant execute on function public.get_ticket_payment_summary(uuid) to authenticated;

revoke all on function public.get_ticket_payments(uuid) from public;
revoke all on function public.get_ticket_payments(uuid) from anon;
grant execute on function public.get_ticket_payments(uuid) to authenticated;

revoke all on function public.register_ticket_payment(uuid, numeric, text, text, text) from public;
revoke all on function public.register_ticket_payment(uuid, numeric, text, text, text) from anon;
grant execute on function public.register_ticket_payment(uuid, numeric, text, text, text) to authenticated;
