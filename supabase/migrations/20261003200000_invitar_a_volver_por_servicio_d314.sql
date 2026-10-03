-- ==============================================================================
-- D-314, paso 4B del plan de David: INVITAR A VOLVER, POR SERVICIO.
-- ==============================================================================
--
-- LO QUE DECIDIÓ EL PROPIETARIO (03-oct)
--
--   * Cada servicio tiene su propio TIEMPO DE VOLVER: un arreglo de uñas tiene
--     un mantenimiento, un tinte otro. Si un servicio no lo tiene, manda el
--     del salón, 45 días por defecto (la regla de "En riesgo" de hoy), que
--     cada salón puede cambiar.
--   * Cada servicio que se hizo una clienta es un RECORDATORIO APARTE:
--     "¿qué pasaría si invitamos una clienta que se hace un rubber en las uñas
--     y un tinte en el cabello? El rubber se le envía invitación a los 20 días
--     y entonces se pierde el recordatorio del tinte a los 2 o 3 meses". Se
--     elige por cuál servicio invitar; uno no borra el otro.
--   * Cada invitación se GUARDA. La invitada que no volvió queda aparte
--     ("invitadas que no volvieron"), con su última invitación a la vista, y
--     reaparece cuando pasa otra vez el tiempo del servicio: el salón decide.
--   * La lista sale arriba de la Agenda y como filtro en Clientes.
--
-- QUÉ HACE ESTA MIGRACIÓN: SOLO AGREGA
--
-- La lectura viva (`intervenciones/extraer_invitar_a_volver_4b.sql`) mostró
-- dónde va cada cosa, y que no hace falta reescribir nada de lo que funciona:
--   1. `services.return_after_days` (vacío = el del salón) y
--      `tenants.return_default_days` (45). Las funciones de servicios y de
--      ajustes que ya existen NO se tocan: estas se leen y se cambian con
--      funciones nuevas.
--   2. La tabla `client_return_invitations`, con el mismo patrón que la lectura
--      encontró en `clients` y `stylist_time_off`: seguridad activada, NINGÚN
--      permiso directo para `anon` ni `authenticated`, y solo se toca con
--      funciones SECURITY DEFINER.
--   3. Seis funciones nuevas. Leer y cambiar los tiempos: dueño y
--      administrador (como `update_service`). La lista y registrar una
--      invitación: dueño, administrador y recepción. **La estilista no**: no
--      ve la base de clientas del salón (D-266).
--
-- CÓMO SE CUENTA "SE HIZO EL SERVICIO": una cita `finalizado` o `cerrado` de
-- esa sede con ese servicio `finalizado` (lo mismo que cuenta las visitas en
-- Clientes, y lo que es "Cerrado" en la agenda de tres estados, D-312). Si la
-- clienta ya tiene una cita próxima con ese servicio, no se le sugiere.
--
-- Lo prueba el **control 242**.
-- ==============================================================================

set client_encoding = 'UTF8';

begin;

-- ---------------------------------------------------------------------------
-- 1. Los tiempos de volver
-- ---------------------------------------------------------------------------
alter table public.services
  add column return_after_days integer;
alter table public.services
  add constraint services_return_after_days_check
  check (return_after_days is null or return_after_days between 1 and 365);

alter table public.tenants
  add column return_default_days integer not null default 45;
alter table public.tenants
  add constraint tenants_return_default_days_check
  check (return_default_days between 1 and 365);

-- ---------------------------------------------------------------------------
-- 2. El registro de invitaciones
-- ---------------------------------------------------------------------------
create table public.client_return_invitations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null
    references public.tenants(id) on update cascade on delete restrict,
  branch_id uuid not null,
  client_id uuid not null,
  service_id uuid not null
    references public.services(id) on update cascade on delete restrict,
  invited_at timestamptz not null default now(),
  invited_by uuid,
  constraint client_return_invitations_branch_fkey
    foreign key (tenant_id, branch_id)
    references public.branches(tenant_id, id) on update cascade on delete restrict,
  constraint client_return_invitations_client_fkey
    foreign key (tenant_id, client_id)
    references public.clients(tenant_id, id) on update cascade on delete restrict
);

