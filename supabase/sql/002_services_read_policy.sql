-- ============================================================
-- BeautyOS
-- Archivo: 002_services_read_policy.sql
-- Propósito:
-- Crear una política RLS para permitir que BeautyOS lea servicios
-- activos y visibles para clientes, sin permitir edición, creación
-- ni eliminación desde la app pública.
-- ============================================================

alter table public.services enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'services'
      and policyname = 'Allow public read active services'
  ) then
    execute '
      create policy "Allow public read active services"
      on public.services
      for select
      to anon, authenticated
      using (
        active = true
        and visible_to_customer = true
      )
    ';
  end if;
end $$;

-- Prueba rápida:
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