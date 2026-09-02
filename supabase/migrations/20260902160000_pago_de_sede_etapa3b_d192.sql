-- BeautyOS / Salón y Más — El pago que activa una sede (D-192, Etapa 3b de D-188)
--
-- Paso 8.16, segunda mitad, parte de base de datos.
--
-- POR QUÉ ESTA FUNCIÓN EXISTE Y NO SE AMPLIÓ LA QUE YA COBRA
--
-- `beautyos_procesar_evento_epayco` es el corazón del cobro: la endureció D-159
-- con la validación de monto, la reescribió D-160 con el ciclo anclado, y
-- D-181/D-182 blindaron el camino que la alimenta. Ampliarla para que además
-- entienda de sedes significaba reescribir entera una función larga que hoy
-- cobra bien — y ese es exactamente el error que D-119, D-122 y D-123
-- documentaron en un solo día.
--
-- **Y hay una razón de fondo, no solo de prudencia:** esa función valida que el
-- monto pagado alcance el precio del plan, con un piso de $10.000. Un cobro
-- prorrateado de una segunda sede puede ser de **$50.000, o de $8.000 si quedan
-- dos días** — y esa validación lo rechazaría. Los dos cobros tienen reglas de
-- monto distintas, así que son dos funciones.
--
-- **Solo se ejecuta una de las dos por pago**, según si la intención (D-191)
-- trae sede o no. Por eso las dos pueden escribir en `subscription_events` sin
-- pisarse: el `UNIQUE(provider, provider_event_id)` de D-141 sigue siendo el
-- que garantiza que un pago se procese una sola vez.
--
-- QUÉ PASA CON EL ACCESO DEL SALÓN
--
-- `tenant_subscriptions` sigue mandando sobre si el salón puede entrar y
-- trabajar (D-068), sobre el aviso de vencimiento (D-143) y sobre lo que ve el
-- panel. Si el pago de una sede no lo tocara, un salón de una sola sede pagaría
-- y **se quedaría fuera de su propia aplicación**.
--
-- Por eso: **cuando se paga la sede principal, se mueve también la suscripción
-- del negocio.** Cuando se paga una sede secundaria, no — su cobro prorrateado
-- termina en la fecha de corte que el negocio ya tiene, y correr esa fecha le
-- regalaría un mes al cliente.

begin;

