-- BeautyOS - Auditoria de solo lectura del Tramo C3.

do $$
declare
  v_signature text;
  v_definition text;
begin
  foreach v_signature in array array[
    'public.get_daily_close_v2(uuid,date)',
    'public.get_commission_summary_v2(uuid,date)',
    'public.get_branch_financial_summary_v2(uuid)',
    'public.get_sales_report_summary_v2(uuid)',
    'public.get_purchases_summary_v2(uuid)',
    'public.get_purchase_items_summary_v2(uuid)',
    'public.get_expenses_summary_v2(uuid)',
    'public.get_products_summary_v2(uuid)',
    'public.get_inventory_movements_summary_v2(uuid)'
  ] loop
    if to_regprocedure(v_signature) is null then
      raise exception 'Falta la funcion C3 %.', v_signature;
    end if;
    if has_function_privilege('anon', v_signature, 'EXECUTE') then
      raise exception 'Anon no debe ejecutar %.', v_signature;
    end if;
    if not has_function_privilege('authenticated', v_signature, 'EXECUTE') then
      raise exception 'Authenticated debe ejecutar %.', v_signature;
    end if;

    select pg_get_functiondef(to_regprocedure(v_signature)) into v_definition;
    if position('beautyos_resolve_branch_access' in v_definition) = 0
       or position('branch_id = p_branch_id' in v_definition) = 0 then
      raise exception 'La funcion % no demuestra validacion y filtro de sede.', v_signature;
    end if;
  end loop;
end;
$$;

select
  p.oid::regprocedure::text as function_signature,
  p.prosecdef as security_definer,
  p.proconfig as function_settings
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'get_daily_close_v2',
    'get_commission_summary_v2',
    'get_branch_financial_summary_v2',
    'get_sales_report_summary_v2',
    'get_purchases_summary_v2',
    'get_purchase_items_summary_v2',
    'get_expenses_summary_v2',
    'get_products_summary_v2',
    'get_inventory_movements_summary_v2'
  )
order by function_signature;
