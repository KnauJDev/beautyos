-- CONTROL 191: Fase 7, pasos 7.1/7.2/7.4 -- cabecera ejecutiva del SaaS,
-- visión 360° financiera por salón y gestión de excepciones de límites
-- (D-172).
--
-- POR QUÉ ESTE ARCHIVO
--
-- platform_get_saas_metrics() agrega sobre TODA la tabla de tenants, que en
-- este momento ya tiene negocios reales. No se puede afirmar un total
-- exacto sin conocer ese dato de antemano, así que este control mide el
-- ANTES y el DESPUÉS de insertar sus propios negocios de prueba y compara
-- la diferencia (delta) contra lo que esos negocios de prueba deberían
-- aportar -- eso sí es exacto, sin importar cuántos negocios reales existan.
--
-- CÓMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\191_test_panel_plataforma_fase7.sql"
--
-- TERMINA EN ROLLBACK. No deja ni una fila.

begin;

do $$
declare
  v_owner_user uuid := '00000000-0000-0000-0000-000000000191';
  v_operator_user uuid := '00000000-0000-0000-0000-000000000192';
  v_outsider_user uuid := '00000000-0000-0000-0000-000000000193';

  v_plan_profesional uuid;
  v_plan_basico uuid;

  v_tenant_a uuid; -- activo, 3 pagos validos + 1 evento sin monto, con trial ya vencido (convertido)
  v_tenant_b uuid; -- past_due, precio pactado propio
  v_tenant_c uuid; -- suspendido MANUAL (no es mora)
  v_tenant_d uuid; -- suspendido AUTOMATICO por gracia vencida (si es mora)
  v_tenant_e uuid; -- demo, activo con pago -- no debe sumar a MRR ni recaudo
  v_tenant_f uuid; -- trialing, nunca pago (para el conteo de "en prueba")

  v_sub_a uuid; v_sub_b uuid; v_sub_c uuid; v_sub_d uuid; v_sub_e uuid; v_sub_f uuid;

  v_metrics_before jsonb;
  v_metrics_after jsonb;
  v_row record;
  v_override_id uuid;
  v_capturo boolean;
  v_error_msg text;
  v_fallos integer := 0;
  v_error text;
