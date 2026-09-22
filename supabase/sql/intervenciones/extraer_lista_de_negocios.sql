-- Extrae el texto VIVO de `public.platform_list_tenants` y el precio de lista
-- de los planes. Hallazgo AG.
--
-- POR QUE. Al reescribir una funcion hay que sacar primero su texto actual y
-- comparar linea por linea (D-119, D-122, D-123). Esta funcion decide lo que
-- ve el panel sobre el dinero de cada cliente, y esta definida en **dos**
-- migraciones distintas (20260830100000 y 20260916190000): lo unico que sabe
-- cual gano es la base.
--
-- NO MODIFICA NADA. Solo lee el catalogo y escribe archivos en el disco.

\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_platform_list_tenants.sql
select pg_get_functiondef('public.platform_list_tenants()'::regprocedure);
\o

-- Los planes vivos y su precio de lista. El modelo de Dart trae escritos a
-- mano 150000/160000/200000/240000 para codigos que D-188 jubilo: esto dice
-- que hay de verdad.
\o C:/Proyectos/salonymas/_vivo_planes.txt
select 'plan | ' || p.code || ' | ' || p.name || ' | lista=' || p.price_cop
       || ' | estado=' || p.status
from public.plans p order by p.price_cop;

\echo '--- que precio tiene pactado cada negocio, y con que descuento ---'
select 'negocio | ' || t.name
       || ' | pactado=' || coalesce(ts.price_cop::text, '(ninguno)')
       || ' | descuento=' || coalesce(ts.discount_percent::text, '(ninguno)')
       || ' | pionero=' || ts.is_founder
       || ' | motivo=' || coalesce(ts.price_reason, '(sin motivo)')
       || ' | SERVIDOR_COBRA=' || pe.precio_cop
from public.tenant_subscriptions ts
join public.tenants t on t.id = ts.tenant_id
cross join lateral private.beautyos_precio_efectivo(ts.tenant_id) pe
where t.active
order by t.name;

\echo '--- y que cobra cada sede, que es lo que manda desde D-239 ---'
select 'sede | ' || t.name || ' / ' || b.name
       || ' | pactado=' || coalesce(bs.price_cop::text, '(ninguno)')
       || ' | SERVIDOR_COBRA=' || pes.precio_cop
       || ' | motivo=' || pes.motivo
from public.branch_subscriptions bs
join public.branches b on b.id = bs.branch_id
join public.tenants t on t.id = b.tenant_id
cross join lateral private.beautyos_precio_efectivo_sede(bs.branch_id) pes
where t.active and b.active
order by t.name, b.name;
\o

\pset tuples_only off
\pset format aligned

\echo ''
\echo 'Listo. Quedaron dos archivos _vivo_* en la carpeta del proyecto.'
