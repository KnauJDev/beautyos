-- BeautyOS / Salón y Más — Tope de equipo por sede y alertas de vencimiento
-- por sede (D-196, Bloque 2 "Pulido Multi-Sede y Alertas de Suscripción")
--
-- CIERRA DOS PENDIENTES QUE YA ESTABAN ESCRITOS
--
-- 1. D-189 puso el tope de equipo en 9 cuentas (+ el dueño = 10 personas),
--    pero avisó en su propio comentario: "el tope es POR NEGOCIO, no por
--    sede... será cierto cuando la Etapa 2 haga la suscripción por sede". La
--    Etapa 2 (D-190) ya existe desde hoy más temprano. Toca cumplir la
--    promesa: `(límite_por_sede * número_de_sedes_activas)`.
--
-- 2. El HANDOFF de D-195 (apartado 3.1) dejó escrito: "Una sede secundaria
--    que se atrase no genera aviso" -- `send-subscription-expiry-alerts`
--    solo mira `tenant_subscriptions`.
--
-- ---------------------------------------------------------------------------
-- PARTE 1: EL TOPE DE EQUIPO CUENTA LAS SEDES ACTIVAS
-- ---------------------------------------------------------------------------
--
-- LA CUENTA, CON EL MISMO CUIDADO QUE LA DE D-189
--
-- El encargo pide "límite_por_sede * número_de_sedes_activas". La sede
-- PRINCIPAL no se cuenta mirando `branch_subscriptions.status`: **ese estado
-- solo lo mantiene al día el flujo NUEVO de pago por sede (D-192)**, y la
-- principal de la inmensa mayoría de los negocios se sigue pagando por el
-- flujo VIEJO (`beautyos_procesar_evento_epayco`, D-159/D-182), que nunca
-- toca `branch_subscriptions` -- se comprobó antes de escribir esto: ninguna
-- otra migración la toca (`grep -rn "branch_subscriptions" supabase/
-- migrations/*.sql` solo devuelve las de la Etapa 2/3 de D-188). Contar la
-- principal por su `branch_subscriptions.status` la dejaría "pending" para
-- siempre en la mayoría de los negocios y el tope se iría a cero: justo lo
-- contrario de lo que pide el encargo.
--
-- Por eso la principal cuenta SIEMPRE que el negocio esté `entitled` -- lo
-- que ya exige no estar `pending` ni `cancelled`, ver
-- `beautyos_resolve_entitlement` --: es exactamente el mismo criterio que ya
-- se usaba antes de este cambio, así que **cero regresión para el salón de
-- una sola sede**. Las secundarias sí cuentan por su propio
-- `branch_subscriptions.status in ('active', 'trialing')`, porque esas SOLO
-- se activan por el flujo nuevo (D-192), que a esas sí las mantiene al día.
--
-- Un salón con 1 sede: 9 * 1 = 9 cuentas de equipo (+ el dueño = 10 personas,
-- sin cambios). Un salón con 2 sedes pagadas: 9 * 2 = 18 (+ el dueño = 19...
-- el encargo dice 20, contando al dueño como una persona más por sede, pero
-- D-136 y D-189 ya dejaron escrito que el dueño es UNA sola cuenta que no
-- cuenta contra ningún tope, sea cual sea el número de sedes: no se duplica
-- por sede porque no es una cuenta de equipo, es el negocio entero).
--
-- ---------------------------------------------------------------------------
-- PARTE 2: ALERTAS DE VENCIMIENTO TAMBIÉN POR SEDE SECUNDARIA
-- ---------------------------------------------------------------------------
--
-- Se reutiliza la MISMA tabla de log (`subscription_notification_logs`) y el
-- MISMO cálculo por días de calendario que ya existían para el negocio
-- (D-143), en vez de inventar una segunda tabla o una segunda lógica: la
-- única diferencia real es la tabla de origen (`branch_subscriptions` en vez
-- de `tenant_subscriptions`) y que la principal queda fuera, porque su
-- vencimiento ya lo cubre la alerta del negocio.
--
-- **No se toca `beautyos_suspender_suscripciones_vencidas()`.** Este bloque
-- es de ALERTAS, no de suspensión automática: hoy ninguna sede secundaria se
-- suspende sola al agotar su gracia (solo el negocio completo). Construir esa
-- suspensión automática por sede es un cambio de comportamiento más grande
-- que el encargo no pidió, y queda anotado como pendiente en el HANDOFF.
--
-- POR QUÉ DOS ÍNDICES PARCIALES Y NO UN UNIQUE CON `branch_id`
--
-- El candado de siempre es `UNIQUE (tenant_id, notification_type,
-- reference_date)`. Añadirle `branch_id` sin más lo habría vuelto inútil
-- para las alertas del NEGOCIO: un `UNIQUE` normal trata cada `NULL` como
-- distinto de los demás, así que con `branch_id` NULL en todas las alertas de
-- negocio, Postgres dejaría insertar el mismo aviso del mismo negocio varias
-- veces el mismo día -- justo lo que este candado existe para impedir. Dos
-- índices parciales lo resuelven sin depender de `NULLS NOT DISTINCT`
-- (Postgres 15+, no se puede dar por hecho la versión del proyecto): uno
-- para `branch_id IS NULL` (igual que hasta hoy) y otro para `branch_id IS
-- NOT NULL` (uno por sede).

