-- CONTROL 231: Las fotos privadas vuelven a verse (hallazgo BW, D-284).
--
-- POR QUE ESTE ARCHIVO
--
-- BC (24-sep) metió en la política del almacén privado una función que
-- `authenticated` no puede ejecutar, y desde ese día ningún salón podía ver
-- ni publicar sus fotos privadas. Ningún control lo vio porque los
-- controles corren como dueño de la base, y el dueño de la base SE SALTA
-- las políticas de Storage: todo daba verde con la pantalla rota.
--
-- Este control no comete ese error: cambia de rol a `authenticated`, con la
-- sesión de una persona concreta, y lee `storage.objects` como lo hace la
-- app. Antes de D-284, el caso 2 fallaba con el mismo "permission denied
-- for function beautyos_current_platform_role" que vio el propietario.
--
-- Usa datos reales (el dueño de la Peluquería Éxito Prueba y un operador de
-- plataforma) solo para LEER. Termina en ROLLBACK.
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\231_test_las_fotos_privadas_vuelven_a_verse_bw.sql"

begin;

do $ctrl$
declare
  v_politica text;
  v_dueno uuid;
  v_operador uuid;
  v_cuantas integer;
  v_capturo boolean;
  v_error text;
  v_fallos integer := 0;
begin
  -- Los datos que hacen falta se leen ANTES de cambiar de rol: como
  -- authenticated, las tablas del negocio las taparía su propio RLS.
  select tm.user_id into v_dueno
  from public.tenant_memberships tm
  join public.tenants t on t.id = tm.tenant_id
  where t.slug = 'peluqueria-exito-prueba'
    and tm.role = 'tenant_owner'
    and tm.active
  limit 1;

  select po.user_id into v_operador
  from public.platform_operators po
  where po.active
  limit 1;

  -- ========================================================================
  -- 1. La política ya no llama a la función que authenticated no ejecuta.
  -- ========================================================================
  select qual into v_politica
  from pg_policies
  where schemaname = 'storage' and tablename = 'objects'
    and policyname = 'work_photos_private_select_staff';

  if v_politica like '%get_my_platform_role%'
     and v_politica not like '%beautyos_current_platform_role%'
     and v_politica like '%beautyos_can_upload_work_photo%'
  then
    raise notice 'OK    1  la politica usa get_my_platform_role y conserva la regla del salon';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 1  politica=%', v_politica;
  end if;

  -- ========================================================================
  -- 2. Una persona con sesión, de NINGÚN negocio, lee el almacén privado:
  --    no revienta, y no ve nada.
  -- ========================================================================
  v_capturo := false;
  begin
    perform set_config('request.jwt.claims',
      json_build_object('sub', gen_random_uuid()::text, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    select count(*) into v_cuantas
    from storage.objects where bucket_id = 'work-photos-private';
    execute 'reset role';
  exception when others then
    v_capturo := true; v_error := sqlerrm;
    execute 'reset role';
  end;
  if not v_capturo and v_cuantas = 0 then
    raise notice 'OK    2  con sesion y sin negocio, leer el almacen privado no revienta y no ve nada';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 2  capturo=%, error=%, vio=%', v_capturo, v_error, v_cuantas;
  end if;

  -- ========================================================================
  -- 3. El dueño de la Peluquería Éxito ve SUS fotos privadas.
  -- ========================================================================
  if v_dueno is null then
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 3  no se encontro el dueno de la Peluqueria Exito Prueba';
  else
    v_capturo := false;
    begin
      perform set_config('request.jwt.claims',
        json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);
      execute 'set local role authenticated';
      select count(*) into v_cuantas
      from storage.objects where bucket_id = 'work-photos-private';
      execute 'reset role';
    exception when others then
      v_capturo := true; v_error := sqlerrm;
      execute 'reset role';
    end;
    if not v_capturo and v_cuantas > 0 then
      raise notice 'OK    3  el dueno del salon ve sus % foto(s) privada(s)', v_cuantas;
    else
      v_fallos := v_fallos + 1;
      raise notice 'FALLO 3  capturo=%, error=%, vio=%', v_capturo, v_error, v_cuantas;
    end if;
  end if;

  -- ========================================================================
  -- 4. Soporte (operador de plataforma) también las ve: lo que BC quería.
  -- ========================================================================
  if v_operador is null then
    raise notice 'AVISO 4  no hay operador de plataforma activo; caso omitido';
  else
    v_capturo := false;
    begin
      perform set_config('request.jwt.claims',
        json_build_object('sub', v_operador::text, 'role', 'authenticated')::text, true);
      execute 'set local role authenticated';
      select count(*) into v_cuantas
      from storage.objects where bucket_id = 'work-photos-private';
      execute 'reset role';
    exception when others then
      v_capturo := true; v_error := sqlerrm;
      execute 'reset role';
    end;
    if not v_capturo and v_cuantas > 0 then
      raise notice 'OK    4  soporte ve las fotos privadas (%), como pedia BC', v_cuantas;
    else
      v_fallos := v_fallos + 1;
      raise notice 'FALLO 4  capturo=%, error=%, vio=%', v_capturo, v_error, v_cuantas;
    end if;
  end if;

  perform set_config('request.jwt.claims', '{}', true);

  -- ========================================================================
  -- 5. Ninguna foto queda "publicada" en la base con el archivo sin publicar.
  -- ========================================================================
  select count(*) into v_cuantas
  from public.work_photos wp
  where wp.active
    and wp.approved_for_portfolio
    and not exists (
      select 1 from storage.objects o
      where o.bucket_id = 'work-photos' and o.name = wp.storage_path);
  if v_cuantas = 0 then
    raise notice 'OK    5  ninguna foto queda publicada en la base sin estarlo en el almacen';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 5  quedan % foto(s) rotas', v_cuantas;
  end if;

  raise notice ' ';
  if v_fallos = 0 then
    raise notice '=== CONTROL 231: 5/5 ===';
  else
    raise notice '=== % FALLO(S) EN EL CONTROL 231. Revisar arriba. ===', v_fallos;
  end if;
end
$ctrl$;

rollback;