create index client_return_invitations_lookup_idx
  on public.client_return_invitations (tenant_id, client_id, service_id, invited_at desc);

alter table public.client_return_invitations enable row level security;
revoke all on table public.client_return_invitations from public, anon, authenticated;

comment on table public.client_return_invitations is
  'D-314: cada invitacion a volver, por clienta y servicio. Solo se toca con las funciones de invitar a volver.';

-- ---------------------------------------------------------------------------
-- 3. Leer y cambiar los tiempos (dueño y administrador)
-- ---------------------------------------------------------------------------
create or replace function public.get_return_days(p_branch_id uuid)
returns table(service_id uuid, return_after_days integer, default_days integer)
language plpgsql
stable
security definer
set search_path = pg_catalog
as $$
#variable_conflict use_column
declare
  v_tenant_id uuid;
begin
  select r.tenant_id into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner', 'admin'], true
  ) r;

  return query
  select s.id, s.return_after_days, t.return_default_days
  from public.services s
  join public.tenants t on t.id = s.tenant_id
  where s.tenant_id = v_tenant_id
  order by lower(s.name);
end;
$$;

create or replace function public.set_service_return_days(
  p_branch_id uuid,
  p_service_id uuid,
  p_days integer
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select r.tenant_id into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner', 'admin'], true
  ) r;

  if p_days is not null and (p_days < 1 or p_days > 365) then
    raise exception 'El tiempo de volver va de 1 a 365 días. Déjalo vacío para usar el del salón.';
  end if;

  update public.services
     set return_after_days = p_days
   where id = p_service_id
     and tenant_id = v_tenant_id;

  if not found then
    raise exception 'El servicio no existe o pertenece a otro negocio.';
  end if;
end;
$$;

create or replace function public.set_return_default_days(
  p_branch_id uuid,
  p_days integer
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select r.tenant_id into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner', 'admin'], true
  ) r;

  if p_days is null or p_days < 1 or p_days > 365 then
    raise exception 'El tiempo de volver del salón va de 1 a 365 días.';
  end if;

  update public.tenants
     set return_default_days = p_days
   where id = v_tenant_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. La lista para invitar, por clienta y servicio (dueño, admin, recepción)
-- ---------------------------------------------------------------------------
-- Devuelve:
--   * las que TOCA invitar por primera vez (pasó su tiempo desde que se hizo
--     el servicio, y no hay invitación posterior): estado 'por_invitar';
--   * TODAS las invitadas que no han vuelto a hacerse ese servicio: estado
--     'invitada_sin_volver', con la última invitación y cuántas van. Para
--     esas, `toca_hoy` dice si ya pasó otra vez el tiempo del servicio.
-- No devuelve a quien ya tiene una cita próxima con ese servicio.
create or replace function public.get_return_invitations(p_branch_id uuid)
returns table(
  client_id uuid,
  client_name text,
  client_phone text,
  service_id uuid,
  service_name text,
  last_done_at timestamptz,
  return_days integer,
  due_at timestamptz,
  last_invited_at timestamptz,
  times_invited integer,
  estado text,
  toca_hoy boolean
)
language plpgsql
stable
security definer
set search_path = pg_catalog
as $$
#variable_conflict use_column
declare
  v_tenant_id uuid;
  v_default integer;
