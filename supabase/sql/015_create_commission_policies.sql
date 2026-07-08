-- ============================================================
-- 015_create_commission_policies.sql
-- BeautyOS AI
-- Propósito:
-- Crear la tabla de políticas de comisión y una función segura
-- para consultar las comisiones del tenant del usuario autenticado.
--
-- Versión endurecida:
-- - Usa tenant del usuario conectado.
-- - Requiere rol owner/admin.
-- - No permite acceso anon.
-- - Evita leer comisiones de otros negocios.
-- ============================================================

create table if not exists public.commission_policies (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  commission_type text not null default 'percentage'
    check (commission_type in ('percentage', 'fixed')),
  commission_percentage numeric not null default 40
    check (commission_percentage >= 0 and commission_percentage <= 100),
  fixed_commission_amount numeric not null default 0
    check (fixed_commission_amount >= 0),
  applies_after_discount boolean not null default true,
  notes text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id)
);

alter table public.commission_policies enable row level security;

create or replace function public.get_commission_policy()
returns table (
  id uuid,
  commission_type text,
  commission_percentage numeric,
  fixed_commission_amount numeric,
  applies_after_discount boolean,
  notes text
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
    raise exception 'No autorizado. Solo owner o admin puede ver las políticas de comisión.';
  end if;

  return query
  select
    cp.id,
    cp.commission_type,
    cp.commission_percentage,
    cp.fixed_commission_amount,
    cp.applies_after_discount,
    cp.notes
  from public.commission_policies cp
  join public.tenants t
    on t.id = cp.tenant_id
  where cp.tenant_id = current_tenant_id
    and cp.active = true
    and t.active = true
  limit 1;
end;
$$;

revoke execute on function public.get_commission_policy() from anon;
revoke execute on function public.get_commission_policy() from public;

grant execute on function public.get_commission_policy() to authenticated;
