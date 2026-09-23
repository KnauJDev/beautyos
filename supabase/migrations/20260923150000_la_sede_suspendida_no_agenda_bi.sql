-- ==============================================================================
-- HALLAZGO BI, lo que quedaba: la sede suspendida no agenda, y el candado dice
-- la verdad. Decision del propietario del 23-sep (D-260).
-- ==============================================================================
--
-- LO QUE DECIDIO EL PROPIETARIO
--
-- *"Cuando una sede no pague esta entra en modo suspendida por no pago… las
-- sedes heredaran los lineamientos y parametros del negocio."* Preguntado que
-- significa exactamente, eligio: **una sede suspendida no puede agendar citas
-- nuevas ni recibir reservas en linea; lo ya agendado se atiende y se cobra, y
-- las demas sedes al dia siguen normales.** Lo mismo que hoy le pasa al
-- negocio entero cuando se suspende.
--
-- Solo `suspended` bloquea. Una sede `pending` (recien creada, sin pagar
-- todavia) NO: eso no lo decidio nadie, y bloquearla seria inventarlo.
--
-- COMO SE HIZO: A PARTIR DEL TEXTO VIVO, NO DE MEMORIA
--
-- Las dos funciones de abajo son el texto que devolvio `pg_get_functiondef`
-- el 23-sep (`intervenciones/extraer_candado_y_vencimiento_bi.sql`), que
-- coincidia linea por linea con la ultima migracion del repositorio. Se
-- generaron con un guion que aplica SOLO estos cambios, comprobando cada uno:
--
--   * `create_scheduled_ticket_with_service_v2` (la agenda interna, "Atender
--     ya" y las citas recurrentes, que la reutilizan):
--       - el mensaje del candado del negocio sale de
--         `beautyos_motivo_sin_citas_nuevas`, segun el estado real. Decia
--         *"La prueba gratis de este negocio esta vencida"* tambien a quien
--         pago meses y dejo de pagar;
--       - y comprueba la sede.
--   * `public_create_booking` (la reserva en linea): comprueba la sede, con un
--     mensaje neutro para la clienta.
--
-- Nada mas cambia: firmas, parametros por defecto, search_path, validaciones
-- y el resto del cuerpo son los vivos.
--
-- COMO SE APLICA (lo aplica el propietario, regla 16)
--
--   1. Respaldo:   scripts\respaldo_supabase.ps1
--   2. Esta migracion con scripts\aplicar_sql.ps1
--   3. El control: supabase\sql\224_test_la_sede_suspendida_no_agenda.sql
-- ==============================================================================

-- Los mensajes llevan tildes. `aplicar_sql.ps1` no fija la codificacion, y en
-- Windows psql puede leer el archivo como WIN1252 y guardar "estÃ¡" en vez de
-- "está". Esta linea lo impide; el control 224 comprueba el resultado letra
-- por letra (D-260).
set client_encoding = 'UTF8';

begin;

-- ---------------------------------------------------------------------------
-- 1. ¿Acepta citas nuevas ESTA sede?
-- ---------------------------------------------------------------------------

create or replace function private.beautyos_branch_accepts_new_commitments(p_branch_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  -- Solo `suspended` bloquea (D-260). Una sede sin fila de suscripcion la
  -- gobierna el candado del negocio, que se comprueba antes.
  select not exists (
    select 1
    from public.branch_subscriptions bs
    where bs.branch_id = p_branch_id
      and bs.status = 'suspended'
  );
$$;

revoke all on function private.beautyos_branch_accepts_new_commitments(uuid) from public, anon, authenticated;
grant execute on function private.beautyos_branch_accepts_new_commitments(uuid) to service_role;

comment on function private.beautyos_branch_accepts_new_commitments(uuid) is
  'D-260: false si la sede esta suspendida por no pago. Solo suspended bloquea; pending no. '
  'Lo usan las dos puertas por las que nace una cita. NO ELIMINAR.';

-- ---------------------------------------------------------------------------
-- 2. Por que un negocio no puede agendar, dicho segun su estado
-- ---------------------------------------------------------------------------
--
-- Se llama SOLO cuando `beautyos_tenant_accepts_new_commitments` ya dijo que
-- no, asi que cada rama es la version bloqueada de ese estado.

create or replace function private.beautyos_motivo_sin_citas_nuevas(p_tenant_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = pg_catalog
as $$
declare
  v_estado text;
begin
  select ts.status into v_estado
  from public.tenant_subscriptions ts
  where ts.tenant_id = p_tenant_id;

  return case v_estado
    when 'trialing' then
      'La prueba gratis de este negocio terminó. Para volver a agendar citas nuevas hay que activar el plan en Configuración.'
    when 'active' then
      'El período pagado de este negocio venció. Para volver a agendar citas nuevas hay que renovarlo en Configuración.'
    when 'past_due' then
      'Terminaron los días de gracia de este negocio. Para volver a agendar citas nuevas hay que ponerse al día en Configuración.'
    when 'grace' then
      'Terminaron los días de gracia de este negocio. Para volver a agendar citas nuevas hay que ponerse al día en Configuración.'
    when 'suspended' then
      'Este negocio está suspendido por falta de pago. Para volver a agendar citas nuevas hay que ponerse al día en Configuración.'
    when 'pending' then
      'Este negocio todavía no ha sido aprobado. Podrá agendar citas cuando Salón y Más lo apruebe.'
    else
      'Este negocio no tiene una suscripción activa, así que no puede agendar citas nuevas.'
  end;
end;
$$;

revoke all on function private.beautyos_motivo_sin_citas_nuevas(uuid) from public, anon, authenticated;
grant execute on function private.beautyos_motivo_sin_citas_nuevas(uuid) to service_role;

comment on function private.beautyos_motivo_sin_citas_nuevas(uuid) is
  'D-260: el motivo, segun el estado, por el que un negocio no puede agendar citas nuevas. Sustituye al '
  '"la prueba gratis esta vencida" que se le decia tambien a quien habia pagado. NO ELIMINAR.';

-- ---------------------------------------------------------------------------
-- 3. La agenda interna (texto vivo + los dos cambios de arriba)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.create_scheduled_ticket_with_service_v2(p_branch_id uuid, p_client_id uuid, p_service_id uuid, p_stylist_id uuid, p_scheduled_at timestamp with time zone, p_channel text DEFAULT 'manual'::text, p_notes text DEFAULT NULL::text)
 RETURNS SETOF tickets
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
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
    -- D-260: el motivo segun el estado. Antes decia "la prueba gratis esta
    -- vencida" tambien a un negocio que habia pagado meses.
    raise exception '%', private.beautyos_motivo_sin_citas_nuevas(v_tenant_id);
  end if;

  -- D-260: una sede suspendida por no pago no agenda citas nuevas. Las demas
  -- sedes del negocio siguen normales, y lo ya agendado se atiende y se cobra.
  if not private.beautyos_branch_accepts_new_commitments(p_branch_id) then
    raise exception 'Esta sede está suspendida por falta de pago y no puede agendar citas nuevas. Lo ya agendado se atiende y se cobra normalmente. Se reactiva pagándola en Configuración, Tus sedes.';
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
$function$;

-- ---------------------------------------------------------------------------
-- 4. La reserva en linea (texto vivo + la comprobacion de la sede)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.public_create_booking(p_branch_id uuid, p_service_id uuid, p_stylist_id uuid, p_scheduled_at timestamp with time zone, p_client_name text, p_client_phone text, p_client_email text DEFAULT NULL::text, p_notes text DEFAULT NULL::text)
 RETURNS TABLE(ticket_id uuid, scheduled_at timestamp with time zone, service_name text, stylist_name text, status text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
declare
  v_tenant_id uuid;
  v_timezone text;
  v_service_price numeric;
  v_service_duration integer;
  v_client_id uuid;
  v_client_name text;
  v_client_phone text;
  v_phone_canonico text;
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

  -- D-260: una sede suspendida por no pago no recibe reservas en linea. A la
  -- clienta NO se le dice por que: la deuda del salon no es asunto suyo.
  if not private.beautyos_branch_accepts_new_commitments(p_branch_id) then
    raise exception 'Esta sede no está aceptando reservas nuevas en este momento.';
  end if;

  v_client_name := nullif(trim(coalesce(p_client_name, '')), '');
  v_client_phone := nullif(trim(coalesce(p_client_phone, '')), '');
  -- D-249: la regla del celular vive en UN sitio. Aqui solo se llama.
  -- Deja el numero en su forma canonica -- diez digitos, sin indicativo -- y
  -- se para si no lo es, que es lo que impide que nazca media llave.
  v_phone_canonico := private.beautyos_celular_valido(v_client_phone);

  if v_client_name is null then
    raise exception 'Escribe tu nombre para reservar.';
  end if;

  if v_phone_canonico is null then
    raise exception 'Escribe tu numero de celular para reservar.';
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
    and c.phone = v_phone_canonico
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
    and c.phone = v_phone_canonico
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
    and c.phone = v_phone_canonico
    and c.active
  order by c.created_at
  limit 1;

  if v_client_id is null then
    insert into public.clients (tenant_id, name, phone, email)
    values (
      v_tenant_id,
      v_client_name,
      v_phone_canonico,
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
$function$;

commit;
