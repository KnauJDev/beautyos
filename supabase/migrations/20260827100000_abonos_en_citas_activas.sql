-- ============================================================================
-- MIGRACIÓN: 20260827100000_abonos_en_citas_activas.sql
-- DESCRIPCIÓN: El salón puede cobrar abonos/anticipos desde que la cita se
--              solicita, no solo cuando ya se atendió (D-163). El bloqueo
--              real estaba en `register_ticket_payment`: exigía
--              `status = 'finalizado'` y sumaba solo los servicios ya
--              finalizados como "total a cobrar". Se relaja al mismo
--              criterio que `AccionesDeTicket.puedeGestionarPagos` en
--              Flutter (cualquier estado activo, ni cancelado ni
--              no_asistio) y al mismo cálculo de "Total" que ya usa
--              `get_ticket_board_list_v2` en el Tablero de Agenda: suma de
--              todo servicio no cancelado, no solo el finalizado.
--
--              El cierre automático del ticket y la generación de
--              comisiones al llegar a saldo 0 SOLO deben pasar cuando el
--              ticket ya está `finalizado` (el servicio se prestó de
--              verdad). Un abono que cubra el 100% del precio cotizado
--              ANTES de atender no debe cerrar la cita ni generar
--              comisiones por un servicio que aún no se hizo.
--
--              Por eso el cierre se saca a un helper privado compartido,
--              `private.beautyos_close_ticket_if_fully_paid`, llamado desde
--              DOS sitios: (1) al registrar un pago, por si llega después
--              de finalizar el servicio (caso de hoy, sin cambios de
--              comportamiento); (2) al pasar el ticket a `finalizado`, por
--              si el abono ya cubría el total ANTES de marcar los
--              servicios como hechos (caso nuevo de este bloque).
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- 1. Helper privado: cierra el ticket y genera comisiones si ya está
--    finalizado y el saldo llega a 0. Idempotente a propósito: si ya está
--    cerrado, si aún no está finalizado, o si queda saldo pendiente, no hace
--    nada. Mismo bloque de cierre+comisiones que tenía `register_ticket_payment`
--    antes de este bloque, solo movido aquí para poder llamarlo desde dos
--    sitios sin duplicar la lógica de dinero (D-163).
-- ----------------------------------------------------------------------------
create or replace function private.beautyos_close_ticket_if_fully_paid(
  p_ticket_id uuid,
  p_tenant_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ticket public.tickets%rowtype;
  v_total numeric(12, 2);
  v_paid numeric(12, 2);
begin
  select *
    into v_ticket
  from public.tickets t
  where t.id = p_ticket_id
    and t.tenant_id = p_tenant_id
  for update;

  if not found or v_ticket.status <> 'finalizado' then
    return;
  end if;

  select coalesce(sum(ts.price), 0)::numeric(12, 2)
    into v_total
  from public.ticket_services ts
  where ts.ticket_id = v_ticket.id
    and ts.tenant_id = p_tenant_id
    and ts.status <> 'cancelado';

  select coalesce(sum(tp.amount), 0)::numeric(12, 2)
    into v_paid
  from public.ticket_payments tp
  where tp.ticket_id = v_ticket.id
    and tp.tenant_id = p_tenant_id
    and tp.status = 'registrado';

  if v_paid < v_total then
    return;
  end if;

  update public.tickets
     set status = 'cerrado'
   where id = v_ticket.id
     and tenant_id = p_tenant_id;

  insert into public.ticket_history (
    tenant_id, ticket_id, event_type, previous_status, new_status, reason, created_by
  ) values (
    p_tenant_id,
    v_ticket.id,
    'status_changed',
    'finalizado',
    'cerrado',
    'Saldo pagado completamente',
    auth.uid()
  );

  insert into public.stylist_commissions (
    tenant_id,
    ticket_id,
    ticket_service_id,
    stylist_id,
    commission_policy_id,
    commission_override_id,
    service_amount,
    commission_type,
    commission_percentage,
    fixed_commission_amount,
    applies_after_discount,
    commission_amount,
    generated_at,
    generated_by
  )
  select
    p_tenant_id,
    v_ticket.id,
    ts.id,
    ts.stylist_id,
    cp.id,
    ov.id,
    ts.price,
    coalesce(ov.commission_type, cp.commission_type),
    coalesce(ov.commission_percentage, cp.commission_percentage),
    coalesce(ov.fixed_commission_amount, cp.fixed_commission_amount),
    cp.applies_after_discount,
    case
      when coalesce(ov.commission_type, cp.commission_type) = 'fixed'
        then coalesce(ov.fixed_commission_amount, cp.fixed_commission_amount)
      else round(ts.price * coalesce(ov.commission_percentage, cp.commission_percentage) / 100, 2)
    end,
    now(),
    auth.uid()
  from public.ticket_services ts
  join public.commission_policies cp
    on cp.tenant_id = p_tenant_id
   and cp.active = true
  left join public.stylist_service_commissions ov
    on ov.tenant_id = p_tenant_id
   and ov.branch_id = v_ticket.branch_id
   and ov.stylist_id = ts.stylist_id
   and ov.service_id = ts.service_id
   and ov.active
  where ts.ticket_id = v_ticket.id
    and ts.tenant_id = p_tenant_id
    and ts.status = 'finalizado'
    and ts.stylist_id is not null
    and not exists (
      select 1
      from public.stylist_commissions sc
      where sc.ticket_service_id = ts.id
        and sc.status = 'generada'
    );
end;
$$;

revoke all on function private.beautyos_close_ticket_if_fully_paid(uuid, uuid)
  from public, anon, authenticated;
grant execute on function private.beautyos_close_ticket_if_fully_paid(uuid, uuid)
  to service_role;

comment on function private.beautyos_close_ticket_if_fully_paid(uuid, uuid)
  is 'Cierra el ticket y genera comisiones si ya esta finalizado y el saldo llega a 0. Compartido entre register_ticket_payment y change_ticket_status (D-163) para que un abono del 100% ANTES de atender no cierre la cita ni genere comisiones antes de tiempo.';

-- ----------------------------------------------------------------------------
-- 2. register_ticket_payment: permite abonos en cualquier estado activo, no
--    solo `finalizado`. Misma firma que antes (D-163 no cambia parámetros).
-- ----------------------------------------------------------------------------
create or replace function public.register_ticket_payment(
  p_ticket_id uuid,
  p_amount numeric,
  p_method text,
  p_reference text default null,
  p_notes text default null
)
returns setof public.ticket_payments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_role text;
  v_ticket public.tickets%rowtype;
  v_total numeric(12, 2);
  v_paid numeric(12, 2);
  v_balance numeric(12, 2);
  v_method text;
  v_payment public.ticket_payments%rowtype;
begin
  select up.tenant_id, up.role
    into v_tenant_id, v_role
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.active = true
  limit 1;

  if v_tenant_id is null or v_role not in ('owner', 'admin', 'assistant') then
    raise exception 'No autorizado para registrar pagos.';
  end if;

  select *
    into v_ticket
  from public.tickets t
  where t.id = p_ticket_id
    and t.tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'Ticket no encontrado o no pertenece al centro actual.';
  end if;

  -- D-163: antes exigia 'finalizado'. Un abono/anticipo es valido en
  -- cualquier estado activo -- solo una cita cancelada o no asistida no
  -- admite cobros (mismo criterio que AccionesDeTicket.puedeGestionarPagos).
  if v_ticket.status in ('cancelado', 'no_asistio') then
    raise exception 'No se pueden registrar pagos en una cita cancelada o no asistida.';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'El valor del pago debe ser mayor que cero.';
  end if;

  v_method := lower(trim(coalesce(p_method, '')));

  if v_method not in ('efectivo', 'tarjeta', 'transferencia', 'otro') then
    raise exception 'Metodo de pago no valido.';
  end if;

  -- D-163: antes sumaba solo `ts.status = 'finalizado'`, lo que daba 0 en
  -- una cita activa sin atender aun. Mismo criterio que ya usa
  -- `get_ticket_board_list_v2` para mostrar "Total" en el Tablero de
  -- Agenda: todo servicio no cancelado cuenta para el total a cobrar.
  select coalesce(sum(ts.price), 0)::numeric(12, 2)
    into v_total
  from public.ticket_services ts
  where ts.ticket_id = v_ticket.id
    and ts.tenant_id = v_tenant_id
    and ts.status <> 'cancelado';

  if v_total <= 0 then
    raise exception 'El ticket no tiene servicios para cobrar.';
  end if;

  select coalesce(sum(tp.amount), 0)::numeric(12, 2)
    into v_paid
  from public.ticket_payments tp
  where tp.ticket_id = v_ticket.id
    and tp.tenant_id = v_tenant_id
    and tp.status = 'registrado';

  v_balance := v_total - v_paid;

  if v_balance <= 0 then
    raise exception 'El ticket ya esta completamente pagado.';
  end if;

  if p_amount > v_balance then
    raise exception 'El pago supera el saldo pendiente de %.', v_balance;
  end if;

  insert into public.ticket_payments (
    tenant_id, ticket_id, amount, method, reference, notes, created_by
  ) values (
    v_tenant_id,
    v_ticket.id,
    p_amount,
    v_method,
    nullif(trim(coalesce(p_reference, '')), ''),
    nullif(trim(coalesce(p_notes, '')), ''),
    auth.uid()
  )
  returning * into v_payment;

  -- D-163: el cierre + comisiones se movieron al helper compartido. Si el
  -- ticket ya esta 'finalizado' y este pago deja el saldo en 0, cierra
  -- igual que antes. Si el ticket todavia no esta finalizado (abono
  -- temprano), el helper no hace nada -- la cita sigue activa.
  perform private.beautyos_close_ticket_if_fully_paid(v_ticket.id, v_tenant_id);

  return next v_payment;
end;
$$;

-- ----------------------------------------------------------------------------
-- 3. change_ticket_status: si el ticket llega a 'finalizado' ya
--    completamente pagado (abono del 100% antes de atender), cierra y
--    genera comisiones en ese mismo momento -- si no, se quedaria en
--    'finalizado' con saldo 0 para siempre, porque la unica otra via a
--    'cerrado' es un pago nuevo que ya no va a llegar. Misma firma que
--    antes (D-163 no cambia parámetros).
-- ----------------------------------------------------------------------------
create or replace function public.change_ticket_status(
  p_ticket_id uuid,
  p_new_status text,
  p_reason text default null
)
returns setof public.tickets
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_role text;
  v_ticket public.tickets%rowtype;
  v_new_status text;
  v_reason text;
begin
  select up.tenant_id, up.role
    into v_tenant_id, v_role
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.active = true
  limit 1;

  if v_tenant_id is null or v_role not in ('owner', 'admin', 'assistant') then
    raise exception 'No autorizado para cambiar el estado del ticket.';
  end if;

  select *
    into v_ticket
  from public.tickets t
  where t.id = p_ticket_id
    and t.tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'Ticket no encontrado o no pertenece al centro actual.';
  end if;

  v_new_status := lower(trim(coalesce(p_new_status, '')));
  v_reason := nullif(trim(coalesce(p_reason, '')), '');

  if v_new_status not in (
    'solicitado', 'cotizado', 'apartado', 'confirmado', 'en_espera',
    'en_proceso', 'finalizado', 'cerrado', 'cancelado', 'no_asistio'
  ) then
    raise exception 'Estado de ticket no válido.';
  end if;

  if v_new_status = v_ticket.status then
    return query select t.* from public.tickets t where t.id = v_ticket.id;
    return;
  end if;

  if v_new_status = 'cerrado' then
    raise exception 'Un ticket solo podrá cerrarse cuando exista el registro de pago.';
  end if;

  if v_new_status in ('cancelado', 'no_asistio') and v_reason is null then
    raise exception 'Indica el motivo para cancelar o marcar que no asistió.';
  end if;

  if v_new_status in ('apartado', 'confirmado', 'en_espera', 'en_proceso')
     and v_ticket.scheduled_at is null then
    raise exception 'Programa fecha y hora antes de llevar el ticket a ese estado.';
  end if;

  if not (
    (v_ticket.status = 'solicitado' and v_new_status in ('cotizado', 'apartado', 'confirmado', 'cancelado'))
    or (v_ticket.status = 'cotizado' and v_new_status in ('apartado', 'confirmado', 'cancelado'))
    or (v_ticket.status = 'apartado' and v_new_status in ('confirmado', 'cancelado'))
    or (v_ticket.status = 'confirmado' and v_new_status in ('en_espera', 'en_proceso', 'cancelado', 'no_asistio'))
    or (v_ticket.status = 'en_espera' and v_new_status in ('en_proceso', 'cancelado', 'no_asistio'))
    or (v_ticket.status = 'en_proceso' and v_new_status = 'finalizado')
  ) then
    raise exception 'La transición de % a % no está permitida.', v_ticket.status, v_new_status;
  end if;

  if v_new_status in ('cancelado', 'no_asistio')
     and exists (
       select 1
       from public.ticket_services ts
       where ts.ticket_id = v_ticket.id
         and ts.tenant_id = v_tenant_id
         and ts.status = 'finalizado'
     ) then
    raise exception 'No se puede % un ticket con servicios finalizados.', v_new_status;
  end if;

  if v_new_status = 'en_proceso'
     and not exists (
       select 1
       from public.ticket_services ts
       where ts.ticket_id = v_ticket.id
         and ts.tenant_id = v_tenant_id
         and ts.status in ('pendiente', 'en_proceso')
     ) then
    raise exception 'El ticket necesita al menos un servicio activo para iniciar atención.';
  end if;

  if v_new_status = 'finalizado'
     and (
       not exists (
         select 1
         from public.ticket_services ts
         where ts.ticket_id = v_ticket.id
           and ts.tenant_id = v_tenant_id
           and ts.status = 'finalizado'
       )
       or exists (
         select 1
         from public.ticket_services ts
         where ts.ticket_id = v_ticket.id
           and ts.tenant_id = v_tenant_id
           and ts.status in ('pendiente', 'en_proceso')
       )
     ) then
    raise exception 'Finaliza todos los servicios activos antes de finalizar el ticket.';
  end if;

  if v_new_status in ('cancelado', 'no_asistio') then
    update public.ticket_services
       set status = 'cancelado'
     where ticket_id = v_ticket.id
       and tenant_id = v_tenant_id
       and status in ('pendiente', 'en_proceso');
  end if;

  update public.tickets
     set status = v_new_status
   where id = v_ticket.id
     and tenant_id = v_tenant_id;

  insert into public.ticket_history (
    tenant_id,
    ticket_id,
    event_type,
    previous_status,
    new_status,
    reason,
    created_by
  ) values (
    v_tenant_id,
    v_ticket.id,
    'status_changed',
    v_ticket.status,
    v_new_status,
    v_reason,
    auth.uid()
  );

  -- D-163: si un abono ya habia cubierto el 100% del precio cotizado antes
  -- de que se marcaran los servicios, este es el unico momento en que se
  -- sabe que el ticket quedo finalizado y pagado -- sin esto se quedaria en
  -- 'finalizado' con saldo 0 para siempre.
  if v_new_status = 'finalizado' then
    perform private.beautyos_close_ticket_if_fully_paid(v_ticket.id, v_tenant_id);
  end if;

  return query
  select t.*
  from public.tickets t
  where t.id = v_ticket.id;
end;
$$;

commit;
