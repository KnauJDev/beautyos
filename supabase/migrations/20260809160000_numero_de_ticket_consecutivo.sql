-- Salon y Mas - Numero de ticket consecutivo y ajustable (tarea 2.6a).
--
-- Cierra el punto 8.1 de ESPECIFICACION_AGENDA_2026-08-07.md, que era
-- bloqueante para la lista ampliada: hoy un ticket solo tiene identificador
-- interno (3f2b8c1a-9d4e-...), impresentable para una persona.
--
-- Decisiones que gobiernan este archivo:
--
-- * D-101/8.1: UN solo consecutivo POR NEGOCIO, no por sede. Asi el numero
--   dice cuantos servicios ha prestado el negocio en total. Sin prefijo de
--   sede. Los tickets que ya existen reciben numero por orden de creacion.
--
-- * D-117 (09-ago, correccion de 8.1): el consecutivo **se puede ajustar**.
--   La especificacion decia "empieza en 0000001 y no se reinicia nunca". El
--   propietario pidio poder fijarlo, para seguir un consecutivo que ya trae de
--   antes o una numeracion autorizada DIAN. Se conserva la intencion original
--   -- que nazca limpio y continuo -- como **valor por defecto**, no como
--   camisa de fuerza.
--
-- * Regla que no se negocia: **un numero emitido no se reescribe jamas**.
--   Ajustar la numeracion afecta a los tickets FUTUROS. Si un numero ya salio
--   en un documento, cambiarlo despues es exactamente lo que un contador no
--   puede permitir. Por eso hay un trigger que bloquea el UPDATE, y no solo
--   una promesa de que la aplicacion no lo hara.
--
-- * El nuevo punto de partida debe ser MAYOR que el ultimo numero emitido del
--   negocio. Es la unica forma de que "unico" siga siendo cierto despues de un
--   ajuste.
--
-- Se guardan DOS columnas a proposito:
--   ticket_number (bigint) -- ordena y garantiza la unicidad. Nunca cambia de
--                             significado aunque el prefijo cambie diez veces.
--   ticket_code   (text)   -- lo que ve la persona, ya congelado con el
--                             prefijo y los ceros del dia en que se emitio.
-- Con una sola columna de texto, cambiar el prefijo dejaria el historial sin
-- forma fiable de ordenarse; con un solo bigint, no habria donde poner un
-- prefijo DIAN.
--
-- AVISO, para que nadie se confunda leyendo esto dentro de seis meses: esto
-- NO es facturacion electronica. La numeracion autorizada real trae numero de
-- resolucion, un rango con fecha de vencimiento y reglas de agotamiento. Aqui
-- solo queda el campo listo y limpio por si termina siendo su base (tarea D4
-- del plan: consultar al contador).
--
-- El numero se asigna con un TRIGGER y no dentro de las funciones que crean
-- tickets, porque hay CUATRO caminos que insertan en public.tickets
-- (create_ticket, create_scheduled_ticket_with_service, su _v2 y
-- public_create_booking). Con un trigger, cualquier camino futuro queda
-- numerado solo; tocando las cuatro funciones, el quinto camino nace sin
-- numero y nadie se entera.

begin;

-- ---------------------------------------------------------------------------
-- 1. Como numera cada negocio.
-- ---------------------------------------------------------------------------

create table if not exists public.tenant_ticket_numbering (
  tenant_id uuid primary key
    references public.tenants(id) on delete cascade,
  prefix text not null default '',
  next_number bigint not null default 1,
  padding smallint not null default 7,
  updated_at timestamptz not null default now(),
  constraint tenant_ticket_numbering_next_number_valido
    check (next_number >= 1),
  -- Doce digitos aguantan mil millones de tickets. El limite existe para que
  -- un cero de mas no genere codigos absurdos, no porque estorbe.
  constraint tenant_ticket_numbering_padding_valido
    check (padding between 1 and 12),
  -- El prefijo es para cosas como 'FE-' o 'SETP'. Se prohiben espacios porque
  -- un codigo con espacio se rompe al copiarlo, buscarlo o imprimirlo.
  constraint tenant_ticket_numbering_prefix_valido
    check (prefix ~ '^[A-Za-z0-9._-]{0,10}$')
);

