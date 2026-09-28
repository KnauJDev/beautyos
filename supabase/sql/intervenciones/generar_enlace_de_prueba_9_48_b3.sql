-- Genera el enlace directo de Juan Carlos Rodriguez (Peluquería Éxito
-- Prueba) para probar en pantalla el Bloque 3 del paso 9.48 (D-287), antes
-- de que exista el botón del salón (Bloque 4).
--
-- QUE HACE. Llama a `get_or_create_client_consent_link` -- la MISMA función
-- que usará el botón del Bloque 4 --, como si la llamara el dueño del salón.
-- Si Juan Carlos ya tiene enlace, devuelve ese mismo; si no, lo crea.
--
-- SÍ ESCRIBE, y a propósito: si el enlace no existía, queda guardado (con
-- COMMIT), igual que quedaría al pulsar el botón. Es permanente y no se
-- borra al probar: es el suyo (D-281).
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\generar_enlace_de_prueba_9_48_b3.sql"
--
-- Deja `_vivo_enlace_de_prueba.txt` en la raiz. No se sube (.gitignore), y
-- el enlace NO se pega en el chat: funciona sin PIN.

\encoding UTF8
\pset format unaligned
\pset tuples_only on

begin;

-- La sesión del dueño de la Peluquería Éxito Prueba, solo dentro de esta
-- transacción.
select set_config(
  'request.jwt.claims',
  json_build_object('sub', m.user_id::text, 'role', 'authenticated')::text,
  true
)
from public.tenant_memberships m
join public.tenants t on t.id = m.tenant_id
where t.slug = 'peluqueria-exito-prueba'
  and m.role = 'tenant_owner'
  and m.active
limit 1;

\o C:/Proyectos/salonymas/_vivo_enlace_de_prueba.txt

select 'https://salonymas.com/?autorizar='
       || public.get_or_create_client_consent_link(c.id)
from public.clients c
join public.tenants t on t.id = c.tenant_id
where t.slug = 'peluqueria-exito-prueba'
  and c.name = 'Juan Carlos Rodriguez'
  and c.active;

\o

commit;
