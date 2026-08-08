-- Salon y Mas - "Agenda de hoy" y los avisos del Dashboard (2.5a, D-110).
--
-- Lo que falta de la Vista 1: el bloque de hoy y los dos o tres avisos de "lo
-- que deberias mirar". Van en una sola consulta porque se pintan juntos y
-- ninguno de los dos depende del rango de fechas elegido arriba: **hoy es hoy,
-- mire el propietario el mes o el ano**.
--
-- LOS TRES AVISOS, Y POR QUE ESTOS
--
-- 1. **Por cobrar.** Servicios terminados que nadie cobro. Es dinero ya
--    trabajado que esta en la calle, y es lo unico del tablero sobre lo que se
--    puede actuar hoy mismo. Conecta con la regla del cero de la Agenda
--    (D-101): al cerrar el dia esto deberia estar vacio.
-- 2. **Clientes en riesgo.** Quien venia seguido y lleva mas de 45 dias sin
--    aparecer. Se exige que hubiera venido **dos veces o mas** antes: alguien
--    que fue una sola vez no "dejo de venir", simplemente probo.
-- 3. **Citas de hoy sin confirmar.** Lo que exige una llamada esta manana.
--
-- Se descarto a proposito cualquier aviso que necesite capacidad -- "tienes 18
-- espacios libres manana" -- porque sin horarios por profesional seria una
-- cifra inventada. Es la regla de oro de D-110.

begin;

drop function if exists public.get_dashboard_today(uuid[]);

create or replace function public.get_dashboard_today(
  p_branch_ids uuid[]
)
returns table (
  today_on date,
  appointments_today integer,
  attended_today integer,
  pending_today integer,
  unconfirmed_today integer,
  receivable_amount numeric,
  receivable_tickets integer,
  clients_at_risk integer
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if not public.is_owner_or_admin() then
    raise exception 'No autorizado. El Dashboard es de owner o admin.';
  end if;

  if not exists (
    select 1 from private.beautyos_dashboard_branches(p_branch_ids)
  ) then
    raise exception 'No tienes sedes que consultar con ese filtro.';
  end if;

  return query
  with sedes as (
    select * from private.beautyos_dashboard_branches(p_branch_ids)
  ),

  -- El dia lo decide la sede, no el navegador. A partir de las 7 de la noche
  -- una zona equivocada mueve la agenda al dia siguiente.
  reloj as (
    select (now() at time zone s.timezone)::date as hoy
    from sedes s
    order by s.is_primary desc, s.branch_id
    limit 1
  ),

  citas_hoy as (
    select
      tk.id,
      lower(tk.status) as estado
    from public.tickets tk
    join sedes s on s.branch_id = tk.branch_id
    cross join reloj r
    where tk.scheduled_at is not null
      and (tk.scheduled_at at time zone s.timezone)::date = r.hoy
      and lower(tk.status) <> 'cancelado'
  ),

  -- Lo que se trabajo y nadie cobro. Se mira sobre TODO el historial y no
  -- sobre el periodo elegido: una cuenta de hace tres meses sigue sin cobrar
  -- hoy, y esconderla porque el filtro dice "esta semana" seria perder plata.
  por_cobrar as (
    select
      coalesce(sum(v.valor - v.pagado), 0)::numeric as monto,
      count(*)::integer as tickets
    from (
      select
        tk.id,
        coalesce((
          select sum(ts.price) from public.ticket_services ts
          where ts.ticket_id = tk.id and lower(ts.status) <> 'cancelado'
        ), 0) as valor,
        coalesce((
          select sum(tp.amount) from public.ticket_payments tp
          where tp.ticket_id = tk.id and tp.status = 'registrado'
        ), 0) as pagado
      from public.tickets tk
      join sedes s on s.branch_id = tk.branch_id
      where lower(tk.status) = 'finalizado'
    ) v
    where v.valor > v.pagado
  ),

  -- Clientes que venian y dejaron de venir. Dos atenciones o mas antes, y mas
  -- de 45 dias sin aparecer.
  en_riesgo as (
    select count(*)::integer as n
    from (
      select
        tk.client_id,
        count(*) as visitas,
        max((tk.scheduled_at at time zone s.timezone)::date) as ultima
      from public.tickets tk
      join sedes s on s.branch_id = tk.branch_id
      cross join reloj r
      where tk.client_id is not null
        and tk.scheduled_at is not null
        and lower(tk.status) in ('finalizado', 'cerrado')
        and (tk.scheduled_at at time zone s.timezone)::date <= r.hoy
      group by tk.client_id
    ) h
    cross join reloj r
    where h.visitas >= 2
      and h.ultima < r.hoy - 45
  )

  select
    r.hoy,
    (select count(*)::integer from citas_hoy),
    (select count(*)::integer from citas_hoy
      where estado in ('finalizado', 'cerrado')),
    (select count(*)::integer from citas_hoy
      where estado in ('solicitado', 'cotizado', 'apartado', 'confirmado',
                       'en_espera', 'en_proceso')),
    (select count(*)::integer from citas_hoy
      where estado in ('solicitado', 'cotizado', 'apartado')),
    pc.monto,
    pc.tickets,
    er.n
  from reloj r
  cross join por_cobrar pc
  cross join en_riesgo er;
end;
$$;

revoke all on function public.get_dashboard_today(uuid[])
  from public, anon, authenticated;
grant execute on function public.get_dashboard_today(uuid[])
  to authenticated;

comment on function public.get_dashboard_today(uuid[])
  is 'Bloque "Agenda de hoy" y avisos del Dashboard. Independiente del rango elegido: hoy es hoy. Por cobrar y clientes en riesgo se miran sobre todo el historial, porque una cuenta vieja sin cobrar sigue sin cobrarse.';

commit;
