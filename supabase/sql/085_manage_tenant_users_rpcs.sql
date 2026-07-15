-- Paso 1037: administración segura de usuarios existentes del centro.

create table if not exists public.user_profile_access_history (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  profile_id uuid not null references public.user_profiles(id) on delete restrict,
  target_user_id uuid not null,
  previous_role text not null,
  new_role text not null,
  previous_active boolean not null,
  new_active boolean not null,
  changed_by uuid not null,
  created_at timestamptz not null default now(),
  check (previous_role in ('owner', 'admin', 'stylist', 'assistant', 'client')),
  check (new_role in ('owner', 'admin', 'stylist', 'assistant', 'client'))
);

alter table public.user_profile_access_history enable row level security;

create index if not exists user_profile_access_history_tenant_created_idx
  on public.user_profile_access_history (tenant_id, created_at desc);

create index if not exists user_profile_access_history_profile_id_idx
  on public.user_profile_access_history (profile_id);

revoke all on table public.user_profile_access_history from public;
revoke all on table public.user_profile_access_history from anon;
revoke all on table public.user_profile_access_history from authenticated;

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
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_role text;
begin
  select up.tenant_id, up.role
    into v_tenant_id, v_role
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.active = true
  limit 1;

  if v_tenant_id is null or v_role <> 'owner' then
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
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_role text;
  v_new_role text;
  v_target public.user_profiles%rowtype;
begin
  select up.tenant_id, up.role
    into v_tenant_id, v_role
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.active = true
  limit 1;

  if v_tenant_id is null or v_role <> 'owner' then
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

revoke all on function public.get_tenant_users() from public;
revoke all on function public.get_tenant_users() from anon;
grant execute on function public.get_tenant_users() to authenticated;

revoke all on function public.update_tenant_user_access(uuid, text, boolean) from public;
revoke all on function public.update_tenant_user_access(uuid, text, boolean) from anon;
grant execute on function public.update_tenant_user_access(uuid, text, boolean) to authenticated;
