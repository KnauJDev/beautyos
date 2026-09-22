-- Extrae el texto VIVO de la aprobacion de un negocio y del precio de sede.
-- Hallazgo AG, parte 2.
--
-- POR QUE. `platform_approve_tenant` lleva dentro esto, vivo hoy:
--
--   if p_is_founder is true then
--     v_discount_percent := coalesce(v_discount_percent, 50.00);
--     if v_price_reason is null then
--       v_price_reason := 'Pionero (50% de por vida)';
--     end if;
--   end if;
--
-- Es el **50% que D-221 quito el 07-sep** y que el control 207 vigila... en la
-- otra funcion. Nadie miro esta puerta. Y explica el motivo raro que traia
-- *Prueba Barberia Elite* en la base: no lo escribio nadie a mano, lo escribio
-- esta funcion al aprobarlo.
--
-- Reescribir 115 lineas de la funcion que aprueba clientes no se hace de
-- memoria (D-119, D-122, D-123).
--
-- Se trae tambien `platform_update_branch_pricing`, que es **donde el precio
-- vive ahora**: la aprobacion tiene que mandar ahi en vez de fijar un precio
-- que no cobra.
--
-- NO MODIFICA NADA.

\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_approve_tenant.sql
select pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'platform_approve_tenant';
\o

\o C:/Proyectos/salonymas/_vivo_update_branch_pricing.sql
select '-- ===== ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.proname in ('platform_update_branch_pricing', 'platform_update_tenant_pricing')
order by p.proname, p.oid;
\o

-- Y cuantos negocios arrastran ya el rastro de ese 50% automatico.
\o C:/Proyectos/salonymas/_vivo_rastro_pionero.txt
select '=== QUIEN LLEVA EL MOTIVO QUE ESCRIBIO LA APROBACION ===';
select t.name
       || ' | pionero=' || ts.is_founder
       || ' | descuento=' || coalesce(ts.discount_percent::text, '(ninguno)')
       || ' | pactado=' || coalesce(ts.price_cop::text, '(ninguno)')
       || ' | motivo=' || coalesce(ts.price_reason, '(sin motivo)')
from public.tenant_subscriptions ts
join public.tenants t on t.id = ts.tenant_id
order by t.name;
\o

\pset tuples_only off
\pset format aligned

\echo ''
\echo 'Listo. Quedaron tres archivos _vivo_* en la carpeta del proyecto.'
