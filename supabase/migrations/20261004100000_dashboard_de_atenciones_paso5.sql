-- ==============================================================================
-- Paso 5 del plan de David (D-308, D-311): el DASHBOARD DE ATENCIONES y su
-- INTERRUPTOR PROPIO. (D-317)
-- ==============================================================================
--
-- QUÉ SE DECIDIÓ (04-oct)
--
-- 1. El Dashboard tiene su propio interruptor en el Panel, separado de
--    "Finanzas" (`financial_reports`), que se queda solo con Reportes. Así a
--    David se le puede dar el Dashboard sin darle Reportes de caja.
-- 2. En los negocios sin caja, un Dashboard nuevo que cuenta la historia del
--    negocio en ATENCIONES y no en pesos. El propietario aprobó el prototipo
--    https://claude.ai/artifact/Ptnrpy3N23NbSATn2n3BP3 ("me encantó").
--    El Dashboard de los negocios con caja no se toca (D-311).
--
-- QUÉ TOCA: SOLO AGREGA
--
--   * La capacidad `dashboard`, ENCENDIDA en los cuatro planes, como se hizo
--     con las de D-310: nadie nota nada hasta que el Panel se la apague a un
--     negocio. `on conflict do nothing`.
--   * Una función nueva, `get_dashboard_atenciones`. Ninguna existente se
--     reescribe. Copia de las vivas del Dashboard
--     (`intervenciones/extraer_dashboard_de_atenciones_paso5.sql`): quién
--     puede llamarla (`is_owner_or_admin`), qué sedes mira
--     (`private.beautyos_dashboard_branches`, con el día en la hora de cada
--     sede), las validaciones de los rangos y la granularidad del gráfico
--     (día hasta 62 días, semana hasta 366, mes después).
--
-- QUÉ CUENTA, Y POR QUÉ ASÍ
--
--   * ATENDIDA = cita en `cerrado` o `finalizado`. En un negocio sin caja,
--     "Cerrar" deja la cita en `cerrado` (D-312: atendida, no pagada); en uno
--     con caja, `finalizado` es atendida por cobrar. Es la misma regla de
--     `get_dashboard_today` y de Invitar a volver (D-314).
--   * NUEVA = la clienta cuya PRIMERA cita atendida en el negocio (en
--     cualquier sede) cae en el periodo.
--   * HORAS DE TRABAJO = la duración de los servicios no cancelados de las
--     citas atendidas.
--   * EN LÍNEA = canal `web_publico` (las que nacen en la página del salón).
--   * PERDIDAS = `cancelado` y `no_asistio`. Su motivo vive en
--     `ticket_history.reason` y es texto libre: se devuelven los cinco más
--     recientes, tal cual, sin agruparlos (agrupar texto libre inventaría
--     categorías).
--   * INVITACIONES = las de Invitar a volver enviadas en el periodo, y
--     cuántas de esas clientas agendaron una cita (no cancelada) DESPUÉS de
--     la invitación.
--   * FILTROS: estilista y servicio, como en el prototipo. Una cita pasa el
--     filtro si alguno de sus servicios es de esa estilista o de ese servicio.
--     La lista de servicios se filtra solo por estilista, y la del equipo solo
--     por servicio, para que al tocar una se sigan viendo las demás.
--   * Ningún peso: no lee `price` ni pagos, a propósito.
--
-- NO revisa la capacidad `dashboard` en el servidor, igual que las funciones
-- del Dashboard de hoy: el interruptor decide qué se ve en la app, no quién
-- puede leer sus propias cifras.
--
-- Lo prueba el CONTROL 244.
-- ==============================================================================

set client_encoding = 'UTF8';

begin;

-- ---------------------------------------------------------------- 1. el interruptor
insert into public.features (key, name, description) values
  ('dashboard', 'Dashboard',
   'El tablero de la dueña. Con la caja apagada, cuenta atenciones y no pesos.')
on conflict (key) do nothing;

insert into public.plan_features (plan_id, feature_id, enabled)
select p.id, f.id, true
from public.plans p
cross join public.features f
where f.key = 'dashboard'
on conflict (plan_id, feature_id) do nothing;

