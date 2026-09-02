-- CONTROL 202: Suscripción por sede (D-190, Etapa 2 de 3 de D-188).
--
-- POR QUÉ ESTE ARCHIVO
--
-- La migración 20260902120000 introduce:
--   1. public.branch_subscriptions
--   2. el disparador que le da suscripción pendiente a cada sede nueva
--   3. private.beautyos_precio_efectivo_sede(branch_id)
--   4. public.get_branch_subscriptions()
--   5. public.platform_set_branch_subscription(...)
--
-- Este control valida transaccionalmente:
--   - La tabla existe, tiene RLS y está revocada de `anon` y `authenticated`.
--   - **Las sedes que YA existían no quedaron marcadas como impagas**: heredan
--     el estado de la suscripción de su negocio. Se vendieron bajo "sedes
--     ilimitadas" y cobrarlas retroactivamente sería cambiarles el trato.
--   - Una sede NUEVA nace `pending`, por el disparador.
--   - El precio de una sede sin precio pactado es el de lista del plan.
--   - Con precio pactado, manda el pactado.
--   - Un precio pactado sin motivo se rechaza (mismo criterio que D-136).
--   - Un estado inventado se rechaza.
--   - `activated_at` se sella la PRIMERA vez y no se mueve después.
--   - Ninguna de las funciones de plataforma la alcanza `anon`.
--
-- Lo que este control NO cubre: `get_branch_subscriptions` y
-- `platform_set_branch_subscription` exigen sesión (owner/admin y plataforma),
-- que no existe en psql. Se comprueba que estén declaradas y con sus permisos,
-- y la lógica de estado y precio se ejercita por debajo, sobre las mismas
-- tablas y con la misma función de precio.
--
-- CÓMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\202_test_suscripcion_por_sede_etapa2.sql"
--
-- TERMINA EN ROLLBACK. Todos los datos de prueba se descartan limpiamente.

begin;

do $$
declare
  v_fallos integer := 0;
  v_tenant uuid;
  v_estado_tenant text;
  v_branch_nueva uuid;
  v_estado text;
  v_conteo integer;
  v_rls boolean;
  v_precio record;
  v_lista bigint;
  v_activado timestamptz;
  v_activado2 timestamptz;
