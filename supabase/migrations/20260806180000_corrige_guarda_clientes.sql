-- Correccion urgente de D-094: el propietario perdio el acceso a Clientes.
--
-- Al sumar al asistente se reemplazo la guarda `is_owner_or_admin()` por
-- `get_my_role() not in (...)`, dando por hecho que eran equivalentes. No lo
-- son:
--
--   is_owner_or_admin()  ->  exists(... role in ('owner','admin'))  mira TODOS
--                            los perfiles activos del usuario.
--   get_my_role()        ->  select up.role ... limit 1  SIN order by, o sea
--                            devuelve UN perfil al azar.
--
-- Un usuario con mas de un perfil activo -- el propietario que prueba varios
-- negocios, por ejemplo -- podia recibir un rol distinto al que esperaba y
-- quedar fuera de su propia pantalla de Clientes.
--
-- Regla que deja esto: para sumar un rol se EXTIENDE la comprobacion que ya
-- existe, nunca se reescribe. Aqui se conserva `is_owner_or_admin()` intacta y
-- se le suma el asistente con la misma semantica de exists.

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

  -- Se EXTIENDE la comprobacion original, no se reemplaza (D-095). Usar
  -- get_my_role() fue un error: devuelve UN perfil al azar (select ... limit 1
  -- sin orden), mientras is_owner_or_admin() usa exists y mira TODOS. Quien
  -- tiene mas de un perfil activo -- el propietario, sin ir mas lejos -- podia
  -- quedar fuera de su propio negocio. El asistente se suma con la misma
  -- semantica de exists, sin tocar a nadie mas.
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

  -- Se EXTIENDE la comprobacion original, no se reemplaza (D-095). Usar
  -- get_my_role() fue un error: devuelve UN perfil al azar (select ... limit 1
  -- sin orden), mientras is_owner_or_admin() usa exists y mira TODOS. Quien
  -- tiene mas de un perfil activo -- el propietario, sin ir mas lejos -- podia
  -- quedar fuera de su propio negocio. El asistente se suma con la misma
  -- semantica de exists, sin tocar a nadie mas.
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
