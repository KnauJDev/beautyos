-- Salon y Mas - Un estilista del catalogo, una sola cuenta activa (hallazgo R).
--
-- EL PROBLEMA, encontrado por el propietario el 10-ago: invito a `elboga010`
-- vinculandolo a "Erick Chaparro", que ya tenia cuenta con `elboga005`.
-- Quedaron dos usuarios apuntando al mismo estilista del catalogo. **No es
-- cosmetico:** las dos cuentas ven la misma agenda, las mismas comisiones y
-- las mismas fotos, porque todo cuelga del `stylist_id`, y no hay forma de
-- saber cual es la persona real.
--
-- POR QUE PASABA. `create_team_invitation` comprobaba cuatro cosas -- correo
-- valido, rol valido, estilista activo en la sede, y que el correo no
-- perteneciera ya a un negocio -- pero **ninguna miraba si ese estilista ya
-- tenia cuenta**. Y no habia red debajo: `tenant_memberships.stylist_id` solo
-- tenia indices normales, ninguno unico.
--
-- SOLO CUENTAS ACTIVAS, decidido por el propietario y por un motivo concreto:
-- si a una estilista le bloquean o le hackean el correo, hay que poder
-- desactivar su cuenta e invitarla con otro. **Un candado absoluto dejaria ese
-- caso sin salida.** Se descarto por eso.
--
-- Y LO QUE HACE QUE ESO FUNCIONE, verificado en el esquema real el 11-ago:
-- **el historial cuelga del estilista, no de la cuenta.** `ticket_services`,
-- `stylist_commissions`, `reviews` y `work_photos` guardan `stylist_id` y
-- **ninguna guarda `user_id`**. Asi que desactivar la cuenta vieja e invitar
-- una nueva al mismo estilista **conserva todo automaticamente**: no hay nada
-- que trasladar. Por eso no se construye ningun "traslado de historial".
--
-- SE CIERRAN LOS TRES CAMINOS, no solo el evidente:
--   (1) invitar          -> se rechaza al crear la invitacion
--   (2) aceptar          -> se vuelve a comprobar, por si la invitacion se
--                           creo antes de este candado o hay dos pendientes
--   (3) reactivar        -> reactivar una cuenta suspendida cuyo estilista lo
--                           tomo otra mientras tanto. **Es el caso real de
--                           Erick Chaparro** si algun dia se reactiva la
--                           suspendida.
-- Los tres dan un mensaje que explica que hacer. El indice unico es la red:
-- aunque manana alguien escriba un cuarto camino, ahi se para.

begin;

-- ---------------------------------------------------------------------------
-- 0. Precondicion: si YA hay duplicados activos, parar y decir cuales.
--
-- No se aplica nada a ciegas. Si esto salta, el indice del paso 1 fallaria
-- igual pero con un mensaje que no dice quien es quien.
-- ---------------------------------------------------------------------------

do $$
declare
  v_duplicados text;
begin
  -- Se agrupa por (negocio, estilista) y NO por nombre. Agrupar por nombre
  -- juntaria a dos "Maria" de negocios distintos, cada una con UNA cuenta, y
  -- abortaria la migracion por un duplicado que no existe.
  select string_agg(
           format('%s (%s cuentas activas)',
                  coalesce(st.name, d.stylist_id::text), d.cuentas),
           '; '
         )
    into v_duplicados
  from (
    select tm.tenant_id, tm.stylist_id, count(*) as cuentas
    from public.tenant_memberships tm
    where tm.stylist_id is not null
      and tm.active = true
    group by tm.tenant_id, tm.stylist_id
    having count(*) > 1
  ) d
  left join public.stylists st on st.id = d.stylist_id;

  if v_duplicados is not null then
    raise exception
      'No se puede aplicar: ya hay estilistas con mas de una cuenta ACTIVA -> %. Desactiva las sobrantes en Usuarios y vuelve a ejecutar esta migracion.',
      v_duplicados;
  end if;
end
$$;

