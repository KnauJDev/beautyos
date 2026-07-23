-- BeautyOS - Invitar usuarios del negocio (estilistas, admins, asistentes).
--
-- Hueco confirmado: UsuariosPage solo administra cuentas que ya existen
-- (update_tenant_user_access). No habia forma de que el propietario
-- agregara una cuenta nueva para un estilista o miembro del equipo.
--
-- Diseno: sin Edge Function ni Admin API (evita manejar service_role
-- desde el cliente). El propietario/admin crea una invitacion por correo;
-- la persona invitada se registra con el flujo self-serve normal
-- (RegisterPage, ya construido); al tener sesion, si su correo tiene una
-- invitacion pendiente, se une al tenant en vez de crear uno propio.
--
-- Un estilista invitado se vincula a una fila ya existente en
-- public.stylists (creada antes con create_stylist) via p_stylist_id: la
-- invitacion decide quien puede iniciar sesion, no quien aparece en el
-- catalogo operativo.

begin;

create table public.team_invitations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  branch_id uuid not null references public.branches(id) on delete restrict,
  email text not null,
  role text not null check (role in ('admin', 'assistant', 'stylist')),
  stylist_id uuid references public.stylists(id) on delete restrict,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'cancelled', 'expired')),
  invited_by uuid not null references auth.users(id) on delete restrict,
  accepted_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '7 days'),
  accepted_at timestamptz,
  constraint team_invitations_stylist_role_check check (
    (role = 'stylist' and stylist_id is not null)
    or (role <> 'stylist' and stylist_id is null)
  )
);

create index team_invitations_email_pending_idx
  on public.team_invitations (lower(email), status);

alter table public.team_invitations enable row level security;

revoke all on table public.team_invitations from public, anon, authenticated;
grant all on table public.team_invitations to service_role;

-- Crear invitacion: mismo patron de autorizacion que create_service/
-- create_stylist (beautyos_resolve_branch_access, no is_owner_or_admin).

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

create or replace function public.list_team_invitations(p_branch_id uuid)
returns table (
  invitation_id uuid,
  email text,
  role text,
  stylist_name text,
  status text,
  created_at timestamptz,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner', 'admin'], true
  );

  return query
  select
    ti.id,
    ti.email,
    ti.role,
    st.name,
    case
      when ti.status = 'pending' and ti.expires_at <= now() then 'expired'
      else ti.status
    end,
    ti.created_at,
    ti.expires_at
  from public.team_invitations ti
  left join public.stylists st on st.id = ti.stylist_id
  where ti.tenant_id = v_tenant_id
    and ti.branch_id = p_branch_id
  order by ti.created_at desc;
end;
$$;

create or replace function public.cancel_team_invitation(p_invitation_id uuid)
returns public.team_invitations
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_branch_id uuid;
  v_result public.team_invitations%rowtype;
begin
  select ti.tenant_id, ti.branch_id
    into v_tenant_id, v_branch_id
  from public.team_invitations ti
  where ti.id = p_invitation_id;

  if v_tenant_id is null then
    raise exception 'La invitacion no existe.';
  end if;

  perform 1
  from private.beautyos_resolve_branch_access(
    v_branch_id, array['tenant_owner', 'admin'], true
  );

  update public.team_invitations
     set status = 'cancelled'
   where id = p_invitation_id
     and status = 'pending'
  returning * into v_result;

  if v_result.id is null then
    raise exception 'Solo se puede cancelar una invitacion pendiente.';
  end if;

  return v_result;
end;
$$;

-- Lo que ve la persona invitada, sin necesitar aun una membresia.

create or replace function public.get_my_pending_invitation()
returns table (
  invitation_id uuid,
  tenant_name text,
  branch_name text,
  role text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_email text;
begin
  if v_user_id is null then
    raise exception 'Se requiere una sesion autenticada.';
  end if;

  select email into v_email from auth.users where id = v_user_id;

  return query
  select ti.id, t.name, b.name, ti.role
  from public.team_invitations ti
  join public.tenants t on t.id = ti.tenant_id
  join public.branches b on b.id = ti.branch_id
  where lower(ti.email) = lower(coalesce(v_email, ''))
    and ti.status = 'pending'
    and ti.expires_at > now()
  order by ti.created_at desc
  limit 1;
end;
$$;

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

revoke all on function public.create_team_invitation(uuid, text, text, uuid) from public, anon;
revoke all on function public.list_team_invitations(uuid) from public, anon;
revoke all on function public.cancel_team_invitation(uuid) from public, anon;
revoke all on function public.get_my_pending_invitation() from public, anon;
revoke all on function public.accept_team_invitation(text) from public, anon;

grant execute on function public.create_team_invitation(uuid, text, text, uuid) to authenticated, service_role;
grant execute on function public.list_team_invitations(uuid) to authenticated, service_role;
grant execute on function public.cancel_team_invitation(uuid) to authenticated, service_role;
grant execute on function public.get_my_pending_invitation() to authenticated, service_role;
grant execute on function public.accept_team_invitation(text) to authenticated, service_role;

commit;
