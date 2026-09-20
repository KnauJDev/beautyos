-- AP (segunda mitad): terminar un servicio tambien mira la caja.
--
-- EL FALLO
--
-- La comision solo se calcula cuando **entra un pago**:
-- `register_ticket_payment` llama a
-- `private.beautyos_close_ticket_if_fully_paid`, y esa funcion se sale de
-- vacio si el ticket todavia no esta `finalizado`.
--
-- Asi que si la clienta paga el 100% **antes** de que se marque el servicio
-- como terminado --un anticipo, que es justo lo que D-163 vino a permitir--,
-- cuando el servicio por fin se termina ya no queda ningun momento en el que
-- alguien vuelva a mirar el saldo. El ticket se queda en `finalizado` con
-- saldo cero **para siempre**, y la comision no nace nunca.
--
-- LO CURIOSO: EL REMEDIO ESTABA ESCRITO, EN LA PUERTA EQUIVOCADA
--
-- D-163 describio este caso palabra por palabra en un comentario que sigue
-- en la base:
--
--   "si un abono ya habia cubierto el 100% del precio cotizado antes de que
--    se marcaran los servicios, este es el unico momento en que se sabe que
--    el ticket quedo finalizado y pagado -- sin esto se quedaria en
--    'finalizado' con saldo 0 para siempre."
--
-- Y puso el `perform` correspondiente. Pero lo puso dentro de
-- `change_ticket_status`, el cambio de estado **del ticket a mano**, que para
-- aceptar `finalizado` exige que todos los servicios ya esten terminados --y
-- cuando eso se cumple, `change_ticket_service_status` ya movio el ticket a
-- `finalizado` por su cuenta, asi que la llamada sale por el
-- `if v_new_status = v_ticket.status then return` de arriba.
--
-- **El remedio estaba en una puerta que no se puede usar.** La puerta por la
-- que el ticket llega de verdad a `finalizado` --terminar el ultimo
-- servicio-- se quedo sin el. Aqui se le pone.
--
-- Ese guarda de `change_ticket_status` **no se quita**: si algun dia alguien
-- llama esa RPC directamente, sigue siendo la red correcta. Lo que estaba mal
-- no era tenerlo, era tenerlo **solo** ahi.
--
-- COMO SE ESCRIBIO ESTA MIGRACION
--
-- Se extrajo el texto vivo de la funcion con
-- `supabase/sql/intervenciones/extraer_cambio_de_estado_de_servicio.sql` y se
-- comparo linea por linea con `supabase/sql/071` (D-119, D-122, D-123). Las
-- 152 lineas del cuerpo coinciden: las unicas tres diferencias eran acentos
-- que la extraccion trajo mal codificados. **Un solo cambio respecto al texto
-- vivo**, marcado abajo con `-- AP:`.
--
-- Lo prueba el **control 218**, comprobaciones 5 y 9.

begin;

create or replace function public.change_ticket_service_status(
  p_ticket_service_id uuid,
  p_new_status text
)
returns setof public.ticket_services
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_role text;
  v_stylist_id uuid;
  v_service public.ticket_services%rowtype;
  v_ticket public.tickets%rowtype;
  v_new_status text;
