-- Paso 1036: comprobacion del cierre diario y los reportes financieros.

begin;

select set_config(
  'request.jwt.claim.sub',
  '7661e1c7-798e-41f0-b2a4-9244e277570b',
  true
);

do $$
declare
  v_close record;
  v_financial record;
  v_commission numeric;
  v_expected_received numeric;
  v_expected_cash numeric;
  v_expected_card numeric;
  v_expected_commission numeric;
  v_expected_purchases numeric;
  v_expected_expenses numeric;
begin
  select * into v_close
  from public.get_daily_close(
    date '2026-07-14',
    timestamptz '2026-07-14 05:00:00+00',
    timestamptz '2026-07-15 05:00:00+00'
  );

  select
    coalesce(sum(tp.amount), 0),
    coalesce(sum(tp.amount) filter (where tp.method = 'efectivo'), 0),
    coalesce(sum(tp.amount) filter (where tp.method = 'tarjeta'), 0)
    into v_expected_received, v_expected_cash, v_expected_card
  from public.ticket_payments tp
  where tp.tenant_id = 'd338021b-1aed-4d4c-8462-0fc571867798'
    and tp.status = 'registrado'
    and tp.received_at >= timestamptz '2026-07-14 05:00:00+00'
    and tp.received_at < timestamptz '2026-07-15 05:00:00+00';

  select coalesce(sum(sc.commission_amount), 0)
    into v_expected_commission
  from public.stylist_commissions sc
  where sc.tenant_id = 'd338021b-1aed-4d4c-8462-0fc571867798'
    and sc.status = 'generada'
    and sc.generated_at >= timestamptz '2026-07-14 05:00:00+00'
    and sc.generated_at < timestamptz '2026-07-15 05:00:00+00';

  select coalesce(sum(p.total_amount), 0)
    into v_expected_purchases
  from public.purchases p
  where p.tenant_id = 'd338021b-1aed-4d4c-8462-0fc571867798'
    and p.active = true
    and p.purchase_date = date '2026-07-14';

  select coalesce(sum(e.amount), 0)
    into v_expected_expenses
  from public.expenses e
  where e.tenant_id = 'd338021b-1aed-4d4c-8462-0fc571867798'
    and e.active = true
    and e.expense_date = date '2026-07-14';

  if v_close.total_received <> v_expected_received
     or v_close.cash_received <> v_expected_cash
     or v_close.card_received <> v_expected_card
     or v_close.total_commissions <> v_expected_commission
     or v_close.estimated_result <>
        v_expected_received - v_expected_purchases - v_expected_expenses - v_expected_commission then
    raise exception 'El cierre diario no coincide con pagos y comisiones esperados.';
  end if;

  select coalesce(sum(cs.commission_total), 0)
    into v_commission
  from public.get_commission_summary(
    timestamptz '2026-07-14 05:00:00+00',
    timestamptz '2026-07-15 05:00:00+00'
  ) cs;

  if v_commission <> v_expected_commission then
    raise exception 'El resumen por estilista no coincide con la comision esperada.';
  end if;

  select * into v_financial
  from public.get_financial_summary_v2();

  if v_financial.total_sales <> (
       select coalesce(sum(tp.amount), 0)
       from public.ticket_payments tp
       where tp.tenant_id = 'd338021b-1aed-4d4c-8462-0fc571867798'
         and tp.status = 'registrado'
     )
     or v_financial.total_commissions <> (
       select coalesce(sum(sc.commission_amount), 0)
       from public.stylist_commissions sc
       where sc.tenant_id = 'd338021b-1aed-4d4c-8462-0fc571867798'
         and sc.status = 'generada'
     ) then
    raise exception 'El resumen financiero no usa los pagos y comisiones reales.';
  end if;
end;
$$;

rollback;
