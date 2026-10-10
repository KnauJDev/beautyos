-- ==============================================================================
-- Cerrar una sede sin borrar nada. (Paso 9.65, D-328, hallazgo CQ)
-- ==============================================================================
--
-- QUÉ PASA
--
-- El 09-oct el propietario quiso cerrar una sede en mora de Prueba Barbería
-- Elite y, como el Panel no tenía cómo, usó "Borrar negocio de prueba": se
-- borró el negocio entero. Decidió (D-328, con prototipo aprobado
-- https://claude.ai/artifact/FKNnRij9kGtaNWPknX6HZB):
--   * una sede que se cierra NO se borra: deja de verse, de recibir citas y
--     de cobrarse, conserva su historial y sus pagos, y se puede volver a
--     abrir. Las clientas son del negocio: siguen en las otras sedes;
--   * la cierran él desde el Panel y el dueño del salón desde Configuración;
--   * con citas próximas NO se deja cerrar;
--   * la sede principal no se cierra;
--   * lo hecho en la sede cerrada SIGUE saliendo en los reportes y el
--     Dashboard;
--   * al reabrirla él, queda activa; al reabrirla el dueño, queda pendiente
--     de pago, como una sede nueva.
--
-- LO QUE MOSTRARON LAS TRES LECTURAS VIVAS (intervenciones/extraer_*_9_65.sql)
--
--   * Cerrar de verdad es `branches.active = false`: el equipo no entra
--     (`beautyos_resolve_branch_access`), la app no la lista
--     (`get_my_branch_context_v2`), la reserva en línea y la página no la
--     usan. El estado `cancelled` de su suscripción, solo, no frena nada; sí
--     la saca del cobro, de los avisos y del paso automático a mora.
--   * El Dashboard toma sus sedes de `private.beautyos_dashboard_branches`,
--     que pedía `b.active`: una sede cerrada desaparecía de ahí.
--   * El reporte de todo el negocio recorre `get_my_branch_context_v2` (solo
--     abiertas) y pide cada sede a `get_branch_reports_v3`, que exigía la
--     sede abierta (`p_require_operational = true`).
--
-- QUÉ HACE ESTA MIGRACIÓN
--
--   1. Dos ayudantes privados, `beautyos_cerrar_sede` y
--      `beautyos_reabrir_sede`, con todas las reglas y el rastro en
--      `subscription_events` (`sede_cerrada`, `sede_reabierta`), como
--      `platform_set_branch_subscription` (D-303).
--   2. Cinco funciones: `close_branch` y `reopen_branch` (el dueño del
--      salón), `platform_close_branch` y `platform_reopen_branch` (el Panel),
--      y `get_branch_upcoming_appointments` (las citas que impiden cerrar; la
--      plataforma no ve los nombres de las clientas).
--   3. **Generadas por un script desde su texto vivo**, con cambios contados:
--      `beautyos_dashboard_branches` (deja de pedir `b.active`),
--      `get_branch_reports_v3` (deja consultar una sede cerrada, pero sigue
--      exigiendo el negocio activo) y `get_tenant_reports_v3` (suma también
--      las sedes cerradas y las marca `cerrada` en el desglose). Devuelven lo
--      mismo que antes, así que no hace falta DROP y conservan sus permisos.
--
-- Lo prueba el CONTROL 250.
-- ==============================================================================

set client_encoding = 'UTF8';

begin;

-- ---------------------------------------------------------------------------
-- 1. Las reglas, en un solo sitio
-- ---------------------------------------------------------------------------
create or replace function private.beautyos_cerrar_sede(
  p_branch_id uuid,
  p_quien text
)
returns void
language plpgsql
security definer
set search_path to 'pg_catalog'
as $$
declare
  v_tenant_id uuid;
  v_nombre text;
  v_principal boolean;
  v_activa boolean;
  v_zona text;
  v_citas integer;
  v_antes text;
  v_ts uuid;
begin
  select b.tenant_id, b.name, b.is_primary, b.active, b.timezone
    into v_tenant_id, v_nombre, v_principal, v_activa, v_zona
  from public.branches b
  where b.id = p_branch_id
  for update;

  if not found then
    raise exception 'La sede no existe.';
  end if;

  if v_principal then
    raise exception 'La sede principal no se cierra. Para parar todo el negocio, se suspende el negocio.';
  end if;

  if not v_activa then
    raise exception 'Esa sede ya está cerrada.';
  end if;

  -- Desde el comienzo de HOY en la hora de la sede: una cita de esta mañana
  -- que sigue abierta también cuenta.
  select count(*) into v_citas
  from public.tickets t
  where t.tenant_id = v_tenant_id
    and t.branch_id = p_branch_id
    and t.scheduled_at >= (((now() at time zone v_zona)::date)::timestamp at time zone v_zona)
    and t.status in ('solicitado', 'cotizado', 'apartado', 'confirmado', 'en_espera', 'en_proceso');

  if v_citas > 0 then
    raise exception 'La sede tiene % citas próximas. Muévelas a otra sede o cancélalas primero.', v_citas;
  end if;

  select bs.status into v_antes
  from public.branch_subscriptions bs
  where bs.branch_id = p_branch_id
  for update;

  update public.branches
     set active = false
   where id = p_branch_id;

  update public.branch_subscriptions
     set status = 'cancelled',
         updated_at = now()
   where branch_id = p_branch_id;

  select ts.id into v_ts
  from public.tenant_subscriptions ts
  where ts.tenant_id = v_tenant_id;

  if v_ts is null then
    raise exception 'El negocio de esta sede no tiene suscripcion registrada.';
  end if;

  insert into public.subscription_events (
    tenant_id, tenant_subscription_id, event_type, provider, payload, created_by
  ) values (
    v_tenant_id, v_ts, 'sede_cerrada', p_quien,
    jsonb_build_object('branch_id', p_branch_id, 'sede', v_nombre, 'estado_anterior', v_antes),
    auth.uid()
  );
end;
$$;

create or replace function private.beautyos_reabrir_sede(
  p_branch_id uuid,
  p_estado text,
  p_quien text
)
returns void
language plpgsql
security definer
set search_path to 'pg_catalog'
as $$
declare
  v_tenant_id uuid;
  v_nombre text;
  v_activa boolean;
  v_ts uuid;
begin
  if p_estado not in ('pending', 'active') then
    raise exception 'Estado invalido para reabrir: %.', coalesce(p_estado, 'null');
  end if;

  select b.tenant_id, b.name, b.active
    into v_tenant_id, v_nombre, v_activa
  from public.branches b
  where b.id = p_branch_id
  for update;

  if not found then
    raise exception 'La sede no existe.';
  end if;

  if v_activa then
    raise exception 'Esa sede no está cerrada.';
  end if;

  update public.branches
     set active = true
   where id = p_branch_id;

  update public.branch_subscriptions
     set status = p_estado,
         activated_at = case
           when p_estado = 'active' then coalesce(activated_at, now())
           else activated_at
         end,
         updated_at = now()
   where branch_id = p_branch_id;

  if not found then
    raise exception 'La sede no tiene suscripcion registrada.';
  end if;

  select ts.id into v_ts
  from public.tenant_subscriptions ts
  where ts.tenant_id = v_tenant_id;

  if v_ts is null then
    raise exception 'El negocio de esta sede no tiene suscripcion registrada.';
  end if;

  insert into public.subscription_events (
    tenant_id, tenant_subscription_id, event_type, provider, payload, created_by
  ) values (
    v_tenant_id, v_ts, 'sede_reabierta', p_quien,
    jsonb_build_object('branch_id', p_branch_id, 'sede', v_nombre, 'estado_nuevo', p_estado),
    auth.uid()
  );
end;
$$;

revoke all on function private.beautyos_cerrar_sede(uuid, text) from public, anon, authenticated;
revoke all on function private.beautyos_reabrir_sede(uuid, text, text) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Quién puede
-- ---------------------------------------------------------------------------
-- El dueño del salón. Cerrar: la sede está abierta, así que se entra por la
-- puerta de siempre. Reabrir: la sede está cerrada, así que no se exige que
-- esté operando, pero sí que el negocio siga activo.
create or replace function public.close_branch(p_branch_id uuid)
returns void
language plpgsql
security definer
set search_path to 'pg_catalog'
as $$
begin
  perform 1
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner'], true
  );
  perform private.beautyos_cerrar_sede(p_branch_id, 'tenant_owner');
