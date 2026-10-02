-- Lee que paso con el codigo del estilista de David (hallazgo CF). NO MODIFICA NADA.
--
-- POR QUE. El 02-oct, con el primer cliente real (David Rojas) y su equipo en
-- persona, el estilista invitado escribio el codigo que le llego por correo y la
-- app le dijo "Ese codigo ya vencio o no es valido", casi de inmediato.
-- Supabase da ESE MISMO error para un codigo vencido, uno equivocado y uno
-- viejo: si se pidio un segundo codigo, el primero deja de servir. Antes de
-- arreglar nada hay que saber cual de las tres fue (regla 25a).
--
-- Que lee, de las cuentas creadas desde el 01-oct (los correos salen
-- ENMASCARADOS: tres letras y el dominio, porque son de personas reales):
--   1. Cuando se creo cada cuenta, cuando se envio la confirmacion y si llego
--      a confirmarse.
--   2. El registro de auditoria de Auth desde el 01-oct: cada vez que se pidio
--      un codigo, se registro alguien o se intento entrar, con su hora.
--   3. Cuantos codigos de un solo uso tiene vivos cada cuenta, y de que tipo.
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\verificar_codigo_vencido_del_estilista_cf.sql"
--
-- Deja `_vivo_cf_codigo.sql` en la raiz. No se sube (.gitignore).

\encoding UTF8
\pset format unaligned
\pset tuples_only on

\o C:/Proyectos/salonymas/_vivo_cf_codigo.sql

select '-- ===== 1. CUENTAS CREADAS DESDE EL 01-OCT (hora de Colombia)';
select '-- ' || left(split_part(u.email, '@', 1), 3) || '***@' || split_part(u.email, '@', 2)
       || ' | creada ' || to_char(u.created_at at time zone 'America/Bogota', 'DD-MM HH24:MI:SS')
       || ' | confirmacion enviada ' || coalesce(to_char(u.confirmation_sent_at at time zone 'America/Bogota', 'DD-MM HH24:MI:SS'), '-')
       || ' | confirmada ' || coalesce(to_char(u.email_confirmed_at at time zone 'America/Bogota', 'DD-MM HH24:MI:SS'), 'NO')
       || ' | ultimo ingreso ' || coalesce(to_char(u.last_sign_in_at at time zone 'America/Bogota', 'DD-MM HH24:MI:SS'), '-')
from auth.users u
where u.created_at >= '2026-10-01'
order by u.created_at;

select '-- ===== 2. AUDITORIA DE AUTH DESDE EL 01-OCT';
select '-- ' || to_char(a.created_at at time zone 'America/Bogota', 'DD-MM HH24:MI:SS')
       || ' | ' || coalesce(a.payload->>'action', '?')
       || ' | ' || coalesce(left(split_part(a.payload->>'actor_username', '@', 1), 3) || '***@'
                            || split_part(a.payload->>'actor_username', '@', 2), '-')
       || ' | ' || coalesce(a.payload->>'log_type', '')
from auth.audit_log_entries a
where a.created_at >= '2026-10-01'
order by a.created_at;

select '-- ===== 3. CODIGOS DE UN SOLO USO VIVOS (va al final: si esta tabla no existiera, las dos partes de arriba ya habrian salido)';
select '-- ' || left(split_part(u.email, '@', 1), 3) || '***@' || split_part(u.email, '@', 2)
       || ' | ' || t.token_type::text
       || ' | creado ' || to_char(t.created_at at time zone 'America/Bogota', 'DD-MM HH24:MI:SS')
from auth.one_time_tokens t
join auth.users u on u.id = t.user_id
where u.created_at >= '2026-10-01'
order by u.email, t.created_at;

\o

\echo 'Listo: _vivo_cf_codigo.sql'
