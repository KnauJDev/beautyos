-- Mide cuanto pesa retirar el precio pactado POR NEGOCIO y dejar solo el de
-- sede. Hallazgo AG, pregunta del propietario el 22-sep:
--
--   "que tan complicado es retirar el precio acordado por negocio y dejarlo
--    por sede, al final es asi como se haria en la realidad"
--
-- POR QUE SE PREGUNTA AL CATALOGO Y NO AL REPOSITORIO. Porque el repositorio
-- **no es la fuente del esquema** (hallazgo AI) y porque una misma funcion se
-- redefine en varias migraciones: contar archivos da un numero inflado y, lo
-- que es peor, puede dejar fuera una funcion viva que ninguna migracion
-- reciente menciona. En el camino del dinero eso no se estima: se cuenta.
--
-- `p.prokind = 'f'` NO es adorno: `pg_get_functiondef` revienta con las
-- funciones de agregado ("array_agg is an aggregate function"), y la primera
-- pasada de este archivo se cayo justo ahi.
--
-- NO MODIFICA NADA.

\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_consumidores_precio.txt

select '=== FUNCIONES VIVAS QUE TOCAN EL PRECIO DEL NEGOCIO ===';

with vivas as (
  select n.nspname as esquema, p.proname as nombre,
         pg_get_functiondef(p.oid) as cuerpo
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname in ('public', 'private')
    and p.prokind = 'f'
)
select esquema || '.' || nombre
       || ' | precio_negocio=' || case when cuerpo like '%beautyos_precio_efectivo(%' then 'SI' else '- ' end
       || ' | precio_sede='    || case when cuerpo like '%beautyos_precio_efectivo_sede(%' then 'SI' else '- ' end
       || ' | price_cop='      || case when cuerpo ~ '(ts|sub|s)\.price_cop' then 'SI' else '- ' end
       || ' | descuento='      || case when cuerpo like '%discount_percent%' then 'SI' else '- ' end
from vivas
where cuerpo like '%beautyos_precio_efectivo(%'
   or cuerpo ~ '(ts|sub|s)\.price_cop'
   or cuerpo like '%discount_percent%'
order by 1;

select '';
select '=== CUANTAS SON ===';
with vivas as (
  select pg_get_functiondef(p.oid) as cuerpo
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname in ('public', 'private') and p.prokind = 'f'
)
select 'funciones vivas que tocan el precio del negocio: ' || count(*)
from vivas
where cuerpo like '%beautyos_precio_efectivo(%'
   or cuerpo ~ '(ts|sub|s)\.price_cop'
   or cuerpo like '%discount_percent%';

select '';
select '=== SEDES POR NEGOCIO, Y CUANTAS SIN PRECIO PACTADO ===';
select t.name
       || ' | sedes_activas=' || count(*) filter (where b.active)
       || ' | con_precio_pactado=' || count(*) filter (where b.active and bs.price_cop is not null)
       || ' | SIN_pactar=' || count(*) filter (where b.active and bs.price_cop is null)
from public.tenants t
join public.branches b on b.tenant_id = t.id
left join public.branch_subscriptions bs on bs.branch_id = b.id
where t.active
group by t.name
order by t.name;

select '';
select '=== HAY ALGUN COBRO REAL HECHO POR EL CAMINO DEL NEGOCIO? ===';
select 'pagos de suscripcion registrados: ' || count(*)
       || ' | con sede: ' || count(*) filter (where sp.branch_id is not null)
       || ' | SIN sede (camino del negocio): ' || count(*) filter (where sp.branch_id is null)
from public.subscription_payments sp;

\o

\pset tuples_only off
\pset format aligned

\echo ''
\echo 'Listo. Quedo _vivo_consumidores_precio.txt en la carpeta del proyecto.'
