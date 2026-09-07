-- CONTROL 207: El pionero es una etiqueta, no un 50% (D-221, paso 9.28).
--
-- POR QUÉ ESTE ARCHIVO
--
-- D-221 salió sin control, y eso se notó el mismo día: para saber si la
-- migración había aplicado se miró el TEXTO de la función buscando "50.00",
-- y salió que sí -- porque la propia migración menciona esa cifra en un
-- comentario que explica qué se quitó. La comprobación era ambigua.
--
-- Este control no mira texto: mira COMPORTAMIENTO. Una función que se
-- comporta bien no se puede malinterpretar.
--
-- Qué valida, transaccionalmente:
--   1. `platform_update_tenant_pricing` existe y es SECURITY DEFINER.
--   2. Su cuerpo ya NO contiene la asignación ejecutable del 50%.
--   3. Marcar pionero SIN precio ni descuento se RECHAZA (fail-closed), y el
--      mensaje remite a que la tarifa se negocia una a una.
--   4. Marcar pionero CON precio pactado funciona, y deja `discount_percent`
--      en null: la etiqueta no inventa descuentos.
--   5. El precio pactado manda sobre el de lista al calcular el cargo.
--   6. La trampa de D-222: precio pactado y descuento porcentual NO son
--      alternativas, se ACUMULAN. 50.000 con un 50% marcado cobran 25.000.
--      Se deja probado para que nadie lo descubra cobrando de menos.
--   7. `anon` no alcanza la función.
--
-- CÓMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\207_test_pionero_sin_porcentaje.sql"
--
-- TERMINA EN ROLLBACK. Todos los datos de prueba se descartan limpiamente.

begin;

do $ctrl$
declare
  v_owner_user uuid := gen_random_uuid();
  v_tenant     uuid;
  v_plan       uuid;
  v_lista      bigint;
  v_def        text;
  v_sub        public.tenant_subscriptions%rowtype;
  v_monto      bigint;
  v_capturo    boolean;
  v_error      text;
begin
  select pg_get_functiondef(p.oid) into v_def
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'platform_update_tenant_pricing';

  if v_def is null then
    raise exception 'FALLO 1: public.platform_update_tenant_pricing no existe';
  end if;
  if v_def not ilike '%security definer%' then
    raise exception 'FALLO 1b: la funcion no es SECURITY DEFINER';
  end if;
  raise notice 'OK 1   la funcion existe y es SECURITY DEFINER';

  if v_def like '%v_discount_percent := coalesce(v_discount_percent, 50%' then
    raise exception 'FALLO 2: la asignacion automatica del 50%% sigue viva (D-221 no aplico)';
  end if;
  raise notice 'OK 2   ya no asigna el 50%% automatico';

  select id, price_cop into v_plan, v_lista
  from public.plans where code = 'pro' and status = 'active' limit 1;
  if v_plan is null then
    raise exception 'FALLO: no hay plan pro activo con el que probar';
  end if;

  insert into auth.users (id, email)
  values (v_owner_user, 'owner_test207@salonymas.com')
  on conflict (id) do nothing;

  insert into public.platform_operators (user_id, role, active)
  values (v_owner_user, 'platform_owner', true)
  on conflict (user_id) do update set role = excluded.role, active = true;

  insert into public.tenants (name, business_type, contact_email, whatsapp, is_demo, active)
  values ('Control 207 - socio de diseno', 'barberia', 'c207@salonymas.com', '3000000207', true, true)
  returning id into v_tenant;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_start, current_period_end)
  values (v_tenant, v_plan, 'active', now(), now() + interval '30 days');

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_owner_user::text, 'role', 'authenticated')::text, true);

  v_capturo := false;
  begin
    perform public.platform_update_tenant_pricing(v_tenant, 'pro', true, null, null, null);
  exception when others then
    v_capturo := true;
    v_error := sqlerrm;
  end;

  if not v_capturo then
    raise exception 'FALLO 3: marcar pionero sin precio NO fue rechazado; la funcion esta adivinando';
  end if;
  if v_error not like '%negocia una a una%' then
    raise exception 'FALLO 3b: se rechazo, pero el mensaje no explica por que: %', v_error;
  end if;
  raise notice 'OK 3   pionero sin precio se rechaza, y el mensaje remite a D-188/D-189';

  perform public.platform_update_tenant_pricing(
    v_tenant, 'pro', true, 50000, null, 'Socio de diseno, tarifa congelada (D-222)');

  select * into v_sub from public.tenant_subscriptions where tenant_id = v_tenant;

  if v_sub.price_cop is distinct from 50000 then
    raise exception 'FALLO 4: el precio pactado quedo en % y debia ser 50000', v_sub.price_cop;
  end if;
  if v_sub.discount_percent is not null then
    raise exception 'FALLO 4b: se invento un descuento de %; la etiqueta no debe calcular nada', v_sub.discount_percent;
  end if;
  if v_sub.is_founder is not true then
    raise exception 'FALLO 4c: la etiqueta de pionero no quedo puesta';
  end if;
  raise notice 'OK 4   pionero con precio pactado: 50.000, sin descuento inventado, etiqueta puesta';

  select monto_cop into v_monto
  from private.beautyos_calcular_cargo_epayco(v_tenant, 'pro');

  if v_monto is distinct from 50000 then
    raise exception 'FALLO 5: el cargo salio en % y el precio pactado era 50000 (lista: %)', v_monto, v_lista;
  end if;
  raise notice 'OK 5   el cargo respeta el precio pactado: % (la lista es %)', v_monto, v_lista;

  perform public.platform_update_tenant_pricing(
    v_tenant, 'pro', true, 50000, 50, 'Prueba de acumulacion (control 207)');

  select monto_cop into v_monto
  from private.beautyos_calcular_cargo_epayco(v_tenant, 'pro');

  if v_monto = 50000 then
    raise exception 'FALLO 6: se esperaba acumulacion y el cargo siguio en 50000. Si cambio a proposito, actualizar D-222';
  end if;
  raise notice 'OK 6   AVISO DOCUMENTADO: precio 50.000 mas descuento 50%% cobran %. NO se ponen los dos (D-222)', v_monto;

  if has_function_privilege('anon',
       'public.platform_update_tenant_pricing(uuid, text, boolean, bigint, numeric, text)', 'execute') then
    raise exception 'FALLO 7: anon puede ejecutar la funcion de tarifas';
  end if;
  raise notice 'OK 7   anon no alcanza la funcion';

  raise notice '---------------------------------------------';
  raise notice 'CONTROL 207 COMPLETO: 7 de 7 en verde.';
end
$ctrl$;

rollback;
