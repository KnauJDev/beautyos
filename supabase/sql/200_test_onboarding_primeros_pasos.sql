-- CONTROL 200: Paso 8.8 -- Onboarding guiado "Primeros pasos" (D-186).
--
-- POR QUÉ ESTE ARCHIVO
--
-- La migración 20260901180000 introduce:
--   1. public.tenants.onboarding_dismissed_at
--   2. public.get_onboarding_progress(p_branch_id uuid)
--   3. public.dismiss_onboarding()
--
-- Este control valida transaccionalmente:
--   - La columna existe.
--   - Las dos funciones existen, son SECURITY DEFINER y están revocadas de
--     `anon` (la lista es del negocio, no de un visitante).
--   - Una sede recién creada no cuenta ningún paso.
--   - Un servicio del catálogo que NO está activo en la sede NO cuenta: lo que
--     se mide es si se puede agendar EN ESTA SEDE, no tener catálogo.
--   - Activarlo en la sede sí cuenta.
--   - Un estilista activo en la sede cuenta igual.
--   - Descartar la lista deja fecha, y hacerlo dos veces no la mueve.
--
-- El horario y la primera cita no se montan aquí: `business_hours` es por
-- negocio (así que tocarlo afectaría al salón real dentro de la transacción,
-- aunque se deshaga) y crear un ticket arrastra media docena de tablas. Sus dos
-- comprobaciones son `exists` de una línea y se ven en la propia función.
--
-- Lo que este control NO cubre: `get_onboarding_progress` y `dismiss_onboarding`
-- exigen sesión de owner/admin (`get_my_tenant_id`, `is_owner_or_admin`), que no
-- existe en una sesión de psql. Por eso los casos de conteo se comprueban con
-- las MISMAS consultas que usa la función, sobre datos de prueba reales, y
-- aparte se verifica que la función está declarada como debe.
--
-- CÓMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\200_test_onboarding_primeros_pasos.sql"
--
-- TERMINA EN ROLLBACK. Todos los datos de prueba se descartan limpiamente.

begin;

do $$
declare
  v_fallos integer := 0;
  v_tenant uuid;
  v_branch uuid;
  v_servicio uuid;
  v_estilista uuid;
  v_existe boolean;
  v_secdef boolean;
  v_completos integer;
  v_fecha timestamptz;
  v_fecha2 timestamptz;
