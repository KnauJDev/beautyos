-- CONTROL 197: Paso 8.10 -- Intenciones de pago de ePayco (TL-02, D-182).
--
-- POR QUÉ ESTE ARCHIVO
--
-- La migración 20260901120000 introduce:
--   1. public.subscription_payment_intents
--   2. private.beautyos_registrar_intencion_pago(...)
--   3. private.beautyos_resolver_intencion_pago(...)
--
-- Existen porque la firma SHA-256 de ePayco no cubre `x_extra1` (el negocio)
-- ni `x_extra2` (el plan): una confirmación legítima se podía reenviar con el
-- negocio cambiado y la firma seguía siendo válida (TL-02).
--
-- Este control valida transaccionalmente:
--   - Se registra la intención y queda en `pendiente`.
--   - Resolver con el negocio correcto devuelve `coincide = true` y los datos
--     autoritativos del servidor, y la deja en `verificada`.
--   - EL ATAQUE DE TL-02: resolver con un negocio distinto al de la factura
--     devuelve `coincide = false` y la deja en `rechazada` con su motivo.
--   - Falla cerrado: una factura que no existe no resuelve a ningún negocio.
--   - Falla cerrado: una confirmación sin número de factura tampoco.
--   - Reabrir el checkout con la misma factura actualiza, no duplica.
--   - No se puede registrar una intención por un monto de cero o negativo.
--   - La tabla tiene RLS activo y está revocada de `anon` y `authenticated`.
--   - Las dos funciones están revocadas de `anon`, `authenticated` y `public`.
--
-- CÓMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\197_test_intenciones_pago_epayco_tl02.sql"
--
-- TERMINA EN ROLLBACK. Todos los datos de prueba se descartan limpiamente.

begin;

do $$
declare
  v_fallos integer := 0;
  v_tenant_a uuid;
  v_tenant_b uuid;
  v_factura text := 'SUB-TEST197-' || extract(epoch from now())::bigint::text;
  v_id uuid;
  v_res record;
  v_status text;
  v_monto bigint;
  v_conteo integer;
  v_rls boolean;
  v_error text;
