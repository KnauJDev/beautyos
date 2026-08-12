-- Salon y Mas - Pasos 3.5 y 3.6: precios, limites que se hacen cumplir, y
-- precio negociado por cliente.
--
-- QUE RESUELVE. Hasta hoy no se podia cobrar nada: los tres planes existian
-- desde el 22-jul **con el precio en blanco**, y los limites que decidio D-124
-- -- 1/3/sin limite sedes, 5/15/sin limite cuentas -- **no existian en ninguna
-- parte**. Se comprobo el 12-ago: `create_branch`, `create_team_invitation` y
-- `register_tenant` no tenian **ni una sola** comprobacion de limite. Un plan
-- Basico podia crear diez sedes.
--
-- LO QUE ESTA MIGRACION NO HACE, Y ES A PROPOSITO. **No decide que plan lleva
-- que.** Esa matriz son 15 casillas de si/no que ya estan cargadas segun D-124
-- y que el propietario cambiara cuando vuelva de sus primeras visitas a
-- salones reales (D-136). Aqui se construye **la maquina**, que es lo caro de
-- cambiar despues; los interruptores se mueven con una instruccion, y desde la
-- Fase 7 con un clic.
--
-- LAS TRES DECISIONES DEL PROPIETARIO QUE GOBIERNAN ESTE ARCHIVO (D-136):
--   1. El precio se guarda en PESOS enteros: 160000, no 16000000.
--   2. Un limite vacio significa SIN LIMITE. Es un "hasta N".
--   3. Los limites se hacen cumplir AHORA, no despues.

begin;

-- ---------------------------------------------------------------------------
-- 1. La columna del precio se llama por lo que guarda.
--
-- Se llamaba `price_cents` -- centavos -- y el propietario decidio guardar
-- PESOS. Dejar pesos dentro de una columna que dice "centavos" es literalmente
-- como nacio el hallazgo H-08, que sigue abierto por columnas de dinero
-- inconsistentes. **Renombrar sale gratis**: la columna esta vacia en las tres
-- filas, ningun archivo de Flutter la menciona, y la unica funcion que la lee
-- es `list_public_plans`, que esta dormida y se actualiza mas abajo.
-- ---------------------------------------------------------------------------

alter table public.plans rename column price_cents to price_cop;
alter table public.plans rename constraint plans_price_cents_check to plans_price_cop_check;

comment on column public.plans.price_cop is
  'Precio de lista en PESOS COLOMBIANOS ENTEROS (160000 = $160.000). No son centavos: se renombro el 12-ago justamente para que no se confunda (D-136).';

-- ---------------------------------------------------------------------------
-- 2. Los precios de lista (D-124).
--
-- Se escriben por `code` y no por identificador, porque el codigo es lo unico
-- estable entre la base real y la de ensayo.
-- ---------------------------------------------------------------------------

update public.plans set price_cop = 160000, updated_at = now() where code = 'basico';
update public.plans set price_cop = 200000, updated_at = now() where code = 'business';
update public.plans set price_cop = 240000, updated_at = now() where code = 'profesional';

do $$
declare v_sin_precio integer;
begin
  select count(*) into v_sin_precio
  from public.plans where status = 'active' and price_cop is null;

  if v_sin_precio > 0 then
    raise exception 'Quedaron % planes activos sin precio. Revisa los codigos de plan.', v_sin_precio;
  end if;
end
$$;

-- ---------------------------------------------------------------------------
-- 3. Las dos capacidades que faltaban.
--
-- POR QUE HACEN FALTA, y corrige una afirmacion de D-124. Aquella decision dijo
-- que la negociacion cliente por cliente "ya esta disenada; falta solo la
-- pantalla", porque `tenant_feature_overrides` tiene `limit_value`. **Es media
-- verdad**: el mecanismo existe, pero solo puede negociar sobre capacidades que
-- EXISTAN. El propietario pidio poder pactar *"3 sedes pero con 25 cuentas"* y
-- eso hoy **no se puede ni escribir**, porque ni "sedes" ni "cuentas" son una
-- capacidad. Sin estas dos filas, la pantalla de la Fase 7 no tendria que
-- mostrar.
--
-- `enabled = true` en los tres planes a proposito: **todos pueden tener sedes y
-- equipo**. Lo que cambia es CUANTAS, y eso es `limit_value`.
-- ---------------------------------------------------------------------------

insert into public.features (key, name, description) values
  ('branches',     'Sedes',             'Cuantas sedes puede tener el negocio. Vacio = sin limite.'),
  ('team_members', 'Cuentas de equipo', 'Cuantas cuentas activas puede tener el negocio, sin contar al propietario. Vacio = sin limite.')
on conflict (key) do nothing;

