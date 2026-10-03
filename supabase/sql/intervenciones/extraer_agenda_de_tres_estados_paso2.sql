-- Extrae el texto VIVO de como nace una cita y como cambia de estado.
-- Paso 2 del plan del primer cliente real (D-308), ampliado el 02-oct por el
-- propietario: AGENDA DE TRES ESTADOS. NO MODIFICA NADA.
--
-- POR QUE. A un negocio con la caja apagada por la plataforma (D-310), como
-- David, el propietario decidio que:
--   * toda cita entre CONFIRMADA, la pida la clienta por el enlace o la cree
--     el salon;
--   * la agenda tenga solo tres estados: Confirmado -> En proceso -> Cerrado;
--   * Cancelar y No asistio sean botones, no columnas;
--   * todo eso vaya amarrado al interruptor 'Caja y cobros', sin otro nuevo.
-- Y "Cerrado" ahi significa ATENDIDA, no cobrada: no puede nacer ningun pago
-- ni comision, ni tocarse el historial de dinero (AGENTS.md).
--
-- Antes de escribir la migracion se lee lo vivo (regla 10):
--   1. Las funciones por donde NACE una cita, y con que estado nace.
--   2. Las que la CAMBIAN de estado, y la que la cierra cuando esta pagada:
--      hay que saber que pasa si se termina un servicio que nadie cobra.
--   3. Lo que ve el estilista en Mi agenda.
--   4. Los disparadores de las tablas de citas, con su texto.
--   5. Las restricciones de esas tablas: que estados existen y cual impide
--      que dos citas choquen.
--   6. Solo los NOMBRES de las demas funciones que tratan aparte las citas
--      'solicitado' o 'finalizado': lo que podria cambiar sin que se note
--      (por ejemplo, el tope de reservas publicas).
--   7. Cuantas citas hay por estado en los negocios con la caja apagada
--      (sin nombres).
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\extraer_agenda_de_tres_estados_paso2.sql"
--
-- Deja `_vivo_paso2_tres_estados.sql` en la raiz. No se sube (.gitignore).

\encoding UTF8
\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_paso2_tres_estados.sql

select '-- ===== 1, 2 y 3. LAS FUNCIONES';
select '-- ===== FUNCION ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind = 'f'
  and n.nspname in ('public', 'private')
  and p.proname in (
    'public_create_booking',
    'create_ticket',
    'create_scheduled_ticket_with_service',
    'create_scheduled_ticket_with_service_v2',
    'create_recurring_scheduled_tickets_v2',
    'change_ticket_status',
    'change_ticket_status_v2',
    'change_ticket_service_status',
    'change_ticket_service_status_v2',
    'beautyos_close_ticket_if_fully_paid',
    'get_my_stylist_agenda_by_date_v2'
  )
order by n.nspname, p.proname;

select '-- ===== PERMISOS ' || routine_schema || '.' || routine_name || ' -> '
       || string_agg(grantee || ':' || privilege_type, ', ' order by grantee)
from information_schema.routine_privileges
where routine_schema in ('public', 'private')
  and routine_name in (
    'public_create_booking',
    'create_scheduled_ticket_with_service_v2',
    'create_recurring_scheduled_tickets_v2',
    'change_ticket_status_v2',
    'change_ticket_service_status_v2'
  )
group by routine_schema, routine_name
order by routine_schema, routine_name;

select '-- ===== 4. DISPARADORES DE tickets Y ticket_services';
select '-- ' || c.relname || ' | ' || pg_get_triggerdef(t.oid)
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('tickets', 'ticket_services')
  and not t.tgisinternal
order by c.relname, t.tgname;

select '-- ===== FUNCION DE DISPARADOR ' || n.nspname || '.' || p.proname || ' =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
join pg_namespace cn on cn.oid = c.relnamespace
join pg_proc p on p.oid = t.tgfoid
join pg_namespace n on n.oid = p.pronamespace
where cn.nspname = 'public'
  and c.relname in ('tickets', 'ticket_services')
  and not t.tgisinternal
group by n.nspname, p.proname, p.oid
order by n.nspname, p.proname;

select '-- ===== 5. RESTRICCIONES';
select '-- ' || rel.relname || ' | ' || con.conname || ' | ' || pg_get_constraintdef(con.oid)
from pg_constraint con
join pg_class rel on rel.oid = con.conrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public'
  and rel.relname in ('tickets', 'ticket_services')
order by rel.relname, con.conname;

select '-- ===== 6. OTRAS FUNCIONES QUE NOMBRAN ''solicitado'' O ''finalizado'' (solo el nombre)';
select '-- ' || n.nspname || '.' || p.proname
       || case when p.prosrc ilike '%solicitado%' then ' [solicitado]' else '' end
       || case when p.prosrc ilike '%finalizado%' then ' [finalizado]' else '' end
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public', 'private')
  and p.prokind = 'f'
  and (p.prosrc ilike '%solicitado%' or p.prosrc ilike '%finalizado%')
group by n.nspname, p.proname, p.prosrc
order by n.nspname, p.proname;

select '-- ===== 7. CITAS POR ESTADO EN LOS NEGOCIOS CON LA CAJA APAGADA (sin nombres)';
select '-- negocio ' || left(t.tenant_id::text, 8) || ' | ' || t.status || ' | ' || count(*)
from public.tickets t
where exists (
  select 1
  from public.tenant_feature_overrides o
  join public.features f on f.id = o.feature_id
  where o.tenant_id = t.tenant_id
    and f.key = 'cash_register'
    and o.enabled = false
    and o.starts_at <= now()
    and (o.ends_at is null or o.ends_at > now())
)
group by t.tenant_id, t.status
order by 1;

\o

\echo 'Listo: _vivo_paso2_tres_estados.sql'
