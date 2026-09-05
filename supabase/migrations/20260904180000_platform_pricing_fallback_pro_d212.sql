-- ============================================================================
-- MIGRACIÓN: 20260904180000_platform_pricing_fallback_pro_d212.sql
-- DESCRIPCIÓN: RPC platform_update_tenant_pricing con fallback a 'pro' y
--              tolerancia a códigos de plan heredados (D-212, Paso 8.35).
-- ============================================================================

begin;

create or replace function public.platform_update_tenant_pricing(
  p_tenant_id uuid,
  p_plan_code text default 'pro',
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
  v_normalized_plan text := lower(trim(coalesce(p_plan_code, 'pro')));
begin
  if v_caller_role is null or v_caller_role != 'platform_owner' then
    raise exception 'No autorizado: solo el dueño de la plataforma puede modificar tarifas y planes.';
  end if;

  -- Mapeo de códigos legacy (D-188): los planes anteriores retirados
  -- (profesional, basico, business) resuelven al plan único activo 'pro'.
  if v_normalized_plan in ('profesional', 'basico', 'business', 'pro', '') then
    v_normalized_plan := 'pro';
  end if;

  -- Buscar plan activo
  select p.id into v_plan_id
  from public.plans p
  where p.code = v_normalized_plan and p.status = 'active';

  -- Fallback de seguridad: si no existe el código específico, asignar el plan 'pro' activo
  if v_plan_id is null then
    select p.id into v_plan_id
    from public.plans p
    where p.code = 'pro' and p.status = 'active'
    limit 1;
  end if;

  if v_plan_id is null then
    raise exception 'No hay un plan activo disponible en la plataforma.';
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
    raise exception 'No se encontró suscripción para el tenant especificado.';
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
      'plan_code', v_normalized_plan,
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
  is 'Permite al dueño de plataforma modificar el plan o tarifa especial en COP de un salón en cualquier momento, con fallback automático al plan pro (D-212).';

commit;
