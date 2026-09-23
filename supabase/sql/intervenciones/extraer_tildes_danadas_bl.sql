-- Extrae el texto VIVO de las funciones con tildes danadas. Hallazgo BL.
--
-- POR QUE. La comprobacion 9 del control 224 (23-sep) encontro UNA funcion con
-- texto danado por la codificacion: `public.reopen_finished_ticket_service`.
-- Y dos cosas que obligan a leerla antes de tocarla:
--
--   1. **Su version del repositorio no tiene ni una tilde**, asi que la viva es
--      otra: se cambio en la base por fuera de las migraciones (hallazgo AI).
--   2. Las migraciones con tildes aplicadas con `aplicar_sql.ps1` del 19 al
--      22-sep quedaron BIEN. La sospecha de D-261 -- que el guion danaba las
--      tildes -- era falsa: el dano viene de otro sitio.
--
-- Reescribir una funcion que no esta en el repositorio sin ver su texto es
-- exactamente lo que prohiben las reglas 10 y 25.
--
-- NO MODIFICA NADA.
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\extraer_tildes_danadas_bl.sql"
--
-- Deja `_vivo_bl_tildes_danadas.sql` en la raiz. No se sube (.gitignore).

-- El archivo de salida tiene que ser UTF-8 para leer el dano tal cual esta.
\encoding UTF8
\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_bl_tildes_danadas.sql
select '-- ===== ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ') =====' || chr(10)
       || pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public', 'private')
  and p.prokind = 'f'
  and pg_get_functiondef(p.oid) ~ U&'\00C3[\00A0-\00BF]'
order by n.nspname, p.proname;

-- Y quien la llama, para saber donde se ve el mensaje.
select '-- llamada desde: ' || n.nspname || '.' || p.proname
       || '(' || pg_get_function_identity_arguments(p.oid) || ')'
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public', 'private')
  and p.prokind = 'f'
  and p.proname <> 'reopen_finished_ticket_service'
  and pg_get_functiondef(p.oid) ilike '%reopen_finished_ticket_service(%'
order by n.nspname, p.proname;
\o
