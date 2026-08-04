-- BeautyOS - Citas recurrentes (agenda interna). Benchmarking
-- 2026-07-28 (AgendaPro), punto 4b: el propietario decidio empezar solo
-- por agenda interna (no reserva publica) y que, si una fecha de la
-- serie choca con otra cita, se creen las que no chocan y se avisen
-- claramente cuales fallaron (no todo o nada).
--
-- Diseno de bajo riesgo: reutiliza create_scheduled_ticket_with_service_v2
-- (Tramo C2a/D-068) tal cual, sin duplicar su logica de precio/duracion/
-- disponibilidad -- cualquier correccion futura en esa funcion aplica
-- automaticamente aqui tambien. No se agrega ninguna columna nueva a
-- tickets ni se crea un concepto de "serie" persistente: cada ocurrencia
-- queda como un ticket normal e independiente, gestionable con las
-- pantallas de Tickets que ya existen (cancelar/reprogramar cada una por
-- separado si hace falta). El unico resultado nuevo es el reporte de
-- exito/fracaso por fecha que se devuelve al momento de crear la serie.
--
-- Mismo tope de seguridad que los bloqueos recurrentes (D-080): maximo
-- 180 dias desde la primera cita.

begin;

create or replace function public.create_recurring_scheduled_tickets_v2(
  p_branch_id uuid,
  p_client_id uuid,
  p_service_id uuid,
  p_stylist_id uuid,
  p_scheduled_at timestamptz,
  p_repeat_frequency text,
  p_repeat_until date,
  p_channel text default 'manual',
  p_notes text default null
)
returns table (
  scheduled_at timestamptz,
  success boolean,
  ticket_id uuid,
  error_message text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_step interval;
  v_offset interval;
  v_occurrence timestamptz;
  v_ticket public.tickets%rowtype;
begin
  -- Autorizacion previa (rechazo limpio si no tiene acceso, en vez de
  -- devolver una tabla llena de fallas uno por uno).
  select r.tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner', 'admin', 'assistant'], true
  ) r;

  if p_scheduled_at is null then
    raise exception 'La fecha y hora de la primera cita son obligatorias.';
  end if;

  if p_repeat_frequency not in ('daily', 'weekly') then
    raise exception 'Frecuencia de repeticion no valida.';
  end if;

  if p_repeat_until is null then
    raise exception 'Indica hasta que fecha se repite la cita.';
  end if;

  if p_repeat_until < p_scheduled_at::date then
    raise exception 'La fecha final debe ser posterior a la primera cita.';
  end if;

  if p_repeat_until > (p_scheduled_at::date + 180) then
    raise exception 'Una serie de citas no puede repetirse por mas de 180 dias.';
  end if;

  v_step := case p_repeat_frequency
    when 'daily' then interval '1 day'
    else interval '7 days'
  end;

  v_offset := interval '0 day';

  while (p_scheduled_at + v_offset)::date <= p_repeat_until loop
    v_occurrence := p_scheduled_at + v_offset;

    begin
      select *
        into strict v_ticket
      from public.create_scheduled_ticket_with_service_v2(
        p_branch_id, p_client_id, p_service_id, p_stylist_id,
        v_occurrence, p_channel, p_notes
      );

      scheduled_at := v_occurrence;
      success := true;
      ticket_id := v_ticket.id;
      error_message := null;
      return next;
    exception
      when others then
        scheduled_at := v_occurrence;
        success := false;
        ticket_id := null;
        error_message := sqlerrm;
        return next;
    end;

    v_offset := v_offset + v_step;
  end loop;

  return;
end;
$$;

revoke all on function public.create_recurring_scheduled_tickets_v2(uuid, uuid, uuid, uuid, timestamptz, text, date, text, text)
  from public, anon;
grant execute on function public.create_recurring_scheduled_tickets_v2(uuid, uuid, uuid, uuid, timestamptz, text, date, text, text)
  to authenticated, service_role;

comment on function public.create_recurring_scheduled_tickets_v2(uuid, uuid, uuid, uuid, timestamptz, text, date, text, text)
  is 'Crea una serie de citas (agenda interna) reutilizando create_scheduled_ticket_with_service_v2 por cada ocurrencia. Las que chocan con otra cita o caen en un dia cerrado se reportan como fallidas sin tumbar el resto de la serie.';

commit;
