-- BeautyOS - Tramo D2: branch_id obligatorio en operacion por sede.
--
-- Precondicion: Flutter estricto de sede (D1) publicado por separado y cero
-- filas operativas sin sede. Los triggers y RPC heredados se conservan hasta
-- D3; esta migracion solo endurece la nulabilidad de los datos.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $$
declare
  v_table text;
  v_null_count bigint;
begin
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
      raise exception using
        errcode = '23502',
        message = format(
          'Tramo D2 detenido: public.%I conserva %s fila(s) sin branch_id.',
          v_table,
          v_null_count
        );
    end if;
  end loop;
end;
$$;

-- Configuracion operativa por sede.
alter table public.business_hours
  alter column branch_id set not null;
alter table public.appointment_policies
  alter column branch_id set not null;

-- Tickets e historiales derivados.
alter table public.tickets
  alter column branch_id set not null;
alter table public.ticket_services
  alter column branch_id set not null;
alter table public.ticket_history
  alter column branch_id set not null;
alter table public.ticket_service_history
  alter column branch_id set not null;
alter table public.ticket_service_change_history
  alter column branch_id set not null;
alter table public.ticket_payments
  alter column branch_id set not null;
alter table public.stylist_commissions
  alter column branch_id set not null;

-- Inventario, compras y gastos.
alter table public.inventory_movements
  alter column branch_id set not null;
alter table public.purchases
  alter column branch_id set not null;
alter table public.purchase_items
  alter column branch_id set not null;
alter table public.expenses
  alter column branch_id set not null;

-- Evidencia y reputacion asociadas a tickets.
alter table public.work_photos
  alter column branch_id set not null;
alter table public.reviews
  alter column branch_id set not null;

commit;
