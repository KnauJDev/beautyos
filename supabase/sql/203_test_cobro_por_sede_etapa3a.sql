-- CONTROL 203: Cobro por sede, la base (D-191, Etapa 3a de D-188).
--
-- POR QUÉ ESTE ARCHIVO
--
-- La migración 20260902140000 le enseña sedes a la intención de pago (D-182) y
-- crea `beautyos_calcular_cargo_sede`, con el prorrateo hasta la fecha de corte
-- del negocio.
--
-- Este control valida transaccionalmente:
--   - `subscription_payment_intents` tiene `branch_id`, y una intención SIN
--     sede sigue funcionando: es el cobro del negocio de siempre.
--   - Una intención CON sede la guarda y la devuelve al resolverla.
--   - Una sede que no es de ese negocio se rechaza al registrar la intención
--     (misma clase de comprobación que cerró TL-01).
--   - **El ataque de TL-02 sigue cerrado**: cambiar el negocio en el payload
--     rechaza el pago, ahora también devolviendo la sede.
--   - Una sede nueva a mitad del ciclo del negocio se cobra PRORRATEADA hasta
--     la fecha de corte, no un mes completo.
--   - Y si el negocio no tiene ciclo vivo, la sede estrena mes completo.
--   - La renovación anticipada de una sede no corre su ancla.
--   - Ninguna de las tres funciones la alcanza `authenticated`.
--
-- CÓMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\203_test_cobro_por_sede_etapa3a.sql"
--
-- TERMINA EN ROLLBACK. Todos los datos de prueba se descartan limpiamente.

begin;

do $$
declare
  v_fallos integer := 0;
  v_tenant uuid;
  v_otro_tenant uuid;
  v_branch uuid;
  v_factura_negocio text := 'SUB-TEST203-NEG-' || extract(epoch from now())::bigint::text;
  v_factura_sede text := 'SUB-TEST203-SED-' || extract(epoch from now())::bigint::text;
  v_res record;
  v_cargo record;
  v_precio bigint;
  v_esperado bigint;
  v_dias numeric;
  v_existe boolean;
