-- D-166: la direccion fisica de la sede principal se edita desde
-- Configuracion y viaja de vuelta a la pantalla (y a la pagina publica).
--
-- POR QUE ESTE ARCHIVO
--
-- `update_tenant_contact_info` gano un septimo parametro (`p_address`) y
-- ahora tambien escribe en `branches`, no solo en `tenants` -- dos tablas
-- en una sola funcion es exactamente el tipo de cambio que se rompe en
-- silencio si el `update` a `branches` apunta a la sede equivocada o no
-- filtra por sede principal activa.
--
-- COMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\186_test_direccion_sede_y_contacto.sql"
--
-- TERMINA EN ROLLBACK. No deja ni una fila (incluye lo que toque del
-- negocio real: se usa el owner real porque la RPC resuelve "mi tenant" a
-- partir de la sesion, mismo patron que 183/184/185).

begin;

do $$
declare
  v_tenant uuid;
  v_branch uuid;
  v_owner uuid;
  v_stylist_user uuid;
  v_direccion_nueva text := 'Calle Prueba D166 #12-34, Local 5';
  v_direccion_leida text;
  v_slug_actual text;
  v_capturo boolean;
  v_fallos integer := 0;
  v_error text;
begin
  select t.id into v_tenant
  from public.tenants t
  where t.active
  order by t.created_at
  limit 1;

  select b.id into v_branch
  from public.branches b
  where b.tenant_id = v_tenant and b.active and b.is_primary
  limit 1;

  select tm.user_id into v_owner
  from public.tenant_memberships tm
  where tm.tenant_id = v_tenant
    and tm.role = 'tenant_owner'
    and tm.active
  limit 1;

  select tm.user_id into v_stylist_user
  from public.tenant_memberships tm
  where tm.tenant_id = v_tenant
    and tm.role = 'stylist'
    and tm.active
  limit 1;

  if v_tenant is null or v_branch is null or v_owner is null then
    raise notice 'SIN DATOS suficientes para las pruebas. Nada que comprobar.';
    return;
  end if;

  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_owner::text, 'role', 'authenticated')::text,
    true
  );

  -- =====================================================================
  -- CASO 1: el owner guarda una direccion nueva -- llega a la sede
  -- principal, no a cualquier sede.
  -- =====================================================================
  perform public.update_tenant_contact_info(
    'Titular de Prueba', 'Salon de prueba', '3009998877', '3009998877',
    '@prueba', 'PruebaFacebook', v_direccion_nueva
  );

  select address into v_direccion_leida
  from public.branches
  where id = v_branch;

  if v_direccion_leida = v_direccion_nueva then
    raise notice 'OK  1a  la direccion nueva quedo guardada en la sede principal';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 1a  se esperaba "%"; llego "%"', v_direccion_nueva, v_direccion_leida;
  end if;

  -- =====================================================================
  -- CASO 2: get_business_settings devuelve la direccion recien guardada,
  -- para que la pantalla de edicion la precargue.
  -- =====================================================================
  select address into v_direccion_leida
  from public.get_business_settings();

  if v_direccion_leida = v_direccion_nueva then
    raise notice 'OK  2a  get_business_settings devuelve la direccion actualizada';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 2a  se esperaba "%"; llego "%"', v_direccion_nueva, v_direccion_leida;
  end if;

  -- =====================================================================
  -- CASO 3: get_public_salon_by_slug (D-164/D-165) tambien refleja la
  -- direccion nueva -- es la misma columna que lee la pagina publica.
  -- =====================================================================
  select t.slug into v_slug_actual from public.tenants t where t.id = v_tenant;

  if v_slug_actual is null then
    raise notice 'SALTADA 3a: el tenant no tiene slug asignado todavia (D-164 no aplicada).';
  else
    select gs.address into v_direccion_leida
    from public.get_public_salon_by_slug(v_slug_actual) gs;

    if v_direccion_leida = v_direccion_nueva then
      raise notice 'OK  3a  la pagina publica del negocio ve la misma direccion nueva';
    else
      v_fallos := v_fallos + 1;
      raise notice 'FALLO 3a  se esperaba "%"; llego "%"', v_direccion_nueva, v_direccion_leida;
    end if;
  end if;

  -- =====================================================================
  -- CASO 4: un estilista no puede editar el contacto/direccion del negocio.
  -- =====================================================================
  if v_stylist_user is null then
    raise notice 'SALTADA 4a: el negocio no tiene estilista con cuenta.';
  else
    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', v_stylist_user::text, 'role', 'authenticated')::text,
      true
    );

    v_capturo := false;
    begin
      perform public.update_tenant_contact_info(
        'Otro Nombre', 'Otro tipo', '3000000000', '3000000000',
        '@otro', 'Otro', 'Otra direccion'
      );
    exception
      when others then
        v_capturo := true;
    end;

    if v_capturo then
      raise notice 'OK  4a  un estilista no puede editar el contacto del negocio';
    else
      v_fallos := v_fallos + 1;
      raise notice 'FALLO 4a  un estilista pudo editar el contacto del negocio';
    end if;

    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', v_owner::text, 'role', 'authenticated')::text,
      true
    );
  end if;

  -- =====================================================================
  -- CASO 5: dejar la direccion en blanco la limpia (mismo criterio que ya
  -- tenian los demas campos de este formulario, ej. Instagram/Facebook).
  -- =====================================================================
  perform public.update_tenant_contact_info(
    'Titular de Prueba', 'Salon de prueba', '3009998877', '3009998877',
    '@prueba', 'PruebaFacebook', ''
  );

  select address into v_direccion_leida from public.branches where id = v_branch;

  if v_direccion_leida is null then
    raise notice 'OK  5a  una direccion vacia limpia el campo (mismo criterio que Instagram/Facebook)';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 5a  se esperaba direccion nula; llego "%"', v_direccion_leida;
  end if;

  -- =====================================================================
  raise notice ' ';
  if v_fallos = 0 then
    raise notice '=== TODAS LAS PRUEBAS DE DIRECCION DE SEDE PASARON ===';
  else
    raise notice '=== % FALLO(S). Revisar arriba. ===', v_fallos;
  end if;

exception
  when others then
    v_error := sqlerrm;
    raise notice ' ';
    raise notice '=== LA PRUEBA SE DETUVO: % ===', v_error;
    raise notice 'Si es la primera vez que se corre, puede ser el guion y no';
    raise notice 'la aplicacion. Pasale este mensaje al asistente.';
end;
$$;

rollback;
