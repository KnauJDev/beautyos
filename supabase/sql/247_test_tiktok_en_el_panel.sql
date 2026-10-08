-- CONTROL 247: el Panel ve el TikTok de cada salón (D-321, 08-oct).
--
-- Que valida, transaccionalmente:
--   1. `platform_list_tenants` devuelve la columna `tiktok`, y sigue
--      devolviendo lo de antes (instagram, facebook, branches_breakdown).
--   2. El operador de la plataforma ve el TikTok de un salón.
--   3. Un salón sin TikTok sale con NULL (el Panel dice "Sin registrar").
--   4. Alguien sin rol de plataforma sigue sin poder llamarla, y sin sesión no
--      tiene permiso: los permisos de antes.
--
-- COMO SE EJECUTA (despues de aplicar 20261008100000_tiktok_en_el_panel_d321.sql)
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\247_test_tiktok_en_el_panel.sql"
--
-- TERMINA EN ROLLBACK.
--
-- Datos de prueba copiados del control 245 (07-oct), que ya pasó (regla 25d):
-- el plan pro activo y el operador platform_owner que ya existe.

set client_encoding = 'UTF8';

begin;

do $ctrl$
declare
  v_plan      uuid;
  v_operador  uuid;
  v_con       uuid;
  v_sin       uuid;
  v_tiktok    text;
  v_res       text;
  v_capturo   boolean;
begin
  select id into v_plan from public.plans where code = 'pro' and status = 'active' limit 1;
  if v_plan is null then
    raise exception 'FALLO: no hay plan pro activo con el que probar';
  end if;
  select po.user_id into v_operador
  from public.platform_operators po
  where po.active and po.role = 'platform_owner'
  limit 1;
  if v_operador is null then
    raise exception 'FALLO: no hay ningun platform_owner activo con el que probar';
  end if;

  insert into public.tenants (name, business_type, contact_email, whatsapp, active, tiktok)
  values ('Control 247 con', 'barberia', 'c247@salonymas.com', '3000000247', true, '@control247')
  returning id into v_con;
  insert into public.tenant_subscriptions (
    tenant_id, plan_id, status, current_period_start, current_period_end
  ) values (v_con, v_plan, 'active', now() - interval '10 days', now() + interval '20 days');

  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 247 sin', 'barberia', 'c247b@salonymas.com', '3000000248', true)
  returning id into v_sin;
  insert into public.tenant_subscriptions (
    tenant_id, plan_id, status, current_period_start, current_period_end
  ) values (v_sin, v_plan, 'active', now() - interval '10 days', now() + interval '20 days');

  -- 1. Lo que devuelve
  select pg_get_function_result(p.oid) into v_res
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'platform_list_tenants';
  if v_res not like '%tiktok text%'
     or v_res not like '%instagram text%'
     or v_res not like '%facebook text%'
     or v_res not like '%branches_breakdown text%' then
    raise exception 'FALLO 1: devuelve %', v_res;
  end if;
  raise notice 'OK 1   devuelve tiktok, y lo de antes';

  -- 2. El operador ve el TikTok
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_operador::text, 'role', 'authenticated')::text, true);
  select l.tiktok into v_tiktok from public.platform_list_tenants() l where l.tenant_id = v_con;
  if v_tiktok is distinct from '@control247' then
    raise exception 'FALLO 2: el Panel vio "%" y debia ver @control247', v_tiktok;
  end if;
  raise notice 'OK 2   el operador ve el TikTok del salon';

  -- 3. Sin TikTok, NULL
  select l.tiktok into v_tiktok from public.platform_list_tenants() l where l.tenant_id = v_sin;
  if v_tiktok is not null then
    raise exception 'FALLO 3: un salon sin TikTok salio con "%"', v_tiktok;
  end if;
  raise notice 'OK 3   un salon sin TikTok sale sin nada';

  -- 4. Permisos de antes
  perform set_config('request.jwt.claims',
    json_build_object('sub', gen_random_uuid()::text, 'role', 'authenticated')::text, true);
  v_capturo := false;
  begin
    perform 1 from public.platform_list_tenants();
  exception when others then v_capturo := true;
  end;
  if not v_capturo then
    raise exception 'FALLO 4: alguien sin rol de plataforma pudo ver la lista';
  end if;
  if has_function_privilege('anon', 'public.platform_list_tenants()', 'execute')
     or not has_function_privilege('authenticated', 'public.platform_list_tenants()', 'execute') then
    raise exception 'FALLO 4b: los permisos cambiaron';
  end if;
  raise notice 'OK 4   sin rol de plataforma no se ve, y los permisos son los de antes';

  perform set_config('request.jwt.claims', '{}', true);
  raise notice '--- CONTROL 247: 4/4 ---';
end
$ctrl$;

rollback;
