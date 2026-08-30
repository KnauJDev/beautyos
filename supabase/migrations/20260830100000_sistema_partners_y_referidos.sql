-- Paso 7.3 del Plan Maestro (D-173): "Sistema de referidos" -- un salón
-- aliado o una persona externa (amigo, barbero, distribuidor) que trae
-- clientes nuevos y gana una comisión cuando ese salón paga. Cierra la
-- Fase 7 completa (7.1/7.2/7.4 quedaron en D-172).
--
-- Verificado en el esquema real antes de escribir esto (regla 8.1):
-- `beautyos_procesar_evento_epayco` (D-160, migración 20260823150000) es
-- donde nace o se renueva un pago aceptado -- ahí es donde debe generarse
-- la comisión, no en una RPC aparte que dependería de que alguien la
-- llame. Se copia su cuerpo completo sin tocar una sola línea existente
-- (regla 8.10) y se agrega el cálculo al final del camino "pago
-- aceptado", justo después de que el payload del evento ya tiene
-- `monto_cop_recibido` -- así el hook cuenta exactamente los mismos pagos
-- que ya cuenta `platform_list_tenants` para LTV/períodos pagados (D-172).
--
-- Los salones `is_demo` (D-112) NO generan comisión -- mismo criterio que
-- D-172 usa para excluirlos de MRR y recaudo: no son clientes reales.
--
-- `register_tenant` gana `p_referral_code_used` al final de su firma, sin
-- `drop function`: mismo criterio que ya se usó para agregar
-- `p_referral_source` en D-164 (ahí mismo quedó escrito que no hace falta
-- drop para un parámetro nuevo con default al final, siempre que Flutter
-- llame por parámetros nombrados -- y `TenantRegistrationService` lo
-- hace). La firma vieja de 8 parámetros queda sin uso, no se borra.

begin;

-- -----------------------------------------------------------------------
-- 1. Tabla `partners`.
-- -----------------------------------------------------------------------

create table public.partners (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  document_id text,
  referral_code text not null unique,
  phone text,
  whatsapp text,
  email text,
  payout_channel text not null default 'bre_b'
    check (payout_channel in ('bre_b', 'daviplata', 'nequi', 'bancolombia', 'otro')),
  payout_account text not null,
  commission_type text not null default 'percentage'
    check (commission_type in ('fixed_cop', 'percentage')),
  commission_value numeric not null default 15.0 check (commission_value > 0),
  commission_duration text not null default 'first_payment_only'
    check (commission_duration in ('first_payment_only', 'first_n_months', 'recurring_lifetime')),
  duration_months integer check (duration_months is null or duration_months > 0),
  active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  constraint partners_percentage_max_check
    check (commission_type <> 'percentage' or commission_value <= 100),
  constraint partners_duration_months_required_check
    check (commission_duration <> 'first_n_months' or duration_months is not null)
);

create index partners_referral_code_idx on public.partners (referral_code);
create index partners_active_idx on public.partners (active);

alter table public.partners enable row level security;

revoke all on table public.partners from public, anon, authenticated;
grant all on table public.partners to service_role;

comment on table public.partners is
  'Partners y referidos (D-173): salones aliados o personas externas que traen clientes nuevos y ganan comisión. Sin políticas de RLS a propósito: todo acceso pasa por RPC security definer.';
comment on column public.partners.referral_code is
  'Código único del enlace de referido (salonymas.com/?ref=CODIGO). Normalizado en mayúsculas, sin espacios, por las RPC de creación.';
comment on column public.partners.commission_duration is
  'first_payment_only = solo el primer pago del salón; first_n_months = los primeros duration_months pagos; recurring_lifetime = todos los pagos mientras el salón siga pagando.';

-- -----------------------------------------------------------------------
-- 2. Vínculo del salón con su partner.
-- -----------------------------------------------------------------------

alter table public.tenants
  add column if not exists partner_id uuid references public.partners(id) on delete set null,
  add column if not exists referral_code_used text;

create index tenants_partner_id_idx on public.tenants (partner_id) where partner_id is not null;

comment on column public.tenants.partner_id is
  'Partner vinculado a este salón (D-173): quien lo trajo. Nulo = sin partner. Se asigna por ?ref=CODIGO al registrarse o a mano desde el Panel de Plataforma.';
