-- Paso 1034: prueba transaccional de generar, anular y regenerar comisiones.

begin;

select set_config(
  'request.jwt.claim.sub',
  '7661e1c7-798e-41f0-b2a4-9244e277570b',
  true
);

do $$
declare
  v_ticket_id constant uuid := '59a72637-42fc-4558-a2c0-c5135f5e7676';
  v_payment_id uuid;
  v_payment_amount numeric(12, 2);
  v_active_commission numeric(12, 2);
  v_ticket_status text;
begin
  select coalesce(sum(sc.commission_amount), 0)
    into v_active_commission
  from public.stylist_commissions sc
  where sc.ticket_id = v_ticket_id
    and sc.status = 'generada';

  if v_active_commission <> 14000 then
    raise exception 'La comision inicial esperada era 14000 y se obtuvo %.', v_active_commission;
  end if;

  select tp.id, tp.amount
    into v_payment_id, v_payment_amount
  from public.ticket_payments tp
  where tp.ticket_id = v_ticket_id
    and tp.status = 'registrado'
  order by tp.created_at desc
  limit 1;

  perform * from public.void_ticket_payment(
    v_payment_id,
    'Prueba transaccional de comisiones'
  );

  if exists (
    select 1 from public.stylist_commissions sc
    where sc.ticket_id = v_ticket_id and sc.status = 'generada'
  ) then
    raise exception 'La comision siguio activa despues de anular el pago.';
  end if;

  perform * from public.register_ticket_payment(
    v_ticket_id,
    v_payment_amount,
    'efectivo',
    'PRUEBA-COMISION',
    'Regeneracion transaccional de la comision'
  );

  select t.status into v_ticket_status
  from public.tickets t
  where t.id = v_ticket_id;

  select coalesce(sum(sc.commission_amount), 0)
    into v_active_commission
  from public.stylist_commissions sc
  where sc.ticket_id = v_ticket_id
    and sc.status = 'generada';

  if v_ticket_status <> 'cerrado' or v_active_commission <> 14000 then
    raise exception 'El recierre no restauro ticket y comision correctamente.';
  end if;
end;
$$;

rollback;
