-- BeautyOS / Salón y Más — Portal de la clienta: sin enumeración y con índice
-- (TL-04 y TL-05, paso 8.11, D-183)
--
-- POR QUÉ EXISTE ESTE ARCHIVO
--
-- `client_portal_authenticate` es una función pública: la puede ejecutar `anon`,
-- sin ninguna cuenta, porque de eso se trata el portal de la clienta (D-167). Y
-- el `tenant_id` que necesita también es público desde D-164, porque
-- `get_public_salon_by_slug` se lo devuelve a `anon` a partir del slug del
-- salón. Es decir: cualquiera puede llamarla, para cualquier salón.
--
-- TL-04 — LA FUGA
--
-- Devolvía CUATRO mensajes distinguibles:
--
--   1. 'No encontramos ninguna cuenta con ese celular en este negocio.'
--   2. 'Todavía no tienes un PIN de acceso. Pídelo en el salón.'
--   3. 'Demasiados intentos fallidos. Espera unos minutos...'
--   4. 'PIN incorrecto.'
--
-- Los tres últimos confirman que **ese celular sí es clienta de ese salón**. Con
-- una lista de números de una ciudad y un bucle, se reconstruye la clientela de
-- un centro de estética sin adivinar un solo PIN. Eso es tratamiento de datos
-- personales sin autorización: Ley 1581 (Habeas Data), que es justamente la ley
-- por la que existe el consentimiento de las fotos en D-167.
--
-- Y el contador de intentos no lo frenaba: `portal_failed_attempts` solo sube
-- cuando la clienta existe **y** ya tiene PIN, así que **la enumeración no tenía
-- tope ninguno**. Se podía barrer indefinidamente.
--
-- LA CORRECCIÓN
--
-- Un solo mensaje para los cuatro casos. La pista de "si aún no tienes PIN,
-- pídelo en tu salón" se le da a TODO EL MUNDO, así que ayuda a la clienta que
-- no tiene PIN sin confirmarle nada a quien está barriendo números.
--
-- Se iguala también el TIEMPO de respuesta: antes, si el celular no existía se
-- volvía sin calcular ningún hash, y eso se nota. Ahora se hace el mismo
-- trabajo en los dos caminos.
--
-- El precio, dicho claro: una clienta bloqueada por 5 intentos fallidos ya no
-- ve "espera unos minutos", ve el mensaje genérico. Es el costo de no tener un
-- oráculo, y es el intercambio correcto: la que se bloquea es una persona al
-- año y pide ayuda en el salón; el barrido es automatizable y masivo.
--
-- TL-05 — EL ESCANEO
--
-- La búsqueda es por `regexp_replace(c.phone, '[^0-9]', '', 'g') = <digitos>`,
-- porque la clienta puede estar registrada con o sin "+57" y no tiene por qué
-- saber cuál de las dos formas usó el salón (D-167). Pero al ser una expresión
-- sobre la columna, **ningún índice la puede usar**: cada intento de ingreso
-- recorre las clientas de ese salón una por una.
--
-- Matiz sobre la severidad, para no exagerarla: la consulta filtra antes por
-- `tenant_id`, así que recorre los clientes de UN salón, no la tabla entera.
-- Con cientos de filas no se nota. Lo que lo vuelve un problema es la
-- combinación con TL-04: un endpoint anónimo, sin tope, que se puede llamar en
-- bucle y que en cada llamada hace un recorrido secuencial.
--
-- Se arregla con un índice funcional sobre la misma expresión. Sirve a las dos
-- funciones del portal (`client_portal_authenticate` y `get_client_portal_data`).
--
-- QUÉ NO HACE ESTE ARCHIVO
--
-- No toca el hasheo del PIN. Que sea `sha256` de una sola vuelta sobre 4
-- dígitos es el hallazgo TL-06, va aparte y necesita `pgcrypto`.
--
-- Tampoco pone un tope por IP: eso no se puede hacer desde PostgreSQL y hay que
-- decidirlo en el borde (Cloudflare o Edge Function). Queda anotado.

begin;

-- ---------------------------------------------------------------------------
-- 1. TL-05: el índice funcional
-- ---------------------------------------------------------------------------
--
-- La expresión tiene que ser IDÉNTICA a la de las dos funciones del portal,
-- si no el planificador no lo usa. `regexp_replace` es IMMUTABLE, que es lo que
-- permite indexarla.
--
-- Parcial sobre `active = true` porque las dos consultas siempre lo filtran.

