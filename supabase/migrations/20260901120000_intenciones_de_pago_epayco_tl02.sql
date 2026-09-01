-- BeautyOS / Salón y Más — Intenciones de pago de ePayco (TL-02, paso 8.10, D-182)
--
-- POR QUÉ EXISTE ESTE ARCHIVO
--
-- El webhook de ePayco valida la firma criptográfica SHA-256 (D-141), y esa
-- parte está bien hecha. El problema es qué cubre esa firma. La fórmula
-- estándar de ePayco es:
--
--   sha256(p_cust_id ^ p_key ^ x_ref_payco ^ x_transaction_id ^ x_amount ^ x_currency_code)
--
-- Ahí NO están `x_extra1` (el negocio) ni `x_extra2` (el plan), que son
-- justamente los dos campos con los que el webhook decide A QUIÉN se le activa
-- la suscripción y CON QUÉ PLAN. O sea: la firma demuestra que hubo un pago de
-- ese monto en nuestro comercio, pero no dice de qué negocio era.
--
-- Camino de abuso concreto (hallazgo TL-02 de la auditoría del 01-sep):
--   1. Un cliente real paga su propia suscripción por el flujo normal.
--   2. Recibe (o captura) la confirmación firmada de ePayco.
--   3. La reenvía al webhook cambiando `x_extra1` por el uuid de otro negocio.
--   4. La firma sigue siendo válida, porque no cubre ese campo.
--
-- Mitigación que YA existía y por la que esto no era una puerta abierta: el
-- `UNIQUE(provider, provider_event_id)` de D-141 rechaza la segunda vez que se
-- procesa la misma referencia. Pero eso convierte el ataque en una carrera, no
-- lo impide: si el reenvío manipulado llega antes que la notificación legítima
-- de ePayco, gana el atacante y el pago legítimo queda bloqueado por idempotencia.
--
-- LA SOLUCIÓN
--
-- Que el servidor decida el negocio y el plan ANTES de mandar a nadie a pagar,
-- y que el webhook lea esa decisión en vez de creerle al payload.
--
-- `create-epayco-session` ya genera el número de factura (`SUB-XXXXXXXX-<ts>`)
-- y ya calcula el monto con `beautyos_calcular_cargo_epayco`, así que ya sabe
-- todo lo que hace falta. Solo faltaba escribirlo. Esta migración crea:
--
--   1. public.subscription_payment_intents — el vínculo factura → negocio → plan,
--      escrito por el servidor en el momento de abrir el checkout.
--   2. private.beautyos_registrar_intencion_pago(...) — la escribe.
--   3. private.beautyos_resolver_intencion_pago(...) — la lee y contrasta lo
--      que dice el payload. Es la que convierte el hallazgo en imposible.
--
-- La factura SÍ va dentro de campos que el flujo controla de extremo a extremo
-- y no la fija el cliente: la genera el servidor y viaja en `x_id_invoice`.
--
-- QUÉ NO HACE
--
-- No toca `private.beautyos_procesar_evento_epayco` ni la validación de monto
-- de D-159/D-160: esas siguen mandando sobre cuánto vale el plan y cómo se
-- ancla el ciclo. Esto solo blinda la pregunta anterior, que es de quién es
-- el pago.

begin;

-- ---------------------------------------------------------------------------
-- 1. La tabla
-- ---------------------------------------------------------------------------

