-- CONTROL 198: Paso 8.11 -- Portal de la clienta sin enumeración e índice
-- funcional de teléfono (TL-04 y TL-05, D-183).
--
-- POR QUÉ ESTE ARCHIVO
--
-- La migración 20260901140000 cambia `public.client_portal_authenticate` para
-- que devuelva UN SOLO mensaje en todos los casos de fallo, y crea el índice
-- funcional `clients_tenant_phone_digits_idx`.
--
-- Antes devolvía cuatro mensajes distinguibles, y los tres últimos confirmaban
-- que un celular SÍ era clienta de un salón. Como la función la ejecuta `anon`
-- y el `tenant_id` es público (D-164), cualquiera podía barrer una lista de
-- números y reconstruir la clientela de un centro de estética sin adivinar un
-- solo PIN. Ley 1581.
--
-- Este control valida transaccionalmente:
--   - Celular que no es clienta -> mensaje genérico.
--   - Clienta sin PIN asignado -> mensaje genérico.
--   - Clienta con PIN, PIN equivocado -> mensaje genérico.
--   - Clienta bloqueada, incluso con el PIN CORRECTO -> mensaje genérico.
--   - LA ASERCIÓN CENTRAL: los cuatro mensajes son idénticos entre sí.
--   - El PIN correcto sigue funcionando y devuelve token.
--   - El error de formato sigue siendo distinto (no confirma nada de nadie).
--   - El contador de intentos sigue subiendo y bloquea a los 5.
--   - El índice funcional existe y su expresión es la que usan las funciones.
--
-- CÓMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\198_test_portal_clienta_sin_enumeracion_tl04_tl05.sql"
--
-- TERMINA EN ROLLBACK. Todos los datos de prueba se descartan limpiamente.

begin;

do $$
declare
  v_fallos integer := 0;
  v_tenant uuid;
  v_cliente_con_pin uuid;
  v_cliente_sin_pin uuid;
  v_salt text := 'sal-de-prueba-198';
  v_pin text := '4791';
  v_tel_con_pin text := '3009990198';
  v_tel_sin_pin text := '3009990199';
  v_tel_inexistente text := '3009990100';
  v_r jsonb;
  v_msg_no_existe text;
  v_msg_sin_pin text;
  v_msg_pin_malo text;
  v_msg_bloqueada text;
  v_intentos integer;
  v_bloqueo timestamptz;
  v_indexdef text;
