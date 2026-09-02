-- BeautyOS / Salón y Más — Suscripción por sede (D-190, Etapa 2 de 3 de D-188)
--
-- Paso 8.15 del Plan Maestro.
--
-- QUÉ HACE Y QUÉ NO
--
-- D-188 dejó el cobro **por sede activa** como modelo de negocio, y avisó de que
-- hacerlo entero rehace el ciclo anclado de D-160, el webhook y las intenciones
-- de pago de D-182 — el código de dinero recién blindado. Por eso va en etapas.
--
-- **Esta etapa construye la capa por sede y NO toca el cobro.** Al terminar:
--   - cada sede tiene su propio estado, su propio período y su propio precio;
--   - una sede nueva nace **pendiente de pago**;
--   - el dueño de la plataforma puede activarla a mano desde el panel;
--   - y el cobro por ePayco **sigue siendo uno por negocio**, exactamente como
--     ayer. Eso es la Etapa 3.
--
-- POR QUÉ SE PUEDE ACTIVAR A MANO, Y NO ES UN PARCHE
--
-- Si una sede nueva naciera pendiente y no hubiera forma de activarla hasta que
-- exista la Etapa 3, crear una sede sería **peor que hoy**: el dueño se quedaría
-- con un local muerto y sin manera de pagarlo. La activación manual desde el
-- panel cierra ese hueco, y además es como se va a vender la segunda sede en la
-- práctica durante las primeras semanas: hablando por WhatsApp y cobrando
-- aparte. Cuando llegue la Etapa 3, ePayco hará automático lo que aquí se hace
-- a mano; la función se queda igual, porque el propietario va a seguir
-- necesitando conceder y corregir casos puntuales.
--
-- LA MIGRACIÓN DE LO QUE YA EXISTE, QUE ES UNA DECISIÓN Y NO UN DETALLE
--
-- **Las sedes que ya existen NO se marcan como impagas.** Se vendieron bajo el
-- plan viejo, donde el Profesional traía *sedes ilimitadas*: cobrarlas ahora
-- retroactivamente sería cambiarle el trato a alguien que ya compró. Todas
-- heredan el estado, el período y el precio de la suscripción de su negocio.
--
-- **Solo nacen pendientes las sedes creadas a partir de aquí.**
--
-- POR QUÉ UN DISPARADOR Y NO REESCRIBIR `create_branch`
--
-- `create_branch` es una función larga que además crea la membresía, el horario
-- de la semana y sincroniza catálogos. Reescribirla entera para añadirle una
-- línea es justo el riesgo que D-119, D-122 y D-123 dejaron documentado en un
-- mismo día. Un disparador `after insert` sobre `branches` hace lo mismo sin
-- tocar una función que ya funciona — y cubre además cualquier otro camino que
-- cree sedes hoy o mañana.

begin;

-- ---------------------------------------------------------------------------
-- 1. La suscripción de cada sede
-- ---------------------------------------------------------------------------

create table if not exists public.branch_subscriptions (
  id uuid primary key default gen_random_uuid(),

  tenant_id uuid not null references public.tenants(id) on delete restrict,
  branch_id uuid not null references public.branches(id) on delete cascade,

  -- Mismos estados que `tenant_subscriptions`, a proposito: el dia que la
  -- Etapa 3 mueva el cobro aqui, la maquinaria de D-141 y D-160 tiene que poder
  -- razonar sobre esto sin traducir nada.
  status text not null default 'pending',

  -- Precio pactado DE ESTA SEDE. Null = el precio de lista del plan.
  -- No hay `discount_percent`: D-188 y D-189 dejaron el descuento como precio
  -- pactado, no como porcentaje, porque los porcentajes no caen redondos y el
  -- monto se compara contra el pago (D-159).
  price_cop bigint,
  price_reason text,

  trial_ends_at timestamptz,
  current_period_start timestamptz,
  current_period_end timestamptz,
  grace_ends_at timestamptz,

  -- Cuando esta sede se activo por primera vez. Sirve para saber si una sede
  -- nunca llego a pagarse o si se cayo despues.
  activated_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint branch_subscriptions_branch_unico unique (branch_id),
  constraint branch_subscriptions_status_valido
    check (status in (
      'pending', 'trialing', 'active', 'past_due', 'grace', 'suspended', 'cancelled'
    )),
  -- Mismo candado que D-136 en tenant_subscriptions: un precio distinto del de
  -- lista exige decir por que.
  constraint branch_subscriptions_precio_con_motivo
    check (price_cop is null or price_reason is not null),
  constraint branch_subscriptions_precio_positivo
    check (price_cop is null or price_cop > 0)
);

