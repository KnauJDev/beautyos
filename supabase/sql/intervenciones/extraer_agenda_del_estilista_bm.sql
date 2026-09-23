-- Extrae el texto VIVO de todo lo que toca "el estilista agenda para si mismo".
-- Hallazgo BM, decidido por el propietario el 23-sep (D-263, D-265):
--
--   * el estilista agenda citas **para si mismo** ("leads y ventas por sus
--     medios"), no para otros;
--   * puede dar de alta a la clienta nueva **desde Mi agenda**;
--   * la cita que crea **nace por confirmar**.
--
-- Hoy el servidor no le deja: `create_scheduled_ticket_with_service_v2` solo
-- acepta dueno, administrador y recepcion desde el 20-jul. Y para que la
-- ventana de nueva cita funcione, el estilista tiene que poder leer los
-- servicios, los horarios libres y las clientas: cada una de esas funciones
-- decide por su cuenta quien entra. Se leen todas antes de tocar ninguna.
--
-- NO MODIFICA NADA.
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\extraer_agenda_del_estilista_bm.sql"
--
-- Deja `_vivo_bm_agenda_del_estilista.sql` en la raiz. No se sube (.gitignore).

\encoding UTF8
\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_bm_agenda_del_estilista.sql
select '-- ===== ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind = 'f'
  and (
    (n.nspname = 'public' and p.proname in (
      'create_scheduled_ticket_with_service_v2',
      'create_client',
      'get_clients_summary',
      'get_ticket_service_options_v2',
      'get_available_appointment_slots_v2'
    ))
    or (n.nspname = 'private' and p.proname = 'beautyos_resolve_branch_access')
  )
order by n.nspname, p.proname;
\o
