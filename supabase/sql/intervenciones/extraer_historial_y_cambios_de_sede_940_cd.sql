-- Extrae el texto VIVO de lo que escribe y lee el historial de pagos de un
-- negocio. Paso 9.40 y hallazgo CD.
--
-- POR QUE.
--   9.40: el historial del Panel ("5. Historial de Periodos Registrados") no
--         dice de que sede fue cada cobro. Desde D-239 cada sede paga lo suyo,
--         asi que un negocio con dos sedes ve una lista de importes sin dueno.
--   CD:   el 30-sep el propietario guardo el precio de la sede de Exito desde el
--         Panel y el historial no enseno nada. Segun el repositorio,
--         `platform_set_branch_subscription` cambia precio, estado y vencimiento
--         de una sede SIN escribir en `subscription_events`, mientras que aprobar
--         un negocio y cambiarle el plan si escriben su evento.
--
-- Antes de tocar nada se lee, del texto vivo y no del repositorio (regla 10):
--   1. Las tres funciones: la que lee el historial, la que cambia una sede desde
--      el Panel y la que registra el pago de una sede.
--   2. Sus permisos (un CREATE OR REPLACE los conserva, pero se miran antes).
--   3. Como es hoy `subscription_events`: columnas, restricciones y disparadores
--      (si alguna restringe los tipos de evento, la migracion tiene que saberlo).
--   4. Que CLAVES lleva el `payload` de cada tipo de evento. Solo los nombres de
--      las claves y cuantos eventos hay: ningun dato de nadie. De aqui sale si
--      un pago de sede guarda de que sede es, o hay que buscarlo en la intencion.
--   5. Las columnas de `subscription_payment_intents`, que sabe la sede de cada
--      cobro desde D-191.
--
-- NO MODIFICA NADA.
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\extraer_historial_y_cambios_de_sede_940_cd.sql"
--
-- Deja `_vivo_940_cd.sql` en la raiz. No se sube (.gitignore).

\encoding UTF8
\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_940_cd.sql

-- 1. Las funciones.
select '-- ===== FUNCION ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind = 'f'
  and n.nspname in ('public', 'private')
  and p.proname in (
    'platform_get_tenant_subscription_history',
    'platform_set_branch_subscription',
    'beautyos_procesar_pago_de_sede'
  )
order by n.nspname, p.proname;

-- 2. Sus permisos.
select '-- ===== PERMISOS ' || routine_schema || '.' || routine_name || ' -> '
       || string_agg(grantee || ':' || privilege_type, ', ' order by grantee)
from information_schema.routine_privileges
where routine_schema in ('public', 'private')
  and routine_name in (
    'platform_get_tenant_subscription_history',
    'platform_set_branch_subscription',
    'beautyos_procesar_pago_de_sede'
  )
group by routine_schema, routine_name
order by routine_schema, routine_name;

-- 3. La tabla de eventos: columnas, restricciones y disparadores.
select '-- ===== subscription_events';
select '-- columna: ' || column_name || ' ' || data_type
       || case when is_nullable = 'NO' then ' not null' else '' end
from information_schema.columns
where table_schema = 'public' and table_name = 'subscription_events'
order by ordinal_position;
select '-- restriccion: ' || con.conname || ' | ' || pg_get_constraintdef(con.oid)
from pg_constraint con
join pg_class rel on rel.oid = con.conrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public' and rel.relname = 'subscription_events'
order by con.conname;
select '-- disparador: ' || tgname || ' -> ' || tgfoid::regproc::text
from pg_trigger
where tgrelid = 'public.subscription_events'::regclass and not tgisinternal
order by tgname;

-- 4. Que claves lleva el payload de cada tipo de evento (solo los nombres).
select '-- ===== CLAVES DEL PAYLOAD POR TIPO DE EVENTO';
select '-- ' || se.event_type || ' / ' || coalesce(se.provider, '(sin provider)')
       || ' / ' || count(distinct se.id) || ' eventos -> '
       || string_agg(distinct k, ', ' order by k)
from public.subscription_events se
cross join lateral jsonb_object_keys(se.payload) k
group by se.event_type, se.provider
order by se.event_type, se.provider;

-- 5. Las columnas de las intenciones de pago.
select '-- ===== subscription_payment_intents';
select '-- columna: ' || column_name || ' ' || data_type
       || case when is_nullable = 'NO' then ' not null' else '' end
from information_schema.columns
where table_schema = 'public' and table_name = 'subscription_payment_intents'
order by ordinal_position;

\o

\echo 'Listo: _vivo_940_cd.sql'
