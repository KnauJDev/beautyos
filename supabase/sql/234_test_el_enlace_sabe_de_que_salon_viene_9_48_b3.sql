-- CONTROL 234: Paso 9.48, Bloque 3 (D-287) -- la página del enlace directo
--              sabe de qué salón viene.
--
-- POR QUE ESTE ARCHIVO
--
-- `client_consent_get_pending` gana `business_slug`, para que la página del
-- enlace pinte los colores del salón y ofrezca ir a su página. Lo que puede
-- salir mal y no se ve con una sola clienta:
--   * que el slug no sea el del negocio de la clienta;
--   * que por el enlace de una se vea el nombre de otra;
--   * que un enlace falso devuelva algo en vez de rechazarse.
--
-- Datos de prueba copiados del control 230, que corrió en verde (regla 25 d),
-- con un slug puesto a propósito al negocio.
--
-- COMO SE EJECUTA (después de aplicar
-- 20260928100000_el_enlace_sabe_de_que_salon_viene_9_48_b3.sql)
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\234_test_el_enlace_sabe_de_que_salon_viene_9_48_b3.sql"
--
-- TERMINA EN ROLLBACK. No deja ni una fila.

begin;

do $ctrl$
declare
  v_plan uuid;
  v_tenant uuid;
  v_branch uuid;
  v_service uuid;
  v_stylist uuid;
  v_dueno uuid := gen_random_uuid();
  v_estilista_cuenta uuid := gen_random_uuid();
  v_memb uuid;
  v_cliente1 uuid;
  v_cliente2 uuid;
  v_portal_token1 text := 'control234-portal-token-uno';
  v_portal_token2 text := 'control234-portal-token-dos';
  v_enlace1 text;
  v_enlace2 text;
  v_datos jsonb;
  v_capturo boolean;
  v_error text;
  v_fallos integer := 0;