insert into public.plan_features (plan_id, feature_id, enabled, limit_value)
select p.id, f.id, true, l.limite
from (values
  ('basico',      'branches',     1),
  ('business',    'branches',     3),
  ('profesional', 'branches',     null),
  ('basico',      'team_members', 5),
  ('business',    'team_members', 15),
  ('profesional', 'team_members', null)
) as l(plan_code, feature_key, limite)
join public.plans p on p.code = l.plan_code
join public.features f on f.key = l.feature_key
on conflict (plan_id, feature_id) do nothing;

comment on column public.plan_features.limit_value is
  'El tope de esa capacidad para ese plan. NULO SIGNIFICA SIN LIMITE, no "sin definir" (D-136). Se lee como "hasta N".';

-- ---------------------------------------------------------------------------
-- 4. El precio negociado con cada cliente (paso 3.6).
--
-- El propietario va a vender salon por salon y necesita poder pactar, EN EL
-- MOMENTO DE APROBAR el negocio (D-125), una de dos cosas:
--   * un precio propio            -> `price_cop`
--   * un descuento por un tiempo  -> `discount_percent` + `discount_ends_at`
--
-- **El pionero es el segundo caso sin fecha de fin**: 50 % para siempre
-- mientras siga activo. D-124 lo decidio asi tras descartar el 50 % por seis
-- meses: al mes 7 el precio se duplicaria y se irian justo los 25 primeros,
-- que son los que dan las referencias.
--
-- `price_reason` es OBLIGATORIO si hay cualquiera de los dos. Mismo criterio
-- que `tenant_feature_overrides` desde D-044: un trato distinto sin motivo
-- escrito es un descuadre esperando a que alguien pregunte por que.
-- ---------------------------------------------------------------------------

alter table public.tenant_subscriptions
  add column if not exists price_cop        bigint,
  add column if not exists discount_percent numeric(5,2),
  add column if not exists discount_ends_at timestamptz,
  add column if not exists price_reason     text,
  add column if not exists is_founder       boolean not null default false;

alter table public.tenant_subscriptions
  drop constraint if exists tenant_subscriptions_precio_check;

alter table public.tenant_subscriptions
  add constraint tenant_subscriptions_precio_check check (
    (price_cop is null or price_cop >= 0)
    and (discount_percent is null or (discount_percent > 0 and discount_percent <= 100))
    and (discount_ends_at is null or discount_percent is not null)
    and (
      (price_cop is null and discount_percent is null)
      or length(trim(coalesce(price_reason, ''))) > 0
    )
  );

comment on column public.tenant_subscriptions.price_cop is
  'Precio propio pactado con este cliente, en pesos enteros. VACIO = paga el precio de lista de su plan.';
comment on column public.tenant_subscriptions.discount_percent is
  'Descuento sobre el precio. VACIO = ninguno. Sin `discount_ends_at` es PARA SIEMPRE mientras siga activo: asi es el pionero (D-124).';
comment on column public.tenant_subscriptions.is_founder is
  'Uno de los 25 pioneros. Solo sirve para contarlos y reconocerlos: el descuento lo hace `discount_percent`.';

-- ---------------------------------------------------------------------------
-- 5. Cuanto paga de verdad este negocio.
--
-- La regla en un solo sitio, para que nadie la reimplemente distinta el dia que
-- se conecte ePayco (pasos 3.9 y 3.10).
--
-- Orden: se parte del precio propio si lo hay, si no del de lista; y despues se
-- aplica el descuento **solo si sigue vigente**. Se redondea a pesos enteros,
-- coherente con D-055.
-- ---------------------------------------------------------------------------

create or replace function private.beautyos_precio_efectivo(p_tenant_id uuid)
returns table (precio_cop bigint, base_cop bigint, descuento numeric, motivo text)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v record;
begin
  select ts.price_cop, ts.discount_percent, ts.discount_ends_at, ts.price_reason,
         p.price_cop as lista
    into v
  from public.tenant_subscriptions ts
  join public.plans p on p.id = ts.plan_id
  where ts.tenant_id = p_tenant_id;

  if not found then
    return;
  end if;

  base_cop := coalesce(v.price_cop, v.lista);

  -- El descuento vence: si tiene fecha y ya paso, se cobra el precio completo.
  if v.discount_percent is not null
     and (v.discount_ends_at is null or v.discount_ends_at > now()) then
    descuento := v.discount_percent;
  else
    descuento := null;
  end if;

  precio_cop := round(coalesce(base_cop, 0) * (1 - coalesce(descuento, 0) / 100.0));
  motivo := v.price_reason;

  return next;
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. El ayudante que hace cumplir un limite.
--
-- Hasta hoy `beautyos_require_entitlement` solo comprobaba el ENCENDIDO de una
-- capacidad (D-069). Este comprueba el NUMERO.
--
-- **Falla cerrado a proposito**, igual que `beautyos_can_delete_work_photo`
-- (D-119): si la capacidad no esta habilitada, no se deja crear nada.
-- ---------------------------------------------------------------------------

