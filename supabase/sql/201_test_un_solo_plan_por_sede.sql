-- CONTROL 201: Un solo plan "Todo Incluido" (D-188, Etapa 1 de 3).
--
-- POR QUÉ ESTE ARCHIVO
--
-- La migración 20260901200000 retira la escalera de tres planes (D-124, D-136)
-- y deja uno solo con todo dentro, a $120.000 de lista por sede.
--
-- Este control valida transaccionalmente:
--   - Existe el plan `pro` a $120.000, activo.
--   - Los tres viejos quedaron en `retired` y NO se borraron (el histórico de
--     pagos y las suscripciones los referencian).
--   - `list_public_plans()` devuelve UN SOLO plan.
--   - Ese plan trae las cuatro capacidades de software encendidas y sin tope.
--   - Sedes y cuentas de equipo quedan sin tope: estilistas ilimitados.
--   - `social_publishing` sigue APAGADA: es Fase 6 y no existe. El Plan
--     Maestro prohíbe venderla antes de construirla.
--   - Ningún negocio quedó apuntando a un plan retirado.
--   - Un tenant del plan nuevo resuelve TODAS las capacidades en `true` a
--     través de `beautyos_resolve_entitlement`, sin haber tocado esa función.
--   - Los pioneros tienen precio pactado de $80.000, no un porcentaje: el
--     33,33% de 120.000 da 80.004 y el checkout mostraría un número raro.
--
-- CÓMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\201_test_un_solo_plan_por_sede.sql"
--
-- TERMINA EN ROLLBACK. Todos los datos de prueba se descartan limpiamente.

begin;

do $$
declare
  v_fallos integer := 0;
  v_plan_id uuid;
  v_precio bigint;
  v_estado text;
  v_conteo integer;
  v_planes_publicos integer;
  v_tenant uuid;
  v_r record;
  v_clave text;
