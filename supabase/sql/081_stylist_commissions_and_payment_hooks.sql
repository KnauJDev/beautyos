-- Paso 1033: libro historico de comisiones y enlace con el cierre de pagos.

create table if not exists public.stylist_commissions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  ticket_id uuid not null references public.tickets(id) on delete restrict,
  ticket_service_id uuid not null references public.ticket_services(id) on delete restrict,
  stylist_id uuid not null references public.stylists(id) on delete restrict,
  commission_policy_id uuid references public.commission_policies(id) on delete set null,
  service_amount numeric(12, 2) not null check (service_amount >= 0),
  commission_type text not null check (commission_type in ('percentage', 'fixed')),
  commission_percentage numeric(7, 4) not null default 0
    check (commission_percentage >= 0 and commission_percentage <= 100),
  fixed_commission_amount numeric(12, 2) not null default 0
    check (fixed_commission_amount >= 0),
  applies_after_discount boolean not null default true,
  commission_amount numeric(12, 2) not null check (commission_amount >= 0),
  status text not null default 'generada' check (status in ('generada', 'anulada')),
  generated_at timestamptz not null default now(),
  generated_by uuid not null,
  created_at timestamptz not null default now(),
  voided_at timestamptz,
  voided_by uuid,
  void_reason text,
  check (
    (status = 'generada' and voided_at is null and voided_by is null and void_reason is null)
    or
    (status = 'anulada' and voided_at is not null and voided_by is not null and void_reason is not null)
  )
);

alter table public.stylist_commissions enable row level security;

create index if not exists stylist_commissions_tenant_generated_at_idx
  on public.stylist_commissions (tenant_id, generated_at desc);

create index if not exists stylist_commissions_stylist_generated_at_idx
  on public.stylist_commissions (tenant_id, stylist_id, generated_at desc);

create index if not exists stylist_commissions_ticket_id_idx
  on public.stylist_commissions (ticket_id);

create index if not exists stylist_commissions_stylist_id_idx
  on public.stylist_commissions (stylist_id);

create index if not exists stylist_commissions_policy_id_idx
  on public.stylist_commissions (commission_policy_id)
  where commission_policy_id is not null;

create unique index if not exists stylist_commissions_active_service_uidx
  on public.stylist_commissions (ticket_service_id)
  where status = 'generada';

revoke all on table public.stylist_commissions from public;
revoke all on table public.stylist_commissions from anon;
revoke all on table public.stylist_commissions from authenticated;

-- Registra las comisiones de tickets que ya estaban cerrados antes de este paso.
insert into public.stylist_commissions (
  tenant_id,
  ticket_id,
  ticket_service_id,
  stylist_id,
  commission_policy_id,
  service_amount,
  commission_type,
  commission_percentage,
  fixed_commission_amount,
  applies_after_discount,
  commission_amount,
  generated_at,
  generated_by
)
select
  t.tenant_id,
  t.id,
  ts.id,
  ts.stylist_id,
  cp.id,
  ts.price,
  cp.commission_type,
  cp.commission_percentage,
  cp.fixed_commission_amount,
  cp.applies_after_discount,
  case
    when cp.commission_type = 'fixed'
      then cp.fixed_commission_amount
    else round(ts.price * cp.commission_percentage / 100, 2)
  end,
  fp.received_at,
  fp.created_by
from public.tickets t
join public.ticket_services ts
  on ts.ticket_id = t.id
 and ts.tenant_id = t.tenant_id
join public.commission_policies cp
  on cp.tenant_id = t.tenant_id
 and cp.active = true
