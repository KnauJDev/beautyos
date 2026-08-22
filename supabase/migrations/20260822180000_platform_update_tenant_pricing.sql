-- ============================================================================
-- MIGRACIÓN: 20260822180000_platform_update_tenant_pricing.sql
-- DESCRIPCIÓN: RPCs para modificar plan, tarifa especial en caliente e
--              historial de suscripciones para el Panel de Plataforma (D-158).
-- ============================================================================

begin;

-- 1. RPC `public.platform_update_tenant_pricing`
-- Permite al dueño de la plataforma ajustar el plan, descuento o precio fijo
-- en COP para cualquier salón en cualquier momento (ej. $30.000, $50.000, etc.).
create or replace function public.platform_update_tenant_pricing(
  p_tenant_id uuid,
  p_plan_code text default 'profesional',
  p_is_founder boolean default false,
  p_price_cop bigint default null,
  p_discount_percent numeric default null,
  p_price_reason text default null
)
returns public.tenant_subscriptions
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_caller_role text := private.beautyos_current_platform_role();
  v_plan_id uuid;
  v_subscription public.tenant_subscriptions%rowtype;
  v_discount_percent numeric(5,2) := p_discount_percent;
  v_price_reason text := nullif(trim(coalesce(p_price_reason, '')), '');
begin
  if v_caller_role is null or v_caller_role != 'platform_owner' then
    raise exception 'No autorizado: solo el dueño de la plataforma puede modificar tarifas y planes.';
  end if;

  select p.id into v_plan_id
  from public.plans p
  where p.code = lower(trim(p_plan_code)) and p.status = 'active';

  if v_plan_id is null then
    raise exception 'El plan especificado (%) no existe o no está activo.', p_plan_code;
  end if;

  if p_is_founder is true then
    v_discount_percent := coalesce(v_discount_percent, 50.00);
    if v_price_reason is null then
      v_price_reason := 'Pionero (50% de por vida)';
    end if;
  end if;

  if (p_price_cop is not null or v_discount_percent is not null) and v_price_reason is null then
    raise exception 'Debes ingresar un motivo para el precio especial o descuento.';
  end if;

  update public.tenant_subscriptions
  set
    plan_id = v_plan_id,
    is_founder = p_is_founder,
    price_cop = p_price_cop,
    discount_percent = v_discount_percent,
    price_reason = v_price_reason,
    updated_at = now()
  where tenant_id = p_tenant_id
  returning * into v_subscription;

  if not found then
    raise exception 'No se encontró suscripción activa para el tenant especificado.';
  end if;

  -- Registrar evento de auditoría
  insert into public.subscription_events (
    tenant_id,
    tenant_subscription_id,
    event_type,
    provider,
    payload,
    created_by
  ) values (
    p_tenant_id,
    v_subscription.id,
    'pricing_updated',
    'platform_admin',
    jsonb_build_object(
      'plan_code', p_plan_code,
      'is_founder', p_is_founder,
      'price_cop', p_price_cop,
      'discount_percent', v_discount_percent,
      'price_reason', v_price_reason
    ),
    auth.uid()
  );

  return v_subscription;
end;
$$;

revoke all on function public.platform_update_tenant_pricing(uuid, text, boolean, bigint, numeric, text) from public, anon;
grant execute on function public.platform_update_tenant_pricing(uuid, text, boolean, bigint, numeric, text) to authenticated;

comment on function public.platform_update_tenant_pricing(uuid, text, boolean, bigint, numeric, text)
  is 'Permite al dueño de plataforma modificar el plan o tarifa especial en COP de un salón en cualquier momento.';

-- 2. RPC `public.platform_get_tenant_subscription_history`
-- Devuelve los eventos y períodos históricos de suscripción de un negocio.
create or replace function public.platform_get_tenant_subscription_history(
  p_tenant_id uuid
)
returns table (
  event_id uuid,
  event_type text,
  provider text,
  plan_code text,
  amount_cop bigint,
  description text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_caller_role text := private.beautyos_current_platform_role();
begin
  if v_caller_role is null then
    raise exception 'No autorizado: se requiere rol de plataforma.';
  end if;

  return query
  select
    se.id as event_id,
    se.event_type,
    se.provider,
    coalesce(se.payload->>'plan_code', se.payload->>'plan', p.code, 'profesional') as plan_code,
    coalesce((se.payload->>'amount_cop')::bigint, (se.payload->>'price_cop')::bigint, ts.price_cop, null) as amount_cop,
    coalesce(se.payload->>'price_reason', se.payload->>'description', se.event_type) as description,
    se.created_at
  from public.subscription_events se
  join public.tenant_subscriptions ts on ts.id = se.tenant_subscription_id
  left join public.plans p on p.id = ts.plan_id
  where se.tenant_id = p_tenant_id
  order by se.created_at desc;
end;
$$;

revoke all on function public.platform_get_tenant_subscription_history(uuid) from public, anon;
grant execute on function public.platform_get_tenant_subscription_history(uuid) to authenticated;

commit;
