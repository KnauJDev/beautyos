-- ==============================================================================
-- Cuándo vuelve cada clienta. (Paso 9.63, D-323)
-- ==============================================================================
--
-- QUÉ PASA
--
-- El 08-oct David (Inspirant) le explicó al propietario que varias clientas se
-- hacen el mismo servicio pero no vuelven con la misma frecuencia. D-314 dio a
-- cada SERVICIO su tiempo de volver (y uno del salón, 45). Ahora cada CLIENTA
-- puede tener el suyo, por servicio. Decidido por el propietario (prototipo
-- https://claude.ai/artifact/N48aApd2qmN17Fxc5kHTne):
--   * al terminar un servicio se pregunta en cuántos días invitarla a volver,
--     ya lleno: su número si ya tiene; si no, el del servicio; si no, el del
--     salón. Lo que se pone se recuerda;
--   * lo ponen el dueño, recepción Y la estilista (solo en sus servicios);
--   * en la ficha de la clienta se ve y se cambia ("Usar el del servicio" le
--     quita su número propio);
--   * cada servicio trae un interruptor "Invitar a volver": apagado, ese
--     servicio no la invita ESTA VEZ y su número no se borra. Cuando vuelva a
--     hacérselo, la marca deja de valer sola y se pregunta otra vez.
--
-- QUÉ HACE ESTA MIGRACIÓN
--
--   1. La tabla `client_service_return_days`: una fila por clienta y
--      servicio, con su número (vacío = el del servicio) y la marca de "esta
--      vez no" (`skip_visit_at`, la hora de la cita en que se dijo). Con el
--      patrón de `client_return_invitations` que mostró la lectura viva:
--      seguridad activada y NINGÚN permiso directo; solo se toca con
--      funciones SECURITY DEFINER.
--   2. Cuatro funciones nuevas:
--      - `get_return_days_for_ticket`: lo que se pregunta al cerrar (dueño,
--        admin, recepción; la estilista solo ve sus servicios).
--      - `set_client_return_after_close`: guarda la respuesta de un servicio
--        ya terminado. La estilista, solo en los suyos (la misma regla de
--        `change_ticket_service_status_v2`).
--      - `get_client_return_days` y `set_client_return_days`: la ficha de la
--        clienta (dueño, admin, recepción; la estilista no ve la base de
--        clientas, D-266).
--   3. `get_return_invitations` ("Para invitar hoy", la campana y el filtro de
--      Clientes) usa el número de la clienta y salta los "esta vez no".
--      **Generada por un script desde su texto vivo** (lectura
--      `intervenciones/extraer_cuando_vuelve_9_63.sql`, 08-oct) con solo tres
--      cambios comprobados: el número de la clienta primero en el
--      `coalesce`, el `left join` a la tabla nueva y la condición de la
--      marca. Devuelve lo mismo que antes, así que no hace falta DROP y
--      conserva sus permisos.
--
-- Las funciones que cierran una cita y terminan un servicio NO se tocan: la
-- app guarda la respuesta después, con la función nueva.
--
-- Lo prueba el CONTROL 248.
-- ==============================================================================

set client_encoding = 'UTF8';

begin;

-- ---------------------------------------------------------------------------
-- 1. La tabla
-- ---------------------------------------------------------------------------
create table public.client_service_return_days (
  tenant_id uuid not null
    references public.tenants(id) on update cascade on delete restrict,
  client_id uuid not null,
  service_id uuid not null
    references public.services(id) on update cascade on delete restrict,
  return_days integer,
  skip_visit_at timestamptz,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  constraint client_service_return_days_pkey
    primary key (tenant_id, client_id, service_id),
  constraint client_service_return_days_client_fkey
    foreign key (tenant_id, client_id)
    references public.clients(tenant_id, id) on update cascade on delete restrict,
  constraint client_service_return_days_check
    check (return_days is null or return_days between 1 and 365)
);

alter table public.client_service_return_days enable row level security;
revoke all on table public.client_service_return_days from public, anon, authenticated;

comment on table public.client_service_return_days is
  'Paso 9.63: cada cuanto vuelve cada clienta a cada servicio (vacio = el del servicio) y la marca de "esta vez no se invita". Solo se toca con sus funciones.';

-- ---------------------------------------------------------------------------
-- 2. Lo que se pregunta al cerrar
-- ---------------------------------------------------------------------------
create or replace function public.get_return_days_for_ticket(
  p_branch_id uuid,
  p_ticket_id uuid
)
returns table(
  ticket_service_id uuid,
  service_id uuid,
  service_name text,
  service_status text,
  client_days integer,
  service_days integer,
  default_days integer
)
language plpgsql
stable
security definer
set search_path to 'pg_catalog'
as $$
#variable_conflict use_column
declare
  v_tenant_id uuid;
  v_role text;
  v_stylist_id uuid;
  v_client_id uuid;
  v_default integer;
begin
  select c.tenant_id, c.role, c.stylist_id
    into v_tenant_id, v_role, v_stylist_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner','admin','assistant','stylist'], true
  ) c;

  select t.client_id into v_client_id
  from public.tickets t
  where t.id = p_ticket_id
    and t.tenant_id = v_tenant_id
    and t.branch_id = p_branch_id;

  if not found then
    raise exception 'El recurso no esta disponible para esta sede.';
  end if;

  select t.return_default_days into v_default
  from public.tenants t
  where t.id = v_tenant_id;

  return query
  select ts.id, ts.service_id, s.name, ts.status,
         cr.return_days, s.return_after_days, v_default
  from public.ticket_services ts
  join public.services s
    on s.id = ts.service_id and s.tenant_id = v_tenant_id
  left join public.client_service_return_days cr
    on cr.tenant_id = v_tenant_id
   and cr.client_id = v_client_id
   and cr.service_id = ts.service_id
  where ts.ticket_id = p_ticket_id
    and ts.tenant_id = v_tenant_id
    and ts.branch_id = p_branch_id
    and ts.status <> 'cancelado'
    and (v_role is distinct from 'stylist' or ts.stylist_id = v_stylist_id)
  order by ts.created_at, s.name, ts.id;