comment on table public.tenant_ticket_numbering
  is 'Como numera sus tickets cada negocio (D-117). Una fila por tenant. Solo se toca desde set_ticket_numbering; afecta a los tickets futuros, nunca a los ya emitidos.';

comment on column public.tenant_ticket_numbering.next_number
  is 'El numero que recibira el proximo ticket del negocio. Al ajustarlo debe ser mayor que el ultimo emitido.';

comment on column public.tenant_ticket_numbering.prefix
  is 'Prefijo opcional del codigo visible, para una numeracion propia o autorizada DIAN. Vacio por defecto (D-101/8.1: sin prefijo de sede).';

comment on column public.tenant_ticket_numbering.padding
  is 'Cuantos digitos lleva el numero con ceros a la izquierda. 7 por defecto, que es el 0000001 de la especificacion.';

-- La tabla no se abre a nadie: se entra por las funciones de mas abajo, que
-- son las que verifican quien eres. Mismo criterio que el resto del esquema.
alter table public.tenant_ticket_numbering enable row level security;

revoke all on table public.tenant_ticket_numbering
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Las dos columnas en tickets.
-- ---------------------------------------------------------------------------

alter table public.tickets
  add column if not exists ticket_number bigint;

alter table public.tickets
  add column if not exists ticket_code text;

comment on column public.tickets.ticket_number
  is 'Consecutivo del negocio (D-101/8.1). Unico por tenant. Se asigna al crear y NO se puede cambiar despues.';

comment on column public.tickets.ticket_code
  is 'El consecutivo como lo ve una persona, ya con prefijo y ceros. Congelado en el momento de la emision (D-117).';

-- ---------------------------------------------------------------------------
-- 3. Numerar lo que ya existe, por orden de creacion.
--
--    Va ANTES de crear el trigger que congela el numero: si no, el propio
--    relleno quedaria bloqueado por su propia regla.
-- ---------------------------------------------------------------------------

with numerados as (
  select
    tk.id,
    row_number() over (
      partition by tk.tenant_id
      order by tk.created_at, tk.id
    ) as n
  from public.tickets tk
  where tk.ticket_number is null
)
update public.tickets tk
set ticket_number = nm.n,
    ticket_code = lpad(nm.n::text, 7, '0')
from numerados nm
where tk.id = nm.id;

-- Cada negocio arranca donde quedo su historia. Los negocios sin un solo
-- ticket empiezan en 1, que es el 0000001 de la especificacion.
insert into public.tenant_ticket_numbering (tenant_id, next_number)
select
  t.id,
  coalesce(max(tk.ticket_number), 0) + 1
from public.tenants t
left join public.tickets tk
  on tk.tenant_id = t.id
group by t.id
on conflict (tenant_id) do update
  set next_number = greatest(
        excluded.next_number,
        public.tenant_ticket_numbering.next_number
      );

-- Ahora que no queda ninguno sin numero, se exige que nunca vuelva a haberlo.
alter table public.tickets
  alter column ticket_number set not null;

alter table public.tickets
  alter column ticket_code set not null;

-- Unico por negocio, no global: dos negocios distintos pueden tener cada uno
-- su ticket 0000001, y deben poder tenerlo.
create unique index if not exists tickets_tenant_number_uidx
  on public.tickets (tenant_id, ticket_number);

create unique index if not exists tickets_tenant_code_uidx
  on public.tickets (tenant_id, ticket_code);

-- ---------------------------------------------------------------------------
-- 4. Asignar el numero al crear el ticket.
-- ---------------------------------------------------------------------------

