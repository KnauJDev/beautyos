-- BeautyOS - Reserva publica de cliente (web/QR), D-005.
--
-- Primer bloque de esta ruta: cuatro RPC nuevas, aditivas, otorgadas a
-- "anon" (primera superficie del proyecto abierta sin sesion). Todas
-- validan tenant.active y branch.active para no exponer negocios
-- suspendidos o sedes desactivadas.
--
-- Reutiliza el mismo patron de disponibilidad ya probado en
-- get_available_appointment_slots_v2 / create_scheduled_ticket_with_service_v2
-- (Tramo C2a), agregando el filtro visible_to_customer (services y
-- branch_services, ya existente desde crear_servicio_y_estilista) para que
-- un servicio o profesional marcado "no visible al cliente" no aparezca ni
-- sea reservable publicamente aunque se adivine su id.
--
-- La proteccion real contra choques de agenda ya existe en produccion
-- (Tramo C2b: trigger enforce_stylist_schedule_conflict sobre tickets y
-- ticket_services, con pg_advisory_xact_lock por sede) y se verifico contra
-- el proyecto real dentro de una transaccion con rollback antes de escribir
-- este archivo: bloquea dos "solicitado" del mismo estilista chocando y
-- permite servicios simultaneos del mismo ticket. public_create_booking no
-- necesita logica nueva de choque: hereda esa proteccion al insertar en las
-- mismas tablas.
--
-- Decision del propietario (2026-07-23): toda reserva publica queda
-- siempre en estado 'solicitado' (pendiente de confirmacion manual del
-- negocio), sin importar branch.booking_mode ni si la politica de citas
-- exige anticipo. Se revisita cuando exista pasarela de pago (Wompi).
--
-- Decision del propietario (2026-07-23): el enlace publico usa el UUID de
-- la sede (branch_id) directamente, sin slug global nuevo (branch.slug hoy
-- solo es unico por tenant y toda sede nueva nace con slug 'principal').

begin;