create table if not exists public.subscription_payment_intents (
  id uuid primary key default gen_random_uuid(),

  -- Número de factura que genera `create-epayco-session` y que ePayco devuelve
  -- en `x_id_invoice`. Es la llave de unión con la confirmación.
  invoice_number text not null,

  tenant_id uuid not null references public.tenants(id) on delete cascade,

  -- Plan y monto que el SERVIDOR calculó al abrir el checkout, con
  -- `beautyos_calcular_cargo_epayco`. Se guardan para poder contrastar.
  plan_code text not null,
  plan_id uuid,
  amount_cop bigint not null,

  -- `pendiente` mientras nadie ha confirmado; `verificada` cuando el webhook
  -- la usó para resolver un pago; `rechazada` si el payload no coincidió.
  --
  -- Ojo con lo que esta columna NO es: el registro de lo que pasó con el dinero
  -- vive en `subscription_events` (D-141), que es el que manda. Esto es el
  -- rastro de la decisión previa, no un segundo libro de cuentas.
  status text not null default 'pendiente',

  -- Usuario autenticado que abrió el checkout (auditoría).
  created_by uuid,

  x_ref_payco text,
  motivo_rechazo text,

  created_at timestamptz not null default now(),
  resolved_at timestamptz,

  constraint subscription_payment_intents_invoice_unico unique (invoice_number),
  constraint subscription_payment_intents_status_valido
    check (status in ('pendiente', 'verificada', 'rechazada')),
  -- Regla del dinero entero en pesos (D-175): `bigint` ya lo garantiza; el
  -- candado que falta es que nadie registre una intención de cobrar cero.
  constraint subscription_payment_intents_monto_positivo
    check (amount_cop > 0)
);

comment on table public.subscription_payment_intents is
  'Vinculo factura -> negocio -> plan, escrito por el servidor al abrir el checkout de ePayco. '
  'Existe porque la firma SHA-256 de ePayco no cubre x_extra1 ni x_extra2, asi que el webhook no '
  'puede creerle al payload sobre a quien activarle la suscripcion (TL-02, D-182). NO ELIMINAR.';

comment on column public.subscription_payment_intents.invoice_number is
  'Factura SUB-XXXXXXXX-<timestamp> generada por create-epayco-session. Llega de vuelta en x_id_invoice.';

comment on column public.subscription_payment_intents.status is
  'pendiente | verificada | rechazada. El registro de lo que paso con el dinero vive en subscription_events (D-141).';

create index if not exists subscription_payment_intents_tenant_idx
  on public.subscription_payment_intents (tenant_id, created_at desc);

create index if not exists subscription_payment_intents_status_idx
  on public.subscription_payment_intents (status)
  where status = 'pendiente';

-- Deny-all deliberado, igual que el resto de tablas del proyecto: no se accede
-- por PostgREST, solo por las funciones de abajo con `service_role`. Sin
-- politicas, RLS bloquea a `anon` y a `authenticated` por completo.
alter table public.subscription_payment_intents enable row level security;

revoke all on table public.subscription_payment_intents from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Registrar la intención (la llama `create-epayco-session`)
-- ---------------------------------------------------------------------------

