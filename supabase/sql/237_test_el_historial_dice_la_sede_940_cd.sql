-- CONTROL 237: el historial dice de que sede es cada cobro (paso 9.40), y un
-- cambio de sede desde el Panel deja rastro (hallazgo CD). D-303.
--
-- POR QUE ESTE ARCHIVO
--
-- `platform_set_branch_subscription` cambia el precio, el estado y el
-- vencimiento de una sede, que es el dinero de un cliente, y hasta el 30-sep no
-- lo dejaba escrito en ninguna parte. Y el historial del Panel no decia de que
-- sede era cada cobro. La migracion 20260930190000 arregla las dos cosas.
--
-- Que valida, transaccionalmente:
--   1. Las dos funciones existen, son SECURITY DEFINER, y el historial devuelve
--      `branch_name`.
--   2. Tras borrar y crear el historial, `authenticated` lo puede llamar y
--      `anon` no (los mismos permisos que tenia).
--   3. Pactar un precio en una sede escribe UN evento con el antes y el despues,
--      y quien lo hizo.
--   4. Guardar lo mismo otra vez NO escribe otro.
--   5. Cambiar solo el estado escribe otro, y su descripcion lo dice.
--   6. El historial enseña la sede de esos eventos y describe el precio.
--   7. Un pago de sede CANCELADO, que se guarda sin sede, la toma de su
--      intencion de pago.
--   8. Un evento del negocio (no de una sede) sale sin sede.
--   9. Sin rol de plataforma, el historial se niega.
--
-- COMO SE EJECUTA (despues de aplicar 20260930190000_el_historial_dice_la_sede_940_cd.sql)
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\237_test_el_historial_dice_la_sede_940_cd.sql"
--
-- TERMINA EN ROLLBACK. Los datos de prueba se descartan.
--
-- De donde salen los datos de prueba (regla 25d, copiados de controles que
-- pasaron): el negocio, su suscripcion y sus sedes, del 236 (30-sep); el
-- operador de plataforma que ya existe, del 231; la intencion de pago de una
-- sede, del 203, con las mismas funciones que usa produccion.

begin;

do $ctrl$
declare
  v_plan      uuid;
  v_operador  uuid;
  v_tenant    uuid;
  v_principal uuid;
  v_sede      uuid;
  v_ts        uuid;
  v_factura   text := 'C237-' || substr(gen_random_uuid()::text, 1, 8);
  v_ref       text := 'ref-237-' || substr(gen_random_uuid()::text, 1, 8);
  v_cuantos   integer;
  v_capturo   boolean;
  v_res       record;
  r           record;
