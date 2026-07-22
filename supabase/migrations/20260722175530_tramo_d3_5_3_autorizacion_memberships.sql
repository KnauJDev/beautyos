-- BeautyOS - Tramo D3.5.3
-- Cierra NC-D-04: la autorizacion heredada basada en user_profiles.role
-- se reemplaza por tenant_memberships (ADR-002) en toda funcion cuyo
-- proposito es autorizar, no identificar.
--
-- Alcance:
-- 1. Los 3 helpers de autorizacion (get_my_tenant_id, get_my_role,
--    is_owner_or_admin) leen ahora tenant_memberships con vigencia
--    (active, starts_at, ends_at), igual que beautyos_resolve_branch_access.
-- 2. get_tenant_users y update_tenant_user_access usan esos helpers para
--    autorizar en vez de repetir una consulta inline a user_profiles.
-- 3. update_tenant_user_access ahora tambien sincroniza tenant_memberships
--    cuando cambia el rol o el estado de un usuario, evitando que el
--    modelo de membresias quede desactualizado frente a user_profiles.
-- 4. create_client reemplaza su verificacion inline de user_profiles por
--    tenant_memberships con el mismo conjunto de roles (tenant_owner,
--    admin, assistant).
--
-- Fuera de alcance (decision explicita, no un olvido):
-- - user_profiles sigue siendo la identidad global del usuario (D-010):
--   full_name, email de auth.users y el propio rol legado se conservan
--   para lectura/visualizacion en get_tenant_users y get_my_profile.
-- - Las 24 rutas operativas heredadas sin consumidor (add_ticket_service,
--   create_ticket, create_scheduled_ticket_with_service,
--   get_available_appointment_slots, get_my_stylist_agenda_by_date,
--   get_ticket_service_options, etc.) siguen citando user_profiles en su
--   cuerpo, pero ya quedaron sin EXECUTE para authenticated/anon desde
--   D3.5.2 y estan propuestas para retiro completo (Tramo D3.0, 3.1).
--   Reescribirlas ahora duplicaria trabajo que su propio retiro hara
--   innecesario; su cierre formal es un micro-paso aparte.

begin;

-- 1. Helpers de autorizacion sobre tenant_memberships.

create or replace function public.get_my_tenant_id()
returns uuid
language sql
security definer
set search_path = pg_catalog
as $$
  select tm.tenant_id
  from public.tenant_memberships tm
  where tm.user_id = auth.uid()
    and tm.active
    and tm.starts_at <= now()
    and (tm.ends_at is null or tm.ends_at > now())
  order by tm.starts_at asc
  limit 1;
$$;

create or replace function public.get_my_role()
returns text
language sql
security definer
set search_path = pg_catalog
as $$
  select tm.role
  from public.tenant_memberships tm
  where tm.user_id = auth.uid()
    and tm.active
    and tm.starts_at <= now()
    and (tm.ends_at is null or tm.ends_at > now())
  order by tm.starts_at asc
  limit 1;
$$;

create or replace function public.is_owner_or_admin()
returns boolean
language sql
security definer
set search_path = pg_catalog
as $$
  select exists (
    select 1
    from public.tenant_memberships tm
    where tm.user_id = auth.uid()
      and tm.active
      and tm.starts_at <= now()
      and (tm.ends_at is null or tm.ends_at > now())
      and tm.role in ('tenant_owner', 'admin')
  );
$$;

-- 2 y 3. Gestion de usuarios del tenant: autorizar via memberships y
-- mantener tenant_memberships sincronizado con cada cambio de acceso.

create or replace function public.get_tenant_users()
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
declare
  v_tenant_id uuid;
  v_role text;
begin
  v_tenant_id := public.get_my_tenant_id();
  v_role := public.get_my_role();

  if v_tenant_id is null or v_role <> 'tenant_owner' then
    raise exception 'Solo el propietario puede administrar usuarios.';
  end if;

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
  where up.tenant_id = v_tenant_id
  order by
    case up.role when 'owner' then 0 else 1 end,
    up.full_name asc;
end;
$$;

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
begin
  v_tenant_id := public.get_my_tenant_id();
  v_role := public.get_my_role();

  if v_tenant_id is null or v_role <> 'tenant_owner' then
    raise exception 'Solo el propietario puede modificar accesos.';
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

-- 4. create_client: autorizacion inline sobre tenant_memberships.

create or replace function public.create_client(
  p_name text,
  p_phone text,
  p_email text default null,
  p_notes text default null
)
returns setof public.clients
language sql
security definer
set search_path = pg_catalog
as $$
  insert into public.clients (
    tenant_id,
    name,
    phone,
    email,
    notes
  )
  select
    tm.tenant_id,
    trim(p_name),
    trim(p_phone),
    nullif(trim(coalesce(p_email, '')), ''),
    nullif(trim(coalesce(p_notes, '')), '')
  from public.tenant_memberships tm
  where tm.user_id = auth.uid()
    and tm.active
    and tm.starts_at <= now()
    and (tm.ends_at is null or tm.ends_at > now())
    and tm.role in ('tenant_owner', 'admin', 'assistant')
    and length(trim(coalesce(p_name, ''))) > 0
    and length(trim(coalesce(p_phone, ''))) > 0
  order by tm.starts_at asc
  limit 1
  returning *;
$$;

-- Privilegios explicitos (sin cambios de superficie, solo reafirmacion).

revoke all on function public.get_my_role() from public, anon;
revoke all on function public.get_my_tenant_id() from public, anon;
revoke all on function public.is_owner_or_admin() from public, anon;
revoke all on function public.get_tenant_users() from public, anon;
revoke all on function public.update_tenant_user_access(uuid, text, boolean) from public, anon;
revoke all on function public.create_client(text, text, text, text) from public, anon;

grant execute on function public.get_my_role() to authenticated, service_role;
grant execute on function public.get_my_tenant_id() to authenticated, service_role;
grant execute on function public.is_owner_or_admin() to authenticated, service_role;
grant execute on function public.get_tenant_users() to authenticated, service_role;
grant execute on function public.update_tenant_user_access(uuid, text, boolean) to authenticated, service_role;
grant execute on function public.create_client(text, text, text, text) to authenticated, service_role;

commit;
