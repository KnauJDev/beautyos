-- ==============================================================================
-- HALLAZGO BI (parte del servidor): vencer sin pagar pasa a mora, con su gracia
-- ==============================================================================
--
-- QUE PASABA
--
-- Solo un pago **rechazado** por ePayco pasaba una suscripcion de `active` a
-- `past_due` (`beautyos_procesar_evento_epayco`). Aqui el pago es **manual
-- cada mes**: quien simplemente no paga no produce ningun rechazo. Y el
-- vigilante diario (`beautyos_suspender_suscripciones_vencidas`, 17-ago) solo
-- suspende lo que YA esta en `past_due`/`grace`: no mira fechas, ni sedes.
--
-- Resultado, comprobado en pantalla por el propietario el 23-sep con Naguara:
--
--   * la suscripcion seguia `active` con el periodo vencido el 22-sep;
--   * `beautyos_tenant_accepts_new_commitments` —que SI mira la fecha— ya
--     negaba las citas nuevas, **sin los 5 dias de gracia** de D-141;
--   * y una sede que no paga se quedaba `active` para siempre.
--
-- QUE HACE ESTA MIGRACION
--
-- **No reescribe ninguna funcion existente** (regla 10: reescribir exige
-- extraer el texto vivo y compararlo linea por linea). Anade una sola, nueva,
-- que hace el paso que faltaba —de `active` a `past_due` por FECHA—, y la
-- programa cada dia **antes** del vigilante que ya existe. Desde ahi la
-- maquinaria de D-141 funciona sola: gracia de 5 dias, avisos y suspension.
--
--   1. Negocio `active` con el periodo vencido -> `past_due`, con
--      `grace_ends_at = current_period_end + 5 dias`.
--   2. Sede `active` con el periodo vencido -> lo mismo.
--   3. Sede `past_due`/`grace` con la gracia vencida -> `suspended`. El
--      vigilante del 17-ago solo suspende negocios, porque es anterior a las
--      sedes (D-190).
--
-- Cada paso deja su fila en `subscription_events`, como el vigilante.
--
-- LO QUE NO HACE, a proposito
--
--   * **No cambia el mensaje del candado** (*"La prueba gratis de este negocio
--     esta vencida"*), que vive dentro de `create_scheduled_ticket_with_service_v2`
--     y `public_create_booking`. Tocarlo es reescribirlas: va aparte, con su
--     extraccion. Con esta migracion ese mensaje deja de salir durante la
--     gracia, que es cuando mas mentia.
--   * **No corta la operacion de una sede secundaria.** El acceso sigue siendo
--     del negocio (ADR-006). Que una sede sin pagar deje de agendar es una
--     decision de producto del propietario, no un arreglo.
--
-- COMO SE APLICA (lo aplica el propietario, regla 16)
--
--   1. Respaldo:   scripts\respaldo_supabase.ps1
--   2. Esta migracion con scripts\aplicar_sql.ps1
--   3. El control: supabase\sql\222_test_vencer_sin_pagar_pasa_a_mora.sql
--
-- AL APLICARSE SE CORRE UNA VEZ (paso 5): lo que ya vencio no espera a
-- manana. Hoy son tres negocios, los tres de prueba (MAPA_TECNICO §1-bis).
-- ==============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 0. Antes de nada: que las columnas sean las que este archivo cree
-- ---------------------------------------------------------------------------
--
-- El repositorio no es la fuente del esquema (hallazgo AI). Si alguna columna
-- no existe con este nombre, se para aqui y no a medias.

do $comprobar$
declare
  v_falta text;
begin
  select string_agg(esperada.tabla || '.' || esperada.columna, ', ')
    into v_falta
  from (values
    ('tenant_subscriptions', 'status'),
    ('tenant_subscriptions', 'current_period_end'),
    ('tenant_subscriptions', 'grace_ends_at'),
    ('tenant_subscriptions', 'updated_at'),
    ('branch_subscriptions', 'status'),
    ('branch_subscriptions', 'current_period_end'),
    ('branch_subscriptions', 'grace_ends_at'),
    ('branch_subscriptions', 'updated_at'),
    ('branch_subscriptions', 'branch_id'),
    ('branch_subscriptions', 'tenant_id'),
    ('subscription_events', 'tenant_subscription_id'),
    ('subscription_events', 'provider_event_id')
  ) as esperada(tabla, columna)
  where not exists (
    select 1 from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = esperada.tabla
      and c.column_name = esperada.columna
  );

  if v_falta is not null then
    raise exception 'PARADA: faltan columnas que esta migracion necesita: %. No se toco nada.', v_falta;
  end if;
end
$comprobar$;

-- ---------------------------------------------------------------------------
-- 1. El paso que faltaba
-- ---------------------------------------------------------------------------

create or replace function private.beautyos_pasar_a_mora_por_fecha()
returns table (
  negocios_en_mora integer,
  sedes_en_mora integer,
  sedes_suspendidas integer
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  -- Los mismos 5 dias de D-141, que es lo que ya mira
  -- `beautyos_tenant_accepts_new_commitments` en `past_due`/`grace`.
  c_gracia constant interval := interval '5 days';
  v_negocios integer := 0;
  v_sedes integer := 0;
  v_suspendidas integer := 0;
  v_hoy text := to_char(now(), 'YYYYMMDD');
  v_row record;
begin
  -- 1. Negocios: activos con el periodo vencido
  for v_row in
    update public.tenant_subscriptions ts
    set status = 'past_due',
        grace_ends_at = ts.current_period_end + c_gracia,
        updated_at = now()
    where ts.status = 'active'
      and ts.current_period_end is not null
      and ts.current_period_end < now()
    returning ts.id, ts.tenant_id, ts.current_period_end, ts.grace_ends_at
  loop
    v_negocios := v_negocios + 1;

    insert into public.subscription_events (
      tenant_id, tenant_subscription_id, event_type, provider, provider_event_id, payload
    ) values (
      v_row.tenant_id,
      v_row.id,
      'auto_past_due_period_expired',
      'system',
      'mora_negocio_' || v_row.id || '_' || v_hoy,
      jsonb_build_object(
        'motivo', 'Periodo vencido sin pago registrado (hallazgo BI)',
        'periodo_vencio', v_row.current_period_end,
        'gracia_hasta', v_row.grace_ends_at
      )
    );
  end loop;

  -- 2. Sedes: activas con el periodo vencido
  for v_row in
    update public.branch_subscriptions bs
    set status = 'past_due',
        grace_ends_at = bs.current_period_end + c_gracia,
        updated_at = now()
    where bs.status = 'active'
      and bs.current_period_end is not null
      and bs.current_period_end < now()
    returning bs.tenant_id, bs.branch_id, bs.current_period_end, bs.grace_ends_at
  loop
    v_sedes := v_sedes + 1;

    insert into public.subscription_events (
      tenant_id, tenant_subscription_id, event_type, provider, provider_event_id, payload
    )
    select v_row.tenant_id, ts.id,
      'auto_past_due_sede_period_expired',
      'system',
      'mora_sede_' || v_row.branch_id || '_' || v_hoy,
      jsonb_build_object(
        'motivo', 'Periodo de la sede vencido sin pago registrado (hallazgo BI)',
        'branch_id', v_row.branch_id,
        'periodo_vencio', v_row.current_period_end,
        'gracia_hasta', v_row.grace_ends_at
      )
    from public.tenant_subscriptions ts
    where ts.tenant_id = v_row.tenant_id
    on conflict do nothing;
  end loop;

  -- 3. Sedes: gracia vencida -> suspendida. Lo mismo que el vigilante del
  -- 17-ago hace con los negocios, y que no hace con las sedes porque es
  -- anterior a ellas.
  for v_row in
    update public.branch_subscriptions bs
    set status = 'suspended',
        updated_at = now()
    where bs.status in ('past_due', 'grace')
      and bs.grace_ends_at is not null
      and bs.grace_ends_at < now()
    returning bs.tenant_id, bs.branch_id, bs.grace_ends_at
  loop
    v_suspendidas := v_suspendidas + 1;

    insert into public.subscription_events (
      tenant_id, tenant_subscription_id, event_type, provider, provider_event_id, payload
    )
    select v_row.tenant_id, ts.id,
      'auto_suspended_sede_grace_expired',
      'system',
      'suspension_sede_' || v_row.branch_id || '_' || v_hoy,
      jsonb_build_object(
        'motivo', 'Gracia de 5 dias de la sede vencida sin pago (hallazgo BI)',
        'branch_id', v_row.branch_id,
        'gracia_vencio', v_row.grace_ends_at
      )
    from public.tenant_subscriptions ts
    where ts.tenant_id = v_row.tenant_id
    on conflict do nothing;
  end loop;

  return query select v_negocios, v_sedes, v_suspendidas;
end;
$$;

revoke all on function private.beautyos_pasar_a_mora_por_fecha() from public, anon, authenticated;
grant execute on function private.beautyos_pasar_a_mora_por_fecha() to service_role;

comment on function private.beautyos_pasar_a_mora_por_fecha() is
  'Hallazgo BI (23-sep): pasa a past_due, con 5 dias de gracia, a negocios y sedes activos cuyo periodo vencio, '
  'y suspende las sedes con la gracia vencida. Antes solo un pago RECHAZADO ponia past_due, y el pago aqui es '
  'manual: quien no pagaba se quedaba active para siempre. Corre cada dia antes del vigilante de D-141. NO ELIMINAR.';

-- ---------------------------------------------------------------------------
-- 2. Cada dia, antes del vigilante
-- ---------------------------------------------------------------------------
--
-- 12:50 UTC = 07:50 en Colombia, diez minutos antes de la tarea de las 08:00
-- (`avisos_vencimiento_suscripcion_diario`), que suspende y manda los avisos.
-- Asi los avisos de ese dia ya ven la mora de ese dia.
--
-- SQL directo y no una Edge Function: no hay nada que mandar, solo cambiar
-- estados, y asi no depende de ningun secreto ni de ningun despliegue.

do $programar$
begin
  if exists (select 1 from cron.job where jobname = 'mora_por_fecha_diario') then
    perform cron.unschedule('mora_por_fecha_diario');
  end if;
end
$programar$;

select cron.schedule(
  'mora_por_fecha_diario',
  '50 12 * * *',
  $cron$ select * from private.beautyos_pasar_a_mora_por_fecha(); $cron$
);

-- ---------------------------------------------------------------------------
-- 3. Lo que ya vencio no espera a manana
-- ---------------------------------------------------------------------------

do $primera_vez$
declare
  v record;
begin
  select * into v from private.beautyos_pasar_a_mora_por_fecha();
  raise notice 'Primera pasada: % negocio(s) a mora, % sede(s) a mora, % sede(s) suspendida(s).',
    v.negocios_en_mora, v.sedes_en_mora, v.sedes_suspendidas;
end
$primera_vez$;

commit;