create index if not exists clients_tenant_phone_digits_idx
  on public.clients (tenant_id, (regexp_replace(phone, '[^0-9]', '', 'g')))
  where active = true;

comment on index public.clients_tenant_phone_digits_idx is
  'Sirve la busqueda por digitos del celular del portal de la clienta (TL-05, D-183). '
  'La expresion debe coincidir exactamente con la de client_portal_authenticate y '
  'get_client_portal_data, o deja de usarse sin avisar. NO ELIMINAR.';

-- ---------------------------------------------------------------------------
-- 2. TL-04: un solo mensaje y un solo tiempo de respuesta
-- ---------------------------------------------------------------------------

create or replace function public.client_portal_authenticate(
  p_tenant_id uuid,
  p_phone text,
  p_pin text
)
returns jsonb
language plpgsql
security definer
set search_path = public
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

  -- UN SOLO MENSAJE para los cuatro casos: celular que no es clienta, clienta
  -- sin PIN, clienta bloqueada y PIN equivocado. La pista final se le da a todo
  -- el mundo, así que ayuda sin confirmar nada (TL-04, D-183).
  c_generico constant text :=
    'Celular o PIN incorrectos. Si aún no tienes PIN, pídelo en tu salón.';
begin
  -- Este sí puede ser distinto: habla del formato de lo que se escribió, no de
  -- si existe o no en la base. No confirma nada de nadie.
  if v_phone_digits = '' or v_pin !~ '^[0-9]{4}$' then
    return jsonb_build_object(
      'token', null,
      'error', 'Escribe tu celular y un PIN de 4 dígitos.'
    );
  end if;

  -- Se compara solo por dígitos: la clienta puede haber quedado registrada
  -- con o sin "+57" y no tiene por qué saber cuál de las dos formas usa el
  -- salón. (Desde D-183 esta búsqueda va por el índice funcional de arriba.)
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
  v_tiene_pin := v_encontrada
                 and v_client.portal_pin_hash is not null
                 and v_client.portal_pin_salt is not null;

  if v_tiene_pin then
    v_bloqueada := v_client.portal_locked_until is not null
                   and v_client.portal_locked_until > now();

    v_pin_ok := (not v_bloqueada)
                and encode(sha256((v_pin || v_client.portal_pin_salt)::bytea), 'hex')
                    = v_client.portal_pin_hash;
  else
    -- Mismo trabajo cuando no hay contra qué comparar, para que el tiempo de
    -- respuesta no delate si el celular es clienta o no (TL-04, D-183).
    perform encode(sha256((v_pin || 'relleno-de-tiempo-constante')::bytea), 'hex');
  end if;

  if not v_pin_ok then
    -- El contador solo tiene sentido cuando hay una cuenta real que proteger.
    -- Ya no sirve de nada para enumerar, porque la respuesta es la misma en
    -- todos los casos.
    if v_tiene_pin and not v_bloqueada then
      update public.clients
      set portal_failed_attempts = portal_failed_attempts + 1,
          portal_locked_until = case
            when portal_failed_attempts + 1 >= 5 then now() + interval '15 minutes'
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
      portal_session_expires_at = now() + interval '60 days'
  where id = v_client.id;

  return jsonb_build_object('token', v_token, 'error', null);
end;
$$;

comment on function public.client_portal_authenticate(uuid, text, text) is
  'Verifica celular + PIN del portal de la clienta. Devuelve UN SOLO mensaje de error para todos los '
  'casos de fallo: distinguirlos permitia enumerar que celulares son clientas de un salon sin adivinar '
  'ningun PIN (TL-04, D-183, Ley 1581). NO volver a separar los mensajes. NO ELIMINAR.';

-- Los permisos no cambian: la sigue ejecutando `anon`, que es el punto del
-- portal. Se re-declaran porque `create or replace` no los toca y conviene que
-- queden a la vista de quien lea esta migración.
revoke all on function public.client_portal_authenticate(uuid, text, text)
  from public;
grant execute on function public.client_portal_authenticate(uuid, text, text)
  to anon, authenticated;

commit;
