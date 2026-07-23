-- BeautyOS - Editar y desactivar servicios y estilistas.
--
-- Bloque acordado tras crear_servicio_y_estilista (20260723152713): hasta
-- ahora solo se podia dar de alta, sin forma de corregir un precio mal
-- escrito ni de retirar un servicio/estilista sin borrarlo.
--
-- Lectura de gestion aparte de la publica: get_services_for_management y
-- get_stylists_for_management muestran TAMBIEN los inactivos (para poder
-- reactivarlos). Los RPC/politicas existentes (get_active_visible
-- services via RLS, get_stylists_summary) solo devuelven activos a
-- proposito para el catalogo operativo/publico; no se tocan.
--
-- Igual que create_service/create_stylist: toda escritura actualiza a la
-- vez el catalogo del tenant y la fila de sede, porque la agenda (Tramo
-- C2a) solo consulta branch_services/branch_stylists.

begin;

create or replace function public.get_services_for_management(p_branch_id uuid)
returns table (
  service_id uuid,
  name text,
  category text,
  duration_minutes integer,
  price numeric,
  visible_to_customer boolean,
  active boolean
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
    s.id,
    s.name,
    coalesce(s.category, 'Sin categoria'),
    coalesce(bs.duration_minutes, s.duration_minutes),
    coalesce(bs.price, s.price),
    coalesce(bs.visible_to_customer, s.visible_to_customer),
    s.active and coalesce(bs.active, false)
  from public.services s
  left join public.branch_services bs
    on bs.tenant_id = v_tenant_id
   and bs.branch_id = p_branch_id
   and bs.service_id = s.id
  where s.tenant_id = v_tenant_id
  order by lower(s.name);
end;
$$;

create or replace function public.update_service(
  p_branch_id uuid,
  p_service_id uuid,
  p_name text,
  p_category text,
  p_duration_minutes integer,
  p_price numeric,
  p_visible_to_customer boolean default true
)
returns void
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

  if length(trim(coalesce(p_name, ''))) = 0 then
    raise exception 'El nombre del servicio es obligatorio.';
  end if;

  if p_duration_minutes is null or p_duration_minutes <= 0 then
    raise exception 'La duracion debe ser mayor a cero.';
  end if;

  if p_price is null or p_price < 0 then
    raise exception 'El precio no puede ser negativo.';
  end if;

  update public.services
     set name = trim(p_name),
         category = nullif(trim(coalesce(p_category, '')), ''),
         duration_minutes = p_duration_minutes,
         price = p_price,
         visible_to_customer = p_visible_to_customer
   where id = p_service_id
     and tenant_id = v_tenant_id;

  if not found then
    raise exception 'El servicio no existe o pertenece a otro negocio.';
  end if;

  update public.branch_services
     set duration_minutes = p_duration_minutes,
         price = p_price,
         visible_to_customer = p_visible_to_customer,
         updated_at = now()
   where tenant_id = v_tenant_id
     and branch_id = p_branch_id
     and service_id = p_service_id;
end;
$$;

create or replace function public.set_service_active(
  p_branch_id uuid,
  p_service_id uuid,
  p_active boolean
)
returns void
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

  update public.services
     set active = p_active
   where id = p_service_id
     and tenant_id = v_tenant_id;

  if not found then
    raise exception 'El servicio no existe o pertenece a otro negocio.';
  end if;

  update public.branch_services
     set active = p_active, updated_at = now()
   where tenant_id = v_tenant_id
     and branch_id = p_branch_id
     and service_id = p_service_id;
end;
$$;

create or replace function public.get_stylists_for_management(p_branch_id uuid)
returns table (
  stylist_id uuid,
  name text,
  phone text,
  specialty text,
  active boolean
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
    st.id,
    st.name,
    coalesce(st.phone, 'Sin telefono'),
    coalesce(st.specialty, 'Sin especialidad'),
    st.active and coalesce(bst.active, false)
  from public.stylists st
  left join public.branch_stylists bst
    on bst.tenant_id = v_tenant_id
   and bst.branch_id = p_branch_id
   and bst.stylist_id = st.id
  where st.tenant_id = v_tenant_id
  order by lower(st.name);
end;
$$;

create or replace function public.update_stylist(
  p_branch_id uuid,
  p_stylist_id uuid,
  p_name text,
  p_phone text default null,
  p_specialty text default null
)
returns void
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

  if length(trim(coalesce(p_name, ''))) = 0 then
    raise exception 'El nombre del estilista es obligatorio.';
  end if;

  update public.stylists
     set name = trim(p_name),
         phone = nullif(trim(coalesce(p_phone, '')), ''),
         specialty = nullif(trim(coalesce(p_specialty, '')), '')
   where id = p_stylist_id
     and tenant_id = v_tenant_id;

  if not found then
    raise exception 'El estilista no existe o pertenece a otro negocio.';
  end if;
end;
$$;

create or replace function public.set_stylist_active(
  p_branch_id uuid,
  p_stylist_id uuid,
  p_active boolean
)
returns void
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

  update public.stylists
     set active = p_active
   where id = p_stylist_id
     and tenant_id = v_tenant_id;

  if not found then
    raise exception 'El estilista no existe o pertenece a otro negocio.';
  end if;

  update public.branch_stylists
     set active = p_active, updated_at = now()
   where tenant_id = v_tenant_id
     and branch_id = p_branch_id
     and stylist_id = p_stylist_id;
end;
$$;

revoke all on function public.get_services_for_management(uuid) from public, anon;
revoke all on function public.update_service(uuid, uuid, text, text, integer, numeric, boolean) from public, anon;
revoke all on function public.set_service_active(uuid, uuid, boolean) from public, anon;
revoke all on function public.get_stylists_for_management(uuid) from public, anon;
revoke all on function public.update_stylist(uuid, uuid, text, text, text) from public, anon;
revoke all on function public.set_stylist_active(uuid, uuid, boolean) from public, anon;

grant execute on function public.get_services_for_management(uuid) to authenticated, service_role;
grant execute on function public.update_service(uuid, uuid, text, text, integer, numeric, boolean) to authenticated, service_role;
grant execute on function public.set_service_active(uuid, uuid, boolean) to authenticated, service_role;
grant execute on function public.get_stylists_for_management(uuid) to authenticated, service_role;
grant execute on function public.update_stylist(uuid, uuid, text, text, text) to authenticated, service_role;
grant execute on function public.set_stylist_active(uuid, uuid, boolean) to authenticated, service_role;

commit;
