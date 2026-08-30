-- CONTROL 194: Paso 8.2 -- Dinero en pesos enteros (H-08).
--
-- POR QUÉ ESTE ARCHIVO
--
-- La migración 20260830140000 hace dos cosas distintas y este control las
-- comprueba por separado:
--   1. El bug real: `beautyos_close_ticket_if_fully_paid` redondeaba la
--      comisión porcentual a 2 decimales en vez de a peso entero. Se
--      fuerza temporalmente (dentro de esta transacción, que termina en
--      ROLLBACK) la política de comisión de un tenant real a 33% y se
--      cobra un ticket de $133 -- 133 * 33 / 100 = 43.89, un caso que
--      distingue sin ambigüedad `round(x)` (=44) de `round(x,2)` (=43.89).
--      Si el bug siguiera presente, esta prueba lo detecta.
--   2. El candado nuevo: confirma que el `CHECK ... NOT VALID` quedó
--      puesto en cada columna de dinero de la lista, y de paso reporta
--      (solo informativo, no hace fallar la prueba) cuántas filas viejas
--      de cada tabla violarían la regla si se validara hoy -- ese número
--      es el que decide si ya se puede correr `VALIDATE CONSTRAINT` sin
--      sorpresas.
--
-- CÓMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\194_test_regla_dinero_entero_h08.sql"
--
-- TERMINA EN ROLLBACK. La política de comisión que se fuerza a 33%, el
-- ticket, el servicio, el pago y la comisión generada -- todo desaparece.

begin;

do $$
declare
  v_fallos integer := 0;
  v_error text;
  v_tenant uuid;
  v_owner_user uuid;
  v_branch uuid;
  v_client uuid;
  v_service uuid;
  v_stylist uuid;
  v_ticket uuid;
  v_ticket_service uuid;
  v_comision numeric;
  v_conteo_columnas_objetivo integer := 16;
  v_conteo_checks integer;