begin
  -- 1. Las funciones
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'platform_set_branch_subscription'
      and p.prosecdef
  ) then
    raise exception 'FALLO 1: platform_set_branch_subscription no existe o no es SECURITY DEFINER';
  end if;
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'platform_get_tenant_subscription_history'
      and p.prosecdef
      and pg_get_function_result(p.oid) like '%branch_name%'
  ) then
    raise exception 'FALLO 1b: el historial no existe, no es SECURITY DEFINER o no devuelve branch_name';
  end if;
  raise notice 'OK 1   las dos funciones existen, blindadas, y el historial devuelve la sede';

  -- 2. Los permisos tras borrar y crear
  if not has_function_privilege('authenticated',
       'public.platform_get_tenant_subscription_history(uuid)', 'EXECUTE') then
    raise exception 'FALLO 2: authenticated ya no puede leer el historial (el Panel se quedaria en blanco)';
  end if;
  if has_function_privilege('anon',
       'public.platform_get_tenant_subscription_history(uuid)', 'EXECUTE') then
    raise exception 'FALLO 2b: anon puede llamar al historial';
  end if;
  raise notice 'OK 2   el historial conserva sus permisos: authenticated si, anon no';

  -- Datos de prueba
  select id into v_plan from public.plans where status = 'active' limit 1;
  if v_plan is null then
    raise exception 'FALLO: no hay ningun plan activo con el que probar';
  end if;

  select po.user_id into v_operador
  from public.platform_operators po
  where po.active
  limit 1;
  if v_operador is null then
    raise exception 'FALLO: no hay ningun operador de plataforma activo con el que probar';
  end if;

  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 237', 'barberia', 'c237@salonymas.com', '3000000237', true)
  returning id into v_tenant;

  insert into public.tenant_subscriptions (
    tenant_id, plan_id, status, current_period_start, current_period_end
  ) values (
    v_tenant, v_plan, 'active', now() - interval '10 days', now() + interval '20 days'
  ) returning id into v_ts;

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C237 principal', 'c237-principal', true, true)
  returning id into v_principal;

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_tenant, 'C237 segunda', 'c237-segunda', false, true)
  returning id into v_sede;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_operador::text, 'role', 'authenticated')::text, true);

  -- 3. Pactar un precio escribe un evento con el antes y el despues
  perform public.platform_set_branch_subscription(
    v_sede, 'pending', 20000, 'Control 237: precio pactado'
  );

  select count(*) into v_cuantos
  from public.subscription_events
  where tenant_id = v_tenant and event_type = 'sede_cambiada_desde_el_panel';
  if v_cuantos <> 1 then
    raise exception 'FALLO 3: pactar el precio escribio % eventos y debia escribir 1', v_cuantos;
  end if;

  select * into r
  from public.subscription_events
  where tenant_id = v_tenant and event_type = 'sede_cambiada_desde_el_panel';
  if (r.payload->>'branch_id')::uuid is distinct from v_sede then
    raise exception 'FALLO 3b: el evento no dice de que sede es';
  end if;
  if r.payload->>'precio_anterior' is not null
     or (r.payload->>'precio_nuevo')::bigint is distinct from 20000 then
    raise exception 'FALLO 3c: el evento dice de % a % y debia ser de nada a 20000',
      r.payload->>'precio_anterior', r.payload->>'precio_nuevo';
  end if;
  if r.created_by is distinct from v_operador then
    raise exception 'FALLO 3d: el evento no dice quien hizo el cambio';
  end if;
  if r.provider is distinct from 'platform_admin' or r.tenant_subscription_id is distinct from v_ts then
    raise exception 'FALLO 3e: el evento no quedo como los demas del Panel (provider %, suscripcion %)',
      r.provider, r.tenant_subscription_id;
  end if;
  raise notice 'OK 3   pactar un precio deja un evento: la sede, de nada a 20000, y quien fue';

  -- 4. Guardar lo mismo no escribe otro
  perform public.platform_set_branch_subscription(
    v_sede, 'pending', 20000, 'Control 237: precio pactado'
  );
  select count(*) into v_cuantos
  from public.subscription_events
  where tenant_id = v_tenant and event_type = 'sede_cambiada_desde_el_panel';
  if v_cuantos <> 1 then
    raise exception 'FALLO 4: guardar lo mismo escribio otro evento (hay %)', v_cuantos;
  end if;
  raise notice 'OK 4   guardar lo mismo no ensucia el historial';

  -- 5. Cambiar solo el estado escribe otro
  perform public.platform_set_branch_subscription(v_sede, 'active');
  select count(*) into v_cuantos
  from public.subscription_events
  where tenant_id = v_tenant and event_type = 'sede_cambiada_desde_el_panel';
  if v_cuantos <> 2 then
    raise exception 'FALLO 5: cambiar el estado dejo % eventos y debian ser 2', v_cuantos;
  end if;
  raise notice 'OK 5   cambiar solo el estado tambien queda escrito';

  -- 6. El historial dice la sede y describe el cambio
  select count(*) into v_cuantos
  from public.platform_get_tenant_subscription_history(v_tenant) h
  where h.event_type = 'sede_cambiada_desde_el_panel'
    and h.branch_id = v_sede
    and h.branch_name = 'C237 segunda';
  if v_cuantos <> 2 then
    raise exception 'FALLO 6: el historial enseña la sede en % de los 2 cambios', v_cuantos;
  end if;
  if not exists (
    select 1 from public.platform_get_tenant_subscription_history(v_tenant) h
    where h.event_type = 'sede_cambiada_desde_el_panel'
      and h.description like '%precio%20000%'
  ) then
    raise exception 'FALLO 6b: el historial no describe el cambio de precio';
  end if;
  if not exists (
    select 1 from public.platform_get_tenant_subscription_history(v_tenant) h
    where h.event_type = 'sede_cambiada_desde_el_panel'
      and h.description like '%estado pending -> active%'
  ) then
    raise exception 'FALLO 6c: el historial no describe el cambio de estado';
  end if;
  raise notice 'OK 6   el historial dice la sede y que cambio';

  -- 7. Un pago de sede cancelado toma la sede de su intencion
  perform private.beautyos_registrar_intencion_pago(
    v_factura, v_tenant, 'pro', null, 20000::bigint, null, v_sede
  );
  select * into v_res
  from private.beautyos_resolver_intencion_pago(v_factura, v_tenant, v_ref);
  if not v_res.coincide then
    raise exception 'FALLO 7 (preparacion): la intencion de pago no se resolvio: %', v_res.motivo;
  end if;

  insert into public.subscription_events (
    tenant_id, tenant_subscription_id, event_type, provider, provider_event_id, payload
  ) values (
    v_tenant, v_ts, 'epayco_sede_cancelada', 'epayco', v_ref,
    jsonb_build_object('x_cod_transaction_state', '11', 'x_transaction_state', 'Cancelada')
  );

  select * into r
  from public.platform_get_tenant_subscription_history(v_tenant) h
  where h.event_type = 'epayco_sede_cancelada';
  if r.branch_name is distinct from 'C237 segunda' then
    raise exception 'FALLO 7: el pago cancelado sale con la sede % y debia salir C237 segunda',
      coalesce(r.branch_name, '(ninguna)');
  end if;
  raise notice 'OK 7   un pago de sede cancelado toma su sede de la intencion de pago';

  -- 8. Un evento del negocio sale sin sede
  insert into public.subscription_events (
    tenant_id, tenant_subscription_id, event_type, provider, payload
  ) values (
    v_tenant, v_ts, 'contact_updated', 'platform_admin',
    jsonb_build_object('contact_name', 'Control 237')
  );
  select * into r
  from public.platform_get_tenant_subscription_history(v_tenant) h
  where h.event_type = 'contact_updated';
  if r.branch_id is not null or r.branch_name is not null then
    raise exception 'FALLO 8: un evento del negocio salio con la sede %', r.branch_name;
  end if;
  raise notice 'OK 8   un evento del negocio sale sin sede';

  -- 9. Sin rol de plataforma, el historial se niega
  perform set_config('request.jwt.claims',
    json_build_object('sub', gen_random_uuid()::text, 'role', 'authenticated')::text, true);
  v_capturo := false;
  begin
    perform * from public.platform_get_tenant_subscription_history(v_tenant);
  exception when others then
    v_capturo := true;
  end;
  if not v_capturo then
    raise exception 'FALLO 9: alguien sin rol de plataforma leyo el historial de un negocio';
  end if;
  raise notice 'OK 9   sin rol de plataforma, el historial se niega';

  perform set_config('request.jwt.claims', '{}', true);

  raise notice '--- CONTROL 237: 9/9 ---';
end
$ctrl$;

rollback;
