-- Tramo Etapa 1, tarea 1.1 (hallazgo H-02 de la auditoria integral del
-- 2026-08-06): limitar la reserva publica.
--
-- Problema: public_create_booking no tenia ningun freno. Quien tuviera el
-- enlace publico de una sede podia crear reservas sin limite, y como cada una
-- ocupa el horario de inmediato, podia dejar la agenda inservible y llenar la
-- tabla de clientes de basura.
--
-- Se agregan dos topes, ambos por numero de celular dentro del negocio:
--   1. Maximo 4 citas futuras activas a la vez.
--   2. Maximo 8 reservas creadas en las ultimas 24 horas.
--
-- Los numeros salen de un caso real: en la reserva publica cada cita es un
-- solo servicio con un solo profesional, asi que una clienta que quiera corte
-- y unas ya necesita dos reservas, y una mama que agende para ella y sus dos
-- hijas necesita tres. Con un tope de 3 esa familia quedaba fuera. Se prefiere
-- pecar de amplio: que un abusador tenga un horario mas da igual, que una
-- clienta real sea rechazada cuesta el cliente.
--
-- Limite conocido: quien cambie de numero de celular en cada intento sigue
-- pudiendo insistir. Cerrar eso del todo exige verificar el celular con un
-- codigo, que es una decision aparte y de mayor alcance. Estos topes cubren
-- el abuso realista y el doble clic accidental, sin estorbar a un cliente
-- normal.

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
  v_futuras integer;
  v_recientes integer;
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

  -- Tope de reservas por celular (H-02). Sin esto, cualquiera con el enlace
  -- publico puede llenar la agenda: cada reserva nace en 'solicitado' con su
  -- servicio en 'pendiente', y eso ya ocupa el horario para las funciones de
  -- disponibilidad y para el trigger de choque, sin que el negocio confirme
  -- nada. Solo se cuentan las reservas del canal publico: las que crea el
  -- propio negocio por telefono o mostrador no deben estorbar al cliente.
  select count(*)
    into v_futuras
  from public.tickets tk
  join public.clients c
    on c.id = tk.client_id
   and c.tenant_id = tk.tenant_id
  where tk.tenant_id = v_tenant_id
    and c.phone = v_client_phone
    and tk.channel = 'web_publico'
    and tk.scheduled_at > now()
    and tk.status in ('solicitado', 'confirmado', 'en_espera', 'en_proceso');

  if v_futuras >= 4 then
    raise exception 'Ya tienes 4 citas pendientes con este numero de celular. Si necesitas otra, comunicate con el negocio.';
  end if;

  -- Las canceladas si cuentan aqui, a proposito: es lo que frena el ciclo de
  -- reservar y cancelar en bucle para saturar la agenda.
  select count(*)
    into v_recientes
  from public.tickets tk
  join public.clients c
    on c.id = tk.client_id
   and c.tenant_id = tk.tenant_id
  where tk.tenant_id = v_tenant_id
    and c.phone = v_client_phone
    and tk.channel = 'web_publico'
    and tk.created_at > now() - interval '24 hours';

  if v_recientes >= 8 then
    raise exception 'Este numero de celular ya hizo varias reservas hoy. Intenta de nuevo manana o comunicate con el negocio.';
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
