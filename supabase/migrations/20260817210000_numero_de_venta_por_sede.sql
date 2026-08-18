-- ==============================================================================
-- Migración: Número de venta consecutivo e inmutable por sede (Paso 4.4 / D-150 / Hallazgo P)
-- ==============================================================================
-- Separa el número operativo (#0000701, D-117) del número de venta contable
-- (VTA-0000001) para evitar huecos fiscales por citas canceladas o no asistidas.
-- El número de venta se asigna atómicamente al pasar a estado 'cerrado'.
-- Soporta reglas de facturación y Resolución DIAN por sede.
-- ==============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 1. Tabla de configuración de numeración de ventas por sede
-- -----------------------------------------------------------------------------
create table if not exists public.branch_sale_numbering (
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  branch_id uuid not null references public.branches(id) on delete cascade,
  prefix text not null default 'VTA-',
  next_number bigint not null default 1,
  padding smallint not null default 7,
  resolution_number text default null,
  resolution_date date default null,
  range_from bigint default null,
  range_to bigint default null,
  valid_until date default null,
  updated_at timestamptz not null default now(),
  constraint branch_sale_numbering_pkey primary key (tenant_id, branch_id),
  constraint branch_sale_numbering_next_number_check check (next_number >= 1),
  constraint branch_sale_numbering_padding_check check (padding between 1 and 12),
  constraint branch_sale_numbering_prefix_check check (prefix ~ '^[A-Za-z0-9._-]{0,10}$'),
  constraint branch_sale_numbering_range_check check (
    (range_from is null and range_to is null) or
    (range_from is not null and range_to is not null and range_from <= range_to)
  )
);

comment on table public.branch_sale_numbering is
  'Configuración del consecutivo de ventas y Resolución DIAN por sede (D-150 / Hallazgo P).';

alter table public.branch_sale_numbering enable row level security;
revoke all on table public.branch_sale_numbering from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 2. Columnas en public.tickets
-- -----------------------------------------------------------------------------
alter table public.tickets
  add column if not exists sale_number bigint,
  add column if not exists sale_code text,
  add column if not exists closed_at timestamptz;

comment on column public.tickets.sale_number is
  'Consecutivo numérico de venta asignado al cerrarse el ticket (D-150). Inmutable.';

comment on column public.tickets.sale_code is
  'Código visible formateado de la venta (ej. VTA-0000001 o resolución DIAN). Inmutable.';

comment on column public.tickets.closed_at is
  'Momento exacto en que se completó el pago y se cerró la venta.';

-- Índices únicos parciales por sede (solo para tickets cerrados con número emitido)
create unique index if not exists tickets_tenant_branch_sale_number_idx
  on public.tickets (tenant_id, branch_id, sale_number)
  where sale_number is not null;

create unique index if not exists tickets_tenant_branch_sale_code_idx
  on public.tickets (tenant_id, branch_id, sale_code)
  where sale_code is not null;

-- -----------------------------------------------------------------------------
-- 3. Trigger: Asignación atómica de número de venta al cerrar ticket
-- -----------------------------------------------------------------------------
create or replace function private.beautyos_assign_sale_number_on_close()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_num bigint;
  v_prefix text;
  v_padding smallint;
begin
  -- Solo se ejecuta si el ticket pasa a 'cerrado' y AÚN NO TIENE sale_number.
  -- A propósito no se vuelve a entrar aqui solo porque el status cambio: un
  -- ticket que ya tiene numero de venta lo conserva para siempre, sin importar
  -- cuantas veces se reabra (void_ticket_payment) y se vuelva a cerrar. La
  -- inmutabilidad contable depende de esto, no solo del trigger de proteccion
  -- de abajo (D-150 / Hallazgo P, corregido en auditoria).
  if new.status = 'cerrado' and old.sale_number is null then
    -- 1. Asegurar que existe la fila de configuración para la sede (con lock FOR UPDATE)
    insert into public.branch_sale_numbering (tenant_id, branch_id, prefix, next_number, padding)
    values (new.tenant_id, new.branch_id, 'VTA-', 1, 7)
    on conflict (tenant_id, branch_id) do nothing;

    select bsn.prefix, bsn.next_number, bsn.padding
      into v_prefix, v_num, v_padding
    from public.branch_sale_numbering bsn
    where bsn.tenant_id = new.tenant_id
      and bsn.branch_id = new.branch_id
    for update;

    -- 2. Asignar el número y el código visible
    new.sale_number := v_num;
    new.sale_code := coalesce(v_prefix, '') || lpad(v_num::text, coalesce(v_padding, 7), '0');
    new.closed_at := coalesce(new.closed_at, now());

    -- 3. Incrementar el contador para la próxima venta
    update public.branch_sale_numbering
       set next_number = v_num + 1,
           updated_at = now()
     where tenant_id = new.tenant_id
       and branch_id = new.branch_id;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_assign_sale_number_on_close on public.tickets;
create trigger trg_assign_sale_number_on_close
  before update on public.tickets
  for each row
  when (new.status = 'cerrado' and old.sale_number is null)
  execute function private.beautyos_assign_sale_number_on_close();

-- -----------------------------------------------------------------------------
-- 4. Trigger: Inmutabilidad contable estricta
-- -----------------------------------------------------------------------------
create or replace function private.beautyos_protect_immutable_sale_number()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if old.sale_number is not null and (
    new.sale_number is distinct from old.sale_number or
    new.sale_code is distinct from old.sale_code
  ) then
    raise exception 'El número de venta de un ticket cerrado no se puede modificar ni reasignar (D-150 / Hallazgo P).';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_protect_immutable_sale_number on public.tickets;
create trigger trg_protect_immutable_sale_number
  before update of sale_number, sale_code on public.tickets
  for each row
  execute function private.beautyos_protect_immutable_sale_number();

-- -----------------------------------------------------------------------------
-- 5. RPCs de Configuración y Consulta
-- -----------------------------------------------------------------------------

-- A. get_branch_sale_numbering
create or replace function public.get_branch_sale_numbering(
  p_branch_id uuid
)
returns table (
  tenant_id uuid,
  branch_id uuid,
  prefix text,
  next_number bigint,
  padding smallint,
  resolution_number text,
  resolution_date date,
  range_from bigint,
  range_to bigint,
  valid_until date,
  last_emitted_number bigint,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  -- Validar permisos de sede (tenant_owner, admin, assistant)
  select r.tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id,
    array['tenant_owner', 'admin', 'assistant'],
    true
  ) r;

  -- Asegurar registro base si no existía
  insert into public.branch_sale_numbering (tenant_id, branch_id, prefix, next_number, padding)
  values (v_tenant_id, p_branch_id, 'VTA-', 1, 7)
  on conflict on constraint branch_sale_numbering_pkey do nothing;

  return query
  select
    bsn.tenant_id,
    bsn.branch_id,
    bsn.prefix,
    bsn.next_number,
    bsn.padding,
    bsn.resolution_number,
    bsn.resolution_date,
    bsn.range_from,
    bsn.range_to,
    bsn.valid_until,
    coalesce((
      select max(tk.sale_number)
      from public.tickets tk
      where tk.tenant_id = v_tenant_id
        and tk.branch_id = p_branch_id
        and tk.sale_number is not null
    ), 0)::bigint as last_emitted_number,
    bsn.updated_at
  from public.branch_sale_numbering bsn
  where bsn.tenant_id = v_tenant_id
    and bsn.branch_id = p_branch_id;
end;
$$;

revoke all on function public.get_branch_sale_numbering(uuid) from public, anon;
grant execute on function public.get_branch_sale_numbering(uuid) to authenticated, service_role;

-- B. set_branch_sale_numbering
create or replace function public.set_branch_sale_numbering(
  p_branch_id uuid,
  p_prefix text,
  p_next_number bigint,
  p_padding smallint,
  p_resolution_number text default null,
  p_resolution_date date default null,
  p_range_from bigint default null,
  p_range_to bigint default null,
  p_valid_until date default null
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_last_number bigint;
  v_clean_prefix text;
begin
  -- Solo owner o admin pueden ajustar la numeración de ventas
  select r.tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id,
    array['tenant_owner', 'admin'],
    true
  ) r;

  v_clean_prefix := trim(coalesce(p_prefix, ''));
  if v_clean_prefix !~ '^[A-Za-z0-9._-]{0,10}$' then
    raise exception 'Prefijo inválido. Use hasta 10 caracteres alfanuméricos sin espacios.';
  end if;

  if p_next_number is null or p_next_number < 1 then
    raise exception 'El próximo número debe ser mayor o igual a 1.';
  end if;

  if p_padding is null or p_padding not between 1 and 12 then
    raise exception 'El relleno de ceros debe estar entre 1 y 12 dígitos.';
  end if;

  -- Validar consistencia de resolución DIAN si se especifican rangos
  if (p_range_from is not null or p_range_to is not null) and
     (p_range_from is null or p_range_to is null or p_range_from > p_range_to) then
    raise exception 'Rango de facturación inválido: el rango inicial debe ser menor o igual al final.';
  end if;

  -- Validar que next_number sea estrictamente mayor que el último número emitido
  select coalesce(max(tk.sale_number), 0)
    into v_last_number
  from public.tickets tk
  where tk.tenant_id = v_tenant_id
    and tk.branch_id = p_branch_id
    and tk.sale_number is not null;

  if p_next_number <= v_last_number then
    raise exception 'El próximo número (%s) debe ser estrictamente mayor que el último emitido (%s).',
      p_next_number, v_last_number;
  end if;

  -- Guardar configuración
  insert into public.branch_sale_numbering (
    tenant_id,
    branch_id,
    prefix,
    next_number,
    padding,
    resolution_number,
    resolution_date,
    range_from,
    range_to,
    valid_until,
    updated_at
  ) values (
    v_tenant_id,
    p_branch_id,
    v_clean_prefix,
    p_next_number,
    p_padding,
    nullif(trim(coalesce(p_resolution_number, '')), ''),
    p_resolution_date,
    p_range_from,
    p_range_to,
    p_valid_until,
    now()
  )
  on conflict (tenant_id, branch_id) do update set
    prefix = excluded.prefix,
    next_number = excluded.next_number,
    padding = excluded.padding,
    resolution_number = excluded.resolution_number,
    resolution_date = excluded.resolution_date,
    range_from = excluded.range_from,
    range_to = excluded.range_to,
    valid_until = excluded.valid_until,
    updated_at = now();
end;
$$;

revoke all on function public.set_branch_sale_numbering(uuid, text, bigint, smallint, text, date, bigint, bigint, date) from public, anon;
grant execute on function public.set_branch_sale_numbering(uuid, text, bigint, smallint, text, date, bigint, bigint, date) to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 6. Actualización de get_ticket_board_list_v2 para incluir número de venta
-- -----------------------------------------------------------------------------
drop function if exists public.get_ticket_board_list_v2(uuid, date, date, text[], text, text);

create or replace function public.get_ticket_board_list_v2(
  p_branch_id uuid,
  p_start_date date,
  p_end_date date,
  p_statuses text[] default null,
  p_bucket text default null,
  p_granularity text default null
)
returns table (
  id uuid,
  ticket_number bigint,
  ticket_code text,
  sale_number bigint,
  sale_code text,
  closed_at timestamptz,
  client_id uuid,
  client_name text,
  client_phone text,
  scheduled_at timestamptz,
  status text,
  channel text,
  service_names text,
  stylist_names text,
  total_price numeric,
  total_duration_minutes integer,
  paid_amount numeric,
  pending_balance numeric,
  payment_status text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_timezone text;
begin
  -- 1. Validar permisos de sede y obtener zona horaria configurada
  select r.tenant_id, coalesce(r.timezone, 'America/Bogota')
    into v_tenant_id, v_timezone
  from private.beautyos_resolve_branch_access(
    p_branch_id,
    array['tenant_owner', 'admin', 'assistant'],
    true
  ) r;

  -- 2. Validar parámetros
  if p_start_date is null or p_end_date is null or p_start_date > p_end_date then
    raise exception 'Rango de fechas invalido.';
  end if;

  if p_granularity is not null and p_granularity not in ('15min', '30min', 'hour', 'day') then
    raise exception 'Granularidad invalida. Valores permitidos: 15min, 30min, hour, day.';
  end if;

  if p_bucket is not null and p_bucket <> '' and p_granularity is null then
    raise exception 'Debe especificar p_granularity cuando filtra por p_bucket.';
  end if;

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
  ),
  ticket_rows as (
    select
      tk.id,
      tk.ticket_number,
      tk.ticket_code,
      tk.sale_number,
      tk.sale_code,
      tk.closed_at,
      c.id as client_id,
      coalesce(c.name, 'Cliente sin nombre') as client_name,
      coalesce(c.phone, '') as client_phone,
      tk.scheduled_at,
      tk.status,
      tk.channel,
      coalesce(ss.service_names, 'Sin servicios') as service_names,
      coalesce(ss.stylist_names, 'Sin estilista') as stylist_names,
      coalesce(ss.total_price, 0)::numeric as total_price,
      coalesce(ss.total_duration_minutes, 0)::integer as total_duration_minutes,
      coalesce(ps.paid_amount, 0)::numeric as paid_amount,
      greatest(
        coalesce(ss.total_price, 0) - coalesce(ps.paid_amount, 0),
        0
      )::numeric as pending_balance,
      case
        when coalesce(ps.paid_amount, 0) = 0 then 'sin_pago'
        when coalesce(ps.paid_amount, 0) < coalesce(ss.total_price, 0) then 'parcial'
        else 'pagado'
      end as payment_status,
      case
        when p_granularity = '15min' then
          to_char(
            date_trunc('hour', tk.scheduled_at at time zone v_timezone) +
            (floor(extract(minute from (tk.scheduled_at at time zone v_timezone)) / 15) * interval '15 minute'),
            'HH24:MI'
          )
        when p_granularity = '30min' then
          to_char(
            date_trunc('hour', tk.scheduled_at at time zone v_timezone) +
            (floor(extract(minute from (tk.scheduled_at at time zone v_timezone)) / 30) * interval '30 minute'),
            'HH24:MI'
          )
        when p_granularity = 'hour' then
          to_char(
            date_trunc('hour', tk.scheduled_at at time zone v_timezone),
            'HH24:00'
          )
        else
          to_char((tk.scheduled_at at time zone v_timezone)::date, 'YYYY-MM-DD')
      end as bucket_val
    from public.tickets tk
    left join public.clients c
      on c.tenant_id = tk.tenant_id
     and c.id = tk.client_id
     and c.active
    left join service_summary ss on ss.ticket_id = tk.id
    left join payment_summary ps on ps.ticket_id = tk.id
    where tk.tenant_id = v_tenant_id
      and tk.branch_id = p_branch_id
      and tk.scheduled_at is not null
      and (tk.scheduled_at at time zone v_timezone)::date >= p_start_date
      and (tk.scheduled_at at time zone v_timezone)::date <= p_end_date
      and (p_statuses is null or cardinality(p_statuses) = 0 or tk.status = any(p_statuses))
  )
  select
    tr.id,
    tr.ticket_number,
    tr.ticket_code,
    tr.sale_number,
    tr.sale_code,
    tr.closed_at,
    tr.client_id,
    tr.client_name,
    tr.client_phone,
    tr.scheduled_at,
    tr.status,
    tr.channel,
    tr.service_names,
    tr.stylist_names,
    tr.total_price,
    tr.total_duration_minutes,
    tr.paid_amount,
    tr.pending_balance,
    tr.payment_status
  from ticket_rows tr
  where (p_bucket is null or p_bucket = '' or tr.bucket_val = p_bucket)
  order by tr.scheduled_at asc, tr.ticket_number asc;
end;
$$;

revoke all on function public.get_ticket_board_list_v2(uuid, date, date, text[], text, text) from public, anon;
grant execute on function public.get_ticket_board_list_v2(uuid, date, date, text[], text, text) to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 7. Backfill de tickets históricos cerrados existentes
-- -----------------------------------------------------------------------------
do $$
declare
  r_branch record;
  r_ticket record;
  v_seq bigint;
begin
  for r_branch in (
    select distinct t.tenant_id, t.branch_id
    from public.tickets t
    where t.status = 'cerrado'
  ) loop
    -- Inicializar configuración para la sede
    insert into public.branch_sale_numbering (tenant_id, branch_id, prefix, next_number, padding)
    values (r_branch.tenant_id, r_branch.branch_id, 'VTA-', 1, 7)
    on conflict (tenant_id, branch_id) do nothing;

    v_seq := 1;
    for r_ticket in (
      select t.id, t.created_at, t.scheduled_at
      from public.tickets t
      where t.tenant_id = r_branch.tenant_id
        and t.branch_id = r_branch.branch_id
        and t.status = 'cerrado'
        and t.sale_number is null
      order by coalesce(t.scheduled_at, t.created_at) asc, t.created_at asc
    ) loop
      update public.tickets
         set sale_number = v_seq,
             sale_code = 'VTA-' || lpad(v_seq::text, 7, '0'),
             closed_at = coalesce(closed_at, r_ticket.scheduled_at, r_ticket.created_at)
       where id = r_ticket.id;

      v_seq := v_seq + 1;
    end loop;

    -- Ajustar next_number
    update public.branch_sale_numbering
       set next_number = (
         select coalesce(max(tk.sale_number), 0) + 1
         from public.tickets tk
         where tk.tenant_id = r_branch.tenant_id
           and tk.branch_id = r_branch.branch_id
       ),
       updated_at = now()
     where tenant_id = r_branch.tenant_id
       and branch_id = r_branch.branch_id;
  end loop;
end;
$$;

commit;
