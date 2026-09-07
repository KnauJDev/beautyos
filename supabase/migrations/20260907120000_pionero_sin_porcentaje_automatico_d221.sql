-- ============================================================================
-- MIGRACIÓN: 20260907120000_pionero_sin_porcentaje_automatico_d221.sql
-- DESCRIPCIÓN: El pionero deja de llevar un 50% automático (D-221, paso 9.28).
--
-- POR QUÉ EXISTE
--
-- D-188 y D-189 abolieron el "50% de pionero": dejó de ser un porcentaje y
-- pasó a ser **precio pactado, uno a uno**. Pero la migración de D-212
-- (20260904180000) volvió a escribirlo dentro de la RPC:
--
--     if p_is_founder is true then
--       v_discount_percent := coalesce(v_discount_percent, 50.00);
--
-- Consecuencia real: al marcar la casilla "Pionero" para un salón con precio
-- pactado en 80.000, la base le clavaba 75.000 (el 50% de la lista de 150.000)
-- y pisaba el acuerdo. Encontrado el 07-sep en la auditoría de Antigravity
-- (D-220) y verificado línea por línea antes de tocar nada.
--
-- QUÉ CAMBIA
--
-- `is_founder` vuelve a ser lo que D-188 decidió: **una etiqueta**, no una
-- regla de precio. No calcula, no rellena y no supone.
--
-- Y falla cerrado: marcar a alguien como pionero **sin decir cuánto paga** ya
-- no cuela un precio inventado — la función se detiene y lo pide. Es el mismo
-- principio del hallazgo W: en el camino del dinero, adivinar es peor que
-- fallar a la vista.
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

  select p.id into v_plan_id
  from public.plans p
  where p.code = v_normalized_plan and p.status = 'active';

  -- Fallback de plan (D-212): si el código no existe, se usa el 'pro' activo.
  -- Esto SÍ se conserva: resolver un plan retirado a su sustituto no inventa
  -- dinero, solo apunta al único plan que queda.
  if v_plan_id is null then
    select p.id into v_plan_id
    from public.plans p
    where p.code = 'pro' and p.status = 'active'
    limit 1;
  end if;

  if v_plan_id is null then
    raise exception 'No hay un plan activo disponible en la plataforma.';
  end if;

  -- D-221: el pionero es una etiqueta, no un porcentaje.
  -- Antes aquí se asignaba 50.00 en silencio (D-212). Ahora, si se marca
  -- pionero, hay que decir cuánto paga: precio pactado o descuento explícito.
  if p_is_founder is true
     and p_price_cop is null
     and v_discount_percent is null then
    raise exception 'Un negocio pionero necesita su precio pactado o su descuento explícito. La tarifa de pionero se negocia una a una (D-188, D-189); no hay un porcentaje por defecto.';
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
is 'Tarifa y plan de un negocio, solo para el dueño de plataforma. is_founder es una ETIQUETA, no un porcentaje: la tarifa de pionero se pacta una a una (D-188, D-189, D-221). Marcar pionero sin precio ni descuento explícito falla a propósito.';

commit;