begin
  raise notice '======================================================================';
  raise notice 'CONTROL 203 - Cobro por sede, la base (D-191, Etapa 3a)';
  raise notice '======================================================================';

  select ts.tenant_id into v_tenant
  from public.tenant_subscriptions ts order by ts.created_at limit 1;

  if v_tenant is null then
    raise exception 'No hay ninguna suscripcion de negocio: este control necesita al menos una.';
  end if;

  select id into v_otro_tenant from public.tenants where id <> v_tenant limit 1;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 1: la columna existe y una intencion SIN sede sigue valiendo ---';
  -- -------------------------------------------------------------------------
  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'subscription_payment_intents'
      and column_name = 'branch_id'
  ) into v_existe;

  if not v_existe then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 1: falta subscription_payment_intents.branch_id.';
  end if;

  perform private.beautyos_registrar_intencion_pago(
    v_factura_negocio, v_tenant, 'pro', null, 150000::bigint, null
  );

  select * into v_res
  from private.beautyos_resolver_intencion_pago(v_factura_negocio, v_tenant, 'ref-203-neg');

  if not v_res.coincide then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 1b (CRITICO): una intencion sin sede dejo de funcionar. '
      'Eso rompe los cobros que ya existen.';
  elsif v_res.branch_id is not null then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 1c: una intencion sin sede devolvio sede.';
  else
    raise notice 'OK 1: el cobro del negocio entero sigue funcionando igual.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 2: una intencion CON sede guarda y devuelve la sede ---';
  -- -------------------------------------------------------------------------
  insert into public.branches (tenant_id, name, slug, active, is_primary)
  values (v_tenant, 'Sede Control 203', 'sede-control-203', true, false)
  returning id into v_branch;

  perform private.beautyos_registrar_intencion_pago(
    v_factura_sede, v_tenant, 'pro', null, 75000::bigint, null, v_branch
  );

  select * into v_res
  from private.beautyos_resolver_intencion_pago(v_factura_sede, v_tenant, 'ref-203-sed');

  if not v_res.coincide then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 2: la intencion con sede no resolvio.';
  elsif v_res.branch_id is distinct from v_branch then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 2b (CRITICO): resolvio a la sede % en vez de a la %. '
      'El webhook activaria la sede equivocada.', v_res.branch_id, v_branch;
  else
    raise notice 'OK 2: la factura resuelve a su sede.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 3: una sede de OTRO negocio se rechaza al registrar ---';
  -- -------------------------------------------------------------------------
  if v_otro_tenant is null then
    raise notice 'AVISO 3: solo hay un negocio, no se puede probar la sede ajena.';
  else
    begin
      perform private.beautyos_registrar_intencion_pago(
        'SUB-TEST203-AJENA', v_otro_tenant, 'pro', null, 150000::bigint, null, v_branch
      );
      v_fallos := v_fallos + 1;
      raise warning 'FALLO 3 (CRITICO): se registro una intencion con la sede de otro negocio. '
        'Es la misma clase de agujero que cerro TL-01.';
    exception when others then
      raise notice 'OK 3: la sede tiene que ser del negocio que paga (%).', sqlerrm;
    end;
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 4: el ataque de TL-02 sigue cerrado ---';
  -- -------------------------------------------------------------------------
  if v_otro_tenant is null then
    raise notice 'AVISO 4: solo hay un negocio, no se puede probar el cambio de negocio.';
  else
    select * into v_res
    from private.beautyos_resolver_intencion_pago(v_factura_sede, v_otro_tenant, 'ref-203-ataque');

    if v_res.coincide then
      v_fallos := v_fallos + 1;
      raise warning 'FALLO 4 (CRITICO): se acepto una confirmacion con el negocio cambiado. '
        'TL-02 SE REABRIO.';
    else
      raise notice 'OK 4: rechazado, y el negocio autoritativo sigue siendo el de la factura.';
    end if;
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 5: sede nueva a mitad de ciclo, PRORRATEADA ---';
  -- -------------------------------------------------------------------------
  --
  -- Se le da al negocio un corte dentro de 10 dias y se comprueba que la sede
  -- se enganche a esa fecha en vez de estrenar 30 dias por su cuenta.
  update public.tenant_subscriptions
  set current_period_end = now() + interval '10 days'
  where tenant_id = v_tenant;

  select precio_cop into v_precio
  from private.beautyos_precio_efectivo_sede(v_branch);

  select * into v_cargo from private.beautyos_calcular_cargo_sede(v_branch);

  if v_cargo is null then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 5: no se pudo calcular el cargo de la sede.';
  elsif v_cargo.motivo is distinct from 'alta_de_sede_prorrateada' then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 5b: el motivo fue "%" y se esperaba alta_de_sede_prorrateada.', v_cargo.motivo;
  else
    v_dias := ceil(extract(epoch from (v_cargo.periodo_fin - now())) / 86400.0);
    v_esperado := ceil(v_precio * v_dias / 30.0);

    if v_cargo.monto_cop is distinct from v_esperado then
      v_fallos := v_fallos + 1;
      raise warning 'FALLO 5c: cobro % y por % dias sobre % deberia ser %.',
        v_cargo.monto_cop, v_dias, v_precio, v_esperado;
    elsif v_cargo.monto_cop >= v_precio then
      v_fallos := v_fallos + 1;
      raise warning 'FALLO 5d: el prorrateo cobro % , que no es menos que el mes completo (%).',
        v_cargo.monto_cop, v_precio;
    else
      raise notice 'OK 5: % por % dias, en vez de % del mes completo.',
        v_cargo.monto_cop, v_dias, v_precio;
      raise notice '       Y termina el mismo dia que el corte del negocio: %', v_cargo.periodo_fin;
    end if;
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 6: sin ciclo vivo en el negocio, la sede estrena mes completo ---';
  -- -------------------------------------------------------------------------
  update public.tenant_subscriptions
  set current_period_end = null
  where tenant_id = v_tenant;

  select * into v_cargo from private.beautyos_calcular_cargo_sede(v_branch);

  if v_cargo.motivo is distinct from 'alta_de_sede_primer_ciclo' then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 6: el motivo fue "%" y se esperaba alta_de_sede_primer_ciclo.', v_cargo.motivo;
  elsif v_cargo.monto_cop is distinct from v_precio then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 6b: cobro % y el mes completo son %.', v_cargo.monto_cop, v_precio;
  else
    raise notice 'OK 6: sin ancla del negocio, la sede estrena su propio ciclo de 30 dias.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 7: la renovacion anticipada NO corre el ancla ---';
  -- -------------------------------------------------------------------------
  update public.branch_subscriptions
  set status = 'active',
      current_period_end = now() + interval '8 days'
  where branch_id = v_branch;

  select * into v_cargo from private.beautyos_calcular_cargo_sede(v_branch);

  if v_cargo.motivo is distinct from 'renovacion_anticipada' then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 7: el motivo fue "%" y se esperaba renovacion_anticipada.', v_cargo.motivo;
  elsif v_cargo.monto_cop is distinct from v_precio then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 7b: la renovacion anticipada deberia costar el mes completo (%), y cobro %.',
      v_precio, v_cargo.monto_cop;
  elsif v_cargo.periodo_inicio <= now() then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 7c (CRITICO): el periodo nuevo empieza ya y no al terminar el vigente. '
      'Pagar antes le estaria REGALANDO dias al cliente, o quitandoselos.';
  else
    raise notice 'OK 7: el mes nuevo se acumula al final del vigente. La ancla no se corre.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 8: las tres funciones son solo del servidor ---';
  -- -------------------------------------------------------------------------
  if has_function_privilege('authenticated',
       'private.beautyos_calcular_cargo_sede(uuid)', 'EXECUTE')
     or has_function_privilege('authenticated',
       'private.beautyos_registrar_intencion_pago(text, uuid, text, uuid, bigint, uuid, uuid)', 'EXECUTE')
     or has_function_privilege('authenticated',
       'private.beautyos_resolver_intencion_pago(text, uuid, text)', 'EXECUTE') then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 8 (CRITICO): authenticated alcanza alguna funcion de cobro.';
  else
    raise notice 'OK 8: solo service_role.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '======================================================================';
  if v_fallos = 0 then
    raise notice 'CONTROL 203: TODOS LOS CASOS EN VERDE. Etapa 3a lista.';
    raise notice 'RECORDATORIO: las Edge Functions todavia NO mandan branch_id.';
    raise notice 'Esta migracion es compatible hacia atras a proposito: se puede';
    raise notice 'aplicar sin desplegar nada. La 3b conecta el checkout y el webhook.';
  else
    raise exception 'CONTROL 203: % caso(s) fallaron. Revisar arriba.', v_fallos;
  end if;
  raise notice '======================================================================';
end;
$$;

rollback;
