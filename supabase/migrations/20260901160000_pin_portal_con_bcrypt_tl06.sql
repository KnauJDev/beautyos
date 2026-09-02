-- BeautyOS / Salón y Más — El PIN del portal pasa a bcrypt (TL-06, paso 8.12, D-185)
--
-- POR QUÉ EXISTE ESTE ARCHIVO
--
-- El PIN de la clienta se guardaba como `encode(sha256((pin || salt)::bytea), 'hex')`:
-- SHA-256 de **una sola vuelta**, con sal, sobre un PIN de **4 dígitos**.
--
-- La sal está bien puesta y evita las tablas precalculadas. El problema es otro:
-- SHA-256 está diseñado para ser **rápido**, y 4 dígitos son **10.000
-- combinaciones**. Si la tabla `clients` se filtrara alguna vez, recorrer las
-- 10.000 por cada clienta es cuestión de milisegundos en cualquier portátil. La
-- sal no ayuda contra eso: solo obliga a hacerlo clienta por clienta, y 10.000
-- intentos por clienta sigue siendo instantáneo.
--
-- bcrypt está diseñado para lo contrario: ser deliberadamente lento. Con coste
-- 10 cada comprobación tarda del orden de 50-100 ms, así que las 10.000
-- combinaciones pasan de milisegundos a horas **por cada clienta**. Y de paso
-- frena también el ataque en vivo contra el portal.
--
-- LA SEGUNDA MITAD DE TL-06, QUE NO ES DE HASHEO
--
-- El bloqueo era plano: 5 intentos errados y **15 minutos** fuera. Eso protege
-- contra la fuerza bruta, pero le da a cualquiera una forma de **dejar sin
-- acceso a una clienta real sabiendo solo su celular**, sin filtrar nada y sin
-- adivinar ningún PIN. Basta con equivocarse cinco veces a propósito.
--
-- Ahora el bloqueo **escala**: 1 minuto a los 5 intentos, 5 minutos a los 10 y
-- 30 minutos a los 15. Es mejor por los dos lados:
--   - Al que molesta le cuesta a la clienta 1 minuto, no 15.
--   - Al que ataca de verdad le deja 10 intentos por hora a partir del tercer
--     tramo: 10.000 combinaciones son más de mil horas, y eso ANTES de sumar
--     los 50-100 ms de bcrypt.
--
-- CÓMO SE MIGRAN LOS PIN QUE YA EXISTEN
--
-- No se puede reescribir un hash sin el PIN en claro, y el PIN en claro no lo
-- tiene nadie: eso es lo correcto. Así que la migración es **al vuelo**:
--
--   - Un hash que empieza por `$2` es bcrypt y se comprueba con `crypt`.
--   - Cualquier otro es el SHA-256 heredado (D-167) y se comprueba como antes.
--   - **Cuando una clienta entra con un PIN heredado, se le reescribe el hash a
--     bcrypt en ese mismo momento**, sin que ella note nada.
--
-- Ninguna clienta pierde su PIN, y el legado se va vaciando solo a medida que
-- cada una entra. El día que se quiera cerrar del todo, basta con mirar cuántas
-- filas quedan sin `$2` y restablecerles el PIN desde la ficha.
--
-- NOTA SOBRE `portal_pin_salt`
--
-- bcrypt lleva la sal dentro del propio hash, así que la columna deja de hacer
-- falta. **No se borra**: la siguen necesitando los hashes heredados que aún no
-- se han migrado. Se pone a `null` al reescribir a bcrypt.

begin;

-- ---------------------------------------------------------------------------
-- 1. La extensión
-- ---------------------------------------------------------------------------
--
-- Mismo patrón que `pg_cron`/`pg_net` en `20260817140000`. Si ya estuviera
-- instalada en otro esquema, esto no la mueve — por eso las funciones de abajo
-- llevan `extensions` en su `search_path` además de `public`.

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
-- 2. Verificar el PIN: bcrypt, con el legado aceptado y migrado al vuelo
-- ---------------------------------------------------------------------------

