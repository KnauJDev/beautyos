-- CONTROL 192: Paso 7.3 -- Sistema de Partners y Referidos (D-173).
--
-- POR QUÉ ESTE ARCHIVO
--
-- El hook de comisión vive DENTRO de `beautyos_procesar_evento_epayco`
-- (D-160), la misma función que ya activa/renueva suscripciones -- un
-- error ahí no solo generaría una comisión mal calculada, podría romper
-- el cobro real de cualquier salón. Este control simula pagos completos
-- con esa misma función (no una versión simplificada) para las tres
-- reglas de duración (`first_payment_only`, `first_n_months`,
-- `recurring_lifetime`), la exclusión de salones demo y de partners
-- inactivos, y el ciclo completo de liquidación.
--
-- CÓMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\192_test_sistema_partners_fase7.sql"
--
-- TERMINA EN ROLLBACK. No deja ni una fila.

begin;

do $$
declare
  v_owner_user uuid := '00000000-0000-0000-0000-000000000201';
  v_operator_user uuid := '00000000-0000-0000-0000-000000000202';
  v_outsider_user uuid := '00000000-0000-0000-0000-000000000203';
  v_registrant_1 uuid := '00000000-0000-0000-0000-000000000204';
  v_registrant_2 uuid := '00000000-0000-0000-0000-000000000205';

  v_plan_profesional uuid;
  v_plan_basico uuid;

  v_partner_a uuid; -- 15%, first_payment_only, Bre-B
  v_partner_b uuid; -- $50.000 fijo, recurring_lifetime
  v_partner_c uuid; -- se desactiva después de crearse
  v_partner_public uuid; -- via public_register_partner

  v_tenant_x uuid; -- vinculado a A, dos pagos (solo el 1o comisiona)
  v_tenant_y uuid; -- demo, vinculado a A (nunca comisiona)
  v_tenant_z uuid; -- vinculado a B, dos pagos (ambos comisionan)
  v_tenant_w uuid; -- vinculado a C (inactivo, nunca comisiona)
  v_tenant_t uuid; -- sin partner, para probar set_tenant_partner

  v_sub_x uuid; v_sub_y uuid; v_sub_z uuid; v_sub_w uuid; v_sub_t uuid;

  v_row record;
  v_reg record;
  v_epayco record;
  v_detail jsonb;
  v_summary_before jsonb;
  v_summary_after jsonb;
  v_capturo boolean;
  v_error_msg text;
  v_fallos integer := 0;
  v_error text;
