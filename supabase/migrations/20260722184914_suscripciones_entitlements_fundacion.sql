-- BeautyOS - Fundacion de suscripciones y entitlements.
--
-- Implementa el modelo de datos y la resolucion de funcionalidades definidos
-- en docs/01_arquitectura/SUSCRIPCION_Y_ENTITLEMENTS.md (diseno aprobado,
-- sin construir hasta ahora). Alcance de este bloque:
--
-- 1. Tablas: plans, features, plan_features, tenant_subscriptions,
--    subscription_events, tenant_feature_overrides. RLS activa, sin
--    politicas directas: todo acceso pasa por RPC (mismo patron que
--    tenant_memberships/branch_memberships).
-- 2. private.beautyos_resolve_entitlement(tenant_id, feature_key): helper
--    interno que resuelve segun el orden del diseno (suscripcion operativa
--    -> plan vigente -> feature del plan -> override valido). El calculo de
--    "consumo actual" (paso 5 del diseno) queda a cargo de cada RPC que
--    conozca que contar; este helper no lo implementa de forma generica
--    para no inventar logica de conteo que todavia no existe.
-- 3. RPC publicas de lectura: get_my_entitlements(),
--    get_my_tenant_subscription(), list_public_plans() (esta ultima es
--    publica/anonima, pensada para una futura pagina de precios).
-- 4. Semillas: los 3 planes (Basico/Business/Profesional) y las 5
--    funcionalidades ya nombradas en el diseno, con la matriz exacta de la
--    seccion 2 del documento. Los precios quedan NULL ("por definir": no es
--    una decision tecnica, la fija el propietario) y los limites numericos
--    (sedes, usuarios, mensajes, almacenamiento) quedan NULL (ilimitado)
--    porque el diseno no fijo cifras concretas todavia.
-- 5. Los tenants existentes reciben una suscripcion `active` al plan
--    Profesional sin fecha de fin, para no perder acceso al agregar
--    entitlements mas adelante (son cuentas de desarrollo, no clientes).
--
-- Fuera de alcance (bloques aparte): pasarela de pago, webhooks, alta de
-- tenant self-serve, panel de plataforma para gestionar suscripciones.

begin;

create table public.plans (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  version integer not null default 1,
  name text not null,
  billing_period text not null default 'monthly'
    check (billing_period in ('monthly', 'yearly')),
  price_cents bigint check (price_cents is null or price_cents >= 0),
  currency_code text not null default 'COP',
  status text not null default 'draft'
    check (status in ('draft', 'active', 'retired')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint plans_code_version_key unique (code, version)
);

create index plans_code_status_idx on public.plans (code, status);

create table public.features (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  name text not null,
  description text,
  created_at timestamptz not null default now()
);

create table public.plan_features (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.plans(id) on delete cascade,
  feature_id uuid not null references public.features(id) on delete restrict,
  enabled boolean not null default true,
  limit_value integer check (limit_value is null or limit_value >= 0),
  config jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint plan_features_plan_feature_key unique (plan_id, feature_id)
);

create table public.tenant_subscriptions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  plan_id uuid not null references public.plans(id) on delete restrict,
  status text not null default 'pending'
    check (status in ('pending', 'trialing', 'active', 'past_due', 'grace', 'suspended', 'cancelled')),
  provider text,
  provider_reference text,
  trial_ends_at timestamptz,
  current_period_start timestamptz,
  current_period_end timestamptz,
  grace_ends_at timestamptz,
  cancel_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint tenant_subscriptions_tenant_id_key unique (tenant_id)
);

create table public.subscription_events (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  tenant_subscription_id uuid not null references public.tenant_subscriptions(id) on delete restrict,
  event_type text not null,
  provider text,
  provider_event_id text,
  payload jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint subscription_events_provider_event_key
    unique (provider, provider_event_id)
);

create index subscription_events_tenant_created_idx
  on public.subscription_events (tenant_id, created_at desc);

create table public.tenant_feature_overrides (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  feature_id uuid not null references public.features(id) on delete restrict,
  enabled boolean not null,
  limit_value integer check (limit_value is null or limit_value >= 0),
  reason text not null,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint tenant_feature_overrides_validity_check
    check (ends_at is null or ends_at > starts_at)
);