join lateral (
  select tp.received_at, tp.created_by
  from public.ticket_payments tp
  where tp.ticket_id = t.id
    and tp.tenant_id = t.tenant_id
    and tp.status = 'registrado'
  order by tp.received_at desc, tp.created_at desc
  limit 1
) fp on true
where t.status = 'cerrado'
  and ts.status = 'finalizado'
  and ts.stylist_id is not null
  and not exists (
    select 1
    from public.stylist_commissions sc
    where sc.ticket_service_id = ts.id
      and sc.status = 'generada'
  );

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
    raise exception 'Metodo de pago no valido.';
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
    raise exception 'El ticket ya esta completamente pagado.';
  end if;

  if p_amount > v_balance then
    raise exception 'El pago supera el saldo pendiente de %.', v_balance;
  end if;

  insert into public.ticket_payments (
    tenant_id, ticket_id, amount, method, reference, notes, created_by
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
      tenant_id, ticket_id, event_type, previous_status, new_status, reason, created_by
    ) values (
      v_tenant_id,
      v_ticket.id,
      'status_changed',
      'finalizado',
      'cerrado',
      'Saldo pagado completamente',
      auth.uid()
    );

    insert into public.stylist_commissions (
      tenant_id,
      ticket_id,
      ticket_service_id,
      stylist_id,
      commission_policy_id,
      service_amount,
      commission_type,
      commission_percentage,
      fixed_commission_amount,
      applies_after_discount,
      commission_amount,
      generated_at,
      generated_by
    )
    select
      v_tenant_id,
      v_ticket.id,
      ts.id,
      ts.stylist_id,
      cp.id,
      ts.price,
      cp.commission_type,
      cp.commission_percentage,
      cp.fixed_commission_amount,
      cp.applies_after_discount,
      case
        when cp.commission_type = 'fixed'
          then cp.fixed_commission_amount
        else round(ts.price * cp.commission_percentage / 100, 2)
      end,
      v_payment.received_at,
      auth.uid()
    from public.ticket_services ts
    join public.commission_policies cp
      on cp.tenant_id = v_tenant_id
     and cp.active = true
    where ts.ticket_id = v_ticket.id
      and ts.tenant_id = v_tenant_id
      and ts.status = 'finalizado'
      and ts.stylist_id is not null
      and not exists (
        select 1
        from public.stylist_commissions sc
        where sc.ticket_service_id = ts.id
          and sc.status = 'generada'
      );
  end if;

  return next v_payment;
end;
$$;

create or replace function public.void_ticket_payment(
  p_payment_id uuid,
  p_reason text
)
returns setof public.ticket_payments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_role text;
  v_reason text;
  v_payment public.ticket_payments%rowtype;
  v_ticket public.tickets%rowtype;
begin
  select up.tenant_id, up.role
    into v_tenant_id, v_role
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.active = true
  limit 1;

  if v_tenant_id is null or v_role not in ('owner', 'admin') then
    raise exception 'Solo owner o admin puede anular pagos.';
  end if;

  v_reason := nullif(trim(coalesce(p_reason, '')), '');

  if v_reason is null then
    raise exception 'Indica el motivo de la anulacion.';
  end if;

  select *
    into v_payment
  from public.ticket_payments tp
  where tp.id = p_payment_id
    and tp.tenant_id = v_tenant_id
  for update;

  if not found or v_payment.status <> 'registrado' then
    raise exception 'El pago no existe, ya fue anulado o no pertenece al centro actual.';
  end if;

  select *
    into v_ticket
  from public.tickets t
  where t.id = v_payment.ticket_id
    and t.tenant_id = v_tenant_id
  for update;

  if not found or v_ticket.status not in ('finalizado', 'cerrado') then
    raise exception 'El estado actual del ticket no permite anular este pago.';
  end if;

  update public.ticket_payments
     set status = 'anulado',
         voided_at = now(),
         voided_by = auth.uid(),
         void_reason = v_reason
   where id = v_payment.id
     and tenant_id = v_tenant_id
  returning * into v_payment;

  if v_ticket.status = 'cerrado' then
    update public.tickets
       set status = 'finalizado'
     where id = v_ticket.id
       and tenant_id = v_tenant_id;

    update public.stylist_commissions
       set status = 'anulada',
           voided_at = now(),
           voided_by = auth.uid(),
           void_reason = 'Anulacion de pago: ' || v_reason
     where ticket_id = v_ticket.id
       and tenant_id = v_tenant_id
       and status = 'generada';

    insert into public.ticket_history (
      tenant_id, ticket_id, event_type, previous_status, new_status, reason, created_by
    ) values (
      v_tenant_id,
      v_ticket.id,
      'status_changed',
      'cerrado',
      'finalizado',
      'Anulacion de pago: ' || v_reason,
      auth.uid()
    );
  end if;

  return next v_payment;
end;
$$;

revoke all on function public.register_ticket_payment(uuid, numeric, text, text, text) from public;
revoke all on function public.register_ticket_payment(uuid, numeric, text, text, text) from anon;
grant execute on function public.register_ticket_payment(uuid, numeric, text, text, text) to authenticated;

revoke all on function public.void_ticket_payment(uuid, text) from public;
revoke all on function public.void_ticket_payment(uuid, text) from anon;
grant execute on function public.void_ticket_payment(uuid, text) to authenticated;