begin
  select up.tenant_id, up.role, up.stylist_id
    into v_tenant_id, v_role, v_stylist_id
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.active = true
  limit 1;

  if v_tenant_id is null or v_role not in ('owner', 'admin', 'assistant', 'stylist') then
    raise exception 'No autorizado para actualizar servicios del ticket.';
  end if;

  select *
    into v_service
  from public.ticket_services ts
  where ts.id = p_ticket_service_id
    and ts.tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'Servicio del ticket no encontrado o no pertenece al centro actual.';
  end if;

  select *
    into v_ticket
  from public.tickets t
  where t.id = v_service.ticket_id
    and t.tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'El ticket asociado no está disponible.';
  end if;

  if v_role = 'stylist' and v_service.stylist_id is distinct from v_stylist_id then
    raise exception 'Solo puedes actualizar servicios asignados a tu agenda.';
  end if;

  v_new_status := lower(trim(coalesce(p_new_status, '')));

  if v_new_status not in ('pendiente', 'en_proceso', 'finalizado', 'cancelado') then
    raise exception 'Estado de servicio no válido.';
  end if;

  if v_new_status = v_service.status then
    return query select ts.* from public.ticket_services ts where ts.id = v_service.id;
    return;
  end if;

  if v_role = 'stylist' and v_new_status not in ('en_proceso', 'finalizado') then
    raise exception 'Un estilista solo puede iniciar o finalizar sus servicios asignados.';
  end if;

  if v_service.status = 'pendiente' and v_new_status = 'en_proceso' then
    if v_ticket.status not in ('confirmado', 'en_espera', 'en_proceso') then
      raise exception 'El ticket debe estar confirmado o en espera para iniciar el servicio.';
    end if;
  elsif v_service.status = 'en_proceso' and v_new_status = 'finalizado' then
    if v_ticket.status <> 'en_proceso' then
      raise exception 'El ticket debe estar en proceso para finalizar el servicio.';
    end if;
  elsif v_role in ('owner', 'admin', 'assistant')
        and v_service.status in ('pendiente', 'en_proceso')
        and v_new_status = 'cancelado' then
    null;
  else
    raise exception 'La transición de servicio de % a % no está permitida.',
      v_service.status, v_new_status;
  end if;

  update public.ticket_services
     set status = v_new_status
   where id = v_service.id
     and tenant_id = v_tenant_id;

  insert into public.ticket_service_history (
    tenant_id,
    ticket_id,
    ticket_service_id,
    previous_status,
    new_status,
    created_by
  ) values (
    v_tenant_id,
    v_ticket.id,
    v_service.id,
    v_service.status,
    v_new_status,
    auth.uid()
  );

  if v_new_status = 'en_proceso' and v_ticket.status <> 'en_proceso' then
    update public.tickets
       set status = 'en_proceso'
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
      'en_proceso',
      'Inicio de servicio asignado',
      auth.uid()
    );
  end if;

  if v_new_status = 'finalizado'
     and not exists (
       select 1
       from public.ticket_services ts
       where ts.ticket_id = v_ticket.id
         and ts.tenant_id = v_tenant_id
         and ts.status in ('pendiente', 'en_proceso')
     )
     and exists (
       select 1
       from public.ticket_services ts
       where ts.ticket_id = v_ticket.id
         and ts.tenant_id = v_tenant_id
         and ts.status = 'finalizado'
     ) then
    update public.tickets
       set status = 'finalizado'
     where id = v_ticket.id
       and tenant_id = v_tenant_id
       and status = 'en_proceso';

    if found then
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
        'en_proceso',
        'finalizado',
        'Todos los servicios del ticket finalizaron',
        auth.uid()
      );

      -- AP: EL UNICO CAMBIO. Este es el otro momento en que se sabe que el
      -- ticket quedo finalizado, y hasta hoy nadie miraba la caja aqui. Si
      -- la clienta ya habia pagado el 100% por adelantado (D-163), el cierre
      -- y la comision no llegaban nunca.
      --
      -- Va dentro del `if found` a proposito: solo cuando este `update`
      -- acaba de mover el ticket. La funcion es idempotente de todos modos
      -- --se sale de vacio si no esta finalizado o si falta saldo, y su
      -- `insert` excluye las comisiones ya generadas-- pero llamarla de mas
      -- seria decir que aqui pasa algo que no paso.
      perform private.beautyos_close_ticket_if_fully_paid(v_ticket.id, v_tenant_id);
    end if;
  end if;

  return query
  select ts.*
  from public.ticket_services ts
  where ts.id = v_service.id;
end;
$$;

comment on function public.change_ticket_service_status(uuid, text)
  is 'NO ELIMINAR: llamada internamente por change_ticket_service_status_v2 (D-040, Paso 8.1). Sin EXECUTE directo para anon/authenticated desde D-040; solo el dueño del esquema (el wrapper) puede invocarla. Desde AP (20-sep) cierra el ticket y genera comisiones cuando el ultimo servicio se termina sobre un ticket ya pagado: el perform que D-163 dejo en change_ticket_status no alcanzaba este camino.';

commit;