end;
$$;

create or replace function public.reopen_branch(p_branch_id uuid)
returns void
language plpgsql
security definer
set search_path to 'pg_catalog'
as $$
declare
  v_tenant_id uuid;
begin
  select r.tenant_id into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner'], false
  ) r;

  if not exists (
    select 1 from public.tenants t where t.id = v_tenant_id and t.active
  ) then
    raise exception 'El contexto de sede no esta disponible.';
  end if;

  -- Como una sede nueva: pendiente de pago (decisión del propietario).
  perform private.beautyos_reabrir_sede(p_branch_id, 'pending', 'tenant_owner');
end;
$$;

-- La plataforma, desde el Panel.
create or replace function public.platform_close_branch(p_branch_id uuid)
returns void
language plpgsql
security definer
set search_path to 'pg_catalog'
as $$
begin
  if private.beautyos_current_platform_role() is null then
    raise exception 'No autorizado: se requiere rol de plataforma.';
  end if;
  perform private.beautyos_cerrar_sede(p_branch_id, 'platform_admin');
end;
$$;

create or replace function public.platform_reopen_branch(p_branch_id uuid)
returns void
language plpgsql
security definer
set search_path to 'pg_catalog'
as $$
begin
  if private.beautyos_current_platform_role() is null then
    raise exception 'No autorizado: se requiere rol de plataforma.';
  end if;
  perform private.beautyos_reabrir_sede(p_branch_id, 'active', 'platform_admin');
