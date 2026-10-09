-- ==============================================================================
-- Precios "desde", por categoría. (D-326)
-- ==============================================================================
--
-- QUÉ PASA
--
-- El 09-oct el propietario pidió que en la categoría Color de Inspirant (David)
-- los precios digan "Desde": un balayage no cuesta lo mismo en un cabello
-- corto que en uno largo. Decidido por él:
--   * se marca POR CATEGORÍA (no servicio por servicio), en Servicios, con un
--     interruptor que sale al elegir la categoría;
--   * el "Desde" sale donde se ofrece el servicio (su página, la reserva en
--     línea, los cuadritos de Nueva cita, Servicios, Estilistas) y en las
--     líneas de servicio de cada cita. El total y "Cobrar $..." siguen con el
--     número exacto: no se cobra "desde".
--
-- QUÉ HACE ESTA MIGRACIÓN: SOLO AGREGA
--
--   1. `tenants.price_from_categories`: las categorías con precio "desde", en
--      minúsculas y sin espacios a los lados (las categorías son texto libre
--      en cada servicio; se comparan sin mirar mayúsculas, como los cuadritos
--      de D-322).
--   2. `get_price_from_categories(p_branch_id)`: la lista. La pueden pedir
--      todos, también sin sesión, porque se ve en la página pública; resuelve
--      el negocio desde la sede con la misma regla que
--      `public_get_bookable_services` (negocio y sede activos).
--   3. `set_price_from_category(p_branch_id, p_category, p_desde)`: marca o
--      desmarca una categoría. Dueño y administrador, como `update_service`.
--
-- Ninguna función que ya existe se toca: la app pide la lista aparte y
-- escribe "Desde" ella misma. Si la pide antes de que esto esté aplicado, la
-- llamada falla y la app sigue sin "Desde", como hoy.
--
-- Lo prueba el CONTROL 249.
-- ==============================================================================

set client_encoding = 'UTF8';

begin;

alter table public.tenants
  add column price_from_categories text[] not null default '{}';

comment on column public.tenants.price_from_categories is
  'D-326: categorias con precio "desde", en minusculas y sin espacios a los lados. Se cambian con set_price_from_category.';

create or replace function public.get_price_from_categories(p_branch_id uuid)
returns text[]
language plpgsql
stable
security definer
set search_path to 'pg_catalog'
as $$
declare
  v_categorias text[];
begin
  select t.price_from_categories
    into v_categorias
  from public.branches b
  join public.tenants t
    on t.id = b.tenant_id
  where b.id = p_branch_id
    and t.active
    and b.active;

  if not found then
    raise exception 'Este negocio no esta disponible en este momento.';
  end if;

  return v_categorias;
end;
$$;

create or replace function public.set_price_from_category(
  p_branch_id uuid,
  p_category text,
  p_desde boolean
)
returns text[]
language plpgsql
security definer
set search_path to 'pg_catalog'
as $$
declare
  v_tenant_id uuid;
  v_clave text := lower(trim(coalesce(p_category, '')));
  v_resultado text[];
begin
  select r.tenant_id into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner', 'admin'], true
  ) r;

  if v_clave = '' then
    raise exception 'Elige una categoría.';
  end if;

  update public.tenants t
     set price_from_categories = case
           when coalesce(p_desde, false) then (
             select array_agg(distinct x order by x)
             from unnest(array_append(t.price_from_categories, v_clave)) x
           )
           else array_remove(t.price_from_categories, v_clave)
         end
   where t.id = v_tenant_id
  returning t.price_from_categories into v_resultado;

  return coalesce(v_resultado, '{}');
end;
$$;

-- La lista se ve en la página pública: también sin sesión (como
-- get_public_salon_by_slug). Marcar, solo con sesión.
revoke all on function public.get_price_from_categories(uuid) from public;
grant execute on function public.get_price_from_categories(uuid) to anon, authenticated;

revoke all on function public.set_price_from_category(uuid, text, boolean) from public, anon;
grant execute on function public.set_price_from_category(uuid, text, boolean) to authenticated;

commit;
