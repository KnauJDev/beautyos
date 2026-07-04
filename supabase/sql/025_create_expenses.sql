-- ============================================================
-- BeautyOS - Paso 619
-- Crear tabla de gastos del negocio y funcion segura resumida
-- Archivo: supabase/sql/025_create_expenses.sql
-- ============================================================

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),

  tenant_id uuid not null references public.tenants(id) on delete cascade,

  expense_date date not null default current_date,

  category text not null,

  description text not null,

  amount numeric(12, 2) not null default 0
    check (amount >= 0),

  payment_method text not null default 'cash'
    check (
      payment_method in (
        'cash',
        'transfer',
        'card',
        'credit',
        'other'
      )
    ),

  notes text,

  active boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.expenses enable row level security;

create index if not exists expenses_tenant_id_idx
on public.expenses(tenant_id);

create index if not exists expenses_expense_date_idx
on public.expenses(expense_date);

create or replace function public.get_expenses_summary()
returns table (
  id uuid,
  expense_date date,
  category text,
  description text,
  amount numeric,
  payment_method text,
  notes text
)
language sql
security definer
set search_path = public
as $$
  select
    expenses.id,
    expenses.expense_date,
    expenses.category,
    expenses.description,
    expenses.amount,
    expenses.payment_method,
    expenses.notes
  from public.expenses
  where expenses.active = true
  order by expenses.expense_date desc, expenses.created_at desc;
$$;

grant execute on function public.get_expenses_summary() to anon, authenticated;