comment on table public.branch_subscriptions is
  'El estado de pago de cada sede (D-190, Etapa 2 de D-188). Una sede nueva nace pendiente. '
  'El cobro por ePayco sigue siendo por negocio hasta la Etapa 3. NO ELIMINAR.';

comment on column public.branch_subscriptions.price_cop is
  'Precio pactado de ESTA sede en pesos enteros. Null = precio de lista del plan. '
  'No hay porcentaje a proposito: el descuento se fija como precio (D-188, D-189).';

create index if not exists branch_subscriptions_tenant_idx
  on public.branch_subscriptions (tenant_id, status);

create index if not exists branch_subscriptions_pendientes_idx
  on public.branch_subscriptions (tenant_id)
  where status = 'pending';

alter table public.branch_subscriptions enable row level security;
revoke all on table public.branch_subscriptions from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Lo que ya existe hereda lo que ya se vendio
-- ---------------------------------------------------------------------------

insert into public.branch_subscriptions (
  tenant_id, branch_id, status, price_cop, price_reason,
  trial_ends_at, current_period_start, current_period_end, grace_ends_at,
  activated_at
)
select
  b.tenant_id,
  b.id,
  coalesce(ts.status, 'pending'),
  ts.price_cop,
  ts.price_reason,
  ts.trial_ends_at,
  ts.current_period_start,
  ts.current_period_end,
  ts.grace_ends_at,
  case when ts.status in ('active', 'trialing') then coalesce(ts.current_period_start, now()) end
from public.branches b
left join public.tenant_subscriptions ts on ts.tenant_id = b.tenant_id
on conflict (branch_id) do nothing;

-- ---------------------------------------------------------------------------
-- 3. La sede nueva nace pendiente
-- ---------------------------------------------------------------------------

create or replace function private.beautyos_crear_suscripcion_de_sede()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  insert into public.branch_subscriptions (tenant_id, branch_id, status)
  values (new.tenant_id, new.id, 'pending')
  on conflict (branch_id) do nothing;

  return new;
end;
$$;

comment on function private.beautyos_crear_suscripcion_de_sede() is
  'Le crea su suscripcion pendiente a cada sede nueva (D-190). Va como disparador y no dentro de '
  'create_branch para no reescribir una funcion larga que ya funciona. NO ELIMINAR.';

drop trigger if exists branches_crear_suscripcion on public.branches;

create trigger branches_crear_suscripcion
  after insert on public.branches
  for each row
  execute function private.beautyos_crear_suscripcion_de_sede();

-- ---------------------------------------------------------------------------
-- 4. Cuanto cuesta ESTA sede
-- ---------------------------------------------------------------------------
--
-- Hermana de `beautyos_precio_efectivo` (D-136), que sigue viva y sigue siendo
-- la que manda mientras el cobro sea por negocio. Esta es la que mandara cuando
-- la Etapa 3 mueva el cobro a la sede.

create or replace function private.beautyos_precio_efectivo_sede(p_branch_id uuid)
returns table (precio_cop bigint, base_cop bigint, motivo text)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v record;
begin
  select bs.price_cop, bs.price_reason, p.price_cop as lista
    into v
  from public.branch_subscriptions bs
  join public.branches b on b.id = bs.branch_id
  join public.tenant_subscriptions ts on ts.tenant_id = b.tenant_id
  join public.plans p on p.id = ts.plan_id
  where bs.branch_id = p_branch_id;

  if not found then
    return;
  end if;

  base_cop := v.lista;
  precio_cop := coalesce(v.price_cop, v.lista);
  motivo := coalesce(v.price_reason, 'Precio de lista');

  return next;
