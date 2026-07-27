-- BeautyOS - Hacer cumplir la prueba gratis vencida (bloque 1 de "hacer
-- cumplir los planes").
--
-- La fundacion de D-044 (plans/tenant_subscriptions/beautyos_resolve_entitlement)
-- nunca se consultaba desde ninguna RPC de negocio. El propietario decidio
-- (2026-07-25/26): cuando la prueba gratis de 21 dias se vence sin pago
-- registrado, el negocio se "desactiva" en el sentido de no poder aceptar
-- compromisos nuevos con clientes, pero conserva todo lo demas (catalogo,
-- equipo, compras, gastos, reportes, y terminar/cobrar tickets ya
-- abiertos). Sin tarea programada: se calcula al vuelo comparando
-- trial_ends_at contra el reloj en el momento de cada intento de reserva o
-- cita nueva, no con un job que reescriba `status`.
--
-- Reactivacion mientras no exista pasarela de pago: manual, via
-- platform_extend_trial (D-046) que ya existe en el panel de plataforma.

begin;

create or replace function private.beautyos_tenant_accepts_new_commitments(
  p_tenant_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_subscription public.tenant_subscriptions%rowtype;
begin
  select *
    into v_subscription
  from public.tenant_subscriptions
  where tenant_id = p_tenant_id;

  if v_subscription.id is null then
    return false;
  end if;

  if v_subscription.status = 'active' then
    return true;
  end if;

  if v_subscription.status = 'trialing' then
    return v_subscription.trial_ends_at is null
      or v_subscription.trial_ends_at > now();
  end if;

  return false;
end;
$$;

revoke all on function private.beautyos_tenant_accepts_new_commitments(uuid)
  from public, anon, authenticated;
grant execute on function private.beautyos_tenant_accepts_new_commitments(uuid)
  to service_role;

comment on function private.beautyos_tenant_accepts_new_commitments(uuid)
  is 'True si el tenant puede aceptar compromisos nuevos con clientes (activo, o en prueba gratis vigente). No bloquea lectura ni operaciones ya existentes.';

-- Reserva publica de cliente (D-053): bloquea reservas nuevas si la
-- prueba esta vencida. Mensaje generico, sin exponer detalles de
-- facturacion a un cliente anonimo.

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

  if not private.beautyos_tenant_accepts_new_commitments(v_tenant_id) then
    raise exception 'Este negocio no esta aceptando reservas nuevas en este momento.';
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

-- Ticket nuevo creado por el propio negocio (Tramo C2a): mismo bloqueo,
-- mensaje mas explicito porque quien llama es el equipo del negocio, no
-- un cliente anonimo.

create or replace function public.create_scheduled_ticket_with_service_v2(
  p_branch_id uuid,
  p_client_id uuid,
  p_service_id uuid,
  p_stylist_id uuid,
  p_scheduled_at timestamptz,
  p_channel text default 'manual',
  p_notes text default null
)
returns setof public.tickets
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_ticket public.tickets%rowtype;
  v_service_price numeric;
  v_service_duration integer;
begin
  select r.tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id,
    array['tenant_owner', 'admin', 'assistant'],
    true
  ) r;

  if not private.beautyos_tenant_accepts_new_commitments(v_tenant_id) then
    raise exception 'La prueba gratis de este negocio esta vencida. No se pueden crear citas nuevas hasta reactivar la suscripcion.';
  end if;

  if p_scheduled_at is null then
    raise exception 'La fecha y hora son obligatorias para una reserva.';
  end if;

  perform 1
  from public.clients c
  where c.id = p_client_id
    and c.tenant_id = v_tenant_id
    and c.active;

  if not found then
    raise exception 'El recurso no esta disponible para esta sede.';
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
    and bs.active;

  if not found then
    raise exception 'El recurso no esta disponible para esta sede.';
  end if;

  if not exists (
    select 1
    from public.get_available_appointment_slots_v2(
      p_branch_id,
      p_service_id,
      p_stylist_id,
      (p_scheduled_at at time zone (
        select b.timezone
        from public.branches b
        where b.tenant_id = v_tenant_id
          and b.id = p_branch_id
      ))::date
    ) slots
    where slots.starts_at = p_scheduled_at
  ) then
    raise exception 'El horario seleccionado ya no esta disponible.';
  end if;

  insert into public.tickets (
    tenant_id,
    branch_id,
    client_id,
    scheduled_at,
    status,
    channel,
    notes
  ) values (
    v_tenant_id,
    p_branch_id,
    p_client_id,
    p_scheduled_at,
    'solicitado',
    nullif(trim(coalesce(p_channel, 'manual')), ''),
    nullif(trim(coalesce(p_notes, '')), '')
  )
  returning * into v_ticket;

  insert into public.ticket_services (
    tenant_id,
    branch_id,
    ticket_id,
    service_id,
    stylist_id,
    price,
    duration_minutes,
    status
  ) values (
    v_tenant_id,
    p_branch_id,
    v_ticket.id,
    p_service_id,
    p_stylist_id,
    v_service_price,
    v_service_duration,
    'pendiente'
  );

  return next v_ticket;
end;
$$;

commit;
