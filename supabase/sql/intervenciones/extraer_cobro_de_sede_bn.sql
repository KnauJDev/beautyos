-- Extrae el texto VIVO del cobro de una sede. Hallazgos BN y BO.
--
-- POR QUE.
--
-- BN (decidido por el propietario el 23-sep): *"cobra el mes completo aunque
-- paguen en la gracia"*. Hoy `beautyos_calcular_cargo_sede` cobra solo los dias
-- que faltan hasta el corte (D-160, regla 3), asi que los dias de gracia salen
-- gratis. Cambiarlo es reescribir esa funcion.
--
-- BO (sospecha, sin comprobar): en el repositorio,
-- `beautyos_procesar_pago_de_sede` -- la que ACTIVA la sede cuando llega el
-- pago -- exige un minimo de $10.000 a todo pago que no sea prorrateado. La
-- sede de la Peluqueria Exito esta pactada en $4.500: si la base viva es igual,
-- el pago real del paso 9.8 se cobraria y la sede NO se activaria.
--
-- Las dos cosas se deciden sobre el texto vivo, no sobre el del repositorio
-- (reglas 10 y 25).
--
-- NO MODIFICA NADA.
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\extraer_cobro_de_sede_bn.sql"
--
-- Deja `_vivo_bn_cobro_de_sede.sql` en la raiz. No se sube (.gitignore).

\encoding UTF8
\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_bn_cobro_de_sede.sql
select '-- ===== ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind = 'f'
  and n.nspname in ('public', 'private')
  and p.proname in (
    'beautyos_calcular_cargo_sede',
    'beautyos_procesar_pago_de_sede'
  )
order by n.nspname, p.proname;

-- Quien usa los motivos del calculo, para no romper a nadie al renombrar uno.
select '-- usa el motivo pago_tardio_prorrateado: ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ')'
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind = 'f'
  and n.nspname in ('public', 'private')
  and pg_get_functiondef(p.oid) ilike '%pago_tardio_prorrateado%'
order by n.nspname, p.proname;

-- Los precios pactados por debajo de $10.000 hoy (los afectados por BO).
select '-- sede por debajo de 10.000: ' || t.name || ' / ' || b.name
       || ' = ' || bs.price_cop || ' (' || coalesce(bs.price_reason, '') || ')'
from public.branch_subscriptions bs
join public.branches b on b.id = bs.branch_id
join public.tenants t on t.id = bs.tenant_id
where bs.price_cop is not null and bs.price_cop < 10000
order by t.name, b.name;
\o
