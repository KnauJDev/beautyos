-- Extrae el texto VIVO de lo que toca el paso 5 del plan de David (D-308,
-- D-311): EL DASHBOARD DE ATENCIONES, sin dinero, y su INTERRUPTOR PROPIO.
-- NO MODIFICA NADA.
--
-- POR QUÉ. El propietario decidió el 04-oct:
--   * el Dashboard tiene su propio interruptor en el Panel, separado de
--     "Finanzas" (que se queda con Reportes);
--   * en los negocios sin caja, un Dashboard nuevo que cuenta la historia
--     del negocio en atenciones y no en pesos. Aprobó el prototipo
--     https://claude.ai/artifact/Ptnrpy3N23NbSATn2n3BP3 : citas atendidas,
--     clientas, nuevas, asistencia y horas de trabajo contra el periodo
--     anterior; por día; día × hora; por servicio; por estilista (con
--     reseñas); en línea contra el salón; nuevas contra las que vuelven;
--     canceladas y no llegaron con sus motivos.
-- Antes de escribir la consulta nueva se lee lo vivo (regla 10). El
-- repositorio no tiene el esquema entero (hallazgo AI): las tablas de citas
-- nacieron fuera de las migraciones.
--   1. Las columnas de las tablas que se van a leer.
--   2. Las funciones del Dashboard de hoy, para copiar cómo eligen las sedes,
--      cómo ponen el día en la hora de la sede y quién puede llamarlas.
--   3. Las funciones de capacidades (para el interruptor nuevo) y la de
--      Invitar a volver (D-314), que el Dashboard va a reutilizar.
--   4. Los permisos de esas funciones.
--   5. CÓMO SON LOS DATOS, solo con conteos y sin un nombre: los canales y
--      estados de las citas, cómo se guarda el motivo de una cancelación, si
--      las reseñas traen estilista, y las capacidades que ya existen.
--   6. Los índices, para que la consulta no recorra tablas enteras.
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\extraer_dashboard_de_atenciones_paso5.sql"
--
-- Deja `_vivo_paso5_dashboard.sql` en la raiz. No se sube (.gitignore).

\encoding UTF8
\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_paso5_dashboard.sql

select '-- ===== 1. COLUMNAS';
select '-- ' || c.table_name || '.' || c.column_name || ' | ' || c.data_type
       || ' | nulo=' || c.is_nullable || ' | defecto=' || coalesce(c.column_default, '-')
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name in ('tickets', 'ticket_services', 'ticket_history', 'clients',
                       'reviews', 'client_return_invitations', 'services',
                       'stylists', 'branches', 'features', 'plan_features',
                       'tenant_feature_overrides')
order by c.table_name, c.ordinal_position;

select '-- ===== 2 y 3. LAS FUNCIONES';
select '-- ===== FUNCION ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind = 'f'
  and n.nspname in ('public', 'private')
  and p.proname in (
    'get_dashboard_overview',
    'get_dashboard_today',
    'get_dashboard_series',
    'beautyos_dashboard_branches',
    'is_owner_or_admin',
    'get_return_invitations',
    'beautyos_resolve_entitlement',
    'get_my_entitlements'
  )
order by n.nspname, p.proname;

select '-- ===== 4. PERMISOS DE FUNCIONES ' || routine_schema || '.' || routine_name || ' -> '
       || string_agg(grantee || ':' || privilege_type, ', ' order by grantee)
from information_schema.routine_privileges
where routine_schema in ('public', 'private')
  and routine_name in (
    'get_dashboard_overview', 'get_dashboard_today', 'get_dashboard_series',
    'beautyos_dashboard_branches', 'get_return_invitations', 'get_my_entitlements'
  )
group by routine_schema, routine_name
order by routine_schema, routine_name;

select '-- ===== 5. COMO SON LOS DATOS (solo conteos, sin nombres)';

select '-- citas por canal | ' || coalesce(t.channel, '(vacio)') || ' | ' || count(*)
from public.tickets t
group by t.channel
order by count(*) desc;

select '-- citas por estado | ' || coalesce(t.status, '(vacio)') || ' | ' || count(*)
from public.tickets t
group by t.status
order by count(*) desc;

select '-- servicios de cita por estado | ' || coalesce(ts.status, '(vacio)') || ' | '
       || count(*) || ' | sin estilista=' || count(*) filter (where ts.stylist_id is null)
       || ' | sin duracion=' || count(*) filter (where ts.duration_minutes is null)
from public.ticket_services ts
group by ts.status
order by count(*) desc;

select '-- historial por evento y estado nuevo | ' || coalesce(h.event_type, '(vacio)') || ' | '
       || coalesce(h.new_status, '(vacio)') || ' | ' || count(*)
       || ' | con motivo=' || count(*) filter (where nullif(trim(h.reason), '') is not null)
from public.ticket_history h
group by h.event_type, h.new_status
order by count(*) desc;

select '-- resenas | total=' || count(*)
       || ' | con estilista=' || count(*) filter (where r.stylist_id is not null)
       || ' | con cita=' || count(*) filter (where r.ticket_id is not null)
from public.reviews r;

select '-- resenas por estado | ' || coalesce(r.status::text, '(vacio)') || ' | ' || count(*)
from public.reviews r
group by r.status
order by count(*) desc;

select '-- invitaciones a volver | total=' || count(*)
from public.client_return_invitations;

select '-- capacidad | ' || f.key || ' | ' || f.name || ' | planes con fila='
       || (select count(*) from public.plan_features pf where pf.feature_id = f.id)
       || ' | encendida en=' || (select count(*) from public.plan_features pf
                                  where pf.feature_id = f.id and pf.enabled)
from public.features f
order by f.key;

select '-- planes | total=' || count(*) from public.plans;

select '-- ===== 6. INDICES';
select '-- ' || tablename || ' | ' || indexname || ' | ' || indexdef
from pg_indexes
where schemaname = 'public'
  and tablename in ('tickets', 'ticket_services', 'ticket_history', 'reviews',
                    'client_return_invitations')
order by tablename, indexname;

select '-- ===== RESTRICCIONES DE features Y plan_features';
select '-- ' || rel.relname || ' | ' || con.conname || ' | ' || pg_get_constraintdef(con.oid)
from pg_constraint con
join pg_class rel on rel.oid = con.conrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public' and rel.relname in ('features', 'plan_features')
order by rel.relname, con.conname;

\o

\echo 'Listo: _vivo_paso5_dashboard.sql'
