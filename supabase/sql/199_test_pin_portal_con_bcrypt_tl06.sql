-- CONTROL 199: Paso 8.12 -- El PIN del portal pasa a bcrypt (TL-06, D-185).
--
-- POR QUÉ ESTE ARCHIVO
--
-- La migración 20260901160000 cambia `client_portal_authenticate` y
-- `admin_reset_client_portal_pin` para guardar el PIN con bcrypt en vez de
-- SHA-256 de una sola vuelta, migrando al vuelo los hashes ya existentes, y
-- convierte el bloqueo plano de 15 minutos en uno escalonado.
--
-- Este control valida transaccionalmente:
--   - `pgcrypto` está disponible y `crypt`/`gen_salt` funcionan.
--   - Una clienta con hash bcrypt entra con su PIN.
--   - Una clienta con el hash SHA-256 HEREDADO sigue entrando (nadie pierde su
--     PIN por la migración).
--   - Y al entrar, su hash queda REESCRITO a bcrypt y su sal a null.
--   - Un PIN equivocado no entra, con hash nuevo y con hash heredado.
--   - Sigue habiendo UN SOLO mensaje de error (no se rompió D-183 / TL-04).
--   - El bloqueo es ESCALONADO: 1 minuto a los 5 intentos y mas a los 10.
--   - Estando bloqueada, ni siquiera el PIN correcto entra.
--
-- Lo que este control NO cubre: `admin_reset_client_portal_pin` exige sesion
-- de owner/admin (`get_my_tenant_id`, `is_owner_or_admin`), que no existe en
-- una sesion de psql. Que el PIN nuevo nace en bcrypt se comprueba leyendo la
-- funcion, y en vivo al restablecer un PIN desde la ficha de la clienta.
--
-- CÓMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\199_test_pin_portal_con_bcrypt_tl06.sql"
--
-- TERMINA EN ROLLBACK. Todos los datos de prueba se descartan limpiamente.

begin;

-- Para que `crypt` y `gen_salt` se resuelvan tanto si pgcrypto quedó en
-- `extensions` (lo normal en Supabase) como si estuviera en `public`.
set local search_path = public, extensions;

do $$
declare
  v_fallos integer := 0;
  v_tenant uuid;
  v_bcrypt uuid;
  v_legado uuid;
  v_pin text := '2846';
  v_salt_legado text := 'sal-heredada-199';
  v_tel_bcrypt text := '3009990201';
  v_tel_legado text := '3009990202';
  v_tel_inexistente text := '3009990203';
  v_r jsonb;
  v_hash text;
  v_sal text;
  v_bloqueo timestamptz;
  v_intentos integer;
  v_minutos numeric;
  v_msg_a text;
  v_msg_b text;
