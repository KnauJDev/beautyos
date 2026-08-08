-- Salon y Mas - Resumen comparado del Dashboard (tarea 2.5a, D-110).
--
-- Una sola consulta que devuelve los cuatro indicadores protagonistas del
-- periodo elegido, los mismos cuatro del periodo con el que se comparan, y el
-- contexto que la aplicacion necesita para decidir si esa comparacion se puede
-- mostrar.
--
-- Va todo junto en un solo viaje a proposito: si el periodo actual y el
-- anterior llegaran en dos consultas, la pantalla pintaria el numero y el
-- porcentaje aparecería despues, que es exactamente el parpadeo que D-110
-- quiere evitar.
--
-- DEFINICIONES QUE FIJA ESTE ARCHIVO (apartado 3 de la especificacion). No se
-- pueden cambiar aqui sin cambiarlas alli:
--
--   * VENTA es **dinero cobrado**: `ticket_payments` en estado `registrado`.
--     NO es ticket finalizado. Un servicio terminado y sin cobrar no suma a
--     ventas -- vive en "por cobrar". Es coherente con la regla del cero de la
--     Agenda (D-101).
--   * CITA es un ticket con fecha dentro del periodo, **excluyendo los
--     cancelados**. Cancelado y no asistio se cuentan aparte y nunca dentro de
--     "Citas": no es lo mismo "18 citas" que "20 citas, 18 atendidas, 2 no
--     asistio".
--   * CLIENTE ATENDIDO es el que tiene al menos un cobro en el periodo. **No
--     es el cliente registrado**, que es justamente el numero que hoy muestra
--     el Dashboard y no sirve.
--
-- ZONA HORARIA: cada pago se ubica en el dia segun la zona de **su propia
-- sede** (`branches.timezone`), no en UTC ni en la del navegador. Sin esto un
-- cobro de las 7:30 de la noche caeria en el dia siguiente y el cierre de caja
-- no cuadraria sin que nadie entendiera por que.

begin;

-- ---------------------------------------------------------------------------
-- 1. Sedes que el usuario puede consultar de verdad.
--
-- Misma regla que `get_my_branch_context_v2`: el propietario alcanza todas las
-- sedes de su negocio por su rol; los demas solo aquellas donde tienen
-- membresia. **El filtro que manda la pantalla se intersecta con esto, nunca
-- lo sustituye**: un asistente que pidiera la sede vecina recibe cero filas,
-- no los datos de la otra sede.
-- ---------------------------------------------------------------------------

create or replace function private.beautyos_dashboard_branches(
  p_branch_ids uuid[]
)
returns table (branch_id uuid, tenant_id uuid, timezone text, is_primary boolean)
language sql
security definer
set search_path = pg_catalog
stable
as $$
  select b.id, b.tenant_id, b.timezone, b.is_primary
  from public.tenant_memberships tm
  join public.branches b
    on b.tenant_id = tm.tenant_id
   and b.active
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
$$;

revoke all on function private.beautyos_dashboard_branches(uuid[])
  from public, anon, authenticated;
grant execute on function private.beautyos_dashboard_branches(uuid[])
  to authenticated;

comment on function private.beautyos_dashboard_branches(uuid[])
  is 'Sedes que el usuario actual puede consultar en el Dashboard. Interseca el filtro de la pantalla con las sedes de las que realmente es miembro.';

-- ---------------------------------------------------------------------------
-- 2. El resumen comparado.
-- ---------------------------------------------------------------------------

drop function if exists public.get_dashboard_overview(uuid[], date, date, date, date);

