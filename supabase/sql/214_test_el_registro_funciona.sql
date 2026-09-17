-- CONTROL 214: Un negocio nuevo se puede registrar (D-245, paso 9.46).
--
-- POR QUE ESTE ARCHIVO, Y POR QUE LLEGA TARDE
--
-- `register_tenant` buscaba el plan por su codigo -- `'profesional'`-- y
-- **D-188 jubilo ese codigo el 01-sep**. Desde ese dia cualquiera que
-- intentara darse de alta recibia *"No hay un plan disponible para registrar
-- la solicitud"*.
--
-- **Dieciseis dias.** Y no lo encontro una prueba: lo encontro un desconocido
-- al que el propietario invito a probar la aplicacion.
--
-- Este control existe porque **no habia ninguno que recorriera el registro**.
-- Habia controles del cobro, de las sedes, de los precios y de los permisos;
-- del camino por el que entran TODOS los clientes, ninguno. Y un camino que
-- nadie recorre no avisa de que esta roto: avisa el primero que lo recorre.
--
-- Es la tercera vez con esta forma -- el cobro caido 26 dias por las llaves
-- heredadas (D-215) y el `calc is not defined` en produccion (hallazgo AB)--
-- asi que aqui no se comprueba una regla de negocio: se comprueba **que la
-- puerta de entrada abre**.
--
-- Que valida, transaccionalmente:
--   1. La funcion existe y es SECURITY DEFINER.
--   2. **Registrar funciona de verdad**: devuelve negocio y sede. La que
--      hubiera cazado el fallo.
--   3. Todo duenyo queda con su primera sede, y es la principal (D-239).
--   4. La suscripcion apunta a un plan **activo**, no a uno jubilado.
--   5. **El registro sobrevive a que cambien los codigos del catalogo.** Se
--      prueba renombrandolo de verdad, no leyendo la fuente: leerla dio dos
--      veredictos falsos porque el cuerpo explica el fallo citandolo.
--   6. Registrarse dos veces con el mismo usuario se rechaza.
--   7. `anon` no alcanza la funcion.
--
-- COMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\214_test_el_registro_funciona.sql"
--
-- TERMINA EN ROLLBACK. Todos los datos de prueba se descartan limpiamente.

begin;

do $ctrl$
declare
  v_user     uuid := gen_random_uuid();
  v_otro     uuid := gen_random_uuid();
  v_def      text;
  v_tenant   uuid;
  v_branch   uuid;
  v_estado   text;
  v_plan     uuid;
  v_activo   boolean;
  v_primaria boolean;
  v_cuantas  integer;
  v_capturo  boolean;
  v_error    text;