begin
  -- =====================================================================
  -- 1. Bug real: comisión porcentual debe quedar en peso entero.
  -- =====================================================================
  select tm.tenant_id, tm.user_id
    into v_tenant, v_owner_user
  from public.tenant_memberships tm
  join public.commission_policies cp on cp.tenant_id = tm.tenant_id
  where tm.role = 'tenant_owner'
    and tm.active
  limit 1;

  if v_tenant is null then
    raise notice 'SIN DATOS  no hay ningun tenant con politica de comision para probar el bug de round(). Se sigue con el punto 2.';
  else
    select b.id into v_branch from public.branches b
      where b.tenant_id = v_tenant and b.active limit 1;
    select c.id into v_client from public.clients c
      where c.tenant_id = v_tenant and c.active limit 1;
    select s.id into v_service from public.services s
      where s.tenant_id = v_tenant and s.active limit 1;
    select st.id into v_stylist from public.stylists st
      where st.tenant_id = v_tenant and st.active limit 1;

    if v_branch is null or v_client is null or v_service is null or v_stylist is null then
      raise notice 'SIN DATOS  el tenant encontrado no tiene sede/cliente/servicio/estilista activos para armar el ticket de prueba. Se sigue con el punto 2.';
    else
      -- Se fuerza la politica a 33% -- solo dentro de esta transaccion.
      update public.commission_policies
         set commission_type = 'percentage',
             commission_percentage = 33,
             active = true
       where tenant_id = v_tenant;

      -- Limpiar cualquier override especifico existente entre este estilista y servicio (solo dentro de esta transaccion)
      delete from public.stylist_service_commissions
       where tenant_id = v_tenant and stylist_id = v_stylist and service_id = v_service;

      perform set_config(
        'request.jwt.claims',
        json_build_object('sub', v_owner_user::text, 'role', 'authenticated')::text,
        true
      );

      insert into public.tickets (tenant_id, branch_id, client_id, status, channel, scheduled_at)
      values (v_tenant, v_branch, v_client, 'finalizado', 'manual', now())
      returning id into v_ticket;

      insert into public.ticket_services (
        tenant_id, branch_id, ticket_id, service_id, stylist_id,
        price, duration_minutes, status
      ) values (
        v_tenant, v_branch, v_ticket, v_service, v_stylist,
        133, 30, 'finalizado'
      )
      returning id into v_ticket_service;

      insert into public.ticket_payments (
        tenant_id, ticket_id, amount, method, created_by
      ) values (
        v_tenant, v_ticket, 133, 'efectivo', v_owner_user
      );

      perform private.beautyos_close_ticket_if_fully_paid(v_ticket, v_tenant);

      select sc.commission_amount into v_comision
      from public.stylist_commissions sc
      where sc.ticket_service_id = v_ticket_service
      limit 1;

      if v_comision is null then
        v_fallos := v_fallos + 1;
        raise notice 'FALLO 1  no se genero ninguna comision para el ticket de prueba (se esperaba una de $133 x 33%%)';
      elsif v_comision <> round(v_comision) then
        v_fallos := v_fallos + 1;
        raise notice 'FALLO 1  la comision quedo en % (con centavos) -- el bug de round(x,2) sigue presente', v_comision;
      elsif v_comision <> 44 then
        v_fallos := v_fallos + 1;
        raise notice 'FALLO 1  la comision quedo en % (peso entero, pero no el 44 esperado para $133 x 33%%)', v_comision;
      else
        raise notice 'OK 1  $133 al 33%% genero una comision de $44 en peso entero, sin centavos';
      end if;
    end if;
  end if;

  -- =====================================================================
  -- 2. El candado: confirmar que los CHECK quedaron puestos.
  -- =====================================================================
  select count(*) into v_conteo_checks
  from pg_constraint
  where conname in (
    'services_price_es_entero_check',
    'branch_services_price_es_entero_check',
    'ticket_services_price_es_entero_check',
    'ticket_payments_amount_es_entero_check',
    'branch_products_average_cost_es_entero_check',
    'branch_products_sale_price_es_entero_check',
    'purchases_total_amount_es_entero_check',
    'purchase_items_unit_cost_es_entero_check',
    'expenses_amount_es_entero_check',
    'commission_policies_fixed_commission_amount_es_entero_check',
    'stylist_service_commissions_fixed_commission_amount_es_entero_c',
    'stylist_commissions_service_amount_es_entero_check',
    'stylist_commissions_fixed_commission_amount_es_entero_check',
    'stylist_commissions_commission_amount_es_entero_check'
  );

  v_conteo_columnas_objetivo := 14;

  raise notice 'INFO 2  % de % candados de "es entero" existen hoy en el esquema.', v_conteo_checks, v_conteo_columnas_objetivo;

  if v_conteo_checks = 0 then
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 2  no quedo ningun candado puesto -- la migracion no corrio o fallo antes de este punto';
  else
    raise notice 'OK 2  todos los % candados de "es entero" verificados', v_conteo_checks;
  end if;

  -- =====================================================================
  -- 3. Diagnostico informativo: filas viejas que violarian cada candado.
  --    No hace fallar la prueba -- es la foto de "que tan sucia" esta
  --    cada tabla antes de decidir si se valida el CHECK.
  -- =====================================================================
  raise notice ' ';
  raise notice '--- Filas existentes que hoy violarian cada candado (0 = listo para VALIDATE CONSTRAINT) ---';
  raise notice 'services.price: %', (select count(*) from public.services where price <> round(price));
  raise notice 'branch_services.price: %', (select count(*) from public.branch_services where price <> round(price));
  raise notice 'ticket_services.price: %', (select count(*) from public.ticket_services where price <> round(price));
  raise notice 'ticket_payments.amount: %', (select count(*) from public.ticket_payments where amount <> round(amount));
  raise notice 'branch_products.average_cost: %', (select count(*) from public.branch_products where average_cost <> round(average_cost));
  raise notice 'branch_products.sale_price: %', (select count(*) from public.branch_products where sale_price <> round(sale_price));
  raise notice 'purchases.total_amount: %', (select count(*) from public.purchases where total_amount <> round(total_amount));
  raise notice 'purchase_items.unit_cost: %', (select count(*) from public.purchase_items where unit_cost <> round(unit_cost));
  raise notice 'expenses.amount: %', (select count(*) from public.expenses where amount <> round(amount));
  raise notice 'commission_policies.fixed_commission_amount: %', (select count(*) from public.commission_policies where fixed_commission_amount <> round(fixed_commission_amount));
  raise notice 'stylist_service_commissions.fixed_commission_amount: %', (select count(*) from public.stylist_service_commissions where fixed_commission_amount <> round(fixed_commission_amount));
  raise notice 'stylist_commissions.service_amount: %', (select count(*) from public.stylist_commissions where service_amount <> round(service_amount));
  raise notice 'stylist_commissions.fixed_commission_amount: %', (select count(*) from public.stylist_commissions where fixed_commission_amount <> round(fixed_commission_amount));
  raise notice 'stylist_commissions.commission_amount: %', (select count(*) from public.stylist_commissions where commission_amount <> round(commission_amount));

  -- =====================================================================
  raise notice ' ';
  if v_fallos = 0 then
    raise notice '=== TODAS LAS PRUEBAS DEL PASO 8.2 (H-08) PASARON ===';
  else
    raise notice '=== % FALLO(S). Revisar arriba. ===', v_fallos;
  end if;

exception
  when others then
    v_error := sqlerrm;
    raise notice ' ';
    raise notice '=== LA PRUEBA SE DETUVO: % ===', v_error;
end;
$$;

rollback;