begin
  raise notice '======================================================================';
  raise notice 'CONTROL 202 - Suscripcion por sede (D-190, Etapa 2)';
  raise notice '======================================================================';

  select ts.tenant_id, ts.status into v_tenant, v_estado_tenant
  from public.tenant_subscriptions ts
  order by ts.created_at
  limit 1;

  if v_tenant is null then
    raise exception 'No hay ninguna suscripcion de negocio: este control necesita al menos una.';
  end if;

  select p.price_cop into v_lista
  from public.tenant_subscriptions ts
  join public.plans p on p.id = ts.plan_id
  where ts.tenant_id = v_tenant;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 1: la tabla existe, con RLS y sin acceso directo ---';
  -- -------------------------------------------------------------------------
  select relrowsecurity into v_rls
  from pg_class where oid = 'public.branch_subscriptions'::regclass;

  if not coalesce(v_rls, false) then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 1: branch_subscriptions no tiene RLS activado.';
  elsif has_table_privilege('anon', 'public.branch_subscriptions', 'SELECT')
     or has_table_privilege('authenticated', 'public.branch_subscriptions', 'SELECT') then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 1b (CRITICO): anon o authenticated leen la tabla directamente.';
  else
    raise notice 'OK 1: RLS activo y sin acceso directo. Solo por las funciones.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 2: las sedes que YA existian no quedaron impagas ---';
  -- -------------------------------------------------------------------------
  --
  -- Es la decision de migracion de D-190: se vendieron bajo "sedes ilimitadas".
  select count(*) into v_conteo
  from public.branches b
  left join public.branch_subscriptions bs on bs.branch_id = b.id
  where b.tenant_id = v_tenant
    and bs.branch_id is null;

  if v_conteo > 0 then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 2: % sede(s) existentes se quedaron sin suscripcion.', v_conteo;
  end if;

  select count(*) into v_conteo
  from public.branches b
  join public.branch_subscriptions bs on bs.branch_id = b.id
  where b.tenant_id = v_tenant
    and bs.status is distinct from v_estado_tenant;

  if v_conteo > 0 then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 2b: % sede(s) existentes no heredaron el estado del negocio (%). '
      'Se vendieron bajo sedes ilimitadas: marcarlas impagas seria cambiarles el trato.',
      v_conteo, v_estado_tenant;
  else
    raise notice 'OK 2: las sedes existentes heredaron el estado "%" del negocio.', v_estado_tenant;
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 3: una sede NUEVA nace pendiente ---';
  -- -------------------------------------------------------------------------
  insert into public.branches (tenant_id, name, slug, active, is_primary)
  values (v_tenant, 'Sede Control 202', 'sede-control-202', true, false)
  returning id into v_branch_nueva;

  select status into v_estado
  from public.branch_subscriptions where branch_id = v_branch_nueva;

  if v_estado is null then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 3 (CRITICO): el disparador no le creo suscripcion a la sede nueva.';
  elsif v_estado <> 'pending' then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 3b: la sede nueva nacio en "%" y deberia nacer pendiente.', v_estado;
  else
    raise notice 'OK 3: la sede nueva nace pendiente de pago.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 4: sin precio pactado, cuesta el de lista ---';
  -- -------------------------------------------------------------------------
  select * into v_precio
  from private.beautyos_precio_efectivo_sede(v_branch_nueva);

  if v_precio is null then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 4: no se pudo calcular el precio de la sede.';
  elsif v_precio.precio_cop is distinct from v_lista then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 4b: la sede cuesta % y el de lista es %.', v_precio.precio_cop, v_lista;
  else
    raise notice 'OK 4: sin pactar, cuesta el de lista (%). Motivo: %', v_precio.precio_cop, v_precio.motivo;
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 5: con precio pactado, manda el pactado ---';
  -- -------------------------------------------------------------------------
  update public.branch_subscriptions
  set price_cop = 95000,
      price_reason = 'Tarifa de lanzamiento, control 202'
  where branch_id = v_branch_nueva;

  select * into v_precio
  from private.beautyos_precio_efectivo_sede(v_branch_nueva);

  if v_precio.precio_cop is distinct from 95000 then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 5: el precio pactado no manda (devolvio %).', v_precio.precio_cop;
  elsif v_precio.base_cop is distinct from v_lista then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 5b: se perdio el precio de lista de referencia.';
  else
    raise notice 'OK 5: pactado % sobre una lista de %.', v_precio.precio_cop, v_precio.base_cop;
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 6: un precio sin motivo se rechaza ---';
  -- -------------------------------------------------------------------------
  begin
    update public.branch_subscriptions
    set price_cop = 70000, price_reason = null
    where branch_id = v_branch_nueva;

    v_fallos := v_fallos + 1;
    raise warning 'FALLO 6: se acepto un precio pactado sin motivo. D-136 exige el porque.';
  exception when check_violation then
    raise notice 'OK 6: sin motivo no hay precio pactado.';
  end;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 7: un estado inventado se rechaza ---';
  -- -------------------------------------------------------------------------
  begin
    update public.branch_subscriptions
    set status = 'regalada'
    where branch_id = v_branch_nueva;

    v_fallos := v_fallos + 1;
    raise warning 'FALLO 7: se acepto un estado que no existe.';
  exception when check_violation then
    raise notice 'OK 7: los estados son los mismos que los del negocio, ni uno mas.';
  end;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 8: activated_at se sella una sola vez ---';
  -- -------------------------------------------------------------------------
  --
  -- Se ejercita la misma expresion que usa platform_set_branch_subscription.
  update public.branch_subscriptions
  set status = 'active',
      activated_at = coalesce(activated_at, now())
  where branch_id = v_branch_nueva;

  select activated_at into v_activado
  from public.branch_subscriptions where branch_id = v_branch_nueva;

  update public.branch_subscriptions
  set status = 'past_due',
      activated_at = coalesce(activated_at, now())
  where branch_id = v_branch_nueva;

  update public.branch_subscriptions
  set status = 'active',
      activated_at = coalesce(activated_at, now())
  where branch_id = v_branch_nueva;

  select activated_at into v_activado2
  from public.branch_subscriptions where branch_id = v_branch_nueva;

  if v_activado is null then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 8: al activar no se sello la fecha.';
  elsif v_activado2 is distinct from v_activado then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 8b: la fecha de primera activacion se movio (% -> %). '
      'Sirve para saber si una sede nunca llego a pagarse o si se cayo despues.',
      v_activado, v_activado2;
  else
    raise notice 'OK 8: la primera activacion queda sellada y no se mueve.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 9: anon no alcanza ninguna de las funciones ---';
  -- -------------------------------------------------------------------------
  if has_function_privilege('anon', 'public.get_branch_subscriptions()', 'EXECUTE')
     or has_function_privilege(
          'anon',
          'public.platform_set_branch_subscription(uuid, text, bigint, text, timestamptz)',
          'EXECUTE') then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 9 (CRITICO): anon alcanza el estado de pago de las sedes.';
  else
    raise notice 'OK 9: anon no alcanza ninguna de las dos.';
  end if;

  if has_function_privilege('authenticated', 'private.beautyos_precio_efectivo_sede(uuid)', 'EXECUTE') then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 9b: authenticated puede calcular precios de sede por su cuenta.';
  else
    raise notice 'OK 9b: el calculo de precio es solo del servidor.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '======================================================================';
  if v_fallos = 0 then
    raise notice 'CONTROL 202: TODOS LOS CASOS EN VERDE. Etapa 2 lista en base de datos.';
    raise notice 'RECORDATORIO: el cobro por ePayco SIGUE SIENDO POR NEGOCIO. La sede';
    raise notice 'nueva se activa a mano desde el panel hasta que llegue la Etapa 3.';
  else
    raise exception 'CONTROL 202: % caso(s) fallaron. Revisar arriba.', v_fallos;
  end if;
  raise notice '======================================================================';
end;
$$;

rollback;
