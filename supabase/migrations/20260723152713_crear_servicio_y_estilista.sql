-- BeautyOS - Crear servicio y estilista desde Flutter.
--
-- Hueco encontrado probando el registro self-serve de punta a punta:
-- ServiciosPage y EstilistasPage eran de solo lectura (ninguna migracion
-- creaba una RPC de alta); todo tenant hasta ahora se sembraba a mano por
-- SQL. Un negocio nuevo no tenia forma de cargar su propio catalogo.
--
-- services/stylists son catalogo del tenant, pero la agenda y las
-- reservas (Tramo C2a) solo consultan branch_services/branch_stylists.
-- Por eso cada RPC escribe en ambas tablas en una sola transaccion: un
-- servicio o estilista creado sin su fila de sede quedaria invisible para
-- la agenda aunque apareciera en el catalogo.
--
-- Autorizacion: mismo patron ya probado de Tramo C
-- (private.beautyos_resolve_branch_access), no el helper heredado
-- is_owner_or_admin() que no valida sede asignada de un admin.

begin;

create or replace function public.create_service(
  p_branch_id uuid,
  p_name text,
  p_category text,
  p_duration_minutes integer,
  p_price numeric,
  p_visible_to_customer boolean default true,
  p_booking_interval_minutes integer default 15
)
returns table (
  service_id uuid,
  branch_service_id uuid
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_service_id uuid;
  v_branch_service_id uuid;
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

  insert into public.services (
    tenant_id, name, category, duration_minutes, price, visible_to_customer
  ) values (
    v_tenant_id,
    trim(p_name),
    nullif(trim(coalesce(p_category, '')), ''),
    p_duration_minutes,
    p_price,
    p_visible_to_customer
  )
  returning id into v_service_id;

  insert into public.branch_services (
    tenant_id, branch_id, service_id, price, duration_minutes,
    booking_interval_minutes, visible_to_customer
  ) values (
    v_tenant_id,
    p_branch_id,
    v_service_id,
    p_price,
    p_duration_minutes,
    coalesce(p_booking_interval_minutes, 15),
    p_visible_to_customer
  )
  returning id into v_branch_service_id;

  return query select v_service_id, v_branch_service_id;
end;
$$;

create or replace function public.create_stylist(
  p_branch_id uuid,
  p_name text,
  p_phone text default null,
  p_specialty text default null
)
returns table (
  stylist_id uuid,
  branch_stylist_id uuid
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_stylist_id uuid;
  v_branch_stylist_id uuid;
begin
  select tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner', 'admin'], true
  );

  if length(trim(coalesce(p_name, ''))) = 0 then
    raise exception 'El nombre del estilista es obligatorio.';
  end if;

  insert into public.stylists (tenant_id, name, phone, specialty)
  values (
    v_tenant_id,
    trim(p_name),
    nullif(trim(coalesce(p_phone, '')), ''),
    nullif(trim(coalesce(p_specialty, '')), '')
  )
  returning id into v_stylist_id;

  insert into public.branch_stylists (tenant_id, branch_id, stylist_id)
  values (v_tenant_id, p_branch_id, v_stylist_id)
  returning id into v_branch_stylist_id;

  return query select v_stylist_id, v_branch_stylist_id;
end;
$$;

revoke all on function public.create_service(uuid, text, text, integer, numeric, boolean, integer)
  from public, anon;
revoke all on function public.create_stylist(uuid, text, text, text)
  from public, anon;

grant execute on function public.create_service(uuid, text, text, integer, numeric, boolean, integer)
  to authenticated, service_role;
grant execute on function public.create_stylist(uuid, text, text, text)
  to authenticated, service_role;

commit;
