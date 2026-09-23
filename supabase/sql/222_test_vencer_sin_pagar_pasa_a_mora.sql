-- CONTROL 222: Vencer sin pagar pasa a mora, con su gracia. Hallazgo BI.
--
-- POR QUE ESTE ARCHIVO EXISTE
--
-- Hasta el 23-sep solo un pago RECHAZADO pasaba una suscripcion a mora. Aqui
-- el pago es manual: quien no pagaba se quedaba `active` para siempre, el
-- candado le negaba las citas sin los 5 dias de gracia de D-141, y una sede
-- sin pagar no se cortaba nunca. Lo vio el propietario con Naguara.
--
-- **Y no se sospecho en dos meses porque ningun control RECORRIA el
-- vencimiento**: los que habia leian estados ya puestos a mano. Este fabrica
-- un negocio que vencio ayer y otro que vencio hace diez dias, **corre el
-- reloj** con la funcion nueva y el vigilante que ya existia, y mira lo que
-- queda (D-245: los controles EJECUTAN el camino, no lo leen).
--
-- Que valida, transaccionalmente:
--   1. Antes: un negocio `active` vencido NO acepta citas (es el fallo: sin
--      gracia).
--   2. La funcion lo pasa a `past_due` con la gracia en fin de periodo + 5 dias.
--   3. **Y en gracia vuelve a aceptar citas**, como prometio D-141.
--   4. Queda escrito en `subscription_events`.
--   5. La sede principal vencida pasa a `past_due` con su gracia.
--   6. La sede que vencio hace diez dias acaba `suspended` en la misma pasada.
--   7. Un negocio al dia no se toca.
--   8. Correrla dos veces no duplica nada.
--   9. Cuando la gracia vence, el vigilante del 17-ago suspende el negocio, y
--      ya no acepta citas: la cadena entera funciona.
--  10. La tarea diaria esta programada, y antes del vigilante.
--
-- COMO SE EJECUTA (despues de aplicar 20260923120000_vencer_sin_pagar_pasa_a_mora_bi.sql)
--
--   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
--     -Archivo "supabase\sql\222_test_vencer_sin_pagar_pasa_a_mora.sql"
--
-- TERMINA EN ROLLBACK. Los fixtures se copiaron del control 221, que ya
-- funciona, en vez de escribirlos de memoria.

begin;

do $ctrl$
declare
  v_plan        uuid;
  v_moroso      uuid;
  v_al_dia      uuid;
  v_principal   uuid;
  v_secundaria  uuid;
  v_ts          uuid;
  v_estado      text;
  v_gracia      timestamptz;
  v_fin         timestamptz := now() - interval '1 day';
  v_acepta      boolean;
  v_eventos     integer;
  v_eventos_2   integer;
  v_hora        text;
