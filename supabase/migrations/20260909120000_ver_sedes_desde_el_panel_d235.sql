-- ============================================================================
-- MIGRACIÓN: 20260909120000_ver_sedes_desde_el_panel_d235.sql
-- DESCRIPCIÓN: El Panel de Plataforma puede ver el estado de cada sede
--              (D-235, paso 9.35).
--
-- POR QUÉ EXISTE
--
-- El Panel lista negocios, y las sedes salían solo como un número: "Sedes
-- Activas: 2". Tras pagar una sede secundaria, **el panel se veía igual antes
-- y después** — no había forma de saber desde ahí si una sede estaba al día.
--
-- El salón sí lo ve, en Configuración, con `get_branch_subscriptions()`. Pero
-- esa función saca el negocio de `get_my_tenant_id()`: sirve para que un salón
-- vea LO SUYO, no para que el dueño de plataforma mire el de otro.
--
-- Existía `platform_set_branch_subscription` para ESCRIBIR el estado de una
-- sede, y ninguna para LEERLO. Se podía cambiar a ciegas lo que no se podía
-- consultar.
--
-- QUÉ HACE
--
-- `platform_get_tenant_branches(p_tenant_id)`, con la forma de las otras
-- `platform_get_tenant_*` (equipo, tickets, reseñas, fotos): solo rol de
-- plataforma, y `security definer` para saltar el aislamiento por tenant, que
-- es justo lo que el panel necesita y ningún salón debe poder hacer.
--
-- **La regla de `al_dia` se copia palabra por palabra de
-- `get_branch_subscriptions`**, a propósito: si el panel y el salón calcularan
-- "al día" de formas distintas, la conversación de soporte sería imposible.
-- Y no es lo mismo que "activa": una sede puede estar operando y en mora.
-- ============================================================================

begin;

create or replace function public.platform_get_tenant_branches(
  p_tenant_id uuid
)
returns table (
  branch_id uuid,
  branch_name text,
  is_primary boolean,
  branch_active boolean,
  status text,
  al_dia boolean,
  precio_cop bigint,
  motivo_precio text,
  current_period_end timestamptz,
  activated_at timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if private.beautyos_current_platform_role() is null then
    raise exception 'No autorizado: se requiere rol de plataforma.';
  end if;

  return query
  select
    b.id,
    b.name,
    b.is_primary,
    b.active,
    bs.status,
    -- Misma regla que ve el salón en su Configuración (D-190). "Al dia" no es
    -- lo mismo que "activa": una sede puede estar operando y en mora.
    bs.status in ('active', 'trialing'),
    coalesce(bs.price_cop, p.price_cop),
    coalesce(bs.price_reason, 'Precio de lista'),
    bs.current_period_end,
    bs.activated_at
  from public.branches b
  join public.branch_subscriptions bs on bs.branch_id = b.id
  join public.tenant_subscriptions ts on ts.tenant_id = b.tenant_id
  join public.plans p on p.id = ts.plan_id
  where b.tenant_id = p_tenant_id
  order by b.is_primary desc, b.created_at;
end;
$$;

revoke all on function public.platform_get_tenant_branches(uuid) from public, anon;
grant execute on function public.platform_get_tenant_branches(uuid) to authenticated;

comment on function public.platform_get_tenant_branches(uuid) is
  'Estado de pago de las sedes de un negocio, para el dueño de plataforma (D-235). '
  'Hermana de get_branch_subscriptions, que hace lo mismo para el propio salón: '
  'las dos calculan "al_dia" igual a propósito. NO ELIMINAR.';

commit;
