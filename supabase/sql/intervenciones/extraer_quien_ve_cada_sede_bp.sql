-- Extrae el texto VIVO de lo que decide quien ve y paga cada sede. Hallazgo BP.
--
-- DECIDIDO POR EL PROPIETARIO (D-268, y precisado el 23-sep por la tarde):
--   * el DUENO ve todas sus sedes y puede pagar cualquiera (como hoy);
--   * cada ADMINISTRADOR ve y paga solo la suya.
--
-- Hoy `get_branch_subscriptions` devuelve TODAS las sedes a cualquier dueno o
-- administrador, y `create-epayco-session` solo comprueba que la sede sea del
-- negocio. La idea es apoyarse en `get_my_branch_context_v2` -- la que llena el
-- selector de sede de arriba --, para que "Tus sedes" y el selector usen la
-- MISMA regla. Antes hay que ver que devuelve de verdad para un dueno y para
-- un administrador, y como estan escritas las piezas que se van a usar.
--
-- NO MODIFICA NADA.
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\extraer_quien_ve_cada_sede_bp.sql"
--
-- Deja `_vivo_bp_quien_ve_cada_sede.sql` en la raiz. No se sube (.gitignore).

\encoding UTF8
\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_bp_quien_ve_cada_sede.sql
select '-- ===== ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind = 'f'
  and n.nspname in ('public', 'private')
  and p.proname in (
    'get_branch_subscriptions',
    'get_my_branch_context_v2',
    'is_owner_or_admin',
    'get_my_tenant_id'
  )
order by n.nspname, p.proname;

-- Quien mas llama a get_my_branch_context_v2, para no romper a nadie.
select '-- la usa: ' || n.nspname || '.' || p.proname
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind = 'f'
  and n.nspname in ('public', 'private')
  and p.proname <> 'get_my_branch_context_v2'
  and pg_get_functiondef(p.oid) ilike '%get_my_branch_context_v2%'
order by 1;
\o