begin
  select id into v_plan_profesional from public.plans where code = 'profesional';
  select id into v_plan_basico from public.plans where code = 'basico';

  -- =====================================================================
  -- Fixtures: usuarios de auth y operadores de plataforma.
  -- =====================================================================
  insert into auth.users (id, email)
  values
    (v_owner_user, 'owner_test191@salonymas.com'),
    (v_operator_user, 'operator_test191@salonymas.com'),
    (v_outsider_user, 'outsider_test191@salonymas.com')
  on conflict (id) do nothing;

  insert into public.platform_operators (user_id, role, active)
  values
    (v_owner_user, 'platform_owner', true),
    (v_operator_user, 'platform_operator', true)
  on conflict (user_id) do update set role = excluded.role, active = true;

  -- "Antes": foto de las métricas justo antes de insertar los fixtures, en
  -- la misma transacción, para poder medir el delta exacto que ellos
  -- aportan sin importar cuántos negocios reales existan ya.
  perform set_config('request.jwt.claims', json_build_object('sub', v_owner_user::text, 'role', 'authenticated')::text, true);
  select public.platform_get_saas_metrics() into v_metrics_before;

  -- =====================================================================
  -- Fixtures: seis negocios de prueba cubriendo cada rama del calculo.
  -- =====================================================================
  insert into public.tenants (name, business_type, contact_email, whatsapp, is_demo, active)
  values ('Salón Prueba A D172', 'peluqueria', 'a191@test.com', '3000000191', false, true)
  returning id into v_tenant_a;

  insert into public.tenants (name, business_type, contact_email, whatsapp, is_demo, active)
  values ('Salón Prueba B D172', 'peluqueria', 'b191@test.com', '3000000192', false, true)
  returning id into v_tenant_b;

  insert into public.tenants (name, business_type, contact_email, whatsapp, is_demo, active)
  values ('Salón Prueba C D172', 'peluqueria', 'c191@test.com', '3000000193', false, true)
  returning id into v_tenant_c;

  insert into public.tenants (name, business_type, contact_email, whatsapp, is_demo, active)
  values ('Salón Prueba D D172', 'peluqueria', 'd191@test.com', '3000000194', false, true)
  returning id into v_tenant_d;

  insert into public.tenants (name, business_type, contact_email, whatsapp, is_demo, active)
  values ('Salón Prueba E Demo D172', 'peluqueria', 'e191@test.com', '3000000195', true, true)
  returning id into v_tenant_e;

  insert into public.tenants (name, business_type, contact_email, whatsapp, is_demo, active)
  values ('Salón Prueba F D172', 'peluqueria', 'f191@test.com', '3000000196', false, true)
  returning id into v_tenant_f;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, trial_ends_at, current_period_start, current_period_end)
  values (v_tenant_a, v_plan_profesional, 'active', now() - interval '40 days', now() - interval '10 days', now() + interval '20 days')
  returning id into v_sub_a;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, price_cop, price_reason, trial_ends_at, current_period_end, grace_ends_at)
  values (v_tenant_b, v_plan_basico, 'past_due', 150000, 'Precio pactado de prueba (control 191)', now() - interval '60 days', now() - interval '3 days', now() + interval '2 days')
  returning id into v_sub_b;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, trial_ends_at)
  values (v_tenant_c, v_plan_basico, 'suspended', now() - interval '60 days')
  returning id into v_sub_c;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, trial_ends_at)
  values (v_tenant_d, v_plan_basico, 'suspended', now() - interval '60 days')
  returning id into v_sub_d;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_tenant_e, v_plan_profesional, 'active', now() + interval '20 days')
  returning id into v_sub_e;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, trial_ends_at)
  values (v_tenant_f, v_plan_basico, 'trialing', now() + interval '10 days')
  returning id into v_sub_f;

  -- Evento de suspensión manual (tenant C, NO es mora) y automática por
  -- gracia vencida (tenant D, SÍ es mora) -- mismos event_type que usa la
  -- máquina de estados real (20260823150000).
  insert into public.subscription_events (tenant_id, tenant_subscription_id, event_type, payload)
  values (v_tenant_c, v_sub_c, 'suspended_by_platform', '{}'::jsonb);

  insert into public.subscription_events (tenant_id, tenant_subscription_id, event_type, payload)
  values (v_tenant_d, v_sub_d, 'auto_suspended_grace_expired', '{}'::jsonb);

  -- Tenant A: 3 pagos de ePayco que sí activaron/renovaron (con
  -- monto_cop_recibido, igual que escribe beautyos_procesar_evento_epayco)
  -- y 1 evento de ePayco SIN ese campo (pago rechazado o insuficiente, no
  -- debe contar como período pagado).
  insert into public.subscription_events (tenant_id, tenant_subscription_id, event_type, provider, provider_event_id, payload)
  values
    (v_tenant_a, v_sub_a, 'epayco_aceptada', 'epayco', 'ref-191-1', jsonb_build_object('monto_cop_recibido', 240000)),
    (v_tenant_a, v_sub_a, 'epayco_aceptada', 'epayco', 'ref-191-2', jsonb_build_object('monto_cop_recibido', 240000)),
    (v_tenant_a, v_sub_a, 'epayco_aceptada', 'epayco', 'ref-191-3', jsonb_build_object('monto_cop_recibido', 240000)),
    (v_tenant_a, v_sub_a, 'epayco_rechazada', 'epayco', 'ref-191-4', '{}'::jsonb);

  -- Tenant E (demo): un pago con monto_cop_recibido que NO debe sumar a
  -- MRR ni a recaudo histórico -- es la prueba del filtro is_demo.
  insert into public.subscription_events (tenant_id, tenant_subscription_id, event_type, provider, provider_event_id, payload)
  values (v_tenant_e, v_sub_e, 'epayco_aceptada', 'epayco', 'ref-191-5', jsonb_build_object('monto_cop_recibido', 240000));

  -- =====================================================================
  -- CASO 1-5: platform_get_saas_metrics() -- delta exacto antes/después de
  -- insertar los fixtures. El delta de recaudo (720.000, no 960.000) es la
  -- prueba real de que el pago del tenant E (demo) NO se cuenta.
  -- =====================================================================
  select public.platform_get_saas_metrics() into v_metrics_after;

  if (v_metrics_after->>'mrr_cop')::bigint - (v_metrics_before->>'mrr_cop')::bigint = 240000 then
    raise notice 'OK  1  el MRR sube exactamente 240.000 (solo el tenant A activo; E queda fuera por ser demo)';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 1  delta mrr_cop=%, se esperaba 240000',
      (v_metrics_after->>'mrr_cop')::bigint - (v_metrics_before->>'mrr_cop')::bigint;
  end if;

  if (v_metrics_after->>'total_collected_cop')::bigint - (v_metrics_before->>'total_collected_cop')::bigint = 720000 then
    raise notice 'OK  2  el recaudo histórico sube exactamente 720.000 (3 pagos de A; el pago del tenant E demo NO se cuenta)';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 2  delta total_collected_cop=%, se esperaba 720000',
      (v_metrics_after->>'total_collected_cop')::bigint - (v_metrics_before->>'total_collected_cop')::bigint;
  end if;

  if (v_metrics_after->>'active_count')::integer - (v_metrics_before->>'active_count')::integer = 1
     and (v_metrics_after->>'trialing_count')::integer - (v_metrics_before->>'trialing_count')::integer = 1
     and (v_metrics_after->>'past_due_count')::integer - (v_metrics_before->>'past_due_count')::integer = 1
  then
    raise notice 'OK  3  activos +1 (A), en prueba +1 (F), en gracia/mora +1 (B) -- ni C/D/E los alteran';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 3  delta active=%, trialing=%, past_due=%',
      (v_metrics_after->>'active_count')::integer - (v_metrics_before->>'active_count')::integer,
      (v_metrics_after->>'trialing_count')::integer - (v_metrics_before->>'trialing_count')::integer,
      (v_metrics_after->>'past_due_count')::integer - (v_metrics_before->>'past_due_count')::integer;
  end if;

  if (v_metrics_after->>'conversion_rate_percent')::numeric between 0 and 100 then
    raise notice 'OK  4  la tasa de conversión es un porcentaje válido (0-100)';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 4  conversion_rate_percent=%', v_metrics_after->>'conversion_rate_percent';
  end if;

  select * into v_row from public.platform_list_tenants() where tenant_id = v_tenant_e;
  if v_row.total_paid_cop = 240000 then
    raise notice 'OK  5  la fila propia del tenant demo sí ve su pago (el filtro es solo en los agregados del SaaS, no en su ficha)';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 5  no se pudo verificar el fixture del tenant demo';
  end if;

  -- =====================================================================
  -- CASO 6: platform_list_tenants() -- fila exacta del tenant A.
  -- =====================================================================
  select * into v_row from public.platform_list_tenants() where tenant_id = v_tenant_a;

  if v_row.paid_periods_count = 3
     and v_row.total_paid_cop = 720000
     and v_row.effective_monthly_price = 240000
     and v_row.debt_status = 'al_dia'
     and v_row.debt_amount_cop = 0
  then
    raise notice 'OK  6  tenant A (activo, 3 pagos válidos, plan lista): períodos, LTV, precio y estado de cartera exactos';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 6  periodos=%, total=%, precio=%, debt_status=%, debt_amount=%',
      v_row.paid_periods_count, v_row.total_paid_cop, v_row.effective_monthly_price, v_row.debt_status, v_row.debt_amount_cop;
  end if;

  -- =====================================================================
  -- CASO 7: tenant B (past_due, precio pactado 150.000) -- en mora.
  -- =====================================================================
  select * into v_row from public.platform_list_tenants() where tenant_id = v_tenant_b;

  if v_row.debt_status = 'en_mora' and v_row.debt_amount_cop = 150000 and v_row.effective_monthly_price = 150000 then
    raise notice 'OK  7  tenant B (past_due) queda en_mora con el monto pactado (150.000)';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 7  debt_status=%, debt_amount=%, precio=%', v_row.debt_status, v_row.debt_amount_cop, v_row.effective_monthly_price;
  end if;

  -- =====================================================================
  -- CASO 8: tenant C (suspendido MANUALMENTE) -- NO es mora.
  -- =====================================================================
  select * into v_row from public.platform_list_tenants() where tenant_id = v_tenant_c;

  if v_row.debt_status = 'al_dia' and v_row.debt_amount_cop = 0 then
    raise notice 'OK  8  tenant C (suspendido a mano por la plataforma) NO se marca en mora';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 8  debt_status=%, debt_amount=%', v_row.debt_status, v_row.debt_amount_cop;
  end if;

  -- =====================================================================
  -- CASO 9: tenant D (suspendido por gracia vencida) -- SÍ es mora.
  -- =====================================================================
  select * into v_row from public.platform_list_tenants() where tenant_id = v_tenant_d;

  if v_row.debt_status = 'en_mora' and v_row.debt_amount_cop > 0 then
    raise notice 'OK  9  tenant D (suspendido por gracia vencida) SÍ se marca en mora';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 9  debt_status=%, debt_amount=%', v_row.debt_status, v_row.debt_amount_cop;
  end if;

  -- =====================================================================
  -- CASO 10: tenant F (trialing, sin pagos) -- en_prueba, sin mora.
  -- =====================================================================
  select * into v_row from public.platform_list_tenants() where tenant_id = v_tenant_f;

  if v_row.debt_status = 'en_prueba' and v_row.paid_periods_count = 0 and v_row.debt_amount_cop = 0 then
    raise notice 'OK 10  tenant F (en prueba) queda en_prueba, sin períodos pagados ni deuda';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 10  debt_status=%, periodos=%, debt_amount=%', v_row.debt_status, v_row.paid_periods_count, v_row.debt_amount_cop;
  end if;

  -- =====================================================================
  -- CASO 11-14: conceder, listar y revocar una excepción (paso 7.2).
  -- =====================================================================
  select override_id into v_override_id
  from public.platform_set_tenant_feature_override(
    v_tenant_a, 'branches', true, 3, 'Prueba control 191 D-172', null
  );

  if v_override_id is not null then
    raise notice 'OK 11  platform_owner concede una excepción de sedes (3) al tenant A';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 11  no se devolvió override_id';
  end if;

  if exists (
    select 1 from public.platform_get_tenant_feature_overrides(v_tenant_a)
    where override_id = v_override_id and feature_key = 'branches' and limit_value = 3 and is_active
  ) then
    raise notice 'OK 12  la excepción aparece activa al listarla';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 12  la excepción no apareció activa en el listado';
  end if;

  select * into v_row from public.platform_list_tenants() where tenant_id = v_tenant_a;
  if v_row.active_overrides_count = 1 then
    raise notice 'OK 13  platform_list_tenants ve 1 excepción activa en el tenant A';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 13  active_overrides_count=%, se esperaba 1', v_row.active_overrides_count;
  end if;

  perform public.platform_delete_tenant_feature_override(v_override_id);

  select * into v_row from public.platform_list_tenants() where tenant_id = v_tenant_a;
  if v_row.active_overrides_count = 0
     and exists (
       select 1 from public.platform_get_tenant_feature_overrides(v_tenant_a)
       where override_id = v_override_id and not is_active
     )
  then
    raise notice 'OK 14  al revocarla, deja de contar como activa pero sigue en el historial';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 14  active_overrides_count=%', v_row.active_overrides_count;
  end if;

  -- =====================================================================
  -- CASO 15: motivo vacío se rechaza.
  -- =====================================================================
  v_capturo := false;
  begin
    perform public.platform_set_tenant_feature_override(v_tenant_a, 'branches', true, 2, '   ', null);
  exception
    when others then
      v_capturo := true;
  end;

  if v_capturo then
    raise notice 'OK 15  una excepción sin motivo se rechaza';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 15  se aceptó una excepción sin motivo';
  end if;

  -- =====================================================================
  -- CASO 16: un platform_operator (no owner) puede LEER pero no CONCEDER.
  -- =====================================================================
  perform set_config('request.jwt.claims', json_build_object('sub', v_operator_user::text, 'role', 'authenticated')::text, true);

  begin
    perform public.platform_get_saas_metrics();
    perform public.platform_get_tenant_feature_overrides(v_tenant_a);
    v_capturo := false;
  exception
    when others then
      v_capturo := true;
  end;

  if not v_capturo then
    raise notice 'OK 16a  platform_operator puede leer métricas y excepciones';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 16a  platform_operator no pudo leer';
  end if;

  v_capturo := false;
  begin
    perform public.platform_set_tenant_feature_override(v_tenant_a, 'branches', true, 5, 'Intento no autorizado', null);
  exception
    when others then
      v_capturo := true;
      v_error_msg := sqlerrm;
  end;

  if v_capturo and v_error_msg like '%platform_owner%' then
    raise notice 'OK 16b  platform_operator NO puede conceder excepciones (solo platform_owner)';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 16b  capturo=%, mensaje="%"', v_capturo, v_error_msg;
  end if;

  -- =====================================================================
  -- CASO 17: un usuario sin ningún rol de plataforma es rechazado en todo.
  -- =====================================================================
  perform set_config('request.jwt.claims', json_build_object('sub', v_outsider_user::text, 'role', 'authenticated')::text, true);

  v_capturo := false;
  begin
    perform public.platform_get_saas_metrics();
  exception
    when others then
      v_capturo := true;
  end;

  if v_capturo then
    raise notice 'OK 17a  sin rol de plataforma, platform_get_saas_metrics se rechaza';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 17a  un usuario sin rol pudo leer las métricas del SaaS';
  end if;

  v_capturo := false;
  begin
    perform public.platform_list_tenants();
  exception
    when others then
      v_capturo := true;
  end;

  if v_capturo then
    raise notice 'OK 17b  sin rol de plataforma, platform_list_tenants se rechaza';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 17b  un usuario sin rol pudo listar los negocios';
  end if;

  v_capturo := false;
  begin
    perform public.platform_get_tenant_feature_overrides(v_tenant_a);
  exception
    when others then
      v_capturo := true;
  end;

  if v_capturo then
    raise notice 'OK 17c  sin rol de plataforma, platform_get_tenant_feature_overrides se rechaza';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 17c  un usuario sin rol pudo ver las excepciones de un negocio ajeno';
  end if;

  v_capturo := false;
  begin
    perform public.platform_set_tenant_feature_override(v_tenant_a, 'branches', true, 9, 'Intento externo', null);
  exception
    when others then
      v_capturo := true;
  end;

  if v_capturo then
    raise notice 'OK 17d  sin rol de plataforma, platform_set_tenant_feature_override se rechaza';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 17d  un usuario sin rol pudo conceder una excepción';
  end if;

  -- =====================================================================
  raise notice ' ';
  if v_fallos = 0 then
    raise notice '=== TODAS LAS PRUEBAS DEL PANEL DE PLATAFORMA FASE 7 PASARON ===';
  else
    raise notice '=== % FALLO(S). Revisar arriba. ===', v_fallos;
  end if;

exception
  when others then
    v_error := sqlerrm;
    raise notice ' ';
    raise notice '=== LA PRUEBA SE DETUVO: % ===', v_error;
    raise notice 'Si es la primera vez que se corre, puede ser el guion y no';
    raise notice 'la aplicacion. Pasale este mensaje al asistente.';
end;
$$;

rollback;
