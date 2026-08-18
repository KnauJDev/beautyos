-- Migración 20260818140000: Métricas de retorno, valor y cadencia de clientes (Paso 4.6 / D-153)
--
-- Agrega a get_clients_management_summary():
-- 1. total_visits: total de citas completadas (finalizado o cerrado)
-- 2. total_spent: gasto total acumulado en servicios completados
-- 3. average_ticket: ticket promedio por visita
-- 4. last_visit_at y first_visit_at: fechas de primera y última atención
-- 5. days_since_last_visit: días transcurridos desde su última cita
-- 6. avg_days_between_visits: cadencia promedio entre visitas (cada cuántos días visita)
-- 7. segment: vip, recurrente, nuevo, en_riesgo, sin_visitas
-- 8. balance_amount: saldo pendiente por cobrar

drop function if exists public.get_clients_management_summary();

create or replace function public.get_clients_management_summary()
returns table (
  id uuid,
  name text,
  phone text,
  email text,
  notes text,
  active boolean,
  created_at timestamptz,
  balance_amount numeric,
  total_visits integer,
  total_spent numeric,
  average_ticket numeric,
  last_visit_at timestamptz,
  first_visit_at timestamptz,
  days_since_last_visit integer,
  avg_days_between_visits integer,
  segment text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
begin
  v_tenant_id := public.get_my_tenant_id();

  if v_tenant_id is null then
    raise exception 'No existe un perfil activo asociado al usuario actual.';
  end if;

  if not (
    public.is_owner_or_admin()
    or exists (
      select 1
      from public.user_profiles up
      where up.user_id = auth.uid()
        and up.active = true
        and up.role = 'assistant'
    )
  ) then
    raise exception 'No autorizado. Solo owner, admin o asistente puede administrar clientes.';
  end if;

  return query
  with ticket_totals as (
    -- Totales por ticket finalizado o cerrado
    select
      t.id as ticket_id,
      t.client_id,
      t.status as ticket_status,
      t.scheduled_at,
      t.closed_at,
      coalesce(sum(ts.price) filter (where ts.status = 'finalizado'), 0)::numeric as total_amount
    from public.tickets t
    join public.ticket_services ts
      on ts.ticket_id = t.id
     and ts.tenant_id = v_tenant_id
    where t.tenant_id = v_tenant_id
      and t.status in ('finalizado', 'cerrado')
    group by t.id, t.client_id, t.status, t.scheduled_at, t.closed_at
  ),
  ticket_paid as (
    select
      tp.ticket_id,
      coalesce(sum(tp.amount), 0)::numeric as paid_amount
    from public.ticket_payments tp
    where tp.tenant_id = v_tenant_id
      and tp.status = 'registrado'
    group by tp.ticket_id
  ),
  client_ticket_stats as (
    select
      tt.client_id,
      count(tt.ticket_id)::integer as total_visits,
      coalesce(sum(tt.total_amount), 0)::numeric as total_spent,
      min(coalesce(tt.scheduled_at, tt.closed_at)) as first_visit_at,
      max(coalesce(tt.scheduled_at, tt.closed_at)) as last_visit_at,
      -- Saldo pendiente solo de tickets donde el precio > pagado
      coalesce(sum(greatest(tt.total_amount - coalesce(tpaid.paid_amount, 0), 0)), 0)::numeric as balance_amount
    from ticket_totals tt
    left join ticket_paid tpaid on tpaid.ticket_id = tt.ticket_id
    group by tt.client_id
  ),
  client_metrics as (
    select
      c.id,
      c.name,
      c.phone,
      c.email,
      c.notes,
      c.active,
      c.created_at,
      coalesce(cts.balance_amount, 0)::numeric as balance_amount,
      coalesce(cts.total_visits, 0)::integer as total_visits,
      coalesce(cts.total_spent, 0)::numeric as total_spent,
      case 
        when coalesce(cts.total_visits, 0) > 0 then round(cts.total_spent / cts.total_visits, 0)
        else 0
      end::numeric as average_ticket,
      cts.last_visit_at,
      cts.first_visit_at,
      case 
        when cts.last_visit_at is not null then 
          greatest(0, floor(extract(epoch from (now() - cts.last_visit_at)) / 86400.0)::integer)
        else null
      end as days_since_last_visit,
      case 
        when coalesce(cts.total_visits, 0) > 1 and cts.last_visit_at > cts.first_visit_at then 
          greatest(1, round((extract(epoch from (cts.last_visit_at - cts.first_visit_at)) / 86400.0) / (cts.total_visits - 1))::integer)
        else null
      end as avg_days_between_visits
    from public.clients c
    left join client_ticket_stats cts on cts.client_id = c.id
    where c.tenant_id = v_tenant_id
  )
  select
    cm.id,
    cm.name,
    cm.phone,
    cm.email,
    cm.notes,
    cm.active,
    cm.created_at,
    cm.balance_amount,
    cm.total_visits,
    cm.total_spent,
    cm.average_ticket,
    cm.last_visit_at,
    cm.first_visit_at,
    cm.days_since_last_visit,
    cm.avg_days_between_visits,
    case
      when cm.total_visits = 0 then 'sin_visitas'
      when cm.days_since_last_visit > 45 then 'en_riesgo'
      when cm.total_visits >= 3 and cm.days_since_last_visit <= 35 then 'vip'
      when cm.total_visits >= 2 and cm.days_since_last_visit <= 45 then 'recurrente'
      else 'nuevo'
    end::text as segment
  from client_metrics cm
  order by cm.active desc, lower(cm.name) asc, cm.created_at desc;
end;
$$;

revoke all on function public.get_clients_management_summary() from public;
revoke all on function public.get_clients_management_summary() from anon;
grant execute on function public.get_clients_management_summary() to authenticated;