comment on column public.tenants.referral_code_used is
  'El código de referido tal como se usó al registrarse (puede no resolver a ningún partner si el código no existía en ese momento) -- se guarda igual, para trazabilidad.';

-- -----------------------------------------------------------------------
-- 3. Tabla `partner_commissions`.
-- -----------------------------------------------------------------------

create table public.partner_commissions (
  id uuid primary key default gen_random_uuid(),
  partner_id uuid not null references public.partners(id) on delete restrict,
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  subscription_event_id uuid references public.subscription_events(id) on delete set null,
  amount_cop bigint not null check (amount_cop > 0),
  payment_event_amount_cop bigint not null,
  status text not null default 'pending'
    check (status in ('pending', 'paid', 'cancelled')),
  paid_at timestamptz,
  payout_method text,
  payout_reference text,
  payout_notes text,
  created_at timestamptz not null default now()
);

create index partner_commissions_partner_status_idx
  on public.partner_commissions (partner_id, status);
create index partner_commissions_tenant_idx
  on public.partner_commissions (tenant_id);

alter table public.partner_commissions enable row level security;

revoke all on table public.partner_commissions from public, anon, authenticated;
grant all on table public.partner_commissions to service_role;

comment on table public.partner_commissions is
  'Comisiones generadas por cada pago aceptado de un salón vinculado a un partner (D-173). Append-only: liquidar cambia status/paid_at, nunca se borra una fila.';

-- -----------------------------------------------------------------------
-- 4. Hook de comisión dentro de `beautyos_procesar_evento_epayco`.
--
-- Misma firma exacta que la versión de D-160 (9 parámetros): `create or
-- replace` sin drop, es un reemplazo real, no un overload nuevo. Todo el
-- cuerpo se copia sin alterar una línea; el bloque de comisión se agrega
-- justo antes del `return query` final del camino "pago aceptado".
-- -----------------------------------------------------------------------

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
  v_partner_id uuid;
  v_partner public.partners%rowtype;
  v_pagos_previos integer;
  v_ordinal_pago integer;
  v_partner_elegible boolean;
  v_comision_cop bigint;
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

    -- ---------------------------------------------------------------
    -- Comisión de partner (D-173, paso 7.3). Solo si el salón está
    -- vinculado a un partner activo, no es un negocio de prueba del
    -- propietario (D-112), y la regla de duración autoriza ESTE pago.
    -- ---------------------------------------------------------------
    select t.partner_id into v_partner_id
    from public.tenants t
    where t.id = p_tenant_id
      and not t.is_demo;

    if v_partner_id is not null then
      select * into v_partner
      from public.partners
      where id = v_partner_id
        and active = true;

      if v_partner.id is not null then
        select count(*) into v_pagos_previos
        from public.subscription_events se2
        where se2.tenant_id = p_tenant_id
          and se2.provider = 'epayco'
          and se2.payload ? 'monto_cop_recibido'
          and se2.id <> v_event_id;

        v_ordinal_pago := v_pagos_previos + 1;

        v_partner_elegible :=
          (v_partner.commission_duration = 'first_payment_only' and v_ordinal_pago = 1)
          or (v_partner.commission_duration = 'first_n_months'
              and v_ordinal_pago <= coalesce(v_partner.duration_months, 0))
          or (v_partner.commission_duration = 'recurring_lifetime');

        if v_partner_elegible then
          if v_partner.commission_type = 'percentage' then
            v_comision_cop := round(p_amount_cop * v_partner.commission_value / 100.0);
          else
            v_comision_cop := round(v_partner.commission_value);
          end if;

          if v_comision_cop > 0 then
            insert into public.partner_commissions (
              partner_id, tenant_id, subscription_event_id,
              amount_cop, payment_event_amount_cop, status
            ) values (
              v_partner.id, p_tenant_id, v_event_id,
              v_comision_cop, p_amount_cop, 'pending'
            );
          end if;
        end if;
      end if;
    end if;

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
  'Procesa confirmaciones de pago de ePayco con idempotencia estricta, guards de estado (D-125/D-138, y suspension manual del owner), ciclos de 30 dias anclados al primer pago con prorrateo en gracia, plan/precio pactado con precedencia absoluta, y generación automática de comisión de partner (D-173).';

