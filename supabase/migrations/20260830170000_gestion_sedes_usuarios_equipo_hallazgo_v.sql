-- BeautyOS - Migración 20260830170000: Gestión de sedes para usuarios de equipo multi-sede (Hallazgo V / Paso 8.6).
--
-- Resuelve el Hallazgo V:
-- Permite al propietario o administrador de un salón consultar y configurar
-- a cuáles sedes tiene acceso un usuario de su equipo (branch_memberships).
-- Si el usuario tiene rol de estilista (stylist_id no nulo), sincroniza
-- automáticamente branch_stylists para que get_my_branch_context_v2 reconozca
-- la sede autorizada sin inconsistencias de catálogo.

begin;

-- ---------------------------------------------------------------------------
-- 1. get_tenant_user_branches(p_profile_id uuid)
-- ---------------------------------------------------------------------------
create or replace function public.get_tenant_user_branches(p_profile_id uuid)
returns table (
  branch_id uuid,
  branch_name text,
  is_primary boolean,
  has_access boolean,
  in_catalog boolean
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_role text;
  v_target public.user_profiles%rowtype;
  v_tenant_membership_id uuid;
begin
  v_tenant_id := public.get_my_tenant_id();
  v_role := public.get_my_role();

  if v_tenant_id is null or v_role not in ('tenant_owner', 'admin') then
    raise exception 'Solo el propietario o un administrador pueden consultar sedes de usuarios.';
  end if;

  if p_profile_id is null then
    raise exception 'El identificador de perfil es obligatorio.';
  end if;

  select *
    into v_target
  from public.user_profiles up
  where up.id = p_profile_id
    and up.tenant_id = v_tenant_id;

  if not found then
    raise exception 'Usuario no encontrado o no pertenece al centro actual.';
  end if;

  select tm.id
    into v_tenant_membership_id
  from public.tenant_memberships tm
  where tm.tenant_id = v_tenant_id
    and tm.user_id = v_target.user_id;

  return query
  select
    b.id as branch_id,
    b.name as branch_name,
    b.is_primary,
    case
      when v_target.role = 'owner' then true
      else coalesce(bm.active, false)
    end as has_access,
    case
      when v_target.stylist_id is null then null::boolean
      else exists (
        select 1
        from public.branch_stylists bst
        where bst.tenant_id = v_tenant_id
          and bst.branch_id = b.id
          and bst.stylist_id = v_target.stylist_id
          and bst.active
          and bst.starts_at <= now()
          and (bst.ends_at is null or bst.ends_at > now())
      )
    end as in_catalog
  from public.branches b
  left join public.branch_memberships bm
    on bm.tenant_id = v_tenant_id
   and bm.branch_id = b.id
   and bm.tenant_membership_id = v_tenant_membership_id
   and bm.active
   and bm.starts_at <= now()
   and (bm.ends_at is null or bm.ends_at > now())
  where b.tenant_id = v_tenant_id
    and b.active
  order by
    b.is_primary desc,
    b.name asc;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. set_tenant_user_branches(p_profile_id uuid, p_branch_ids uuid[])
-- ---------------------------------------------------------------------------
create or replace function public.set_tenant_user_branches(
  p_profile_id uuid,
  p_branch_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
#variable_conflict use_column
declare
  v_tenant_id uuid;
  v_role text;
  v_target public.user_profiles%rowtype;
  v_tenant_membership_id uuid;
  v_bid uuid;
begin
  v_tenant_id := public.get_my_tenant_id();
  v_role := public.get_my_role();

  if v_tenant_id is null or v_role not in ('tenant_owner', 'admin') then
    raise exception 'Solo el propietario o un administrador pueden modificar sedes de usuarios.';
  end if;

  if p_profile_id is null or p_branch_ids is null then
    raise exception 'El usuario y la lista de sedes son obligatorios.';
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
    raise exception 'No puedes modificar tus propias sedes asignadas.';
  end if;

  if v_target.role = 'owner' then
    raise exception 'La cuenta del propietario tiene acceso universal a todas las sedes.';
  end if;

  -- Regla de integridad: un usuario activo con rol de equipo debe tener al menos una sede.
  if v_target.active and v_target.role in ('admin', 'stylist', 'assistant') and coalesce(cardinality(p_branch_ids), 0) = 0 then
    raise exception 'Un usuario de equipo activo debe tener al menos una sede asignada.';
  end if;

  -- Validar que todas las sedes pertenezcan al tenant y estén activas.
  if cardinality(p_branch_ids) > 0 then
    if exists (
      select 1
      from unnest(p_branch_ids) as bid
      left join public.branches b
        on b.id = bid
       and b.tenant_id = v_tenant_id
       and b.active
      where b.id is null
    ) then
      raise exception 'Una o más sedes no existen o no pertenecen a este negocio.';
    end if;
  end if;

  -- Asegurar tenant_membership_id
  select tm.id
    into v_tenant_membership_id
  from public.tenant_memberships tm
  where tm.tenant_id = v_tenant_id
    and tm.user_id = v_target.user_id;

  if v_tenant_membership_id is null then
    insert into public.tenant_memberships (
      tenant_id, user_id, role, stylist_id, active, starts_at, created_by
    ) values (
      v_tenant_id,
      v_target.user_id,
      case when v_target.role = 'owner' then 'tenant_owner' else v_target.role end,
      v_target.stylist_id,
      v_target.active,
      now(),
      auth.uid()
    )
    returning id into v_tenant_membership_id;
  end if;

  -- Activar / insertar sedes asignadas en branch_memberships
  if cardinality(p_branch_ids) > 0 then
    foreach v_bid in array p_branch_ids loop
      insert into public.branch_memberships (
        tenant_id,
        branch_id,
        tenant_membership_id,
        active,
        starts_at,
        ends_at,
        created_by
      ) values (
        v_tenant_id,
        v_bid,
        v_tenant_membership_id,
        true,
        now(),
        null,
        auth.uid()
      )
      on conflict (branch_id, tenant_membership_id) do update
        set active = true,
            ends_at = null,
            updated_at = now();
    end loop;
  end if;

  -- Desactivar sedes de este tenant que ya no estén en p_branch_ids
  update public.branch_memberships bm
     set active = false,
         ends_at = coalesce(bm.ends_at, now()),
         updated_at = now()
   where bm.tenant_id = v_tenant_id
     and bm.tenant_membership_id = v_tenant_membership_id
     and bm.active
     and not (bm.branch_id = any(p_branch_ids));

  -- Sincronizar branch_stylists si el usuario es estilista
  if v_target.stylist_id is not null then
    -- Activar / insertar en las sedes asignadas
    if cardinality(p_branch_ids) > 0 then
      foreach v_bid in array p_branch_ids loop
        insert into public.branch_stylists (
          tenant_id,
          branch_id,
          stylist_id,
          active,
          starts_at,
          ends_at,
          created_at,
          updated_at
        ) values (
          v_tenant_id,
          v_bid,
          v_target.stylist_id,
          true,
          now(),
          null,
          now(),
          now()
        )
        on conflict (branch_id, stylist_id) do update
          set active = true,
              ends_at = null,
              updated_at = now();
      end loop;
    end if;

    -- Desactivar en branch_stylists de las sedes que ya no tiene asignadas
    update public.branch_stylists bst
       set active = false,
           ends_at = coalesce(bst.ends_at, now()),
           updated_at = now()
     where bst.tenant_id = v_tenant_id
       and bst.stylist_id = v_target.stylist_id
       and bst.active
       and not (bst.branch_id = any(p_branch_ids));
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Permisos perimétricos (seguridad)
-- ---------------------------------------------------------------------------
revoke all on function public.get_tenant_user_branches(uuid) from public, anon;
grant execute on function public.get_tenant_user_branches(uuid) to authenticated, service_role;

revoke all on function public.set_tenant_user_branches(uuid, uuid[]) from public, anon;
grant execute on function public.set_tenant_user_branches(uuid, uuid[]) to authenticated, service_role;

commit;
