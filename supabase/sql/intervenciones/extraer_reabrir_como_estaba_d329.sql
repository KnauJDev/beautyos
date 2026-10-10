-- Lectura antes de que una sede reabierta vuelva COMO ESTABA (D-329,
-- hallazgo CR). NO MODIFICA NADA.
--
-- POR QUÉ. El 10-oct, probando el paso 9.65 con *Prueba Dos Sedes*, Sede
-- Norte estaba sin pagar; se cerró y se reabrió desde el Panel, y quedó
-- *Al día* sin fecha de pago: gratis. Hoy reabrir no mira cómo estaba la
-- sede: el Panel la deja `active` y el dueño del salón `pending`. El
-- propietario decidió que vuelva como estaba al cerrarse, en los dos sitios.
-- El estado de antes ya se guarda en el rastro `sede_cerrada`
-- (`estado_anterior`). Se lee lo vivo (regla 10):
--   1. Las columnas de `subscription_events` (para elegir el último cierre).
--   2. El texto vivo de las dos reglas: cerrar y reabrir.
--   3. El rastro de Sede Norte de *Prueba Dos Sedes* (sin datos de personas).
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\extraer_reabrir_como_estaba_d329.sql"
--
-- Deja `_vivo_reabrir_como_estaba.sql` en la raiz. No se sube (.gitignore).

\encoding UTF8
\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_reabrir_como_estaba.sql

select '-- ===== 1. COLUMNAS DE subscription_events';
select '-- ' || c.column_name || ' | ' || c.data_type
       || ' | nulo=' || c.is_nullable || ' | defecto=' || coalesce(c.column_default, '-')
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name = 'subscription_events'
order by c.ordinal_position;

select '-- ===== 2. FUNCION ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind = 'f'
  and n.nspname = 'private'
  and p.proname in ('beautyos_cerrar_sede', 'beautyos_reabrir_sede')
order by p.proname;

select '-- ===== 3. RASTRO DE SEDE NORTE (Prueba Dos Sedes)';
select '-- ' || to_char(e.created_at at time zone 'America/Bogota', 'YYYY-MM-DD HH24:MI:SS')
       || ' | ' || e.event_type || ' | ' || coalesce(e.provider, '-')
       || ' | antes=' || coalesce(e.payload ->> 'estado_anterior', '-')
       || ' | nuevo=' || coalesce(e.payload ->> 'estado_nuevo', '-')
from public.subscription_events e
join public.branches b on b.id::text = e.payload ->> 'branch_id'
join public.tenants t on t.id = b.tenant_id
where t.name = 'Prueba Dos Sedes'
  and b.name = 'Sede Norte'
order by e.created_at;

select '-- ESTADO HOY: activa=' || b.active || ' | pago=' || bs.status
       || ' | pagada_hasta=' || coalesce(bs.current_period_end::text, '-')
from public.branches b
join public.tenants t on t.id = b.tenant_id
join public.branch_subscriptions bs on bs.branch_id = b.id
where t.name = 'Prueba Dos Sedes'
  and b.name = 'Sede Norte';

\o

\echo 'Listo: _vivo_reabrir_como_estaba.sql'