end;
$$;

-- Las citas que impiden cerrar. El dueño y el administrador de la sede las
-- ven con el nombre de la clienta; la plataforma, sin él.
create or replace function public.get_branch_upcoming_appointments(p_branch_id uuid)
returns table(scheduled_at timestamptz, client_name text, service_names text)
language plpgsql
stable
security definer
set search_path to 'pg_catalog'
as $$
#variable_conflict use_column
declare
  v_tenant_id uuid;
  v_zona text;
  v_con_nombre boolean;
begin
  if private.beautyos_current_platform_role() is not null then
    v_con_nombre := false;
  else
    perform 1
    from private.beautyos_resolve_branch_access(
      p_branch_id, array['tenant_owner', 'admin'], true
    );
    v_con_nombre := true;
  end if;

  select b.tenant_id, b.timezone into v_tenant_id, v_zona
  from public.branches b
  where b.id = p_branch_id;

  if not found then
    raise exception 'La sede no existe.';
  end if;

  return query
  select
    t.scheduled_at,
    case when v_con_nombre then c.name else null end,
    coalesce((
      select string_agg(s.name, ' + ' order by ts.created_at)
      from public.ticket_services ts
      join public.services s on s.id = ts.service_id
      where ts.ticket_id = t.id
        and ts.tenant_id = t.tenant_id
        and ts.status <> 'cancelado'
    ), '')
  from public.tickets t
  join public.clients c
    on c.id = t.client_id
   and c.tenant_id = t.tenant_id
  where t.tenant_id = v_tenant_id
    and t.branch_id = p_branch_id
    and t.scheduled_at >= (((now() at time zone v_zona)::date)::timestamp at time zone v_zona)
    and t.status in ('solicitado', 'cotizado', 'apartado', 'confirmado', 'en_espera', 'en_proceso')
  order by t.scheduled_at
  limit 20;