create or replace function public.get_dashboard_overview(
  p_branch_ids uuid[],
  p_from date,
  p_to date,
  p_prev_from date,
  p_prev_to date
)
returns table (
  sales numeric,
  appointments integer,
  clients_served integer,
  paid_tickets integer,
  prev_sales numeric,
  prev_appointments integer,
  prev_clients_served integer,
  prev_paid_tickets integer,
  first_activity_on date,
  today_on date,
  branches_included integer
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_branches integer;
begin
  if not public.is_owner_or_admin() then
    raise exception 'No autorizado. El Dashboard es de owner o admin.';
  end if;

  if p_from is null or p_to is null
     or p_prev_from is null or p_prev_to is null then
    raise exception 'Los dos rangos del Dashboard son obligatorios.';
  end if;

  if p_to < p_from or p_prev_to < p_prev_from then
    raise exception 'Un rango no puede terminar antes de empezar.';
  end if;

  -- Tope de cordura: el atajo mas largo es un ano y el rango libre lo elige
  -- una persona a mano. Pedir doscientos anos solo puede ser un error o una
  -- forma barata de tumbar la base de datos.
  if (p_to - p_from) > 3660 or (p_prev_to - p_prev_from) > 3660 then
    raise exception 'El rango del Dashboard no puede superar los 10 anos.';
  end if;

  select count(*) into v_branches
  from private.beautyos_dashboard_branches(p_branch_ids);

  if v_branches = 0 then
    raise exception 'No tienes sedes que consultar con ese filtro.';
  end if;

  return query
  with sedes as (
    select * from private.beautyos_dashboard_branches(p_branch_ids)
  ),

  -- Cada pago cae en el dia de SU sede. El join contra tickets no es
  -- decorativo: `ticket_payments` no guarda la sede, hay que llegar por el
  -- ticket.
  pagos as (
    select
      tp.amount,
      tp.ticket_id,
      tk.client_id,
      (tp.received_at at time zone s.timezone)::date as dia
    from public.ticket_payments tp
    join public.tickets tk
      on tk.id = tp.ticket_id
     and tk.tenant_id = tp.tenant_id
    join sedes s
      on s.branch_id = tk.branch_id
    where tp.status = 'registrado'
  ),

  citas as (
    select
      tk.id,
      (tk.scheduled_at at time zone s.timezone)::date as dia
    from public.tickets tk
    join sedes s
      on s.branch_id = tk.branch_id
    where tk.scheduled_at is not null
      -- Los cancelados nunca entran en "Citas". Se cuentan aparte.
      and lower(tk.status) <> 'cancelado'
  ),

  actual as (
    select
      coalesce(sum(p.amount), 0)::numeric as sales,
      count(distinct p.ticket_id)::integer as paid_tickets,
      count(distinct p.client_id)::integer as clients_served
    from pagos p
    where p.dia between p_from and p_to
  ),
  actual_citas as (
    select count(distinct c.id)::integer as n
    from citas c
    where c.dia between p_from and p_to
  ),

  anterior as (
    select
      coalesce(sum(p.amount), 0)::numeric as sales,
      count(distinct p.ticket_id)::integer as paid_tickets,
      count(distinct p.client_id)::integer as clients_served
    from pagos p
    where p.dia between p_prev_from and p_prev_to
  ),
  anterior_citas as (
    select count(distinct c.id)::integer as n
    from citas c
    where c.dia between p_prev_from and p_prev_to
  ),

  -- Desde cuando hay historia. Es lo que permite distinguir "tu negocio no
  -- existia" de "no hubo movimiento": la primera dice espera, la segunda dice
  -- mejoraste, y mostrarlas igual seria mentir en una de las dos.
  historia as (
    select least(
      (select min(c.dia) from citas c),
      (select min(p.dia) from pagos p)
    ) as desde
  ),

  reloj as (
    select (now() at time zone s.timezone)::date as hoy
    from sedes s
    order by s.is_primary desc, s.branch_id
    limit 1
  )

  select
    a.sales,
    ac.n,
    a.clients_served,
    a.paid_tickets,
    b.sales,
    bc.n,
    b.clients_served,
    b.paid_tickets,
    h.desde,
    r.hoy,
    v_branches
  from actual a
  cross join actual_citas ac
  cross join anterior b
  cross join anterior_citas bc
  cross join historia h
  cross join reloj r;
end;
$$;

revoke all on function public.get_dashboard_overview(uuid[], date, date, date, date)
  from public, anon, authenticated;
grant execute on function public.get_dashboard_overview(uuid[], date, date, date, date)
  to authenticated;

comment on function public.get_dashboard_overview(uuid[], date, date, date, date)
  is 'Vista 1 del Dashboard: los cuatro indicadores del periodo y los del periodo anterior en un solo viaje, mas la fecha de inicio de la historia y el hoy de la sede. Venta = cobro registrado; cita excluye cancelados; cliente atendido = con cobro en el periodo.';

commit;
