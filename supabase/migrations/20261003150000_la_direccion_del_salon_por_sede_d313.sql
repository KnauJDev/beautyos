-- ==============================================================================
-- D-313: la dirección pública del salón, a partir de una sede.
-- ==============================================================================
--
-- QUÉ PASABA
--
-- D-313 decidió que el enlace que se comparte para reservar sea la dirección
-- con el nombre del salón (`salonymas.com/<nombre>`) en la sede principal.
-- La tarjeta de la estilista intentaba leer esa dirección directamente de la
-- tabla `tenants`, contando con la política `tenant_isolation_select` del
-- 16-ago. **La lectura del 03-oct
-- (`intervenciones/verificar_enlace_con_nombre_d313.sql`) mostró que no se
-- puede:** la política consulta `tenant_memberships`, y nadie con sesión
-- tiene permiso de leer esa tabla directamente (*"permission denied for table
-- tenant_memberships"*). Es correcto que sea así. La app caía al enlace de
-- código, que funciona, pero no era lo decidido.
--
-- Fue un supuesto sin leer lo vivo (regla 10): se confió en una migración
-- del 16-ago sin comprobar el estado de hoy. La lectura lo cazó antes de que
-- llegara a un cliente.
--
-- QUÉ SE HACE
--
-- Una función NUEVA, pública, que dada una sede devuelve la dirección de su
-- salón. **No abre nada:** la dirección es la de la página pública del salón,
-- que cualquiera puede visitar, y el código de la sede ya viaja en el enlace
-- público de reserva (`?reservar=<sede>`), cuya página enseña además el
-- nombre del negocio, la dirección física y el WhatsApp
-- (`public_get_branch_booking_info`). Devuelve solo un texto.
--
-- Las condiciones son las mismas con que la reserva pública acepta una sede
-- (`public_create_booking`, texto vivo leído el 02-oct): negocio activo y
-- sede activa. Si no se cumplen, o el salón no tiene dirección, devuelve
-- NULL y la app comparte el enlace de código.
--
-- Se concede a `anon` y a `authenticated` desde el principio: es la lección
-- de CE (D-307), donde lo público concedido solo a `anon` falló a quien tenía
-- la sesión abierta.
--
-- No reescribe ninguna función existente.
--
-- COMO SE APLICA (lo aplica el propietario, regla 16)
--
--   1. Esta migración con scripts\aplicar_sql.ps1
--   2. El control: supabase\sql\241_test_la_direccion_del_salon_por_sede.sql
--   3. En pantalla: en la app de la estilista, "Copiar enlace" debe dar
--      salonymas.com/<nombre-del-salon>.
-- ==============================================================================

set client_encoding = 'UTF8';

begin;

create or replace function public.public_get_salon_slug_by_branch(p_branch_id uuid)
returns text
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select nullif(trim(t.slug), '')
  from public.branches b
  join public.tenants t
    on t.id = b.tenant_id
  where b.id = p_branch_id
    and t.active
    and b.active;
$$;

revoke all on function public.public_get_salon_slug_by_branch(uuid) from public;
grant execute on function public.public_get_salon_slug_by_branch(uuid) to anon, authenticated;

comment on function public.public_get_salon_slug_by_branch(uuid) is
  'D-313: la direccion publica del salon (tenants.slug) a partir de una sede activa de un negocio activo. NULL si no. Para el enlace con el nombre del salon.';

commit;