begin
  select r.tenant_id into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner', 'admin', 'assistant'], true
  ) r;

  select t.return_default_days into v_default
  from public.tenants t
  where t.id = v_tenant_id;

  return query
  with hechos as (
    select t.client_id, ts.service_id, max(t.scheduled_at) as last_done_at
    from public.tickets t
    join public.ticket_services ts
      on ts.ticket_id = t.id
     and ts.tenant_id = t.tenant_id
    where t.tenant_id = v_tenant_id
      and t.branch_id = p_branch_id
      and t.status in ('finalizado', 'cerrado')
      and ts.status = 'finalizado'
      and t.scheduled_at is not null
    group by t.client_id, ts.service_id
  ),
  proximas as (
    select distinct t.client_id, ts.service_id
    from public.tickets t
    join public.ticket_services ts
      on ts.ticket_id = t.id
     and ts.tenant_id = t.tenant_id
    where t.tenant_id = v_tenant_id
      and t.scheduled_at > now()
      and t.status in ('solicitado', 'cotizado', 'apartado', 'confirmado', 'en_espera', 'en_proceso')
      and ts.status in ('pendiente', 'en_proceso')
  ),
  invitaciones as (
    select i.client_id, i.service_id,
           max(i.invited_at) as last_invited_at,
           count(*)::integer as veces
    from public.client_return_invitations i
    join hechos h
      on h.client_id = i.client_id
     and h.service_id = i.service_id
     and i.invited_at > h.last_done_at
    where i.tenant_id = v_tenant_id
    group by i.client_id, i.service_id
  ),
  base as (
    select
      c.id as client_id,
      c.name as client_name,
      c.phone as client_phone,
      s.id as service_id,
      s.name as service_name,
      h.last_done_at,
      coalesce(s.return_after_days, v_default) as dias,
      inv.last_invited_at,
      coalesce(inv.veces, 0) as veces
    from hechos h
    join public.clients c
      on c.id = h.client_id
     and c.tenant_id = v_tenant_id
     and c.active
    join public.services s
      on s.id = h.service_id
     and s.tenant_id = v_tenant_id
     and s.active
    left join invitaciones inv
      on inv.client_id = h.client_id
     and inv.service_id = h.service_id
    where not exists (
      select 1 from proximas p
      where p.client_id = h.client_id
        and p.service_id = h.service_id
    )
  )
  select
    b.client_id,
    b.client_name,
    b.client_phone,
    b.service_id,
    b.service_name,
    b.last_done_at,
    b.dias,
    b.last_done_at + make_interval(days => b.dias),
    b.last_invited_at,
    b.veces,
    case when b.last_invited_at is null then 'por_invitar' else 'invitada_sin_volver' end,
    case
      when b.last_invited_at is null then now() >= b.last_done_at + make_interval(days => b.dias)
      else now() >= b.last_invited_at + make_interval(days => b.dias)
    end
  from base b
  where b.last_invited_at is not null
     or now() >= b.last_done_at + make_interval(days => b.dias)
  order by b.last_done_at + make_interval(days => b.dias), b.client_name, b.service_name;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Registrar una invitación (dueño, admin, recepción)
-- ---------------------------------------------------------------------------
create or replace function public.register_return_invitation(
  p_branch_id uuid,
  p_client_id uuid,
  p_service_id uuid
)
returns timestamptz
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_invited_at timestamptz;
begin
  select r.tenant_id into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner', 'admin', 'assistant'], true
  ) r;

  if not exists (
    select 1 from public.clients c
    where c.id = p_client_id and c.tenant_id = v_tenant_id
  ) then
    raise exception 'La clienta no existe o pertenece a otro negocio.';
  end if;

  if not exists (
    select 1 from public.services s
    where s.id = p_service_id and s.tenant_id = v_tenant_id
  ) then
    raise exception 'El servicio no existe o pertenece a otro negocio.';
  end if;

  insert into public.client_return_invitations (
    tenant_id, branch_id, client_id, service_id, invited_by
  ) values (
    v_tenant_id, p_branch_id, p_client_id, p_service_id, auth.uid()
  )
  returning invited_at into v_invited_at;

  return v_invited_at;
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. Permisos: solo con sesión, como el resto de funciones del salón
-- ---------------------------------------------------------------------------
revoke all on function public.get_return_days(uuid) from public, anon;
revoke all on function public.set_service_return_days(uuid, uuid, integer) from public, anon;
revoke all on function public.set_return_default_days(uuid, integer) from public, anon;
revoke all on function public.get_return_invitations(uuid) from public, anon;
revoke all on function public.register_return_invitation(uuid, uuid, uuid) from public, anon;

grant execute on function public.get_return_days(uuid) to authenticated;
grant execute on function public.set_service_return_days(uuid, uuid, integer) to authenticated;
grant execute on function public.set_return_default_days(uuid, integer) to authenticated;
grant execute on function public.get_return_invitations(uuid) to authenticated;
grant execute on function public.register_return_invitation(uuid, uuid, uuid) to authenticated;

commit;