create or replace function private.beautyos_registrar_intencion_pago(
  p_invoice_number text,
  p_tenant_id uuid,
  p_plan_code text,
  p_plan_id uuid,
  p_amount_cop bigint,
  p_created_by uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_id uuid;
begin
  if p_invoice_number is null or length(trim(p_invoice_number)) = 0 then
    raise exception 'Parametros invalidos: la factura es obligatoria.';
  end if;

  if p_tenant_id is null then
    raise exception 'Parametros invalidos: el negocio es obligatorio.';
  end if;

  if p_amount_cop is null or p_amount_cop <= 0 then
    raise exception 'Parametros invalidos: el monto debe ser mayor que cero.';
  end if;

  -- Reabrir el checkout con la misma factura no deberia pasar (lleva
  -- timestamp), pero si pasa se actualiza en vez de reventar: lo que importa
  -- es que la factura apunte al negocio correcto, no cuantas veces se escribio.
  insert into public.subscription_payment_intents (
    invoice_number, tenant_id, plan_code, plan_id, amount_cop, created_by
  )
  values (
    trim(p_invoice_number), p_tenant_id, p_plan_code, p_plan_id, p_amount_cop, p_created_by
  )
  on conflict (invoice_number) do update
    set tenant_id  = excluded.tenant_id,
        plan_code  = excluded.plan_code,
        plan_id    = excluded.plan_id,
        amount_cop = excluded.amount_cop,
        created_by = excluded.created_by
  returning id into v_id;

  return v_id;
end;
$$;

comment on function private.beautyos_registrar_intencion_pago(text, uuid, text, uuid, bigint, uuid) is
  'Registra la decision del servidor (que negocio, que plan, cuanto) antes de mandar a pagar. '
  'La llama create-epayco-session con service_role (TL-02, D-182). NO ELIMINAR.';

-- ---------------------------------------------------------------------------
-- 3. Resolver la intención (la llama `epayco-webhook`)
-- ---------------------------------------------------------------------------
--
-- Devuelve SIEMPRE una fila. `coincide` es el veredicto; `tenant_id` y
-- `plan_code` son los valores autoritativos, los del servidor, no los del
-- payload. Cuando `coincide` es false el webhook debe rechazar el evento.

create or replace function private.beautyos_resolver_intencion_pago(
  p_invoice_number text,
  p_tenant_en_payload uuid default null,
  p_x_ref_payco text default null
)
returns table (
  coincide boolean,
  tenant_id uuid,
  plan_code text,
  amount_cop bigint,
  motivo text
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_intent public.subscription_payment_intents%rowtype;
begin
  if p_invoice_number is null or length(trim(p_invoice_number)) = 0 then
    return query select false, null::uuid, null::text, null::bigint,
      'La confirmacion no trae numero de factura, asi que no se puede saber de que negocio es.'::text;
    return;
  end if;

  select * into v_intent
  from public.subscription_payment_intents
  where invoice_number = trim(p_invoice_number)
  for update;

  if not found then
    -- FAIL-CLOSED: sin intencion registrada no se sabe de quien es el pago, y
    -- adivinarlo por el payload es exactamente lo que se vino a cerrar.
    return query select false, null::uuid, null::text, null::bigint,
      format('No hay intencion de pago registrada para la factura %s.', trim(p_invoice_number))::text;
    return;
  end if;

  -- El payload dice pertenecer a otro negocio que el que el servidor decidio
  -- al abrir el checkout. Esto es el ataque de TL-02, tal cual.
  if p_tenant_en_payload is not null and p_tenant_en_payload <> v_intent.tenant_id then
    update public.subscription_payment_intents
    set status = 'rechazada',
        resolved_at = now(),
        x_ref_payco = coalesce(p_x_ref_payco, x_ref_payco),
        motivo_rechazo = format(
          'El payload declaraba el negocio %s pero la factura se emitio para %s.',
          p_tenant_en_payload, v_intent.tenant_id
        )
    where id = v_intent.id;

    return query select false, v_intent.tenant_id, v_intent.plan_code, v_intent.amount_cop,
      format(
        'La confirmacion declara el negocio %s pero la factura %s se emitio para %s.',
        p_tenant_en_payload, v_intent.invoice_number, v_intent.tenant_id
      )::text;
    return;
  end if;

  update public.subscription_payment_intents
  set status = 'verificada',
      resolved_at = now(),
      x_ref_payco = coalesce(p_x_ref_payco, x_ref_payco)
  where id = v_intent.id;

  return query select true, v_intent.tenant_id, v_intent.plan_code, v_intent.amount_cop, null::text;
end;
$$;

comment on function private.beautyos_resolver_intencion_pago(text, uuid, text) is
  'Resuelve de que negocio y plan es una confirmacion de ePayco leyendo la intencion registrada por el '
  'servidor, no el payload. Falla cerrado si no hay intencion (TL-02, D-182). NO ELIMINAR.';

-- ---------------------------------------------------------------------------
-- 4. Permisos: solo el servidor
-- ---------------------------------------------------------------------------

revoke all on function private.beautyos_registrar_intencion_pago(text, uuid, text, uuid, bigint, uuid)
  from public, anon, authenticated;
revoke all on function private.beautyos_resolver_intencion_pago(text, uuid, text)
  from public, anon, authenticated;

grant execute on function private.beautyos_registrar_intencion_pago(text, uuid, text, uuid, bigint, uuid)
  to service_role;
grant execute on function private.beautyos_resolver_intencion_pago(text, uuid, text)
  to service_role;

commit;
