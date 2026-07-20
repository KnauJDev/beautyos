-- BeautyOS - Tramo C1: contexto de sede efectiva.
--
-- Alcance aditivo:
-- 1. Resolver en servidor tenant, rol y sede autorizada.
-- 2. Exponer solo las sedes que el usuario autenticado puede seleccionar.
-- 3. Mantener intactas las RPC y rutas heredadas.

begin;

create or replace function private.beautyos_resolve_branch_access(
  p_branch_id uuid,
  p_allowed_roles text[],
  p_require_operational boolean default true
)
returns table (
  tenant_id uuid,
  branch_id uuid,
  tenant_membership_id uuid,
  role text,
  stylist_id uuid,
  timezone text,
  currency_code text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if auth.uid() is null then
    raise exception 'No existe una sesion autenticada.';
  end if;

  if p_branch_id is null
     or p_allowed_roles is null
     or cardinality(p_allowed_roles) = 0 then
    raise exception 'El contexto de sede no esta disponible.';
  end if;

  return query
  select
    tm.tenant_id,
    b.id,
    tm.id,
    tm.role,
    tm.stylist_id,
    b.timezone,
    b.currency_code
  from public.branches b
  join public.tenants t
    on t.id = b.tenant_id
  join public.tenant_memberships tm
    on tm.tenant_id = b.tenant_id
   and tm.user_id = auth.uid()
   and tm.active
   and tm.starts_at <= now()
   and (tm.ends_at is null or tm.ends_at > now())
   and tm.role = any (p_allowed_roles)
  where b.id = p_branch_id
    and (not p_require_operational or (t.active and b.active))
    and (
      tm.role = 'tenant_owner'
      or exists (
        select 1
        from public.branch_memberships bm
        where bm.tenant_id = tm.tenant_id
          and bm.branch_id = b.id
          and bm.tenant_membership_id = tm.id
          and bm.active
          and bm.starts_at <= now()
          and (bm.ends_at is null or bm.ends_at > now())
      )
    )
    and (
      tm.role <> 'stylist'
      or exists (
        select 1
        from public.branch_stylists bst
        where bst.tenant_id = tm.tenant_id
          and bst.branch_id = b.id
          and bst.stylist_id = tm.stylist_id
          and bst.active
          and bst.starts_at <= now()
          and (bst.ends_at is null or bst.ends_at > now())
      )
    )
  limit 1;

  if not found then
    raise exception 'El contexto de sede no esta disponible.';
  end if;
end;
$$;

revoke all on function private.beautyos_resolve_branch_access(uuid, text[], boolean)
  from public, anon, authenticated;
grant execute on function private.beautyos_resolve_branch_access(uuid, text[], boolean)
  to service_role;

create or replace function public.get_my_branch_context_v2()
returns table (
  tenant_id uuid,
  tenant_name text,
  branch_id uuid,
  branch_name text,
  branch_slug text,
  role text,
  stylist_id uuid,
  timezone text,
  currency_code text,
  is_primary boolean,
  option_count integer
)
language sql
security definer
set search_path = pg_catalog
as $$
  with accessible as (
    select
      tm.tenant_id,
      t.name as tenant_name,
      b.id as branch_id,
      b.name as branch_name,
      b.slug as branch_slug,
      tm.role,
      tm.stylist_id,
      b.timezone,
      b.currency_code,
      b.is_primary
    from public.tenant_memberships tm
    join public.tenants t
      on t.id = tm.tenant_id
     and t.active
    join public.branches b
      on b.tenant_id = tm.tenant_id
     and b.active
    where tm.user_id = auth.uid()
      and tm.active
      and tm.starts_at <= now()
      and (tm.ends_at is null or tm.ends_at > now())
      and (
        tm.role = 'tenant_owner'
        or exists (
          select 1
          from public.branch_memberships bm
          where bm.tenant_id = tm.tenant_id
            and bm.branch_id = b.id
            and bm.tenant_membership_id = tm.id
            and bm.active
            and bm.starts_at <= now()
            and (bm.ends_at is null or bm.ends_at > now())
        )
      )
      and (
        tm.role <> 'stylist'
        or exists (
          select 1
          from public.branch_stylists bst
          where bst.tenant_id = tm.tenant_id
            and bst.branch_id = b.id
            and bst.stylist_id = tm.stylist_id
            and bst.active
            and bst.starts_at <= now()
            and (bst.ends_at is null or bst.ends_at > now())
        )
      )
  )
  select
    a.tenant_id,
    a.tenant_name,
    a.branch_id,
    a.branch_name,
    a.branch_slug,
    a.role,
    a.stylist_id,
    a.timezone,
    a.currency_code,
    a.is_primary,
    count(*) over ()::integer as option_count
  from accessible a
  order by a.tenant_name, a.is_primary desc, a.branch_name, a.branch_id;
$$;

revoke all on function public.get_my_branch_context_v2()
  from public, anon, authenticated;
grant execute on function public.get_my_branch_context_v2()
  to authenticated, service_role;

comment on function private.beautyos_resolve_branch_access(uuid, text[], boolean)
  is 'Resuelve y valida tenant, rol y sede efectiva para RPC del Tramo C.';
comment on function public.get_my_branch_context_v2()
  is 'Lista exclusivamente las sedes activas que el usuario puede seleccionar.';

commit;