-- ---------------------------------------------------------------------------
-- 1. El candado.
--
-- Va sobre `tenant_memberships`, que es POR NEGOCIO y no por sede: una persona
-- tiene una cuenta en el negocio, y esa cuenta se conecta a las sedes aparte
-- (`branch_memberships`). Asi la regla vale igual con una sede que con cinco.
--
-- `where ... and active` es lo que deja libre al estilista cuando su cuenta se
-- desactiva. Sin esa condicion, cambiar de correo seria imposible.
-- ---------------------------------------------------------------------------

create unique index if not exists tenant_memberships_estilista_cuenta_activa_idx
  on public.tenant_memberships (tenant_id, stylist_id)
  where stylist_id is not null and active = true;

comment on index public.tenant_memberships_estilista_cuenta_activa_idx is
  'Hallazgo R: un estilista del catalogo no puede tener dos cuentas ACTIVAS en el mismo negocio. Solo cuentas activas, para que cambiar de correo siga siendo posible.';

-- ---------------------------------------------------------------------------
-- 2. Al invitar.
--
-- Copia exacta de la version del 23-jul (`20260723173701`) mas el bloque
-- nuevo. Se conservan las cuatro comprobaciones originales sin tocar una coma:
-- correo valido, rol permitido, estilista activo en la sede, correo que no
-- pertenezca ya a un negocio, e invitacion pendiente para ese correo.
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

    -- NUEVO (hallazgo R). El mensaje dice que hacer, no solo que no se puede:
    -- quien lee esto casi siempre esta intentando cambiarle el correo a
    -- alguien, y el camino correcto no es evidente.
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
-- 3. Al aceptar.
--
-- Hace falta aunque el paso 2 ya rechace: puede haber invitaciones creadas
-- ANTES de esta migracion, y dos personas podrian aceptar a la vez. El indice
-- unico atraparia la segunda, pero con un error de base de datos ilegible.
--
-- Copia exacta de la version del 23-jul mas el bloque nuevo. Se conservan las
-- tres comprobaciones originales y los tres `insert` en el mismo orden.
-- ---------------------------------------------------------------------------

create or replace function public.accept_team_invitation(
  p_full_name text
)
returns table (
  tenant_id uuid,
  branch_id uuid,
  role text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_email text;
  v_invitation public.team_invitations%rowtype;
  v_tenant_membership_id uuid;
begin
  if v_user_id is null then
    raise exception 'Se requiere una sesion autenticada.';
  end if;

  if exists (
    select 1 from public.tenant_memberships where user_id = v_user_id
  ) then
    raise exception 'Este usuario ya pertenece a un negocio.';
  end if;

  if length(trim(coalesce(p_full_name, ''))) = 0 then
    raise exception 'Tu nombre completo es obligatorio.';
  end if;

  select email into v_email from auth.users where id = v_user_id;

  select *
    into v_invitation
  from public.team_invitations
  where lower(email) = lower(coalesce(v_email, ''))
    and status = 'pending'
    and expires_at > now()
  order by created_at desc
  limit 1;

  if v_invitation.id is null then
    raise exception 'No encontramos una invitacion pendiente para este correo.';
  end if;

  -- NUEVO (hallazgo R). El mensaje va dirigido al invitado, que no puede
  -- arreglarlo por su cuenta: se le dice a quien pedirselo.
  if v_invitation.stylist_id is not null and exists (
    select 1
    from public.tenant_memberships tm
    where tm.tenant_id = v_invitation.tenant_id
      and tm.stylist_id = v_invitation.stylist_id
      and tm.active = true
  ) then
    raise exception 'Esta invitacion no se puede aceptar: ese estilista ya tiene otra cuenta activa en el negocio. Pidele al dueno o al administrador que lo revise.';
  end if;

  insert into public.user_profiles (
    tenant_id, user_id, full_name, role, stylist_id, active
  ) values (
    v_invitation.tenant_id, v_user_id, trim(p_full_name),
    v_invitation.role, v_invitation.stylist_id, true
  );

  insert into public.tenant_memberships (
    tenant_id, user_id, role, stylist_id, active, starts_at, created_by
  ) values (
    v_invitation.tenant_id, v_user_id, v_invitation.role,
    v_invitation.stylist_id, true, now(), v_invitation.invited_by
  )
  returning id into v_tenant_membership_id;

  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, created_by
  ) values (
    v_invitation.tenant_id, v_invitation.branch_id, v_tenant_membership_id,
    true, v_invitation.invited_by
  );

  update public.team_invitations
     set status = 'accepted', accepted_by = v_user_id, accepted_at = now()
   where id = v_invitation.id;

  return query
  select v_invitation.tenant_id, v_invitation.branch_id, v_invitation.role;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Al reactivar una cuenta suspendida.
