-- BeautyOS / Salón y Más — Onboarding guiado "Primeros pasos" (paso 8.8, D-186)
--
-- POR QUÉ EXISTE ESTE ARCHIVO
--
-- El "broche de oro" de la Fase 8, y el único punto en el que coincidieron las
-- cuatro revisiones de la auditoría del 01-sep: el salón nuevo entra por primera
-- vez y aterriza en un Dashboard vacío, sin saber si lo primero es crear los
-- servicios, el equipo o el horario. El benchmarking contra AgendaPro ya lo
-- había marcado como prioridad alta el 28-jul: ellos muestran un panel
-- "Primeros pasos X/6" con un botón por tarea.
--
-- Hoy existe `_DiaCero` en el Dashboard, pero es **texto**: enumera tres cosas
-- que hacer, no sabe cuáles están hechas y no lleva a ninguna parte. Esta
-- migración pone debajo lo que le falta: **saber, de verdad, qué está hecho.**
--
-- LOS CUATRO PASOS, Y POR QUÉ ESOS
--
-- Los cuatro llevan al bucle central del producto — que el salón cobre una cita
-- — que es la métrica que la revisión de producto propuso como estrella:
--
--   1. Servicios      — sin catálogo no se puede agendar nada.
--   2. Equipo         — sin estilista tampoco.
--   3. Horario        — sin horario no hay huecos disponibles que ofrecer.
--   4. Primera cita   — el bucle cerrado.
--
-- **El portafolio se deja fuera a propósito**, aunque el paso 8.8 lo mencionaba:
-- desde D-184 las fotos son de plan Profesional, así que a un salón en Básico se
-- le estaría pidiendo como "primer paso" algo que su plan no le deja hacer.
--
-- POR QUÉ SE MIRAN LOS SERVICIOS Y EL EQUIPO POR SEDE, NO POR NEGOCIO
--
-- Porque lo que se está midiendo es si el salón **puede agendar en esta sede**,
-- y para eso no basta con que el servicio exista en el catálogo del negocio:
-- tiene que estar activo en la sede (`branch_services` / `branch_stylists`).
-- Es el mismo criterio de `20260723175921`.
--
-- El horario, en cambio, se mira por negocio, porque así lo mira
-- `get_available_appointment_slots` desde el principio (`business_hours` por
-- `tenant_id`). Si algún día el horario pasa a ser por sede, este es uno de los
-- sitios que hay que cambiar.

begin;

-- ---------------------------------------------------------------------------
-- 1. Poder decir "ya lo vi, no me lo muestres más"
-- ---------------------------------------------------------------------------
--
-- Va en `tenants` y no en el perfil de la persona: la lista es del negocio, no
-- de quien la mira. Si el dueño la termina, el administrador tampoco tiene que
-- volver a verla.

alter table public.tenants
  add column if not exists onboarding_dismissed_at timestamptz;

comment on column public.tenants.onboarding_dismissed_at is
  'Cuando el negocio dio por vista la lista de Primeros pasos (paso 8.8, D-186). Null = sigue mostrandose.';

-- ---------------------------------------------------------------------------
-- 2. Qué está hecho y qué falta
-- ---------------------------------------------------------------------------

create or replace function public.get_onboarding_progress(p_branch_id uuid)
returns table (
  tiene_servicios boolean,
  tiene_equipo boolean,
  tiene_horario boolean,
  tiene_primera_cita boolean,
  pasos_completos integer,
  pasos_totales integer,
  descartado boolean
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_tenant_id uuid;
  v_servicios boolean;
  v_equipo boolean;
  v_horario boolean;
  v_cita boolean;
begin
  v_tenant_id := public.get_my_tenant_id();

  if v_tenant_id is null then
    raise exception 'No existe una membresia activa para este usuario.';
  end if;

  if not public.is_owner_or_admin() then
    raise exception 'No autorizado. Solo owner o admin ve los primeros pasos del negocio.';
  end if;

  -- La sede tiene que ser de este negocio. Sin esto, un owner podria preguntar
  -- por la sede de otro salon (misma clase de agujero que TL-01).
  if p_branch_id is null or not exists (
    select 1 from public.branches b
    where b.id = p_branch_id and b.tenant_id = v_tenant_id
  ) then
    raise exception 'La sede indicada no pertenece a este negocio.';
  end if;

  select exists (
    select 1
    from public.services s
    join public.branch_services bs
      on bs.tenant_id = v_tenant_id
     and bs.branch_id = p_branch_id
     and bs.service_id = s.id
    where s.tenant_id = v_tenant_id
      and s.active
      and bs.active
  ) into v_servicios;

  select exists (
    select 1
    from public.stylists st
    join public.branch_stylists bst
      on bst.tenant_id = v_tenant_id
     and bst.branch_id = p_branch_id
     and bst.stylist_id = st.id
    where st.tenant_id = v_tenant_id
      and st.active
      and bst.active
  ) into v_equipo;

  -- Por negocio, igual que `get_available_appointment_slots` (ver cabecera).
  select exists (
    select 1
    from public.business_hours bh
    where bh.tenant_id = v_tenant_id
      and bh.active
      and bh.is_open
  ) into v_horario;

  select exists (
    select 1
    from public.tickets t
    where t.branch_id = p_branch_id
  ) into v_cita;

  return query
  select
    v_servicios,
    v_equipo,
    v_horario,
    v_cita,
    (v_servicios::int + v_equipo::int + v_horario::int + v_cita::int),
    4,
    exists (
      select 1 from public.tenants t
      where t.id = v_tenant_id
        and t.onboarding_dismissed_at is not null
    );
end;
$$;

comment on function public.get_onboarding_progress(uuid) is
  'Que lleva hecho un salon nuevo de los cuatro Primeros pasos: servicios, equipo, horario y primera cita '
  '(paso 8.8, D-186). Servicios y equipo se miran POR SEDE, el horario por negocio. NO ELIMINAR.';

-- ---------------------------------------------------------------------------
-- 3. Darla por vista
-- ---------------------------------------------------------------------------

create or replace function public.dismiss_onboarding()
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_tenant_id uuid;
begin
  v_tenant_id := public.get_my_tenant_id();

  if v_tenant_id is null then
    raise exception 'No existe una membresia activa para este usuario.';
  end if;

  if not public.is_owner_or_admin() then
    raise exception 'No autorizado. Solo owner o admin puede ocultar los primeros pasos.';
  end if;

  update public.tenants
  set onboarding_dismissed_at = now()
  where id = v_tenant_id
    and onboarding_dismissed_at is null;
end;
$$;

comment on function public.dismiss_onboarding() is
  'Marca la lista de Primeros pasos como vista para todo el negocio (paso 8.8, D-186). Idempotente: si ya '
  'estaba descartada no vuelve a mover la fecha. NO ELIMINAR.';

-- ---------------------------------------------------------------------------
-- 4. Permisos
-- ---------------------------------------------------------------------------

revoke all on function public.get_onboarding_progress(uuid) from public, anon;
grant execute on function public.get_onboarding_progress(uuid) to authenticated;

revoke all on function public.dismiss_onboarding() from public, anon;
grant execute on function public.dismiss_onboarding() to authenticated;

commit;
