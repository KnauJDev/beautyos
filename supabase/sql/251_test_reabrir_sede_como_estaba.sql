-- CONTROL 251: una sede que se vuelve a abrir queda COMO ESTABA (D-329,
-- hallazgo CR).
--
-- Que valida, transaccionalmente:
--   1. En mora: el dueño la cierra y la reabre, y sigue en mora (antes
--      volvía "pendiente", y cerrar y reabrir borraba la mora). El rastro
--      dice con qué volvió y cómo estaba al cerrarse.
--   2. Al día con días pagados: vuelve al día, con la misma fecha de pago.
--   3. Sin pagar (lo que pasó con Sede Norte el 10-oct): la plataforma la
--      cierra y la reabre, y sigue sin pagar (antes quedaba activa, gratis).
--      Y manda el último cierre, no uno viejo.
--   4. Suspendida: la cierra la plataforma, la reabre el dueño, y sigue
--      suspendida.
--   5. Sin rastro de cómo estaba (cerrada antes de D-328): el dueño la
--      reabre pendiente; la plataforma, activa. Como antes.
--   6. Un administrador no la reabre.
--
-- COMO SE EJECUTA (despues de aplicar 20261010200000_reabrir_sede_como_estaba_d329.sql)
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\251_test_reabrir_sede_como_estaba.sql"
--
-- TERMINA EN ROLLBACK.
--
-- Datos de prueba copiados del control 250, que ya pasó (regla 25d). Cada
-- caso usa su propia sede: dentro de un control todo comparte la misma hora
-- (`now()`), y dos cierres de una misma sede empatarían.

set client_encoding = 'UTF8';

begin;

do $ctrl$
declare
  v_plan      uuid;
  v_operador  uuid;
  v_tenant    uuid;
  v_ts        uuid;
  v_principal uuid;
  v_mora      uuid;
  v_aldia     uuid;
  v_sinpagar  uuid;
  v_susp      uuid;
  v_vieja1    uuid;
  v_vieja2    uuid;
  v_memb      uuid;
  v_dueno     uuid := gen_random_uuid();
  v_admin     uuid := gen_random_uuid();
  v_fecha     timestamptz := date_trunc('second', now() + interval '20 days');
  v_texto     text;
  v_capturo   boolean;
  v_error     text;
  r           record;
