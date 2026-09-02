-- BeautyOS / Salón y Más — Cobro por sede: la base (D-191, Etapa 3a de D-188)
--
-- Paso 8.16, primera mitad.
--
-- QUÉ HACE ESTA MIGRACIÓN
--
--   1. La intención de pago (D-182) aprende de sedes: gana `branch_id`.
--   2. Nace `beautyos_calcular_cargo_sede`, que dice cuánto cuesta activar o
--      renovar UNA sede, con el prorrateo hasta la fecha ancla del negocio.
--
-- **No toca las Edge Functions ni el webhook.** Esa es la 3b, y va aparte a
-- propósito: esto es el código que cobra, y lo que se rompa aquí no se nota
-- hasta que alguien paga.
--
-- ES COMPATIBLE HACIA ATRÁS, Y ESO IMPORTA
--
-- `beautyos_registrar_intencion_pago` gana un parámetro **con valor por
-- defecto**, así que las funciones que hoy están desplegadas la siguen llamando
-- igual y siguen funcionando. `beautyos_resolver_intencion_pago` devuelve una
-- columna más, y el webhook desplegado lee las que le interesan y no se entera.
--
-- Se puede aplicar esta migración sin desplegar nada. Una intención sin
-- `branch_id` es lo de hoy: un cobro del negocio entero.
--
-- LA FECHA ANCLA ES DEL NEGOCIO, NO DE CADA SEDE
--
-- Cuando un salón activa su segunda sede a mitad de mes, se le cobra **solo lo
-- que falta hasta su fecha de corte**, y desde el siguiente ciclo paga las dos
-- completas. Es lo que se decidió, y además es lo único que no vuelve loco al
-- dueño: **un salón, una fecha de cobro**. Si cada sede tuviera su propia
-- ancla, un salón con tres locales recibiría tres cobros en tres días
-- distintos del mes.
--
-- El prorrateo usa **la misma fórmula** que el pago tardío en gracia de D-160
-- —días restantes sobre 30, redondeando hacia arriba— porque es el mismo
-- problema y tener dos fórmulas para lo mismo es cómo empiezan las
-- discrepancias de un peso que nadie sabe explicar.

begin;

-- ---------------------------------------------------------------------------
-- 1. La intención de pago aprende de sedes
-- ---------------------------------------------------------------------------

alter table public.subscription_payment_intents
  add column if not exists branch_id uuid references public.branches(id) on delete cascade;

comment on column public.subscription_payment_intents.branch_id is
  'La sede que se esta pagando (D-191). Null = cobro del negocio entero, que es como funcionaba hasta '
  'la Etapa 3 y como siguen funcionando los pagos ya registrados.';

create index if not exists subscription_payment_intents_branch_idx
  on public.subscription_payment_intents (branch_id)
  where branch_id is not null;

-- ---------------------------------------------------------------------------
-- 2. Registrar la intención, ahora con sede
-- ---------------------------------------------------------------------------
--
-- Se DEJA CAER y se vuelve a crear en la misma transaccion, en vez de crear una
-- sobrecarga: dos funciones con el mismo nombre y distinta firma dejarian a
-- PostgREST eligiendo, y el sitio donde eso se descubre es el checkout.

drop function if exists private.beautyos_registrar_intencion_pago(
  text, uuid, text, uuid, bigint, uuid
);

