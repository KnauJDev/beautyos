-- CONTROL 245: el interruptor de los cinco lugares nace apagado y se enciende
-- salón por salón desde el Panel (D-318, paso 6 del plan de David).
--
-- Que valida, transaccionalmente:
--   1. Existe `cinco_lugares` y los planes la traen APAGADA (todos).
--   2. Un negocio la tiene negada, por el plan: al publicar, nadie la ve.
--   3. Encenderla desde el Panel (`platform_set_tenant_feature_override` con
--      enabled = true) la concede, con source = 'override', y deja su evento.
--   4. Encenderla a uno no se la enciende a otro negocio.
--   5. El dueño del negocio la ve encendida en `get_my_entitlements`, que es
--      lo que lee la app.
--   6. Quitar la excepción la devuelve a apagada, por el plan.
--
-- COMO SE EJECUTA (despues de aplicar 20261007100000_cinco_lugares_interruptor_d318.sql)
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\245_test_cinco_lugares_interruptor.sql"
--
-- TERMINA EN ROLLBACK.
--
-- Datos de prueba copiados del control 239 (02-oct), que ya pasó (regla 25d):
-- los dos negocios en el plan pro, el operador platform_owner que ya existe y
-- las funciones del Panel. El dueño con su membresía, del 244 (04-oct).

set client_encoding = 'UTF8';

begin;

do $ctrl$
declare
  v_plan      uuid;
  v_planes    integer;
  v_operador  uuid;
  v_tenant    uuid;
  v_otro      uuid;
  v_branch    uuid;
  v_memb      uuid;
  v_dueno     uuid := gen_random_uuid();
  v_override  uuid;
  v_n         integer;
  r           record;
begin
  -- 1. Existe, y todos los planes la traen apagada
  select count(*) into v_planes from public.plans;
  if not exists (select 1 from public.features where key = 'cinco_lugares') then
    raise exception 'FALLO 1: no existe la capacidad cinco_lugares';
  end if;
  select count(*) into v_n
  from public.plan_features pf
  join public.features f on f.id = pf.feature_id
  where f.key = 'cinco_lugares' and not pf.enabled;
  if v_n <> v_planes then
    raise exception 'FALLO 1b: cinco_lugares apagada en % de % planes', v_n, v_planes;
  end if;
  raise notice 'OK 1   cinco_lugares existe, apagada en los % planes', v_planes;

  -- Datos de prueba
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

  insert into auth.users (id, email) values (v_dueno, 'dueno_test245@salonymas.com')
  on conflict (id) do nothing;

  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 245', 'barberia', 'c245@salonymas.com', '3000000245', true)
  returning id into v_tenant;
  insert into public.tenant_subscriptions (
    tenant_id, plan_id, status, current_period_start, current_period_end
  ) values (
    v_tenant, v_plan, 'active', now() - interval '10 days', now() + interval '20 days'
  );
  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C245 sede', 'c245-sede', true, true)
  returning id into v_branch;
  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_dueno, 'tenant_owner', true)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);
  insert into public.user_profiles (tenant_id, user_id, full_name, role, active)
  values (v_tenant, v_dueno, 'C245 dueno', 'owner', true);

  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 245 otro', 'barberia', 'c245b@salonymas.com', '3000000246', true)
  returning id into v_otro;
  insert into public.tenant_subscriptions (
    tenant_id, plan_id, status, current_period_start, current_period_end
  ) values (
    v_otro, v_plan, 'active', now() - interval '10 days', now() + interval '20 days'
  );

  -- 2. Por el plan, apagada
  select * into r from private.beautyos_resolve_entitlement(v_tenant, 'cinco_lugares');
  if r.entitled or r.source <> 'plan' then
    raise exception 'FALLO 2: cinco_lugares da entitled=% source=% y debia ser false por el plan', r.entitled, r.source;
  end if;
  raise notice 'OK 2   un negocio la tiene apagada, por el plan: al publicar nadie la ve';

  -- 3. Encenderla desde el Panel
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_operador::text, 'role', 'authenticated')::text, true);
  select o.override_id into v_override
  from public.platform_set_tenant_feature_override(
    v_tenant, 'cinco_lugares', true, null, 'Control 245: encendido desde el Panel', null
  ) o;
  select * into r from private.beautyos_resolve_entitlement(v_tenant, 'cinco_lugares');
  if not r.entitled or r.source <> 'override' then
    raise exception 'FALLO 3: tras encenderla, da entitled=% source=%', r.entitled, r.source;
  end if;
  if not exists (
    select 1 from public.subscription_events
    where tenant_id = v_tenant and event_type = 'feature_override_granted'
      and payload->>'feature_key' = 'cinco_lugares' and payload->>'enabled' = 'true'
  ) then
    raise exception 'FALLO 3b: encenderla no dejo su evento en el historial';
  end if;
  raise notice 'OK 3   encendida desde el Panel: concedida, por excepcion, y queda en el historial';

  -- 4. Al otro negocio no se le enciende
  select * into r from private.beautyos_resolve_entitlement(v_otro, 'cinco_lugares');
  if r.entitled then
    raise exception 'FALLO 4: encenderla a un negocio se la encendio a otro';
  end if;
  raise notice 'OK 4   encenderla a uno no se la enciende a otro';

  -- 5. El dueño la ve encendida, en lo que lee la app
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);
  select * into r from public.get_my_entitlements() e where e.feature_key = 'cinco_lugares';
  if not r.entitled or r.source <> 'override' then
    raise exception 'FALLO 5: el dueno la ve entitled=% source=%', r.entitled, r.source;
  end if;
  raise notice 'OK 5   el dueno la ve encendida en get_my_entitlements';

  -- 6. Quitar la excepcion la apaga otra vez
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_operador::text, 'role', 'authenticated')::text, true);
  perform public.platform_delete_tenant_feature_override(v_override);
  select * into r from private.beautyos_resolve_entitlement(v_tenant, 'cinco_lugares');
  if r.entitled or r.source <> 'plan' then
    raise exception 'FALLO 6: tras quitar la excepcion, da entitled=% source=%', r.entitled, r.source;
  end if;
  raise notice 'OK 6   quitar la excepcion la apaga otra vez, por el plan';

  perform set_config('request.jwt.claims', '{}', true);
  raise notice '--- CONTROL 245: 6/6 ---';
end
$ctrl$;

rollback;
