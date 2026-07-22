-- BeautyOS - Fundacion de suscripciones y entitlements.
-- Prueba de contrato contra el esquema sintetico de 132 + tenant_memberships
-- + la migracion real 20260722184914. Mismo aviso de alcance que 132/133:
-- no sustituye una prueba contra el esquema vivo completo.

do $$
declare
  v_tenant_id uuid := gen_random_uuid();
  v_owner_id uuid := gen_random_uuid();
  v_basico_id uuid;
  v_business_id uuid;
  v_profesional_id uuid;
  v_inventory_id uuid;
  v_portfolio_id uuid;
  v_entitled boolean;
  v_limit integer;
  v_source text;
  v_public_rows integer;
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
  ) values (
    '00000000-0000-0000-0000-000000000000', v_owner_id, 'authenticated', 'authenticated',
    'owner-subs@synth.test', crypt('x', gen_salt('bf')), now(), '{}', '{}', now(), now()
  );

  insert into public.tenants (id, name) values (v_tenant_id, 'Centro sintetico suscripciones');

  insert into public.tenant_memberships (tenant_id, user_id, role, active, starts_at)
  values (v_tenant_id, v_owner_id, 'tenant_owner', true, now() - interval '1 day');

  select id into v_basico_id from public.plans where code = 'basico';
  select id into v_business_id from public.plans where code = 'business';
  select id into v_profesional_id from public.plans where code = 'profesional';
  select id into v_inventory_id from public.features where key = 'inventory';
  select id into v_portfolio_id from public.features where key = 'portfolio';

  perform set_config('request.jwt.claim.sub', v_owner_id::text, true);

  -- 1. Sin fila en tenant_subscriptions todavia: nada esta autorizado.
  select entitled into v_entitled
  from private.beautyos_resolve_entitlement(v_tenant_id, 'inventory');
  if v_entitled is distinct from false then
    raise exception 'FALLA 1: sin suscripcion no debio haber entitlement.';
  end if;

  -- 2. Se suscribe al plan Basico (trialing): inventory (Business+) no
  --    incluido, portfolio (solo Profesional) tampoco.
  insert into public.tenant_subscriptions (tenant_id, plan_id, status, trial_ends_at)
  values (v_tenant_id, v_basico_id, 'trialing', now() + interval '14 days');

  select entitled, source into v_entitled, v_source
  from private.beautyos_resolve_entitlement(v_tenant_id, 'inventory');
  if v_entitled is distinct from false or v_source is distinct from 'plan' then
    raise exception 'FALLA 2: Basico no debio incluir inventory (source=%).', v_source;
  end if;

  -- 3. Sube a Business: inventory si, portfolio no.
  update public.tenant_subscriptions set plan_id = v_business_id, status = 'active'
  where tenant_id = v_tenant_id;

  select entitled into v_entitled
  from private.beautyos_resolve_entitlement(v_tenant_id, 'inventory');
  if v_entitled is distinct from true then
    raise exception 'FALLA 3: Business debio incluir inventory.';
  end if;

  select entitled into v_entitled
  from private.beautyos_resolve_entitlement(v_tenant_id, 'portfolio');
  if v_entitled is distinct from false then
    raise exception 'FALLA 4: Business no debio incluir portfolio.';
  end if;

  -- 4. Override temporal habilita portfolio en Business sin cambiar de plan.
  insert into public.tenant_feature_overrides (
    tenant_id, feature_id, enabled, reason, created_by
  ) values (
    v_tenant_id, v_portfolio_id, true, 'Piloto de fotos para el propietario', v_owner_id
  );

  select entitled, source into v_entitled, v_source
  from private.beautyos_resolve_entitlement(v_tenant_id, 'portfolio');
  if v_entitled is distinct from true or v_source is distinct from 'override' then
    raise exception 'FALLA 5: el override debio habilitar portfolio (source=%).', v_source;
  end if;

  -- 5. Override vencido no debe aplicar (se prueba con uno ya expirado).
  insert into public.tenant_feature_overrides (
    tenant_id, feature_id, enabled, reason, starts_at, ends_at, created_by
  ) values (
    v_tenant_id, v_inventory_id, false, 'Prueba de vencimiento', now() - interval '10 days', now() - interval '1 day', v_owner_id
  );

  select entitled, source into v_entitled, v_source
  from private.beautyos_resolve_entitlement(v_tenant_id, 'inventory');
  if v_entitled is distinct from true or v_source is distinct from 'plan' then
    raise exception 'FALLA 6: un override vencido no debio aplicar (source=%).', v_source;
  end if;

  -- 6. get_my_entitlements() devuelve las 5 funcionalidades para el owner.
  if (select count(*) from public.get_my_entitlements()) <> 5 then
    raise exception 'FALLA 7: get_my_entitlements debio devolver 5 filas.';
  end if;

  -- 7. get_my_tenant_subscription() refleja el plan y estado actuales.
  select status into v_source from public.get_my_tenant_subscription();
  if v_source is distinct from 'active' then
    raise exception 'FALLA 8: get_my_tenant_subscription debio mostrar active.';
  end if;

  -- 8. Suscripcion cancelada bloquea todo, incluso con override activo.
  update public.tenant_subscriptions set status = 'cancelled' where tenant_id = v_tenant_id;

  select entitled into v_entitled
  from private.beautyos_resolve_entitlement(v_tenant_id, 'portfolio');
  if v_entitled is distinct from false then
    raise exception 'FALLA 9: una suscripcion cancelada no debio autorizar nada.';
  end if;

  raise notice 'Suscripciones/entitlements: 9 de 9 verificaciones de contrato aprobadas.';
end;
$$;

-- 10. list_public_plans() es de verdad publica (anon) y no depende de
--     autenticacion ni de auth.uid().
select set_config('request.jwt.claim.sub', '', true);
select count(*) as filas_publicas from public.list_public_plans();