create index tenant_feature_overrides_lookup_idx
  on public.tenant_feature_overrides (tenant_id, feature_id, starts_at, ends_at);

create trigger plans_set_updated_at
before update on public.plans
for each row execute function private.beautyos_set_updated_at();

create trigger tenant_subscriptions_set_updated_at
before update on public.tenant_subscriptions
for each row execute function private.beautyos_set_updated_at();

alter table public.plans enable row level security;
alter table public.features enable row level security;
alter table public.plan_features enable row level security;
alter table public.tenant_subscriptions enable row level security;
alter table public.subscription_events enable row level security;
alter table public.tenant_feature_overrides enable row level security;

revoke all on table public.plans from public, anon, authenticated;
revoke all on table public.features from public, anon, authenticated;
revoke all on table public.plan_features from public, anon, authenticated;
revoke all on table public.tenant_subscriptions from public, anon, authenticated;
revoke all on table public.subscription_events from public, anon, authenticated;
revoke all on table public.tenant_feature_overrides from public, anon, authenticated;

grant all on table public.plans to service_role;
grant all on table public.features to service_role;
grant all on table public.plan_features to service_role;
grant all on table public.tenant_subscriptions to service_role;
grant all on table public.subscription_events to service_role;
grant all on table public.tenant_feature_overrides to service_role;

-- Helper interno: resuelve una funcionalidad para un tenant.

