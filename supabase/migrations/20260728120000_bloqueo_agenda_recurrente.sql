-- BeautyOS - Bloqueo de agenda recurrente (diario/semanal hasta una fecha).
-- Benchmarking 2026-07-28 (AgendaPro), punto 4a: extiende D-075
-- (stylist_time_off, un solo rango) para permitir repetir el bloqueo sin
-- crearlo manualmente uno por uno.
--
-- Diseno de bajo riesgo: cada ocurrencia se genera como una fila normal
-- de stylist_time_off (igual que si se hubiera creado a mano), ligadas
-- por recurrence_group_id. Ni get_available_appointment_slots_v2, ni
-- public_get_available_slots, ni enforce_stylist_schedule_conflict
-- necesitan ningun cambio -- ya consultan stylist_time_off fila por fila
-- por rango de fecha, exactamente como antes.
--
-- Tope de seguridad: el rango de repeticion no puede superar 180 dias
-- desde el primer bloqueo, para evitar generar una serie enorme por
-- error (ej. escoger mal el año en el selector de fecha).

begin;

alter table public.stylist_time_off
  add column if not exists recurrence_group_id uuid;

create index if not exists stylist_time_off_recurrence_group_idx
  on public.stylist_time_off (tenant_id, recurrence_group_id)
  where recurrence_group_id is not null;

comment on column public.stylist_time_off.recurrence_group_id
  is 'Agrupa las ocurrencias generadas por un mismo bloqueo recurrente. Null si el bloqueo no se repite.';

-- DROP requerido: se agregan 2 parametros nuevos, Postgres lo trataria
-- como una sobrecarga distinta (ambigua con la firma vieja de 5) en vez
-- de un reemplazo.
drop function if exists public.create_stylist_time_off(uuid, timestamptz, timestamptz, text, uuid);

