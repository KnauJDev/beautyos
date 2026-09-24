-- ==============================================================================
-- Pregunta del propietario, 24-sep: al borrar Naguara de Uñas, ¿qué pasa con
-- las cuentas de auth.users de su equipo (elboga000..006@gmail.com)?
--
-- POR QUE: platform_delete_demo_tenant (D-246) deliberadamente NO toca
-- auth.users -- solo borra tenant_memberships y las demas filas con
-- tenant_id. Antes de borrar Naguara hay que saber, con datos reales y no
-- con una suposicion, que les queda a esas cuentas: si pueden volver a
-- entrar a algun lado, si quedan huerfanas, y si ese correo se puede volver
-- a usar despues para registrar o unirse a otro negocio.
--
-- NO MODIFICA NADA. Solo lecturas.
-- ==============================================================================

\echo '--- 1. Las cuentas de auth.users de Naguara: existen, cuando se crearon, cuando entraron por ultima vez ---'
select
  u.id,
  u.email,
  u.created_at,
  u.last_sign_in_at,
  u.email_confirmed_at is not null as correo_confirmado
from auth.users u
where u.email in (
  'elboga002@gmail.com', 'elboga000@gmail.com', 'elboga004@gmail.com',
  'elboga005@gmail.com', 'elboga006@gmail.com'
)
order by u.email;

\echo '--- 2. Cada una de esas cuentas, en TODOS los negocios donde tiene membresia (no solo Naguara) ---'
select
  u.email,
  tm.tenant_id,
  t.name as negocio,
  t.is_demo,
  tm.role,
  tm.active,
  tm.stylist_id
from auth.users u
join public.tenant_memberships tm on tm.user_id = u.id
join public.tenants t on t.id = tm.tenant_id
where u.email in (
  'elboga002@gmail.com', 'elboga000@gmail.com', 'elboga004@gmail.com',
  'elboga005@gmail.com', 'elboga006@gmail.com'
)
order by u.email, t.name;

\echo '--- 4. Si existe alguna restriccion de unicidad sobre el correo, fuera de auth.users ---'
select conname, conrelid::regclass as tabla, pg_get_constraintdef(oid) as definicion
from pg_constraint
where pg_get_constraintdef(oid) ilike '%email%'
  and connamespace = 'public'::regnamespace
order by conrelid::regclass::text;

\echo '--- 5. get_my_tenant_id y la logica de login: como resuelve el tenant de un usuario sin membresia activa ---'
select pg_get_functiondef(p.oid)
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'get_my_tenant_id';