end;
$$;

revoke all on function public.close_branch(uuid) from public, anon;
revoke all on function public.reopen_branch(uuid) from public, anon;
revoke all on function public.platform_close_branch(uuid) from public, anon;
revoke all on function public.platform_reopen_branch(uuid) from public, anon;
revoke all on function public.get_branch_upcoming_appointments(uuid) from public, anon;

grant execute on function public.close_branch(uuid) to authenticated;
grant execute on function public.reopen_branch(uuid) to authenticated;
grant execute on function public.platform_close_branch(uuid) to authenticated;
grant execute on function public.platform_reopen_branch(uuid) to authenticated;
grant execute on function public.get_branch_upcoming_appointments(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Lo hecho en una sede cerrada sigue en los reportes (texto vivo + cambios)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.beautyos_dashboard_branches(p_branch_ids uuid[])
 RETURNS TABLE(branch_id uuid, tenant_id uuid, timezone text, is_primary boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
  select b.id, b.tenant_id, b.timezone, b.is_primary
  from public.tenant_memberships tm
  join public.branches b
    on b.tenant_id = tm.tenant_id
  -- D-328: sin "and b.active". Lo hecho en una sede cerrada sigue en el
  -- Dashboard cuando se mira el pasado.
  where tm.user_id = auth.uid()
    and tm.active
    and tm.starts_at <= now()
    and (tm.ends_at is null or tm.ends_at > now())
    and tm.role in ('tenant_owner', 'admin')
    and (
      tm.role = 'tenant_owner'
      or exists (
        select 1
        from public.branch_memberships bm
        where bm.tenant_id = tm.tenant_id
          and bm.branch_id = b.id
          and bm.tenant_membership_id = tm.id
          and bm.active
          and bm.starts_at <= now()
          and (bm.ends_at is null or bm.ends_at > now())
      )
    )
    and (
      p_branch_ids is null
      or cardinality(p_branch_ids) = 0
      or b.id = any(p_branch_ids)
    );
$function$;

CREATE OR REPLACE FUNCTION public.get_branch_reports_v3(p_branch_id uuid, p_start_date date, p_end_date date)
 RETURNS TABLE(start_date date, end_date date, total_received numeric, payments_count integer, paid_tickets_count integer, cash_received numeric, card_received numeric, transfer_received numeric, other_received numeric, total_purchases numeric, cash_purchases numeric, total_expenses numeric, cash_expenses numeric, total_commissions numeric, commission_services_count integer, expected_cash numeric, net_result numeric, prev_total_received numeric, prev_net_result numeric, prev_payments_count integer, commissions_by_stylist jsonb, sales_by_service jsonb)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_tenant_id uuid;
  v_timezone text;
  v_start_at timestamptz;
  v_end_at timestamptz;
  v_days integer;
  v_prev_start_date date;
  v_prev_end_date date;
  v_prev_start_at timestamptz;
  v_prev_end_at timestamptz;
begin
  select c.tenant_id, c.timezone
    into v_tenant_id, v_timezone
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner','admin'], false
  ) c;

  -- D-328: una sede cerrada se puede consultar (su historial sigue
  -- contando), pero el negocio tiene que seguir activo, como antes.
  if not exists (
    select 1 from public.tenants t where t.id = v_tenant_id and t.active
  ) then
    raise exception 'El contexto de sede no esta disponible.';
  end if;

  if p_start_date is null or p_end_date is null then
    raise exception 'Las fechas de inicio y fin son obligatorias.';
  end if;

  if p_end_date < p_start_date then
    raise exception 'La fecha de fin no puede ser anterior a la fecha de inicio.';
  end if;

  v_timezone := coalesce(v_timezone, 'America/Bogota');
  v_start_at := p_start_date::timestamp at time zone v_timezone;
  v_end_at := (p_end_date + 1)::timestamp at time zone v_timezone;

  -- Periodo previo de igual duracion para calculo de tendencias/comparacion
  v_days := (p_end_date - p_start_date) + 1;
  v_prev_start_date := p_start_date - v_days;
  v_prev_end_date := p_start_date - 1;
  v_prev_start_at := v_prev_start_date::timestamp at time zone v_timezone;
  v_prev_end_at := (v_prev_end_date + 1)::timestamp at time zone v_timezone;

  return query
  with current_payments as (
    select
      count(*)::integer as payments_count,
      count(distinct tp.ticket_id)::integer as paid_tickets_count,
      coalesce(sum(tp.amount), 0)::numeric as total_received,
      coalesce(sum(tp.amount) filter (where tp.method = 'efectivo'), 0)::numeric as cash_received,
      coalesce(sum(tp.amount) filter (where tp.method = 'tarjeta'), 0)::numeric as card_received,
      coalesce(sum(tp.amount) filter (where tp.method = 'transferencia'), 0)::numeric as transfer_received,
      coalesce(sum(tp.amount) filter (where tp.method = 'otro'), 0)::numeric as other_received
    from public.ticket_payments tp
    where tp.tenant_id = v_tenant_id
      and tp.branch_id = p_branch_id
      and tp.status = 'registrado'
      and tp.received_at >= v_start_at
      and tp.received_at < v_end_at
  ),
  current_purchases as (
    select
      coalesce(sum(p.total_amount), 0)::numeric as total_purchases,
      coalesce(sum(p.total_amount) filter (where p.payment_method = 'cash'), 0)::numeric as cash_purchases
    from public.purchases p
    where p.tenant_id = v_tenant_id
      and p.branch_id = p_branch_id
      and p.active
      and p.purchase_date >= p_start_date
      and p.purchase_date <= p_end_date
  ),
  current_expenses as (
    select
      coalesce(sum(e.amount), 0)::numeric as total_expenses,
      coalesce(sum(e.amount) filter (where e.payment_method = 'cash'), 0)::numeric as cash_expenses
    from public.expenses e
    where e.tenant_id = v_tenant_id
      and e.branch_id = p_branch_id
      and e.active
      and e.expense_date >= p_start_date
      and e.expense_date <= p_end_date
  ),
  current_commissions as (
    select
      count(*)::integer as services_count,
      coalesce(sum(sc.commission_amount), 0)::numeric as total_commissions
    from public.stylist_commissions sc
    where sc.tenant_id = v_tenant_id
      and sc.branch_id = p_branch_id
      and sc.status = 'generada'
      and sc.generated_at >= v_start_at
      and sc.generated_at < v_end_at
  ),
  prev_payments as (
    select
      count(*)::integer as prev_payments_count,
      coalesce(sum(tp.amount), 0)::numeric as prev_total_received
    from public.ticket_payments tp
    where tp.tenant_id = v_tenant_id
      and tp.branch_id = p_branch_id
      and tp.status = 'registrado'
      and tp.received_at >= v_prev_start_at
      and tp.received_at < v_prev_end_at
  ),
  prev_purchases as (
    select
      coalesce(sum(p.total_amount), 0)::numeric as prev_purchases
    from public.purchases p
    where p.tenant_id = v_tenant_id
      and p.branch_id = p_branch_id
      and p.active
      and p.purchase_date >= v_prev_start_date
      and p.purchase_date <= v_prev_end_date
  ),
  prev_expenses as (
    select
      coalesce(sum(e.amount), 0)::numeric as prev_expenses
    from public.expenses e
    where e.tenant_id = v_tenant_id
      and e.branch_id = p_branch_id
      and e.active
      and e.expense_date >= v_prev_start_date
      and e.expense_date <= v_prev_end_date
  ),
  prev_commissions as (
    select
      coalesce(sum(sc.commission_amount), 0)::numeric as prev_commissions
    from public.stylist_commissions sc
    where sc.tenant_id = v_tenant_id
      and sc.branch_id = p_branch_id
      and sc.status = 'generada'
      and sc.generated_at >= v_prev_start_at
      and sc.generated_at < v_prev_end_at
  )
  select
    p_start_date,
    p_end_date,
    cp.total_received,
    cp.payments_count,
    cp.paid_tickets_count,
    cp.cash_received,
    cp.card_received,
    cp.transfer_received,
    cp.other_received,
    pur.total_purchases,
    pur.cash_purchases,
    exp.total_expenses,
    exp.cash_expenses,
    com.total_commissions,
    com.services_count as commission_services_count,
    (cp.cash_received - pur.cash_purchases - exp.cash_expenses)::numeric as expected_cash,
    (cp.total_received - pur.total_purchases - exp.total_expenses - com.total_commissions)::numeric as net_result,
    pp.prev_total_received,
    (pp.prev_total_received - ppu.prev_purchases - pex.prev_expenses - pcom.prev_commissions)::numeric as prev_net_result,
    pp.prev_payments_count,
    (
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'stylist_id', sub.id,
            'stylist_name', sub.name,
            'services_count', sub.cnt,
            'service_sales', sub.sales,
            'commission_total', sub.comm
          )
        ),
        '[]'::jsonb
      )
      from (
        select
          st.id,
          st.name,
          count(*)::integer as cnt,
          coalesce(sum(sc.service_amount), 0)::numeric as sales,
          coalesce(sum(sc.commission_amount), 0)::numeric as comm
        from public.stylist_commissions sc
        join public.stylists st
          on st.id = sc.stylist_id
         and st.tenant_id = v_tenant_id
        where sc.tenant_id = v_tenant_id
          and sc.branch_id = p_branch_id
          and sc.status = 'generada'
          and sc.generated_at >= v_start_at
          and sc.generated_at < v_end_at
        group by st.id, st.name
        order by comm desc, st.name asc
      ) sub
    ) as commissions_by_stylist,
    (
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'service_name', sub.service_name,
            'stylist_name', sub.stylist_name,
            'tickets_count', sub.tickets_count,
            'total_sales', sub.total_sales,
            'total_duration_minutes', sub.total_duration_minutes
          )
        ),
        '[]'::jsonb
      )
      from (
        select
          coalesce(s.name, 'Sin servicio') as service_name,
          coalesce(st.name, 'Sin estilista') as stylist_name,
          count(distinct t.id)::integer as tickets_count,
          coalesce(sum(ts.price), 0)::numeric as total_sales,
          coalesce(sum(ts.duration_minutes), 0)::integer as total_duration_minutes
        from public.tickets t
        join public.ticket_services ts
          on ts.ticket_id = t.id
         and ts.tenant_id = v_tenant_id
         and ts.branch_id = p_branch_id
         and ts.status = 'finalizado'
        join public.services s
          on s.id = ts.service_id
         and s.tenant_id = v_tenant_id
        left join public.stylists st
          on st.id = ts.stylist_id
         and st.tenant_id = v_tenant_id
        where t.tenant_id = v_tenant_id
          and t.branch_id = p_branch_id
          and t.status in ('finalizado', 'cerrado')
          and coalesce(t.closed_at, t.scheduled_at) >= v_start_at
          and coalesce(t.closed_at, t.scheduled_at) < v_end_at
        group by s.name, st.name
        order by total_sales desc, service_name asc
      ) sub
    ) as sales_by_service
  from current_payments cp
  cross join current_purchases pur
  cross join current_expenses exp
  cross join current_commissions com
  cross join prev_payments pp
  cross join prev_purchases ppu
  cross join prev_expenses pex
  cross join prev_commissions pcom;
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_tenant_reports_v3(p_start_date date, p_end_date date)
 RETURNS TABLE(start_date date, end_date date, total_received numeric, payments_count integer, paid_tickets_count integer, cash_received numeric, card_received numeric, transfer_received numeric, other_received numeric, total_purchases numeric, cash_purchases numeric, total_expenses numeric, cash_expenses numeric, total_commissions numeric, commission_services_count integer, expected_cash numeric, net_result numeric, prev_total_received numeric, prev_net_result numeric, prev_payments_count integer, commissions_by_stylist jsonb, sales_by_service jsonb, branches_count integer, by_branch jsonb)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_sede record;
  v_r record;
  v_comisiones jsonb := '[]'::jsonb;
  v_servicios jsonb := '[]'::jsonb;
  v_por_sede jsonb := '[]'::jsonb;
  v_sedes integer := 0;
