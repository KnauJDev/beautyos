-- ==============================================================================
-- Que paso al cerrar la ventana de ePayco SIN pagar (30-sep, ~08:11 hora de
-- Colombia, 13:11 UTC), en "Barberia Barber Elite" de Prueba Barberia Elite.
--
-- POR QUE: al cerrar, la app mostro "Estamos validando tu pago con ePayco...",
-- aunque no hubo pago. Ese aviso sale cuando la app vuelve de ePayco con
-- ?ref_payco= y `verify-epayco-transaction` no devuelve ni aceptado, ni
-- rechazado, ni reversado. Antes de arreglarlo hay que saber que estado
-- reporto ePayco, y confirmar que no se cobro ni se activo nada.
--
-- NO MODIFICA NADA. Solo lectura.
-- ==============================================================================

\echo '--- 1. Eventos de pago de ese negocio en las ultimas 3 horas (lo que registro la verificacion) ---'
select se.created_at,
       se.event_type,
       se.provider_event_id as ref_payco,
       se.payload->>'x_transaction_state' as estado_epayco,
       se.payload->>'x_cod_transaction_state' as codigo_epayco,
       se.payload->>'x_response_reason_text' as motivo_epayco,
       se.payload->>'x_amount' as monto
from public.subscription_events se
where se.tenant_id = 'b30a051a-747e-482d-a1bf-f26100136056'
  and se.created_at > now() - interval '3 hours'
order by se.created_at;

\echo '--- 2. Intenciones de pago de ese negocio hoy (cada vez que se abrio ePayco) ---'
select spi.created_at, spi.invoice_number, spi.amount_cop, spi.status
from public.subscription_payment_intents spi
where spi.tenant_id = 'b30a051a-747e-482d-a1bf-f26100136056'
  and spi.created_at > now() - interval '12 hours'
order by spi.created_at;

\echo '--- 3. Las sedes de ese negocio: ninguna debio activarse ---'
select b.name as sede, bs.status, bs.current_period_end
from public.branch_subscriptions bs
join public.branches b on b.id = bs.branch_id
where bs.tenant_id = 'b30a051a-747e-482d-a1bf-f26100136056'
order by b.is_primary desc;
