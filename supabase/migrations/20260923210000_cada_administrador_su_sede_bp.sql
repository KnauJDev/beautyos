-- ==============================================================================
-- HALLAZGO BP: cada administrador ve y paga solo su sede
-- Decision del propietario del 23-sep (D-268, precisada ese dia: D-273).
-- ==============================================================================
--
-- LO QUE DECIDIO
--
--   * El DUENO ve todas sus sedes y puede pagar cualquiera. **Como hoy.**
--   * Cada ADMINISTRADOR ve y paga **solo las sedes que tiene asignadas**, *"para
--     que no vaya a generar pagos a otras sedes desde la de el"*.
--
-- LO QUE PASABA
--
-- `get_branch_subscriptions` devolvia TODAS las sedes a cualquier dueno o
-- administrador, con sus precios; y `create-epayco-session` solo comprobaba que
-- la sede fuera del negocio, no que quien paga tuviera acceso a ella.
--
-- COMO SE HACE
--
-- Una sola regla, `public.beautyos_puedo_pagar_sede(sede)`:
--   * dueno (`tenant_owner`) activo del negocio de esa sede -> si;
--   * administrador (`admin`) activo con la sede asignada -> si;
--   * cualquier otro -> no.
-- Las condiciones de membresia se COPIARON de `get_my_branch_context_v2` (la
-- del selector de sede, texto vivo del 23-sep), para que el selector y "Tus
-- sedes" digan lo mismo. Diferencia a proposito: el dueno puede pagar tambien
-- una sede cerrada, porque hoy la ve en "Tus sedes" y quitarsela no se pidio.
--
-- La usan dos sitios:
--   1. `get_branch_subscriptions` (texto vivo + una condicion): el
--      administrador solo recibe sus sedes.
--   2. `create-epayco-session` (Edge Function): antes de abrir ePayco, pregunta
--      y se niega si la respuesta es no. **Se publica DESPUES de aplicar esta
--      migracion**: si se publica antes, no encuentra la funcion y se niega a
--      todo el mundo.
--
-- COMO SE APLICA (lo aplica el propietario, regla 16)
--
--   1. Esta migracion con scripts\aplicar_sql.ps1
--   2. El control: supabase\sql\227_test_cada_administrador_su_sede.sql
--   3. Despues, publicar create-epayco-session.
-- ==============================================================================

set client_encoding = 'UTF8';

begin;

-- ---------------------------------------------------------------------------
-- 1. La regla, en un solo sitio
-- ---------------------------------------------------------------------------

create or replace function public.beautyos_puedo_pagar_sede(p_branch_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select exists (
    select 1
    from public.tenant_memberships tm
    join public.branches b
      on b.tenant_id = tm.tenant_id
     and b.id = p_branch_id
    where tm.user_id = auth.uid()
      and tm.active
      and tm.starts_at <= now()
      and (tm.ends_at is null or tm.ends_at > now())
      and (
        tm.role = 'tenant_owner'
        or (
          tm.role = 'admin'
          and exists (
            select 1
            from public.branch_memberships bm
            where bm.tenant_id = tm.tenant_id
              and bm.branch_id = b.id
              and bm.tenant_membership_id = tm.id
              and bm.active
              and bm.starts_at <= now()
              and (bm.ends_at is null or bm.ends_at > now())
          )
        )
      )
  );
$$;

revoke all on function public.beautyos_puedo_pagar_sede(uuid) from public, anon;
grant execute on function public.beautyos_puedo_pagar_sede(uuid) to authenticated, service_role;

comment on function public.beautyos_puedo_pagar_sede(uuid) is
  'D-273 (hallazgo BP): si quien llama puede ver y pagar ESTA sede. El dueno, cualquiera de su negocio; '
  'el administrador, solo las que tiene asignadas. Condiciones copiadas de get_my_branch_context_v2. '
  'La usan get_branch_subscriptions y create-epayco-session. NO ELIMINAR.';

-- ---------------------------------------------------------------------------
-- 2. "Tus sedes": el administrador recibe solo las suyas (texto vivo + 1)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_branch_subscriptions()
 RETURNS TABLE(branch_id uuid, branch_name text, is_primary boolean, branch_active boolean, status text, al_dia boolean, precio_cop bigint, motivo_precio text, current_period_end timestamp with time zone, activated_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_tenant_id uuid;
begin
  v_tenant_id := public.get_my_tenant_id();

  if v_tenant_id is null then
    raise exception 'No existe una membresia activa para este usuario.';
  end if;

  if not public.is_owner_or_admin() then
    raise exception 'No autorizado. Solo owner o admin ve el estado de pago de las sedes.';
  end if;

  return query
  select
    b.id,
    b.name,
    b.is_primary,
    b.active,
    bs.status,
    -- "Al dia" es lo que la interfaz necesita saber, y no es lo mismo que
    -- "activa": una sede puede estar activa operativamente y en mora.
    bs.status in ('active', 'trialing'),
    coalesce(bs.price_cop, p.price_cop),
    coalesce(bs.price_reason, 'Precio de lista'),
    bs.current_period_end,
    bs.activated_at
  from public.branches b
  join public.branch_subscriptions bs on bs.branch_id = b.id
  join public.tenant_subscriptions ts on ts.tenant_id = b.tenant_id
  join public.plans p on p.id = ts.plan_id
  where b.tenant_id = v_tenant_id
    -- D-273 (hallazgo BP): el dueno sigue viendo todas; cada administrador,
    -- solo las sedes que tiene asignadas. La regla vive en una sola funcion,
    -- la misma que usa el cobro para dejar pagar o no.
    and public.beautyos_puedo_pagar_sede(b.id)
  order by b.is_primary desc, b.created_at;
end;
$function$;

commit;
