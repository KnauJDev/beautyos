-- BeautyOS - Un administrador tambien puede gestionar usuarios.
--
-- El propietario confirmo que gestionar usuarios (ver la lista, cambiar
-- rol, activar/desactivar) si deberia ser una funcion normal de admin,
-- no solo del dueno -- corrige el planteamiento original (D-070 aclaro
-- que hoy era exclusivo de tenant_owner por diseno, no por bug). Se
-- amplia la autorizacion de get_tenant_users/update_tenant_user_access
-- para aceptar tambien 'admin', igual que ya acepta create_team_invitation
-- desde D-050. Las protecciones existentes se conservan sin cambios: nadie
-- puede modificar su propia cuenta ni la del propietario.

begin;

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

  if v_tenant_id is null or v_role not in ('tenant_owner', 'admin') then
    raise exception 'Solo el propietario o un administrador pueden administrar usuarios.';
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

commit;