begin
  -- 1. Existe y esta blindada
  select pg_get_functiondef(p.oid) into v_def
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'register_tenant';

  if v_def is null then
    raise exception 'FALLO 1: public.register_tenant no existe. Es la puerta de entrada de TODOS los clientes.';
  end if;
  if v_def not ilike '%security definer%' then
    raise exception 'FALLO 1b: register_tenant no es SECURITY DEFINER';
  end if;
  raise notice 'OK 1   la funcion de registro existe y es SECURITY DEFINER';

  -- Fixtures: un usuario con correo y sin negocio.
  insert into auth.users (id, email) values (v_user, 'nueva_test214@salonymas.com')
  on conflict (id) do nothing;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_user::text, 'role', 'authenticated')::text, true);

  -- 2. LA IMPORTANTE: registrar funciona de verdad.
  select r.tenant_id, r.branch_id, r.status
    into v_tenant, v_branch, v_estado
  from public.register_tenant(
    'Control 214 Salon',
    'Maria Perez',
    '3185196010',
    'barberia',
    'Bogota',
    1,
    1,
    'Recomendacion de un colega',
    null
  ) r;

  if v_tenant is null then
    raise exception 'FALLO 2: el registro no devolvio negocio. ESTO es lo que le pasaba a cada prospecto desde el 01-sep (D-245).';
  end if;
  if v_branch is null then
    raise exception 'FALLO 2b: el registro no devolvio sede';
  end if;
  raise notice 'OK 2   un negocio nuevo se registra y devuelve negocio y sede (estado: %)', v_estado;

  -- 3. Su primera sede existe y es la principal (D-239)
  select count(*)::integer into v_cuantas
  from public.branches where tenant_id = v_tenant;
  if v_cuantas <> 1 then
    raise exception 'FALLO 3: el registro dejo % sedes y deberia dejar exactamente 1', v_cuantas;
  end if;

  select is_primary into v_primaria from public.branches where id = v_branch;
  if not coalesce(v_primaria, false) then
    raise exception 'FALLO 3b: la sede creada al registrarse no quedo como principal. Todo duenyo tiene minimo una sede y es esa (D-239).';
  end if;
  raise notice 'OK 3   queda con su primera sede, y es la principal';

  -- 4. La suscripcion apunta a un plan ACTIVO, no a uno jubilado
  select ts.plan_id into v_plan
  from public.tenant_subscriptions ts where ts.tenant_id = v_tenant;
  if v_plan is null then
    raise exception 'FALLO 4: el negocio quedo sin suscripcion';
  end if;

  select (p.status = 'active') into v_activo
  from public.plans p where p.id = v_plan;
  if not coalesce(v_activo, false) then
    raise exception 'FALLO 4b: la suscripcion quedo apuntando a un plan que NO esta activo. Es justo el estado en que un plan jubilado se cuela (D-188, D-245).';
  end if;
  raise notice 'OK 4   la suscripcion apunta a un plan activo';

  -- 5. EL GUARDIAN CONTRA LA REGRESION, **probandolo en vez de leerlo**.
  --
  -- Se renombra el catalogo entero: se jubila el plan activo y se crea otro
  -- con un codigo que nadie ha escrito jamas. Si el registro sigue
  -- funcionando, es que no depende de ningun codigo. Si se cae, depende --y
  -- eso es exactamente el fallo de D-245, reproducido a proposito.
  --
  -- **Por que no se comprueba leyendo la fuente.** Se intento dos veces con
  -- `pg_get_functiondef` y dio dos veredictos falsos, porque el cuerpo de la
  -- funcion **explica el fallo citandolo**: `-- Aqui decia p.code =
  -- 'profesional'`. Es la misma trampa que el 16-sep hizo que un guardian de
  -- Dart diera VERDE con la llamada comentada, y aqui hacia que diera ROJO
  -- estando bien.
  --
  -- La leccion no es "acuerdate de quitar los comentarios": es que **una
  -- prueba que lee codigo comprueba la intencion, y una que lo ejecuta
  -- comprueba el hecho**. Cuando se puede ejecutar, se ejecuta.
  --
  -- Todo esto vive dentro del `begin`/`rollback`: el catalogo real no se toca.
  update public.plans set status = 'retired' where status = 'active';

  insert into public.plans
    (code, version, name, billing_period, price_cop, currency_code, status)
  values
    ('c214-codigo-jamas-escrito', 1, 'Plan del control 214',
     'monthly', 150000, 'COP', 'active');

  insert into auth.users (id, email) values (v_otro, 'otra_test214@salonymas.com')
  on conflict (id) do nothing;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_otro::text, 'role', 'authenticated')::text, true);

  v_capturo := false;
  begin
    select r.tenant_id into v_tenant
    from public.register_tenant(
      'Control 214 Catalogo', 'Ana Gomez', '3001112233',
      'barberia', 'Bogota', 1, 1, null, null
    ) r;
  exception when others then
    v_capturo := true;
    v_error := sqlerrm;
  end;

  if v_capturo then
    raise exception 'FALLO 5: al renombrar el catalogo de planes, el registro dejo de funcionar (%). Depende de un codigo concreto, que es EXACTAMENTE lo que tuvo el registro roto 16 dias cuando D-188 jubilo "profesional" (D-245).', v_error;
  end if;
  if v_tenant is null then
    raise exception 'FALLO 5b: con el catalogo renombrado el registro no devolvio negocio';
  end if;
  raise notice 'OK 5   el registro sobrevive a que cambien los codigos del catalogo';

  -- 6. Registrarse dos veces con el mismo usuario se rechaza
  v_capturo := false;
  begin
    perform public.register_tenant(
      'Control 214 Segundo', 'Maria Perez', '3185196010',
      'barberia', 'Bogota', 1, 1, null, null
    );
  exception when others then
    v_capturo := true;
    v_error := sqlerrm;
  end;
  if not v_capturo then
    raise exception 'FALLO 6: el mismo usuario registro dos negocios';
  end if;
  if v_error not ilike '%ya pertenece%' then
    raise exception 'FALLO 6b: se rechazo, pero el mensaje no lo explica: %', v_error;
  end if;
  raise notice 'OK 6   el mismo usuario no puede registrar dos negocios';

  -- 7. anon no la alcanza
  if has_function_privilege('anon',
       'public.register_tenant(text, text, text, text, text, integer, integer, text, text)',
       'execute') then
    raise exception 'FALLO 7: anon puede registrar negocios sin sesion';
  end if;
  raise notice 'OK 7   anon no alcanza la funcion';

  raise notice '---------------------------------------------';
  raise notice 'CONTROL 214 COMPLETO: 7 de 7 en verde.';
  raise notice 'Este es el control que faltaba: recorre la puerta';
  raise notice 'por la que entran TODOS los clientes.';
end
$ctrl$;

rollback;
