-- CONTROL 193: Paso 8.3 -- Alinear el permiso suelto de Storage (H-11).
--
-- POR QUÉ ESTE ARCHIVO
--
-- La migración 20260830120000 solo toca privilegios (revoke/grant), no
-- lógica. Este control comprueba tres cosas distintas para no dar nada por
-- sentado:
--   1. La matriz de privilegios de las tres funciones de autorización de
--      Storage queda IDÉNTICA entre sí (anon=false, public=false,
--      authenticated=true) -- antes de esta migración,
--      `beautyos_can_upload_work_photo` era la única con `anon`/`public`
--      en verdadero por herencia de PUBLIC.
--   2. Un intento REAL de ejecutarla como rol `anon` queda rechazado
--      (no es solo una lectura de catálogo: es un intento de escritura de
--      rol contra la función real).
--   3. La lógica de autorización sigue funcionando igual que antes para un
--      usuario legítimo -- se busca un tenant_owner real con una sede real
--      y se confirma que la función le sigue devolviendo `true`. Esto es
--      lo que demuestra que el arreglo de permisos NO rompió el flujo de
--      subida de fotos de trabajo.
--
-- CÓMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\193_test_alinear_permiso_storage_h11.sql"
--
-- TERMINA EN ROLLBACK. No deja ni una fila ni cambia ningún privilegio.

begin;

do $$
declare
  v_fallos integer := 0;
  v_error text;
  v_blocked boolean;
  v_owner_user uuid;
  v_owner_tenant uuid;
  v_owner_branch uuid;
  v_resultado boolean;
begin
  -- =====================================================================
  -- 1. Matriz de privilegios: las tres funciones deben quedar idénticas.
  -- =====================================================================
  with expected(nombre, signature) as (
    values
    ('work_photo', 'private.beautyos_can_upload_work_photo(uuid)'::regprocedure),
    ('tenant_logo', 'private.beautyos_can_upload_tenant_logo(uuid)'::regprocedure),
    ('stylist_photo', 'private.beautyos_can_manage_stylist_photo(uuid, uuid)'::regprocedure)
  ), matrix as (
    select
      nombre,
      signature,
      has_function_privilege('anon', signature, 'execute') as anon_execute,
      has_function_privilege('public', signature, 'execute') as public_execute,
      has_function_privilege('authenticated', signature, 'execute') as authenticated_execute
    from expected
  )
  select count(*) into v_fallos
  from matrix
  where anon_execute is true
     or public_execute is true
     or authenticated_execute is false;

  if v_fallos = 0 then
    raise notice 'OK 1  las tres funciones de autorizacion de Storage quedan identicas: anon=false, public=false, authenticated=true';
  else
    raise notice 'FALLO 1  % funcion(es) con privilegios distintos a lo esperado', v_fallos;
  end if;

  -- =====================================================================
  -- 2. Intento real de ejecucion como anon: debe quedar rechazado.
  -- =====================================================================
  execute 'set local role anon';
  v_blocked := false;
  begin
    perform private.beautyos_can_upload_work_photo('00000000-0000-0000-0000-000000000000'::uuid);
  exception when insufficient_privilege then
    v_blocked := true;
  end;
  execute 'reset role';

  if v_blocked then
    raise notice 'OK 2  anon queda rechazado al intentar ejecutar beautyos_can_upload_work_photo';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 2  anon pudo ejecutar beautyos_can_upload_work_photo';
  end if;

  -- =====================================================================
  -- 3. La logica sigue intacta para un tenant_owner real con sede real.
  -- =====================================================================
  select tm.user_id, tm.tenant_id
    into v_owner_user, v_owner_tenant
  from public.tenant_memberships tm
  where tm.role = 'tenant_owner'
    and tm.active
    and tm.starts_at <= now()
    and (tm.ends_at is null or tm.ends_at > now())
  limit 1;

  if v_owner_user is null then
    raise notice 'SIN DATOS  no hay ningun tenant_owner activo para probar la logica. Solo se validaron los privilegios (1 y 2).';
  else
    select b.id into v_owner_branch
    from public.branches b
    where b.tenant_id = v_owner_tenant
      and b.active
    limit 1;

    if v_owner_branch is null then
      raise notice 'SIN DATOS  el tenant_owner encontrado no tiene ninguna sede activa. Solo se validaron los privilegios (1 y 2).';
    else
      perform set_config(
        'request.jwt.claims',
        json_build_object('sub', v_owner_user::text, 'role', 'authenticated')::text,
        true
      );

      select private.beautyos_can_upload_work_photo(v_owner_branch) into v_resultado;

      if v_resultado is true then
        raise notice 'OK 3  un tenant_owner real sigue autorizado para subir fotos de trabajo en su propia sede';
      else
        v_fallos := v_fallos + 1;
        raise notice 'FALLO 3  el tenant_owner no quedo autorizado (resultado=%)', v_resultado;
      end if;
    end if;
  end if;

  -- =====================================================================
  raise notice ' ';
  if v_fallos = 0 then
    raise notice '=== TODAS LAS PRUEBAS DEL PASO 8.3 (H-11) PASARON ===';
  else
    raise notice '=== % FALLO(S). Revisar arriba. ===', v_fallos;
  end if;

exception
  when others then
    execute 'reset role';
    v_error := sqlerrm;
    raise notice ' ';
    raise notice '=== LA PRUEBA SE DETUVO: % ===', v_error;
end;
$$;

rollback;