end;
$$;

comment on function private.beautyos_precio_efectivo_sede(uuid) is
  'Cuanto cuesta una sede al mes: su precio pactado, o el de lista del plan (D-190). Hermana de '
  'beautyos_precio_efectivo, que sigue mandando mientras el cobro sea por negocio. NO ELIMINAR.';

-- ---------------------------------------------------------------------------
-- 5. Que ve el salon de sus propias sedes
-- ---------------------------------------------------------------------------

create or replace function public.get_branch_subscriptions()
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
set search_path = pg_catalog, public
as $$
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
  order by b.is_primary desc, b.created_at;
end;
$$;

comment on function public.get_branch_subscriptions() is
  'Estado de pago de las sedes del negocio, para el owner/admin (D-190). "al_dia" no es lo mismo que '
  '"activa": una sede puede estar operativa y en mora. NO ELIMINAR.';

-- ---------------------------------------------------------------------------
-- 6. Como el dueño de la plataforma activa una sede
-- ---------------------------------------------------------------------------
--
-- Mientras no exista la Etapa 3, esta es LA forma de cobrar una segunda sede:
-- se habla con el salon, se cobra aparte, y se activa aqui con su motivo. No es
-- un parche: cuando ePayco lo haga solo, esta funcion se queda para conceder y
-- corregir casos puntuales, igual que `platform_set_tenant_feature_override`.

create or replace function public.platform_set_branch_subscription(
  p_branch_id uuid,
  p_status text,
  p_price_cop bigint default null,
  p_price_reason text default null,
  p_period_end timestamptz default null
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_tenant_id uuid;
begin
  if private.beautyos_current_platform_role() is null then
    raise exception 'No autorizado: solo la plataforma puede cambiar el estado de pago de una sede.';
  end if;

  if p_status is null or p_status not in (
    'pending', 'trialing', 'active', 'past_due', 'grace', 'suspended', 'cancelled'
  ) then
    raise exception 'Estado invalido: %.', coalesce(p_status, 'null');
  end if;

  if p_price_cop is not null
     and (p_price_reason is null or length(trim(p_price_reason)) = 0) then
    raise exception 'Un precio pactado exige motivo. Mismo criterio que D-136.';
  end if;

  select tenant_id into v_tenant_id
  from public.branches where id = p_branch_id;

  if v_tenant_id is null then
    raise exception 'La sede no existe.';
  end if;

  update public.branch_subscriptions
  set status = p_status,
      price_cop = coalesce(p_price_cop, price_cop),
      price_reason = coalesce(p_price_reason, price_reason),
      current_period_end = coalesce(p_period_end, current_period_end),
      -- La primera activacion se sella una sola vez: sirve para saber si una
      -- sede nunca llego a pagarse o si se cayo despues.
      activated_at = case
        when p_status in ('active', 'trialing') then coalesce(activated_at, now())
        else activated_at
      end,
      updated_at = now()
  where branch_id = p_branch_id;

  if not found then
    raise exception 'La sede no tiene suscripcion registrada.';
  end if;
end;
$$;

comment on function public.platform_set_branch_subscription(uuid, text, bigint, text, timestamptz) is
  'El dueño de la plataforma fija el estado y el precio pactado de una sede (D-190). Mientras no exista '
  'la Etapa 3, es la forma de cobrar y activar una segunda sede. NO ELIMINAR.';

-- ---------------------------------------------------------------------------
-- 7. Permisos
-- ---------------------------------------------------------------------------

revoke all on function private.beautyos_precio_efectivo_sede(uuid)
  from public, anon, authenticated;
grant execute on function private.beautyos_precio_efectivo_sede(uuid) to service_role;

revoke all on function public.get_branch_subscriptions() from public, anon;
grant execute on function public.get_branch_subscriptions() to authenticated;

revoke all on function public.platform_set_branch_subscription(uuid, text, bigint, text, timestamptz)
  from public, anon;
grant execute on function public.platform_set_branch_subscription(uuid, text, bigint, text, timestamptz)
  to authenticated;

commit;