begin
  raise notice '======================================================================';
  raise notice 'CONTROL 200 - Onboarding "Primeros pasos" (paso 8.8 / D-186)';
  raise notice '======================================================================';

  select id into v_tenant from public.tenants order by created_at limit 1;
  if v_tenant is null then
    raise exception 'No hay ningun negocio en public.tenants: este control necesita al menos uno.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 1: la columna de descarte existe ---';
  -- -------------------------------------------------------------------------
  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'tenants'
      and column_name = 'onboarding_dismissed_at'
  ) into v_existe;

  if not v_existe then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 1: falta public.tenants.onboarding_dismissed_at.';
  else
    raise notice 'OK 1: columna presente.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 2: las dos funciones existen y son SECURITY DEFINER ---';
  -- -------------------------------------------------------------------------
  select p.prosecdef into v_secdef
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'get_onboarding_progress';

  if v_secdef is null then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 2: no existe public.get_onboarding_progress.';
  elsif not v_secdef then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 2b: get_onboarding_progress no es SECURITY DEFINER.';
  else
    raise notice 'OK 2: get_onboarding_progress presente y SECURITY DEFINER.';
  end if;

  select p.prosecdef into v_secdef
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'dismiss_onboarding';

  if v_secdef is null or not v_secdef then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 2c: dismiss_onboarding falta o no es SECURITY DEFINER.';
  else
    raise notice 'OK 2c: dismiss_onboarding presente y SECURITY DEFINER.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 3: ninguna de las dos la puede ejecutar anon ---';
  -- -------------------------------------------------------------------------
  if has_function_privilege('anon', 'public.get_onboarding_progress(uuid)', 'EXECUTE')
     or has_function_privilege('anon', 'public.dismiss_onboarding()', 'EXECUTE') then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 3 (CRITICO): anon puede consultar los primeros pasos de un negocio.';
  else
    raise notice 'OK 3: anon no alcanza ninguna de las dos.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 4: una sede recien creada da 0 de 4 ---';
  -- -------------------------------------------------------------------------
  insert into public.branches (tenant_id, name, slug, active, is_primary)
  values (v_tenant, 'Sede Control 200', 'sede-control-200', true, false)
  returning id into v_branch;

  v_completos :=
    (exists (select 1 from public.services s
             join public.branch_services bs on bs.tenant_id = v_tenant
              and bs.branch_id = v_branch and bs.service_id = s.id
             where s.tenant_id = v_tenant and s.active and bs.active))::int
  + (exists (select 1 from public.stylists st
             join public.branch_stylists bst on bst.tenant_id = v_tenant
              and bst.branch_id = v_branch and bst.stylist_id = st.id
             where st.tenant_id = v_tenant and st.active and bst.active))::int
  + (exists (select 1 from public.tickets t where t.branch_id = v_branch))::int;

  if v_completos <> 0 then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 4: una sede nueva ya cuenta % paso(s) de catalogo/citas.', v_completos;
  else
    raise notice 'OK 4: sede nueva sin servicios, sin equipo y sin citas.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 5: un servicio del catalogo que NO esta activo en la sede no cuenta ---';
  -- -------------------------------------------------------------------------
  insert into public.services (tenant_id, name, duration_minutes, price, active)
  values (v_tenant, 'Servicio Control 200', 30, 30000, true)
  returning id into v_servicio;

  insert into public.branch_services (tenant_id, branch_id, service_id, price, duration_minutes, active)
  values (v_tenant, v_branch, v_servicio, 30000, 30, false);

  select exists (
    select 1 from public.services s
    join public.branch_services bs on bs.tenant_id = v_tenant
     and bs.branch_id = v_branch and bs.service_id = s.id
    where s.tenant_id = v_tenant and s.active and bs.active
  ) into v_existe;

  if v_existe then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 5: un servicio desactivado en la sede esta contando como hecho.';
  else
    raise notice 'OK 5: lo que se mide es poder agendar EN ESTA SEDE, no tener catalogo.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 6: activarlo en la sede si cuenta ---';
  -- -------------------------------------------------------------------------
  update public.branch_services set active = true
  where tenant_id = v_tenant and branch_id = v_branch and service_id = v_servicio;

  select exists (
    select 1 from public.services s
    join public.branch_services bs on bs.tenant_id = v_tenant
     and bs.branch_id = v_branch and bs.service_id = s.id
    where s.tenant_id = v_tenant and s.active and bs.active
  ) into v_existe;

  if not v_existe then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 6: un servicio activo en la sede no cuenta.';
  else
    raise notice 'OK 6: el primer paso queda hecho.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 7: el equipo cuenta igual, por sede ---';
  -- -------------------------------------------------------------------------
  insert into public.stylists (tenant_id, name, active)
  values (v_tenant, 'Estilista Control 200', true)
  returning id into v_estilista;

  insert into public.branch_stylists (tenant_id, branch_id, stylist_id, active)
  values (v_tenant, v_branch, v_estilista, true);

  select exists (
    select 1 from public.stylists st
    join public.branch_stylists bst on bst.tenant_id = v_tenant
     and bst.branch_id = v_branch and bst.stylist_id = st.id
    where st.tenant_id = v_tenant and st.active and bst.active
  ) into v_existe;

  if not v_existe then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 7: un estilista activo en la sede no cuenta.';
  else
    raise notice 'OK 7: segundo paso hecho.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 8: descartar deja la fecha, y es idempotente ---';
  -- -------------------------------------------------------------------------
  update public.tenants set onboarding_dismissed_at = null where id = v_tenant;

  update public.tenants
  set onboarding_dismissed_at = now()
  where id = v_tenant and onboarding_dismissed_at is null;

  select onboarding_dismissed_at into v_fecha
  from public.tenants where id = v_tenant;

  -- Segunda pasada: la fecha NO se debe mover (misma condicion que la funcion).
  update public.tenants
  set onboarding_dismissed_at = now()
  where id = v_tenant and onboarding_dismissed_at is null;

  select onboarding_dismissed_at into v_fecha2
  from public.tenants where id = v_tenant;

  if v_fecha is null then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 8: descartar no dejo fecha.';
  elsif v_fecha2 is distinct from v_fecha then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 8b: descartar dos veces movio la fecha (% -> %).', v_fecha, v_fecha2;
  else
    raise notice 'OK 8: fecha puesta una sola vez, idempotente.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '======================================================================';
  if v_fallos = 0 then
    raise notice 'CONTROL 200: TODOS LOS CASOS EN VERDE. Paso 8.8 listo en base de datos.';
  else
    raise exception 'CONTROL 200: % caso(s) fallaron. Revisar arriba.', v_fallos;
  end if;
  raise notice '======================================================================';
end;
$$;

rollback;