begin;

-- ---------------------------------------------------------------------------
-- 1. El ayudante de tope de equipo, hermano de `beautyos_require_limit`
-- ---------------------------------------------------------------------------
--
-- No se modifica `beautyos_require_limit`: la comparten `create_branch`
-- (capacidad "branches") y `create_team_invitation`, y multiplicar por sedes
-- activas no tiene sentido para el tope de SEDES -- sería una sede
-- necesitando sedes para poder existir. Por eso el multiplicador vive en un
-- ayudante aparte, solo para `team_members`.

create or replace function private.beautyos_require_team_limit(
  p_tenant_id uuid,
  p_actual integer
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v record;
  v_sedes_activas integer;
  v_limite_efectivo integer;
begin
  select * into v
  from private.beautyos_resolve_entitlement(p_tenant_id, 'team_members');

  if v is null or not v.entitled then
    raise exception 'Tu plan no incluye cuentas de equipo.';
  end if;

  -- NULO = SIN LIMITE (D-136). Sigue significando lo mismo aquí: no hay nada
  -- que multiplicar.
  if v.limit_value is null then
    return;
  end if;

  -- La principal cuenta siempre (ya se comprobó "entitled" arriba, que exige
  -- una suscripción que no esté pending/cancelled). Las secundarias cuentan
  -- solo si su propia suscripción de sede está activa o en prueba.
  select 1 + coalesce((
    select count(*)
    from public.branches b
    join public.branch_subscriptions bs on bs.branch_id = b.id
    where b.tenant_id = p_tenant_id
      and b.is_primary = false
      and bs.status in ('active', 'trialing')
  ), 0)
  into v_sedes_activas;

  v_limite_efectivo := v.limit_value * v_sedes_activas;

  if p_actual >= v_limite_efectivo then
    raise exception
      'Tu plan permite hasta % cuentas de equipo por sede activa (% sede(s) activa(s) -> % en total). Ya tienes %. Escribenos si necesitas mas: el limite se puede ampliar sin cambiar de plan.',
      v.limit_value, v_sedes_activas, v_limite_efectivo, p_actual;
  end if;
end;
$$;

revoke all on function private.beautyos_require_team_limit(uuid, integer) from public, anon, authenticated;
grant execute on function private.beautyos_require_team_limit(uuid, integer) to service_role;

comment on function private.beautyos_require_team_limit(uuid, integer) is
  'Como beautyos_require_limit, pero el tope de team_members se multiplica por las sedes activas del negocio (D-196): la principal cuenta si el negocio esta entitled (mismo criterio de siempre), las secundarias por su propio branch_subscriptions.status. Vive aparte de beautyos_require_limit porque esa la comparte create_branch, donde multiplicar por sedes no tiene sentido. NO ELIMINAR.';

-- ---------------------------------------------------------------------------
-- 2. Se hace cumplir al invitar a alguien al equipo
-- ---------------------------------------------------------------------------
--
-- Copia exacta de la versión del 12-ago (D-136) cambiando solo la llamada al
-- límite. Se conservan sin tocar TODAS sus protecciones: correo válido, rol
-- permitido, estilista activo en la sede, el candado del hallazgo R, la
-- invitación pendiente por estilista, que el correo no pertenezca ya a un
-- negocio, y la invitación pendiente por correo.

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

  -- Cuentas activas del equipo + invitaciones pendientes (paso 3.5, D-136).
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

  -- CAMBIO DE D-196: antes llamaba a beautyos_require_limit con el tope
  -- plano del plan; ahora llama al ayudante que lo multiplica por sedes
  -- activas.
  perform private.beautyos_require_team_limit(v_tenant_id, v_equipo);

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

-- ---------------------------------------------------------------------------
-- 3. El log de alertas aprende de sedes
-- ---------------------------------------------------------------------------

alter table public.subscription_notification_logs
  add column if not exists branch_id uuid references public.branches(id) on delete cascade;

comment on column public.subscription_notification_logs.branch_id is
  'NULL = alerta del negocio (tenant_subscriptions), como siempre. Con valor = alerta de UNA sede secundaria (D-196).';

alter table public.subscription_notification_logs
  drop constraint if exists subscription_notification_logs_unique_day;

create unique index if not exists subscription_notification_logs_unique_day_tenant_uidx
  on public.subscription_notification_logs (tenant_id, notification_type, reference_date)
  where branch_id is null;

create unique index if not exists subscription_notification_logs_unique_day_branch_uidx
  on public.subscription_notification_logs (tenant_id, notification_type, reference_date, branch_id)
  where branch_id is not null;

-- ---------------------------------------------------------------------------
-- 4. Registrar una alerta enviada, con sede opcional
-- ---------------------------------------------------------------------------
--
-- Parametro nuevo AL FINAL y con default -- pero eso NO es un simple
-- `create or replace`. En Postgres, (uuid, uuid, text, text, jsonb) y
-- (uuid, uuid, text, text, jsonb, uuid) son DOS FIRMAS DISTINTAS: sin el
-- `drop function` de abajo, esto habria dejado DOS funciones conviviendo
-- (la vieja de 5 argumentos intacta, con sus propios permisos) en vez de
-- reemplazarla -- exactamente la trampa que D-174 ya documento para
-- `beautyos_can_upload_work_photo`. Se elimina primero la firma vieja y
-- luego se crea la nueva con el parametro extra.

drop function if exists private.beautyos_registrar_alerta_enviada(uuid, uuid, text, text, jsonb);

create or replace function private.beautyos_registrar_alerta_enviada(
  p_tenant_id uuid,
  p_subscription_id uuid,
  p_notification_type text,
  p_recipient_email text,
  p_metadata jsonb default '{}'::jsonb,
  p_branch_id uuid default null
)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  insert into public.subscription_notification_logs (
    tenant_id,
    tenant_subscription_id,
    notification_type,
    recipient_email,
    reference_date,
    metadata,
    branch_id
  ) values (
    p_tenant_id,
    p_subscription_id,
    p_notification_type,
    p_recipient_email,
    current_date,
    coalesce(p_metadata, '{}'::jsonb),
    p_branch_id
  )
  on conflict do nothing; -- uno de los dos indices parciales de la seccion 3

  return true;
end;
$$;

revoke all on function private.beautyos_registrar_alerta_enviada(uuid, uuid, text, text, jsonb, uuid) from public, anon, authenticated;
grant execute on function private.beautyos_registrar_alerta_enviada(uuid, uuid, text, text, jsonb, uuid) to service_role;

-- ---------------------------------------------------------------------------
-- 5. Las alertas pendientes, pero de sedes secundarias
-- ---------------------------------------------------------------------------
--
-- Hermana de `beautyos_obtener_alertas_suscripcion_pendientes` (D-143): mismo
-- calculo por dias de calendario, mismo filtro anti-spam contra el mismo log,
-- pero leyendo `branch_subscriptions` en vez de `tenant_subscriptions` y
-- excluyendo la principal (su vencimiento ya lo cubre la alerta del negocio).
--
-- No incluye el caso "suspended": ninguna sede secundaria se suspende sola
-- todavia (ver nota de la cabecera). Avisar de una sede "suspendida" que
-- nunca se suspendio solo confundiria al dueno.

create or replace function private.beautyos_obtener_alertas_sede_pendientes()
returns table (
  tenant_id uuid,
  tenant_name text,
  recipient_email text,
  owner_name text,
  branch_id uuid,
  branch_name text,
  branch_subscription_id uuid,
  notification_type text,
  days_remaining integer,
  expiry_date timestamptz,
  price_cop bigint
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  return query
  with due_owners as (
    select distinct on (tm.tenant_id)
      tm.tenant_id,
      u.email as owner_user_email,
      coalesce(up.full_name, u.raw_user_meta_data->>'full_name', 'Propietario(a)') as owner_full_name
    from public.tenant_memberships tm
    join auth.users u on u.id = tm.user_id
    left join public.user_profiles up on up.id = tm.user_id
    where tm.role in ('owner', 'tenant_owner')
      and tm.active
    order by tm.tenant_id, tm.created_at asc
  ),
  candidatos as (
    select
      t.id as c_tenant_id,
      t.name as c_tenant_name,
      coalesce(t.contact_email, dow.owner_user_email) as c_recipient_email,
      coalesce(dow.owner_full_name, 'Propietario(a)') as c_owner_name,
      b.id as c_branch_id,
      b.name as c_branch_name,
      bs.id as c_branch_subscription_id,
      coalesce(bs.price_cop, p.price_cop) as c_price_cop,
      bs.trial_ends_at,
      bs.current_period_end,
      bs.grace_ends_at,

      case
        when bs.status = 'trialing' and bs.trial_ends_at is not null then
          case
            when (bs.trial_ends_at::date - current_date) = 10 then 'trial_10d'
            when (bs.trial_ends_at::date - current_date) = 5 then 'trial_5d'
            when (bs.trial_ends_at::date - current_date) = 3 then 'trial_3d'
            when (bs.trial_ends_at::date - current_date) <= 1 and (bs.trial_ends_at::date - current_date) >= 0 then 'trial_1d'
            else null
          end

        when bs.status = 'active' and bs.current_period_end is not null then
          case
            when (bs.current_period_end::date - current_date) = 5 then 'period_5d'
            when (bs.current_period_end::date - current_date) = 3 then 'period_3d'
            when (bs.current_period_end::date - current_date) <= 1 and (bs.current_period_end::date - current_date) >= 0 then 'period_1d'
            else null
          end

        when bs.status in ('past_due', 'grace') and bs.grace_ends_at is not null and bs.grace_ends_at > now() then
          case
            when (bs.grace_ends_at::date - current_date) >= 5 then 'grace_day_1'
            when (bs.grace_ends_at::date - current_date) = 4 then 'grace_day_2'
            when (bs.grace_ends_at::date - current_date) = 3 then 'grace_day_3'
            when (bs.grace_ends_at::date - current_date) = 2 then 'grace_day_4'
            when (bs.grace_ends_at::date - current_date) <= 1 then 'grace_day_5'
            else null
          end

        else null
      end as c_notification_type,

      case
        when bs.status = 'trialing' then (bs.trial_ends_at::date - current_date)
        when bs.status = 'active' then (bs.current_period_end::date - current_date)
        when bs.status in ('past_due', 'grace') then (bs.grace_ends_at::date - current_date)
        else 0
      end as c_days_remaining,

      case
        when bs.status = 'trialing' then bs.trial_ends_at
        when bs.status = 'active' then bs.current_period_end
        when bs.status in ('past_due', 'grace') then bs.grace_ends_at
        else bs.updated_at
      end as c_expiry_date

    from public.branches b
    join public.branch_subscriptions bs on bs.branch_id = b.id
    join public.tenants t on t.id = b.tenant_id
    join public.tenant_subscriptions ts on ts.tenant_id = t.id
    join public.plans p on p.id = ts.plan_id
    left join due_owners dow on dow.tenant_id = t.id
    where t.is_demo = false
      and b.is_primary = false
  )
  select
    c.c_tenant_id,
    c.c_tenant_name,
    c.c_recipient_email,
    c.c_owner_name,
    c.c_branch_id,
    c.c_branch_name,
    c.c_branch_subscription_id,
    c.c_notification_type,
    greatest(0, c.c_days_remaining),
    c.c_expiry_date,
    c.c_price_cop
  from candidatos c
  where c.c_notification_type is not null
    and c.c_recipient_email is not null
    and not exists (
      select 1
      from public.subscription_notification_logs snl
      where snl.tenant_id = c.c_tenant_id
        and snl.notification_type = c.c_notification_type
        and snl.reference_date = current_date
        and snl.branch_id = c.c_branch_id
    );
end;
$$;

revoke all on function private.beautyos_obtener_alertas_sede_pendientes() from public, anon, authenticated;
grant execute on function private.beautyos_obtener_alertas_sede_pendientes() to service_role;

comment on function private.beautyos_obtener_alertas_sede_pendientes() is
  'Hermana de beautyos_obtener_alertas_suscripcion_pendientes (D-143), pero para sedes SECUNDARIAS via branch_subscriptions (D-196). La principal no entra: su vencimiento ya lo cubre la alerta del negocio. NO ELIMINAR.';

commit;
