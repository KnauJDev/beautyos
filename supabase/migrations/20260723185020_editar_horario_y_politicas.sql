-- BeautyOS - Editar horario, politica de citas y politica de comision.
--
-- Tercer bloque de la ruta acordada: Configuracion era de solo lectura.
-- business_hours y appointment_policies son por sede (branch_id
-- obligatorio en la lectura _v2, verificado contra el esquema real:
-- get_business_hours_v2/get_appointment_policy_v2 exigen
-- branch_id = branch_id exacto, no aceptan nulo). commission_policies
-- sigue siendo por tenant (sin columna branch_id, D2 no la incluyo entre
-- las 15 tablas obligadas a sede explicita).
--
-- Autorizacion: beautyos_resolve_branch_access, mismo patron ya usado.

begin;

create or replace function public.update_business_hours(
  p_branch_id uuid,
  p_hours jsonb
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_item jsonb;
  v_day integer;
  v_is_open boolean;
  v_opens time;
  v_closes time;
  v_seen_days integer[] := array[]::integer[];
begin
  select tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner', 'admin'], true
  );

  if p_hours is null or jsonb_typeof(p_hours) <> 'array' then
    raise exception 'El horario debe enviarse como una lista.';
  end if;

  for v_item in select * from jsonb_array_elements(p_hours)
  loop
    v_day := (v_item ->> 'day_of_week')::integer;
    v_is_open := coalesce((v_item ->> 'is_open')::boolean, false);
    v_opens := nullif(v_item ->> 'opens_at', '')::time;
    v_closes := nullif(v_item ->> 'closes_at', '')::time;

    if v_day is null or v_day < 1 or v_day > 7 then
      raise exception 'Dia de la semana invalido: %.', v_day;
    end if;

    if v_is_open and (v_opens is null or v_closes is null or v_opens >= v_closes) then
      raise exception 'El horario del dia % debe tener apertura antes que cierre.', v_day;
    end if;

    update public.business_hours
       set opens_at = case when v_is_open then v_opens else null end,
           closes_at = case when v_is_open then v_closes else null end,
           is_open = v_is_open,
           updated_at = now()
     where tenant_id = v_tenant_id
       and branch_id = p_branch_id
       and day_of_week = v_day;

    if not found then
      raise exception 'No existe horario base para el dia % en esta sede.', v_day;
    end if;

    v_seen_days := array_append(v_seen_days, v_day);
  end loop;

  if array_length(v_seen_days, 1) is distinct from 7
     or (select count(distinct d) from unnest(v_seen_days) d) <> 7 then
    raise exception 'Se deben enviar los 7 dias de la semana, sin repetir.';
  end if;
end;
$$;

create or replace function public.update_appointment_policy(
  p_branch_id uuid,
  p_requires_deposit boolean,
  p_deposit_percentage numeric,
  p_cancellation_hours integer,
  p_reschedule_hours integer,
  p_manual_confirmation_required boolean,
  p_customer_reschedule_allowed boolean
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner', 'admin'], true
  );

  if p_deposit_percentage is null or p_deposit_percentage < 0 or p_deposit_percentage > 100 then
    raise exception 'El porcentaje de anticipo debe estar entre 0 y 100.';
  end if;

  if p_cancellation_hours is null or p_cancellation_hours < 0 then
    raise exception 'Las horas de cancelacion no pueden ser negativas.';
  end if;

  if p_reschedule_hours is null or p_reschedule_hours < 0 then
    raise exception 'Las horas de reagendamiento no pueden ser negativas.';
  end if;

  update public.appointment_policies
     set requires_deposit = p_requires_deposit,
         deposit_percentage = p_deposit_percentage,
         cancellation_hours = p_cancellation_hours,
         reschedule_hours = p_reschedule_hours,
         manual_confirmation_required = p_manual_confirmation_required,
         customer_reschedule_allowed = p_customer_reschedule_allowed,
         updated_at = now()
   where tenant_id = v_tenant_id
     and branch_id = p_branch_id
     and active = true;

  if not found then
    raise exception 'No existe una politica de citas activa para esta sede.';
  end if;
end;
$$;

create or replace function public.update_commission_policy(
  p_branch_id uuid,
  p_commission_type text,
  p_commission_percentage numeric,
  p_fixed_commission_amount numeric,
  p_applies_after_discount boolean,
  p_notes text default null
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner', 'admin'], true
  );

  if p_commission_type not in ('percentage', 'fixed') then
    raise exception 'Tipo de comision no valido.';
  end if;

  if p_commission_percentage is null or p_commission_percentage < 0 or p_commission_percentage > 100 then
    raise exception 'El porcentaje de comision debe estar entre 0 y 100.';
  end if;

  if p_fixed_commission_amount is null or p_fixed_commission_amount < 0 then
    raise exception 'El valor fijo de comision no puede ser negativo.';
  end if;

  update public.commission_policies
     set commission_type = p_commission_type,
         commission_percentage = p_commission_percentage,
         fixed_commission_amount = p_fixed_commission_amount,
         applies_after_discount = p_applies_after_discount,
         notes = nullif(trim(coalesce(p_notes, '')), ''),
         updated_at = now()
   where tenant_id = v_tenant_id
     and active = true;

  if not found then
    raise exception 'No existe una politica de comision activa para este negocio.';
  end if;
end;
$$;

revoke all on function public.update_business_hours(uuid, jsonb) from public, anon;
revoke all on function public.update_appointment_policy(uuid, boolean, numeric, integer, integer, boolean, boolean) from public, anon;
revoke all on function public.update_commission_policy(uuid, text, numeric, numeric, boolean, text) from public, anon;

grant execute on function public.update_business_hours(uuid, jsonb) to authenticated, service_role;
grant execute on function public.update_appointment_policy(uuid, boolean, numeric, integer, integer, boolean, boolean) to authenticated, service_role;
grant execute on function public.update_commission_policy(uuid, text, numeric, numeric, boolean, text) to authenticated, service_role;

commit;
