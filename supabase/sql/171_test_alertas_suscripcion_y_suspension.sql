-- ==============================================================================
-- Control 171: Verificacion de Alertas de Suscripcion y Suspension Automatica
-- ==============================================================================
-- Se ejecuta en una transaccion aislada que termina en ROLLBACK (sin dejar basura).
-- ==============================================================================

begin;

do $$
declare
  v_plan_id uuid;
  v_tenant_id uuid;
  v_sub_id uuid;
  v_alert record;
  v_suspended_count integer;
  v_found boolean := false;
begin
  raise notice 'Iniciando Control 171...';

  -- 1. Obtener plan profesional
  select id into v_plan_id from public.plans where code = 'profesional' limit 1;
  if v_plan_id is null then
    raise exception 'No se encontro el plan profesional.';
  end if;

  -- 2. Crear tenant de prueba con contacto de correo
  insert into public.tenants (name, slug, contact_email, is_demo)
  values ('Salon Alertas Test', 'salon-alertas-' || floor(random()*100000)::text, 'owner@salonalertas.com', false)
  returning id into v_tenant_id;

  -- 3. Crear suscripcion en 'trialing' con vencimiento en 5 dias
  insert into public.tenant_subscriptions (
    tenant_id,
    plan_id,
    status,
    trial_ends_at
  ) values (
    v_tenant_id,
    v_plan_id,
    'trialing',
    now() + interval '5 days'
  ) returning id into v_sub_id;

  -- ============================================================================
  -- PRUEBA 1: Deteccion de alerta de prueba gratis a 5 dias
  -- ============================================================================
  for v_alert in select * from private.beautyos_obtener_alertas_suscripcion_pendientes() where tenant_id = v_tenant_id loop
    v_found := true;
    if v_alert.notification_type != 'trial_5d' then
      raise exception 'Fallo Prueba 1: se esperaba tipo trial_5d, se obtuvo: %', v_alert.notification_type;
    end if;
  end loop;

  if not v_found then
    raise exception 'Fallo Prueba 1: no se detecto la alerta pendiente para el salon en prueba a 5 dias.';
  end if;

  raise notice '✅ Prueba 1 superada: alerta trial_5d detectada con exito.';

  -- ============================================================================
  -- PRUEBA 2: Idempotencia y anti-spam (marcar como enviada)
  -- ============================================================================
  perform private.beautyos_registrar_alerta_enviada(
    v_tenant_id,
    v_sub_id,
    'trial_5d',
    'owner@salonalertas.com',
    '{"test": true}'::jsonb
  );

  v_found := false;
  for v_alert in select * from private.beautyos_obtener_alertas_suscripcion_pendientes() where tenant_id = v_tenant_id loop
    v_found := true;
  end loop;

  if v_found then
    raise exception 'Fallo Prueba 2: la alerta no debio volver a aparecer hoy tras ser registrada como enviada.';
  end if;

  raise notice '✅ Prueba 2 superada: filtro anti-spam evita envios repetidos en el mismo dia.';

  -- ============================================================================
  -- PRUEBA 3: Deteccion de alerta diaria en periodo de gracia (Dia 3 / 3 dias restantes)
  -- ============================================================================
  update public.tenant_subscriptions
  set
    status = 'past_due',
    grace_ends_at = now() + interval '3 days'
  where id = v_sub_id;

  v_found := false;
  for v_alert in select * from private.beautyos_obtener_alertas_suscripcion_pendientes() where tenant_id = v_tenant_id loop
    v_found := true;
    if v_alert.notification_type != 'grace_day_3' then
      raise exception 'Fallo Prueba 3: se esperaba grace_day_3, se obtuvo: %', v_alert.notification_type;
    end if;
  end loop;

  if not v_found then
    raise exception 'Fallo Prueba 3: no se detecto la alerta del periodo de gracia.';
  end if;

  raise notice '✅ Prueba 3 superada: alerta grace_day_3 generada correctamente.';

  -- ============================================================================
  -- PRUEBA 4: Suspension automatica cuando expira la gracia (grace_ends_at < now())
  -- ============================================================================
  update public.tenant_subscriptions
  set
    status = 'past_due',
    grace_ends_at = now() - interval '1 hour'
  where id = v_sub_id;

  select tenants_suspendidos into v_suspended_count
  from private.beautyos_suspender_suscripciones_vencidas();

  if v_suspended_count < 1 then
    raise exception 'Fallo Prueba 4: el salon con gracia vencida debio ser suspendido.';
  end if;

  -- Comprobar estado en tabla
  select status into v_alert.subscription_status
  from public.tenant_subscriptions
  where id = v_sub_id;

  if v_alert.subscription_status != 'suspended' then
    raise exception 'Fallo Prueba 4: el estado de la suscripcion debio ser suspended, pero es: %', v_alert.subscription_status;
  end if;

  -- Comprobar auditoria en subscription_events
  if not exists (
    select 1 from public.subscription_events
    where tenant_id = v_tenant_id
      and event_type = 'auto_suspended_grace_expired'
  ) then
    raise exception 'Fallo Prueba 4: no se registro el evento auto_suspended_grace_expired en subscription_events.';
  end if;

  raise notice '✅ Prueba 4 superada: suspension automatica ejecutada y auditada en subscription_events.';

  raise notice '==================================================';
  raise notice 'TODAS LAS PRUEBAS DEL CONTROL 171 EN VERDE!';
  raise notice '==================================================';
end;
$$;

rollback;
