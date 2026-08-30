-- Fase 7, pasos 7.1, 7.2 y 7.4 del Plan Maestro (D-172): panel de dueño de
-- la plataforma con cabecera ejecutiva (MRR, recaudo histórico, salud de
-- cartera, conversión), visión 360° financiera de cada salón (antigüedad,
-- períodos pagados, LTV, mora con monto y días) y gestión visual de
-- excepciones de límites (`tenant_feature_overrides`, que ya existía desde
-- la fundación del 22-jul pero sin RPC ni pantalla).
--
-- Verificado en el esquema real antes de escribir esto (regla 1, apartado
-- 8): `subscription_events` NO tiene columna de monto. El cobro real de un
-- pago de ePayco que sí activó/renovó la suscripción vive en
-- `payload->>'monto_cop_recibido'` (lo escribe `beautyos_procesar_evento_
-- epayco` desde D-160, migración 20260823150000). Es el mismo campo que ya
-- usa `platform_get_tenant_subscription_history` (D-161) para mostrar el
-- historial de cada salón: MRR, recaudo histórico y LTV cuentan aquí
-- exactamente lo mismo que el propietario ya ve ahí, no una cifra paralela.
--
-- `debt_status`: un salón `suspended` puede serlo por decisión manual del
-- propietario (evento `suspended_by_platform`, sin relación con dinero) o
-- por vencimiento automático del período de gracia (evento
-- `auto_suspended_grace_expired`, sí es mora). Solo el segundo caso cuenta
-- como `en_mora` -- si se contaran los dos, un salón que el propietario
-- pausó por otro motivo aparecería con badge de cobranza y botón de
-- WhatsApp de cobro de forma incorrecta.

begin;

-- -----------------------------------------------------------------------
-- 1. Extender `public.platform_list_tenants` con la visión 360° financiera
--    de cada salón (paso 7.1). Cambia el RETURNS TABLE: DROP requerido.
--    Todo lo que ya devolvía se conserva línea por línea (regla 10).
-- -----------------------------------------------------------------------

drop function if exists public.platform_list_tenants();

