-- ==============================================================================
-- PASO 9.40 Y HALLAZGO CD: el historial dice de que sede es cada cobro, y un
-- cambio de sede desde el Panel deja rastro. (D-303)
-- ==============================================================================
--
-- QUE PASABA
--
--   9.40: "5. Historial de Periodos Registrados" del Panel no decia de que sede
--         era cada cobro. Desde D-239 cada sede paga lo suyo, asi que un negocio
--         con dos sedes veia una lista de importes sin dueno.
--   CD:   `platform_set_branch_subscription` cambia precio, estado y vencimiento
--         de una sede sin escribir en `subscription_events`. Confirmado en su
--         texto vivo (30-sep). El propietario guardo el precio de la sede de
--         Exito y el historial no enseno nada. Aprobar un negocio y cambiarle el
--         plan si escriben su evento.
--
-- QUE CAMBIA, Y QUE NO (las dos funciones, generadas desde su texto vivo,
-- `intervenciones/extraer_historial_y_cambios_de_sede_940_cd.sql`)
--
--   1. `platform_set_branch_subscription`: misma firma y mismas reglas. Lee la
--      fila antes de cambiarla y, SI ALGO CAMBIO (estado, precio, motivo o
--      vencimiento), escribe el evento `sede_cambiada_desde_el_panel` con el
--      antes y el despues, y quien lo hizo. Guardar lo mismo no escribe nada.
--   2. `platform_get_tenant_subscription_history`: devuelve dos columnas mas al
--      final, `branch_id` y `branch_name`. Cambiar lo que devuelve exige
--      borrarla y crearla: se le devuelven sus permisos (solo `authenticated`,
--      como hoy) y su comentario. El cambio de sede se describe como lo que
--      fue ("precio 4500 -> 10000; estado pending -> active").
--
-- NO se tocan la tabla, los pagos ni `beautyos_procesar_pago_de_sede`.
-- La aplicacion vieja ignora las columnas nuevas, y la nueva aguanta que no
-- esten: da igual que se publique antes o despues de aplicar esto.
--
-- COMO SE APLICA (lo aplica el propietario, regla 16)
--
--   0. El respaldo (regla 15): scripts\respaldo_supabase.ps1
--   1. Esta migracion con scripts\aplicar_sql.ps1
--   2. El control: supabase\sql\237_test_el_historial_dice_la_sede_940_cd.sql
--   3. En pantalla (regla 21): Panel -> la ficha de un negocio -> "5. Historial"
--      debe tener la columna Sede; y al cambiar algo en "1. Esta sede" -> Pago,
--      aparece un renglon nuevo que dice que cambio.
-- ==============================================================================

begin;

