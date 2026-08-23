-- ============================================================================
-- MIGRACIÓN: 20260823150000_ciclo_facturacion_ancla_y_plan_pactado.sql
-- DESCRIPCIÓN: Ciclos de facturación de 30 días "comerciales" anclados al
--              primer pago, prorrateo de pagos tardíos dentro de gracia, y
--              plan/precio pactado por el owner con precedencia absoluta
--              sobre lo que el tenant elija en el checkout.
--
-- REGLAS (confirmadas con el propietario):
--   1. Primera activación: mes completo desde el momento del pago. Esa fecha
--      queda como ancla implícita — no se guarda en columna aparte, porque
--      "current_period_end + 30 días" ya preserva la ancla sin necesitarla
--      (nada en el código pone current_period_end en null tras la primera
--      activación).
--   2. Renovación anticipada (paga mientras el período vigente no ha
--      terminado): el nuevo período se acumula al final del vigente, precio
--      completo. La ancla nunca se corre.
--   3. Pago tardío dentro de gracia (status in ('past_due','grace') — se usa
--      el estado persistido, NO now() en vivo, para no cobrar de más si una
--      sesión de pago queda abierta justo cuando cruza el límite de gracia):
--      se cobra proporcional a los días que faltan hasta la próxima fecha
--      ancla (current_period_end + 30 días), redondeando hacia arriba. Sin el
--      piso de $10.000: es un prorrateo legítimo, puede ser menor.
--   4. Pago con status = 'suspended': mes completo desde ahora, se reancla.
--      EXCEPCIÓN: si la suspensión fue manual por la plataforma
--      (subscription_events.event_type = 'suspended_by_platform', no por
--      vencimiento de gracia), el pago se registra pero NO reactiva —
--      requiere revisión del propietario, igual que pending/rejected.
--   5. Precio/plan pactado: si tenant_subscriptions.price_reason no es nulo
--      (lo exige el CHECK constraint siempre que haya price_cop o
--      discount_percent), el plan también es pactado — se ignora
--      p_plan_code por completo, no solo para el precio (corrige un hueco:
--      antes un pionero con SOLO descuento, sin price_cop, no quedaba
--      cubierto por el candado).
--   6. Bug corregido de paso: plan_id nunca se actualizaba al pagar. Un
--      tenant sin precio pactado que paga un plan distinto al asignado ahora
--      sí termina con plan_id actualizado al que pagó.
--   7. Bug corregido de paso: platform_reactivate_tenant no restauraba
--      current_period_end, así que un tenant reactivado a mano después de
--      vencer su gracia seguía bloqueado para agendar aunque su estado
--      dijera 'active'.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- 1. Función pura de cálculo (fuente de verdad), dos formas.
-- ----------------------------------------------------------------------------

