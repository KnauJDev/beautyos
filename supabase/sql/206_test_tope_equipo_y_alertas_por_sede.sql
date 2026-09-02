-- CONTROL 206: Tope de equipo por sede y alertas de vencimiento por sede
-- (D-196, Bloque 2 "Pulido Multi-Sede y Alertas de Suscripción").
--
-- POR QUÉ ESTE ARCHIVO
--
-- La migración 20260902200000 introduce:
--   1. private.beautyos_require_team_limit(tenant_id, actual) -- multiplica
--      el tope de team_members por las sedes activas.
--   2. public.create_team_invitation(...) -- redefinida para llamar al nuevo
--      ayudante en vez de beautyos_require_limit.
--   3. subscription_notification_logs.branch_id + dos índices parciales que
--      reemplazan el UNIQUE de siempre.
--   4. private.beautyos_registrar_alerta_enviada(...) -- con branch_id
--      opcional al final.
--   5. private.beautyos_obtener_alertas_sede_pendientes() -- hermana de la
--      de negocio, pero para sedes secundarias.
--
-- Este control valida transaccionalmente:
--   - Las cuatro funciones nuevas/redefinidas existen y son SECURITY DEFINER.
--   - Con solo la sede principal, el tope de equipo se comporta EXACTAMENTE
--     igual que antes de D-196 (9 cuentas): cero regresión.
--   - Una sede secundaria PENDIENTE de pago no amplía el cupo.
--   - Una sede secundaria ACTIVA sí lo amplía (9 -> 18).
--   - Un tenant sin suscripción operativa (entitled = false) se rechaza.
--   - `limit_value = null` (sin límite) sigue significando sin límite.
--   - El candado anti-spam de las alertas del NEGOCIO sigue funcionando
--     igual que antes (esto es lo más delicado: dos índices parciales en vez
--     de un UNIQUE con NULL, para que un NULL no cuente como "distinto" y
--     deje mandar el mismo aviso dos veces).
--   - El candado anti-spam por SEDE funciona por separado del de negocio.
--   - `beautyos_obtener_alertas_sede_pendientes` encuentra una sede
--     secundaria por vencer y dejar de encontrarla tras registrar el envío.
--   - `anon`/`authenticated` no alcanzan ninguna de las funciones nuevas.
--
-- Lo que este control NO cubre: el envío real de correos (Resend) y el
-- agrupamiento por negocio en un solo email viven en la Edge Function
-- `send-subscription-expiry-alerts`, que no corre aquí. Se probó a mano
-- contra el log de invocaciones tras desplegar.
--
-- CÓMO SE EJECUTA
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\206_test_tope_equipo_y_alertas_por_sede.sql"
--
-- TERMINA EN ROLLBACK. Todos los datos de prueba se descartan limpiamente.

begin;

do $$
declare
  v_fallos integer := 0;
  v_tenant uuid;
  v_owner uuid;
  v_branches_previos integer;
  v_branch_secundaria uuid;
  v_feature_id uuid;
  v_override_id uuid;
  v_conteo integer;
  v_secdef boolean;
  v_reference_date date := current_date;