create or replace function private.beautyos_assign_ticket_number()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_number bigint;
  v_prefix text;
  v_padding smallint;
begin
  -- Un negocio creado antes de esta migracion, o recien registrado, todavia
  -- no tiene fila de numeracion. Se le crea con los valores por defecto.
  insert into public.tenant_ticket_numbering (tenant_id)
  values (new.tenant_id)
  on conflict (tenant_id) do nothing;

  -- El UPDATE bloquea la fila hasta el fin de la transaccion. Eso es lo que
  -- impide que dos recepcionistas cobrando a la vez saquen el mismo numero:
  -- la segunda espera a que la primera termine. Sin esto, la unicidad se
  -- caeria justo el dia de mas trabajo.
  update public.tenant_ticket_numbering n
  set next_number = n.next_number + 1,
      updated_at = now()
  where n.tenant_id = new.tenant_id
  returning n.next_number - 1, n.prefix, n.padding
  into v_number, v_prefix, v_padding;

  new.ticket_number := v_number;
  new.ticket_code := v_prefix || lpad(v_number::text, v_padding, '0');

  return new;
end;
$$;

comment on function private.beautyos_assign_ticket_number()
  is 'Asigna el consecutivo del negocio a cada ticket nuevo, venga del camino que venga (D-117).';

drop trigger if exists tickets_set_number on public.tickets;

create trigger tickets_set_number
  before insert on public.tickets
  for each row
  execute function private.beautyos_assign_ticket_number();

-- ---------------------------------------------------------------------------
-- 5. Un numero emitido no se reescribe. Nunca.
-- ---------------------------------------------------------------------------

create or replace function private.beautyos_freeze_ticket_number()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  if new.ticket_number is distinct from old.ticket_number
     or new.ticket_code is distinct from old.ticket_code then
    raise exception
      'El numero de un ticket ya emitido no se puede cambiar (ticket %).',
      old.ticket_code;
  end if;

  return new;
end;
$$;

comment on function private.beautyos_freeze_ticket_number()
  is 'Impide cambiar el consecutivo de un ticket ya emitido (D-117). Es una cerradura, no una recomendacion.';

drop trigger if exists tickets_freeze_number on public.tickets;

create trigger tickets_freeze_number
  before update of ticket_number, ticket_code on public.tickets
  for each row
  execute function private.beautyos_freeze_ticket_number();

-- ---------------------------------------------------------------------------
-- 6. Leer y ajustar la numeracion.
--
--    Leer: owner y admin, que son quienes ven la configuracion del negocio.
--    Ajustar: SOLO tenant_owner. Cambiar la numeracion tiene consecuencias
--    contables; no es una preferencia de quien esta en el mostrador. Mismo
--    criterio que el logo, la portada y el tema (D-109).
-- ---------------------------------------------------------------------------

