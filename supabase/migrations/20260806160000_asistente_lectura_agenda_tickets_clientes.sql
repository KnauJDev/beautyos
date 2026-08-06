-- Etapa 1, cierre de H-01: el rol asistente no podia LEER lo que si podia
-- ESCRIBIR.
--
-- Al dar pantallas al asistente (D-092) se verificaron las 14 funciones de
-- accion que ya lo autorizaban -- agendar, reprogramar, cobrar, crear
-- clientes -- pero no las de lectura, que son las que las pantallas usan para
-- mostrar datos. Resultado: el asistente entraba, veia su menu de tres
-- modulos y la Agenda fallaba con 'El contexto de sede no esta disponible.',
-- porque get_agenda_summary_v2 solo admitia tenant_owner y admin.
--
-- Se auditaron las 20 funciones que usan Agenda, Tickets y Clientes. Se
-- corrigen las cuatro que le faltaban:
--   get_agenda_summary_v2, get_tickets_summary_v2   (roles de sede)
--   get_clients_management_summary, update_client   (helpers heredados)
--
-- Queda fuera a proposito get_ticket_services_for_correction_v2, que es la
-- lectura previa a reabrir un servicio ya finalizado: eso toca comisiones ya
-- calculadas y tickets cerrados, y sigue siendo cosa de owner y admin, igual
-- que su accion reopen_finished_ticket_service_v2.

create or replace function public.get_agenda_summary_v2(
  p_branch_id uuid
)
returns table (
  id uuid,
  client_name text,
  scheduled_at timestamptz,
  status text,
  service_names text,
  stylist_names text,
  total_price numeric,
  total_duration_minutes integer
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select r.tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id,
    array['tenant_owner', 'admin', 'assistant'],
    true
  ) r;

  return query
  select
    tk.id,
    coalesce(c.name, 'Cliente sin nombre'),
    tk.scheduled_at,
    tk.status,
    coalesce(
      string_agg(distinct s.name, ', ' order by s.name),
      'Sin servicios'
    ),
    coalesce(
      string_agg(distinct st.name, ', ' order by st.name),
      'Sin estilista'
    ),
    coalesce(sum(ts.price), 0)::numeric,
    coalesce(sum(ts.duration_minutes), 0)::integer
  from public.tickets tk
  left join public.clients c
    on c.tenant_id = tk.tenant_id
   and c.id = tk.client_id
   and c.active
  left join public.ticket_services ts
    on ts.tenant_id = tk.tenant_id
   and ts.branch_id = tk.branch_id
   and ts.ticket_id = tk.id
   and lower(ts.status) <> 'cancelado'
  left join public.services s
    on s.tenant_id = ts.tenant_id
   and s.id = ts.service_id
   and s.active
  left join public.stylists st
    on st.tenant_id = ts.tenant_id
   and st.id = ts.stylist_id
   and st.active
  where tk.tenant_id = v_tenant_id
    and tk.branch_id = p_branch_id
    and tk.scheduled_at is not null
    and lower(tk.status) in ('confirmado', 'en_espera', 'en_proceso')
  group by tk.id, c.name, tk.scheduled_at, tk.status
  order by tk.scheduled_at;
end;
$$;

create or replace function public.get_tickets_summary_v2(
  p_branch_id uuid
)
returns table (
  id uuid,
  client_name text,
  scheduled_at timestamptz,
  status text,
  channel text,
  service_names text,
  stylist_names text,
  total_price numeric,
  total_duration_minutes integer,
  paid_amount numeric,
  balance_amount numeric,
  payment_status text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select r.tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id,
    array['tenant_owner', 'admin', 'assistant'],
    true
  ) r;

  return query
  with service_summary as (
    select
      ts.ticket_id,
      coalesce(
        string_agg(distinct s.name, ', ' order by s.name)
          filter (where ts.status <> 'cancelado'),
        'Sin servicios'
      ) as service_names,
      coalesce(
        string_agg(distinct st.name, ', ' order by st.name)
          filter (where ts.status <> 'cancelado'),
        'Sin estilista'
      ) as stylist_names,
      coalesce(
        sum(ts.price) filter (where ts.status <> 'cancelado'),
        0
      )::numeric as total_price,
      coalesce(
        sum(ts.duration_minutes) filter (where ts.status <> 'cancelado'),
        0
      )::integer as total_duration_minutes
    from public.ticket_services ts
    left join public.services s
      on s.tenant_id = ts.tenant_id
     and s.id = ts.service_id
    left join public.stylists st
      on st.tenant_id = ts.tenant_id
     and st.id = ts.stylist_id
    where ts.tenant_id = v_tenant_id
      and ts.branch_id = p_branch_id
    group by ts.ticket_id
  ),
  payment_summary as (
    select
      tp.ticket_id,
      coalesce(sum(tp.amount), 0)::numeric as paid_amount
    from public.ticket_payments tp
    where tp.tenant_id = v_tenant_id
      and tp.branch_id = p_branch_id
      and tp.status = 'registrado'
    group by tp.ticket_id
  )
  select
    tk.id,
    coalesce(c.name, 'Cliente sin nombre'),
    tk.scheduled_at,
    tk.status,
    tk.channel,
    coalesce(ss.service_names, 'Sin servicios'),
    coalesce(ss.stylist_names, 'Sin estilista'),
    coalesce(ss.total_price, 0)::numeric,
    coalesce(ss.total_duration_minutes, 0)::integer,
    coalesce(ps.paid_amount, 0)::numeric,
    greatest(
      coalesce(ss.total_price, 0) - coalesce(ps.paid_amount, 0),
      0
    )::numeric,
    case
      when coalesce(ps.paid_amount, 0) = 0 then 'sin_pago'
      when coalesce(ps.paid_amount, 0) < coalesce(ss.total_price, 0)
        then 'parcial'
      else 'pagado'
    end
  from public.tickets tk
  left join public.clients c
    on c.tenant_id = tk.tenant_id
   and c.id = tk.client_id
   and c.active
  left join service_summary ss on ss.ticket_id = tk.id
  left join payment_summary ps on ps.ticket_id = tk.id
  where tk.tenant_id = v_tenant_id
    and tk.branch_id = p_branch_id
  order by tk.scheduled_at desc nulls last, tk.created_at desc;