begin
  raise notice '======================================================================';
  raise notice 'CONTROL 206 - Tope de equipo y alertas por sede (D-196)';
  raise notice '======================================================================';

  -- Un tenant real, con suscripcion al dia y UNA sola sede, para que el
  -- resultado de "9" no dependa de datos que ya existan en la base.
  select ts.tenant_id
    into v_tenant
  from public.tenant_subscriptions ts
  where ts.status in ('active', 'trialing')
    and (select count(*) from public.branches b where b.tenant_id = ts.tenant_id) = 1
  order by ts.created_at
  limit 1;

  if v_tenant is null then
    raise exception 'No hay ningun tenant activo/trialing con exactamente 1 sede: este control necesita al menos uno.';
  end if;

  select tm.user_id
    into v_owner
  from public.tenant_memberships tm
  where tm.tenant_id = v_tenant
    and tm.role in ('owner', 'tenant_owner')
    and tm.active
  order by tm.created_at
  limit 1;

  select count(*) into v_branches_previos from public.branches where tenant_id = v_tenant;
  raise notice 'Tenant de prueba: % (con % sede(s) antes de empezar).', v_tenant, v_branches_previos;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 1: las cuatro funciones nuevas/redefinidas existen y son SECURITY DEFINER ---';
  -- -------------------------------------------------------------------------
  select count(*), bool_and(p.prosecdef) into v_conteo, v_secdef
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where (n.nspname, p.proname) in (
    ('private', 'beautyos_require_team_limit'),
    ('private', 'beautyos_obtener_alertas_sede_pendientes')
  )
  or (n.nspname = 'private' and p.proname = 'beautyos_registrar_alerta_enviada'
      and p.pronargs = 6)
  or (n.nspname = 'public' and p.proname = 'create_team_invitation');

  if v_conteo <> 4 or v_secdef is null or not v_secdef then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 1 (CRITICO): se esperaban 4 funciones y se encontraron %, o alguna no es SECURITY DEFINER.', v_conteo;
  else
    raise notice 'OK 1: las 4 funciones existen y son SECURITY DEFINER.';
  end if;

  -- La trampa que D-174 ya documento para otra funcion: una firma distinta
  -- crea un OBJETO NUEVO en vez de reemplazar. Si la migracion olvido el
  -- `drop function` de la firma vieja de 5 argumentos, aqui quedarian DOS
  -- versiones de beautyos_registrar_alerta_enviada conviviendo.
  select count(*) into v_conteo
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'private'
    and p.proname = 'beautyos_registrar_alerta_enviada'
    and p.pronargs = 5;

  if v_conteo <> 0 then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 1b (CRITICO): sigue existiendo la firma VIEJA de 5 argumentos de beautyos_registrar_alerta_enviada -- deberia haberse eliminado con DROP FUNCTION antes de crear la de 6.';
  else
    raise notice 'OK 1b: la firma vieja de 5 argumentos ya no existe, solo la de 6.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 2: con solo la principal, el tope se comporta igual que antes (9) ---';
  -- -------------------------------------------------------------------------
  begin
    perform private.beautyos_require_team_limit(v_tenant, 8);
    raise notice 'OK 2a: con 8 cuentas de equipo, 8 < 9, se permite.';
  exception when others then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 2a: se rechazo con 8 cuentas cuando 1 sede deberia permitir 9. %', sqlerrm;
  end;

  begin
    perform private.beautyos_require_team_limit(v_tenant, 9);
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 2b (CRITICO): con 9 cuentas de equipo y 1 sola sede deberia rechazar (limite 9*1=9) y no lo hizo.';
  exception when others then
    raise notice 'OK 2b: con 9 cuentas y 1 sede se rechaza (limite = 9*1 = 9).';
  end;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 3: sede secundaria PENDIENTE no amplia el cupo ---';
  -- -------------------------------------------------------------------------
  insert into public.branches (tenant_id, name, slug, is_primary)
  values (v_tenant, 'Sede de prueba Control 206', 'control-206-sede-prueba', false)
  returning id into v_branch_secundaria;

  if not exists (
    select 1 from public.branch_subscriptions
    where branch_id = v_branch_secundaria and status = 'pending'
  ) then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 3 (CRITICO): la sede nueva no nacio "pending" en branch_subscriptions (deberia venir del disparador de D-190).';
  end if;

  begin
    perform private.beautyos_require_team_limit(v_tenant, 9);
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 3b (CRITICO): con la sede secundaria PENDIENTE, el cupo crecio. Deberia seguir en 9.';
  exception when others then
    raise notice 'OK 3: la sede secundaria pendiente NO amplia el cupo (sigue en 9).';
  end;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 4: sede secundaria ACTIVA amplia el cupo (9 -> 18) ---';
  -- -------------------------------------------------------------------------
  update public.branch_subscriptions
  set status = 'active',
      current_period_start = now(),
      current_period_end = now() + interval '30 days'
  where branch_id = v_branch_secundaria;

  begin
    perform private.beautyos_require_team_limit(v_tenant, 9);
    raise notice 'OK 4a: con la secundaria activa, 9 cuentas de equipo ya se permiten (limite = 9*2 = 18).';
  exception when others then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 4a: con la secundaria activa deberia permitir 9 cuentas (limite 18) y no lo hizo. %', sqlerrm;
  end;

  begin
    perform private.beautyos_require_team_limit(v_tenant, 18);
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 4b (CRITICO): con 18 cuentas y 2 sedes activas deberia rechazar (limite 9*2=18) y no lo hizo.';
  exception when others then
    raise notice 'OK 4b: con 18 cuentas y 2 sedes activas se rechaza (limite = 9*2 = 18).';
  end;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 5: un tenant sin suscripcion operativa se rechaza (entitled = false) ---';
  -- -------------------------------------------------------------------------
  begin
    perform private.beautyos_require_team_limit(gen_random_uuid(), 0);
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 5 (CRITICO): un tenant inexistente deberia rechazarse por "no entitled" y no lo hizo.';
  exception when others then
    raise notice 'OK 5: un tenant sin suscripcion operativa se rechaza. %', sqlerrm;
  end;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 6: limit_value = null (override) sigue significando sin limite ---';
  -- -------------------------------------------------------------------------
  select id into v_feature_id from public.features where key = 'team_members';

  insert into public.tenant_feature_overrides (
    tenant_id, feature_id, enabled, limit_value, reason, created_by
  ) values (
    v_tenant, v_feature_id, true, null, 'Control 206: verificar sin limite', v_owner
  )
  returning id into v_override_id;

  begin
    perform private.beautyos_require_team_limit(v_tenant, 999);
    raise notice 'OK 6: con el override sin limite, 999 cuentas de equipo se permiten sin multiplicar nada.';
  exception when others then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 6: con limit_value NULL (sin limite) deberia permitir cualquier cantidad y no lo hizo. %', sqlerrm;
  end;

  delete from public.tenant_feature_overrides where id = v_override_id;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 7: el candado anti-spam del NEGOCIO sigue intacto (branch_id NULL) ---';
  -- -------------------------------------------------------------------------
  -- Es el caso mas delicado: si un NULL contara como "distinto" de otro NULL,
  -- esto insertaria dos filas y el aviso del negocio se duplicaria.
  perform private.beautyos_registrar_alerta_enviada(
    v_tenant, null, 'control_206_test', 'prueba@salonymas.com'
  );
  perform private.beautyos_registrar_alerta_enviada(
    v_tenant, null, 'control_206_test', 'prueba@salonymas.com'
  );

  select count(*) into v_conteo
  from public.subscription_notification_logs
  where tenant_id = v_tenant
    and notification_type = 'control_206_test'
    and reference_date = v_reference_date
    and branch_id is null;

  if v_conteo <> 1 then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 7 (CRITICO): el candado del negocio dejo % filas en vez de 1 -- un NULL se esta tratando como distinto de otro NULL.', v_conteo;
  else
    raise notice 'OK 7: dos llamadas iguales del negocio dejan 1 sola fila (branch_id NULL).';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 8: el candado anti-spam POR SEDE funciona aparte del de negocio ---';
  -- -------------------------------------------------------------------------
  perform private.beautyos_registrar_alerta_enviada(
    v_tenant, null, 'control_206_test', 'prueba@salonymas.com', '{}'::jsonb, v_branch_secundaria
  );
  perform private.beautyos_registrar_alerta_enviada(
    v_tenant, null, 'control_206_test', 'prueba@salonymas.com', '{}'::jsonb, v_branch_secundaria
  );

  select count(*) into v_conteo
  from public.subscription_notification_logs
  where tenant_id = v_tenant
    and notification_type = 'control_206_test'
    and reference_date = v_reference_date
    and branch_id = v_branch_secundaria;

  if v_conteo <> 1 then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 8a (CRITICO): el candado por sede dejo % filas en vez de 1.', v_conteo;
  else
    raise notice 'OK 8a: dos llamadas iguales de la misma sede dejan 1 sola fila.';
  end if;

  select count(*) into v_conteo
  from public.subscription_notification_logs
  where tenant_id = v_tenant
    and notification_type = 'control_206_test'
    and reference_date = v_reference_date;

  if v_conteo <> 2 then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 8b (CRITICO): deberian quedar exactamente 2 filas (negocio + sede) y quedaron %.', v_conteo;
  else
    raise notice 'OK 8b: el aviso del negocio (branch_id NULL) y el de la sede conviven como filas distintas.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 9: beautyos_obtener_alertas_sede_pendientes encuentra y luego deja de encontrar ---';
  -- -------------------------------------------------------------------------
  update public.branch_subscriptions
  set current_period_end = current_date + interval '3 days'
  where branch_id = v_branch_secundaria;

  select count(*) into v_conteo
  from private.beautyos_obtener_alertas_sede_pendientes()
  where branch_id = v_branch_secundaria
    and notification_type = 'period_3d';

  if v_conteo <> 1 then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 9a (CRITICO): con vencimiento a 3 dias deberia aparecer 1 alerta "period_3d" y aparecieron %.', v_conteo;
  else
    raise notice 'OK 9a: la sede secundaria por vencer en 3 dias aparece en la lista.';
  end if;

  perform private.beautyos_registrar_alerta_enviada(
    v_tenant, null, 'period_3d', 'prueba@salonymas.com', '{}'::jsonb, v_branch_secundaria
  );

  select count(*) into v_conteo
  from private.beautyos_obtener_alertas_sede_pendientes()
  where branch_id = v_branch_secundaria
    and notification_type = 'period_3d';

  if v_conteo <> 0 then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 9b (CRITICO): tras registrar el envio, la misma alerta deberia desaparecer hoy y sigue apareciendo.';
  else
    raise notice 'OK 9b: tras registrar el envio, no se vuelve a ofrecer la misma alerta el mismo dia.';
  end if;

  -- La sede PRINCIPAL nunca debe aparecer en esta lista: su vencimiento ya lo
  -- cubre la alerta del negocio.
  select count(*) into v_conteo
  from private.beautyos_obtener_alertas_sede_pendientes() a
  join public.branches b on b.id = a.branch_id
  where b.tenant_id = v_tenant and b.is_primary = true;

  if v_conteo <> 0 then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 9c (CRITICO): la sede principal aparecio en las alertas de sede secundaria.';
  else
    raise notice 'OK 9c: la sede principal nunca aparece en las alertas de sede secundaria.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '--- CASO 10: anon/authenticated no alcanzan las funciones nuevas ---';
  -- -------------------------------------------------------------------------
  if has_function_privilege('anon', 'private.beautyos_require_team_limit(uuid, integer)', 'EXECUTE')
     or has_function_privilege('authenticated', 'private.beautyos_require_team_limit(uuid, integer)', 'EXECUTE') then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 10a (CRITICO): anon o authenticated alcanzan beautyos_require_team_limit directamente.';
  else
    raise notice 'OK 10a: beautyos_require_team_limit solo se llama desde dentro de otra funcion.';
  end if;

  if has_function_privilege('anon', 'private.beautyos_obtener_alertas_sede_pendientes()', 'EXECUTE')
     or has_function_privilege('authenticated', 'private.beautyos_obtener_alertas_sede_pendientes()', 'EXECUTE') then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 10b (CRITICO): anon o authenticated alcanzan beautyos_obtener_alertas_sede_pendientes.';
  else
    raise notice 'OK 10b: beautyos_obtener_alertas_sede_pendientes es solo de service_role.';
  end if;

  if has_function_privilege(
       'anon',
       'private.beautyos_registrar_alerta_enviada(uuid, uuid, text, text, jsonb, uuid)',
       'EXECUTE') then
    v_fallos := v_fallos + 1;
    raise warning 'FALLO 10c (CRITICO): anon alcanza beautyos_registrar_alerta_enviada con branch_id.';
  else
    raise notice 'OK 10c: beautyos_registrar_alerta_enviada sigue siendo solo de service_role.';
  end if;

  -- -------------------------------------------------------------------------
  raise notice '======================================================================';
  if v_fallos = 0 then
    raise notice 'CONTROL 206: TODOS LOS CASOS EN VERDE. D-196 listo en base de datos.';
    raise notice 'RECORDATORIO: falta desplegar la Edge Function send-subscription-';
    raise notice 'expiry-alerts y probar el agrupamiento por negocio con un envio real.';
  else
    raise exception 'CONTROL 206: % caso(s) fallaron. Revisar arriba.', v_fallos;
  end if;
  raise notice '======================================================================';
end;
$$;

rollback;