begin
  select id into v_plan from public.plans where status = 'active' limit 1;
  if v_plan is null then
    raise exception 'FALLO: no hay ningun plan activo con el que probar';
  end if;

  -- Un negocio que vencio AYER, con su sede principal y una secundaria que
  -- vencio hace diez dias.
  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 222 moroso', 'barberia', 'c222@salonymas.com', '3000000222', true)
  returning id into v_moroso;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_start, current_period_end)
  values (v_moroso, v_plan, 'active', v_fin - interval '30 days', v_fin)
  returning id into v_ts;

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_moroso, 'C222 principal', 'c222-principal', true, true)
  returning id into v_principal;

  insert into public.branches (tenant_id, name, slug, is_primary, active)
  values (v_moroso, 'C222 secundaria', 'c222-secundaria', false, true)
  returning id into v_secundaria;

  -- La suscripcion de cada sede la crea un disparador al insertar la sede; se
  -- ponen al dia a mano como las dejaria un pago.
  update public.branch_subscriptions
  set status = 'active', current_period_end = v_fin, activated_at = v_fin - interval '30 days'
  where branch_id = v_principal;

  update public.branch_subscriptions
  set status = 'active', current_period_end = now() - interval '10 days',
      activated_at = now() - interval '40 days'
  where branch_id = v_secundaria;

  if not exists (select 1 from public.branch_subscriptions where branch_id = v_secundaria and status = 'active') then
    raise exception 'FALLO: el fixture no pudo crear la suscripcion de la sede. Revisar el disparador de sedes.';
  end if;

  -- Y un negocio al dia, que no se debe tocar.
  insert into public.tenants (name, business_type, contact_email, whatsapp, active)
  values ('Control 222 al dia', 'barberia', 'c222b@salonymas.com', '3000000223', true)
  returning id into v_al_dia;

  insert into public.tenant_subscriptions (tenant_id, plan_id, status, current_period_start, current_period_end)
  values (v_al_dia, v_plan, 'active', now() - interval '5 days', now() + interval '25 days');

  -- 1. Antes: sin gracia
  v_acepta := private.beautyos_tenant_accepts_new_commitments(v_moroso);
  if v_acepta then
    raise exception 'FALLO 1: un negocio activo vencido ayer acepta citas ANTES de pasar a mora. El fixture no reproduce el caso.';
  end if;
  raise notice 'OK 1   antes: el negocio vencido ayer no acepta citas y no tiene gracia (el fallo)';

  -- Corre el reloj
  perform private.beautyos_pasar_a_mora_por_fecha();

  -- 2. A mora, con la gracia bien puesta
  select status, grace_ends_at into v_estado, v_gracia
  from public.tenant_subscriptions where tenant_id = v_moroso;

  if v_estado is distinct from 'past_due' then
    raise exception 'FALLO 2: el negocio vencido quedo en % y no en past_due.', v_estado;
  end if;
  if v_gracia is distinct from v_fin + interval '5 days' then
    raise exception 'FALLO 2b: la gracia quedo hasta % y debia ser el fin del periodo + 5 dias (%).', v_gracia, v_fin + interval '5 days';
  end if;
  raise notice 'OK 2   el negocio vencido pasa a past_due con gracia hasta fin de periodo + 5 dias';

  -- 3. En gracia vuelve a aceptar citas
  v_acepta := private.beautyos_tenant_accepts_new_commitments(v_moroso);
  if not v_acepta then
    raise exception 'FALLO 3: en gracia el negocio sigue sin aceptar citas. D-141 prometio 5 dias.';
  end if;
  raise notice 'OK 3   en gracia el negocio vuelve a aceptar citas, como prometio D-141';

  -- 4. Queda escrito
  select count(*) into v_eventos
  from public.subscription_events
  where tenant_id = v_moroso and event_type = 'auto_past_due_period_expired';
  if v_eventos <> 1 then
    raise exception 'FALLO 4: esperaba 1 evento de mora del negocio y hay %.', v_eventos;
  end if;
  raise notice 'OK 4   el paso a mora queda escrito en subscription_events';

  -- 5. La sede principal, a mora con su gracia
  select status, grace_ends_at into v_estado, v_gracia
  from public.branch_subscriptions where branch_id = v_principal;
  if v_estado is distinct from 'past_due' or v_gracia is distinct from v_fin + interval '5 days' then
    raise exception 'FALLO 5: la sede principal quedo en % con gracia hasta %.', v_estado, v_gracia;
  end if;
  raise notice 'OK 5   la sede principal vencida pasa a past_due con su gracia';

  -- 6. La secundaria, vencida hace diez dias: suspendida en la misma pasada
  select status into v_estado
  from public.branch_subscriptions where branch_id = v_secundaria;
  if v_estado is distinct from 'suspended' then
    raise exception 'FALLO 6: la sede vencida hace diez dias quedo en % y no suspendida. Es el "no se corta nunca" de BI.', v_estado;
  end if;
  raise notice 'OK 6   la sede con la gracia vencida queda suspendida';

  -- 7. El negocio al dia, intacto
  select status into v_estado from public.tenant_subscriptions where tenant_id = v_al_dia;
  if v_estado is distinct from 'active' then
    raise exception 'FALLO 7: un negocio al dia quedo en %.', v_estado;
  end if;
  raise notice 'OK 7   un negocio al dia no se toca';

  -- 8. Dos veces no duplica
  select count(*) into v_eventos
  from public.subscription_events where tenant_id = v_moroso;
  perform private.beautyos_pasar_a_mora_por_fecha();
  select count(*) into v_eventos_2
  from public.subscription_events where tenant_id = v_moroso;
  if v_eventos_2 <> v_eventos then
    raise exception 'FALLO 8: correrla otra vez anadio % evento(s).', v_eventos_2 - v_eventos;
  end if;
  raise notice 'OK 8   correrla dos veces no duplica nada';

  -- 9. La cadena entera: vence la gracia, el vigilante suspende
  update public.tenant_subscriptions
  set grace_ends_at = now() - interval '1 minute'
  where tenant_id = v_moroso;

  perform private.beautyos_suspender_suscripciones_vencidas();

  select status into v_estado from public.tenant_subscriptions where tenant_id = v_moroso;
  if v_estado is distinct from 'suspended' then
    raise exception 'FALLO 9: con la gracia vencida el vigilante dejo el negocio en %.', v_estado;
  end if;
  if private.beautyos_tenant_accepts_new_commitments(v_moroso) then
    raise exception 'FALLO 9b: un negocio suspendido sigue aceptando citas.';
  end if;
  raise notice 'OK 9   vencida la gracia, el vigilante suspende y el candado cierra: la cadena entera funciona';

  -- 10. Programada, y antes del vigilante
  select schedule into v_hora from cron.job where jobname = 'mora_por_fecha_diario';
  if v_hora is null then
    raise exception 'FALLO 10: la tarea diaria mora_por_fecha_diario no esta programada.';
  end if;
  if v_hora <> '50 12 * * *' then
    raise exception 'FALLO 10b: la tarea corre a "%" y tiene que ir antes del vigilante de las 13:00 UTC.', v_hora;
  end if;
  raise notice 'OK 10  la tarea diaria corre a las 07:50 de Colombia, antes del vigilante';

  raise notice '--- CONTROL 222: 10/10 ---';
end
$ctrl$;

rollback;