create or replace function public.platform_list_tenants()
returns table (
  tenant_id uuid,
  tenant_name text,
  contact_name text,
  business_type text,
  city text,
  estimated_branches integer,
  estimated_team_size integer,
  referral_source text,
  rejection_reason text,
  contact_email text,
  contact_phone text,
  whatsapp text,
  instagram text,
  facebook text,
  real_branches_count integer,
  real_team_count integer,
  team_breakdown text,
  tenant_active boolean,
  is_demo boolean,
  plan_code text,
  subscription_status text,
  is_founder boolean,
  price_cop bigint,
  discount_percent numeric,
  trial_ends_at timestamptz,
  current_period_end timestamptz,
  grace_ends_at timestamptz,
  created_at timestamptz,
  paid_periods_count integer,
  total_paid_cop bigint,
  effective_monthly_price bigint,
  debt_status text,
  debt_amount_cop bigint,
  active_overrides_count integer
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
    t.id,
    t.name,
    up_owner.full_name,
    t.business_type,
    t.city,
    t.estimated_branches,
    t.estimated_team_size,
    t.referral_source,
    t.rejection_reason,
    t.contact_email,
    t.contact_phone,
    t.whatsapp,
    t.instagram,
    t.facebook,
    coalesce(branches_count.cnt, 0),
    coalesce(team.real_team_count, 0),
    coalesce(team.team_breakdown, 'Sin colaboradores activos'),
    t.active,
    t.is_demo,
    p.code,
    ts.status,
    ts.is_founder,
    ts.price_cop,
    ts.discount_percent,
    ts.trial_ends_at,
    ts.current_period_end,
    ts.grace_ends_at,
    t.created_at,
    coalesce(pagos.cnt, 0),
    coalesce(pagos.total_cop, 0),
    coalesce(precio.precio_cop, 0),
    case
      when ts.status = 'trialing' then 'en_prueba'
      when ts.status in ('past_due', 'grace') then 'en_mora'
      when ts.status = 'suspended' and last_susp.event_type = 'auto_suspended_grace_expired' then 'en_mora'
      else 'al_dia'
    end,
    case
      when ts.status in ('past_due', 'grace') then coalesce(precio.precio_cop, ts.price_cop, 0)
      when ts.status = 'suspended' and last_susp.event_type = 'auto_suspended_grace_expired'
        then coalesce(precio.precio_cop, ts.price_cop, 0)
      else 0
    end,
    coalesce(overrides.cnt, 0)
  from public.tenants t
  left join public.tenant_subscriptions ts on ts.tenant_id = t.id
  left join public.plans p on p.id = ts.plan_id
  left join public.user_profiles up_owner
    on up_owner.tenant_id = t.id
   and up_owner.role = 'owner'
   and up_owner.active = true
  left join lateral (
    select count(*)::integer as cnt
    from public.branches b
    where b.tenant_id = t.id
      and b.active = true
  ) branches_count on true
  left join lateral (
    select
      sum(cnt)::integer as real_team_count,
      string_agg(cnt || ' ' || label, ', ' order by ord) as team_breakdown
    from (
      select
        case up2.role
          when 'owner' then 1
          when 'admin' then 2
          when 'assistant' then 3
          when 'stylist' then 4
        end as ord,
        count(*) as cnt,
        case up2.role
          when 'owner' then (case when count(*) = 1 then 'dueño' else 'dueños' end)
          when 'admin' then (case when count(*) = 1 then 'admin' else 'admins' end)
          when 'assistant' then (case when count(*) = 1 then 'asistente' else 'asistentes' end)
          when 'stylist' then (case when count(*) = 1 then 'estilista' else 'estilistas' end)
        end as label
      from public.user_profiles up2
      where up2.tenant_id = t.id
        and up2.active = true
        and up2.role in ('owner', 'admin', 'assistant', 'stylist')
      group by up2.role
    ) roles
  ) team on true
  left join lateral (
    select
      count(*)::integer as cnt,
      coalesce(sum((se.payload->>'monto_cop_recibido')::bigint), 0)::bigint as total_cop
    from public.subscription_events se
    where se.tenant_id = t.id
      and se.provider = 'epayco'
      and se.payload ? 'monto_cop_recibido'
  ) pagos on true
  left join lateral (
    select pe.precio_cop
    from private.beautyos_precio_efectivo(t.id) pe
  ) precio on true
  left join lateral (
    select se.event_type
    from public.subscription_events se
    where se.tenant_id = t.id
      and se.event_type in ('suspended_by_platform', 'auto_suspended_grace_expired')
    order by se.created_at desc
    limit 1
  ) last_susp on true
  left join lateral (
    select count(*)::integer as cnt
    from public.tenant_feature_overrides tfo
    where tfo.tenant_id = t.id
      and tfo.starts_at <= now()
      and (tfo.ends_at is null or tfo.ends_at > now())
  ) overrides on true
  order by
    case when ts.status = 'pending' then 0 else 1 end,
    t.is_demo,
    t.created_at desc;
end;
$$;

revoke all on function public.platform_list_tenants() from public, anon, authenticated;
grant execute on function public.platform_list_tenants() to authenticated;

comment on function public.platform_list_tenants() is
  'Lista de negocios para el Panel de Plataforma, con capacidad operativa real (D-162) y visión 360° financiera: períodos pagados, LTV, precio pactado efectivo y estado de cartera (D-172).';

-- -----------------------------------------------------------------------
-- 2. `public.platform_get_saas_metrics()` -- cabecera ejecutiva del SaaS
--    (paso 7.4). Lectura: cualquier rol de plataforma.
-- -----------------------------------------------------------------------

create or replace function public.platform_get_saas_metrics()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_mrr_cop bigint;
  v_total_collected_cop bigint;
  v_active_count integer;
  v_trialing_count integer;
  v_past_due_count integer;
  v_cancelled_count integer;
  v_ever_trialed_count integer;
  v_ever_converted_count integer;
  v_conversion_rate numeric;
begin
  if private.beautyos_current_platform_role() is null then
    raise exception 'No autorizado: se requiere rol de plataforma.';
  end if;

  -- MRR: suma del precio efectivo pactado (private.beautyos_precio_efectivo)
  -- de cada salón ACTIVO que no es de prueba del propietario (D-112).
  select coalesce(sum(pe.precio_cop), 0)
    into v_mrr_cop
  from public.tenant_subscriptions ts
  join public.tenants t on t.id = ts.tenant_id
  left join lateral (
    select precio_cop from private.beautyos_precio_efectivo(ts.tenant_id)
  ) pe on true
  where ts.status = 'active'
    and not t.is_demo;

  -- Recaudo histórico: mismo criterio que el historial por tenant (D-161):
  -- solo pagos de ePayco que sí activaron/renovaron una suscripción.
  select coalesce(sum((se.payload->>'monto_cop_recibido')::bigint), 0)
    into v_total_collected_cop
  from public.subscription_events se
  join public.tenants t on t.id = se.tenant_id
  where se.provider = 'epayco'
    and se.payload ? 'monto_cop_recibido'
    and not t.is_demo;

  select
    count(*) filter (where ts.status = 'active'),
    count(*) filter (where ts.status = 'trialing'),
    count(*) filter (where ts.status in ('past_due', 'grace')),
    count(*) filter (where ts.status = 'cancelled')
    into v_active_count, v_trialing_count, v_past_due_count, v_cancelled_count
  from public.tenant_subscriptions ts
  join public.tenants t on t.id = ts.tenant_id
  where not t.is_demo;

  -- Conversión prueba -> activo: de los salones que alguna vez tuvieron
  -- reloj de prueba (trial_ends_at no nulo), cuántos llegaron a pagar al
  -- menos una vez.
  select count(*)
    into v_ever_trialed_count
  from public.tenant_subscriptions ts
  join public.tenants t on t.id = ts.tenant_id
  where ts.trial_ends_at is not null
    and not t.is_demo;

  select count(distinct se.tenant_id)
    into v_ever_converted_count
  from public.subscription_events se
  join public.tenant_subscriptions ts on ts.tenant_id = se.tenant_id
  join public.tenants t on t.id = se.tenant_id
  where se.provider = 'epayco'
    and se.payload ? 'monto_cop_recibido'
    and ts.trial_ends_at is not null
    and not t.is_demo;

  if v_ever_trialed_count > 0 then
    v_conversion_rate := round((v_ever_converted_count::numeric / v_ever_trialed_count::numeric) * 100, 1);
  else
    v_conversion_rate := 0;
  end if;

  return jsonb_build_object(
    'mrr_cop', v_mrr_cop,
    'total_collected_cop', v_total_collected_cop,
    'active_count', v_active_count,
    'trialing_count', v_trialing_count,
    'past_due_count', v_past_due_count,
    'cancelled_count', v_cancelled_count,
    'conversion_rate_percent', v_conversion_rate
  );
end;
$$;

revoke all on function public.platform_get_saas_metrics() from public, anon, authenticated;
grant execute on function public.platform_get_saas_metrics() to authenticated;

comment on function public.platform_get_saas_metrics() is
  'Cabecera ejecutiva del Panel de Plataforma: MRR, recaudo histórico, conteo de salones por salud y tasa de conversión prueba->activo (D-172).';

-- -----------------------------------------------------------------------
-- 3. Gestión visual de `tenant_feature_overrides` (paso 7.2). La tabla y
--    `private.beautyos_resolve_entitlement` ya existían desde la fundación
--    (22-jul); solo faltaban las RPC y la pantalla.
-- -----------------------------------------------------------------------

-- Relajar la restricción para permitir ends_at >= starts_at (al revocar una
-- excepción en la misma marca de tiempo o fecha que su inicio):
alter table public.tenant_feature_overrides
  drop constraint if exists tenant_feature_overrides_validity_check,
  add constraint tenant_feature_overrides_validity_check
    check (ends_at is null or ends_at >= starts_at);

create or replace function public.platform_get_tenant_feature_overrides(
  p_tenant_id uuid
)
returns table (
  override_id uuid,
  feature_key text,
  feature_name text,
  feature_description text,
  enabled boolean,
  limit_value integer,
  reason text,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz,
  is_active boolean
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if private.beautyos_current_platform_role() is null then
    raise exception 'No autorizado: se requiere rol de plataforma.';
  end if;

  if p_tenant_id is null then
    raise exception 'tenant_id es obligatorio.';
  end if;

  return query
  select
    tfo.id,
    f.key,
    f.name,
    f.description,
    tfo.enabled,
    tfo.limit_value,
    tfo.reason,
    tfo.starts_at,
    tfo.ends_at,
    tfo.created_at,
    (tfo.starts_at <= now() and (tfo.ends_at is null or tfo.ends_at > now())) as is_active
  from public.tenant_feature_overrides tfo
  join public.features f on f.id = tfo.feature_id
  where tfo.tenant_id = p_tenant_id
  order by tfo.created_at desc;
end;
$$;

revoke all on function public.platform_get_tenant_feature_overrides(uuid) from public, anon, authenticated;
grant execute on function public.platform_get_tenant_feature_overrides(uuid) to authenticated;

comment on function public.platform_get_tenant_feature_overrides(uuid) is
  'Excepciones de límites/funcionalidades de un salón, activas e históricas, para la Ficha Nivel 3 del Panel de Plataforma (D-172).';

create or replace function public.platform_set_tenant_feature_override(
  p_tenant_id uuid,
  p_feature_key text,
  p_enabled boolean,
  p_limit_value integer,
  p_reason text,
  p_ends_at timestamptz default null
)
returns table (override_id uuid)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_feature_id uuid;
  v_subscription_id uuid;
  v_tenant_name text;
  v_override_id uuid;
begin
  if private.beautyos_current_platform_role() is distinct from 'platform_owner' then
    raise exception 'No autorizado: solo platform_owner puede conceder excepciones.';
  end if;

  if p_tenant_id is null or p_feature_key is null or p_enabled is null then
    raise exception 'tenant_id, feature_key y enabled son obligatorios.';
  end if;

  if p_reason is null or length(trim(p_reason)) = 0 then
    raise exception 'El motivo es obligatorio para conceder una excepción.';
  end if;

  if p_limit_value is not null and p_limit_value < 0 then
    raise exception 'El límite no puede ser negativo.';
  end if;

  if p_ends_at is not null and p_ends_at <= now() then
    raise exception 'La fecha de expiración debe ser futura.';
  end if;

  select id into v_feature_id from public.features where key = p_feature_key;
  if v_feature_id is null then
    raise exception 'Funcionalidad desconocida: %.', p_feature_key;
  end if;

  select name into v_tenant_name from public.tenants where id = p_tenant_id;
  if v_tenant_name is null then
    raise exception 'Negocio no encontrado.';
  end if;

  select id into v_subscription_id
  from public.tenant_subscriptions
  where tenant_id = p_tenant_id;

  if v_subscription_id is null then
    raise exception 'El negocio no tiene una suscripción registrada.';
  end if;

  insert into public.tenant_feature_overrides (
    tenant_id, feature_id, enabled, limit_value, reason, ends_at, created_by
  ) values (
    p_tenant_id, v_feature_id, p_enabled, p_limit_value, trim(p_reason), p_ends_at, auth.uid()
  )
  returning id into v_override_id;

  insert into public.subscription_events (
    tenant_id, tenant_subscription_id, event_type, payload, created_by
  ) values (
    p_tenant_id,
    v_subscription_id,
    'feature_override_granted',
    jsonb_build_object(
      'override_id', v_override_id,
      'feature_key', p_feature_key,
      'enabled', p_enabled,
      'limit_value', p_limit_value,
      'reason', trim(p_reason),
      'ends_at', p_ends_at
    ),
    auth.uid()
  );

  return query select v_override_id;
end;
$$;

revoke all on function public.platform_set_tenant_feature_override(uuid, text, boolean, integer, text, timestamptz) from public, anon, authenticated;
grant execute on function public.platform_set_tenant_feature_override(uuid, text, boolean, integer, text, timestamptz) to authenticated;

comment on function public.platform_set_tenant_feature_override(uuid, text, boolean, integer, text, timestamptz) is
  'Concede una excepción de límite/funcionalidad a un salón, con motivo obligatorio y expiración opcional. Solo platform_owner (D-172).';

create or replace function public.platform_delete_tenant_feature_override(
  p_override_id uuid
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_override public.tenant_feature_overrides%rowtype;
  v_subscription_id uuid;
begin
  if private.beautyos_current_platform_role() is distinct from 'platform_owner' then
    raise exception 'No autorizado: solo platform_owner puede revocar excepciones.';
  end if;

  if p_override_id is null then
    raise exception 'override_id es obligatorio.';
  end if;

  select * into v_override
  from public.tenant_feature_overrides
  where id = p_override_id;

  if v_override.id is null then
    raise exception 'Excepción no encontrada.';
  end if;

  -- Se finaliza (ends_at = now()), no se borra: preserva el rastro de que
  -- existió, mismo criterio de auditoría append-only del resto del proyecto.
  -- Si el override empezó en la misma transacción o en el futuro (starts_at >= now()),
  -- ajustamos starts_at 1 milisegundo atrás para que ends_at > starts_at
  -- se cumpla siempre sin ambigüedad temporal ni violaciones de constraint.
  update public.tenant_feature_overrides
  set starts_at = case
                    when starts_at >= now() then now() - interval '1 millisecond'
                    else starts_at
                  end,
      ends_at = least(coalesce(ends_at, now()), now())
  where id = p_override_id;

  select id into v_subscription_id
  from public.tenant_subscriptions
  where tenant_id = v_override.tenant_id;

  if v_subscription_id is not null then
    insert into public.subscription_events (
      tenant_id, tenant_subscription_id, event_type, payload, created_by
    ) values (
      v_override.tenant_id,
      v_subscription_id,
      'feature_override_revoked',
      jsonb_build_object('override_id', p_override_id),
      auth.uid()
    );
  end if;
end;
$$;

revoke all on function public.platform_delete_tenant_feature_override(uuid) from public, anon, authenticated;
grant execute on function public.platform_delete_tenant_feature_override(uuid) to authenticated;

comment on function public.platform_delete_tenant_feature_override(uuid) is
  'Revoca (finaliza) una excepción de límite/funcionalidad vigente. Solo platform_owner (D-172).';

commit;
