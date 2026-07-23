-- BeautyOS - Sincronizar asignaciones estilista-servicio con la sede.
--
-- Hueco encontrado probando de punta a punta el registro self-serve:
-- set_stylist_services() (091_manage_stylist_capabilities...) solo
-- escribia stylist_services (catalogo del tenant). La agenda y las
-- reservas (Tramo C2a) solo consultan branch_stylist_services. Resultado
-- real observado: se asigna "Corte de Pelo" a un estilista desde la
-- pantalla de Estilistas, la asignacion se ve correcta ahi, pero
-- get_available_appointment_slots_v2 nunca encuentra horarios porque
-- branch_stylist_services queda en cero filas para esa combinacion.
--
-- Mismo patron ya corregido hoy en create_service/create_stylist
-- (20260723152713): toda escritura de catalogo que la agenda necesita
-- debe sincronizar tambien su fila de sede.
--
-- Alcance: set_stylist_services ahora sincroniza branch_stylist_services
-- para cada sede donde el estilista este activo (branch_stylists) y el
-- servicio tenga fila de sede (branch_services). No cambia la firma ni la
-- autorizacion de la funcion original.

begin;

create or replace function public.set_stylist_services(
  p_stylist_id uuid,
  p_service_ids uuid[]
)
returns table (
  service_id uuid,
  service_name text,
  category text,
  price numeric,
  duration_minutes integer,
  assigned boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_role text;
  v_service_ids uuid[] := coalesce(p_service_ids, array[]::uuid[]);
begin
  select up.tenant_id, up.role
    into v_tenant_id, v_role
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.active = true
  limit 1;

  if v_tenant_id is null or v_role not in ('owner', 'admin') then
    raise exception 'Solo el propietario o un administrador puede gestionar servicios de estilistas.';
  end if;

  perform 1
  from public.stylists st
  where st.id = p_stylist_id
    and st.tenant_id = v_tenant_id
    and st.active = true
  for update;

  if not found then
    raise exception 'El estilista no existe, esta inactivo o pertenece a otro negocio.';
  end if;

  if exists (
    select 1
    from unnest(v_service_ids) requested(service_id)
    left join public.services s
      on s.id = requested.service_id
     and s.tenant_id = v_tenant_id
     and s.active = true
    where s.id is null
  ) then
    raise exception 'Uno de los servicios seleccionados no existe, esta inactivo o pertenece a otro negocio.';
  end if;

  update public.stylist_services ss
     set active = false
   where ss.tenant_id = v_tenant_id
     and ss.stylist_id = p_stylist_id
     and ss.active = true
     and not (ss.service_id = any(v_service_ids));

  insert into public.stylist_services (
    tenant_id,
    stylist_id,
    service_id,
    active
  )
  select
    v_tenant_id,
    p_stylist_id,
    requested.service_id,
    true
  from (
    select distinct unnest(v_service_ids) as service_id
  ) requested
  on conflict on constraint stylist_services_stylist_id_service_id_key
  do update set active = excluded.active;

  -- Sincronizar la fila de sede: sin esto, la agenda (Tramo C2a) nunca
  -- ve la asignacion aunque el catalogo del tenant este correcto.
  update public.branch_stylist_services bss
     set active = false, updated_at = now()
   where bss.tenant_id = v_tenant_id
     and bss.active = true
     and bss.branch_stylist_id in (
       select bst.id
       from public.branch_stylists bst
       where bst.tenant_id = v_tenant_id
         and bst.stylist_id = p_stylist_id
     )
     and bss.branch_service_id not in (
       select bs.id
       from public.branch_services bs
       where bs.tenant_id = v_tenant_id
         and bs.service_id = any(v_service_ids)
     );

  insert into public.branch_stylist_services (
    tenant_id, branch_id, branch_stylist_id, branch_service_id, active
  )
  select
    v_tenant_id,
    bst.branch_id,
    bst.id,
    bs.id,
    true
  from public.branch_stylists bst
  join public.branch_services bs
    on bs.tenant_id = v_tenant_id
   and bs.branch_id = bst.branch_id
   and bs.service_id = any(v_service_ids)
  where bst.tenant_id = v_tenant_id
    and bst.stylist_id = p_stylist_id
    and bst.active = true
  on conflict on constraint branch_stylist_services_pair_key
  do update set active = true, updated_at = now();

  return query
  select
    s.id,
    s.name,
    coalesce(s.category, 'Sin categoria'),
    s.price,
    s.duration_minutes,
    coalesce(ss.active, false)
  from public.services s
  left join public.stylist_services ss
    on ss.tenant_id = s.tenant_id
   and ss.stylist_id = p_stylist_id
   and ss.service_id = s.id
  where s.tenant_id = v_tenant_id
    and s.active = true
  order by lower(s.name), s.id;
end;
$$;

commit;
