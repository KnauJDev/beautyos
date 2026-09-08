-- ============================================================================
-- MIGRACIÓN: 20260908120000_las_cifras_cuentan_las_sedes_d232.sql
-- DESCRIPCIÓN: El dinero de las sedes empieza a contar (D-232, paso 9.34).
--
-- POR QUÉ EXISTE
--
-- D-188 decidió el 01-sep que el plan se cobra **por sede activa**, y D-190 a
-- D-192 lo construyeron el 02-sep. Pero las métricas de la plataforma se
-- escribieron el **29-ago** (D-172) y nunca se volvieron a mirar. Resultado,
-- verificado el 08-sep contra el código:
--
--   * El MRR sumaba el precio del NEGOCIO, una vez por negocio. Un salón con
--     tres sedes pagando tres veces aparecía como una.
--   * El cobrado histórico suma `payload->>'monto_cop_recibido'`, y el pago de
--     sede **no escribía esa clave**: su payload era el crudo de ePayco. Un
--     pago de sede quedaba registrado como evento y no sumaba en ninguna cifra.
--   * Y esa misma clave alimenta **las comisiones de partners**. Un partner que
--     refiriera un salón de tres sedes cobraba por una. **Eso no era un número
--     mal pintado: era dinero que se le debe a un tercero y no aparecía.**
--
-- QUÉ CAMBIA
--
--   1. `beautyos_procesar_pago_de_sede` escribe `monto_cop_recibido` en el
--      evento, igual que hace el pago del negocio desde D-160. Con eso se
--      arreglan el cobrado histórico y las comisiones **sin tocar ninguna de
--      las dos funciones que las calculan**.
--   2. `platform_get_saas_metrics` calcula el MRR sobre las **sedes activas**.
--
-- CÓMO SE ESCRIBIÓ, que importa para revisarla
--
-- Los dos cuerpos se **extrajeron de sus migraciones de origen** y solo se les
-- insertó lo nuevo. No se transcribieron a mano: la regla 10 del apartado 8
-- existe porque reescribir una función es donde se cuelan los errores, y aquí
-- el único cambio es el que se lee arriba.
-- ============================================================================

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

  -- D-232 (paso 9.34): dejar escrito CUANTO se recibio, en la misma clave que
  -- usa el pago del negocio desde D-160.
  --
  -- Sin esta linea el evento quedaba con el payload crudo de ePayco, y las tres
  -- cifras que leen `monto_cop_recibido` no veian ni un peso de las sedes:
  -- el cobrado historico del panel, y -- lo que de verdad importaba -- las
  -- comisiones de partners. Un partner que refiriera un salon de tres sedes
  -- cobraba por una.
  update public.subscription_events
  set payload = payload || jsonb_build_object(
    'motivo', v_calc.motivo,
    'monto_cop_esperado', v_calc.monto_cop,
    'monto_cop_recibido', p_amount_cop,
    'periodo_inicio', v_calc.periodo_inicio,
    'periodo_fin', v_calc.periodo_fin,
    'branch_id', p_branch_id,
    'es_sede_principal', coalesce(v_es_principal, false)
  )
  where id = v_event_id;

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

create or replace function public.platform_get_saas_metrics()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_mrr_cop bigint;
  v_total_collected_cop bigint;
  v_active_count integer;
  v_trialing_count integer;
  v_past_due_count integer;
  v_cancelled_count integer;
  v_ever_trialed_count integer;
  v_ever_converted_count integer;
  v_conversion_rate numeric;
begin
  if private.beautyos_current_platform_role() is null then
    raise exception 'No autorizado: se requiere rol de plataforma.';
  end if;

  -- MRR: suma del precio efectivo de cada SEDE ACTIVA (D-232, paso 9.34).
  --
  -- Antes se sumaba el precio del NEGOCIO, una vez por negocio. Eso quedo
  -- obsoleto el 02-sep con D-190/D-191: desde D-188 el plan se cobra **por
  -- sede activa**, y un salon de tres sedes aparecia como uno.
  --
  -- No se suman negocio + sedes, que contaria dos veces la principal: la
  -- suscripcion del negocio ES la de la sede principal, y el propio
  -- `beautyos_procesar_pago_de_sede` lo dice -- "la sede principal arrastra al
  -- negocio; una sede secundaria NO lo toca". Se cuentan las sedes, que es la
  -- unidad de cobro.
  select coalesce(sum(pes.precio_cop), 0)
    into v_mrr_cop
  from public.branch_subscriptions bs
  join public.branches b on b.id = bs.branch_id
  join public.tenants t on t.id = bs.tenant_id
  left join lateral (
    select precio_cop from private.beautyos_precio_efectivo_sede(bs.branch_id)
  ) pes on true
  where bs.status = 'active'
    and b.active
    and not t.is_demo;

  -- Recaudo histórico: mismo criterio que el historial por tenant (D-161):
  -- solo pagos de ePayco que sí activaron/renovaron una suscripción.
  select coalesce(sum((se.payload->>'monto_cop_recibido')::bigint), 0)
    into v_total_collected_cop
  from public.subscription_events se
  join public.tenants t on t.id = se.tenant_id
  where se.provider = 'epayco'
    and se.payload ? 'monto_cop_recibido'
    and not t.is_demo;

  select
    count(*) filter (where ts.status = 'active'),
    count(*) filter (where ts.status = 'trialing'),
    count(*) filter (where ts.status in ('past_due', 'grace')),
    count(*) filter (where ts.status = 'cancelled')
    into v_active_count, v_trialing_count, v_past_due_count, v_cancelled_count
  from public.tenant_subscriptions ts
  join public.tenants t on t.id = ts.tenant_id
  where not t.is_demo;

  -- Conversión prueba -> activo: de los salones que alguna vez tuvieron
  -- reloj de prueba (trial_ends_at no nulo), cuántos llegaron a pagar al
  -- menos una vez.
  select count(*)
    into v_ever_trialed_count
  from public.tenant_subscriptions ts
  join public.tenants t on t.id = ts.tenant_id
  where ts.trial_ends_at is not null
    and not t.is_demo;

  select count(distinct se.tenant_id)
    into v_ever_converted_count
  from public.subscription_events se
  join public.tenant_subscriptions ts on ts.tenant_id = se.tenant_id
  join public.tenants t on t.id = se.tenant_id
  where se.provider = 'epayco'
    and se.payload ? 'monto_cop_recibido'
    and ts.trial_ends_at is not null
    and not t.is_demo;

  if v_ever_trialed_count > 0 then
    v_conversion_rate := round((v_ever_converted_count::numeric / v_ever_trialed_count::numeric) * 100, 1);
  else
    v_conversion_rate := 0;
  end if;

  return jsonb_build_object(
    'mrr_cop', v_mrr_cop,
    'total_collected_cop', v_total_collected_cop,
    'active_count', v_active_count,
    'trialing_count', v_trialing_count,
    'past_due_count', v_past_due_count,
    'cancelled_count', v_cancelled_count,
    'conversion_rate_percent', v_conversion_rate
  );
end;
$$;

commit;
