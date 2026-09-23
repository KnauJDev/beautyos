-- Extrae el texto VIVO de lo que decide si un negocio vencido puede agendar.
-- Hallazgo BI, la parte que queda despues de la migracion 20260923120000.
--
-- AMPLIADO EL 23-SEP (D-260). El propietario decidio que **una sede
-- suspendida por no pago deja de poder agendar citas nuevas** (las demas
-- siguen normales, y lo ya agendado se atiende y se cobra). Para hacerlo hay
-- que tocar las DOS puertas por las que nace una cita -- la interna y la
-- reserva publica --, y la tabla `tickets` NO esta en ninguna migracion del
-- repositorio (hallazgo AI). Por eso se traen tambien, por su nombre, las dos
-- funciones y la forma viva de `tickets` con sus disparadores.
--
-- POR QUE. La migracion de BI no reescribe nada: anade el paso de `active` a
-- `past_due` por fecha y deja que la maquinaria de D-141 haga el resto. Se
-- escribio leyendo el REPOSITORIO, que no es la fuente del esquema (hallazgo
-- AI). Esto trae el texto vivo para comprobar dos cosas:
--
--   1. Que `beautyos_tenant_accepts_new_commitments` y
--      `beautyos_suspender_suscripciones_vencidas` son hoy lo que la migracion
--      supone (gracia en `past_due`, suspension al vencerla).
--   2. Donde vive el mensaje *"La prueba gratis de este negocio esta
--      vencida"*, que se le dice tambien a quien pago meses y dejo de pagar.
--      Cambiarlo es reescribir las funciones que lo lanzan: no se hace de
--      memoria (D-119, D-122, D-123).
--
-- NO MODIFICA NADA.
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\extraer_candado_y_vencimiento_bi.sql"
--
-- Deja tres archivos _vivo_*.sql en la raiz del repositorio. No se suben:
-- se leen, se comparan y se borran.

\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_bi_candado_y_vigilante.sql
select '-- ===== ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind = 'f'
  and n.nspname = 'private'
  and p.proname in (
    'beautyos_tenant_accepts_new_commitments',
    'beautyos_suspender_suscripciones_vencidas'
  )
order by p.proname;
\o

\o C:/Proyectos/salonymas/_vivo_bi_quien_dice_prueba_gratis.sql
select '-- ===== ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind = 'f'
  and n.nspname in ('public', 'private')
  and pg_get_functiondef(p.oid) ilike '%prueba gratis de este negocio%'
order by n.nspname, p.proname;
\o

\o C:/Proyectos/salonymas/_vivo_bi_las_dos_puertas.sql
select '-- ===== ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind = 'f'
  and n.nspname = 'public'
  and p.proname in ('create_scheduled_ticket_with_service_v2', 'public_create_booking')
order by p.proname;
\o

\o C:/Proyectos/salonymas/_vivo_bi_tabla_tickets.sql
select '-- columna: ' || column_name || ' ' || data_type
       || case when is_nullable = 'NO' then ' not null' else '' end
from information_schema.columns
where table_schema = 'public' and table_name = 'tickets'
order by ordinal_position;
select '-- disparador: ' || tgname || ' -> ' || tgfoid::regproc::text
from pg_trigger
where tgrelid = 'public.tickets'::regclass and not tgisinternal
order by tgname;
\o

\o C:/Proyectos/salonymas/_vivo_bi_sedes_al_dia.sql
select '-- ===== ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind = 'f'
  and n.nspname in ('public', 'private')
  and p.proname in ('get_branch_subscriptions', 'platform_get_tenant_branches')
order by n.nspname, p.proname;
\o
