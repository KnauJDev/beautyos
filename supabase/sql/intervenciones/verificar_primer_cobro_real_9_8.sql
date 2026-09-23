-- Verifica el PRIMER COBRO REAL por el camino de la sede. Pasos 9.8 y 9.7.
--
-- POR QUE. El camino de la sede es el unico que queda para cobrar (D-252) y
-- nunca ha cobrado un peso real (R-01). El propietario paga $10.000 con la sede
-- de la Peluqueria Exito (D-265, D-268). Esta lectura, corrida DESPUES del
-- pago, ensenya cada eslabon de la cadena:
--
--   1. La intencion de pago: se registro con su SEDE antes de ir a ePayco
--      (create-epayco-session, D-182, D-191).
--   2. El evento de ePayco: llego, con cuanto se recibio y por que motivo
--      (beautyos_procesar_pago_de_sede, D-192, D-232).
--   3. La sede: activa, con su periodo.
--   4. El negocio: activo con el mismo periodo, porque es la sede principal
--      (D-192).
--
-- Y el 9.7 (TL-01): si el pago llego por `verify-epayco-transaction` al volver
-- de la pasarela, esa funcion comparo el comercio del pago con el nuestro. Un
-- pago real que pasa esa comparacion es lo que faltaba ver desde el 01-sep.
--
-- Donde no se sabe con certeza el nombre de una columna se usa `select *`, para
-- no inventarlo (regla 25 d).
--
-- NO MODIFICA NADA.
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\verificar_primer_cobro_real_9_8.sql"
--
-- Deja `_vivo_9_8_primer_cobro.txt` en la raiz. No se sube (.gitignore).

\encoding UTF8
\pset format unaligned
\pset tuples_only off
\pset fieldsep ' | '

\o C:/Proyectos/salonymas/_vivo_9_8_primer_cobro.txt

\qecho '=== 0. EL NEGOCIO Y SU SEDE ==='
select t.id as tenant_id, t.name, b.id as branch_id, b.name as sede, b.is_primary
from public.tenants t
join public.branches b on b.tenant_id = t.id
where t.name ilike '%xito Prueba%'
order by b.is_primary desc;

\qecho '=== 1. LAS INTENCIONES DE PAGO (con su sede) ==='
select spi.*
from public.subscription_payment_intents spi
join public.tenants t on t.id = spi.tenant_id
where t.name ilike '%xito Prueba%';

\qecho '=== 2. LOS ULTIMOS EVENTOS DE SUSCRIPCION ==='
select se.created_at, se.event_type, se.provider, se.provider_event_id, se.payload
from public.subscription_events se
join public.tenants t on t.id = se.tenant_id
where t.name ilike '%xito Prueba%'
order by se.created_at desc
limit 6;

\qecho '=== 3. LA SEDE ==='
select b.name as sede, bs.status, bs.price_cop, bs.current_period_start,
       bs.current_period_end, bs.grace_ends_at, bs.activated_at
from public.branch_subscriptions bs
join public.branches b on b.id = bs.branch_id
join public.tenants t on t.id = bs.tenant_id
where t.name ilike '%xito Prueba%';

\qecho '=== 4. EL NEGOCIO ==='
select ts.status, ts.provider, ts.trial_ends_at, ts.current_period_start,
       ts.current_period_end, ts.grace_ends_at
from public.tenant_subscriptions ts
join public.tenants t on t.id = ts.tenant_id
where t.name ilike '%xito Prueba%';

\o
