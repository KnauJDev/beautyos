-- BeautyOS - Crear sedes adicionales (punto 4.1 de RUTA_GENERAL_2026-07-25.md).
--
-- Hueco confirmado desde D-058: un tenant_owner no tenia forma de crear una
-- segunda sede; solo existia la principal creada por register_tenant().
-- Mismo patron de sembrado que register_tenant (D-047), pero SIN duplicar
-- nada del catalogo (servicios/estilistas) ni de commission_policies (esa
-- es a nivel de tenant, no de sede, ya existe desde la sede principal):
--
-- - branches: fila nueva, is_primary = false, slug generado del nombre
--   (con sufijo si colisiona dentro del mismo tenant).
-- - branch_memberships: vincula la MISMA membresia de tenant_owner del
--   dueno a la sede nueva (igual que register_tenant hace con la primera).
-- - business_hours: horario por defecto (lunes a sabado 8-20, domingo
--   cerrado), igual que register_tenant.
-- - appointment_policies: fila con los valores por defecto de la columna
--   (si branch_id, el resto son default). commission_policies NO se
--   repite: es unica por tenant.
--
-- La sede queda vacia de catalogo operativo (branch_services,
-- branch_stylists, branch_products): el propietario asigna servicios y
-- estilistas con las pantallas que ya existen (Servicios/Estilistas),
-- igual que tuvo que hacerlo para la sede principal al registrarse.

begin;

create or replace function public.create_branch(
  p_name text,
  p_address text default null,
  p_city text default null
)
returns table (
  branch_id uuid
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_tenant_membership_id uuid;
  v_branch_id uuid;
  v_base_slug text;
  v_slug text;
  v_suffix integer := 1;
begin
  v_tenant_id := public.get_my_tenant_id();

  if v_tenant_id is null or public.get_my_role() <> 'tenant_owner' then
    raise exception 'Solo el propietario del negocio puede crear sedes.';
  end if;

  select tm.id
    into v_tenant_membership_id
  from public.tenant_memberships tm
  where tm.tenant_id = v_tenant_id
    and tm.user_id = auth.uid()
    and tm.role = 'tenant_owner'
    and tm.active;

  if v_tenant_membership_id is null then
    raise exception 'No se encontro tu membresia de propietario para este negocio.';
  end if;

  if length(trim(coalesce(p_name, ''))) = 0 then
    raise exception 'El nombre de la sede es obligatorio.';
  end if;

  v_base_slug := trim(both '-' from regexp_replace(lower(trim(p_name)), '[^a-z0-9]+', '-', 'g'));

  if v_base_slug = '' then
    raise exception 'El nombre de la sede debe incluir letras o numeros.';
  end if;

  v_slug := v_base_slug;

  while exists (
    select 1 from public.branches where tenant_id = v_tenant_id and slug = v_slug
  ) loop
    v_suffix := v_suffix + 1;
    v_slug := v_base_slug || '-' || v_suffix;
  end loop;

  insert into public.branches (
    tenant_id, name, slug, address, city, is_primary
  ) values (
    v_tenant_id,
    trim(p_name),
    v_slug,
    nullif(trim(coalesce(p_address, '')), ''),
    nullif(trim(coalesce(p_city, '')), ''),
    false
  )
  returning id into v_branch_id;

  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (
    v_tenant_id, v_branch_id, v_tenant_membership_id, true, now(), auth.uid()
  );

  insert into public.business_hours (
    tenant_id, branch_id, day_of_week, opens_at, closes_at, is_open
  )
  select
    v_tenant_id,
    v_branch_id,
    schedule.day_of_week,
    schedule.opens_at,
    schedule.closes_at,
    schedule.is_open
  from (
    values
      (1, time '08:00', time '20:00', true),
      (2, time '08:00', time '20:00', true),
      (3, time '08:00', time '20:00', true),
      (4, time '08:00', time '20:00', true),
      (5, time '08:00', time '20:00', true),
      (6, time '08:00', time '20:00', true),
      (7, null::time, null::time, false)
  ) as schedule(day_of_week, opens_at, closes_at, is_open);

  insert into public.appointment_policies (tenant_id, branch_id)
  values (v_tenant_id, v_branch_id);

  return query select v_branch_id;
end;
$$;

revoke all on function public.create_branch(text, text, text) from public, anon;
grant execute on function public.create_branch(text, text, text) to authenticated, service_role;

comment on function public.create_branch(text, text, text)
  is 'Crea una sede adicional para el tenant del propietario autenticado, con horario y politica de citas por defecto. No copia catalogo operativo.';

commit;