end;
$$;

create or replace function public.set_client_return_after_close(
  p_branch_id uuid,
  p_ticket_service_id uuid,
  p_days integer,
  p_invitar boolean
)
returns void
language plpgsql
security definer
set search_path to 'pg_catalog'
as $$
declare
  v_tenant_id uuid;
  v_role text;
  v_stylist_id uuid;
  v_assigned_stylist uuid;
  v_service_id uuid;
  v_status text;
  v_client_id uuid;
  v_visita timestamptz;
begin
  select c.tenant_id, c.role, c.stylist_id
    into v_tenant_id, v_role, v_stylist_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner','admin','assistant','stylist'], true
  ) c;

  select ts.stylist_id, ts.service_id, ts.status, t.client_id, t.scheduled_at
    into v_assigned_stylist, v_service_id, v_status, v_client_id, v_visita
  from public.ticket_services ts
  join public.tickets t
    on t.id = ts.ticket_id
   and t.tenant_id = ts.tenant_id
  where ts.id = p_ticket_service_id
    and ts.tenant_id = v_tenant_id
    and ts.branch_id = p_branch_id;

  if not found or (v_role = 'stylist' and v_assigned_stylist is distinct from v_stylist_id) then
    raise exception 'El recurso no esta disponible para esta sede.';
  end if;

  if v_status <> 'finalizado' then
    raise exception 'Primero hay que terminar el servicio.';
  end if;

  if coalesce(p_invitar, true) then
    if p_days is not null and (p_days < 1 or p_days > 365) then
      raise exception 'El tiempo de volver va de 1 a 365 días.';
    end if;

    -- Su número (vacío = el del servicio). Invitar borra un "esta vez no".
    insert into public.client_service_return_days (
      tenant_id, client_id, service_id, return_days, skip_visit_at, updated_by
    ) values (
      v_tenant_id, v_client_id, v_service_id, p_days, null, auth.uid()
    )
    on conflict (tenant_id, client_id, service_id) do update
      set return_days = excluded.return_days,
          skip_visit_at = null,
          updated_at = now(),
          updated_by = excluded.updated_by;
  else
    -- "Esta vez no": la marca es la hora de ESTA cita. Su número no se toca;
    -- cuando vuelva a hacerse el servicio, la cita nueva es posterior y la
    -- marca deja de valer sola.
    insert into public.client_service_return_days (
      tenant_id, client_id, service_id, return_days, skip_visit_at, updated_by
    ) values (
      v_tenant_id, v_client_id, v_service_id, null, coalesce(v_visita, now()), auth.uid()
    )
    on conflict (tenant_id, client_id, service_id) do update
      set skip_visit_at = excluded.skip_visit_at,
          updated_at = now(),
          updated_by = excluded.updated_by;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. La ficha de la clienta (dueño, admin, recepción)