create or replace function public.get_ticket_numbering()
returns table (
  prefix text,
  next_number bigint,
  padding smallint,
  last_issued_number bigint,
  last_issued_code text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_prefix text := '';
  v_next bigint := 1;
  v_padding smallint := 7;
  v_ultimo_numero bigint;
  v_ultimo_codigo text;
begin
  v_tenant_id := public.get_my_tenant_id();

  if v_tenant_id is null or not public.is_owner_or_admin() then
    raise exception 'No autorizado para ver la numeracion de tickets.';
  end if;

  -- Un negocio que aun no tiene fila responde con los valores por defecto, no
  -- con vacio: la pantalla debe poder mostrar "empieza en 0000001" antes de
  -- que nadie haya tocado nada.
  select n.prefix, n.next_number, n.padding
    into v_prefix, v_next, v_padding
  from public.tenant_ticket_numbering n
  where n.tenant_id = v_tenant_id;

  if not found then
    v_prefix := '';
    v_next := 1;
    v_padding := 7;
  end if;

  select tk.ticket_number, tk.ticket_code
    into v_ultimo_numero, v_ultimo_codigo
  from public.tickets tk
  where tk.tenant_id = v_tenant_id
  order by tk.ticket_number desc
  limit 1;

  return query
  select v_prefix, v_next, v_padding, v_ultimo_numero, v_ultimo_codigo;
end;
$$;

revoke all on function public.get_ticket_numbering()
  from public, anon, authenticated;
grant execute on function public.get_ticket_numbering()
  to authenticated;

comment on function public.get_ticket_numbering()
  is 'Como numera sus tickets el negocio y cual fue el ultimo emitido. Owner y admin.';

create or replace function public.set_ticket_numbering(
  p_next_number bigint,
  p_prefix text default '',
  p_padding smallint default 7
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_prefix text;
  v_ultimo bigint;
begin
  v_tenant_id := public.get_my_tenant_id();

  if v_tenant_id is null or public.get_my_role() <> 'tenant_owner' then
    raise exception
      'Solo el propietario del negocio puede cambiar la numeracion de tickets.';
  end if;

  v_prefix := upper(trim(coalesce(p_prefix, '')));

  if v_prefix !~ '^[A-Za-z0-9._-]{0,10}$' then
    raise exception
      'El prefijo solo admite letras, numeros, punto, guion y guion bajo, hasta 10 caracteres.';
  end if;

  if p_padding is null or p_padding not between 1 and 12 then
    raise exception 'La cantidad de digitos debe estar entre 1 y 12.';
  end if;

  if p_next_number is null or p_next_number < 1 then
    raise exception 'El proximo numero debe ser 1 o mayor.';
  end if;

  -- La regla que sostiene todo lo demas: hacia atras no se va. Si se
  -- permitiera, el siguiente ticket chocaria con uno ya emitido -- y el
  -- choque saldria en la cara de la recepcionista a mitad de un cobro.
  select max(tk.ticket_number)
    into v_ultimo
  from public.tickets tk
  where tk.tenant_id = v_tenant_id;

  if v_ultimo is not null and p_next_number <= v_ultimo then
    raise exception
      'El proximo numero debe ser mayor que el ultimo emitido (%). Un numero que ya salio no se puede repetir.',
      v_ultimo;
  end if;

  insert into public.tenant_ticket_numbering (
    tenant_id, prefix, next_number, padding, updated_at
  )
  values (v_tenant_id, v_prefix, p_next_number, p_padding, now())
  on conflict (tenant_id) do update
    set prefix = excluded.prefix,
        next_number = excluded.next_number,
        padding = excluded.padding,
        updated_at = now();
end;
$$;

revoke all on function public.set_ticket_numbering(bigint, text, smallint)
  from public, anon, authenticated;
grant execute on function public.set_ticket_numbering(bigint, text, smallint)
  to authenticated;

comment on function public.set_ticket_numbering(bigint, text, smallint)
  is 'Ajusta la numeracion de tickets del negocio (D-117). Exclusivo de tenant_owner. Solo afecta a los tickets futuros: lo ya emitido es inmutable.';

-- ---------------------------------------------------------------------------
-- 7. Que el numero se vea.
--
--    DROP requerido: create or replace no permite agregar columnas a
--    RETURNS TABLE. La autorizacion se copia tal cual de D-095: se extiende,
--    no se reescribe.
-- ---------------------------------------------------------------------------

drop function if exists public.get_tickets_summary_v2(uuid);

create or replace function public.get_tickets_summary_v2(
  p_branch_id uuid
)
returns table (
  id uuid,
  ticket_code text,
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
    tk.ticket_code,
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

revoke all on function public.get_tickets_summary_v2(uuid)
  from public, anon, authenticated;
grant execute on function public.get_tickets_summary_v2(uuid)
  to authenticated;

comment on function public.get_tickets_summary_v2(uuid)
  is 'Resumen de tickets de la sede, con su consecutivo visible (D-117). Owner, admin y asistente (D-094).';

commit;