create or replace function public.client_portal_authenticate(
  p_tenant_id uuid,
  p_phone text,
  p_pin text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_phone_digits text := regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g');
  v_pin text := trim(coalesce(p_pin, ''));
  v_client public.clients%rowtype;
  v_token text;
  v_encontrada boolean := false;
  v_tiene_pin boolean := false;
  v_bloqueada boolean := false;
  v_pin_ok boolean := false;
  v_era_legado boolean := false;
  v_intentos integer;

  -- UN SOLO MENSAJE para todos los casos de fallo (TL-04, D-183). No volver a
  -- separarlos: distinguirlos permitia enumerar que celulares son clientas.
  c_generico constant text :=
    'Celular o PIN incorrectos. Si aún no tienes PIN, pídelo en tu salón.';
begin
  if v_phone_digits = '' or v_pin !~ '^[0-9]{4}$' then
    return jsonb_build_object(
      'token', null,
      'error', 'Escribe tu celular y un PIN de 4 dígitos.'
    );
  end if;

  select *
    into v_client
  from public.clients c
  where c.tenant_id = p_tenant_id
    and c.active = true
    and regexp_replace(c.phone, '[^0-9]', '', 'g') = v_phone_digits
  order by c.created_at
  limit 1
  for update;

  v_encontrada := found;
  v_tiene_pin := v_encontrada and v_client.portal_pin_hash is not null;

  if v_tiene_pin then
    v_bloqueada := v_client.portal_locked_until is not null
                   and v_client.portal_locked_until > now();

    if not v_bloqueada then
      if v_client.portal_pin_hash like '$2%' then
        -- bcrypt: la sal va dentro del propio hash.
        v_pin_ok := crypt(v_pin, v_client.portal_pin_hash)
                    = v_client.portal_pin_hash;
      elsif v_client.portal_pin_salt is not null then
        -- SHA-256 heredado (D-167). Se acepta esta vez y se migra abajo.
        v_pin_ok := encode(sha256((v_pin || v_client.portal_pin_salt)::bytea), 'hex')
                    = v_client.portal_pin_hash;
        v_era_legado := v_pin_ok;
      end if;
    end if;
  else
    -- Mismo trabajo cuando no hay contra que comparar, para que el tiempo de
    -- respuesta no delate si el celular es clienta o no (TL-04, D-183).
    -- Ahora el relleno tambien es bcrypt, que es lo que cuesta de verdad.
    perform crypt(v_pin, gen_salt('bf', 10));
  end if;

  if not v_pin_ok then
    if v_tiene_pin and not v_bloqueada then
      v_intentos := coalesce(v_client.portal_failed_attempts, 0) + 1;

      -- Bloqueo ESCALONADO (TL-06, D-185): antes eran 15 minutos planos a los
      -- 5 intentos, y eso permitia dejar fuera a una clienta real sabiendo
      -- solo su celular. Ahora el primer tramo cuesta 1 minuto, y al que
      -- insiste de verdad se le cierra la puerta cada vez mas.
      update public.clients
      set portal_failed_attempts = v_intentos,
          portal_locked_until = case
            when v_intentos >= 15 then now() + interval '30 minutes'
            when v_intentos >= 10 then now() + interval '5 minutes'
            when v_intentos >= 5 then now() + interval '1 minute'
            else portal_locked_until
          end
      where id = v_client.id;
    end if;

    return jsonb_build_object('token', null, 'error', c_generico);
  end if;

  v_token := gen_random_uuid()::text;

  update public.clients
  set portal_failed_attempts = 0,
      portal_locked_until = null,
      portal_session_token = v_token,
      portal_session_expires_at = now() + interval '60 days',
      -- Migracion al vuelo (TL-06, D-185): la clienta acaba de demostrar que
      -- sabe su PIN, que es el unico momento en el que se puede reescribir el
      -- hash. `portal_pin_salt` deja de hacer falta: bcrypt la lleva dentro.
      portal_pin_hash = case
        when v_era_legado then crypt(v_pin, gen_salt('bf', 10))
        else portal_pin_hash
      end,
      portal_pin_salt = case when v_era_legado then null else portal_pin_salt end
  where id = v_client.id;

  return jsonb_build_object('token', v_token, 'error', null);
end;
$$;

comment on function public.client_portal_authenticate(uuid, text, text) is
  'Verifica celular + PIN del portal de la clienta. UN SOLO mensaje de error para todos los casos de fallo '
  '(TL-04, D-183): no volver a separarlos. El PIN se guarda con bcrypt y los hashes SHA-256 heredados se '
  'migran al vuelo cuando la clienta entra (TL-06, D-185). Bloqueo escalonado 1/5/30 min. NO ELIMINAR.';

-- ---------------------------------------------------------------------------
-- 3. Asignar o restablecer el PIN: ya nace en bcrypt
-- ---------------------------------------------------------------------------

create or replace function public.admin_reset_client_portal_pin(
  p_client_id uuid,
  p_new_pin text
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_tenant_id uuid := public.get_my_tenant_id();
  v_pin text := trim(coalesce(p_new_pin, ''));
begin
  if v_tenant_id is null then
    raise exception 'No existe un perfil activo asociado al usuario actual.';
  end if;

  if not public.is_owner_or_admin() then
    raise exception 'No autorizado. Solo owner o admin puede restablecer el PIN del portal.';
  end if;

  if v_pin !~ '^[0-9]{4}$' then
    raise exception 'El PIN debe tener exactamente 4 dígitos.';
  end if;

  update public.clients
  set portal_pin_hash = crypt(v_pin, gen_salt('bf', 10)),
      -- bcrypt lleva la sal dentro del hash: la columna solo sirve ya para los
      -- hashes heredados que aun no se han migrado (TL-06, D-185).
      portal_pin_salt = null,
      portal_failed_attempts = 0,
      portal_locked_until = null,
      -- Restablecer el PIN cierra cualquier sesion abierta con el PIN
      -- viejo: si alguien mas lo tenia, deja de servirle.
      portal_session_token = null,
      portal_session_expires_at = null
  where id = p_client_id
    and tenant_id = v_tenant_id;

  if not found then
    raise exception 'El cliente no existe o no pertenece a este negocio.';
  end if;
end;
$$;

comment on function public.admin_reset_client_portal_pin(uuid, text) is
  'Asigna o restablece el PIN del portal de una clienta, ya con bcrypt (TL-06, D-185). Exclusivo owner/admin '
  'del tenant. Misma funcion sirve para la primera asignacion y para restablecer (D-167).';

comment on column public.clients.portal_pin_hash is
  'Hash bcrypt del PIN del portal (TL-06, D-185). Los valores de 64 caracteres hexadecimales son el SHA-256 '
  'heredado de D-167 y se migran solos cuando la clienta entra. Nunca el PIN en texto plano.';

comment on column public.clients.portal_pin_salt is
  'Solo para los hashes SHA-256 heredados de D-167 que aun no se han migrado. bcrypt lleva su sal dentro del '
  'hash, asi que en las filas ya migradas esta columna queda en null (TL-06, D-185).';

-- Los permisos no cambian.
revoke all on function public.client_portal_authenticate(uuid, text, text)
  from public;
grant execute on function public.client_portal_authenticate(uuid, text, text)
  to anon, authenticated;

revoke all on function public.admin_reset_client_portal_pin(uuid, text)
  from public, anon;
grant execute on function public.admin_reset_client_portal_pin(uuid, text)
  to authenticated;

commit;