-- ---------------------------------------------------------------- 2. la consulta
create or replace function public.get_dashboard_atenciones(
  p_branch_ids uuid[],
  p_from date,
  p_to date,
  p_prev_from date,
  p_prev_to date,
  p_stylist_id uuid default null,
  p_service_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog
as $$
declare
  v_branches integer;
  v_dias integer;
  v_grano text;
  v_resultado jsonb;
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

  if (p_to - p_from) > 3660 or (p_prev_to - p_prev_from) > 3660 then
    raise exception 'El rango del Dashboard no puede superar los 10 anos.';
  end if;

  select count(*) into v_branches
  from private.beautyos_dashboard_branches(p_branch_ids);

  if v_branches = 0 then
    raise exception 'No tienes sedes que consultar con ese filtro.';
  end if;

  v_dias := (p_to - p_from) + 1;
  v_grano := case
    when v_dias <= 62 then 'day'
    when v_dias <= 366 then 'week'
    else 'month'
  end;

  with sedes as (
    select * from private.beautyos_dashboard_branches(p_branch_ids)
  ),

  reloj as (
    select (now() at time zone s.timezone)::date as hoy
    from sedes s
    order by s.is_primary desc, s.branch_id
    limit 1
  ),

  -- Las citas de los dos tramos, con su día y su hora en la de su sede.
  citas as (
    select
      tk.id,
      tk.client_id,
      tk.channel,
      tk.created_at,
      lower(tk.status) as estado,
      (tk.scheduled_at at time zone s.timezone) as hora_local,
      (tk.scheduled_at at time zone s.timezone)::date as dia,
      s.tenant_id
    from sedes s
    join public.tickets tk
      on tk.branch_id = s.branch_id
     and tk.tenant_id = s.tenant_id
    where tk.scheduled_at is not null
      and tk.scheduled_at >= (least(p_from, p_prev_from)::timestamp at time zone s.timezone)
      and tk.scheduled_at < ((greatest(p_to, p_prev_to) + 1)::timestamp at time zone s.timezone)
  ),

  marcadas as (
    select
      c.*,
      c.estado in ('cerrado', 'finalizado') as atendida,
      c.dia between p_from and p_to as en_actual,
      c.dia between p_prev_from and p_prev_to as en_anterior,
      (p_stylist_id is null or exists (
        select 1 from public.ticket_services ts
        where ts.ticket_id = c.id and ts.stylist_id = p_stylist_id
      )) as pasa_estilista,
      (p_service_id is null or exists (
        select 1 from public.ticket_services ts
        where ts.ticket_id = c.id and ts.service_id = p_service_id
      )) as pasa_servicio
    from citas c
  ),

  -- La primera cita atendida de cada clienta en el negocio, en cualquier sede:
  -- es lo que la vuelve "nueva".
  primera as (
    select tk.client_id, min((tk.scheduled_at at time zone b.timezone)::date) as dia
    from public.tickets tk
    join public.branches b on b.id = tk.branch_id
    where tk.tenant_id in (select distinct s.tenant_id from sedes s)
      and tk.client_id in (select m.client_id from marcadas m where m.atendida)
      and lower(tk.status) in ('cerrado', 'finalizado')
      and tk.scheduled_at is not null
    group by tk.client_id
  ),

  tramos as (
    select * from (values
      ('actual', p_from, p_to),
      ('anterior', p_prev_from, p_prev_to)
    ) t(tramo, desde, hasta)
  ),

  kpi as (
    select
      t.tramo,
      count(m.id) filter (where m.atendida)::integer as atendidas,
      count(distinct m.client_id) filter (where m.atendida)::integer as clientas,
      count(distinct m.client_id) filter (
        where m.atendida and p.dia between t.desde and t.hasta
      )::integer as nuevas,
      count(m.id) filter (where m.estado = 'cancelado')::integer as canceladas,
      count(m.id) filter (where m.estado = 'no_asistio')::integer as no_llegaron,
      count(m.id) filter (where m.atendida and m.channel = 'web_publico')::integer as en_linea
    from tramos t
    left join marcadas m
      on m.dia between t.desde and t.hasta
     and m.pasa_estilista
     and m.pasa_servicio
    left join primera p on p.client_id = m.client_id
    group by t.tramo
  ),

  minutos as (
    select t.tramo, coalesce(sum(ts.duration_minutes), 0)::integer as minutos
    from tramos t
    left join marcadas m
      on m.dia between t.desde and t.hasta
     and m.atendida
     and m.pasa_estilista
     and m.pasa_servicio
    left join public.ticket_services ts
      on ts.ticket_id = m.id
     and lower(ts.status) <> 'cancelado'
     and (p_stylist_id is null or ts.stylist_id = p_stylist_id)
     and (p_service_id is null or ts.service_id = p_service_id)
    group by t.tramo
  ),

  huecos as (
    select 'actual'::text as tramo, g::date as bucket
    from generate_series(
      date_trunc(v_grano, p_from::timestamp),
      date_trunc(v_grano, p_to::timestamp),
      ('1 ' || v_grano)::interval
    ) g
    union all
    select 'anterior'::text, g::date
    from generate_series(
      date_trunc(v_grano, p_prev_from::timestamp),
      date_trunc(v_grano, p_prev_to::timestamp),
      ('1 ' || v_grano)::interval
    ) g
  ),

  conteo_serie as (
    select
      case when m.en_actual then 'actual' else 'anterior' end as tramo,
      date_trunc(v_grano, m.dia::timestamp)::date as bucket,
      count(*)::integer as n
    from marcadas m
    where m.atendida and m.pasa_estilista and m.pasa_servicio
      and (m.en_actual or m.en_anterior)
    group by 1, 2
  ),

  serie as (
    select h.tramo, h.bucket, coalesce(c.n, 0) as atendidas
    from huecos h
    left join conteo_serie c on c.tramo = h.tramo and c.bucket = h.bucket
  ),

  calor as (
    select
      extract(isodow from m.hora_local)::integer as dia_semana,
      extract(hour from m.hora_local)::integer as hora,
      count(*)::integer as atendidas
    from marcadas m
    where m.en_actual and m.atendida and m.pasa_estilista and m.pasa_servicio
    group by 1, 2
  ),

  -- La lista de servicios se filtra por estilista, no por servicio.
  servicios as (
    select
      sv.id as service_id,
      sv.name as nombre,
      sv.category as categoria,
      sv.duration_minutes as duracion,
      count(*)::integer as atenciones,
      coalesce(sum(ts.duration_minutes), 0)::integer as minutos
    from marcadas m
    join public.ticket_services ts
      on ts.ticket_id = m.id
     and lower(ts.status) <> 'cancelado'
     and (p_stylist_id is null or ts.stylist_id = p_stylist_id)
    join public.services sv on sv.id = ts.service_id
    where m.en_actual and m.atendida
    group by sv.id, sv.name, sv.category, sv.duration_minutes
  ),

  -- La del equipo se filtra por servicio, no por estilista.
  equipo_base as (
    select distinct ts.stylist_id, m.id as ticket_id, m.client_id, m.dia, m.channel
    from marcadas m
    join public.ticket_services ts
      on ts.ticket_id = m.id
     and lower(ts.status) <> 'cancelado'
     and ts.stylist_id is not null
     and (p_service_id is null or ts.service_id = p_service_id)
    where m.en_actual and m.atendida
  ),

  equipo as (
    select
      st.id as stylist_id,
      st.name as nombre,
      count(*)::integer as citas,
      (
        select coalesce(sum(ts.duration_minutes), 0)
        from public.ticket_services ts
        where ts.stylist_id = st.id
          and lower(ts.status) <> 'cancelado'
          and (p_service_id is null or ts.service_id = p_service_id)
          and ts.ticket_id in (select e2.ticket_id from equipo_base e2 where e2.stylist_id = st.id)
      )::integer as minutos,
      count(*) filter (where p.dia = e.dia)::integer as nuevas,
      count(*) filter (where e.channel = 'web_publico')::integer as en_linea,
      (
        select round(avg(r.rating)::numeric, 2)
        from public.reviews r
        where r.active and r.stylist_id = st.id
          and r.ticket_id in (select e2.ticket_id from equipo_base e2 where e2.stylist_id = st.id)
      ) as calificacion,
      (
        select count(*)
        from public.reviews r
        where r.active and r.stylist_id = st.id
          and r.ticket_id in (select e2.ticket_id from equipo_base e2 where e2.stylist_id = st.id)
      )::integer as resenas
    from equipo_base e
    join public.stylists st on st.id = e.stylist_id
    left join primera p on p.client_id = e.client_id
    group by st.id, st.name
  ),

  semanas as (
    select
      x.semana,
      count(distinct x.client_id) filter (where x.primera_dia >= x.semana)::integer as nuevas,
      count(distinct x.client_id) filter (where x.primera_dia < x.semana)::integer as vuelven
    from (
      select
        date_trunc('week', m.dia::timestamp)::date as semana,
        m.client_id,
        p.dia as primera_dia
      from marcadas m
      left join primera p on p.client_id = m.client_id
      where m.en_actual and m.atendida and m.pasa_estilista and m.pasa_servicio
    ) x
    group by x.semana
  ),

  invitaciones as (
    select
      count(*)::integer as enviadas,
      count(*) filter (where exists (
        select 1 from public.tickets t2
        where t2.tenant_id = i.tenant_id
          and t2.client_id = i.client_id
          and t2.created_at > i.invited_at
          and lower(t2.status) <> 'cancelado'
      ))::integer as agendaron
    from public.client_return_invitations i
    join sedes s on s.branch_id = i.branch_id and s.tenant_id = i.tenant_id
    where (i.invited_at at time zone s.timezone)::date between p_from and p_to
  ),

  perdidas as (
    select *
    from marcadas m
    where m.en_actual
      and m.estado in ('cancelado', 'no_asistio')
      and m.pasa_estilista
      and m.pasa_servicio
  ),

  perdidas_por_dia as (
    select extract(isodow from pd.hora_local)::integer as dia_semana, count(*)::integer as n
    from perdidas pd
    group by 1
  ),

  motivos as (
    select
      pd.estado,
      h.reason as motivo,
      pd.dia,
      h.created_at,
      (
        select string_agg(distinct sv.name, ', ')
        from public.ticket_services ts
        join public.services sv on sv.id = ts.service_id
        where ts.ticket_id = pd.id
      ) as servicios,
      (
        select string_agg(distinct st.name, ', ')
        from public.ticket_services ts
        join public.stylists st on st.id = ts.stylist_id
        where ts.ticket_id = pd.id
      ) as estilistas
    from perdidas pd
    join lateral (
      select th.reason, th.created_at
      from public.ticket_history th
      where th.ticket_id = pd.id
        and th.new_status = pd.estado
        and nullif(trim(th.reason), '') is not null
      order by th.created_at desc
      limit 1
    ) h on true
    order by h.created_at desc
    limit 5
  ),

  -- Hoy es hoy: no cambia con el periodo ni con los filtros.
  hoy as (
    select
      count(*) filter (where lower(tk.status) <> 'cancelado')::integer as citas,
      count(*) filter (where lower(tk.status) in ('cerrado', 'finalizado'))::integer as cerradas,
      count(*) filter (where lower(tk.status) = 'en_proceso')::integer as en_proceso,
      count(*) filter (where lower(tk.status) in
        ('solicitado', 'cotizado', 'apartado', 'confirmado', 'en_espera'))::integer as por_atender
    from sedes s
    cross join reloj r
    join public.tickets tk
      on tk.branch_id = s.branch_id
     and tk.tenant_id = s.tenant_id
    where tk.scheduled_at >= (r.hoy::timestamp at time zone s.timezone)
      and tk.scheduled_at < ((r.hoy + 1)::timestamp at time zone s.timezone)
  )

  select jsonb_build_object(
    'hoy_en_la_sede', (select r.hoy from reloj r),
    'granularidad', v_grano,
    'sedes', v_branches,
    'hoy', (select to_jsonb(h) from hoy h),
    'actual', (
      select to_jsonb(k) - 'tramo' || jsonb_build_object('minutos', mi.minutos)
      from kpi k join minutos mi on mi.tramo = k.tramo
      where k.tramo = 'actual'
    ),
    'anterior', (
      select to_jsonb(k) - 'tramo' || jsonb_build_object('minutos', mi.minutos)
      from kpi k join minutos mi on mi.tramo = k.tramo
      where k.tramo = 'anterior'
    ),
    'serie', (
      select coalesce(jsonb_agg(jsonb_build_object('bucket', s.bucket, 'atendidas', s.atendidas)
                                order by s.bucket), '[]'::jsonb)
      from serie s where s.tramo = 'actual'
    ),
    'serie_anterior', (
      select coalesce(jsonb_agg(jsonb_build_object('bucket', s.bucket, 'atendidas', s.atendidas)
                                order by s.bucket), '[]'::jsonb)
      from serie s where s.tramo = 'anterior'
    ),
    'calor', (
      select coalesce(jsonb_agg(to_jsonb(c) order by c.dia_semana, c.hora), '[]'::jsonb)
      from calor c
    ),
    'servicios', (
      select coalesce(jsonb_agg(to_jsonb(sv) order by sv.atenciones desc, sv.nombre), '[]'::jsonb)
      from servicios sv
    ),
    'equipo', (
      select coalesce(jsonb_agg(to_jsonb(e) order by e.citas desc, e.nombre), '[]'::jsonb)
      from equipo e
    ),
    'semanas', (
      select coalesce(jsonb_agg(to_jsonb(w) order by w.semana), '[]'::jsonb)
      from semanas w
    ),
    'invitaciones', (select to_jsonb(i) from invitaciones i),
    'perdidas_por_dia', (
      select coalesce(jsonb_agg(to_jsonb(pd) order by pd.dia_semana), '[]'::jsonb)
      from perdidas_por_dia pd
    ),
    'perdidas_en_linea', (
      select count(*)::integer from perdidas pd where pd.channel = 'web_publico'
    ),
    'motivos', (
      select coalesce(jsonb_agg(to_jsonb(mo) - 'created_at' order by mo.created_at desc), '[]'::jsonb)
      from motivos mo
    )
  )
  into v_resultado;

  return v_resultado;
end;
$$;

revoke all on function public.get_dashboard_atenciones(uuid[], date, date, date, date, uuid, uuid)
  from public, anon;
grant execute on function public.get_dashboard_atenciones(uuid[], date, date, date, date, uuid, uuid)
  to authenticated;

commit;
