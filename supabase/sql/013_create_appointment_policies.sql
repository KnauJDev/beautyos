-- ============================================================
-- 013_create_appointment_policies.sql
-- BeautyOS AI
-- Propósito:
-- Crear la tabla de políticas de agenda y una función segura
-- para consultar las políticas del tenant del usuario autenticado.
--
-- Versión endurecida:
-- - Usa tenant del usuario conectado.
-- - Requiere rol owner/admin.
-- - No permite acceso anon.
-- - Evita leer políticas de otros negocios.
-- ============================================================

create table if not exists public.appointment_policies (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  requires_deposit boolean not null default false,
  deposit_percentage numeric not null default 0 check (deposit_percentage >= 0 and deposit_percentage <= 100),
  cancellation_hours integer not null default 24 check (cancellation_hours >= 0),
  reschedule_hours integer not null default 24 check (reschedule_hours >= 0),
  manual_confirmation_required boolean not null default true,
  customer_reschedule_allowed boolean not null default true,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id)
);

alter table public.appointment_policies enable row level security;

create or replace function public.get_appointment_policy()
returns table (
  id uuid,
  requires_deposit boolean,
  deposit_percentage numeric,
  cancellation_hours integer,
  reschedule_hours integer,
  manual_confirmation_required boolean,
  customer_reschedule_allowed boolean
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
    raise exception 'No autorizado. Solo owner o admin puede ver las políticas de agenda.';
  end if;

  return query
  select
    ap.id,
    ap.requires_deposit,
    ap.deposit_percentage,
    ap.cancellation_hours,
    ap.reschedule_hours,
    ap.manual_confirmation_required,
    ap.customer_reschedule_allowed
  from public.appointment_policies ap
  join public.tenants t
    on t.id = ap.tenant_id
  where ap.tenant_id = current_tenant_id
    and ap.active = true
    and t.active = true
  limit 1;
end;
$$;

revoke execute on function public.get_appointment_policy() from anon;
revoke execute on function public.get_appointment_policy() from public;

grant execute on function public.get_appointment_policy() to authenticated;