-- Versión con la fila ya bloqueada (FOR UPDATE) — cero IO extra, y es
-- imposible que la ruta de validación diverja de una segunda consulta.
create or replace function private.beautyos_calcular_cargo_epayco(
  p_sub public.tenant_subscriptions,
  p_plan_code text default null
)
returns table (
  monto_cop bigint,
  periodo_inicio timestamptz,
  periodo_fin timestamptz,
  motivo text,
  plan_id_resuelto uuid
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_plan_code_clean text;
  v_base_price bigint;
  v_full_price bigint;
  v_plan_id_resuelto uuid;
  v_dias_restantes numeric;
begin
  if p_sub.price_reason is not null then
    -- Pactado por el owner (precio fijo y/o solo descuento): el plan tambien
    -- es pactado, se ignora p_plan_code por completo.
    v_plan_id_resuelto := p_sub.plan_id;
    if p_sub.price_cop is not null and p_sub.price_cop > 0 then
      v_base_price := p_sub.price_cop;
    else
      select pl.price_cop into v_base_price from public.plans pl where pl.id = p_sub.plan_id;
    end if;
  else
    -- Sin pactado: el tenant elige libremente en el checkout.
    v_plan_code_clean := nullif(lower(trim(coalesce(p_plan_code, ''))), '');

    select pl.id, pl.price_cop into v_plan_id_resuelto, v_base_price
    from public.plans pl
    where pl.code = coalesce(v_plan_code_clean, (select p2.code from public.plans p2 where p2.id = p_sub.plan_id))
      and pl.status = 'active';

    if v_plan_id_resuelto is null then
      v_plan_id_resuelto := p_sub.plan_id;
      select pl.price_cop into v_base_price from public.plans pl where pl.id = p_sub.plan_id;
    end if;
  end if;

  v_full_price := coalesce(v_base_price, 0);
  if p_sub.price_reason is not null
     and p_sub.discount_percent is not null
     and (p_sub.discount_ends_at is null or p_sub.discount_ends_at > now()) then
    v_full_price := round(v_full_price * (1 - p_sub.discount_percent / 100.0));
  end if;

  plan_id_resuelto := v_plan_id_resuelto;

  if p_sub.current_period_end is null then
    -- Primera activacion.
    periodo_inicio := now();
    periodo_fin := now() + interval '30 days';
    monto_cop := v_full_price;
    motivo := 'primera_activacion';
  elsif now() <= p_sub.current_period_end then
    -- Renovacion anticipada: se acumula al final del periodo vigente.
    periodo_inicio := p_sub.current_period_end;
    periodo_fin := p_sub.current_period_end + interval '30 days';
    monto_cop := v_full_price;
    motivo := 'renovacion_anticipada';
  elsif p_sub.status in ('past_due', 'grace') then
    -- Pago tardio dentro de gracia: prorratea hacia la proxima ancla.
    periodo_fin := p_sub.current_period_end + interval '30 days';
    periodo_inicio := now();
    v_dias_restantes := ceil(extract(epoch from (periodo_fin - now())) / 86400.0);
    monto_cop := ceil(v_full_price * v_dias_restantes / 30.0);
    motivo := 'pago_tardio_prorrateado';
  else
    -- status = 'suspended' (gracia vencida o admin), o 'active'/'cancelled'
    -- con current_period_end vencido por otra via: mes completo, reancla.
    periodo_inicio := now();
    periodo_fin := now() + interval '30 days';
    monto_cop := v_full_price;
    motivo := 'reactivacion_post_suspension';
  end if;

  return next;
end;
$$;

-- Conveniencia para el caller sin bloqueo (create-epayco-session): solo lee,
-- nunca escribe, para cotizar el monto antes de abrir la sesion de ePayco.
create or replace function private.beautyos_calcular_cargo_epayco(
  p_tenant_id uuid,
  p_plan_code text default null
)
returns table (
  monto_cop bigint,
  periodo_inicio timestamptz,
  periodo_fin timestamptz,
  motivo text,
  plan_id_resuelto uuid
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_sub public.tenant_subscriptions%rowtype;
begin
  select * into v_sub from public.tenant_subscriptions where tenant_id = p_tenant_id;

  if v_sub.id is null then
    return;
  end if;

  return query select * from private.beautyos_calcular_cargo_epayco(v_sub, p_plan_code);
end;
$$;

revoke all on function private.beautyos_calcular_cargo_epayco(public.tenant_subscriptions, text) from public, anon, authenticated;
grant execute on function private.beautyos_calcular_cargo_epayco(public.tenant_subscriptions, text) to service_role;

revoke all on function private.beautyos_calcular_cargo_epayco(uuid, text) from public, anon, authenticated;
grant execute on function private.beautyos_calcular_cargo_epayco(uuid, text) to service_role;

comment on function private.beautyos_calcular_cargo_epayco(public.tenant_subscriptions, text) is
  'Fuente de verdad: calcula el monto y el periodo que corresponde cobrar ahora mismo a un tenant, segun ciclos de 30 dias anclados al primer pago (primera activacion, renovacion anticipada, pago tardio prorrateado, o reactivacion con reancla), respetando el plan/precio pactado por el owner si existe.';
comment on function private.beautyos_calcular_cargo_epayco(uuid, text) is
  'Envoltorio de conveniencia sin bloqueo de fila, para cotizar el cargo antes de abrir la sesion de ePayco (create-epayco-session).';


-- ----------------------------------------------------------------------------
-- 2. Reescritura de beautyos_procesar_evento_epayco.
-- ----------------------------------------------------------------------------

drop function if exists private.beautyos_procesar_evento_epayco(uuid, text, text, text, text, bigint, text, jsonb, text);

create or replace function private.beautyos_procesar_evento_epayco(
  p_tenant_id uuid,
  p_x_ref_payco text,
  p_transaction_id text,
  p_transaction_state text,
  p_cod_transaction_state text,
  p_amount_cop bigint,
  p_currency_code text,
  p_payload jsonb,
  p_plan_code text default null
)
returns table (
  processed boolean,
  previous_status text,
  new_status text,
  message text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_sub public.tenant_subscriptions%rowtype;
  v_event_id uuid;
  v_state_clean text;
  v_cod_clean text;
  v_is_accepted boolean;
  v_is_rejected boolean;
  v_is_reversed boolean;
  v_ultimo_evento_susp text;
  v_calc record;
  v_min_required bigint;
begin
  if p_tenant_id is null or p_x_ref_payco is null or length(trim(p_x_ref_payco)) = 0 then
    raise exception 'Parametros invalidos: tenant_id y x_ref_payco son obligatorios.';
  end if;

  -- 1. Obtener la suscripcion actual del tenant, con bloqueo.
  select * into v_sub
  from public.tenant_subscriptions
  where tenant_id = p_tenant_id
  for update;

  if v_sub.id is null then
    raise exception 'No existe suscripcion para el tenant especificado (%).', p_tenant_id;
  end if;

  -- 2. Idempotencia criptografica.
  insert into public.subscription_events (
    tenant_id,
    tenant_subscription_id,
    event_type,
    provider,
    provider_event_id,
    payload
  ) values (
    p_tenant_id,
    v_sub.id,
    'epayco_' || lower(coalesce(trim(p_transaction_state), 'unknown')),
    'epayco',
    trim(p_x_ref_payco),
    coalesce(p_payload, '{}'::jsonb)
  )
  on conflict (provider, provider_event_id) do nothing
  returning id into v_event_id;

  if v_event_id is null then
    return query select false, v_sub.status, v_sub.status, 'Evento ePayco duplicado ignorado por idempotencia.'::text;
    return;
  end if;

  v_state_clean := lower(coalesce(trim(p_transaction_state), ''));
  v_cod_clean := coalesce(trim(p_cod_transaction_state), '');

  v_is_accepted := v_state_clean in ('aceptada', 'aprobada', 'approved', 'success') or v_cod_clean = '1';
  v_is_rejected := v_state_clean in ('rechazada', 'fallida', 'rejected', 'failed') or v_cod_clean in ('2', '4');
  v_is_reversed := v_state_clean in ('reversada', 'reversed') or v_cod_clean = '6';

  -- GUARD DE NEGOCIO: "Nadie entra solo" (D-125 / D-138).
  if v_sub.status in ('pending', 'rejected') then
    return query select true, v_sub.status, v_sub.status, 'Pago registrado. El negocio esta en revision/rechazado y requiere aprobacion del platform_owner.'::text;
    return;
  end if;

  -- GUARD: suspension manual del owner (no por vencimiento de gracia) bloquea
  -- reactivacion automatica por pago, requiere que el propietario la revise.
  if v_sub.status = 'suspended' then
    select se.event_type into v_ultimo_evento_susp
    from public.subscription_events se
    where se.tenant_subscription_id = v_sub.id
      and se.event_type in ('suspended_by_platform', 'auto_suspended_grace_expired')
    order by se.created_at desc
    limit 1;

    if v_ultimo_evento_susp = 'suspended_by_platform' then
      return query select true, v_sub.status, v_sub.status, 'Pago registrado. El negocio fue suspendido manualmente por la plataforma y requiere revision del propietario antes de reactivar.'::text;
      return;
    end if;
  end if;

  if v_is_accepted then
    select * into v_calc from private.beautyos_calcular_cargo_epayco(v_sub, p_plan_code);

    if p_amount_cop is null or p_amount_cop <= 0 then
      return query select true, v_sub.status, v_sub.status, 'Monto de pago invalido.'::text;
      return;
    end if;

    if v_calc.motivo = 'pago_tardio_prorrateado' then
      v_min_required := v_calc.monto_cop;
    else
      v_min_required := greatest(10000, v_calc.monto_cop);
    end if;

    if p_amount_cop < v_min_required then
      return query select true, v_sub.status, v_sub.status,
        format(
          'Pago de $%s COP menor al monto requerido ($%s COP, %s). Suscripcion no activada.',
          p_amount_cop, v_min_required, v_calc.motivo
        )::text;
      return;
    end if;

    update public.tenant_subscriptions
    set
      status = 'active',
      provider = 'epayco',
      provider_reference = coalesce(p_transaction_id, provider_reference, p_x_ref_payco),
      plan_id = v_calc.plan_id_resuelto,
      current_period_start = v_calc.periodo_inicio,
      current_period_end = v_calc.periodo_fin,
      grace_ends_at = null,
      suspended_at = null,
      cancel_at = null,
      cancelled_at = null,
      updated_at = now()
    where id = v_sub.id;

    update public.subscription_events
    set payload = payload || jsonb_build_object(
      'motivo', v_calc.motivo,
      'monto_cop_esperado', v_calc.monto_cop,
      'monto_cop_recibido', p_amount_cop,
      'periodo_inicio', v_calc.periodo_inicio,
      'periodo_fin', v_calc.periodo_fin
    )
    where id = v_event_id;

    return query select true, v_sub.status, 'active'::text,
      format('Pago aceptado (%s). Suscripcion activada/renovada.', v_calc.motivo)::text;
    return;

  elsif (v_is_rejected or v_is_reversed) and v_sub.status = 'active' then
    update public.tenant_subscriptions
    set
      status = 'past_due',
      grace_ends_at = coalesce(grace_ends_at, now() + interval '5 days'),
      updated_at = now()
    where id = v_sub.id;

    return query select true, v_sub.status, 'past_due'::text, 'Pago rechazado/reversado. Suscripcion en estado past_due con 5 dias de gracia.'::text;
    return;

  else
    return query select true, v_sub.status, v_sub.status, 'Evento de pago ePayco registrado sin cambio de estado.'::text;
    return;
  end if;
end;
$$;

revoke all on function private.beautyos_procesar_evento_epayco(uuid, text, text, text, text, bigint, text, jsonb, text) from public, anon, authenticated;
grant execute on function private.beautyos_procesar_evento_epayco(uuid, text, text, text, text, bigint, text, jsonb, text) to service_role;

comment on function private.beautyos_procesar_evento_epayco(uuid, text, text, text, text, bigint, text, jsonb, text) is
  'Procesa confirmaciones de pago de ePayco con idempotencia estricta, guards de estado (D-125/D-138, y suspension manual del owner), ciclos de 30 dias anclados al primer pago con prorrateo en gracia, y plan/precio pactado con precedencia absoluta.';


-- ----------------------------------------------------------------------------
-- 3. Corrige platform_reactivate_tenant: hoy no restauraba current_period_end,
--    asi que un tenant reactivado a mano seguia bloqueado para agendar.
-- ----------------------------------------------------------------------------

create or replace function public.platform_reactivate_tenant(
  p_tenant_id uuid,
  p_reason text
)
returns public.tenant_subscriptions
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_result public.tenant_subscriptions%rowtype;
begin
  if private.beautyos_current_platform_role() is distinct from 'platform_owner' then
    raise exception 'No autorizado: solo platform_owner puede reactivar un tenant.';
  end if;

  if length(trim(coalesce(p_reason, ''))) = 0 then
    raise exception 'El motivo es obligatorio para reactivar un tenant.';
  end if;

  update public.tenant_subscriptions
     set status = 'active',
         current_period_start = now(),
         current_period_end = now() + interval '30 days',
         grace_ends_at = null,
         suspended_at = null,
         updated_at = now()
   where tenant_id = p_tenant_id
     and status = 'suspended'
  returning * into v_result;

  if v_result.id is null then
    raise exception 'No se encontro una suscripcion suspendida para ese tenant.';
  end if;

  insert into public.subscription_events (
    tenant_id, tenant_subscription_id, event_type, payload, created_by
  ) values (
    p_tenant_id, v_result.id, 'reactivated_by_platform',
    jsonb_build_object('reason', p_reason), auth.uid()
  );

  return v_result;
end;
$$;

comment on function public.platform_reactivate_tenant(uuid, text) is
  'Reactiva manualmente un tenant suspendido: ahora tambien restaura un mes completo desde el momento de la reactivacion, para que el estado active realmente otorgue acceso (antes solo cambiaba status, dejando current_period_end vencido).';


-- ----------------------------------------------------------------------------
-- 4. get_my_tenant_subscription_status: expone has_pactado_price y price_reason
--    para que el checkout de Flutter sepa cuando debe bloquear el selector de plan.
-- ----------------------------------------------------------------------------

drop function if exists public.get_my_tenant_subscription_status();

create or replace function public.get_my_tenant_subscription_status()
returns table (
  tenant_id uuid,
  tenant_name text,
  subscription_status text,
  plan_code text,
  plan_name text,
  trial_ends_at timestamptz,
  current_period_start timestamptz,
  current_period_end timestamptz,
  grace_ends_at timestamptz,
  is_founder boolean,
  price_cop bigint,
  discount_percent numeric,
  rejection_reason text,
  created_at timestamptz,
  has_pactado_price boolean,
  price_reason text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_tenant_id uuid;
  v_precio_efectivo bigint;
begin
  if v_user_id is null then
    raise exception 'Se requiere una sesion autenticada.';
  end if;

  select tm.tenant_id into v_tenant_id
  from public.tenant_memberships tm
  where tm.user_id = v_user_id
    and tm.active
  limit 1;

  if v_tenant_id is null then
    return;
  end if;

  select pe.precio_cop into v_precio_efectivo
  from private.beautyos_precio_efectivo(v_tenant_id) pe;

  return query
  select
    t.id as tenant_id,
    t.name as tenant_name,
    ts.status as subscription_status,
    p.code as plan_code,
    p.name as plan_name,
    ts.trial_ends_at,
    ts.current_period_start,
    ts.current_period_end,
    ts.grace_ends_at,
    ts.is_founder,
    coalesce(v_precio_efectivo, ts.price_cop, p.price_cop) as price_cop,
    ts.discount_percent,
    t.rejection_reason,
    t.created_at,
    (ts.price_reason is not null) as has_pactado_price,
    ts.price_reason
  from public.tenants t
  join public.tenant_subscriptions ts on ts.tenant_id = t.id
  join public.plans p on p.id = ts.plan_id
  where t.id = v_tenant_id;
end;
$$;

revoke all on function public.get_my_tenant_subscription_status() from public, anon;
grant execute on function public.get_my_tenant_subscription_status() to authenticated;

comment on function public.get_my_tenant_subscription_status() is
  'Consulta el estado de suscripcion, fechas de periodo, gracia, precio efectivo y si el plan/precio esta pactado por el owner (has_pactado_price) del usuario autenticado.';

commit;