-- 1. CD: el cambio de una sede deja rastro.
CREATE OR REPLACE FUNCTION public.platform_set_branch_subscription(p_branch_id uuid, p_status text, p_price_cop bigint DEFAULT NULL::bigint, p_price_reason text DEFAULT NULL::text, p_period_end timestamp with time zone DEFAULT NULL::timestamp with time zone, p_limpiar_precio boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_tenant_id uuid;
  -- CD (D-303): lo que habia y lo que queda, para dejarlo escrito.
  v_antes public.branch_subscriptions%rowtype;
  v_despues public.branch_subscriptions%rowtype;
  v_ts uuid;
begin
  if private.beautyos_current_platform_role() is null then
    raise exception 'No autorizado: solo la plataforma puede cambiar el estado de pago de una sede.';
  end if;

  if p_status is null or p_status not in (
    'pending', 'trialing', 'active', 'past_due', 'grace', 'suspended', 'cancelled'
  ) then
    raise exception 'Estado invalido: %.', coalesce(p_status, 'null');
  end if;

  if p_price_cop is not null
     and (p_price_reason is null or length(trim(p_price_reason)) = 0) then
    raise exception 'Un precio pactado exige motivo. Mismo criterio que D-136.';
  end if;

  -- Quitar el precio y fijar uno a la vez es contradictorio: se rechaza en
  -- vez de adivinar cual gana.
  if p_limpiar_precio and p_price_cop is not null then
    raise exception 'No se puede limpiar el precio y fijar uno en la misma operacion.';
  end if;

  select tenant_id into v_tenant_id
  from public.branches where id = p_branch_id;

  if v_tenant_id is null then
    raise exception 'La sede no existe.';
  end if;

  select * into v_antes
  from public.branch_subscriptions
  where branch_id = p_branch_id
  for update;

  update public.branch_subscriptions
  set status = p_status,
      price_cop = case when p_limpiar_precio then null
                       else coalesce(p_price_cop, price_cop) end,
      price_reason = case when p_limpiar_precio then null
                          else coalesce(p_price_reason, price_reason) end,
      current_period_end = coalesce(p_period_end, current_period_end),
      -- La primera activacion se sella una sola vez: sirve para saber si una
      -- sede nunca llego a pagarse o si se cayo despues.
      activated_at = case
        when p_status in ('active', 'trialing') then coalesce(activated_at, now())
        else activated_at
      end,
      updated_at = now()
  where branch_id = p_branch_id
  returning * into v_despues;

  if not found then
    raise exception 'La sede no tiene suscripcion registrada.';
  end if;

  -- CD (D-303): cambiar el precio, el estado o el vencimiento de una sede
  -- toca el dinero de un cliente, y hasta hoy no quedaba escrito en ninguna
  -- parte (AGENTS.md: nada del historial financiero sin trazabilidad).
  -- Aprobar un negocio y cambiarle el plan ya escribian su evento; esta no.
  -- Solo se escribe si algo cambio: guardar lo mismo no es un cambio.
  if (v_antes.status, v_antes.price_cop, v_antes.price_reason, v_antes.current_period_end)
     is distinct from
     (v_despues.status, v_despues.price_cop, v_despues.price_reason, v_despues.current_period_end)
  then
    select ts.id into v_ts
    from public.tenant_subscriptions ts
    where ts.tenant_id = v_tenant_id;

    if v_ts is null then
      raise exception 'El negocio de esta sede no tiene suscripcion registrada.';
    end if;

    insert into public.subscription_events (
      tenant_id, tenant_subscription_id, event_type, provider, payload, created_by
    ) values (
      v_tenant_id,
      v_ts,
      'sede_cambiada_desde_el_panel',
      'platform_admin',
      jsonb_build_object(
        'branch_id', p_branch_id,
        'estado_anterior', v_antes.status,
        'estado_nuevo', v_despues.status,
        'precio_anterior', v_antes.price_cop,
        'precio_nuevo', v_despues.price_cop,
        'motivo_anterior', v_antes.price_reason,
        'motivo', v_despues.price_reason,
        'vence_anterior', v_antes.current_period_end,
        'vence_nuevo', v_despues.current_period_end
      ),
      auth.uid()
    );
  end if;
end;
$function$;

-- 2. 9.40: el historial dice de que sede es cada renglon.
drop function if exists public.platform_get_tenant_subscription_history(uuid);

CREATE OR REPLACE FUNCTION public.platform_get_tenant_subscription_history(p_tenant_id uuid)
 RETURNS TABLE(event_id uuid, created_at timestamp with time zone, event_type text, plan_code text, plan_name text, period_start timestamp with time zone, period_end timestamp with time zone, amount_cop bigint, payment_detail text, description text, branch_id uuid, branch_name text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
declare
  v_caller_role text := private.beautyos_current_platform_role();
begin
  if v_caller_role is null then
    raise exception 'No autorizado: se requiere rol de plataforma.';
  end if;

  return query
  select
    se.id as event_id,
    se.created_at,
    se.event_type,
    coalesce(se.payload->>'plan_code', p.code, 'profesional') as plan_code,
    coalesce(p.name, initcap(coalesce(se.payload->>'plan_code', 'profesional'))) as plan_name,
    case
      when se.event_type = 'tenant_approved' then se.created_at
      when se.event_type like 'epayco_%' and se.payload ? 'periodo_inicio'
        then (se.payload->>'periodo_inicio')::timestamptz
      else null
    end as period_start,
    case
      when se.event_type = 'tenant_approved' then (se.payload->>'trial_ends_at')::timestamptz
      when se.event_type like 'epayco_%' and se.payload ? 'periodo_fin'
        then (se.payload->>'periodo_fin')::timestamptz
      when se.event_type = 'trial_extended' then (se.payload->>'new_trial_ends_at')::timestamptz
      else null
    end as period_end,
    coalesce(
      (se.payload->>'monto_cop_recibido')::bigint,
      (se.payload->>'amount_cop')::bigint,
      (se.payload->>'price_cop')::bigint,
      null
    ) as amount_cop,
    case
      when se.provider = 'epayco' then
        nullif(
          trim(
            concat_ws(
              ' ',
              nullif(se.payload->>'x_franchise', ''),
              nullif(se.payload->>'x_bank_name', '')
            )
            || case
                 when se.provider_event_id is not null
                   then format(' (Ref: %s)', se.provider_event_id)
                 else ''
               end
          ),
          ''
        )
      when se.event_type = 'tenant_approved' then 'Período de prueba'
      when se.event_type = 'trial_extended' then 'Prueba ampliada'
      else null
    end as payment_detail,
    -- CD (D-303): un cambio de sede desde el Panel se lee como lo que fue:
    -- que paso de que a que. El resto de eventos, igual que antes.
    case
      when se.event_type = 'sede_cambiada_desde_el_panel' then
        coalesce(
          nullif(
            concat_ws('; ',
              case when se.payload->'precio_anterior' is distinct from se.payload->'precio_nuevo'
                then format('precio %s -> %s',
                  coalesce(se.payload->>'precio_anterior', 'de lista'),
                  coalesce(se.payload->>'precio_nuevo', 'de lista'))
              end,
              case when se.payload->'estado_anterior' is distinct from se.payload->'estado_nuevo'
                then format('estado %s -> %s',
                  se.payload->>'estado_anterior', se.payload->>'estado_nuevo')
              end,
              case when se.payload->'vence_anterior' is distinct from se.payload->'vence_nuevo'
                then format('vence %s -> %s',
                  coalesce(left(se.payload->>'vence_anterior', 10), '-'),
                  coalesce(left(se.payload->>'vence_nuevo', 10), '-'))
              end,
              case when se.payload->'motivo_anterior' is distinct from se.payload->'motivo'
                then format('motivo: %s', coalesce(se.payload->>'motivo', '(sin motivo)'))
              end
            ),
            ''
          ),
          se.event_type
        )
      else coalesce(se.payload->>'price_reason', se.payload->>'motivo', se.event_type)
    end as description,
    -- 9.40 (D-303): de que sede es cada renglon. Desde D-239 cada sede paga
    -- lo suyo, y sin esto el historial era una lista de importes sin dueno.
    sede.branch_id,
    b.name as branch_name
  from public.subscription_events se
  join public.tenant_subscriptions ts on ts.id = se.tenant_subscription_id
  left join public.plans p on p.id = ts.plan_id
  -- La sede sale del payload cuando el evento la lleva (pago de sede aceptado,
  -- precio_de_sede_al_minimo, sede_cambiada_desde_el_panel). Un pago de sede
  -- CANCELADO se guarda con el payload crudo de ePayco, sin sede: la sabe su
  -- intencion de pago, que se resuelve con la misma referencia de ePayco con
  -- la que se guardo el evento (verify-epayco-transaction y epayco-webhook).
  -- Los eventos del negocio (aprobar, plan, contacto) no tienen sede.
  left join lateral (
    select coalesce(
      case
        when (se.payload->>'branch_id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          then (se.payload->>'branch_id')::uuid
      end,
      (
        select spi.branch_id
        from public.subscription_payment_intents spi
        where se.provider = 'epayco'
          and spi.tenant_id = se.tenant_id
          and spi.x_ref_payco = se.provider_event_id
        order by spi.created_at desc
        limit 1
      )
    ) as branch_id
  ) sede on true
  left join public.branches b on b.id = sede.branch_id
  where se.tenant_id = p_tenant_id
  order by se.created_at desc;
end;
$function$;

revoke all on function public.platform_get_tenant_subscription_history(uuid) from public, anon;
grant execute on function public.platform_get_tenant_subscription_history(uuid) to authenticated;

comment on function public.platform_get_tenant_subscription_history(uuid)
  is 'Historial completo de suscripcion: fecha/hora, plan, periodo comprometido, valor/medio de pago/referencia y, desde D-303 (paso 9.40), de que sede es cada renglon. Para el Panel de Plataforma.';

commit;