create or replace function public.public_get_branch_booking_info(
  p_branch_id uuid
)
returns table (
  branch_id uuid,
  tenant_id uuid,
  business_name text,
  branch_name text,
  address text,
  city text,
  whatsapp text,
  timezone text,
  currency_code text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  return query
  select
    b.id,
    t.id,
    t.name,
    b.name,
    b.address,
    b.city,
    coalesce(b.whatsapp, t.whatsapp),
    b.timezone,
    b.currency_code
  from public.branches b
  join public.tenants t
    on t.id = b.tenant_id
  where b.id = p_branch_id
    and t.active
    and b.active;

  if not found then
    raise exception 'Este negocio no esta disponible para reservas en este momento.';
  end if;
end;
$$;

create or replace function public.public_get_bookable_services(
  p_branch_id uuid
)
returns table (
  service_id uuid,
  service_name text,
  category text,
  price numeric,
  duration_minutes integer,
  stylist_id uuid,
  stylist_name text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select t.id
    into v_tenant_id
  from public.branches b
  join public.tenants t
    on t.id = b.tenant_id
  where b.id = p_branch_id
    and t.active
    and b.active;

  if not found then
    raise exception 'Este negocio no esta disponible para reservas en este momento.';
  end if;

  return query
  select
    s.id,
    s.name,
    coalesce(s.category, 'Sin categoria'),
    bs.price,
    bs.duration_minutes,
    st.id,
    st.name
  from public.branch_services bs
  join public.services s
    on s.tenant_id = bs.tenant_id
   and s.id = bs.service_id
   and s.active
  join public.branch_stylist_services bss
    on bss.tenant_id = bs.tenant_id
   and bss.branch_id = bs.branch_id
   and bss.branch_service_id = bs.id
   and bss.active
  join public.branch_stylists bst
    on bst.tenant_id = bss.tenant_id
   and bst.branch_id = bss.branch_id
   and bst.id = bss.branch_stylist_id
   and bst.active
   and bst.starts_at <= now()
   and (bst.ends_at is null or bst.ends_at > now())
  join public.stylists st
    on st.tenant_id = bst.tenant_id
   and st.id = bst.stylist_id
   and st.active
  where bs.tenant_id = v_tenant_id
    and bs.branch_id = p_branch_id
    and bs.active
    and s.visible_to_customer
    and bs.visible_to_customer
  order by s.name, st.name;
end;
$$;

create or replace function public.public_get_available_slots(
  p_branch_id uuid,
  p_service_id uuid,
  p_stylist_id uuid,
  p_date date
)
returns table (
  starts_at timestamptz,
  ends_at timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_timezone text;
  v_duration_minutes integer;
  v_interval_minutes integer;
  v_opens_at time;
  v_closes_at time;
  v_day_of_week integer;
  v_day_start timestamptz;
  v_day_end timestamptz;
begin
  select t.id, b.timezone
    into v_tenant_id, v_timezone
  from public.branches b
  join public.tenants t
    on t.id = b.tenant_id
  where b.id = p_branch_id
    and t.active
    and b.active;

  if not found then
    raise exception 'Este negocio no esta disponible para reservas en este momento.';
  end if;

  if p_date is null then
    raise exception 'Selecciona una fecha para consultar disponibilidad.';
  end if;

  select bs.duration_minutes, bs.booking_interval_minutes
    into v_duration_minutes, v_interval_minutes
  from public.branch_services bs
  join public.services s
    on s.tenant_id = bs.tenant_id
   and s.id = bs.service_id
   and s.active
  where bs.tenant_id = v_tenant_id
    and bs.branch_id = p_branch_id
    and bs.service_id = p_service_id
    and bs.active
    and s.visible_to_customer
    and bs.visible_to_customer;

  if not found then
    raise exception 'El servicio seleccionado no esta disponible para reservar en esta sede.';
  end if;

  if not exists (
    select 1
    from public.branch_services bs
    join public.branch_stylist_services bss
      on bss.tenant_id = bs.tenant_id
     and bss.branch_id = bs.branch_id
     and bss.branch_service_id = bs.id
     and bss.active
    join public.branch_stylists bst
      on bst.tenant_id = bss.tenant_id
     and bst.branch_id = bss.branch_id
     and bst.id = bss.branch_stylist_id
     and bst.stylist_id = p_stylist_id
     and bst.active
     and bst.starts_at <= now()
     and (bst.ends_at is null or bst.ends_at > now())
    join public.stylists st
      on st.tenant_id = bst.tenant_id
     and st.id = bst.stylist_id
     and st.active
    where bs.tenant_id = v_tenant_id
      and bs.branch_id = p_branch_id
      and bs.service_id = p_service_id
      and bs.active
      and bs.visible_to_customer
  ) then
    raise exception 'El profesional seleccionado no esta disponible para reservar este servicio en esta sede.';
  end if;

  v_day_of_week := extract(isodow from p_date)::integer;

  select bh.opens_at, bh.closes_at
    into v_opens_at, v_closes_at
  from public.business_hours bh
  where bh.tenant_id = v_tenant_id
    and bh.branch_id = p_branch_id
    and bh.day_of_week = v_day_of_week
    and bh.active
    and bh.is_open
  order by bh.opens_at
  limit 1;

  if v_opens_at is null
     or v_closes_at is null
     or v_closes_at <= v_opens_at then
    return;
  end if;

  v_day_start := p_date::timestamp at time zone v_timezone;
  v_day_end := (p_date + 1)::timestamp at time zone v_timezone;

  return query
  with candidate_slots as (
    select
      candidate_start as starts_at,
      candidate_start + (v_duration_minutes * interval '1 minute') as ends_at
    from generate_series(
      (p_date + v_opens_at)::timestamp at time zone v_timezone,
      ((p_date + v_closes_at)::timestamp at time zone v_timezone)
        - (v_duration_minutes * interval '1 minute'),
      v_interval_minutes * interval '1 minute'
    ) candidate_start
  ),
  occupied as (
    select
      t.id as ticket_id,
      t.scheduled_at,
      sum(ts.duration_minutes)::integer as duration_minutes
    from public.ticket_services ts
    join public.tickets t
      on t.tenant_id = ts.tenant_id
     and t.branch_id = ts.branch_id
     and t.id = ts.ticket_id
    where ts.tenant_id = v_tenant_id
      and ts.branch_id = p_branch_id
      and ts.stylist_id = p_stylist_id
      and ts.status in ('pendiente', 'en_proceso')
      and t.status in (
        'solicitado', 'cotizado', 'apartado',
        'confirmado', 'en_espera', 'en_proceso'
      )
      and t.scheduled_at >= v_day_start
      and t.scheduled_at < v_day_end
    group by t.id, t.scheduled_at
  )
  select cs.starts_at, cs.ends_at
  from candidate_slots cs
  where cs.starts_at > now()
    and not exists (
      select 1
      from occupied o
      where cs.starts_at
              < o.scheduled_at + (o.duration_minutes * interval '1 minute')
        and cs.ends_at > o.scheduled_at
    )
  order by cs.starts_at;
end;
$$;

create or replace function public.public_create_booking(
  p_branch_id uuid,
  p_service_id uuid,
  p_stylist_id uuid,
  p_scheduled_at timestamptz,
  p_client_name text,
  p_client_phone text,
  p_client_email text default null,
  p_notes text default null
)
returns table (
  ticket_id uuid,
  scheduled_at timestamptz,
  service_name text,
  stylist_name text,
  status text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_timezone text;
  v_service_price numeric;
  v_service_duration integer;
  v_client_id uuid;
  v_client_name text;
  v_client_phone text;
  v_ticket_id uuid;
begin
  select t.id, b.timezone
    into v_tenant_id, v_timezone
  from public.branches b
  join public.tenants t
    on t.id = b.tenant_id
  where b.id = p_branch_id
    and t.active
    and b.active;

  if not found then
    raise exception 'Este negocio no esta disponible para reservas en este momento.';
  end if;

  v_client_name := nullif(trim(coalesce(p_client_name, '')), '');
  v_client_phone := nullif(trim(coalesce(p_client_phone, '')), '');

  if v_client_name is null then
    raise exception 'Escribe tu nombre para reservar.';
  end if;

  if v_client_phone is null or length(v_client_phone) < 7 then
    raise exception 'Escribe un numero de celular valido para reservar.';
  end if;

  if p_scheduled_at is null or p_scheduled_at <= now() then
    raise exception 'Selecciona una fecha y hora futura para reservar.';
  end if;

  select bs.price, bs.duration_minutes
    into v_service_price, v_service_duration
  from public.branch_services bs
  join public.branch_stylist_services bss
    on bss.tenant_id = bs.tenant_id
   and bss.branch_id = bs.branch_id
   and bss.branch_service_id = bs.id
   and bss.active
  join public.branch_stylists bst
    on bst.tenant_id = bss.tenant_id
   and bst.branch_id = bss.branch_id
   and bst.id = bss.branch_stylist_id
   and bst.stylist_id = p_stylist_id
   and bst.active
   and bst.starts_at <= now()
   and (bst.ends_at is null or bst.ends_at > now())
  join public.services s
    on s.tenant_id = bs.tenant_id
   and s.id = bs.service_id
   and s.active
  join public.stylists st
    on st.tenant_id = bst.tenant_id
   and st.id = bst.stylist_id
   and st.active
  where bs.tenant_id = v_tenant_id
    and bs.branch_id = p_branch_id
    and bs.service_id = p_service_id
    and bs.active
    and s.visible_to_customer
    and bs.visible_to_customer;

  if not found then
    raise exception 'El servicio o el profesional seleccionado ya no estan disponibles para reservar.';
  end if;

  if not exists (
    select 1
    from public.public_get_available_slots(
      p_branch_id, p_service_id, p_stylist_id,
      (p_scheduled_at at time zone v_timezone)::date
    ) slots
    where slots.starts_at = p_scheduled_at
  ) then
    raise exception 'Ese horario ya no esta disponible. Elige otro.';
  end if;

  select c.id
    into v_client_id
  from public.clients c
  where c.tenant_id = v_tenant_id
    and c.phone = v_client_phone
    and c.active
  order by c.created_at
  limit 1;

  if v_client_id is null then
    insert into public.clients (tenant_id, name, phone, email)
    values (
      v_tenant_id,
      v_client_name,
      v_client_phone,
      nullif(trim(coalesce(p_client_email, '')), '')
    )
    returning id into v_client_id;
  end if;

  insert into public.tickets (
    tenant_id, branch_id, client_id, scheduled_at, status, channel, notes
  ) values (
    v_tenant_id,
    p_branch_id,
    v_client_id,
    p_scheduled_at,
    'solicitado',
    'web_publico',
    nullif(trim(coalesce(p_notes, '')), '')
  )
  returning id into v_ticket_id;

  insert into public.ticket_services (
    tenant_id, branch_id, ticket_id, service_id, stylist_id,
    price, duration_minutes, status
  ) values (
    v_tenant_id,
    p_branch_id,
    v_ticket_id,
    p_service_id,
    p_stylist_id,
    v_service_price,
    v_service_duration,
    'pendiente'
  );

  return query
  select
    tk.id,
    tk.scheduled_at,
    s.name,
    st.name,
    tk.status
  from public.tickets tk
  join public.services s on s.tenant_id = v_tenant_id and s.id = p_service_id
  join public.stylists st on st.tenant_id = v_tenant_id and st.id = p_stylist_id
  where tk.id = v_ticket_id;
end;
$$;

revoke all on function public.public_get_branch_booking_info(uuid)
  from public, authenticated;
revoke all on function public.public_get_bookable_services(uuid)
  from public, authenticated;
revoke all on function public.public_get_available_slots(uuid, uuid, uuid, date)
  from public, authenticated;
revoke all on function public.public_create_booking(
  uuid, uuid, uuid, timestamptz, text, text, text, text
) from public, authenticated;

grant execute on function public.public_get_branch_booking_info(uuid)
  to anon, service_role;
grant execute on function public.public_get_bookable_services(uuid)
  to anon, service_role;
grant execute on function public.public_get_available_slots(uuid, uuid, uuid, date)
  to anon, service_role;
grant execute on function public.public_create_booking(
  uuid, uuid, uuid, timestamptz, text, text, text, text
) to anon, service_role;

comment on function public.public_get_branch_booking_info(uuid)
  is 'Datos minimos de una sede activa para la pagina publica de reserva. Sin sesion.';
comment on function public.public_get_bookable_services(uuid)
  is 'Catalogo de servicios/profesionales visibles al cliente en una sede activa. Sin sesion.';
comment on function public.public_get_available_slots(uuid, uuid, uuid, date)
  is 'Disponibilidad futura publica, igual a la interna mas filtro visible_to_customer. Sin sesion.';
comment on function public.public_create_booking(
  uuid, uuid, uuid, timestamptz, text, text, text, text
) is 'Crea una reserva publica en estado solicitado; el negocio la confirma manualmente. Sin sesion.';

commit;
