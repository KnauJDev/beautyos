begin;

select set_config(
  'request.jwt.claim.sub',
  '7661e1c7-798e-41f0-b2a4-9244e277570b',
  true
);

select id, amount, method, status
from public.register_ticket_payment(
  '59a72637-42fc-4558-a2c0-c5135f5e7676',
  35000,
  'tarjeta',
  'PRUEBA-ANULACION',
  'Pago completo para probar anulación'
);

select id, amount, status, void_reason
from public.void_ticket_payment(
  (
    select tp.id
    from public.ticket_payments tp
    where tp.ticket_id = '59a72637-42fc-4558-a2c0-c5135f5e7676'
      and tp.status = 'registrado'
    order by tp.created_at desc
    limit 1
  ),
  'Pago registrado por error'
);

do $$
declare
  v_ticket_status text;
  v_paid numeric;
  v_balance numeric;
  v_voided_count integer;
begin
  select t.status into v_ticket_status
  from public.tickets t
  where t.id = '59a72637-42fc-4558-a2c0-c5135f5e7676';

  select s.paid_amount, s.balance_amount
    into v_paid, v_balance
  from public.get_ticket_payment_summary(
    '59a72637-42fc-4558-a2c0-c5135f5e7676'
  ) s;

  select count(*) into v_voided_count
  from public.ticket_payments tp
  where tp.ticket_id = '59a72637-42fc-4558-a2c0-c5135f5e7676'
    and tp.status = 'anulado'
    and tp.void_reason = 'Pago registrado por error';

  if v_ticket_status <> 'finalizado'
     or v_paid <> 0
     or v_balance <> 35000
     or v_voided_count <> 1 then
    raise exception 'La anulación no restauró correctamente ticket y saldo.';
  end if;
end;
$$;

rollback;
