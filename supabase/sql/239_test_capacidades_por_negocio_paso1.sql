-- CONTROL 239: capacidades nuevas, encendidas para todos, y apagables por
-- negocio desde el Panel (paso 1 del plan del primer cliente real, D-310).
--
-- Que valida, transaccionalmente:
--   1. Existen `cash_register`, `commissions` y `blog`, y cada plan las trae
--      ENCENDIDAS (si faltara una fila, ese plan quedaria sin el modulo).
--   2. Un negocio en el plan activo las tiene permitidas, por el plan.
--   3. Apagarle una desde el Panel (`platform_set_tenant_feature_override`
--      con enabled = false) la niega, con source = 'override', y deja su
--      evento en el historial.
--   4. Apagarsela a uno no se la quita a otro negocio.
--   5. Quitar la excepcion (`platform_delete_tenant_feature_override`) la
--      devuelve al plan.
--
-- COMO SE EJECUTA (despues de aplicar 20261002180000_capacidades_por_negocio_paso1.sql)
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\239_test_capacidades_por_negocio_paso1.sql"
--
-- TERMINA EN ROLLBACK.
--
-- Datos de prueba copiados de controles que pasaron (regla 25d): el negocio,
-- su suscripcion y su sede, del 237 (30-sep); el operador de plataforma que
-- ya existe, del 231, aqui exigiendo el rol platform_owner, que es el que
-- piden las funciones de excepciones.

begin;

do $ctrl$
declare
  v_plan      uuid;
  v_planes    integer;
  v_operador  uuid;
  v_tenant    uuid;
  v_otro      uuid;
  v_override  uuid;
  v_clave     text;
  v_n         integer;
  r           record;
begin
  -- 1. Las tres existen y cada plan las trae encendidas
  select count(*) into v_planes from public.plans;
  foreach v_clave in array array['cash_register', 'commissions', 'blog'] loop
    if not exists (select 1 from public.features where key = v_clave) then
      raise exception 'FALLO 1: no existe la capacidad %', v_clave;
    end if;
    select count(*) into v_n
    from public.plan_features pf
    join public.features f on f.id = pf.feature_id
    where f.key = v_clave and pf.enabled;
    if v_n <> v_planes then
      raise exception 'FALLO 1b: % esta encendida en % de % planes', v_clave, v_n, v_planes;
    end if;
  end loop;
  raise notice 'OK 1   caja, comisiones y blog existen, encendidas en los % planes', v_planes;

  -- Datos de prueba
  select id into v_plan from public.plans where code = 'pro' and status = 'active' limit 1;
  if v_plan is null then
    raise exception 'FALLO: no hay plan pro activo con el que probar';
  end if;

  select po.user_id into v_operador
  from public.platform_operators po
  where po.active and po.role = 'platform_owner'
  limit 1;
  if v_operador is null then
    raise exception 'FALLO: no hay ningun platform_owner activo con el que probar';
  end if;

  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 239', 'barberia', 'c239@salonymas.com', '3000000239', true)
  returning id into v_tenant;
  insert into public.tenant_subscriptions (
    tenant_id, plan_id, status, current_period_start, current_period_end
  ) values (
    v_tenant, v_plan, 'active', now() - interval '10 days', now() + interval '20 days'
  );

  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 239 otro', 'barberia', 'c239b@salonymas.com', '3000000240', true)
  returning id into v_otro;
  insert into public.tenant_subscriptions (
    tenant_id, plan_id, status, current_period_start, current_period_end
  ) values (
    v_otro, v_plan, 'active', now() - interval '10 days', now() + interval '20 days'
  );

  -- 2. Por el plan, las tiene
  foreach v_clave in array array['cash_register', 'commissions', 'blog'] loop
    select * into r from private.beautyos_resolve_entitlement(v_tenant, v_clave);
    if not r.entitled or r.source <> 'plan' then
      raise exception 'FALLO 2: % da entitled=% source=% y debia ser true por el plan', v_clave, r.entitled, r.source;
    end if;
  end loop;
  raise notice 'OK 2   un negocio del plan activo tiene las tres, por el plan';

  -- 3. Apagarle la caja desde el Panel
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_operador::text, 'role', 'authenticated')::text, true);

  select o.override_id into v_override
  from public.platform_set_tenant_feature_override(
    v_tenant, 'cash_register', false, null, 'Control 239: apagado desde el Panel', null
  ) o;

  select * into r from private.beautyos_resolve_entitlement(v_tenant, 'cash_register');
  if r.entitled or r.source <> 'override' then
    raise exception 'FALLO 3: tras apagarla, la caja da entitled=% source=%', r.entitled, r.source;
  end if;
  if not exists (
    select 1 from public.subscription_events
    where tenant_id = v_tenant and event_type = 'feature_override_granted'
      and payload->>'feature_key' = 'cash_register' and payload->>'enabled' = 'false'
  ) then
    raise exception 'FALLO 3b: apagar la caja no dejo su evento en el historial';
  end if;
  raise notice 'OK 3   apagada desde el Panel: negada, por excepcion, y queda en el historial';

  -- 4. Al otro negocio no se le toca
  select * into r from private.beautyos_resolve_entitlement(v_otro, 'cash_register');
  if not r.entitled then
    raise exception 'FALLO 4: apagarle la caja a un negocio se la quito a otro';
  end if;
  raise notice 'OK 4   apagarla a uno no se la quita a otro negocio';

  -- 5. Quitar la excepcion la devuelve al plan
  perform public.platform_delete_tenant_feature_override(v_override);
  select * into r from private.beautyos_resolve_entitlement(v_tenant, 'cash_register');
  if not r.entitled or r.source <> 'plan' then
    raise exception 'FALLO 5: tras quitar la excepcion, la caja da entitled=% source=%', r.entitled, r.source;
  end if;
  raise notice 'OK 5   quitar la excepcion la devuelve al plan';

  perform set_config('request.jwt.claims', '{}', true);

  raise notice '--- CONTROL 239: 5/5 ---';
end
$ctrl$;

rollback;