begin
  raise notice '======================================================================';
  raise notice 'CONTROL 201 - Un solo plan "Todo Incluido" (D-188, Etapa 1)';
  raise notice '======================================================================';

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 1: el plan unico existe, activo y a 120.000 ---';
  -- -------------------------------------------------------------------------
  select id, price_cop, status into v_plan_id, v_precio, v_estado
  from public.plans where code = 'pro' and version = 1;

  if v_plan_id is null then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 1 (CRITICO): no existe el plan `pro`.';
  elsif v_precio <> 120000 then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 1b: el precio de lista es % y deberia ser 120000.', v_precio;
  elsif v_estado <> 'active' then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 1c: el plan unico no esta activo (%).', v_estado;
  else
    raise notice 'OK 1: plan `pro` activo a $120.000 por sede.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 2: los tres viejos retirados, NO borrados ---';
  -- -------------------------------------------------------------------------
  select count(*) into v_conteo
  from public.plans
  where code in ('basico', 'business', 'profesional');

  if v_conteo <> 3 then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 2 (CRITICO): se borro alguno de los planes viejos (quedan %). '
      'El historico de pagos y las suscripciones los referencian.', v_conteo;
  end if;

  select count(*) into v_conteo
  from public.plans
  where code in ('basico', 'business', 'profesional')
    and status <> 'retired';

  if v_conteo <> 0 then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 2b: % plan(es) viejo(s) siguen sin retirar.', v_conteo;
  else
    raise notice 'OK 2: los tres viejos siguen existiendo, retirados.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 3: la pantalla publica ve UN SOLO plan ---';
  -- -------------------------------------------------------------------------
  select count(distinct plan_code) into v_planes_publicos
  from public.list_public_plans();

  if v_planes_publicos <> 1 then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 3: list_public_plans() devuelve % planes distintos.', v_planes_publicos;
  else
    raise notice 'OK 3: la pantalla publica ve un solo plan.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 4: todo dentro y sin topes ---';
  -- -------------------------------------------------------------------------
  foreach v_clave in array array['inventory', 'financial_reports', 'portfolio',
                                 'reviews', 'branches', 'team_members']
  loop
    select pf.enabled, pf.limit_value into v_r
    from public.plan_features pf
    join public.features f on f.id = pf.feature_id
    where pf.plan_id = v_plan_id and f.key = v_clave;

    if v_r is null then
      v_fallos := v_fallos + 1;
      raise warning 'FALLO 4: el plan unico no declara la capacidad %.', v_clave;
    elsif not v_r.enabled then
      v_fallos := v_fallos + 1;
      raise warning 'FALLO 4b: % viene apagada en el plan unico.', v_clave;
    elsif v_r.limit_value is not null then
      v_fallos := v_fallos + 1;
      raise warning 'FALLO 4c: % tiene tope de % y deberia ser sin limite.', v_clave, v_r.limit_value;
    else
      raise notice 'OK 4: % encendida y sin tope.', v_clave;
    end if;
  end loop;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 5: social_publishing sigue APAGADA (Fase 6, no existe) ---';
  -- -------------------------------------------------------------------------
  select pf.enabled into v_estado
  from public.plan_features pf
  join public.features f on f.id = pf.feature_id
  where pf.plan_id = v_plan_id and f.key = 'social_publishing';

  if v_estado is null then
    raise notice 'OK 5: social_publishing ni siquiera se declara. Correcto: no existe.';
  elsif v_estado::boolean then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 5 (CRITICO): se esta vendiendo social_publishing, que es Fase 6 y NO ESTA '
      'CONSTRUIDA. El Plan Maestro lo prohibe expresamente.';
  else
    raise notice 'OK 5: apagada. No se vende lo que no existe.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 6: ningun negocio quedo en un plan retirado ---';
  -- -------------------------------------------------------------------------
  select count(*) into v_conteo
  from public.tenant_subscriptions ts
  join public.plans p on p.id = ts.plan_id
  where p.status = 'retired';

  if v_conteo > 0 then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 6: % negocio(s) siguen apuntando a un plan retirado.', v_conteo;
  else
    raise notice 'OK 6: todos los negocios migrados al plan unico.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 7: un negocio del plan nuevo resuelve TODO en true ---';
  -- -------------------------------------------------------------------------
  --
  -- Esta es la comprobacion que importa de verdad: `get_my_entitlements` NO se
  -- toco. Si el plan trae todo dentro, la resolucion devuelve todo en `true`
  -- sola, conservando un solo sitio donde vive la verdad y dejando intactos
  -- los overrides por cliente del panel de plataforma (D-172).
  select ts.tenant_id into v_tenant
  from public.tenant_subscriptions ts
  join public.plans p on p.id = ts.plan_id
  where p.code = 'pro'
  limit 1;

  if v_tenant is null then
    raise notice 'AVISO 7: no hay ningun negocio en el plan nuevo, no se puede comprobar.';
  else
    foreach v_clave in array array['inventory', 'financial_reports', 'portfolio', 'reviews']
    loop
      select * into v_r from private.beautyos_resolve_entitlement(v_tenant, v_clave);

      if v_r is null or not v_r.entitled then
        v_fallos := v_fallos + 1;
        raise warning 'FALLO 7 (CRITICO): % sigue bloqueada para un negocio del plan Todo Incluido.', v_clave;
      else
        raise notice 'OK 7: % resuelta en true (origen: %).', v_clave, v_r.source;
      end if;
    end loop;
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 8: los pioneros con precio pactado, no con porcentaje ---';
  -- -------------------------------------------------------------------------
  select count(*) into v_conteo
  from public.tenant_subscriptions
  where is_founder = true
    and (price_cop is distinct from 80000 or discount_percent is not null);

  if v_conteo > 0 then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 8: % pionero(s) sin precio pactado de 80000, o con porcentaje vivo. '
      'El 33,33%% de 120.000 da 80.004 y el checkout mostraria ese numero.', v_conteo;
  else
    raise notice 'OK 8: los pioneros pagan $80.000 exactos por sede.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '======================================================================';
  if v_fallos = 0 then
    raise notice 'CONTROL 201: TODOS LOS CASOS EN VERDE. Etapa 1 de D-188 lista.';
    raise notice 'RECORDATORIO: el cobro POR SEDE es la Etapa 2 y 3. Hoy un negocio';
    raise notice 'paga una sola suscripcion aunque tenga varias sedes.';
  else
    raise exception 'CONTROL 201: % caso(s) fallaron. Revisar arriba.', v_fallos;
  end if;
  raise notice '======================================================================';
end;
$$;

rollback;