begin
  -- ---------------------------------------------------------------- fixtures
  select id into v_plan from public.plans where status = 'active' limit 1;
  if v_plan is null then
    raise exception 'FALLO: no hay ningun plan activo con el que probar';
  end if;
  select po.user_id into v_operador
  from public.platform_operators po
  where po.active and po.role = 'platform_owner'
  limit 1;
  if v_operador is null then
    raise exception 'FALLO: no hay ningun platform_owner activo con el que probar';
  end if;

  insert into auth.users (id, email) values
    (v_dueno, 'dueno_test251@salonymas.com'),
    (v_admin, 'admin_test251@salonymas.com')
  on conflict (id) do nothing;

  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 251', 'peluqueria', 'c251@salonymas.com', '3000000251', true)
  returning id into v_tenant;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_tenant, v_plan, 'active', now() + interval '30 days')
  returning id into v_ts;

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C251 principal', 'c251-principal', true, true)
  returning id into v_principal;
  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C251 mora', 'c251-mora', false, true)
  returning id into v_mora;
  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C251 al dia', 'c251-al-dia', false, true)
  returning id into v_aldia;
  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C251 sin pagar', 'c251-sin-pagar', false, true)
  returning id into v_sinpagar;
  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C251 suspendida', 'c251-suspendida', false, true)
  returning id into v_susp;
  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C251 vieja 1', 'c251-vieja-1', false, true)
  returning id into v_vieja1;
  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C251 vieja 2', 'c251-vieja-2', false, true)
  returning id into v_vieja2;

  update public.branch_subscriptions set status = 'past_due' where branch_id = v_mora;
  update public.branch_subscriptions
     set status = 'active', current_period_end = v_fecha
   where branch_id = v_aldia;
  update public.branch_subscriptions set status = 'pending' where branch_id = v_sinpagar;
  update public.branch_subscriptions set status = 'suspended' where branch_id = v_susp;

  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_dueno, 'tenant_owner', true)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  )
  select v_tenant, b.id, v_memb, true, now() - interval '1 day', v_dueno
  from public.branches b where b.tenant_id = v_tenant;
  insert into public.user_profiles (tenant_id, user_id, full_name, role, active)
  values (v_tenant, v_dueno, 'C251 dueno', 'owner', true);

  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_admin, 'admin', true)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_mora, v_memb, true, now() - interval '1 day', v_dueno);

  -- ---------------------------------------------------------------- 1
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);
  perform public.close_branch(v_mora);
  perform public.reopen_branch(v_mora);
  select bs.status into v_texto from public.branch_subscriptions bs where bs.branch_id = v_mora;
  if v_texto is distinct from 'past_due'
     or not exists (select 1 from public.branches b where b.id = v_mora and b.active) then
    raise exception 'FALLO 1: en mora, tras cerrar y reabrir quedo %', v_texto;
  end if;
  if not exists (
    select 1 from public.subscription_events e
    where e.tenant_id = v_tenant and e.event_type = 'sede_reabierta'
      and e.payload ->> 'branch_id' = v_mora::text
      and e.payload ->> 'estado_nuevo' = 'past_due'
      and e.payload ->> 'estado_al_cerrar' = 'past_due'
  ) then
    raise exception 'FALLO 1b: el rastro sede_reabierta no dice como volvio';
  end if;
  raise notice 'OK 1   en mora: el dueno la cierra y la reabre, y sigue en mora (con su rastro)';

  -- ---------------------------------------------------------------- 2
  perform public.close_branch(v_aldia);
  perform public.reopen_branch(v_aldia);
  select * into r from public.branch_subscriptions bs where bs.branch_id = v_aldia;
  if r.status is distinct from 'active' or r.current_period_end is distinct from v_fecha then
    raise exception 'FALLO 2: al dia, tras cerrar y reabrir quedo % hasta %', r.status, r.current_period_end;
  end if;
  raise notice 'OK 2   al dia con dias pagados: vuelve al dia, con la misma fecha';

  -- ---------------------------------------------------------------- 3
  -- Un cierre viejo, de ayer, cuando estaba al dia: no debe mandar.
  insert into public.subscription_events (
    tenant_id, tenant_subscription_id, event_type, provider, payload, created_at
  ) values (
    v_tenant, v_ts, 'sede_cerrada', 'platform_admin',
    jsonb_build_object('branch_id', v_sinpagar, 'sede', 'C251 sin pagar', 'estado_anterior', 'active'),
    now() - interval '1 day'
  );
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_operador::text, 'role', 'authenticated')::text, true);
  perform public.platform_close_branch(v_sinpagar);
  perform public.platform_reopen_branch(v_sinpagar);
  select bs.status into v_texto from public.branch_subscriptions bs where bs.branch_id = v_sinpagar;
  if v_texto is distinct from 'pending' then
    raise exception 'FALLO 3: sin pagar, tras cerrar y reabrir desde el Panel quedo %', v_texto;
  end if;
  raise notice 'OK 3   sin pagar: la plataforma la cierra y la reabre, y sigue sin pagar (manda el ultimo cierre)';

  -- ---------------------------------------------------------------- 4
  perform public.platform_close_branch(v_susp);
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);
  perform public.reopen_branch(v_susp);
  select bs.status into v_texto from public.branch_subscriptions bs where bs.branch_id = v_susp;
  if v_texto is distinct from 'suspended' then
    raise exception 'FALLO 4: suspendida, tras cerrar y reabrir quedo %', v_texto;
  end if;
  raise notice 'OK 4   suspendida: la cierra la plataforma, la reabre el dueno, y sigue suspendida';

  -- ---------------------------------------------------------------- 5
  -- Cerradas a la antigua: sin el rastro sede_cerrada.
  update public.branches set active = false where id in (v_vieja1, v_vieja2);
  update public.branch_subscriptions set status = 'cancelled' where branch_id in (v_vieja1, v_vieja2);
  perform public.reopen_branch(v_vieja1);
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_operador::text, 'role', 'authenticated')::text, true);
  perform public.platform_reopen_branch(v_vieja2);
  select
    (select bs.status from public.branch_subscriptions bs where bs.branch_id = v_vieja1) as dueno,
    (select bs.status from public.branch_subscriptions bs where bs.branch_id = v_vieja2) as plataforma
  into r;
  if r.dueno is distinct from 'pending' or r.plataforma is distinct from 'active' then
    raise exception 'FALLO 5: sin rastro, el dueno dejo % y la plataforma %', r.dueno, r.plataforma;
  end if;
  raise notice 'OK 5   sin rastro de como estaba: el dueno la reabre pendiente; la plataforma, activa';

  -- ---------------------------------------------------------------- 6
  perform public.platform_close_branch(v_mora);
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_admin::text, 'role', 'authenticated')::text, true);
  v_capturo := false;
  begin
    perform public.reopen_branch(v_mora);
  exception when others then v_capturo := true; v_error := sqlerrm;
  end;
  if not v_capturo then
    raise exception 'FALLO 6: un administrador reabrio la sede';
  end if;
  raise notice 'OK 6   un administrador no la reabre (%)', v_error;

  perform set_config('request.jwt.claims', '{}', true);
  raise notice '--- CONTROL 251: 6/6 ---';
end
$ctrl$;

rollback;