-- ---------------------------------------------------------------------------
create or replace function public.get_client_return_days(
  p_branch_id uuid,
  p_client_id uuid
)
returns table(
  service_id uuid,
  service_name text,
  client_days integer,
  service_days integer,
  default_days integer,
  last_done_at timestamptz,
  skipped boolean
)
language plpgsql
stable
security definer
set search_path to 'pg_catalog'
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

  if not exists (
    select 1 from public.clients c
    where c.id = p_client_id and c.tenant_id = v_tenant_id
  ) then
    raise exception 'La clienta no existe o pertenece a otro negocio.';
  end if;

  select t.return_default_days into v_default
  from public.tenants t
  where t.id = v_tenant_id;

  return query
  with hechos as (
    select ts.service_id as sid, max(t.scheduled_at) as ultima
    from public.tickets t
    join public.ticket_services ts
      on ts.ticket_id = t.id
     and ts.tenant_id = t.tenant_id
    where t.tenant_id = v_tenant_id
      and t.client_id = p_client_id
      and t.status in ('finalizado', 'cerrado')
      and ts.status = 'finalizado'
      and t.scheduled_at is not null
    group by ts.service_id
  ),
  servicios as (
    select h.sid from hechos h
    union
    select cr.service_id from public.client_service_return_days cr
    where cr.tenant_id = v_tenant_id and cr.client_id = p_client_id
  )
  select s.id, s.name, cr.return_days, s.return_after_days, v_default, h.ultima,
         coalesce(cr.skip_visit_at >= h.ultima, false)
  from servicios x
  join public.services s
    on s.id = x.sid
   and s.tenant_id = v_tenant_id
   and s.active
  left join hechos h
    on h.sid = x.sid
  left join public.client_service_return_days cr
    on cr.tenant_id = v_tenant_id
   and cr.client_id = p_client_id
   and cr.service_id = x.sid
  order by h.ultima desc nulls last, lower(s.name);
end;
$$;

create or replace function public.set_client_return_days(
  p_branch_id uuid,
  p_client_id uuid,
  p_service_id uuid,
  p_days integer
)
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
    p_branch_id, array['tenant_owner', 'admin', 'assistant'], true
  ) r;

  if p_days is not null and (p_days < 1 or p_days > 365) then
    raise exception 'El tiempo de volver va de 1 a 365 días. Déjalo vacío para usar el del servicio.';
  end if;

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

  -- Vacío = "Usar el del servicio". La marca de "esta vez no" no se toca.
  insert into public.client_service_return_days (
    tenant_id, client_id, service_id, return_days, updated_by
  ) values (
    v_tenant_id, p_client_id, p_service_id, p_days, auth.uid()
  )
  on conflict (tenant_id, client_id, service_id) do update
    set return_days = excluded.return_days,
        updated_at = now(),
        updated_by = excluded.updated_by;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. "Para invitar hoy" con el número de cada clienta (texto vivo + 3 cambios)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_return_invitations(p_branch_id uuid)
 RETURNS TABLE(client_id uuid, client_name text, client_phone text, service_id uuid, service_name text, last_done_at timestamp with time zone, return_days integer, due_at timestamp with time zone, last_invited_at timestamp with time zone, times_invited integer, estado text, toca_hoy boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
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
      coalesce(cr.return_days, s.return_after_days, v_default) as dias,
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
    left join public.client_service_return_days cr
      on cr.tenant_id = v_tenant_id
     and cr.client_id = h.client_id
     and cr.service_id = h.service_id
    where not exists (
      select 1 from proximas p
      where p.client_id = h.client_id
        and p.service_id = h.service_id
    )
      and (cr.skip_visit_at is null or cr.skip_visit_at < h.last_done_at)
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
$function$;

-- ---------------------------------------------------------------------------
-- 5. Permisos: solo con sesión, como el resto de funciones del salón (D-314)
-- ---------------------------------------------------------------------------
revoke all on function public.get_return_days_for_ticket(uuid, uuid) from public, anon;
revoke all on function public.set_client_return_after_close(uuid, uuid, integer, boolean) from public, anon;
revoke all on function public.get_client_return_days(uuid, uuid) from public, anon;
revoke all on function public.set_client_return_days(uuid, uuid, uuid, integer) from public, anon;

grant execute on function public.get_return_days_for_ticket(uuid, uuid) to authenticated;
grant execute on function public.set_client_return_after_close(uuid, uuid, integer, boolean) to authenticated;
grant execute on function public.get_client_return_days(uuid, uuid) to authenticated;
grant execute on function public.set_client_return_days(uuid, uuid, uuid, integer) to authenticated;

commit;
