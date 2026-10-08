-- Extrae el texto VIVO de lo que toca el paso 9.63: CUÁNDO VUELVE CADA
-- CLIENTA (pedido de David el 08-oct). NO MODIFICA NADA.
--
-- POR QUÉ. El propietario decidió el 08-oct (prototipo
-- https://claude.ai/artifact/N48aApd2qmN17Fxc5kHTne):
--   * al cerrar un servicio se pregunta en cuántos días invitar a volver a
--     ESA clienta por ESE servicio, ya lleno con su número (si no tiene, el
--     del servicio; si no, el del salón);
--   * el número se recuerda en su ficha y se cambia ahí ("Usar el del
--     servicio" lo quita);
--   * lo ponen el dueño, recepción Y la estilista (al terminar en Mi agenda);
--   * cada servicio trae un interruptor "Invitar a volver": apagado, ese
--     servicio no la invita esta vez, su número no se borra, y al próximo
--     cierre de ese servicio se pregunta otra vez;
--   * "Para invitar hoy" y la campana cuentan con el número de cada clienta.
-- Antes de escribir la migración se lee lo vivo (regla 10):
--   1. Las columnas de las tablas que se tocan o se leen.
--   2. Toda función que hoy lee los tiempos de volver o las invitaciones
--      (la lista "Para invitar hoy" se reescribe desde su texto vivo).
--   3. Las funciones que cierran una cita y terminan un servicio (dueño y
--      recepción desde la Agenda; la estilista desde Mi agenda), para saber
--      quién puede qué y cómo se reconoce a la estilista de un servicio.
--   4. Los permisos de esas funciones.
--   5. La seguridad de `client_return_invitations`, para copiar su patrón
--      en la tabla nueva y no inventarlo (D-313).
--   6. Cuántas filas hay hoy (solo números, ningún dato de clientas).
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\extraer_cuando_vuelve_9_63.sql"
--
-- Deja `_vivo_cuando_vuelve.sql` en la raiz. No se sube (.gitignore).

\encoding UTF8
\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_cuando_vuelve.sql

select '-- ===== 1. COLUMNAS';
select '-- ' || c.table_name || '.' || c.column_name || ' | ' || c.data_type
       || ' | nulo=' || c.is_nullable || ' | defecto=' || coalesce(c.column_default, '-')
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name in ('client_return_invitations', 'services', 'tenants',
                       'tickets', 'ticket_services', 'clients', 'stylists')
order by c.table_name, c.ordinal_position;

select '-- ===== 2. LO QUE LEE LOS TIEMPOS DE VOLVER O LAS INVITACIONES';
select '-- ===== FUNCION ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind = 'f'
  and n.nspname in ('public', 'private')
  and (pg_get_functiondef(p.oid) ilike '%client_return_invitations%'
       or pg_get_functiondef(p.oid) ilike '%return_after_days%'
       or pg_get_functiondef(p.oid) ilike '%return_default_days%')
order by n.nspname, p.proname;

select '-- ===== 3. CERRAR UNA CITA Y TERMINAR UN SERVICIO';
select '-- ===== FUNCION ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind = 'f'
  and n.nspname in ('public', 'private')
  and p.proname in (
    'change_ticket_service_status_v2',
    'change_ticket_status_v2',
    'get_ticket_services_for_management_v2',
    'get_my_stylist_agenda_by_date_v2'
  )
order by n.nspname, p.proname;

select '-- ===== 4. PERMISOS DE FUNCIONES ' || routine_schema || '.' || routine_name || ' -> '
       || string_agg(grantee || ':' || privilege_type, ', ' order by grantee)
from information_schema.routine_privileges
where routine_schema = 'public'
  and routine_name in (
    'get_return_invitations', 'register_return_invitation', 'get_return_days',
    'set_service_return_days', 'set_return_default_days',
    'change_ticket_service_status_v2', 'change_ticket_status_v2',
    'get_ticket_services_for_management_v2', 'get_my_stylist_agenda_by_date_v2'
  )
group by routine_schema, routine_name
order by routine_schema, routine_name;

select '-- ===== 5. SEGURIDAD DE client_return_invitations';
select '-- ' || c.relname || ' | rls=' || c.relrowsecurity || ' | forzada=' || c.relforcerowsecurity
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relname = 'client_return_invitations';

select '-- POLITICA ' || pol.tablename || ' | ' || pol.policyname || ' | ' || pol.cmd
       || ' | roles=' || array_to_string(pol.roles, ',') || chr(10)
       || '--   using: ' || coalesce(pol.qual, '-') || chr(10)
       || '--   check: ' || coalesce(pol.with_check, '-')
from pg_policies pol
where pol.schemaname = 'public' and pol.tablename = 'client_return_invitations'
order by pol.policyname;

select '-- PERMISOS DE TABLA ' || g.table_name || ' -> '
       || string_agg(g.grantee || ':' || g.privilege_type, ', ' order by g.grantee, g.privilege_type)
from information_schema.role_table_grants g
where g.table_schema = 'public'
  and g.table_name = 'client_return_invitations'
  and g.grantee in ('anon', 'authenticated', 'service_role')
group by g.table_name;

select '-- RESTRICCION ' || con.conname || ' | ' || pg_get_constraintdef(con.oid)
from pg_constraint con
join pg_class rel on rel.oid = con.conrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public' and rel.relname = 'client_return_invitations'
order by con.conname;

select '-- INDICE ' || indexname || ' | ' || indexdef
from pg_indexes
where schemaname = 'public' and tablename = 'client_return_invitations'
order by indexname;

select '-- ===== 6. CUÁNTAS FILAS (solo números)';
select '-- invitaciones registradas: ' || count(*) from public.client_return_invitations;
select '-- servicios con tiempo propio: ' || count(*)
from public.services where return_after_days is not null;
select '-- salones con tiempo distinto de 45: ' || count(*)
from public.tenants where return_default_days <> 45;

\o

\echo 'Listo: _vivo_cuando_vuelve.sql'
