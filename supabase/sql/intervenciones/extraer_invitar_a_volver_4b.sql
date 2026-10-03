-- Extrae el texto VIVO de lo que toca el paso 4B del plan de David (D-314):
-- INVITAR A VOLVER POR SERVICIO. NO MODIFICA NADA.
--
-- POR QUÉ. El propietario decidió el 03-oct:
--   * cada servicio tiene su propio "tiempo de volver" (el rubber de uñas a
--     20 días, el tinte a 60 o 90), con un valor por defecto del salón (45);
--   * cada servicio que se hizo una clienta es un RECORDATORIO aparte:
--     invitarla por uno no borra el otro, y se elige por cuál invitar;
--   * cada invitación se guarda; la que fue invitada y no volvió queda en
--     "Invitadas que no volvieron", con "última invitación hace N días", y
--     reaparece cuando pasa otra vez el tiempo del servicio;
--   * la lista sale arriba de la Agenda y como filtro en Clientes.
-- Antes de escribir la migración se lee lo vivo (regla 10):
--   1. Las columnas de las tablas que se tocan o se leen.
--   2. Las funciones que crean, editan y listan servicios (a una hay que
--      añadirle el tiempo de volver).
--   3. Los ajustes del negocio: dónde viven y cómo se editan (para el valor
--      por defecto del salón).
--   4. Cómo se calculan hoy las visitas de cada clienta.
--   5. Las reglas de seguridad y los permisos de dos tablas parecidas a la
--      de invitaciones, para copiar su patrón y no inventarlo (D-313).
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\extraer_invitar_a_volver_4b.sql"
--
-- Deja `_vivo_paso4b_invitar.sql` en la raiz. No se sube (.gitignore).

\encoding UTF8
\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_paso4b_invitar.sql

select '-- ===== 1. COLUMNAS';
select '-- ' || c.table_name || '.' || c.column_name || ' | ' || c.data_type
       || ' | nulo=' || c.is_nullable || ' | defecto=' || coalesce(c.column_default, '-')
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name in ('services', 'branch_services', 'tenants', 'ticket_services',
                       'tickets', 'clients', 'stylist_time_off', 'client_consents')
order by c.table_name, c.ordinal_position;

select '-- ===== 2, 3 y 4. LAS FUNCIONES';
select '-- ===== FUNCION ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind = 'f'
  and n.nspname in ('public', 'private')
  and p.proname in (
    'create_service',
    'update_service',
    'set_service_active',
    'get_services_for_management',
    'get_business_settings',
    'update_tenant_contact_info',
    'get_clients_management_summary',
    'create_client'
  )
order by n.nspname, p.proname;

select '-- ===== PERMISOS DE FUNCIONES ' || routine_schema || '.' || routine_name || ' -> '
       || string_agg(grantee || ':' || privilege_type, ', ' order by grantee)
from information_schema.routine_privileges
where routine_schema = 'public'
  and routine_name in (
    'create_service', 'update_service', 'get_services_for_management',
    'get_business_settings', 'update_tenant_contact_info',
    'get_clients_management_summary'
  )
group by routine_schema, routine_name
order by routine_schema, routine_name;

select '-- ===== 5. REGLAS DE SEGURIDAD (RLS) DE TABLAS PARECIDAS';
select '-- ' || c.relname || ' | rls=' || c.relrowsecurity || ' | forzada=' || c.relforcerowsecurity
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('stylist_time_off', 'client_consents', 'services', 'clients')
order by c.relname;

select '-- POLITICA ' || pol.tablename || ' | ' || pol.policyname || ' | ' || pol.cmd
       || ' | roles=' || array_to_string(pol.roles, ',') || chr(10)
       || '--   using: ' || coalesce(pol.qual, '-') || chr(10)
       || '--   check: ' || coalesce(pol.with_check, '-')
from pg_policies pol
where pol.schemaname = 'public'
  and pol.tablename in ('stylist_time_off', 'client_consents', 'services', 'clients')
order by pol.tablename, pol.policyname;

select '-- PERMISOS DE TABLA ' || g.table_name || ' -> '
       || string_agg(g.grantee || ':' || g.privilege_type, ', ' order by g.grantee, g.privilege_type)
from information_schema.role_table_grants g
where g.table_schema = 'public'
  and g.table_name in ('stylist_time_off', 'client_consents', 'services', 'clients')
  and g.grantee in ('anon', 'authenticated', 'service_role')
group by g.table_name
order by g.table_name;

select '-- ===== RESTRICCIONES DE services';
select '-- ' || con.conname || ' | ' || pg_get_constraintdef(con.oid)
from pg_constraint con
join pg_class rel on rel.oid = con.conrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public' and rel.relname = 'services'
order by con.conname;

\o

\echo 'Listo: _vivo_paso4b_invitar.sql'
