-- ==============================================================================
-- D-329 (hallazgo CR): una sede que se vuelve a abrir queda COMO ESTABA.
-- ==============================================================================
--
-- POR QUÉ. El 10-oct, probando el paso 9.65 (D-328) con *Prueba Dos Sedes*,
-- Sede Norte estaba sin pagar (`pending`); se cerró desde el salón y se
-- reabrió desde el Panel, y quedó *Al día* (`active`) sin fecha de pago:
-- gratis. Reabrir no miraba cómo estaba la sede: el Panel la dejaba `active`
-- y el dueño del salón `pending`, aunque hubiera estado al día con días
-- pagados o en mora. Así, cerrar y reabrir también servía para borrar una
-- mora. El propietario decidió: **vuelve como estaba al cerrarse, desde el
-- Panel y desde el salón.**
--
-- QUÉ CAMBIA. Solo `private.beautyos_reabrir_sede`, **generada por un script
-- desde su texto vivo** (`intervenciones/extraer_reabrir_como_estaba_d329.sql`)
-- con cinco cambios contados, que hacen tres cosas:
--   1. Lee el `estado_anterior` del último rastro `sede_cerrada` de la sede
--      (lo escribe `beautyos_cerrar_sede` desde D-328) y lo devuelve.
--   2. Si no se sabe, vale el `p_estado` de siempre: `pending` desde el
--      salón, `active` desde el Panel. Las funciones públicas
--      (`reopen_branch`, `platform_reopen_branch`) no cambian; el comentario
--      de `reopen_branch` que dice "como una sede nueva" queda solo para ese
--      caso.
--   3. El rastro `sede_reabierta` dice con qué estado volvió y cuál tenía al
--      cerrarse (`estado_al_cerrar`).
-- Cerrar no toca la fecha de pago (`current_period_end`), así que con el
-- estado vuelve todo: una sede al día sigue al día hasta su fecha.
--
-- Misma firma y mismo retorno: no hace falta DROP y conserva sus permisos.
--
-- Lo prueba el CONTROL 251.
-- ==============================================================================

set client_encoding = 'UTF8';

begin;

CREATE OR REPLACE FUNCTION private.beautyos_reabrir_sede(p_branch_id uuid, p_estado text, p_quien text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
declare
  v_tenant_id uuid;
  v_nombre text;
  v_activa boolean;
  v_ts uuid;
  v_antes text;
  v_estado text;
begin
  if p_estado not in ('pending', 'active') then
    raise exception 'Estado invalido para reabrir: %.', coalesce(p_estado, 'null');
  end if;

  select b.tenant_id, b.name, b.active
    into v_tenant_id, v_nombre, v_activa
  from public.branches b
  where b.id = p_branch_id
  for update;

  if not found then
    raise exception 'La sede no existe.';
  end if;

  if v_activa then
    raise exception 'Esa sede no está cerrada.';
  end if;

  -- D-329: vuelve COMO ESTABA al cerrarse. El estado de antes lo guardó el
  -- último rastro `sede_cerrada` de esta sede. Si no se sabe (una sede
  -- cerrada sin ese rastro, o que ya estaba `cancelled`), vale `p_estado`:
  -- pendiente si la reabre el dueño, activa si la reabre la plataforma.
  select e.payload ->> 'estado_anterior' into v_antes
  from public.subscription_events e
  where e.tenant_id = v_tenant_id
    and e.event_type = 'sede_cerrada'
    and e.payload ->> 'branch_id' = p_branch_id::text
  order by e.created_at desc
  limit 1;

  v_estado := case
    when v_antes in ('pending', 'trialing', 'active', 'past_due', 'grace', 'suspended') then v_antes
    else p_estado
  end;

  update public.branches
     set active = true
   where id = p_branch_id;

  update public.branch_subscriptions
     set status = v_estado,
         activated_at = case
           when v_estado = 'active' then coalesce(activated_at, now())
           else activated_at
         end,
         updated_at = now()
   where branch_id = p_branch_id;

  if not found then
    raise exception 'La sede no tiene suscripcion registrada.';
  end if;

  select ts.id into v_ts
  from public.tenant_subscriptions ts
  where ts.tenant_id = v_tenant_id;

  if v_ts is null then
    raise exception 'El negocio de esta sede no tiene suscripcion registrada.';
  end if;

  insert into public.subscription_events (
    tenant_id, tenant_subscription_id, event_type, provider, payload, created_by
  ) values (
    v_tenant_id, v_ts, 'sede_reabierta', p_quien,
    jsonb_build_object(
      'branch_id', p_branch_id, 'sede', v_nombre,
      'estado_nuevo', v_estado, 'estado_al_cerrar', v_antes
    ),
    auth.uid()
  );
end;
$function$;

revoke all on function private.beautyos_reabrir_sede(uuid, text, text) from public, anon, authenticated;

commit;
