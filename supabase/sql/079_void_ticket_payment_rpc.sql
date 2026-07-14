-- Paso 1032: anulación auditada de pagos registrados por error.

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
    raise exception 'Indica el motivo de la anulación.';
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
      'cerrado',
      'finalizado',
      'Anulación de pago: ' || v_reason,
      auth.uid()
    );
  end if;

  return next v_payment;
end;
$$;

revoke all on function public.void_ticket_payment(uuid, text) from public;
revoke all on function public.void_ticket_payment(uuid, text) from anon;
grant execute on function public.void_ticket_payment(uuid, text) to authenticated;
