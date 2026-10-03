-- D-312: AGENDA DE TRES ESTADOS para los negocios con la caja apagada.
-- Paso 2 del plan del primer cliente real (D-308), ampliado por el
-- propietario el 02-oct.
--
-- LO QUE SE DECIDIO
--
-- A un negocio al que la plataforma le apago 'Caja y cobros' desde el Panel
-- (D-310) --David, que solo quiere agenda--:
--   * toda cita nace CONFIRMADA, la pida la clienta por el enlace o la cree
--     el salon (tambien las recurrentes);
--   * la agenda tiene tres estados: Confirmado -> En proceso -> Cerrado;
--   * Cancelar y No asistio son botones, no columnas;
--   * va amarrado al interruptor de la caja: no hay interruptor nuevo.
--
-- QUE TOCA ESTA MIGRACION: SOLO COMO NACE UNA CITA
--
-- La lectura (`intervenciones/extraer_agenda_de_tres_estados_paso2.sql`)
-- mostro que el resto ya existe y no hay que tocarlo:
--   * "Cerrado" para un negocio sin caja es el estado `finalizado`: el ticket
--     llega solo cuando se terminan todos sus servicios
--     (`change_ticket_service_status`). El cierre CON DINERO (`cerrado`, el
--     numero de venta y la comision) solo ocurre si los pagos cubren el
--     total (`beautyos_close_ticket_if_fully_paid` se sale de vacio si no).
--     **No nace ningun pago ni comision, y no se toca el historial de
--     dinero** (AGENTS.md).
--   * Iniciar, terminar, cancelar y no asistio ya los permiten
--     `change_ticket_status` y `change_ticket_service_status` a duenyo,
--     admin y recepcion, con su historial. Lo que faltaba eran los botones
--     en la agenda: eso es de la app.
--   * El tope de reservas por celular (H-02) ya cuenta las confirmadas
--     (`'solicitado', 'confirmado', 'en_espera', 'en_proceso'`): que la cita
--     nazca confirmada no abre ningun hueco.
--   * El choque de horarios y la disponibilidad ya tratan igual una cita
--     solicitada que una confirmada: las dos ocupan el horario.
--
-- COMO SE ESCRIBIO
--
-- Las dos funciones se copiaron del texto vivo (regla 10) que dejo la
-- lectura en `_vivo_paso2_tres_estados.sql`. **Un solo cambio en cada una**,
-- marcado `-- D-312`: el estado con que nace la cita. Todo lo demas es
-- identico, linea por linea, a lo que corre hoy. Para los negocios con la
-- caja encendida --todos los demas-- no cambia nada: siguen naciendo en
-- 'solicitado'.
--
-- Lo prueba el **control 240**.

-- Las tildes del texto vivo ('está', 'Esta sede está suspendida…') llegan
-- bien solo si psql lee el archivo como UTF-8 (BL).
set client_encoding = 'UTF8';

begin;

-- ---------------------------------------------------------------------------
-- 1. La pregunta, en UN sitio: ¿este negocio tiene la agenda de tres estados?
-- ---------------------------------------------------------------------------
create or replace function private.beautyos_agenda_de_tres_estados(p_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  -- Solo cuando la PLATAFORMA le apago la caja (una excepcion desde el
  -- Panel, D-310). Un negocio sin suscripcion operativa tambien sale con
  -- la caja negada, pero por otro motivo (`sin_suscripcion_operativa`), y
  -- su agenda no cambia por eso. Es la misma regla que usa la app en
  -- `TenantEntitlements.apagadoPorLaPlataforma`.
  select coalesce((
    select not r.entitled and r.source = 'override'
    from private.beautyos_resolve_entitlement(p_tenant_id, 'cash_register') r
  ), false);
$$;

revoke all on function private.beautyos_agenda_de_tres_estados(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. La reserva por el enlace publico. Texto vivo; un solo cambio, `-- D-312`.
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
    -- D-312: EL UNICO CAMBIO. Con la caja apagada por la plataforma, la
    -- agenda del negocio es de tres estados y la cita nace confirmada.
    case when private.beautyos_agenda_de_tres_estados(v_tenant_id)
         then 'confirmado' else 'solicitado' end,
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

-- ---------------------------------------------------------------------------
-- 3. La cita que crea el salon (y las recurrentes, que la llaman a ella).
--    Texto vivo; un solo cambio, `-- D-312`.
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
    -- D-312: EL UNICO CAMBIO. Con la caja apagada por la plataforma, la
    -- agenda del negocio es de tres estados y la cita nace confirmada.
    case when private.beautyos_agenda_de_tres_estados(v_tenant_id)
         then 'confirmado' else 'solicitado' end,
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

commit;
