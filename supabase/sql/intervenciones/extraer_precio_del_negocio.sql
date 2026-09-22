-- Extrae el texto VIVO de lo que toca retirar el precio por negocio (AG).
--
-- POR QUE. Al reescribir una funcion hay que sacar primero su texto actual y
-- comparar linea por linea (D-119, D-122, D-123). Las tres viven en el camino
-- del dinero y ninguna se puede reescribir de memoria.
--
-- POR QUE SE VUELCAN **TODAS** LAS VERSIONES DE CADA NOMBRE. La primera
-- pasada de este archivo se cayo con *"more than one function named
-- private.beautyos_calcular_cargo_epayco"*: **hay dos versiones vivas del
-- calculo de cobro del negocio**, y `::regproc` no sabe cual. Eso no se sabia
-- antes de preguntar, y es justo la clase de cosa que hace falta saber antes
-- de cerrar un camino de dinero. Asi que aqui no se nombra ninguna firma: se
-- recorre `pg_proc` y se vuelca lo que haya.
--
-- Trae ademas **quien llama a ese calculo**: si alguna otra funcion depende de
-- el, cerrarlo a ciegas romperia algo que nadie esta mirando.
--
-- NO MODIFICA NADA.

\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_firmas.txt
select '=== TODAS LAS VERSIONES VIVAS DE CADA NOMBRE ===';
select n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ')'
       || '  [oid ' || p.oid || ']'
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where p.proname in (
        'platform_approve_tenant',
        'platform_update_tenant_pricing',
        'beautyos_calcular_cargo_epayco',
        'beautyos_calcular_cargo_sede',
        'get_my_tenant_subscription_status')
order by p.proname, p.oid;

select '';
select '=== QUIEN LLAMA AL CAMINO DE COBRO DEL NEGOCIO ===';
with vivas as (
  select n.nspname as esquema, p.proname as nombre,
         pg_get_functiondef(p.oid) as cuerpo
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname in ('public', 'private') and p.prokind = 'f'
)
select esquema || '.' || nombre
from vivas
where cuerpo like '%beautyos_calcular_cargo_epayco%'
  and nombre <> 'beautyos_calcular_cargo_epayco'
order by 1;

select '';
select '(si no sale ninguna linea arriba, solo lo llama la Edge Function)';
\o

-- Todas las versiones del calculo de cobro del negocio, una detras de otra.
\o C:/Proyectos/salonymas/_vivo_cargo_epayco.sql
select '-- ===== ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where p.proname = 'beautyos_calcular_cargo_epayco'
order by p.oid;
\o

\pset tuples_only off
\pset format aligned

\echo ''
\echo 'Listo. Quedaron _vivo_firmas.txt y _vivo_cargo_epayco.sql.'
\echo 'Los de approve_tenant y update_tenant_pricing ya salieron en la pasada anterior.'