-- -----------------------------------------------------------------------
-- 5. `register_tenant` gana `p_referral_code_used` al final. Sin drop
--    (misma firma vieja de 8 parámetros queda sin uso, mismo criterio que
--    D-164 con `p_referral_source`). Todo lo que ya hacía se conserva.
-- -----------------------------------------------------------------------

create or replace function public.register_tenant(
  p_business_name text,
  p_owner_full_name text,
  p_whatsapp text,
  p_business_type text default null,
  p_city text default null,
  p_estimated_branches integer default 1,
  p_estimated_team_size integer default 1,
  p_referral_source text default null,
  p_referral_code_used text default null
)
returns table (
  tenant_id uuid,
  branch_id uuid,
  status text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_email text;
  v_tenant_id uuid;
  v_branch_id uuid;
  v_tenant_membership_id uuid;
  v_plan_id uuid;
  v_subscription_id uuid;
  v_slug text;
  v_referral_code_clean text;
  v_partner_id uuid;
begin
  if v_user_id is null then
    raise exception 'Se requiere una sesion autenticada para registrar un negocio.';
  end if;

  if exists (
    select 1 from public.tenant_memberships where user_id = v_user_id
  ) then
    raise exception 'Este usuario ya pertenece a un negocio.';
  end if;

  if length(trim(coalesce(p_business_name, ''))) = 0 then
    raise exception 'El nombre del negocio es obligatorio.';
  end if;

  if length(trim(coalesce(p_owner_full_name, ''))) = 0 then
    raise exception 'Tu nombre completo es obligatorio.';
  end if;

  if length(trim(coalesce(p_whatsapp, ''))) = 0 then
    raise exception 'El WhatsApp de contacto es obligatorio.';
  end if;

  select email into v_email from auth.users where id = v_user_id;
  if v_email is null then
    raise exception 'No se encontro un correo asociado a esta sesion.';
  end if;

  select p.id into v_plan_id
  from public.plans p
  where p.code = 'profesional' and p.status = 'active';

  if v_plan_id is null then
    raise exception 'No hay un plan disponible para registrar la solicitud.';
  end if;

  v_slug := private.beautyos_generate_unique_tenant_slug(p_business_name);

  -- Partner (D-173): el código puede no existir (se guarda igual en
  -- referral_code_used para trazabilidad) o pertenecer a un partner
  -- inactivo (no se vincula, pero el código queda registrado).
  v_referral_code_clean := upper(trim(coalesce(p_referral_code_used, '')));
  if length(v_referral_code_clean) = 0 then
    v_referral_code_clean := null;
  end if;

  if v_referral_code_clean is not null then
    select p.id into v_partner_id
    from public.partners p
    where p.referral_code = v_referral_code_clean
      and p.active = true;
  end if;

  insert into public.tenants (
    name,
    slug,
    business_type,
    contact_email,
    whatsapp,
    city,
    estimated_branches,
    estimated_team_size,
    referral_source,
    partner_id,
    referral_code_used,
    active
  ) values (
    trim(p_business_name),
    v_slug,
    nullif(trim(coalesce(p_business_type, '')), ''),
    v_email,
    trim(p_whatsapp),
    nullif(trim(coalesce(p_city, '')), ''),
    greatest(1, coalesce(p_estimated_branches, 1)),
    greatest(1, coalesce(p_estimated_team_size, 1)),
    nullif(trim(coalesce(p_referral_source, '')), ''),
    v_partner_id,
    v_referral_code_clean,
    true
  )
  returning id into v_tenant_id;

  insert into public.branches (tenant_id, name, slug, is_primary)
  values (v_tenant_id, trim(p_business_name), 'principal', true)
  returning id into v_branch_id;

  insert into public.user_profiles (tenant_id, user_id, full_name, role, active)
  values (v_tenant_id, v_user_id, trim(p_owner_full_name), 'owner', true);

  insert into public.tenant_memberships (tenant_id, user_id, role, active, starts_at)
  values (v_tenant_id, v_user_id, 'tenant_owner', true, now())
  returning id into v_tenant_membership_id;

  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (
    v_tenant_id, v_branch_id, v_tenant_membership_id, true, now(), v_user_id
  );

  insert into public.business_hours (
    tenant_id, branch_id, day_of_week, opens_at, closes_at, is_open
  )
  select
    v_tenant_id,
    v_branch_id,
    schedule.day_of_week,
    schedule.opens_at,
    schedule.closes_at,
    schedule.is_open
  from (
    values
      (1, time '08:00', time '20:00', true),
      (2, time '08:00', time '20:00', true),
      (3, time '08:00', time '20:00', true),
      (4, time '08:00', time '20:00', true),
      (5, time '08:00', time '20:00', true),
      (6, time '08:00', time '20:00', true),
      (7, null::time, null::time, false)
  ) as schedule(day_of_week, opens_at, closes_at, is_open);

  insert into public.appointment_policies (tenant_id, branch_id)
  values (v_tenant_id, v_branch_id);

  insert into public.commission_policies (tenant_id)
  values (v_tenant_id);

  -- Filtro de Aceptación (D-125): el negocio nace en estado 'pending'.
  -- La prueba gratis NO arranca aquí (trial_ends_at = NULL).
  insert into public.tenant_subscriptions (
    tenant_id, plan_id, status, trial_ends_at, current_period_start
  ) values (
    v_tenant_id, v_plan_id, 'pending', null, null
  )
  returning id into v_subscription_id;

  insert into public.subscription_events (
    tenant_id, tenant_subscription_id, event_type, payload, created_by
  ) values (
    v_tenant_id,
    v_subscription_id,
    'registration_requested',
    jsonb_build_object(
      'business_name', trim(p_business_name),
      'owner_full_name', trim(p_owner_full_name),
      'city', nullif(trim(coalesce(p_city, '')), ''),
      'business_type', nullif(trim(coalesce(p_business_type, '')), ''),
      'estimated_branches', p_estimated_branches,
      'estimated_team_size', p_estimated_team_size,
      'referral_source', nullif(trim(coalesce(p_referral_source, '')), ''),
      'referral_code_used', v_referral_code_clean,
      'partner_id', v_partner_id
    ),
    v_user_id
  );

  return query select v_tenant_id, v_branch_id, 'pending'::text;
end;
$$;

revoke all on function public.register_tenant(text, text, text, text, text, integer, integer, text, text) from public, anon;
grant execute on function public.register_tenant(text, text, text, text, text, integer, integer, text, text) to authenticated;

comment on function public.register_tenant(text, text, text, text, text, integer, integer, text, text)
  is 'Registra una solicitud de nuevo negocio en estado pendiente de aprobacion (D-125), con su slug público (D-164) y su partner vinculado si llegó con ?ref=CODIGO (D-173).';

-- -----------------------------------------------------------------------
-- 6. `platform_list_tenants()` gana el partner vinculado. Cambia el
--    RETURNS TABLE: DROP requerido. Todo lo que D-172 dejó se conserva
--    línea por línea.
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
  active_overrides_count integer,
  partner_id uuid,
  partner_name text,
  referral_code_used text
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
    coalesce(overrides.cnt, 0),
    t.partner_id,
    partner.full_name,
    t.referral_code_used
  from public.tenants t
  left join public.tenant_subscriptions ts on ts.tenant_id = t.id
  left join public.plans p on p.id = ts.plan_id
  left join public.user_profiles up_owner
    on up_owner.tenant_id = t.id
   and up_owner.role = 'owner'
   and up_owner.active = true
  left join public.partners partner on partner.id = t.partner_id
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
  'Lista de negocios para el Panel de Plataforma: capacidad operativa real (D-162), visión 360° financiera (D-172) y partner vinculado (D-173).';

-- -----------------------------------------------------------------------
-- 7. RPC administrativas de partners (solo plataforma).
-- -----------------------------------------------------------------------

create or replace function public.platform_list_partners()
returns table (
  partner_id uuid,
  full_name text,
  document_id text,
  referral_code text,
  phone text,
  whatsapp text,
  email text,
  payout_channel text,
  payout_account text,
  commission_type text,
  commission_value numeric,
  commission_duration text,
  duration_months integer,
  active boolean,
  notes text,
  created_at timestamptz,
  linked_tenants_count integer,
  pending_commissions_cop bigint,
  paid_commissions_cop bigint
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
    pa.id,
    pa.full_name,
    pa.document_id,
    pa.referral_code,
    pa.phone,
    pa.whatsapp,
    pa.email,
    pa.payout_channel,
    pa.payout_account,
    pa.commission_type,
    pa.commission_value,
    pa.commission_duration,
    pa.duration_months,
    pa.active,
    pa.notes,
    pa.created_at,
    coalesce(tenants_count.cnt, 0),
    coalesce(comisiones.pendientes, 0),
    coalesce(comisiones.pagadas, 0)
  from public.partners pa
  left join lateral (
    select count(*)::integer as cnt
    from public.tenants t
    where t.partner_id = pa.id
  ) tenants_count on true
  left join lateral (
    select
      coalesce(sum(pc.amount_cop) filter (where pc.status = 'pending'), 0)::bigint as pendientes,
      coalesce(sum(pc.amount_cop) filter (where pc.status = 'paid'), 0)::bigint as pagadas
    from public.partner_commissions pc
    where pc.partner_id = pa.id
  ) comisiones on true
  order by pa.active desc, pa.created_at desc;
end;
$$;

revoke all on function public.platform_list_partners() from public, anon, authenticated;
grant execute on function public.platform_list_partners() to authenticated;

comment on function public.platform_list_partners() is
  'Lista de partners con salones vinculados y comisiones pendientes/pagadas, para la pestaña Partners y Referidos del Panel de Plataforma (D-173).';

create or replace function public.platform_create_partner(
  p_full_name text,
  p_referral_code text,
  p_payout_channel text,
  p_payout_account text,
  p_document_id text default null,
  p_phone text default null,
  p_whatsapp text default null,
  p_email text default null,
  p_commission_type text default 'percentage',
  p_commission_value numeric default 15.0,
  p_commission_duration text default 'first_payment_only',
  p_duration_months integer default null,
  p_notes text default null
)
returns table (partner_id uuid)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_code text;
  v_partner_id uuid;
begin
  if private.beautyos_current_platform_role() is null then
    raise exception 'No autorizado: se requiere rol de plataforma.';
  end if;

  if length(trim(coalesce(p_full_name, ''))) = 0 then
    raise exception 'El nombre del partner es obligatorio.';
  end if;

  if length(trim(coalesce(p_payout_account, ''))) = 0 then
    raise exception 'La cuenta o llave de pago es obligatoria.';
  end if;

  if p_payout_channel is not null
     and p_payout_channel not in ('bre_b', 'daviplata', 'nequi', 'bancolombia', 'otro')
  then
    raise exception 'Canal de pago inválido.';
  end if;

  v_code := upper(regexp_replace(trim(coalesce(p_referral_code, '')), '\s+', '', 'g'));
  if v_code !~ '^[A-Z0-9_-]{3,20}$' then
    raise exception 'El código de referido debe tener entre 3 y 20 caracteres, sin espacios (letras, números, guion o guion bajo).';
  end if;

  if exists (select 1 from public.partners p where p.referral_code = v_code) then
    raise exception 'Ese código de referido ya está en uso. Elige otro.';
  end if;

  insert into public.partners (
    full_name, document_id, referral_code, phone, whatsapp, email,
    payout_channel, payout_account, commission_type, commission_value,
    commission_duration, duration_months, notes
  ) values (
    trim(p_full_name),
    nullif(trim(coalesce(p_document_id, '')), ''),
    v_code,
    nullif(trim(coalesce(p_phone, '')), ''),
    nullif(trim(coalesce(p_whatsapp, '')), ''),
    nullif(trim(coalesce(p_email, '')), ''),
    coalesce(p_payout_channel, 'bre_b'),
    trim(p_payout_account),
    coalesce(p_commission_type, 'percentage'),
    coalesce(p_commission_value, 15.0),
    coalesce(p_commission_duration, 'first_payment_only'),
    p_duration_months,
    nullif(trim(coalesce(p_notes, '')), '')
  )
  returning id into v_partner_id;

  return query select v_partner_id;
end;
$$;

revoke all on function public.platform_create_partner(text, text, text, text, text, text, text, text, text, numeric, text, integer, text) from public, anon, authenticated;
grant execute on function public.platform_create_partner(text, text, text, text, text, text, text, text, text, numeric, text, integer, text) to authenticated;

comment on function public.platform_create_partner(text, text, text, text, text, text, text, text, text, numeric, text, integer, text) is
  'Crea un partner desde el Panel de Plataforma (D-173). Requiere rol de plataforma.';

create or replace function public.platform_update_partner(
  p_partner_id uuid,
  p_full_name text,
  p_document_id text,
  p_phone text,
  p_whatsapp text,
  p_email text,
  p_payout_channel text,
  p_payout_account text,
  p_commission_type text,
  p_commission_value numeric,
  p_commission_duration text,
  p_duration_months integer,
  p_active boolean,
  p_notes text
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if private.beautyos_current_platform_role() is null then
    raise exception 'No autorizado: se requiere rol de plataforma.';
  end if;

  if not exists (select 1 from public.partners where id = p_partner_id) then
    raise exception 'Partner no encontrado.';
  end if;

  if length(trim(coalesce(p_full_name, ''))) = 0 then
    raise exception 'El nombre del partner es obligatorio.';
  end if;

  if length(trim(coalesce(p_payout_account, ''))) = 0 then
    raise exception 'La cuenta o llave de pago es obligatoria.';
  end if;

  if p_payout_channel is not null
     and p_payout_channel not in ('bre_b', 'daviplata', 'nequi', 'bancolombia', 'otro')
  then
    raise exception 'Canal de pago inválido.';
  end if;

  update public.partners
  set
    full_name = trim(p_full_name),
    document_id = nullif(trim(coalesce(p_document_id, '')), ''),
    phone = nullif(trim(coalesce(p_phone, '')), ''),
    whatsapp = nullif(trim(coalesce(p_whatsapp, '')), ''),
    email = nullif(trim(coalesce(p_email, '')), ''),
    payout_channel = coalesce(p_payout_channel, payout_channel),
    payout_account = trim(p_payout_account),
    commission_type = coalesce(p_commission_type, commission_type),
    commission_value = coalesce(p_commission_value, commission_value),
    commission_duration = coalesce(p_commission_duration, commission_duration),
    duration_months = p_duration_months,
    active = coalesce(p_active, active),
    notes = nullif(trim(coalesce(p_notes, '')), '')
  where id = p_partner_id;
end;
$$;

revoke all on function public.platform_update_partner(uuid, text, text, text, text, text, text, text, text, numeric, text, integer, boolean, text) from public, anon, authenticated;
grant execute on function public.platform_update_partner(uuid, text, text, text, text, text, text, text, text, numeric, text, integer, boolean, text) to authenticated;

comment on function public.platform_update_partner(uuid, text, text, text, text, text, text, text, text, numeric, text, integer, boolean, text) is
  'Actualiza los datos, canal de pago y esquema de comisión de un partner (D-173). El código de referido no se puede cambiar desde aquí -- evita romper enlaces ya compartidos.';

create or replace function public.platform_get_partner_detail(p_partner_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_partner public.partners%rowtype;
  v_result jsonb;
begin
  if private.beautyos_current_platform_role() is null then
    raise exception 'No autorizado: se requiere rol de plataforma.';
  end if;

  select * into v_partner from public.partners where id = p_partner_id;
  if v_partner.id is null then
    raise exception 'Partner no encontrado.';
  end if;

  select jsonb_build_object(
    'partner_id', v_partner.id,
    'full_name', v_partner.full_name,
    'document_id', v_partner.document_id,
    'referral_code', v_partner.referral_code,
    'phone', v_partner.phone,
    'whatsapp', v_partner.whatsapp,
    'email', v_partner.email,
    'payout_channel', v_partner.payout_channel,
    'payout_account', v_partner.payout_account,
    'commission_type', v_partner.commission_type,
    'commission_value', v_partner.commission_value,
    'commission_duration', v_partner.commission_duration,
    'duration_months', v_partner.duration_months,
    'active', v_partner.active,
    'notes', v_partner.notes,
    'created_at', v_partner.created_at,
    'linked_tenants', coalesce((
      select jsonb_agg(jsonb_build_object(
        'tenant_id', t.id,
        'tenant_name', t.name,
        'subscription_status', ts.status,
        'linked_since', t.created_at
      ) order by t.created_at desc)
      from public.tenants t
      left join public.tenant_subscriptions ts on ts.tenant_id = t.id
      where t.partner_id = v_partner.id
    ), '[]'::jsonb),
    'commissions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'commission_id', pc.id,
        'tenant_id', pc.tenant_id,
        'tenant_name', t.name,
        'amount_cop', pc.amount_cop,
        'payment_event_amount_cop', pc.payment_event_amount_cop,
        'status', pc.status,
        'created_at', pc.created_at,
        'paid_at', pc.paid_at,
        'payout_method', pc.payout_method,
        'payout_reference', pc.payout_reference,
        'payout_notes', pc.payout_notes
      ) order by pc.created_at desc)
      from public.partner_commissions pc
      join public.tenants t on t.id = pc.tenant_id
      where pc.partner_id = v_partner.id
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.platform_get_partner_detail(uuid) from public, anon, authenticated;
grant execute on function public.platform_get_partner_detail(uuid) to authenticated;

comment on function public.platform_get_partner_detail(uuid) is
  'Perfil completo de un partner: datos, salones vinculados y detalle de comisiones (D-173).';

create or replace function public.platform_set_tenant_partner(
  p_tenant_id uuid,
  p_partner_id uuid
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_name text;
  v_subscription_id uuid;
  v_previous_partner_id uuid;
begin
  if private.beautyos_current_platform_role() is distinct from 'platform_owner' then
    raise exception 'No autorizado: solo platform_owner puede asignar un partner.';
  end if;

  select name, partner_id into v_tenant_name, v_previous_partner_id
  from public.tenants
  where id = p_tenant_id;

  if v_tenant_name is null then
    raise exception 'Negocio no encontrado.';
  end if;

  if p_partner_id is not null and not exists (
    select 1 from public.partners where id = p_partner_id
  ) then
    raise exception 'Partner no encontrado.';
  end if;

  update public.tenants
  set partner_id = p_partner_id
  where id = p_tenant_id;

  select id into v_subscription_id
  from public.tenant_subscriptions
  where tenant_id = p_tenant_id;

  if v_subscription_id is not null then
    insert into public.subscription_events (
      tenant_id, tenant_subscription_id, event_type, payload, created_by
    ) values (
      p_tenant_id,
      v_subscription_id,
      case when p_partner_id is null then 'partner_unassigned' else 'partner_assigned' end,
      jsonb_build_object('previous_partner_id', v_previous_partner_id, 'new_partner_id', p_partner_id),
      auth.uid()
    );
  end if;
end;
$$;

revoke all on function public.platform_set_tenant_partner(uuid, uuid) from public, anon, authenticated;
grant execute on function public.platform_set_tenant_partner(uuid, uuid) to authenticated;

comment on function public.platform_set_tenant_partner(uuid, uuid) is
  'Vincula, cambia o quita (p_partner_id null) el partner de un salón, desde la Ficha Nivel 3 del Panel de Plataforma. Solo platform_owner (D-173).';

create or replace function public.platform_settle_partner_commissions(
  p_partner_id uuid,
  p_payout_method text,
  p_payout_reference text,
  p_notes text default null
)
returns table (settled_count integer, settled_amount_cop bigint)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_count integer;
  v_amount bigint;
begin
  if private.beautyos_current_platform_role() is distinct from 'platform_owner' then
    raise exception 'No autorizado: solo platform_owner puede liquidar comisiones.';
  end if;

  if not exists (select 1 from public.partners where id = p_partner_id) then
    raise exception 'Partner no encontrado.';
  end if;

  if length(trim(coalesce(p_payout_method, ''))) = 0 then
    raise exception 'El medio de pago es obligatorio para registrar la liquidación.';
  end if;

  select count(*), coalesce(sum(amount_cop), 0)
    into v_count, v_amount
  from public.partner_commissions
  where partner_id = p_partner_id
    and status = 'pending';

  if v_count = 0 then
    raise exception 'Este partner no tiene comisiones pendientes por liquidar.';
  end if;

  update public.partner_commissions
  set
    status = 'paid',
    paid_at = now(),
    payout_method = trim(p_payout_method),
    payout_reference = nullif(trim(coalesce(p_payout_reference, '')), ''),
    payout_notes = nullif(trim(coalesce(p_notes, '')), '')
  where partner_id = p_partner_id
    and status = 'pending';

  return query select v_count, v_amount;
end;
$$;

revoke all on function public.platform_settle_partner_commissions(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.platform_settle_partner_commissions(uuid, text, text, text) to authenticated;

comment on function public.platform_settle_partner_commissions(uuid, text, text, text) is
  'Liquida TODAS las comisiones pendientes de un partner de una sola vez, con medio de pago y referencia bancaria. Solo platform_owner (D-173).';

create or replace function public.platform_get_partners_summary()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_active_partners integer;
  v_linked_tenants integer;
  v_pending_cop bigint;
  v_paid_cop bigint;
begin
  if private.beautyos_current_platform_role() is null then
    raise exception 'No autorizado: se requiere rol de plataforma.';
  end if;

  select count(*) into v_active_partners from public.partners where active = true;

  select count(distinct t.id) into v_linked_tenants
  from public.tenants t
  where t.partner_id is not null;

  select
    coalesce(sum(amount_cop) filter (where status = 'pending'), 0),
    coalesce(sum(amount_cop) filter (where status = 'paid'), 0)
    into v_pending_cop, v_paid_cop
  from public.partner_commissions;

  return jsonb_build_object(
    'active_partners_count', v_active_partners,
    'linked_tenants_count', v_linked_tenants,
    'pending_commissions_cop', v_pending_cop,
    'paid_commissions_cop', v_paid_cop
  );
end;
$$;

revoke all on function public.platform_get_partners_summary() from public, anon, authenticated;
grant execute on function public.platform_get_partners_summary() to authenticated;

comment on function public.platform_get_partners_summary() is
  'KPIs de la pestaña Partners y Referidos: partners activos, salones vinculados, comisiones por pagar y pagadas (D-173).';

-- -----------------------------------------------------------------------
-- 8. RPC pública de auto-registro de partner (rol anon).
-- -----------------------------------------------------------------------

create or replace function public.public_register_partner(
  p_full_name text,
  p_document_id text,
  p_referral_code text,
  p_phone text,
  p_whatsapp text,
  p_email text,
  p_payout_channel text,
  p_payout_account text
)
returns table (partner_id uuid, referral_code text)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_code text;
  v_partner_id uuid;
begin
  if length(trim(coalesce(p_full_name, ''))) = 0 then
    raise exception 'Tu nombre completo es obligatorio.';
  end if;

  if length(trim(coalesce(p_whatsapp, ''))) = 0 then
    raise exception 'Tu WhatsApp es obligatorio.';
  end if;

  if length(trim(coalesce(p_payout_account, ''))) = 0 then
    raise exception 'Tu llave o cuenta de pago es obligatoria.';
  end if;

  if p_payout_channel is null or p_payout_channel not in ('bre_b', 'daviplata', 'nequi', 'bancolombia', 'otro') then
    raise exception 'Canal de pago inválido.';
  end if;

  v_code := upper(regexp_replace(trim(coalesce(p_referral_code, '')), '\s+', '', 'g'));
  if v_code !~ '^[A-Z0-9_-]{3,20}$' then
    raise exception 'El código deseado debe tener entre 3 y 20 caracteres, sin espacios (letras, números, guion o guion bajo).';
  end if;

  if exists (select 1 from public.partners p where p.referral_code = v_code) then
    raise exception 'Ese código ya está en uso. Elige otro.';
  end if;

  insert into public.partners (
    full_name, document_id, referral_code, phone, whatsapp, email,
    payout_channel, payout_account,
    commission_type, commission_value, commission_duration
  ) values (
    trim(p_full_name),
    nullif(trim(coalesce(p_document_id, '')), ''),
    v_code,
    nullif(trim(coalesce(p_phone, '')), ''),
    trim(p_whatsapp),
    nullif(trim(coalesce(p_email, '')), ''),
    p_payout_channel,
    trim(p_payout_account),
    'percentage',
    15.0,
    'first_payment_only'
  )
  returning id into v_partner_id;

  return query select v_partner_id, v_code;
end;
$$;

revoke all on function public.public_register_partner(text, text, text, text, text, text, text, text) from public, authenticated;
grant execute on function public.public_register_partner(text, text, text, text, text, text, text, text) to anon, authenticated;

comment on function public.public_register_partner(text, text, text, text, text, text, text, text) is
  'Auto-registro público de un partner desde salonymas.com/partners (D-173): comisión estándar 15% al primer pago, activo de inmediato. Rol anon.';

commit;
