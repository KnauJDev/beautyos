create table if not exists public.purchases (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  supplier_name text not null,
  purchase_date date not null default current_date,
  invoice_number text,
  total_amount numeric not null default 0 check (total_amount >= 0),
  payment_method text not null default 'cash'
    check (payment_method in ('cash', 'transfer', 'card', 'credit', 'other')),
  notes text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.purchases enable row level security;

create or replace function public.get_purchases_summary()
returns table (
  id uuid,
  supplier_name text,
  purchase_date date,
  invoice_number text,
  total_amount numeric,
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
    raise exception 'No autorizado. Solo owner o admin puede ver compras.';
  end if;

  return query
  select
    p.id,
    p.supplier_name,
    p.purchase_date,
    p.invoice_number,
    p.total_amount,
    p.payment_method,
    p.notes
  from public.purchases p
  where p.active = true
    and p.tenant_id = current_tenant_id
  order by p.purchase_date desc, p.created_at desc;
end;
$$;

revoke execute on function public.get_purchases_summary() from anon;
revoke execute on function public.get_purchases_summary() from public;

grant execute on function public.get_purchases_summary() to authenticated;