create or replace function private.beautyos_resolve_entitlement(
  p_tenant_id uuid,
  p_feature_key text
)
returns table (
  entitled boolean,
  limit_value integer,
  source text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_feature_id uuid;
  v_subscription public.tenant_subscriptions%rowtype;
  v_override record;
  v_plan_feature record;
begin
  if p_tenant_id is null or p_feature_key is null then
    raise exception 'tenant_id y feature_key son obligatorios.';
  end if;

  select id into v_feature_id
  from public.features
  where key = p_feature_key;

  if v_feature_id is null then
    return query select false, null::integer, 'feature_desconocida';
    return;
  end if;

  select *
    into v_subscription
  from public.tenant_subscriptions
  where tenant_id = p_tenant_id;

  if v_subscription.id is null or v_subscription.status in ('pending', 'cancelled') then
    return query select false, null::integer, 'sin_suscripcion_operativa';
    return;
  end if;

  select tfo.enabled, tfo.limit_value
    into v_override
  from public.tenant_feature_overrides tfo
  where tfo.tenant_id = p_tenant_id
    and tfo.feature_id = v_feature_id
    and tfo.starts_at <= now()
    and (tfo.ends_at is null or tfo.ends_at > now())
  order by tfo.created_at desc
  limit 1;

  if found then
    return query select v_override.enabled, v_override.limit_value, 'override';
    return;
  end if;

  select pf.enabled, pf.limit_value
    into v_plan_feature
  from public.plan_features pf
  where pf.plan_id = v_subscription.plan_id
    and pf.feature_id = v_feature_id;

  if not found then
    return query select false, null::integer, 'no_incluida_en_plan';
    return;
  end if;

  return query select v_plan_feature.enabled, v_plan_feature.limit_value, 'plan';
end;
$$;

revoke all on function private.beautyos_resolve_entitlement(uuid, text)
  from public, anon, authenticated;
grant execute on function private.beautyos_resolve_entitlement(uuid, text)
  to service_role;

-- RPC: entitlements del tenant del usuario autenticado (para gatear UI).

create or replace function public.get_my_entitlements()
returns table (
  feature_key text,
  entitled boolean,
  limit_value integer,
  source text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  v_tenant_id := public.get_my_tenant_id();

  if v_tenant_id is null then
    raise exception 'No existe una membresia activa para este usuario.';
  end if;

  return query
  select f.key, r.entitled, r.limit_value, r.source
  from public.features f
  cross join lateral private.beautyos_resolve_entitlement(v_tenant_id, f.key) r
  order by f.key;
end;
$$;

-- RPC: estado de la suscripcion del tenant (para el owner/admin, ej. banner
-- de prueba gratis o aviso de pago pendiente).

create or replace function public.get_my_tenant_subscription()
returns table (
  plan_code text,
  plan_name text,
  status text,
  trial_ends_at timestamptz,
  current_period_end timestamptz,
  grace_ends_at timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  v_tenant_id := public.get_my_tenant_id();

  if v_tenant_id is null or not public.is_owner_or_admin() then
    raise exception 'No autorizado para consultar la suscripcion del centro.';
  end if;

  return query
  select
    p.code,
    p.name,
    ts.status,
    ts.trial_ends_at,
    ts.current_period_end,
    ts.grace_ends_at
  from public.tenant_subscriptions ts
  join public.plans p on p.id = ts.plan_id
  where ts.tenant_id = v_tenant_id;
end;
$$;

-- RPC publica (anonima): catalogo de planes para una futura pagina de
-- precios. No expone tenants, suscripciones ni datos de negocio.

create or replace function public.list_public_plans()
returns table (
  plan_code text,
  plan_name text,
  billing_period text,
  price_cents bigint,
  currency_code text,
  feature_key text,
  feature_name text,
  feature_enabled boolean,
  feature_limit integer
)
language sql
security definer
set search_path = pg_catalog
as $$
  select
    p.code,
    p.name,
    p.billing_period,
    p.price_cents,
    p.currency_code,
    f.key,
    f.name,
    pf.enabled,
    pf.limit_value
  from public.plans p
  join public.plan_features pf on pf.plan_id = p.id
  join public.features f on f.id = pf.feature_id
  where p.status = 'active'
  order by p.code, f.key;
$$;

revoke all on function public.get_my_entitlements() from public, anon;
revoke all on function public.get_my_tenant_subscription() from public, anon;
revoke all on function public.list_public_plans() from public;

grant execute on function public.get_my_entitlements() to authenticated, service_role;
grant execute on function public.get_my_tenant_subscription() to authenticated, service_role;
grant execute on function public.list_public_plans() to anon, authenticated, service_role;

-- Semillas: los 3 planes y las 5 funcionalidades del diseno rector, con la
-- matriz exacta de la seccion 2 de SUSCRIPCION_Y_ENTITLEMENTS.md. Precios y
-- limites numericos (sedes/usuarios/mensajes/almacenamiento) quedan sin
-- definir (NULL) a proposito: son decisiones comerciales del propietario,
-- no algo que deba inventar esta migracion.

insert into public.plans (code, version, name, status) values
  ('basico', 1, 'Básico', 'active'),
  ('business', 1, 'Business', 'active'),
  ('profesional', 1, 'Profesional', 'active');

insert into public.features (key, name, description) values
  ('inventory', 'Inventario, compras y gastos', 'Gestion de productos, movimientos de inventario, compras y gastos.'),
  ('financial_reports', 'Reportes financieros ampliados', 'Reportes financieros mas alla del resumen basico de ventas.'),
  ('portfolio', 'Fotos de trabajos', 'Galeria de fotos de trabajos realizados por estilista.'),
  ('reviews', 'Reseñas', 'Reseñas de clientes sobre servicios y estilistas.'),
  ('social_publishing', 'Publicación social asistida', 'Herramientas para publicar contenido en redes sociales.');

insert into public.plan_features (plan_id, feature_id, enabled)
select p.id, f.id, (p.code in ('business', 'profesional'))
from public.plans p
cross join public.features f
where f.key in ('inventory', 'financial_reports');

insert into public.plan_features (plan_id, feature_id, enabled)
select p.id, f.id, (p.code = 'profesional')
from public.plans p
cross join public.features f
where f.key in ('portfolio', 'reviews', 'social_publishing');

-- Tenants ya existentes (cuentas de desarrollo, no clientes reales) quedan
-- activos en Profesional sin fecha de fin, para no perder acceso al
-- empezar a exigir entitlements en las RPC.

insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_start)
select t.id, p.id, 'active', now()
from public.tenants t
cross join public.plans p
where p.code = 'profesional'
on conflict (tenant_id) do nothing;

commit;