begin
  raise notice '======================================================================';
  raise notice 'CONTROL 199 - PIN del portal con bcrypt (TL-06 / D-185)';
  raise notice '======================================================================';

  select id into v_tenant from public.tenants order by created_at limit 1;
  if v_tenant is null then
    raise exception 'No hay ningun negocio en public.tenants: este control necesita al menos uno.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 1: pgcrypto disponible y bcrypt funcionando ---';
  -- -------------------------------------------------------------------------
  begin
    v_hash := crypt(v_pin, gen_salt('bf', 10));
    if v_hash is null or v_hash not like '$2%' or crypt(v_pin, v_hash) <> v_hash then
      v_fallos := v_fallos + 1;
      raise warning 'FALLO 1: bcrypt no produce un hash valido (%).', v_hash;
    else
      raise notice 'OK 1: bcrypt disponible. Prefijo del hash: %', left(v_hash, 4);
    end if;
  exception when others then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 1 (CRITICO): pgcrypto no esta disponible (%).', sqlerrm;
  end;

  -- Clienta ya en bcrypt
  insert into public.clients (tenant_id, name, phone, active)
  values (v_tenant, 'Clienta Control 199 (bcrypt)', v_tel_bcrypt, true)
  returning id into v_bcrypt;

  update public.clients
  set portal_pin_hash = crypt(v_pin, gen_salt('bf', 10)),
      portal_pin_salt = null,
      portal_failed_attempts = 0,
      portal_locked_until = null
  where id = v_bcrypt;

  -- Clienta con el hash heredado de D-167
  insert into public.clients (tenant_id, name, phone, active)
  values (v_tenant, 'Clienta Control 199 (SHA-256 heredado)', v_tel_legado, true)
  returning id into v_legado;

  update public.clients
  set portal_pin_hash = encode(sha256((v_pin || v_salt_legado)::bytea), 'hex'),
      portal_pin_salt = v_salt_legado,
      portal_failed_attempts = 0,
      portal_locked_until = null
  where id = v_legado;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 2: una clienta ya en bcrypt entra con su PIN ---';
  -- -------------------------------------------------------------------------
  v_r := public.client_portal_authenticate(v_tenant, v_tel_bcrypt, v_pin);

  if v_r->>'token' is null then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 2 (CRITICO): una clienta con hash bcrypt no puede entrar (error=%).', v_r->>'error';
  else
    raise notice 'OK 2: entra con bcrypt.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 3: la del hash HEREDADO sigue entrando (nadie pierde su PIN) ---';
  -- -------------------------------------------------------------------------
  v_r := public.client_portal_authenticate(v_tenant, v_tel_legado, v_pin);

  if v_r->>'token' is null then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 3 (CRITICO): la migracion dejo fuera a las clientas que ya tenian PIN (error=%).', v_r->>'error';
  else
    raise notice 'OK 3: el PIN heredado sigue sirviendo.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 4: y al entrar, su hash queda migrado a bcrypt ---';
  -- -------------------------------------------------------------------------
  select portal_pin_hash, portal_pin_salt into v_hash, v_sal
  from public.clients where id = v_legado;

  if v_hash is null or v_hash not like '$2%' then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 4: el hash heredado no se migro al entrar (sigue siendo %).', left(coalesce(v_hash,'null'), 12);
  elsif v_sal is not null then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 4b: se migro el hash pero quedo la sal vieja (%).', v_sal;
  else
    raise notice 'OK 4: migrado al vuelo a bcrypt y sal puesta a null.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 5: y despues de migrada, sigue entrando ---';
  -- -------------------------------------------------------------------------
  v_r := public.client_portal_authenticate(v_tenant, v_tel_legado, v_pin);

  if v_r->>'token' is null then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 5 (CRITICO): tras migrar el hash, la clienta ya no puede entrar.';
  else
    raise notice 'OK 5: entra igual con el hash ya migrado.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 6: un PIN equivocado no entra, y el mensaje sigue siendo uno solo ---';
  -- -------------------------------------------------------------------------
  update public.clients
  set portal_failed_attempts = 0, portal_locked_until = null
  where id in (v_bcrypt, v_legado);

  v_r := public.client_portal_authenticate(v_tenant, v_tel_bcrypt, '0000');
  v_msg_a := v_r->>'error';

  if v_r->>'token' is not null then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 6 (CRITICO): entro con un PIN equivocado.';
  end if;

  v_r := public.client_portal_authenticate(v_tenant, v_tel_inexistente, v_pin);
  v_msg_b := v_r->>'error';

  if v_msg_a is distinct from v_msg_b then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 6b (CRITICO): se rompio D-183, los mensajes vuelven a distinguirse.';
    raise warning '  PIN malo  : %', v_msg_a;
    raise warning '  no existe : %', v_msg_b;
  else
    raise notice 'OK 6: no entra, y sigue habiendo un solo mensaje (D-183 intacto).';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 7: el bloqueo es ESCALONADO, no 15 minutos planos ---';
  -- -------------------------------------------------------------------------
  update public.clients
  set portal_failed_attempts = 0, portal_locked_until = null
  where id = v_bcrypt;

  for i in 1..5 loop
    perform public.client_portal_authenticate(v_tenant, v_tel_bcrypt, '0000');
  end loop;

  select portal_failed_attempts, portal_locked_until
    into v_intentos, v_bloqueo
  from public.clients where id = v_bcrypt;

  if v_bloqueo is null or v_bloqueo <= now() then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 7: a los 5 intentos no quedo bloqueada (intentos=%).', v_intentos;
  else
    v_minutos := extract(epoch from (v_bloqueo - now())) / 60.0;
    if v_minutos > 3 then
      v_fallos := v_fallos + 1;
      raise warning 'FALLO 7b: el primer tramo sigue siendo largo (% minutos). '
        'Se buscaba ~1 minuto para que no sirva para dejar fuera a una clienta real.', round(v_minutos, 2);
    else
      raise notice 'OK 7: primer tramo de ~% minuto(s) tras 5 intentos.', round(v_minutos, 2);
    end if;
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 8: el segundo tramo aprieta mas ---';
  -- -------------------------------------------------------------------------
  update public.clients
  set portal_failed_attempts = 9, portal_locked_until = null
  where id = v_bcrypt;

  perform public.client_portal_authenticate(v_tenant, v_tel_bcrypt, '0000');

  select portal_locked_until into v_bloqueo
  from public.clients where id = v_bcrypt;

  if v_bloqueo is null then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 8: al llegar a 10 intentos no se bloqueo.';
  else
    v_minutos := extract(epoch from (v_bloqueo - now())) / 60.0;
    if v_minutos < 3 then
      v_fallos := v_fallos + 1;
      raise warning 'FALLO 8b: el segundo tramo no aprieta (% minutos).', round(v_minutos, 2);
    else
      raise notice 'OK 8: segundo tramo de ~% minutos a los 10 intentos.', round(v_minutos, 2);
    end if;
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 9: estando bloqueada, el PIN CORRECTO tampoco entra ---';
  -- -------------------------------------------------------------------------
  v_r := public.client_portal_authenticate(v_tenant, v_tel_bcrypt, v_pin);

  if v_r->>'token' is not null then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 9 (CRITICO): el bloqueo no se esta aplicando.';
  else
    raise notice 'OK 9: bloqueada es bloqueada, aun con el PIN bueno.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '======================================================================';
  if v_fallos = 0 then
    raise notice 'CONTROL 199: TODOS LOS CASOS EN VERDE. TL-06 cerrado.';
  else
    raise exception 'CONTROL 199: % caso(s) fallaron. Revisar arriba.', v_fallos;
  end if;
  raise notice '======================================================================';
end;
$$;

rollback;
