-- Lectura: ¿por qué el enlace de la estilista de Éxito salió con el código y
-- no con el nombre del salón? (D-313, 03-oct). NO MODIFICA NADA: se pone en
-- el lugar de cada estilista y TERMINA EN ROLLBACK.
--
-- LO QUE SE VIO. Tras publicar D-313, el mensaje de WhatsApp de la estilista
-- ya nombraba el salón (la versión nueva estaba cargada), pero el enlace
-- seguía siendo `?reservar=978ee07d-…`. La app usa el enlace con el nombre
-- solo si (a) la sede es la principal y (b) logra leer `tenants.slug` con la
-- sesión de la estilista. Si una de las dos falla, usa el directo. Esta
-- lectura dice cuál, sin adivinar:
--   1. En la tabla: ¿la sede del enlace es la principal? ¿el negocio tiene
--      dirección (slug)?
--   2. Como cada estilista activa del negocio (sin nombres):
--      - ¿puede leer la fila de su negocio en `tenants`?
--      - ¿qué dice `get_my_branch_context_v2` de esa sede: es la principal?
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\intervenciones\verificar_enlace_con_nombre_d313.sql"
--
-- Patrón de cambio de rol copiado del control 231, que ya pasó (regla 25d).

begin;

do $lectura$
declare
  v_sede        uuid := '978ee07d-41c1-491e-aee4-8598e1452d34';
  v_tenant      uuid;
  v_principal   boolean;
  v_tiene_slug  boolean;
  v_n           integer := 0;
  v_filas       integer;
  v_slug_visto  boolean;
  v_ctx         text;
  v_error1      text;
  v_error2      text;
  r             record;
begin
  select b.tenant_id, b.is_primary into v_tenant, v_principal
  from public.branches b where b.id = v_sede;

  if v_tenant is null then
    raise notice 'LA SEDE DEL ENLACE NO EXISTE';
    return;
  end if;

  select (t.slug is not null and length(trim(t.slug)) > 0) into v_tiene_slug
  from public.tenants t where t.id = v_tenant;

  raise notice '1. En la tabla: la sede es la principal = %; el negocio tiene direccion = %',
    v_principal, v_tiene_slug;

  for r in
    select tm.user_id
    from public.tenant_memberships tm
    where tm.tenant_id = v_tenant and tm.role = 'stylist' and tm.active
    order by tm.user_id
  loop
    v_n := v_n + 1;
    v_filas := null; v_slug_visto := null; v_ctx := null;
    v_error1 := null; v_error2 := null;

    perform set_config('request.jwt.claims',
      json_build_object('sub', r.user_id::text, 'role', 'authenticated')::text, true);

    begin
      execute 'set local role authenticated';
      select count(*), bool_or(t.slug is not null and length(trim(t.slug)) > 0)
        into v_filas, v_slug_visto
      from public.tenants t where t.id = v_tenant;
      execute 'reset role';
    exception when others then
      v_error1 := sqlerrm;
      execute 'reset role';
    end;

    begin
      execute 'set local role authenticated';
      select string_agg(coalesce(c.is_primary::text, 'nulo'), ',') into v_ctx
      from public.get_my_branch_context_v2() c
      where c.branch_id = v_sede;
      execute 'reset role';
    exception when others then
      v_error2 := sqlerrm;
      execute 'reset role';
    end;

    raise notice '2. Estilista %: lee su negocio = % fila(s), ve la direccion = %, error = % | el contexto dice principal = %, error = %',
      v_n, v_filas, v_slug_visto, coalesce(v_error1, 'ninguno'),
      coalesce(v_ctx, 'la sede no aparece'), coalesce(v_error2, 'ninguno');
  end loop;

  if v_n = 0 then
    raise notice '2. El negocio no tiene estilistas activas con cuenta';
  end if;

  perform set_config('request.jwt.claims', '{}', true);
end
$lectura$;

rollback;