create or replace function private.beautyos_procesar_pago_de_sede(
  p_tenant_id uuid,
  p_branch_id uuid,
  p_x_ref_payco text,
  p_transaction_id text,
  p_transaction_state text,
  p_cod_transaction_state text,
  p_amount_cop bigint,
  p_currency_code text,
  p_payload jsonb
)
returns table (
  processed boolean,
  previous_status text,
  new_status text,
  message text
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_bs public.branch_subscriptions%rowtype;
  v_sub public.tenant_subscriptions%rowtype;
  v_es_principal boolean;
  v_event_id uuid;
  v_state_clean text;
  v_cod_clean text;
  v_is_accepted boolean;
  v_is_rejected boolean;
  v_calc record;
  v_min_required bigint;
begin
  if p_tenant_id is null or p_branch_id is null
     or p_x_ref_payco is null or length(trim(p_x_ref_payco)) = 0 then
    raise exception 'Parametros invalidos: tenant_id, branch_id y x_ref_payco son obligatorios.';
  end if;

  select * into v_bs
  from public.branch_subscriptions
  where branch_id = p_branch_id
  for update;

  if not found then
    raise exception 'La sede % no tiene suscripcion registrada.', p_branch_id;
  end if;

  -- La sede tiene que ser del negocio que paga. Misma clase de comprobacion
  -- que cerro TL-01: no dar por bueno un identificador que llega de fuera.
  if v_bs.tenant_id <> p_tenant_id then
    raise exception 'La sede no pertenece al negocio indicado.';
  end if;

  select b.is_primary into v_es_principal
  from public.branches b where b.id = p_branch_id;

  select * into v_sub
  from public.tenant_subscriptions
  where tenant_id = p_tenant_id
  for update;

  if v_sub.id is null then
    raise exception 'No existe suscripcion para el negocio (%).', p_tenant_id;
  end if;

  -- Idempotencia: el mismo candado de D-141. Si esta referencia ya se proceso,
  -- aqui se para. Solo una de las dos funciones de cobro corre por pago, asi
  -- que no compiten por esta fila.
  insert into public.subscription_events (
    tenant_id, tenant_subscription_id, event_type, provider, provider_event_id, payload
  ) values (
    p_tenant_id,
    v_sub.id,
    'epayco_sede_' || lower(coalesce(trim(p_transaction_state), 'unknown')),
    'epayco',
    trim(p_x_ref_payco),
    coalesce(p_payload, '{}'::jsonb)
  )
  on conflict (provider, provider_event_id) do nothing
  returning id into v_event_id;

  if v_event_id is null then
    return query select false, v_bs.status, v_bs.status,
      'Evento ePayco duplicado ignorado por idempotencia.'::text;
    return;
  end if;

  v_state_clean := lower(coalesce(trim(p_transaction_state), ''));
  v_cod_clean := coalesce(trim(p_cod_transaction_state), '');

  v_is_accepted := v_state_clean in ('aceptada', 'aprobada', 'approved', 'success')
                   or v_cod_clean = '1';
  v_is_rejected := v_state_clean in ('rechazada', 'fallida', 'rejected', 'failed')
                   or v_cod_clean in ('2', '4');

  -- "Nadie entra solo" (D-125 / D-138): si el negocio esta en revision, un pago
  -- no lo mete por la puerta de atras.
  if v_sub.status in ('pending', 'rejected') then
    return query select true, v_bs.status, v_bs.status,
      'Pago registrado. El negocio esta en revision y requiere aprobacion del propietario.'::text;
    return;
  end if;

  if not v_is_accepted then
    if v_is_rejected then
      return query select true, v_bs.status, v_bs.status,
        'Pago rechazado por la pasarela. La sede no se activa.'::text;
    else
      return query select true, v_bs.status, v_bs.status,
        format('Pago en estado "%s". La sede no se activa todavia.', p_transaction_state)::text;
    end if;
    return;
  end if;

  if p_amount_cop is null or p_amount_cop <= 0 then
    return query select true, v_bs.status, v_bs.status, 'Monto de pago invalido.'::text;
    return;
  end if;

  select * into v_calc from private.beautyos_calcular_cargo_sede(p_branch_id);

  if v_calc is null then
    return query select true, v_bs.status, v_bs.status,
      'No se pudo calcular el cargo de la sede. La sede no se activa.'::text;
    return;
  end if;

  -- El piso de $10.000 NO aplica a los cobros prorrateados: si a la sede le
  -- quedan dos dias hasta el corte del negocio, su cargo legitimo puede ser de
  -- $10.000 o menos. Mismo criterio que D-160 para el pago tardio.
  if v_calc.motivo in ('alta_de_sede_prorrateada', 'pago_tardio_prorrateado') then
    v_min_required := v_calc.monto_cop;
  else
    v_min_required := greatest(10000, v_calc.monto_cop);
  end if;

  if p_amount_cop < v_min_required then
    return query select true, v_bs.status, v_bs.status,
      format(
        'Pago de $%s COP menor al requerido ($%s COP, %s). La sede no se activa.',
        p_amount_cop, v_min_required, v_calc.motivo
      )::text;
    return;
  end if;

  update public.branch_subscriptions
  set status = 'active',
      current_period_start = v_calc.periodo_inicio,
      current_period_end = v_calc.periodo_fin,
      grace_ends_at = null,
      -- La primera activacion se sella una sola vez (D-190).
      activated_at = coalesce(activated_at, now()),
      updated_at = now()
  where branch_id = p_branch_id;

  -- La sede principal arrastra al negocio: si no, un salon de una sola sede
  -- pagaria y se quedaria fuera de su propia aplicacion, porque el acceso, el
  -- aviso de vencimiento y el panel miran `tenant_subscriptions`.
  --
  -- Una sede secundaria NO lo toca: su cobro prorrateado termina en la fecha de
  -- corte que el negocio ya tiene, y correrla le regalaria un mes al cliente.
  if coalesce(v_es_principal, false) then
    update public.tenant_subscriptions
    set status = 'active',
        provider = 'epayco',
        current_period_start = v_calc.periodo_inicio,
        current_period_end = v_calc.periodo_fin,
        grace_ends_at = null,
        updated_at = now()
    where tenant_id = p_tenant_id;
  end if;

  return query select
    true,
    v_bs.status,
    'active'::text,
    format(
      'Sede activada hasta %s (%s).',
      to_char(v_calc.periodo_fin, 'YYYY-MM-DD'),
      v_calc.motivo
    )::text;
end;
$$;

comment on function private.beautyos_procesar_pago_de_sede(
  uuid, uuid, text, text, text, text, bigint, text, jsonb
) is
  'Aplica un pago de ePayco a UNA sede (D-192). Existe aparte de beautyos_procesar_evento_epayco porque las '
  'reglas de monto son distintas: un cobro prorrateado puede estar por debajo del piso de $10.000 y aquella lo '
  'rechazaria. Solo corre una de las dos por pago. La sede PRINCIPAL arrastra la suscripcion del negocio; una '
  'secundaria no. NO ELIMINAR.';

revoke all on function private.beautyos_procesar_pago_de_sede(
  uuid, uuid, text, text, text, text, bigint, text, jsonb
) from public, anon, authenticated;

grant execute on function private.beautyos_procesar_pago_de_sede(
  uuid, uuid, text, text, text, text, bigint, text, jsonb
) to service_role;

commit;