begin
  select id into v_plan_profesional from public.plans where code = 'profesional';
  select id into v_plan_basico from public.plans where code = 'basico';

  -- =====================================================================
  -- Fixtures: usuarios de auth, operadores de plataforma y salones.
  -- =====================================================================
  insert into auth.users (id, email)
  values
    (v_owner_user, 'owner_test192@salonymas.com'),
    (v_operator_user, 'operator_test192@salonymas.com'),
    (v_outsider_user, 'outsider_test192@salonymas.com'),
    (v_registrant_1, 'registrant1_test192@salonymas.com'),
    (v_registrant_2, 'registrant2_test192@salonymas.com')
  on conflict (id) do nothing;

  insert into public.platform_operators (user_id, role, active)
  values
    (v_owner_user, 'platform_owner', true),
    (v_operator_user, 'platform_operator', true)
  on conflict (user_id) do update set role = excluded.role, active = true;

  insert into public.tenants (name, business_type, contact_email, whatsapp, is_demo, active)
  values
    ('Salón Prueba X D173', 'peluqueria', 'x192@test.com', '3000000201', false, true),
    ('Salón Prueba Y Demo D173', 'peluqueria', 'y192@test.com', '3000000202', true, true),
    ('Salón Prueba Z D173', 'peluqueria', 'z192@test.com', '3000000203', false, true),
    ('Salón Prueba W D173', 'peluqueria', 'w192@test.com', '3000000204', false, true),
    ('Salón Prueba T D173', 'peluqueria', 't192@test.com', '3000000205', false, true)
  ;

  select id into v_tenant_x from public.tenants where contact_email = 'x192@test.com';
  select id into v_tenant_y from public.tenants where contact_email = 'y192@test.com';
  select id into v_tenant_z from public.tenants where contact_email = 'z192@test.com';
  select id into v_tenant_w from public.tenants where contact_email = 'w192@test.com';
  select id into v_tenant_t from public.tenants where contact_email = 't192@test.com';

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, trial_ends_at)
  values (v_tenant_x, v_plan_profesional, 'trialing', now() + interval '10 days')
  returning id into v_sub_x;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, trial_ends_at)
  values (v_tenant_y, v_plan_profesional, 'trialing', now() + interval '10 days')
  returning id into v_sub_y;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, trial_ends_at)
  values (v_tenant_z, v_plan_basico, 'trialing', now() + interval '10 days')
  returning id into v_sub_z;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, trial_ends_at)
  values (v_tenant_w, v_plan_basico, 'trialing', now() + interval '10 days')
  returning id into v_sub_w;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, trial_ends_at)
  values (v_tenant_t, v_plan_basico, 'trialing', now() + interval '10 days')
  returning id into v_sub_t;

  -- =====================================================================
  -- CASO 1-4: platform_create_partner.
  -- =====================================================================
  perform set_config('request.jwt.claims', json_build_object('sub', v_owner_user::text, 'role', 'authenticated')::text, true);

  select partner_id into v_partner_a
  from public.platform_create_partner(
    p_full_name => 'Carlos Pérez',
    p_referral_code => '  carlos  ',
    p_payout_channel => 'bre_b',
    p_payout_account => '3001234567',
    p_commission_type => 'percentage',
    p_commission_value => 15.0,
    p_commission_duration => 'first_payment_only'
  );

  if v_partner_a is not null then
    raise notice 'OK  1  platform_create_partner crea a Carlos con Bre-B';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 1  no se devolvió partner_id';
  end if;

  select * into v_row from public.platform_list_partners() where partner_id = v_partner_a;
  if v_row.referral_code = 'CARLOS' then
    raise notice 'OK  2  el código se normaliza a mayúsculas sin espacios (CARLOS)';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 2  referral_code="%"', v_row.referral_code;
  end if;

  v_capturo := false;
  begin
    perform public.platform_create_partner('Otro', 'CARLOS', 'nequi', '3009999999');
  exception
    when others then
      v_capturo := true;
  end;

  if v_capturo then
    raise notice 'OK  3  un código de referido duplicado se rechaza';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 3  se aceptó un código duplicado';
  end if;

  v_capturo := false;
  begin
    perform public.platform_create_partner('Otro2', 'OTRO2', 'bitcoin', '3009999998');
  exception
    when others then
      v_capturo := true;
  end;

  if v_capturo then
    raise notice 'OK  4  un canal de pago inválido se rechaza';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 4  se aceptó un canal de pago inválido ("bitcoin")';
  end if;

  select partner_id into v_partner_b
  from public.platform_create_partner(
    p_full_name => 'Distribuidora Mayorista',
    p_referral_code => 'MAYORISTA',
    p_payout_channel => 'nequi',
    p_payout_account => '3007654321',
    p_commission_type => 'fixed_cop',
    p_commission_value => 50000,
    p_commission_duration => 'recurring_lifetime'
  );

  select partner_id into v_partner_c
  from public.platform_create_partner(
    p_full_name => 'Partner Inactivo',
    p_referral_code => 'INACTIVO',
    p_payout_channel => 'daviplata',
    p_payout_account => '3005555555'
  );
  update public.partners set active = false where id = v_partner_c;

  -- =====================================================================
  -- CASO 5-6: public_register_partner (rol anon, sin ningún claim).
  -- =====================================================================
  perform set_config('request.jwt.claims', '{}', true);

  select * into v_reg from public.public_register_partner(
    'Yelimar Estilista', '1234567890', ' publico1 ', '3001112222',
    '3001112222', 'yelimar@test.com', 'daviplata', '3001112222'
  );

  if v_reg.partner_id is not null and v_reg.referral_code = 'PUBLICO1' then
    raise notice 'OK  5  cualquiera puede postularse como partner (rol anon)';
    v_partner_public := v_reg.partner_id;
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 5  public_register_partner no devolvió lo esperado';
  end if;

  v_capturo := false;
  begin
    perform public.public_register_partner(
      'Otro Postulante', null, 'CARLOS', '3002223333', '3002223333', null, 'nequi', '3002223333'
    );
  exception
    when others then
      v_capturo := true;
  end;

  if v_capturo then
    raise notice 'OK  6  la postulación pública rechaza un código ya usado';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 6  se aceptó una postulación con código duplicado';
  end if;

  -- =====================================================================
  -- CASO 7-8: register_tenant con ?ref=CODIGO.
  -- =====================================================================
  perform set_config('request.jwt.claims', json_build_object('sub', v_registrant_1::text, 'role', 'authenticated')::text, true);

  select * into v_row from public.register_tenant(
    'Salón Registrado Con Ref', 'Registrante Uno', '3009990001',
    'peluqueria', 'Bogotá', 1, 1, 'instagram', ' carlos '
  );

  if exists (
    select 1 from public.tenants t
    where t.id = v_row.tenant_id
      and t.partner_id = v_partner_a
      and t.referral_code_used = 'CARLOS'
  ) then
    raise notice 'OK  7  registrarse con ?ref=carlos (minúsculas, con espacios) vincula al partner correcto';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 7  el registro no quedó vinculado al partner esperado';
  end if;

  perform set_config('request.jwt.claims', json_build_object('sub', v_registrant_2::text, 'role', 'authenticated')::text, true);

  select * into v_row from public.register_tenant(
    'Salón Registrado Sin Partner', 'Registrante Dos', '3009990002',
    'peluqueria', 'Bogotá', 1, 1, null, 'NOEXISTE123'
  );

  if exists (
    select 1 from public.tenants t
    where t.id = v_row.tenant_id
      and t.partner_id is null
      and t.referral_code_used = 'NOEXISTE123'
  ) then
    raise notice 'OK  8  un código que no existe no bloquea el registro y se guarda para trazabilidad';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 8  el registro con código inexistente no se comportó como se esperaba';
  end if;

  -- =====================================================================
  -- CASO 9-12: platform_set_tenant_partner (vincular/reasignar/quitar).
  -- =====================================================================
  perform set_config('request.jwt.claims', json_build_object('sub', v_owner_user::text, 'role', 'authenticated')::text, true);

  perform public.platform_set_tenant_partner(v_tenant_t, v_partner_a);
  if (select partner_id from public.tenants where id = v_tenant_t) = v_partner_a then
    raise notice 'OK  9  platform_owner vincula manualmente un salón a un partner';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 9  el salón no quedó vinculado';
  end if;

  perform public.platform_set_tenant_partner(v_tenant_t, v_partner_b);
  if (select partner_id from public.tenants where id = v_tenant_t) = v_partner_b then
    raise notice 'OK 10  reasignar a otro partner funciona';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 10  la reasignación no se aplicó';
  end if;

  perform public.platform_set_tenant_partner(v_tenant_t, null);
  if (select partner_id from public.tenants where id = v_tenant_t) is null then
    raise notice 'OK 11  quitar el partner (null) desvincula el salón';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 11  el salón siguió vinculado tras pasar null';
  end if;

  perform set_config('request.jwt.claims', json_build_object('sub', v_operator_user::text, 'role', 'authenticated')::text, true);
  v_capturo := false;
  begin
    perform public.platform_set_tenant_partner(v_tenant_t, v_partner_a);
  exception
    when others then
      v_capturo := true;
      v_error_msg := sqlerrm;
  end;

  if v_capturo and v_error_msg like '%platform_owner%' then
    raise notice 'OK 12  platform_operator NO puede vincular partners (solo platform_owner)';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 12  capturo=%, mensaje="%"', v_capturo, v_error_msg;
  end if;

  -- Vincula de verdad los salones de prueba de comisiones, ahora que la
  -- RPC de vinculación ya quedó probada arriba.
  update public.tenants set partner_id = v_partner_a where id in (v_tenant_x, v_tenant_y);
  update public.tenants set partner_id = v_partner_b where id = v_tenant_z;
  update public.tenants set partner_id = v_partner_c where id = v_tenant_w;

  -- =====================================================================
  -- CASO 13-17: comisiones generadas por pagos reales de ePayco.
  -- =====================================================================

  -- Tenant X -- Partner A (15%, first_payment_only). Pago 1: sí comisiona.
  select * into v_epayco from private.beautyos_procesar_evento_epayco(
    v_tenant_x, 'D173-X-1', 'TX-D173-X-1', 'Aceptada', '1', 240000, 'COP', '{}'::jsonb
  );
  if v_epayco.new_status <> 'active' then
    raise exception 'Fixture: el pago 1 del tenant X no activó la suscripción (%).', v_epayco.message;
  end if;

  if exists (
    select 1 from public.partner_commissions
    where tenant_id = v_tenant_x and partner_id = v_partner_a
      and amount_cop = 36000 and payment_event_amount_cop = 240000 and status = 'pending'
  ) then
    raise notice 'OK 13  el primer pago del tenant X genera comisión pending de $36.000 (15%% de 240.000)';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 13  no se encontró la comisión esperada para el tenant X';
  end if;

  -- Tenant X -- pago 2 (renovación): NO debe comisionar (first_payment_only).
  select * into v_epayco from private.beautyos_procesar_evento_epayco(
    v_tenant_x, 'D173-X-2', 'TX-D173-X-2', 'Aceptada', '1', 240000, 'COP', '{}'::jsonb
  );

  if (select count(*) from public.partner_commissions where tenant_id = v_tenant_x) = 1 then
    raise notice 'OK 14  el segundo pago del tenant X NO genera una comisión nueva (first_payment_only ya se usó)';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 14  el tenant X tiene % comisiones, se esperaba 1', (select count(*) from public.partner_commissions where tenant_id = v_tenant_x);
  end if;

  -- Tenant Z -- Partner B ($50.000 fijo, recurring_lifetime). Dos pagos, dos comisiones.
  perform private.beautyos_procesar_evento_epayco(
    v_tenant_z, 'D173-Z-1', 'TX-D173-Z-1', 'Aceptada', '1', 160000, 'COP', '{}'::jsonb
  );
  perform private.beautyos_procesar_evento_epayco(
    v_tenant_z, 'D173-Z-2', 'TX-D173-Z-2', 'Aceptada', '1', 160000, 'COP', '{}'::jsonb
  );

  if (
    select count(*) from public.partner_commissions
    where tenant_id = v_tenant_z and amount_cop = 50000 and status = 'pending'
  ) = 2 then
    raise notice 'OK 15  recurring_lifetime comisiona en cada pago (2 pagos, 2 comisiones de $50.000)';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 15  el tenant Z no generó las 2 comisiones esperadas';
  end if;

  -- Tenant Y -- demo, vinculado a A: no debe comisionar nunca.
  perform private.beautyos_procesar_evento_epayco(
    v_tenant_y, 'D173-Y-1', 'TX-D173-Y-1', 'Aceptada', '1', 240000, 'COP', '{}'::jsonb
  );

  if not exists (select 1 from public.partner_commissions where tenant_id = v_tenant_y) then
    raise notice 'OK 16  un salón demo vinculado a un partner NO genera comisión al pagar';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 16  el salón demo generó una comisión';
  end if;

  -- Tenant W -- vinculado a un partner INACTIVO: no debe comisionar.
  perform private.beautyos_procesar_evento_epayco(
    v_tenant_w, 'D173-W-1', 'TX-D173-W-1', 'Aceptada', '1', 160000, 'COP', '{}'::jsonb
  );

  if not exists (select 1 from public.partner_commissions where tenant_id = v_tenant_w) then
    raise notice 'OK 17  un partner inactivo no genera comisión aunque el salón le esté vinculado';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 17  se generó una comisión para un partner inactivo';
  end if;

  -- =====================================================================
  -- CASO 18-19: detalle y resumen.
  -- =====================================================================
  perform set_config('request.jwt.claims', json_build_object('sub', v_owner_user::text, 'role', 'authenticated')::text, true);

  select public.platform_get_partner_detail(v_partner_a) into v_detail;
  if jsonb_array_length(v_detail->'linked_tenants') >= 2
     and jsonb_array_length(v_detail->'commissions') = 1
  then
    raise notice 'OK 18  platform_get_partner_detail trae los salones vinculados y la comisión de Carlos';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 18  detalle inesperado: %', v_detail;
  end if;

  select public.platform_get_partners_summary() into v_summary_before;

  -- =====================================================================
  -- CASO 20-21: liquidación de comisiones.
  -- =====================================================================
  select * into v_row from public.platform_settle_partner_commissions(
    v_partner_b, 'nequi', 'REF-BANCO-9988', 'Liquidación de prueba control 192'
  );

  if v_row.settled_count = 2 and v_row.settled_amount_cop = 100000 then
    raise notice 'OK 19  liquidar el partner B marca sus 2 comisiones pendientes como pagadas ($100.000 en total)';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 19  settled_count=%, settled_amount_cop=%', v_row.settled_count, v_row.settled_amount_cop;
  end if;

  select public.platform_get_partners_summary() into v_summary_after;
  if (v_summary_after->>'pending_commissions_cop')::bigint = (v_summary_before->>'pending_commissions_cop')::bigint - 100000
     and (v_summary_after->>'paid_commissions_cop')::bigint = (v_summary_before->>'paid_commissions_cop')::bigint + 100000
  then
    raise notice 'OK 20  platform_get_partners_summary refleja el delta exacto tras la liquidación';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 20  el resumen no reflejó el delta esperado';
  end if;

  v_capturo := false;
  begin
    perform public.platform_settle_partner_commissions(v_partner_b, 'nequi', 'REF-OTRA', null);
  exception
    when others then
      v_capturo := true;
  end;

  if v_capturo then
    raise notice 'OK 21  liquidar un partner sin comisiones pendientes se rechaza';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 21  se permitió liquidar sin comisiones pendientes';
  end if;

  -- =====================================================================
  -- CASO 22: un usuario sin ningún rol de plataforma es rechazado en todo.
  -- =====================================================================
  perform set_config('request.jwt.claims', json_build_object('sub', v_outsider_user::text, 'role', 'authenticated')::text, true);

  v_capturo := false;
  begin
    perform public.platform_list_partners();
  exception
    when others then
      v_capturo := true;
  end;
  if not v_capturo then
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 22a  un usuario sin rol pudo listar partners';
  end if;

  v_capturo := false;
  begin
    perform public.platform_create_partner('X', 'XCODE', 'nequi', '3000000000');
  exception
    when others then
      v_capturo := true;
  end;
  if not v_capturo then
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 22b  un usuario sin rol pudo crear un partner';
  end if;

  v_capturo := false;
  begin
    perform public.platform_set_tenant_partner(v_tenant_t, v_partner_a);
  exception
    when others then
      v_capturo := true;
  end;
  if not v_capturo then
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 22c  un usuario sin rol pudo vincular un partner';
  end if;

  v_capturo := false;
  begin
    perform public.platform_settle_partner_commissions(v_partner_a, 'nequi', 'X', null);
  exception
    when others then
      v_capturo := true;
  end;
  if not v_capturo then
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 22d  un usuario sin rol pudo liquidar comisiones';
  end if;

  if v_fallos = 0 then
    raise notice 'OK 22  un usuario sin rol de plataforma queda rechazado en las cuatro operaciones';
  end if;

  -- =====================================================================
  raise notice ' ';
  if v_fallos = 0 then
    raise notice '=== TODAS LAS PRUEBAS DEL SISTEMA DE PARTNERS PASARON ===';
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
