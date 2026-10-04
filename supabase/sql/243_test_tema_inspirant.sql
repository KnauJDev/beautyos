-- CONTROL 243: el tema "Inspirant" (paso 3 del plan de David, 03-oct).
--
-- Que valida, transaccionalmente:
--   1. El dueño elige 'inspirant' y queda guardado, sin color propio (los
--      colores viven en la app, D-093b).
--   2. Un tema que no existe se sigue negando, en la función y en la tabla.
--   3. El personalizado sigue igual: pide su color, y al volver a un tema de
--      la lista el color se borra.
--   4. Solo el dueño cambia el tema: el administrador no.
--
-- COMO SE EJECUTA (despues de aplicar 20261003230000_tema_inspirant_paso3.sql)
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\243_test_tema_inspirant.sql"
--
-- TERMINA EN ROLLBACK.
--
-- Datos de prueba copiados del control 242 (03-oct), que ya pasó (regla 25d).

set client_encoding = 'UTF8';

begin;

do $ctrl$
declare
  v_plan    uuid;
  v_tenant  uuid;
  v_branch  uuid;
  v_memb    uuid;
  v_dueno   uuid := gen_random_uuid();
  v_admin   uuid := gen_random_uuid();
  v_capturo boolean;
  r         record;
begin
  select id into v_plan from public.plans where status = 'active' limit 1;
  if v_plan is null then
    raise exception 'FALLO: no hay ningun plan activo con el que probar';
  end if;

  insert into auth.users (id, email) values
    (v_dueno, 'dueno_test243@salonymas.com'),
    (v_admin, 'admin_test243@salonymas.com')
  on conflict (id) do nothing;

  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 243', 'peluqueria', 'c243@salonymas.com', '3000000243', true)
  returning id into v_tenant;
  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_end)
  values (v_tenant, v_plan, 'active', now() + interval '30 days');
  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C243 sede', 'c243-sede', true, true)
  returning id into v_branch;

  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_dueno, 'tenant_owner', true)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);
  insert into public.user_profiles (tenant_id, user_id, full_name, role, active)
  values (v_tenant, v_dueno, 'C243 dueno', 'owner', true);

  insert into public.tenant_memberships (tenant_id, user_id, role, active)
  values (v_tenant, v_admin, 'admin', true)
  returning id into v_memb;
  insert into public.branch_memberships (
    tenant_id, branch_id, tenant_membership_id, active, starts_at, created_by
  ) values (v_tenant, v_branch, v_memb, true, now() - interval '1 day', v_dueno);
  insert into public.user_profiles (tenant_id, user_id, full_name, role, active)
  values (v_tenant, v_admin, 'C243 admin', 'admin', true);

  -- 1. El dueño elige Inspirant
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_dueno::text, 'role', 'authenticated')::text, true);
  perform public.update_tenant_theme('inspirant', '#FF0000');
  select t.theme_key, t.brand_color into r from public.tenants t where t.id = v_tenant;
  if r.theme_key <> 'inspirant' or r.brand_color is not null then
    raise exception 'FALLO 1: quedo theme_key=% brand_color=%', r.theme_key, r.brand_color;
  end if;
  raise notice 'OK 1   el dueno elige Inspirant, y no se guarda ningun color';

  -- 2. Lo que no existe se niega
  v_capturo := false;
  begin
    perform public.update_tenant_theme('oro', null);
  exception when others then v_capturo := true;
  end;
  if not v_capturo then
    raise exception 'FALLO 2: la funcion acepto un tema que no existe';
  end if;
  v_capturo := false;
  begin
    update public.tenants set theme_key = 'oro' where id = v_tenant;
  exception when others then v_capturo := true;
  end;
  if not v_capturo then
    raise exception 'FALLO 2b: la tabla acepto un tema que no existe';
  end if;
  raise notice 'OK 2   un tema que no existe se niega, en la funcion y en la tabla';

  -- 3. El personalizado sigue igual
  perform public.update_tenant_theme('personalizado', '#2f6fb0');
  select t.theme_key, t.brand_color into r from public.tenants t where t.id = v_tenant;
  if r.theme_key <> 'personalizado' or r.brand_color <> '#2F6FB0' then
    raise exception 'FALLO 3: personalizado dejo theme_key=% brand_color=%', r.theme_key, r.brand_color;
  end if;
  perform public.update_tenant_theme('inspirant', null);
  select t.theme_key, t.brand_color into r from public.tenants t where t.id = v_tenant;
  if r.theme_key <> 'inspirant' or r.brand_color is not null then
    raise exception 'FALLO 3b: al volver a Inspirant quedo brand_color=%', r.brand_color;
  end if;
  raise notice 'OK 3   el personalizado sigue igual, y al volver a la lista se borra el color';

  -- 4. El administrador no cambia el tema
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_admin::text, 'role', 'authenticated')::text, true);
  v_capturo := false;
  begin
    perform public.update_tenant_theme('morado', null);
  exception when others then v_capturo := true;
  end;
  if not v_capturo then
    raise exception 'FALLO 4: el administrador pudo cambiar el tema';
  end if;
  raise notice 'OK 4   solo el dueno cambia el tema';

  perform set_config('request.jwt.claims', '{}', true);
  raise notice '--- CONTROL 243: 4/4 ---';
end
$ctrl$;

rollback;
