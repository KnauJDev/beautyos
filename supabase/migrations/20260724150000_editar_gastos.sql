-- BeautyOS - Editar gastos (sub-bloque 3 de 3: inventario/compras/gastos
-- editables). Cierra la ruta acordada.
--
-- GastosPage era 100% de solo lectura. A diferencia de productos y
-- compras, expenses es una tabla plana sin items ni impacto en stock ni
-- costo promedio -- por eso update_expense puede editar el registro
-- completo (no solo un encabezado) sin ningun riesgo de descuadrar otra
-- cosa. Mismo patron de gobernanza que compras: crear es de
-- tenant_owner/admin; editar y anular quedan solo para tenant_owner
-- (decision ya tomada por el propietario en el bloque anterior). No hay
-- borrado fisico, solo active = false.

begin;

create or replace function public.create_expense(
  p_branch_id uuid,
  p_category text,
  p_description text,
  p_amount numeric,
  p_expense_date date default current_date,
  p_payment_method text default 'cash',
  p_notes text default null
)
returns table (expense_id uuid)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
  v_expense_id uuid;
begin
  select tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner', 'admin'], true
  );

  if length(trim(coalesce(p_category, ''))) = 0 then
    raise exception 'La categoria es obligatoria.';
  end if;

  if length(trim(coalesce(p_description, ''))) = 0 then
    raise exception 'La descripcion es obligatoria.';
  end if;

  if p_amount is null or p_amount < 0 then
    raise exception 'El valor no puede ser negativo.';
  end if;

  if p_payment_method is null
     or p_payment_method not in ('cash', 'transfer', 'card', 'credit', 'other') then
    raise exception 'La forma de pago no es valida.';
  end if;

  insert into public.expenses (
    tenant_id, branch_id, expense_date, category, description, amount,
    payment_method, notes
  ) values (
    v_tenant_id,
    p_branch_id,
    coalesce(p_expense_date, current_date),
    trim(p_category),
    trim(p_description),
    p_amount,
    p_payment_method,
    nullif(trim(coalesce(p_notes, '')), '')
  )
  returning id into v_expense_id;

  return query select v_expense_id;
end;
$$;

create or replace function public.update_expense(
  p_branch_id uuid,
  p_expense_id uuid,
  p_category text,
  p_description text,
  p_amount numeric,
  p_expense_date date,
  p_payment_method text,
  p_notes text
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner'], true
  );

  if length(trim(coalesce(p_category, ''))) = 0 then
    raise exception 'La categoria es obligatoria.';
  end if;

  if length(trim(coalesce(p_description, ''))) = 0 then
    raise exception 'La descripcion es obligatoria.';
  end if;

  if p_amount is null or p_amount < 0 then
    raise exception 'El valor no puede ser negativo.';
  end if;

  if p_payment_method is null
     or p_payment_method not in ('cash', 'transfer', 'card', 'credit', 'other') then
    raise exception 'La forma de pago no es valida.';
  end if;

  update public.expenses
     set category = trim(p_category),
         description = trim(p_description),
         amount = p_amount,
         expense_date = coalesce(p_expense_date, expense_date),
         payment_method = p_payment_method,
         notes = nullif(trim(coalesce(p_notes, '')), ''),
         updated_at = now()
   where id = p_expense_id
     and tenant_id = v_tenant_id
     and branch_id = p_branch_id;

  if not found then
    raise exception 'El gasto no existe o pertenece a otro negocio.';
  end if;
end;
$$;

create or replace function public.set_expense_active(
  p_branch_id uuid,
  p_expense_id uuid,
  p_active boolean
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner'], true
  );

  update public.expenses
     set active = p_active, updated_at = now()
   where id = p_expense_id
     and tenant_id = v_tenant_id
     and branch_id = p_branch_id;

  if not found then
    raise exception 'El gasto no existe o pertenece a otro negocio.';
  end if;
end;
$$;

create or replace function public.get_expenses_for_management(p_branch_id uuid)
returns table (
  expense_id uuid,
  expense_date date,
  category text,
  description text,
  amount numeric,
  payment_method text,
  notes text,
  active boolean
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_tenant_id uuid;
begin
  select tenant_id
    into v_tenant_id
  from private.beautyos_resolve_branch_access(
    p_branch_id, array['tenant_owner', 'admin'], true
  );

  return query
  select e.id, e.expense_date, e.category, e.description, e.amount,
         e.payment_method, e.notes, e.active
  from public.expenses e
  where e.tenant_id = v_tenant_id
    and e.branch_id = p_branch_id
  order by e.expense_date desc, e.created_at desc;
end;
$$;

revoke all on function public.create_expense(uuid, text, text, numeric, date, text, text) from public, anon;
revoke all on function public.update_expense(uuid, uuid, text, text, numeric, date, text, text) from public, anon;
revoke all on function public.set_expense_active(uuid, uuid, boolean) from public, anon;
revoke all on function public.get_expenses_for_management(uuid) from public, anon;

grant execute on function public.create_expense(uuid, text, text, numeric, date, text, text) to authenticated, service_role;
grant execute on function public.update_expense(uuid, uuid, text, text, numeric, date, text, text) to authenticated, service_role;
grant execute on function public.set_expense_active(uuid, uuid, boolean) to authenticated, service_role;
grant execute on function public.get_expenses_for_management(uuid) to authenticated, service_role;

commit;