begin
  select id into v_plan from public.plans where status = 'active' limit 1;
  if v_plan is null then
    raise exception 'FALLO: no hay ningun plan activo con el que probar';
  end if;

  insert into auth.users (id, email) values
    (v_dueno, 'dueno_test234@salonymas.com'),
    (v_estilista_cuenta, 'estilista_test234@salonymas.com')
  on conflict (id) do nothing;

  insert into public.tenants (name, business_type, contact_email, whatsapp, active, slug)
  values ('Control 234', 'peluqueria', 'c234@salonymas.com', '3000000234', true, 'control-234-salon')
  returning id into v_tenant;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_tenant, v_plan, 'active', now() + interval '30 days');

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C234 sede', 'c234-sede', true, true)
  returning id into v_branch;

  -- El dueño.
  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_dueno, 'tenant_owner', true)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);
  insert into public.user_profiles (tenant_id, user_id, full_name, role, active)
  values (v_tenant, v_dueno, 'C234 dueno', 'owner', true);

  insert into public.services (tenant_id, name, category, duration_minutes, price, visible_to_customer)
  values (v_tenant, 'C234 corte', 'Corte', 30, 50000, true)
  returning id into v_service;

  insert into public.stylists (tenant_id, name, phone, specialty)
  values (v_tenant, 'C234 estilista', '3000000234', 'Corte')
  returning id into v_stylist;

  -- El servicio y el estilista, dados de alta EN LA SEDE. Sin esto,
  -- ticket_services revienta: sus llaves apuntan a branch_services y a
  -- branch_stylists, no al catálogo (Tramo B). Copiado del control 218,
  -- que ya corrió en verde (regla 25 d) -- la primera versión de este
  -- control copió del 188, que usaba un negocio existente, y falló aquí.
  insert into public.branch_services (
    tenant_id, branch_id, service_id, price, duration_minutes, visible_to_customer, active
  ) values (v_tenant, v_branch, v_service, 50000, 30, true, true);
  insert into public.branch_stylists (tenant_id, branch_id, stylist_id, active, starts_at)
  values (v_tenant, v_branch, v_stylist, true, now() - interval '1 day');

  -- El estilista con cuenta: copiado tal cual del control 230, donde se
  -- usa; aquí no, pero quitarlo sería cambiar lo que ya corrió en verde.
  insert into public.tenant_memberships (tenant_id, user_id, role, active, stylist_id)
  values (v_tenant, v_estilista_cuenta, 'stylist', true, v_stylist)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);
  insert into public.user_profiles (tenant_id, user_id, full_name, role, active, stylist_id)
  values (v_tenant, v_estilista_cuenta, 'C234 estilista cuenta', 'stylist', true, v_stylist);

  -- Dos clientas. La uno ya tiene sesión de portal abierta (D-167); la dos
  -- solo existe para probar que nadie decide por ella.
  insert into public.clients (tenant_id, name, phone, active, portal_session_token, portal_session_expires_at)
  values (v_tenant, 'C234 Clienta Uno', '3010000001', true, v_portal_token1, now() + interval '60 days')
  returning id into v_cliente1;

  insert into public.clients (tenant_id, name, phone, active, portal_session_token, portal_session_expires_at)
  values (v_tenant, 'C234 Clienta Dos', '3010000002', true, v_portal_token2, now() + interval '60 days')
  returning id into v_cliente2;

  -- Los enlaces directos de las dos, generados por el dueño (D-281).
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);
  v_enlace1 := public.get_or_create_client_consent_link(v_cliente1);
  v_enlace2 := public.get_or_create_client_consent_link(v_cliente2);

  -- Sin sesión desde aquí: la clienta abre el enlace desde WhatsApp.
  perform set_config('request.jwt.claims', '{}', true);

  -- ==========================================================================
  -- 1. Por el enlace directo llega el slug del negocio, con su nombre.
  -- ==========================================================================
  v_datos := public.client_consent_get_pending(null, v_enlace1);
  if v_datos ->> 'business_slug' = 'control-234-salon'
     and v_datos ->> 'business_name' = 'Control 234'
  then
    raise notice 'OK    1  por el enlace llega el slug y el nombre de su salon';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 1  slug=%, nombre=%', v_datos ->> 'business_slug', v_datos ->> 'business_name';
  end if;

  -- ==========================================================================
  -- 2. Por el portal (PIN) llega el mismo slug: dos puertas, una respuesta.
  -- ==========================================================================
  v_datos := public.client_consent_get_pending(v_portal_token1, null);
  if v_datos ->> 'business_slug' = 'control-234-salon' then
    raise notice 'OK    2  por el portal llega el mismo slug';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 2  slug=%', v_datos ->> 'business_slug';
  end if;

  -- ==========================================================================
  -- 3. Cada enlace es de su clienta: por el de la dos, el nombre es el suyo.
  -- ==========================================================================
  v_datos := public.client_consent_get_pending(null, v_enlace2);
  if v_datos ->> 'client_name' = 'C234 Clienta Dos' and v_enlace1 <> v_enlace2 then
    raise notice 'OK    3  el enlace de la clienta dos le muestra a ella, no a la uno';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 3  nombre=%, enlaces iguales=%', v_datos ->> 'client_name', v_enlace1 = v_enlace2;
  end if;

  -- ==========================================================================
  -- 4. Un enlace falso se rechaza, sin devolver nada del salón.
  -- ==========================================================================
  v_capturo := false;
  begin
    v_datos := public.client_consent_get_pending(null, 'control234-enlace-falso');
  exception when others then
    v_capturo := true; v_error := sqlerrm;
  end;
  if v_capturo and v_error like '%enlace no es v%' then
    raise notice 'OK    4  un enlace falso se rechaza';
  else
    v_fallos := v_fallos + 1;
    raise notice 'FALLO 4  capturo=%, mensaje=%', v_capturo, v_error;
  end if;

  raise notice ' ';
  if v_fallos = 0 then
    raise notice '=== CONTROL 234: 4/4 ===';
  else
    raise notice '=== % FALLO(S) EN EL CONTROL 234. Revisar arriba. ===', v_fallos;
  end if;
end
$ctrl$;

rollback;
