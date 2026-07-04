-- ============================================================
-- BeautyOS - Paso 623
-- Datos demo para gastos del negocio
-- Archivo: supabase/sql/026_seed_expenses.sql
-- ============================================================

insert into public.expenses (
  tenant_id,
  expense_date,
  category,
  description,
  amount,
  payment_method,
  notes
)
select
  tenants.id,
  current_date,
  'Arriendo',
  'Pago mensual del local',
  1200000,
  'transfer',
  'Gasto demo: arriendo mensual del centro de belleza.'
from public.tenants
where tenants.name = 'Bella Mujer'
  and not exists (
    select 1
    from public.expenses
    where expenses.tenant_id = tenants.id
      and expenses.description = 'Pago mensual del local'
  );

insert into public.expenses (
  tenant_id,
  expense_date,
  category,
  description,
  amount,
  payment_method,
  notes
)
select
  tenants.id,
  current_date,
  'Servicios públicos',
  'Pago de energía y agua',
  280000,
  'cash',
  'Gasto demo: servicios públicos del negocio.'
from public.tenants
where tenants.name = 'Bella Mujer'
  and not exists (
    select 1
    from public.expenses
    where expenses.tenant_id = tenants.id
      and expenses.description = 'Pago de energía y agua'
  );

insert into public.expenses (
  tenant_id,
  expense_date,
  category,
  description,
  amount,
  payment_method,
  notes
)
select
  tenants.id,
  current_date,
  'Marketing',
  'Publicidad en redes sociales',
  150000,
  'card',
  'Gasto demo: pauta publicitaria para atraer clientes.'
from public.tenants
where tenants.name = 'Bella Mujer'
  and not exists (
    select 1
    from public.expenses
    where expenses.tenant_id = tenants.id
      and expenses.description = 'Publicidad en redes sociales'
  );