create or replace function private.beautyos_require_limit(
  p_tenant_id uuid,
  p_feature_key text,
  p_actual integer,
  p_que text
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v record;
begin
  select * into v
  from private.beautyos_resolve_entitlement(p_tenant_id, p_feature_key);

  if v is null or not v.entitled then
    raise exception 'Tu plan no incluye %.', p_que;
  end if;

  -- NULO = SIN LIMITE. Es la decision del propietario del 12-ago (D-136), y es
  -- la unica lectura posible una vez todos los limites estan cargados.
  if v.limit_value is null then
    return;
  end if;

  if p_actual >= v.limit_value then
    raise exception
      'Tu plan permite hasta % %. Ya tienes %. Escribenos si necesitas mas: el limite se puede ampliar sin cambiar de plan.',
      v.limit_value, p_que, p_actual;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. Se hace cumplir al crear una sede.
--
-- Copia exacta de la version del 27-jul (D-072) mas la comprobacion. Se
-- conservan sin tocar: que solo el propietario cree sedes, la busqueda de su
-- membresia, la validacion del nombre, la generacion del identificador unico
-- con sufijo, y los tres bloques que siembran sede, horarios y politicas.
--
-- La comprobacion va ANTES de insertar nada: si sobra el limite, no se crea a
-- medias.
-- ---------------------------------------------------------------------------

create or replace function public.create_branch(
  p_name text,
  p_address text default null,
  p_city text default null
)
returns table (branch_id uuid)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_tenant_membership_id uuid;
  v_branch_id uuid;
  v_base_slug text;
  v_slug text;
  v_suffix integer := 1;
  v_sedes integer;
begin
  v_tenant_id := public.get_my_tenant_id();

  if v_tenant_id is null or public.get_my_role() <> 'tenant_owner' then
    raise exception 'Solo el propietario del negocio puede crear sedes.';
  end if;

  select tm.id
    into v_tenant_membership_id
  from public.tenant_memberships tm
  where tm.tenant_id = v_tenant_id
    and tm.user_id = auth.uid()
    and tm.role = 'tenant_owner'
    and tm.active;

  if v_tenant_membership_id is null then
    raise exception 'No se encontro tu membresia de propietario para este negocio.';
  end if;

  if length(trim(coalesce(p_name, ''))) = 0 then
    raise exception 'El nombre de la sede es obligatorio.';
  end if;

  -- NUEVO (paso 3.5). Se cuentan las sedes que ya tiene y se compara.
  select count(*) into v_sedes
  from public.branches b
  where b.tenant_id = v_tenant_id;

  perform private.beautyos_require_limit(v_tenant_id, 'branches', v_sedes, 'sedes');

  v_base_slug := trim(both '-' from regexp_replace(lower(trim(p_name)), '[^a-z0-9]+', '-', 'g'));

  if v_base_slug = '' then
    raise exception 'El nombre de la sede debe incluir letras o numeros.';
  end if;

  v_slug := v_base_slug;

  while exists (
    select 1 from public.branches where tenant_id = v_tenant_id and slug = v_slug
  ) loop
    v_suffix := v_suffix + 1;
    v_slug := v_base_slug || '-' || v_suffix;
  end loop;

  insert into public.branches (
    tenant_id, name, slug, address, city, is_primary
  ) values (
    v_tenant_id,
    trim(p_name),
    v_slug,
    nullif(trim(coalesce(p_address, '')), ''),
    nullif(trim(coalesce(p_city, '')), ''),
    false
  )
  returning id into v_branch_id;

  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (
    v_tenant_id, v_branch_id, v_tenant_membership_id, true, now(), auth.uid()
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

  return query select v_branch_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 8. La pantalla publica de planes deja de pedir una columna que ya no existe.
--
-- Se renombra la columna que devuelve, de `price_cents` a `price_cop`. Sigue
-- dormida (paso 3.8), pero si no se toca aqui, se rompe.
-- ---------------------------------------------------------------------------

create or replace function public.list_public_plans()
returns table (
  plan_code text,
  plan_name text,
  billing_period text,
  price_cop bigint,
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
    p.price_cop,
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

-- ---------------------------------------------------------------------------
-- 9. Se hace cumplir al invitar a alguien al equipo.
--
-- Copia exacta de la version del 11-ago (D-132) mas la comprobacion. Se
-- conservan sin tocar TODAS sus protecciones: correo valido, rol permitido,
-- estilista activo en la sede, el candado del hallazgo R -- un estilista, una
-- sola cuenta activa --, la invitacion pendiente por estilista, que el correo
-- no pertenezca ya a un negocio, y la invitacion pendiente por correo.
--
-- SE CUENTAN TAMBIEN LAS INVITACIONES PENDIENTES, y no es un detalle: contar
-- solo las cuentas activas dejaria mandar veinte invitaciones de golpe y
-- superar el limite cuando las acepten. El tope se comprueba al invitar
-- **porque es el momento en que el dueno puede entenderlo y decidir**, no
-- cuando la persona invitada intenta entrar y se lleva un error que no puede
-- resolver.
--
-- El propietario NO cuenta: su cuenta no es "de equipo", es el negocio.
-- ---------------------------------------------------------------------------

create or replace function public.create_team_invitation(
  p_branch_id uuid,
  p_email text,
  p_role text,
  p_stylist_id uuid default null
)
returns public.team_invitations
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_email text := lower(trim(coalesce(p_email, '')));
  v_existing_user_id uuid;
  v_ocupado_por text;
  v_equipo integer;
  v_result public.team_invitations%rowtype;
begin
  select tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner', 'admin'], true
  );

  if v_email = '' or v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'El correo del invitado no es valido.';
  end if;

  if p_role not in ('admin', 'assistant', 'stylist') then
    raise exception 'Rol no permitido para invitacion.';
  end if;

  -- NUEVO (paso 3.5). Cuentas activas del equipo + invitaciones pendientes.
  select
    (select count(*)
       from public.tenant_memberships tm
      where tm.tenant_id = v_tenant_id
        and tm.active = true
        and tm.role <> 'tenant_owner')
    +
    (select count(*)
       from public.team_invitations ti
      where ti.tenant_id = v_tenant_id
        and ti.status = 'pending'
        and ti.expires_at > now())
    into v_equipo;

  perform private.beautyos_require_limit(
    v_tenant_id, 'team_members', v_equipo, 'cuentas de equipo'
  );

  if p_role = 'stylist' then
    if p_stylist_id is null then
      raise exception 'Selecciona a que estilista del catalogo corresponde esta invitacion.';
    end if;

    if not exists (
      select 1
      from public.branch_stylists bst
      where bst.tenant_id = v_tenant_id
        and bst.branch_id = p_branch_id
        and bst.stylist_id = p_stylist_id
        and bst.active = true
    ) then
      raise exception 'Ese estilista no esta activo en la sede seleccionada.';
    end if;

    select coalesce(up.full_name, au.email)
      into v_ocupado_por
    from public.tenant_memberships tm
    left join public.user_profiles up
      on up.user_id = tm.user_id
     and up.tenant_id = tm.tenant_id
    left join auth.users au
      on au.id = tm.user_id
    where tm.tenant_id = v_tenant_id
      and tm.stylist_id = p_stylist_id
      and tm.active = true
    limit 1;

    if v_ocupado_por is not null then
      raise exception
        'Ese estilista del catalogo ya tiene una cuenta activa (%). Si esa persona cambio de correo, desactiva primero su cuenta en Usuarios y vuelve a invitarla: su historial NO se pierde, porque va con el estilista del catalogo y no con la cuenta.',
        v_ocupado_por;
    end if;

    if exists (
      select 1
      from public.team_invitations ti
      where ti.tenant_id = v_tenant_id
        and ti.stylist_id = p_stylist_id
        and ti.status = 'pending'
        and ti.expires_at > now()
    ) then
      raise exception 'Ya hay una invitacion pendiente para ese estilista del catalogo. Cancelala primero si quieres invitar a otro correo.';
    end if;
  elsif p_stylist_id is not null then
    raise exception 'Solo el rol estilista puede vincularse a un estilista del catalogo.';
  end if;

  select u.id
    into v_existing_user_id
  from auth.users u
  where lower(u.email) = v_email;

  if v_existing_user_id is not null and exists (
    select 1 from public.tenant_memberships tm
    where tm.user_id = v_existing_user_id and tm.active = true
  ) then
    raise exception 'Ese correo ya pertenece a un negocio.';
  end if;

  if exists (
    select 1 from public.team_invitations ti
    where lower(ti.email) = v_email
      and ti.tenant_id = v_tenant_id
      and ti.status = 'pending'
      and ti.expires_at > now()
  ) then
    raise exception 'Ya existe una invitacion pendiente para ese correo.';
  end if;

  insert into public.team_invitations (
    tenant_id, branch_id, email, role, stylist_id, invited_by
  ) values (
    v_tenant_id, p_branch_id, v_email, p_role, p_stylist_id, auth.uid()
  )
  returning * into v_result;

  return v_result;
end;
$$;

commit;