begin
  raise notice '======================================================================';
  raise notice 'CONTROL 198 - Portal de la clienta sin enumeracion (TL-04 / TL-05 / D-183)';
  raise notice '======================================================================';

  select id into v_tenant from public.tenants order by created_at limit 1;
  if v_tenant is null then
    raise exception 'No hay ningun negocio en public.tenants: este control necesita al menos uno.';
  end if;

  -- Clienta CON pin
  insert into public.clients (tenant_id, name, phone, active)
  values (v_tenant, 'Clienta Control 198 (con PIN)', v_tel_con_pin, true)
  returning id into v_cliente_con_pin;

  update public.clients
  set portal_pin_salt = v_salt,
      portal_pin_hash = encode(sha256((v_pin || v_salt)::bytea), 'hex'),
      portal_failed_attempts = 0,
      portal_locked_until = null
  where id = v_cliente_con_pin;

  -- Clienta SIN pin
  insert into public.clients (tenant_id, name, phone, active)
  values (v_tenant, 'Clienta Control 198 (sin PIN)', v_tel_sin_pin, true)
  returning id into v_cliente_sin_pin;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 1: celular que no es clienta de este salon ---';
  -- -------------------------------------------------------------------------
  v_r := public.client_portal_authenticate(v_tenant, v_tel_inexistente, v_pin);
  v_msg_no_existe := v_r->>'error';

  if v_r->>'token' is not null then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 1 (CRITICO): entro con un celular que no es clienta.';
  else
    raise notice 'OK 1: no entra. Mensaje: %', v_msg_no_existe;
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 2: clienta real, pero sin PIN asignado ---';
  -- -------------------------------------------------------------------------
  v_r := public.client_portal_authenticate(v_tenant, v_tel_sin_pin, v_pin);
  v_msg_sin_pin := v_r->>'error';

  if v_r->>'token' is not null then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 2 (CRITICO): entro una clienta que no tiene PIN asignado.';
  else
    raise notice 'OK 2: no entra. Mensaje: %', v_msg_sin_pin;
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 3: clienta real con PIN, PIN equivocado ---';
  -- -------------------------------------------------------------------------
  v_r := public.client_portal_authenticate(v_tenant, v_tel_con_pin, '0000');
  v_msg_pin_malo := v_r->>'error';

  if v_r->>'token' is not null then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 3 (CRITICO): entro con un PIN equivocado.';
  else
    raise notice 'OK 3: no entra. Mensaje: %', v_msg_pin_malo;
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 4: clienta bloqueada, y ademas con el PIN CORRECTO ---';
  -- -------------------------------------------------------------------------
  update public.clients
  set portal_locked_until = now() + interval '15 minutes',
      portal_failed_attempts = 5
  where id = v_cliente_con_pin;

  v_r := public.client_portal_authenticate(v_tenant, v_tel_con_pin, v_pin);
  v_msg_bloqueada := v_r->>'error';

  if v_r->>'token' is not null then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 4 (CRITICO): el bloqueo por intentos fallidos no se esta aplicando.';
  else
    raise notice 'OK 4: no entra estando bloqueada. Mensaje: %', v_msg_bloqueada;
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 5: LA ASERCION DE TL-04, los cuatro mensajes iguales ---';
  -- -------------------------------------------------------------------------
  if v_msg_no_existe is distinct from v_msg_sin_pin
     or v_msg_no_existe is distinct from v_msg_pin_malo
     or v_msg_no_existe is distinct from v_msg_bloqueada then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 5 (CRITICO): los mensajes se distinguen entre si. TL-04 SIGUE ABIERTO.';
    raise warning '  no existe : %', v_msg_no_existe;
    raise warning '  sin PIN   : %', v_msg_sin_pin;
    raise warning '  PIN malo  : %', v_msg_pin_malo;
    raise warning '  bloqueada : %', v_msg_bloqueada;
  else
    raise notice 'OK 5: los cuatro casos responden exactamente lo mismo. No hay oraculo.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 6: el PIN correcto sigue funcionando ---';
  -- -------------------------------------------------------------------------
  update public.clients
  set portal_locked_until = null, portal_failed_attempts = 0
  where id = v_cliente_con_pin;

  v_r := public.client_portal_authenticate(v_tenant, v_tel_con_pin, v_pin);

  if v_r->>'token' is null or v_r->>'error' is not null then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 6 (CRITICO): una clienta legitima ya no puede entrar (error=%).', v_r->>'error';
  else
    raise notice 'OK 6: entra con su PIN y recibe token.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 7: el error de formato sigue siendo distinto ---';
  -- -------------------------------------------------------------------------
  v_r := public.client_portal_authenticate(v_tenant, v_tel_con_pin, '12');

  if v_r->>'error' is not distinct from v_msg_no_existe then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 7: el error de formato se unifico de mas; deja de guiar a la clienta sin necesidad.';
  else
    raise notice 'OK 7: el de formato es aparte (no confirma nada). Mensaje: %', v_r->>'error';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 8: el contador sigue subiendo y bloquea a los 5 ---';
  -- -------------------------------------------------------------------------
  update public.clients
  set portal_locked_until = null, portal_failed_attempts = 0
  where id = v_cliente_con_pin;

  for i in 1..5 loop
    perform public.client_portal_authenticate(v_tenant, v_tel_con_pin, '0000');
  end loop;

  select portal_failed_attempts, portal_locked_until
    into v_intentos, v_bloqueo
  from public.clients where id = v_cliente_con_pin;

  if v_intentos < 5 or v_bloqueo is null or v_bloqueo <= now() then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 8: tras 5 intentos fallidos no quedo bloqueada (intentos=%, bloqueo=%).', v_intentos, v_bloqueo;
  else
    raise notice 'OK 8: 5 intentos fallidos -> bloqueada hasta %.', v_bloqueo;
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 9: TL-05, el indice funcional existe y es el correcto ---';
  -- -------------------------------------------------------------------------
  select pg_get_indexdef(i.indexrelid) into v_indexdef
  from pg_index i
  where i.indexrelid = 'public.clients_tenant_phone_digits_idx'::regclass;

  if v_indexdef is null then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 9: no existe el indice clients_tenant_phone_digits_idx.';
  elsif position('regexp_replace' in v_indexdef) = 0
        or position('tenant_id' in v_indexdef) = 0 then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 9b: el indice existe pero no indexa la expresion esperada: %', v_indexdef;
  else
    raise notice 'OK 9: indice presente sobre (tenant_id, digitos del telefono).';
    raise notice '      %', v_indexdef;
  end if;

  -- -------------------------------------------------------------------------
  raise notice '======================================================================';
  if v_fallos = 0 then
    raise notice 'CONTROL 198: TODOS LOS CASOS EN VERDE. TL-04 y TL-05 cerrados.';
  else
    raise exception 'CONTROL 198: % caso(s) fallaron. Revisar arriba.', v_fallos;
  end if;
  raise notice '======================================================================';
end;
$$;

rollback;