create or replace function private.beautyos_registrar_intencion_pago(
  p_invoice_number text,
  p_tenant_id uuid,
  p_plan_code text,
  p_plan_id uuid,
  p_amount_cop bigint,
  p_created_by uuid default null,
  p_branch_id uuid default null
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

  -- La sede, si viene, tiene que ser de ese negocio. Es la misma clase de
  -- comprobacion que cerro TL-01: no dar por bueno un identificador ajeno.
  if p_branch_id is not null and not exists (
    select 1 from public.branches b
    where b.id = p_branch_id and b.tenant_id = p_tenant_id
  ) then
    raise exception 'La sede indicada no pertenece a ese negocio.';
  end if;

  insert into public.subscription_payment_intents (
    invoice_number, tenant_id, branch_id, plan_code, plan_id, amount_cop, created_by
  )
  values (
    trim(p_invoice_number), p_tenant_id, p_branch_id, p_plan_code, p_plan_id,
    p_amount_cop, p_created_by
  )
  on conflict (invoice_number) do update
    set tenant_id  = excluded.tenant_id,
        branch_id  = excluded.branch_id,
        plan_code  = excluded.plan_code,
        plan_id    = excluded.plan_id,
        amount_cop = excluded.amount_cop,
        created_by = excluded.created_by
  returning id into v_id;

  return v_id;
end;
$$;

comment on function private.beautyos_registrar_intencion_pago(text, uuid, text, uuid, bigint, uuid, uuid) is
  'Registra la decision del servidor antes de mandar a pagar (D-182), ahora con la sede (D-191). '
  'p_branch_id null = cobro del negocio entero. NO ELIMINAR.';

-- ---------------------------------------------------------------------------
-- 3. Resolverla devuelve tambien la sede
-- ---------------------------------------------------------------------------

drop function if exists private.beautyos_resolver_intencion_pago(text, uuid, text);

create or replace function private.beautyos_resolver_intencion_pago(
  p_invoice_number text,
  p_tenant_en_payload uuid default null,
  p_x_ref_payco text default null
)
returns table (
  coincide boolean,
  tenant_id uuid,
  branch_id uuid,
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
    return query select false, null::uuid, null::uuid, null::text, null::bigint,
      'La confirmacion no trae numero de factura, asi que no se puede saber de que negocio es.'::text;
    return;
  end if;

  select * into v_intent
  from public.subscription_payment_intents
  where invoice_number = trim(p_invoice_number)
  for update;

  if not found then
    -- FAIL-CLOSED: sin intencion registrada no se sabe de quien es el pago, y
    -- adivinarlo por el payload es exactamente lo que cerro TL-02.
    return query select false, null::uuid, null::uuid, null::text, null::bigint,
      format('No hay intencion de pago registrada para la factura %s.', trim(p_invoice_number))::text;
    return;
  end if;

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

    return query select false, v_intent.tenant_id, v_intent.branch_id,
      v_intent.plan_code, v_intent.amount_cop,
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

  return query select true, v_intent.tenant_id, v_intent.branch_id,
    v_intent.plan_code, v_intent.amount_cop, null::text;
end;
$$;

comment on function private.beautyos_resolver_intencion_pago(text, uuid, text) is
  'Resuelve de que negocio, sede y plan es una confirmacion de ePayco leyendo la intencion registrada por '
  'el servidor, no el payload. Falla cerrado si no hay intencion (TL-02, D-182, D-191). NO ELIMINAR.';

-- ---------------------------------------------------------------------------
-- 4. Cuanto cuesta activar o renovar UNA sede
-- ---------------------------------------------------------------------------
--
-- Hermana de `beautyos_calcular_cargo_epayco` (D-160), y con sus mismos casos y
-- su misma formula de prorrateo. La diferencia esta en el caso nuevo: **el alta
-- de una sede a mitad del ciclo del negocio**, que cobra solo hasta la fecha de
-- corte para que el salon siga teniendo UNA sola fecha de cobro.

create or replace function private.beautyos_calcular_cargo_sede(p_branch_id uuid)
returns table (
  monto_cop bigint,
  periodo_inicio timestamptz,
  periodo_fin timestamptz,
  motivo text,
  tenant_id_resuelto uuid
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_bs public.branch_subscriptions%rowtype;
  v_ancla timestamptz;
  v_precio bigint;
  v_dias numeric;
begin
  select * into v_bs
  from public.branch_subscriptions
  where branch_id = p_branch_id;

  if not found then
    return;
  end if;

  select precio_cop into v_precio
  from private.beautyos_precio_efectivo_sede(p_branch_id);

  if v_precio is null or v_precio <= 0 then
    return;
  end if;

  tenant_id_resuelto := v_bs.tenant_id;

  -- La fecha de corte del NEGOCIO. Un salon, una fecha de cobro.
  select ts.current_period_end into v_ancla
  from public.tenant_subscriptions ts
  where ts.tenant_id = v_bs.tenant_id;

  if v_bs.current_period_end is null then
    -- La sede nunca se ha pagado.
    if v_ancla is not null and v_ancla > now() then
      -- Se engancha al ciclo que el negocio ya tiene: solo lo que falta.
      -- Misma formula que el pago tardio de D-160.
      periodo_inicio := now();
      periodo_fin := v_ancla;
      v_dias := ceil(extract(epoch from (v_ancla - now())) / 86400.0);
      monto_cop := ceil(v_precio * v_dias / 30.0);
      motivo := 'alta_de_sede_prorrateada';
    else
      -- El negocio no tiene ciclo vivo: esta sede lo estrena.
      periodo_inicio := now();
      periodo_fin := now() + interval '30 days';
      monto_cop := v_precio;
      motivo := 'alta_de_sede_primer_ciclo';
    end if;

  elsif now() <= v_bs.current_period_end then
    -- Renovacion anticipada: se acumula al final, la ancla no se corre.
    periodo_inicio := v_bs.current_period_end;
    periodo_fin := v_bs.current_period_end + interval '30 days';
    monto_cop := v_precio;
    motivo := 'renovacion_anticipada';

  elsif v_bs.status in ('past_due', 'grace') then
    -- Pago tardio dentro de gracia: prorratea hacia la proxima ancla.
    periodo_fin := v_bs.current_period_end + interval '30 days';
    periodo_inicio := now();
    v_dias := ceil(extract(epoch from (periodo_fin - now())) / 86400.0);
    monto_cop := ceil(v_precio * v_dias / 30.0);
    motivo := 'pago_tardio_prorrateado';

  else
    -- Suspendida, o vencida por otra via: mes completo y se reancla.
    periodo_inicio := now();
    periodo_fin := now() + interval '30 days';
    monto_cop := v_precio;
    motivo := 'reactivacion_post_suspension';
  end if;

  return next;
end;
$$;

comment on function private.beautyos_calcular_cargo_sede(uuid) is
  'Cuanto cuesta activar o renovar una sede, con el prorrateo hasta la fecha de corte del NEGOCIO para que '
  'el salon tenga una sola fecha de cobro (D-191). Misma formula de prorrateo que D-160. NO ELIMINAR.';

-- ---------------------------------------------------------------------------
-- 5. Permisos
-- ---------------------------------------------------------------------------

revoke all on function private.beautyos_registrar_intencion_pago(text, uuid, text, uuid, bigint, uuid, uuid)
  from public, anon, authenticated;
grant execute on function private.beautyos_registrar_intencion_pago(text, uuid, text, uuid, bigint, uuid, uuid)
  to service_role;

revoke all on function private.beautyos_resolver_intencion_pago(text, uuid, text)
  from public, anon, authenticated;
grant execute on function private.beautyos_resolver_intencion_pago(text, uuid, text)
  to service_role;

revoke all on function private.beautyos_calcular_cargo_sede(uuid)
  from public, anon, authenticated;
grant execute on function private.beautyos_calcular_cargo_sede(uuid) to service_role;

commit;
