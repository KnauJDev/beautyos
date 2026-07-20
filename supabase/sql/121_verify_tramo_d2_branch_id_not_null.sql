-- BeautyOS - Verificacion de solo lectura del Tramo D2.
-- Confirma obligatoriedad de sede sin retirar los puentes de D3.

begin;
set transaction read only;

do $$
declare
  v_nullable_count integer;
  v_missing_column_count integer;
  v_null_count bigint;
  v_table text;
begin
  select count(*) filter (where c.is_nullable = 'YES'),
         15 - count(*)
    into v_nullable_count, v_missing_column_count
  from information_schema.columns c
  where c.table_schema = 'public'
    and c.column_name = 'branch_id'
    and c.table_name = any (array[
      'business_hours',
      'appointment_policies',
      'tickets',
      'ticket_services',
      'ticket_history',
      'ticket_service_history',
      'ticket_service_change_history',
      'ticket_payments',
      'stylist_commissions',
      'inventory_movements',
      'purchases',
      'purchase_items',
      'expenses',
      'work_photos',
      'reviews'
    ]);

  if v_missing_column_count <> 0 or v_nullable_count <> 0 then
    raise exception
      'Tramo D2 incompleto: % columnas ausentes y % columnas anulables.',
      v_missing_column_count,
      v_nullable_count;
  end if;

  foreach v_table in array array[
    'business_hours',
    'appointment_policies',
    'tickets',
    'ticket_services',
    'ticket_history',
    'ticket_service_history',
    'ticket_service_change_history',
    'ticket_payments',
    'stylist_commissions',
    'inventory_movements',
    'purchases',
    'purchase_items',
    'expenses',
    'work_photos',
    'reviews'
  ]
  loop
    execute format(
      'select count(*) from public.%I where branch_id is null',
      v_table
    ) into v_null_count;

    if v_null_count <> 0 then
      raise exception
        'Tramo D2 invalido: public.% contiene % fila(s) sin branch_id.',
        v_table,
        v_null_count;
    end if;
  end loop;
end;
$$;

select c.table_name,
       c.is_nullable
from information_schema.columns c
where c.table_schema = 'public'
  and c.column_name = 'branch_id'
  and c.table_name = any (array[
    'business_hours',
    'appointment_policies',
    'tickets',
    'ticket_services',
    'ticket_history',
    'ticket_service_history',
    'ticket_service_change_history',
    'ticket_payments',
    'stylist_commissions',
    'inventory_movements',
    'purchases',
    'purchase_items',
    'expenses',
    'work_photos',
    'reviews'
  ])
order by c.table_name;

rollback;
