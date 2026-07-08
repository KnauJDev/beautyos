-- ============================================================
-- 011_create_business_hours.sql
-- BeautyOS AI
-- Propósito:
-- Crear la tabla de horarios del negocio y una función segura
-- para consultar los horarios del tenant del usuario autenticado.
--
-- Versión endurecida:
-- - Usa tenant del usuario conectado.
-- - Requiere rol owner/admin.
-- - No permite acceso anon.
-- - Evita leer horarios de otros negocios.
-- ============================================================

create table if not exists public.business_hours (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  day_of_week integer not null check (day_of_week between 1 and 7),
  opens_at time,
  closes_at time,
  is_open boolean not null default true,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, day_of_week)
);

alter table public.business_hours enable row level security;

create or replace function public.get_business_hours()
returns table (
  id uuid,
  day_of_week integer,
  opens_at time,
  closes_at time,
  is_open boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  current_tenant_id uuid;
begin
  current_tenant_id := public.get_my_tenant_id();

  if current_tenant_id is null then
    raise exception 'No existe un perfil activo asociado al usuario actual.';
  end if;

  if not public.is_owner_or_admin() then
    raise exception 'No autorizado. Solo owner o admin puede ver los horarios del negocio.';
  end if;

  return query
  select
    bh.id,
    bh.day_of_week,
    bh.opens_at,
    bh.closes_at,
    bh.is_open
  from public.business_hours bh
  join public.tenants t
    on t.id = bh.tenant_id
  where bh.tenant_id = current_tenant_id
    and bh.active = true
    and t.active = true
  order by bh.day_of_week asc;
end;
$$;

revoke execute on function public.get_business_hours() from anon;
revoke execute on function public.get_business_hours() from public;

grant execute on function public.get_business_hours() to authenticated;
