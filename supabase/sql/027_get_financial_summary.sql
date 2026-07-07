-- ============================================================
-- BeautyOS - Funcion segura de resumen financiero
-- Archivo: supabase/sql/027_get_financial_summary.sql
-- Version endurecida con tenant actual y rol owner/admin
-- ============================================================

create or replace function public.get_financial_summary()
returns table (
  total_sales numeric,
  total_purchases numeric,
  total_expenses numeric,
  net_result numeric
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
    raise exception 'No autorizado. Solo owner o admin puede ver el resumen financiero.';
  end if;

  return query
  select
    coalesce((
      select sum(ts.price)
      from public.tickets t
      join public.ticket_services ts
        on ts.ticket_id = t.id
      where t.tenant_id = current_tenant_id
        and ts.tenant_id = current_tenant_id
        and lower(t.status) in ('confirmado', 'en_proceso', 'finalizado')
    ), 0)::numeric as total_sales,

    coalesce((
      select sum(p.total_amount)
      from public.purchases p
      where p.tenant_id = current_tenant_id
        and p.active = true
    ), 0)::numeric as total_purchases,

    coalesce((
      select sum(e.amount)
      from public.expenses e
      where e.tenant_id = current_tenant_id
        and e.active = true
    ), 0)::numeric as total_expenses,

    (
      coalesce((
        select sum(ts.price)
        from public.tickets t
        join public.ticket_services ts
          on ts.ticket_id = t.id
        where t.tenant_id = current_tenant_id
          and ts.tenant_id = current_tenant_id
          and lower(t.status) in ('confirmado', 'en_proceso', 'finalizado')
      ), 0)
      -
      coalesce((
        select sum(p.total_amount)
        from public.purchases p
        where p.tenant_id = current_tenant_id
          and p.active = true
      ), 0)
      -
      coalesce((
        select sum(e.amount)
        from public.expenses e
        where e.tenant_id = current_tenant_id
          and e.active = true
      ), 0)
    )::numeric as net_result;
end;
$$;

revoke execute on function public.get_financial_summary() from anon;
revoke execute on function public.get_financial_summary() from public;

grant execute on function public.get_financial_summary() to authenticated;