end;
$$;

create or replace function public.get_clients_management_summary()
returns table (
  id uuid,
  name text,
  phone text,
  email text,
  notes text,
  active boolean,
  created_at timestamptz,
  balance_amount numeric
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

  -- El asistente entra aqui (D-094): es el rol de recepcion y caja, y ya podia
  -- crear clientes. Poder administrar los suyos es la contraparte natural; sin esto
  -- veia la pantalla de Clientes con botones que fallaban.
  if public.get_my_role() not in ('owner', 'admin', 'assistant') then
    raise exception 'No autorizado. Solo owner, admin o asistente puede administrar clientes.';
  end if;

  return query
  with ticket_totals as (
    select
      t.id as ticket_id,
      t.client_id,
      coalesce(sum(ts.price) filter (where ts.status = 'finalizado'), 0)::numeric as total_amount
    from public.tickets t
    join public.ticket_services ts
      on ts.ticket_id = t.id
     and ts.tenant_id = v_tenant_id
    where t.tenant_id = v_tenant_id
      and t.status = 'finalizado'
    group by t.id, t.client_id
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
  client_balances as (
    select
      tt.client_id,
      sum(greatest(tt.total_amount - coalesce(tpaid.paid_amount, 0), 0)) as balance_amount
    from ticket_totals tt
    left join ticket_paid tpaid on tpaid.ticket_id = tt.ticket_id
    group by tt.client_id
  )
  select
    c.id,
    c.name,
    c.phone,
    c.email,
    c.notes,
    c.active,
    c.created_at,
    coalesce(cb.balance_amount, 0)::numeric
  from public.clients c
  left join client_balances cb on cb.client_id = c.id
  where c.tenant_id = v_tenant_id
  order by c.active desc, lower(c.name) asc, c.created_at desc;
end;
$$;

create or replace function public.update_client(
  p_client_id uuid,
  p_name text,
  p_phone text,
  p_email text default null,
  p_notes text default null,
  p_active boolean default true
)
returns table (
  id uuid,
  name text,
  phone text,
  email text,
  notes text,
  active boolean,
  created_at timestamptz
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

  -- El asistente entra aqui (D-094): es el rol de recepcion y caja, y ya podia
  -- crear clientes. Poder modificar los suyos es la contraparte natural; sin esto
  -- veia la pantalla de Clientes con botones que fallaban.
  if public.get_my_role() not in ('owner', 'admin', 'assistant') then
    raise exception 'No autorizado. Solo owner, admin o asistente puede modificar clientes.';
  end if;

  if p_client_id is null then
    raise exception 'El cliente es obligatorio.';
  end if;

  if length(trim(coalesce(p_name, ''))) = 0 then
    raise exception 'El nombre del cliente es obligatorio.';
  end if;

  if length(trim(coalesce(p_phone, ''))) = 0 then
    raise exception 'El teléfono del cliente es obligatorio.';
  end if;

  if p_active is null then
    raise exception 'El estado del cliente es obligatorio.';
  end if;

  return query
  update public.clients c
     set name = trim(p_name),
         phone = trim(p_phone),
         email = nullif(trim(coalesce(p_email, '')), ''),
         notes = nullif(trim(coalesce(p_notes, '')), ''),
         active = p_active
   where c.id = p_client_id
     and c.tenant_id = v_tenant_id
  returning
    c.id,
    c.name,
    c.phone,
    c.email,
    c.notes,
    c.active,
    c.created_at;

  if not found then
    raise exception 'Cliente no encontrado o no pertenece al centro actual.';
  end if;
end;
$$;
