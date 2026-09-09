-- ============================================================================
-- SCRIPT DE ACTIVACIÓN Y AUDITORÍA: activar_pago_naguara.sql
-- Procesa y aplica el pago real de ePayco ($10.000 COP, ref 382618073)
-- para el negocio Naguara de Uñas.
-- ============================================================================

begin;

do $$
declare
  v_tenant_id uuid;
  v_sub public.tenant_subscriptions%rowtype;
  v_processed boolean;
  v_prev text;
  v_new text;
  v_msg text;
begin
  -- 1. Buscar tenant Naguara de Uñas
  select id into v_tenant_id
  from public.tenants
  where name ilike '%naguara%'
  limit 1;

  if v_tenant_id is null then
    -- Si no por nombre, por email del owner
    select t.id into v_tenant_id
    from public.tenants t
    join public.tenant_memberships tm on tm.tenant_id = t.id
    join auth.users u on u.id = tm.user_id
    where u.email ilike '%elboga002%' or u.email ilike '%juank%'
    limit 1;
  end if;

  if v_tenant_id is null then
    raise exception 'No se encontró el tenant de Naguara de Uñas.';
  end if;

  select * into v_sub from public.tenant_subscriptions where tenant_id = v_tenant_id;
  raise notice 'Tenant encontrado: % (Estado actual: %, Precio pactado: %, Plan: %)',
    v_tenant_id, v_sub.status, v_sub.price_cop, v_sub.plan_id;

  -- 2. Procesar el pago real de ePayco con la RPC D-160
  select processed, previous_status, new_status, message
  into v_processed, v_prev, v_new, v_msg
  from private.beautyos_procesar_evento_epayco(
    v_tenant_id,
    '382618073',
    '382618073178750154',
    'Aceptada',
    '1',
    10000,
    'COP',
    '{"x_ref_payco": 382618073, "x_amount": 10000, "x_response": "Aceptada", "x_franchise": "PSE", "x_bank_name": "BANCOLOMBIA"}'::jsonb,
    'profesional'
  );

  raise notice 'Resultado activación -> Processed: %, Prev: %, New: %, Mensaje: %',
    v_processed, v_prev, v_new, v_msg;

  -- 3. Quitar la marca de DEMO si tuviera para que figure como cliente real activo
  update public.tenants
  set is_demo = false
  where id = v_tenant_id;

  raise notice 'Marca is_demo actualizada a FALSE para Naguara de Uñas.';
end;
$$;

commit;
