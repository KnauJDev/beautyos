begin;

select set_config(
  'request.jwt.claim.sub',
  '7661e1c7-798e-41f0-b2a4-9244e277570b',
  true
);

-- Primer abono: el ticket debe conservarse finalizado con saldo pendiente.
select id, amount, method, status
from public.register_ticket_payment(
  '59a72637-42fc-4558-a2c0-c5135f5e7676',
  10000,
  'efectivo',
  null,
  'Abono parcial de prueba'
);

select *
from public.get_ticket_payment_summary(
  '59a72637-42fc-4558-a2c0-c5135f5e7676'
);

do $$
declare
  v_status text;
  v_paid numeric;
  v_balance numeric;
begin
  select t.status into v_status
  from public.tickets t
  where t.id = '59a72637-42fc-4558-a2c0-c5135f5e7676';

  select s.paid_amount, s.balance_amount
    into v_paid, v_balance
  from public.get_ticket_payment_summary(
    '59a72637-42fc-4558-a2c0-c5135f5e7676'
  ) s;

  if v_status <> 'finalizado' or v_paid <> 10000 or v_balance <> 25000 then
    raise exception 'El abono parcial no produjo el estado o saldo esperado.';
  end if;
end;
$$;

-- Segundo pago: completa los $35.000 y debe cerrar el ticket.
select id, amount, method, status
from public.register_ticket_payment(
  '59a72637-42fc-4558-a2c0-c5135f5e7676',
  25000,
  'transferencia',
  'PRUEBA-25000',
  'Pago final de prueba'
);

select *
from public.get_ticket_payment_summary(
  '59a72637-42fc-4558-a2c0-c5135f5e7676'
);

select id, status
from public.tickets
where id = '59a72637-42fc-4558-a2c0-c5135f5e7676';

do $$
declare
  v_status text;
  v_paid numeric;
  v_balance numeric;
begin
  select t.status into v_status
  from public.tickets t
  where t.id = '59a72637-42fc-4558-a2c0-c5135f5e7676';

  select s.paid_amount, s.balance_amount
    into v_paid, v_balance
  from public.get_ticket_payment_summary(
    '59a72637-42fc-4558-a2c0-c5135f5e7676'
  ) s;

  if v_status <> 'cerrado' or v_paid <> 35000 or v_balance <> 0 then
    raise exception 'El pago completo no cerró el ticket correctamente.';
  end if;
end;
$$;

select payment_id, amount, method, reference, status
from public.get_ticket_payments(
  '59a72637-42fc-4558-a2c0-c5135f5e7676'
);

rollback;
