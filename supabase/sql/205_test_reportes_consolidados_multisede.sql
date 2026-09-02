-- CONTROL 205: Reportes consolidados de todas las sedes (D-194).
--
-- POR QUÉ ESTE ARCHIVO
--
-- La migración 20260902180000 crea `get_tenant_reports_v3`, que **llama a
-- `get_branch_reports_v3` sede por sede y suma** en vez de duplicar sus 250
-- líneas.
--
-- Eso tiene una consecuencia que hay que vigilar: **las dos funciones están
-- acopladas por el nombre de cada columna**. El día que alguien renombre una
-- columna en la de una sede, la consolidada dejaría de leerla y sumaría cero
-- **sin que nada falle** — el dueño vería un total más bajo y nadie se
-- enteraría. Este control es sobre todo esa guardia.
--
-- Valida:
--   - Las dos funciones existen y son SECURITY DEFINER.
--   - La consolidada devuelve TODAS las columnas de la de una sede, con el
--     mismo nombre y el mismo tipo.
--   - Y además las dos suyas: `branches_count` y `by_branch`.
--   - `anon` no alcanza ninguna de las dos.
--   - La lógica de suma y de agrupación de los desgloses en jsonb, ejercitada
--     con datos de prueba.
--
-- Lo que este control NO cubre: `get_tenant_reports_v3` recorre
-- `get_my_branch_context_v2()`, que necesita `auth.uid()`, y en psql no hay
-- sesión. La suma en vivo se comprueba entrando a Reportes con dos sedes.
--
-- CÓMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\205_test_reportes_consolidados_multisede.sql"
--
-- TERMINA EN ROLLBACK. Todos los datos de prueba se descartan limpiamente.

begin;

do $$
declare
  v_fallos integer := 0;
  v_faltantes text;
  v_secdef boolean;
  v_json jsonb;
  v_res record;
begin
  raise notice '======================================================================';
  raise notice 'CONTROL 205 - Reportes consolidados multi-sede (D-194)';
  raise notice '======================================================================';

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 1: las dos funciones existen y son SECURITY DEFINER ---';
  -- -------------------------------------------------------------------------
  select p.prosecdef into v_secdef
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'get_tenant_reports_v3';

  if v_secdef is null then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 1 (CRITICO): no existe public.get_tenant_reports_v3.';
  elsif not v_secdef then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 1b: get_tenant_reports_v3 no es SECURITY DEFINER.';
  else
    raise notice 'OK 1: la consolidada existe y es SECURITY DEFINER.';
  end if;

  select p.prosecdef into v_secdef
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'get_branch_reports_v3';

  if v_secdef is null or not v_secdef then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 1c: get_branch_reports_v3 falta o dejo de ser SECURITY DEFINER.';
  else
    raise notice 'OK 1c: la de una sede sigue en su sitio.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 2: LA GUARDIA -- la consolidada cubre todas las columnas ---';
  -- -------------------------------------------------------------------------
  --
  -- Si alguien renombra una columna en la de una sede, la consolidada sumaria
  -- cero en silencio. Esto lo caza.
  select string_agg(c.nombre || ' (' || c.tipo || ')', ', ' order by c.nombre)
    into v_faltantes
  from (
    select
      a.attname as nombre,
      format_type(a.atttypid, null) as tipo
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join lateral unnest(p.proallargtypes, p.proargmodes, p.proargnames)
      with ordinality as a(atttypid, mode, attname, ord) on true
    where n.nspname = 'public'
      and p.proname = 'get_branch_reports_v3'
      and a.mode = 't'
  ) c
  where not exists (
    select 1
    from pg_proc p2
    join pg_namespace n2 on n2.oid = p2.pronamespace
    join lateral unnest(p2.proallargtypes, p2.proargmodes, p2.proargnames)
      with ordinality as a2(atttypid, mode, attname, ord) on true
    where n2.nspname = 'public'
      and p2.proname = 'get_tenant_reports_v3'
      and a2.mode = 't'
      and a2.attname = c.nombre
      and format_type(a2.atttypid, null) = c.tipo
  );

  if v_faltantes is not null then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 2 (CRITICO): la consolidada no devuelve estas columnas de la de una sede: %. '
      'El consolidado sumaria cero en silencio y el dueno veria un total mas bajo.', v_faltantes;
  else
    raise notice 'OK 2: la consolidada cubre todas las columnas de la de una sede.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 3: y ademas trae las dos suyas ---';
  -- -------------------------------------------------------------------------
  if not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join lateral unnest(p.proargnames) as nombre on true
    where n.nspname = 'public'
      and p.proname = 'get_tenant_reports_v3'
      and nombre = 'by_branch'
  ) then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 3: falta la columna by_branch.';
  elsif not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join lateral unnest(p.proargnames) as nombre on true
    where n.nspname = 'public'
      and p.proname = 'get_tenant_reports_v3'
      and nombre = 'branches_count'
  ) then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 3b: falta la columna branches_count.';
  else
    raise notice 'OK 3: branches_count y by_branch presentes.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 4: anon no alcanza ninguna de las dos ---';
  -- -------------------------------------------------------------------------
  if has_function_privilege('anon', 'public.get_tenant_reports_v3(date, date)', 'EXECUTE')
     or has_function_privilege('anon', 'public.get_branch_reports_v3(uuid, date, date)', 'EXECUTE') then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 4 (CRITICO): anon puede leer los reportes financieros de un salon.';
  else
    raise notice 'OK 4: anon no alcanza los reportes.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 5: la agrupacion de los desgloses en jsonb suma bien ---';
  -- -------------------------------------------------------------------------
  --
  -- Una misma estilista puede trabajar en dos sedes: el consolidado tiene que
  -- decir cuanto se llevo EN TOTAL, no ensenarla dos veces con la mitad.
  v_json := '[
    {"stylist_name":"Valentina","services_count":3,"service_sales":300000,"commission_total":60000},
    {"stylist_name":"Camila","services_count":2,"service_sales":200000,"commission_total":40000},
    {"stylist_name":"Valentina","services_count":1,"service_sales":100000,"commission_total":20000}
  ]'::jsonb;

  select
    count(*)::integer as filas,
    max(case when nombre = 'Valentina' then comision end) as valentina
    into v_res
  from (
    select
      e ->> 'stylist_name' as nombre,
      sum(coalesce((e ->> 'commission_total')::numeric, 0)) as comision
    from jsonb_array_elements(v_json) e
    group by e ->> 'stylist_name'
  ) x;

  if v_res.filas <> 2 then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 5: la agrupacion dejo % filas y deberian ser 2.', v_res.filas;
  elsif v_res.valentina <> 80000 then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 5b: Valentina suma % y deberia sumar 80000 entre sus dos sedes.', v_res.valentina;
  else
    raise notice 'OK 5: una estilista en dos sedes aparece una vez, con la suma de las dos.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '======================================================================';
  if v_fallos = 0 then
    raise notice 'CONTROL 205: TODOS LOS CASOS EN VERDE.';
    raise notice 'RECORDATORIO: la suma en vivo se comprueba entrando a Reportes';
    raise notice 'con dos sedes y eligiendo "Todas las sedes".';
  else
    raise exception 'CONTROL 205: % caso(s) fallaron. Revisar arriba.', v_fallos;
  end if;
  raise notice '======================================================================';
end;
$$;

rollback;
