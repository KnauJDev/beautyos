-- ============================================================
-- BeautyOS - Paso 619
-- Crear tabla de gastos del negocio y funcion segura resumida
-- Archivo: supabase/sql/025_create_expenses.sql
-- Version endurecida con tenant actual y rol owner/admin
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
    raise exception 'No autorizado. Solo owner o admin puede ver gastos.';
  end if;

  return query
  select
    e.id,
    e.expense_date,
    e.category,
    e.description,
    e.amount,
    e.payment_method,
    e.notes
  from public.expenses e
  where e.active = true
    and e.tenant_id = current_tenant_id
  order by e.expense_date desc, e.created_at desc;
end;
$$;

revoke execute on function public.get_expenses_summary() from anon;
revoke execute on function public.get_expenses_summary() from public;

grant execute on function public.get_expenses_summary() to authenticated;