create or replace function public.create_stylist_time_off(
  p_branch_id uuid,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_reason text default null,
  p_stylist_id uuid default null,
  p_repeat_frequency text default null,
  p_repeat_until date default null
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_access record;
  v_stylist_id uuid;
  v_id uuid;
  v_reason text;
  v_group_id uuid;
  v_step interval;
  v_offset interval;
  v_occurrence_start timestamptz;
  v_occurrence_end timestamptz;
begin
  select * into strict v_access
  from private.beautyos_resolve_branch_access(
    p_branch_id,
    array['tenant_owner', 'admin', 'stylist']::text[],
    true
  );

  if p_starts_at is null or p_ends_at is null then
    raise exception 'El inicio y el fin del bloqueo son obligatorios.';
  end if;

  if p_ends_at <= p_starts_at then
    raise exception 'El fin del bloqueo debe ser posterior al inicio.';
  end if;

  if v_access.role = 'stylist' then
    v_stylist_id := v_access.stylist_id;
  elsif p_stylist_id is not null then
    if not exists (
      select 1 from public.stylists s
      where s.id = p_stylist_id and s.tenant_id = v_access.tenant_id
    ) then
      raise exception 'El estilista seleccionado no pertenece a este negocio.';
    end if;
    v_stylist_id := p_stylist_id;
  else
    raise exception 'Selecciona a que estilista corresponde este bloqueo.';
  end if;

  v_reason := nullif(trim(coalesce(p_reason, '')), '');

  if p_repeat_frequency is null then
    insert into public.stylist_time_off (
      tenant_id, stylist_id, starts_at, ends_at, reason, created_by
    ) values (
      v_access.tenant_id, v_stylist_id, p_starts_at, p_ends_at, v_reason, auth.uid()
    )
    returning id into v_id;

    return v_id;
  end if;

  if p_repeat_frequency not in ('daily', 'weekly') then
    raise exception 'Frecuencia de repeticion no valida.';
  end if;

  if p_repeat_until is null then
    raise exception 'Indica hasta que fecha se repite el bloqueo.';
  end if;

  if p_repeat_until < p_starts_at::date then
    raise exception 'La fecha final debe ser posterior al primer bloqueo.';
  end if;

  if p_repeat_until > (p_starts_at::date + 180) then
    raise exception 'Un bloqueo recurrente no puede repetirse por mas de 180 dias.';
  end if;

  v_step := case p_repeat_frequency
    when 'daily' then interval '1 day'
    else interval '7 days'
  end;

  v_group_id := gen_random_uuid();
  v_offset := interval '0 day';

  while (p_starts_at + v_offset)::date <= p_repeat_until loop
    v_occurrence_start := p_starts_at + v_offset;
    v_occurrence_end := p_ends_at + v_offset;

    insert into public.stylist_time_off (
      tenant_id, stylist_id, starts_at, ends_at, reason, created_by,
      recurrence_group_id
    ) values (
      v_access.tenant_id, v_stylist_id, v_occurrence_start, v_occurrence_end,
      v_reason, auth.uid(), v_group_id
    )
    returning id into v_id;

    v_offset := v_offset + v_step;
  end loop;

  return v_group_id;
end;
$$;

-- Cancela todas las ocurrencias activas de una serie recurrente de una vez.
create or replace function public.cancel_stylist_time_off_series(
  p_branch_id uuid,
  p_recurrence_group_id uuid
)
returns integer
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_access record;
  v_owner_stylist_id uuid;
  v_count integer;
begin
  select * into strict v_access
  from private.beautyos_resolve_branch_access(
    p_branch_id,
    array['tenant_owner', 'admin', 'stylist']::text[],
    true
  );

  select distinct stylist_id
    into v_owner_stylist_id
  from public.stylist_time_off
  where tenant_id = v_access.tenant_id
    and recurrence_group_id = p_recurrence_group_id
    and active = true
  limit 1;

  if v_owner_stylist_id is null then
    raise exception 'La serie de bloqueos no existe o ya fue cancelada.';
  end if;

  if v_access.role = 'stylist' and v_owner_stylist_id <> v_access.stylist_id then
    raise exception 'No puedes cancelar el bloqueo de otro estilista.';
  end if;

  update public.stylist_time_off
     set active = false, updated_at = now()
   where tenant_id = v_access.tenant_id
     and recurrence_group_id = p_recurrence_group_id
     and active = true;

  get diagnostics v_count = row_count;

  return v_count;
end;
$$;

-- get_my_stylist_time_off gana recurrence_group_id para que Flutter pueda
-- ofrecer "cancelar toda la serie" cuando aplica.
-- DROP requerido: create or replace no permite agregar columnas a RETURNS TABLE.
drop function if exists public.get_my_stylist_time_off(uuid);

create or replace function public.get_my_stylist_time_off(
  p_branch_id uuid
)
returns table (
  id uuid,
  starts_at timestamptz,
  ends_at timestamptz,
  reason text,
  created_at timestamptz,
  recurrence_group_id uuid
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_access record;
begin
  select * into strict v_access
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['stylist']::text[], true
  );

  return query
  select sto.id, sto.starts_at, sto.ends_at, sto.reason, sto.created_at,
         sto.recurrence_group_id
  from public.stylist_time_off sto
  where sto.tenant_id = v_access.tenant_id
    and sto.stylist_id = v_access.stylist_id
    and sto.active
    and sto.ends_at > now()
  order by sto.starts_at;
end;
$$;

revoke all on function public.create_stylist_time_off(uuid, timestamptz, timestamptz, text, uuid, text, date) from public, anon;
revoke all on function public.cancel_stylist_time_off_series(uuid, uuid) from public, anon;
revoke all on function public.get_my_stylist_time_off(uuid) from public, anon;

grant execute on function public.create_stylist_time_off(uuid, timestamptz, timestamptz, text, uuid, text, date) to authenticated, service_role;
grant execute on function public.cancel_stylist_time_off_series(uuid, uuid) to authenticated, service_role;
grant execute on function public.get_my_stylist_time_off(uuid) to authenticated, service_role;

comment on function public.create_stylist_time_off(uuid, timestamptz, timestamptz, text, uuid, text, date)
  is 'Crea un bloqueo de agenda; si se pasa frecuencia y fecha limite, genera una ocurrencia por dia/semana (tope 180 dias) ligadas por recurrence_group_id.';
comment on function public.cancel_stylist_time_off_series(uuid, uuid)
  is 'Cancela de una vez todas las ocurrencias activas de una serie recurrente.';

commit;
