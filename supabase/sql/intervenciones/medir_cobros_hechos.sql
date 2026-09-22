-- La ultima pregunta de la medicion de AG: **?alguien ha pagado alguna vez
-- por el camino del negocio, en vez del de sede?**
--
-- Decide si retirar el precio por negocio es limpio o si hay historial que
-- respetar. Los pagos no viven en una tabla de pagos: viven en
-- `subscription_events` con `provider = 'epayco'` y un `monto_cop_recibido`
-- dentro del payload, que es como los cuenta `platform_list_tenants`.
--
-- *(La pasada anterior de esta pregunta se cayo porque el archivo nombraba
-- `public.subscription_payments`, una tabla que no existe. Inventada por el
-- asistente, no leida del esquema. De ahi que esto se saque del sitio que la
-- funcion viva usa de verdad.)*
--
-- NO MODIFICA NADA.

\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_cobros.txt

select '=== COBROS DE SUSCRIPCION REGISTRADOS ===';

select 'total=' || count(*)
       || ' | con sede en el payload=' || count(*) filter (where se.payload ? 'branch_id')
       || ' | SIN sede (camino del negocio)=' || count(*) filter (where not (se.payload ? 'branch_id'))
from public.subscription_events se
where se.provider = 'epayco'
  and se.payload ? 'monto_cop_recibido';

select '';
select '=== UNO POR UNO, POR SI HAY POCOS ===';
select t.name || ' | ' || se.event_type
       || ' | monto=' || coalesce(se.payload->>'monto_cop_recibido', '?')
       || ' | sede=' || coalesce(se.payload->>'branch_id', '(ninguna)')
       || ' | ' || to_char(se.created_at, 'YYYY-MM-DD')
from public.subscription_events se
join public.tenants t on t.id = se.tenant_id
where se.provider = 'epayco'
  and se.payload ? 'monto_cop_recibido'
order by se.created_at;

select '';
select '=== Y CUALQUIER EVENTO DE EPAYCO, HAYA COBRADO O NO ===';
select 'eventos epayco en total: ' || count(*)
from public.subscription_events se where se.provider = 'epayco';

\o

\pset tuples_only off
\pset format aligned

\echo ''
\echo 'Listo. Quedo _vivo_cobros.txt en la carpeta del proyecto.'
