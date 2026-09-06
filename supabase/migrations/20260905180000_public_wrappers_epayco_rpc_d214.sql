-- ============================================================================
-- MIGRACIÓN: 20260905180000_public_wrappers_epayco_rpc_d214.sql
-- DESCRIPCIÓN: Wrappers en schema public para RPCs internas de ePayco (D-214).
--              PostgREST / Supabase JS requiere que las funciones invocadas
--              por .rpc() residan en el schema 'public'.
-- ============================================================================

begin;

-- 1. beautyos_calcular_cargo_epayco
create or replace function public.beautyos_calcular_cargo_epayco(
  p_tenant_id uuid,
  p_plan_code text default null
)
returns table (
  monto_cop bigint,
  periodo_inicio timestamptz,
  periodo_fin timestamptz,
  motivo text,
  plan_id_resuelto uuid
)
language sql
security definer
set search_path = pg_catalog, public
as $$
  select * from private.beautyos_calcular_cargo_epayco(p_tenant_id, p_plan_code);
$$;

revoke all on function public.beautyos_calcular_cargo_epayco(uuid, text) from public, anon, authenticated;
grant execute on function public.beautyos_calcular_cargo_epayco(uuid, text) to service_role;

-- 2. beautyos_calcular_cargo_sede
create or replace function public.beautyos_calcular_cargo_sede(p_branch_id uuid)
returns table (
  monto_cop bigint,
  periodo_inicio timestamptz,
  periodo_fin timestamptz,
  motivo text,
  tenant_id_resuelto uuid
)
language sql
security definer
set search_path = pg_catalog, public
as $$
  select * from private.beautyos_calcular_cargo_sede(p_branch_id);
$$;

revoke all on function public.beautyos_calcular_cargo_sede(uuid) from public, anon, authenticated;
grant execute on function public.beautyos_calcular_cargo_sede(uuid) to service_role;

-- 3. beautyos_registrar_intencion_pago
create or replace function public.beautyos_registrar_intencion_pago(
  p_invoice_number text,
  p_tenant_id uuid,
  p_plan_code text,
  p_plan_id uuid,
  p_amount_cop bigint,
  p_created_by uuid default null,
  p_branch_id uuid default null
)
returns uuid
language sql
security definer
set search_path = pg_catalog, public
as $$
  select private.beautyos_registrar_intencion_pago(
    p_invoice_number, p_tenant_id, p_plan_code, p_plan_id, p_amount_cop, p_created_by, p_branch_id
  );
$$;

revoke all on function public.beautyos_registrar_intencion_pago(text, uuid, text, uuid, bigint, uuid, uuid) from public, anon, authenticated;
grant execute on function public.beautyos_registrar_intencion_pago(text, uuid, text, uuid, bigint, uuid, uuid) to service_role;

-- 4. beautyos_resolver_intencion_pago
create or replace function public.beautyos_resolver_intencion_pago(
  p_invoice_number text,
  p_tenant_en_payload uuid default null,
  p_x_ref_payco text default null
)
returns table (
  coincide boolean,
  tenant_id uuid,
  branch_id uuid,
  plan_code text,
  amount_cop bigint,
  motivo text
)
language sql
security definer
set search_path = pg_catalog, public
as $$
  select * from private.beautyos_resolver_intencion_pago(p_invoice_number, p_tenant_en_payload, p_x_ref_payco);
$$;

revoke all on function public.beautyos_resolver_intencion_pago(text, uuid, text) from public, anon, authenticated;
grant execute on function public.beautyos_resolver_intencion_pago(text, uuid, text) to service_role;

-- 5. beautyos_procesar_evento_epayco
create or replace function public.beautyos_procesar_evento_epayco(
  p_tenant_id uuid,
  p_x_ref_payco text,
  p_transaction_id text,
  p_transaction_state text,
  p_cod_transaction_state text,
  p_amount_cop bigint,
  p_currency_code text,
  p_payload jsonb,
  p_plan_code text default null
)
returns table (
  processed boolean,
  previous_status text,
  new_status text,
  message text
)
language sql
security definer
set search_path = pg_catalog, public
as $$
  select * from private.beautyos_procesar_evento_epayco(
    p_tenant_id, p_x_ref_payco, p_transaction_id, p_transaction_state,
    p_cod_transaction_state, p_amount_cop, p_currency_code, p_payload, p_plan_code
  );
$$;

revoke all on function public.beautyos_procesar_evento_epayco(uuid, text, text, text, text, bigint, text, jsonb, text) from public, anon, authenticated;
grant execute on function public.beautyos_procesar_evento_epayco(uuid, text, text, text, text, bigint, text, jsonb, text) to service_role;

-- 6. beautyos_procesar_pago_de_sede
create or replace function public.beautyos_procesar_pago_de_sede(
  p_tenant_id uuid,
  p_branch_id uuid,
  p_x_ref_payco text,
  p_transaction_id text,
  p_transaction_state text,
  p_cod_transaction_state text,
  p_amount_cop bigint,
  p_currency_code text,
  p_payload jsonb
)
returns table (
  processed boolean,
  previous_status text,
  new_status text,
  message text
)
language sql
security definer
set search_path = pg_catalog, public
as $$
  select * from private.beautyos_procesar_pago_de_sede(
    p_tenant_id, p_branch_id, p_x_ref_payco, p_transaction_id, p_transaction_state,
    p_cod_transaction_state, p_amount_cop, p_currency_code, p_payload
  );
$$;

revoke all on function public.beautyos_procesar_pago_de_sede(uuid, uuid, text, text, text, text, bigint, text, jsonb) from public, anon, authenticated;
grant execute on function public.beautyos_procesar_pago_de_sede(uuid, uuid, text, text, text, text, bigint, text, jsonb) to service_role;

commit;