begin
  if p_start_date is null or p_end_date is null then
    raise exception 'Las fechas de inicio y fin son obligatorias.';
  end if;

  if p_end_date < p_start_date then
    raise exception 'La fecha de fin no puede ser anterior a la fecha de inicio.';
  end if;

  start_date := p_start_date;
  end_date := p_end_date;

  total_received := 0;
  payments_count := 0;
  paid_tickets_count := 0;
  cash_received := 0;
  card_received := 0;
  transfer_received := 0;
  other_received := 0;
  total_purchases := 0;
  cash_purchases := 0;
  total_expenses := 0;
  cash_expenses := 0;
  total_commissions := 0;
  commission_services_count := 0;
  expected_cash := 0;
  net_result := 0;
  prev_total_received := 0;
  prev_net_result := 0;
  prev_payments_count := 0;

  for v_sede in
    select x.branch_id, x.branch_name, x.role, x.is_primary, x.cerrada
    from (
      select c.branch_id, c.branch_name, c.role, c.is_primary, false as cerrada
      from public.get_my_branch_context_v2() c
      union all
      -- D-328: las sedes cerradas siguen contando cuando se mira el
      -- pasado. Las mismas reglas de quién ve qué sede que el
      -- contexto, sin exigir que la sede esté abierta.
      select b.id, b.name, tm.role, b.is_primary, true
      from public.tenant_memberships tm
      join public.tenants t
        on t.id = tm.tenant_id
       and t.active
      join public.branches b
        on b.tenant_id = tm.tenant_id
       and not b.active
      where tm.user_id = auth.uid()
        and tm.active
        and tm.starts_at <= now()
        and (tm.ends_at is null or tm.ends_at > now())
        and tm.role in ('tenant_owner', 'admin')
        and (
          tm.role = 'tenant_owner'
          or exists (
            select 1
            from public.branch_memberships bm
            where bm.tenant_id = tm.tenant_id
              and bm.branch_id = b.id
              and bm.tenant_membership_id = tm.id
              and bm.active
              and bm.starts_at <= now()
              and (bm.ends_at is null or bm.ends_at > now())
          )
        )
    ) x
    order by x.cerrada, x.is_primary desc, x.branch_name
  loop
    -- Solo las sedes donde manda. Un estilista o un asistente no consolida
    -- nada: la funcion de una sola sede ya los rechaza, y aqui se saltan antes
    -- de que reviente.
    if v_sede.role not in ('tenant_owner', 'admin') then
      continue;
    end if;

    select * into v_r
    from public.get_branch_reports_v3(v_sede.branch_id, p_start_date, p_end_date);

    if v_r is null then
      continue;
    end if;

    v_sedes := v_sedes + 1;

    total_received := total_received + coalesce(v_r.total_received, 0);
    payments_count := payments_count + coalesce(v_r.payments_count, 0);
    paid_tickets_count := paid_tickets_count + coalesce(v_r.paid_tickets_count, 0);
    cash_received := cash_received + coalesce(v_r.cash_received, 0);
    card_received := card_received + coalesce(v_r.card_received, 0);
    transfer_received := transfer_received + coalesce(v_r.transfer_received, 0);
    other_received := other_received + coalesce(v_r.other_received, 0);
    total_purchases := total_purchases + coalesce(v_r.total_purchases, 0);
    cash_purchases := cash_purchases + coalesce(v_r.cash_purchases, 0);
    total_expenses := total_expenses + coalesce(v_r.total_expenses, 0);
    cash_expenses := cash_expenses + coalesce(v_r.cash_expenses, 0);
    total_commissions := total_commissions + coalesce(v_r.total_commissions, 0);
    commission_services_count :=
      commission_services_count + coalesce(v_r.commission_services_count, 0);
    expected_cash := expected_cash + coalesce(v_r.expected_cash, 0);
    net_result := net_result + coalesce(v_r.net_result, 0);
    prev_total_received := prev_total_received + coalesce(v_r.prev_total_received, 0);
    prev_net_result := prev_net_result + coalesce(v_r.prev_net_result, 0);
    prev_payments_count := prev_payments_count + coalesce(v_r.prev_payments_count, 0);

    v_comisiones := v_comisiones || coalesce(v_r.commissions_by_stylist, '[]'::jsonb);
    v_servicios := v_servicios || coalesce(v_r.sales_by_service, '[]'::jsonb);

    -- El desglose por sede sale gratis: ya se calculo cada una por separado.
    v_por_sede := v_por_sede || jsonb_build_array(
      jsonb_build_object(
        'branch_id', v_sede.branch_id,
        'branch_name', v_sede.branch_name,
        'is_primary', v_sede.is_primary,
        'cerrada', v_sede.cerrada,
        'total_received', coalesce(v_r.total_received, 0),
        'net_result', coalesce(v_r.net_result, 0),
        'total_expenses', coalesce(v_r.total_expenses, 0),
        'total_purchases', coalesce(v_r.total_purchases, 0),
        'total_commissions', coalesce(v_r.total_commissions, 0),
        'expected_cash', coalesce(v_r.expected_cash, 0),
        'payments_count', coalesce(v_r.payments_count, 0)
      )
    );
  end loop;

  if v_sedes = 0 then
    raise exception 'No autorizado. Solo owner o admin consulta reportes, y de las sedes que tiene asignadas.';
  end if;

  branches_count := v_sedes;
  by_branch := v_por_sede;

  -- Una misma estilista puede trabajar en dos sedes: se agrupa por nombre para
  -- que el consolidado diga cuanto se llevo EN TOTAL, no dos veces la mitad.
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'stylist_name', x.nombre,
        'services_count', x.cnt,
        'service_sales', x.ventas,
        'commission_total', x.comision
      )
      order by x.comision desc, x.nombre
    ),
    '[]'::jsonb
  )
  into commissions_by_stylist
  from (
    select
      e ->> 'stylist_name' as nombre,
      sum(coalesce((e ->> 'services_count')::integer, 0)) as cnt,
      sum(coalesce((e ->> 'service_sales')::numeric, 0)) as ventas,
      sum(coalesce((e ->> 'commission_total')::numeric, 0)) as comision
    from jsonb_array_elements(v_comisiones) e
    group by e ->> 'stylist_name'
  ) x;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'service_name', y.servicio,
        'stylist_name', y.estilista,
        'tickets_count', y.cnt,
        'total_sales', y.ventas,
        'total_duration_minutes', y.minutos
      )
      order by y.ventas desc, y.servicio
    ),
    '[]'::jsonb
  )
  into sales_by_service
  from (
    select
      e ->> 'service_name' as servicio,
      e ->> 'stylist_name' as estilista,
      sum(coalesce((e ->> 'tickets_count')::integer, 0)) as cnt,
      sum(coalesce((e ->> 'total_sales')::numeric, 0)) as ventas,
      sum(coalesce((e ->> 'total_duration_minutes')::integer, 0)) as minutos
    from jsonb_array_elements(v_servicios) e
    group by e ->> 'service_name', e ->> 'stylist_name'
  ) y;

  return next;
end;
$function$;

commit;