--
-- Este es el caso real que dejo el 10-ago: `elboga010` quedo suspendida y
-- `elboga005` sigue activa, las dos apuntando a "Erick Chaparro". Reactivar la
-- suspendida chocaria contra el indice unico y soltaria un error de base de
-- datos. Aqui se para antes y se dice por que.
--
-- Copia exacta de la version del 26-jul (`20260726120000`) mas el bloque
-- nuevo. Se conservan las protecciones originales: nadie modifica su propia
-- cuenta, la del propietario esta protegida, y un estilista sin vinculo no
-- puede tomar ese rol. Se conserva tambien el registro en
-- `user_profile_access_history`.
-- ---------------------------------------------------------------------------

create or replace function public.update_tenant_user_access(
  p_profile_id uuid,
  p_role text,
  p_active boolean
)
returns table (
  profile_id uuid,
  user_id uuid,
  full_name text,
  email text,
  role text,
  active boolean,
  stylist_id uuid,
  stylist_name text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
#variable_conflict use_column
declare
  v_tenant_id uuid;
  v_role text;
  v_new_role text;
  v_target public.user_profiles%rowtype;
  v_ocupado_por text;
begin
  v_tenant_id := public.get_my_tenant_id();
  v_role := public.get_my_role();

  if v_tenant_id is null or v_role not in ('tenant_owner', 'admin') then
    raise exception 'Solo el propietario o un administrador pueden modificar accesos.';
  end if;

  if p_profile_id is null or p_active is null then
    raise exception 'El usuario y su estado son obligatorios.';
  end if;

  v_new_role := lower(trim(coalesce(p_role, '')));

  if v_new_role not in ('admin', 'stylist', 'assistant', 'client') then
    raise exception 'El rol seleccionado no es valido.';
  end if;

  select *
    into v_target
  from public.user_profiles up
  where up.id = p_profile_id
    and up.tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'Usuario no encontrado o no pertenece al centro actual.';
  end if;

  if v_target.user_id = auth.uid() then
    raise exception 'No puedes modificar tu propio acceso.';
  end if;

  if v_target.role = 'owner' then
    raise exception 'La cuenta del propietario esta protegida.';
  end if;

  if v_new_role = 'stylist' and v_target.stylist_id is null then
    raise exception 'Primero vincula este usuario a un perfil de estilista.';
  end if;

  -- NUEVO (hallazgo R). Solo aplica al ACTIVAR: desactivar nunca puede crear
  -- un duplicado, y se excluye a la propia cuenta para que guardar sin
  -- cambios no se rechace a si mismo.
  if p_active = true
     and v_new_role <> 'client'
     and v_target.stylist_id is not null then
    select coalesce(up.full_name, au.email)
      into v_ocupado_por
    from public.tenant_memberships tm
    left join public.user_profiles up
      on up.user_id = tm.user_id
     and up.tenant_id = tm.tenant_id
    left join auth.users au
      on au.id = tm.user_id
    where tm.tenant_id = v_tenant_id
      and tm.stylist_id = v_target.stylist_id
      and tm.active = true
      and tm.user_id <> v_target.user_id
    limit 1;

    if v_ocupado_por is not null then
      raise exception
        'No se puede activar esta cuenta: ese estilista del catalogo ya tiene otra cuenta activa (%). Desactiva primero la otra.',
        v_ocupado_por;
    end if;
  end if;

  update public.user_profiles up
     set role = v_new_role,
         active = p_active,
         updated_at = now()
   where up.id = v_target.id
     and up.tenant_id = v_tenant_id;

  if v_new_role = 'client' then
    update public.tenant_memberships tm
       set active = false,
           updated_at = now()
     where tm.tenant_id = v_tenant_id
       and tm.user_id = v_target.user_id;
  else
    insert into public.tenant_memberships (
      tenant_id,
      user_id,
      stylist_id,
      role,
      active,
      starts_at,
      created_by
    ) values (
      v_tenant_id,
      v_target.user_id,
      v_target.stylist_id,
      v_new_role,
      p_active,
      now(),
      auth.uid()
    )
    on conflict (tenant_id, user_id) do update
      set role = excluded.role,
          stylist_id = excluded.stylist_id,
          active = excluded.active,
          updated_at = now();
  end if;

  insert into public.user_profile_access_history (
    tenant_id,
    profile_id,
    target_user_id,
    previous_role,
    new_role,
    previous_active,
    new_active,
    changed_by
  ) values (
    v_tenant_id,
    v_target.id,
    v_target.user_id,
    v_target.role,
    v_new_role,
    v_target.active,
    p_active,
    auth.uid()
  );

  return query
  select
    up.id,
    up.user_id,
    up.full_name,
    coalesce(au.email, '')::text,
    up.role,
    up.active,
    up.stylist_id,
    s.name,
    up.created_at
  from public.user_profiles up
  left join auth.users au
    on au.id = up.user_id
  left join public.stylists s
    on s.id = up.stylist_id
   and s.tenant_id = v_tenant_id
  where up.id = v_target.id
    and up.tenant_id = v_tenant_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Una funcion NUEVA para la lista de invitar. `get_stylists_summary` NO se
--    toca.
--
-- POR QUE UNA NUEVA Y NO AMPLIAR LA QUE HAY. Agregarle una columna obliga a
-- borrarla y recrearla -- PostgreSQL no deja cambiar la forma de lo que
-- devuelve con `create or replace` --, y **borrarla pierde sus permisos**. Se
-- intento leerlos del respaldo del 11-ago y **el volcado no los trae**: se
-- hace sin permisos, cero `GRANT` en todo el archivo. Recrearlos habria sido
-- inventarselos, y ese es exactamente el fallo de D-122: un permiso a medias
-- que nadie ve hasta que alguien no puede trabajar.
--
-- Y ADEMAS SALE MEJOR, porque arregla un desajuste que ya existia: la lista
-- del dialogo mostraba **todos los estilistas del negocio**, mientras que
-- `create_team_invitation` exige que el estilista este activo **en esa sede**.
-- Con dos sedes se podia elegir a alguien que no trabaja en la seleccionada y
-- llevarse un error despues de llenar el formulario. Esta funcion recibe la
-- sede y responde por ella.
--
-- Devuelve la marca en vez de esconder al ocupado, para que la pantalla pueda
-- distinguir dos situaciones distintas: "no hay estilistas en esta sede" y
-- "todos los de esta sede ya tienen cuenta".
-- ---------------------------------------------------------------------------

create or replace function public.get_stylists_for_invitation(p_branch_id uuid)
returns table (
  id uuid,
  name text,
  has_active_account boolean
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  -- Misma autorizacion que `create_team_invitation` y `list_team_invitations`:
  -- quien puede invitar es quien puede ver a quien invitar.
  select tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner', 'admin'], true
  );

  return query
  select
    st.id,
    st.name,
    exists (
      select 1
      from public.tenant_memberships tm
      where tm.tenant_id = v_tenant_id
        and tm.stylist_id = st.id
        and tm.active = true
    ) as has_active_account
  from public.branch_stylists bst
  join public.stylists st
    on st.id = bst.stylist_id
   and st.tenant_id = bst.tenant_id
  where bst.tenant_id = v_tenant_id
    and bst.branch_id = p_branch_id
    and bst.active = true
    and st.active = true
  order by st.name asc;
end;
$$;

revoke all on function public.get_stylists_for_invitation(uuid) from public, anon;
grant execute on function public.get_stylists_for_invitation(uuid) to authenticated, service_role;

commit;