begin
  raise notice '======================================================================';
  raise notice 'CONTROL 197 - Intenciones de pago de ePayco (TL-02 / D-182)';
  raise notice '======================================================================';

  -- Se usan negocios reales existentes en vez de inventarlos: la prueba va
  -- dentro de una transaccion con ROLLBACK, asi que no los toca.
  select id into v_tenant_a from public.tenants order by created_at limit 1;
  select id into v_tenant_b from public.tenants where id <> v_tenant_a order by created_at limit 1;

  if v_tenant_a is null then
    raise exception 'No hay ningun negocio en public.tenants: este control necesita al menos uno.';
  end if;

  if v_tenant_b is null then
    -- Con un solo negocio en la base, se usa un uuid inventado como "el otro":
    -- para la prueba del ataque solo hace falta que sea distinto.
    v_tenant_b := gen_random_uuid();
    raise notice 'Solo hay un negocio; el caso 3 usa un uuid ajeno inventado.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 1: se registra la intencion y queda pendiente ---';
  -- -------------------------------------------------------------------------
  v_id := private.beautyos_registrar_intencion_pago(
    v_factura, v_tenant_a, 'profesional', null, 120000::bigint, null
  );

  select status, amount_cop into v_status, v_monto
  from public.subscription_payment_intents where id = v_id;

  if v_id is null or v_status is distinct from 'pendiente' or v_monto <> 120000 then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 1: la intencion no quedo registrada como pendiente (status=%, monto=%).', v_status, v_monto;
  else
    raise notice 'OK 1: intencion % registrada como pendiente por 120000 COP.', v_factura;
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 2: resolver con el negocio correcto ---';
  -- -------------------------------------------------------------------------
  select * into v_res
  from private.beautyos_resolver_intencion_pago(v_factura, v_tenant_a, 'ref-197-ok');

  select status into v_status from public.subscription_payment_intents where id = v_id;

  if not v_res.coincide
     or v_res.tenant_id is distinct from v_tenant_a
     or v_res.plan_code is distinct from 'profesional'
     or v_res.amount_cop <> 120000
     or v_status is distinct from 'verificada' then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 2: el pago legitimo no resolvio bien (coincide=%, tenant=%, status=%).',
      v_res.coincide, v_res.tenant_id, v_status;
  else
    raise notice 'OK 2: resuelve al negocio correcto con los datos del servidor y queda verificada.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 3: EL ATAQUE DE TL-02, negocio cambiado en el payload ---';
  -- -------------------------------------------------------------------------
  select * into v_res
  from private.beautyos_resolver_intencion_pago(v_factura, v_tenant_b, 'ref-197-ataque');

  select status into v_status from public.subscription_payment_intents where id = v_id;

  if v_res.coincide then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 3 (CRITICO): se acepto una confirmacion con el negocio cambiado. TL-02 SIGUE ABIERTO.';
  elsif v_status is distinct from 'rechazada' then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 3b: se rechazo el pago pero la intencion no quedo marcada como rechazada (status=%).', v_status;
  else
    raise notice 'OK 3: rechazado. El negocio autoritativo sigue siendo % y no el del payload.', v_res.tenant_id;
    raise notice '       Motivo devuelto: %', v_res.motivo;
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 4: falla cerrado con una factura que no existe ---';
  -- -------------------------------------------------------------------------
  select * into v_res
  from private.beautyos_resolver_intencion_pago('SUB-NO-EXISTE-197', v_tenant_a, null::text);

  if v_res.coincide or v_res.tenant_id is not null then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 4 (CRITICO): una factura sin intencion registrada resolvio a un negocio.';
  else
    raise notice 'OK 4: sin intencion registrada no se activa nada.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 5: falla cerrado sin numero de factura ---';
  -- -------------------------------------------------------------------------
  select * into v_res
  from private.beautyos_resolver_intencion_pago(null::text, v_tenant_a, null::text);

  if v_res.coincide then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 5 (CRITICO): una confirmacion sin factura resolvio a un negocio.';
  else
    raise notice 'OK 5: sin factura no se activa nada.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 6: reabrir el checkout actualiza, no duplica ---';
  -- -------------------------------------------------------------------------
  perform private.beautyos_registrar_intencion_pago(
    v_factura, v_tenant_a, 'business', null, 100000::bigint, null
  );

  select count(*) into v_conteo
  from public.subscription_payment_intents where invoice_number = v_factura;

  select plan_code, amount_cop into v_status, v_monto
  from public.subscription_payment_intents where invoice_number = v_factura;

  if v_conteo <> 1 or v_status is distinct from 'business' or v_monto <> 100000 then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 6: la reapertura no actualizo en su sitio (filas=%, plan=%, monto=%).', v_conteo, v_status, v_monto;
  else
    raise notice 'OK 6: una sola fila por factura, actualizada con el plan y el monto nuevos.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 7: no se registra una intencion por cero o menos ---';
  -- -------------------------------------------------------------------------
  begin
    perform private.beautyos_registrar_intencion_pago(
      'SUB-TEST197-CERO', v_tenant_a, 'basico', null, 0::bigint, null
    );
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 7: se acepto una intencion de pago por 0 COP.';
  exception when others then
    raise notice 'OK 7: rechazada la intencion por 0 COP (%).', sqlerrm;
  end;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 8: la tabla tiene RLS activo ---';
  -- -------------------------------------------------------------------------
  select relrowsecurity into v_rls
  from pg_class
  where oid = 'public.subscription_payment_intents'::regclass;

  if not coalesce(v_rls, false) then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 8: subscription_payment_intents no tiene RLS activado.';
  else
    raise notice 'OK 8: RLS activo (deny-all, sin politicas: solo se accede por las funciones).';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 9: nadie salvo el servidor puede tocar esto ---';
  -- -------------------------------------------------------------------------
  if has_table_privilege('anon', 'public.subscription_payment_intents', 'SELECT')
     or has_table_privilege('authenticated', 'public.subscription_payment_intents', 'SELECT') then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 9: anon o authenticated conservan SELECT sobre la tabla.';
  else
    raise notice 'OK 9: anon y authenticated no tienen acceso a la tabla.';
  end if;

  if has_function_privilege('anon',
       'private.beautyos_resolver_intencion_pago(text, uuid, text)', 'EXECUTE')
     or has_function_privilege('authenticated',
       'private.beautyos_resolver_intencion_pago(text, uuid, text)', 'EXECUTE') then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 9b (CRITICO): anon o authenticated pueden ejecutar la funcion que resuelve pagos.';
  else
    raise notice 'OK 9b: la funcion que resuelve pagos solo la puede ejecutar service_role.';
  end if;

  if has_function_privilege('anon',
       'private.beautyos_registrar_intencion_pago(text, uuid, text, uuid, bigint, uuid)', 'EXECUTE')
     or has_function_privilege('authenticated',
       'private.beautyos_registrar_intencion_pago(text, uuid, text, uuid, bigint, uuid)', 'EXECUTE') then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 9c (CRITICO): anon o authenticated pueden registrar intenciones de pago.';
  else
    raise notice 'OK 9c: registrar intenciones solo lo puede hacer service_role.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '======================================================================';
  if v_fallos = 0 then
    raise notice 'CONTROL 197: TODOS LOS CASOS EN VERDE. TL-02 cerrado en base de datos.';
  else
    raise exception 'CONTROL 197: % caso(s) fallaron. Revisar arriba.', v_fallos;
  end if;
  raise notice '======================================================================';
end;
$$;

rollback;
