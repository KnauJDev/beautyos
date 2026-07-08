-- ============================================================
-- BeautyOS
-- Archivo: 002_services_read_policy.sql
-- Propósito:
-- Crear una política RLS para permitir que BeautyOS lea servicios
-- activos y visibles del tenant del usuario autenticado.
--
-- Version endurecida:
-- - No permite lectura anon.
-- - Permite lectura solo a authenticated.
-- - Filtra por tenant del usuario conectado.
-- - Mantiene lectura solo de servicios activos y visibles.
-- ============================================================

alter table public.services enable row level security;

drop policy if exists "Allow public read active services"
on public.services;

drop policy if exists "Authenticated users can read active visible services from their tenant"
on public.services;

create policy "Authenticated users can read active visible services from their tenant"
on public.services
for select
to authenticated
using (
  tenant_id = public.get_my_tenant_id()
  and active = true
  and visible_to_customer = true
);

-- Prueba rápida después de iniciar sesión:
-- select
--   id,
--   name,
--   category,
--   duration_minutes,
--   price,
--   active,
--   visible_to_customer
-- from public.services
-- where active = true
--   and visible_to_customer = true
-- order by name;
