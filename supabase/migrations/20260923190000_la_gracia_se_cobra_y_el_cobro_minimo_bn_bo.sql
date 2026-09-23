-- ==============================================================================
-- HALLAZGOS BN y BO: la gracia se cobra entera, y el cobro minimo es $10.000
-- Decisiones del propietario del 23-sep (D-264, D-265).
-- ==============================================================================
--
-- BN — PAGAR EN LA GRACIA SALIA MAS BARATO
--
-- `beautyos_calcular_cargo_sede` cobraba, a una sede que pagaba dentro de sus
-- 5 dias de gracia, solo los dias que faltaban hasta el corte (D-160, regla
-- 3). La fecha de corte no se corria -- bien --, pero el precio si bajaba: los
-- dias de gracia se usaban y no se pagaban. El propietario: *"cobra el mes
-- completo aunque paguen en la gracia"*. Ahora: mes completo, misma fecha de
-- corte, y el motivo pasa a llamarse `pago_tardio_en_gracia`, porque ya no
-- prorratea. El que lo usaba en `beautyos_procesar_pago_de_sede` era para
-- eximirlo del minimo; cobrando el mes completo ya no hace falta, y esa
-- funcion NO se toca.
--
-- El cobro DEL NEGOCIO (`beautyos_calcular_cargo_epayco`) no se toca: su
-- entrada esta cerrada desde D-252 y lo que queda solo liquida rezagados.
--
-- BO — UN MINIMO QUE DEJABA SIN ACTIVAR UNA SEDE BARATA
--
-- `beautyos_procesar_pago_de_sede` exige `greatest(10000, monto)` a todo cobro
-- que no sea prorrateado. Viene del 23-ago (D-159), como *"red de seguridad
-- adicional"* del cobro del negocio. La sede de la Peluqueria Exito estaba
-- pactada en $4.500: su pago real del paso 9.8 se habria cobrado en ePayco y
-- la sede NO se habria activado.
--
-- El propietario decidio que el minimo se queda: *"el cobro minimo es de
-- 10000; no tengo problema en cambiarle a Peluqueria Exito de 4500 a 10000"*.
-- Asi que el arreglo no es quitar el minimo sino **impedir pactar por debajo**:
--
--   1. La sede de Exito pasa a $10.000, con su motivo y su evento.
--   2. Un disparador en `branch_subscriptions` rechaza cualquier precio por
--      debajo del minimo, **venga por la puerta que venga** -- aprobar un
--      negocio, pactar una sede, o la que se escriba manana --. Es la leccion
--      de D-252: se arregla una puerta y se olvida la otra.
--
-- COMO SE APLICA (lo aplica el propietario, regla 16)
--
--   1. Esta migracion con scripts\aplicar_sql.ps1
--   2. El control: supabase\sql\226_test_la_gracia_se_cobra_y_el_minimo.sql
-- ==============================================================================

set client_encoding = 'UTF8';

begin;

-- ---------------------------------------------------------------------------
-- 1. BN: el calculo del cargo de una sede (texto vivo + el cambio de arriba)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION private.beautyos_calcular_cargo_sede(p_branch_id uuid)
 RETURNS TABLE(monto_cop bigint, periodo_inicio timestamp with time zone, periodo_fin timestamp with time zone, motivo text, tenant_id_resuelto uuid)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_bs public.branch_subscriptions%rowtype;
  v_ancla timestamptz;
  v_precio bigint;
  v_dias numeric;
begin
  select * into v_bs
  from public.branch_subscriptions
  where branch_id = p_branch_id;

  if not found then
    return;
  end if;

  select precio_cop into v_precio
  from private.beautyos_precio_efectivo_sede(p_branch_id);

  if v_precio is null or v_precio <= 0 then
    return;
  end if;

  tenant_id_resuelto := v_bs.tenant_id;

  -- La fecha de corte del NEGOCIO. Un salon, una fecha de cobro.
  select ts.current_period_end into v_ancla
  from public.tenant_subscriptions ts
  where ts.tenant_id = v_bs.tenant_id;

  if v_bs.current_period_end is null then
    -- La sede nunca se ha pagado.
    if v_ancla is not null and v_ancla > now() then
      -- Se engancha al ciclo que el negocio ya tiene: solo lo que falta.
      -- Misma formula que el pago tardio de D-160.
      periodo_inicio := now();
      periodo_fin := v_ancla;
      v_dias := ceil(extract(epoch from (v_ancla - now())) / 86400.0);
      monto_cop := ceil(v_precio * v_dias / 30.0);
      motivo := 'alta_de_sede_prorrateada';
    else
      -- El negocio no tiene ciclo vivo: esta sede lo estrena.
      periodo_inicio := now();
      periodo_fin := now() + interval '30 days';
      monto_cop := v_precio;
      motivo := 'alta_de_sede_primer_ciclo';
    end if;

  elsif now() <= v_bs.current_period_end then
    -- Renovacion anticipada: se acumula al final, la ancla no se corre.
    periodo_inicio := v_bs.current_period_end;
    periodo_fin := v_bs.current_period_end + interval '30 days';
    monto_cop := v_precio;
    motivo := 'renovacion_anticipada';

  elsif v_bs.status in ('past_due', 'grace') then
    -- Pago tardio dentro de gracia: MES COMPLETO, y la ancla no se corre
    -- (D-265, hallazgo BN). Hasta el 23-sep se cobraba solo lo que faltaba
    -- hasta el corte (D-160, regla 3), asi que los dias de gracia se usaban
    -- y no se pagaban: pagar el quinto dia salia mas barato. El propietario:
    -- "cobra el mes completo aunque paguen en la gracia".
    periodo_fin := v_bs.current_period_end + interval '30 days';
    periodo_inicio := now();
    monto_cop := v_precio;
    motivo := 'pago_tardio_en_gracia';

  else
    -- Suspendida, o vencida por otra via: mes completo y se reancla.
    periodo_inicio := now();
    periodo_fin := now() + interval '30 days';
    monto_cop := v_precio;
    motivo := 'reactivacion_post_suspension';
  end if;

  return next;
end;
$function$;

-- ---------------------------------------------------------------------------
-- 2. BO: el cobro minimo, en un solo sitio
-- ---------------------------------------------------------------------------

create or replace function private.beautyos_cobro_minimo_cop()
returns bigint
language sql
immutable
set search_path = pg_catalog
as $$
  -- Decidido por el propietario el 23-sep (D-265). Es el mismo numero que
  -- `beautyos_procesar_pago_de_sede` exige desde D-159; si cambia, cambian
  -- los dos.
  select 10000::bigint;
$$;

revoke all on function private.beautyos_cobro_minimo_cop() from public, anon;
grant execute on function private.beautyos_cobro_minimo_cop() to authenticated, service_role;

comment on function private.beautyos_cobro_minimo_cop() is
  'D-265: el cobro minimo de una sede, en pesos. Lo mismo que exige beautyos_procesar_pago_de_sede '
  '(greatest(10000, monto), D-159). NO ELIMINAR.';

-- ---------------------------------------------------------------------------
-- 3. BO: la sede de Exito sube a $10.000, antes de poner el candado
-- ---------------------------------------------------------------------------
--
-- Solo se toca la sede que el propietario nombro. Si aparece otra por debajo
-- del minimo, se para: esa no la decidio nadie.

do $exito$
declare
  v_cuantas integer;
  v_bs record;
  v_ts uuid;
begin
  select count(*) into v_cuantas
  from public.branch_subscriptions bs
  where bs.price_cop is not null
    and bs.price_cop < private.beautyos_cobro_minimo_cop();

  if v_cuantas = 0 then
    raise notice 'BO: ninguna sede por debajo del minimo. Nada que subir.';
    return;
  end if;

  select bs.branch_id, bs.tenant_id, bs.price_cop, bs.price_reason, t.name as negocio
    into v_bs
  from public.branch_subscriptions bs
  join public.tenants t on t.id = bs.tenant_id
  where bs.price_cop is not null
    and bs.price_cop < private.beautyos_cobro_minimo_cop();

  if v_cuantas > 1 or v_bs.negocio <> 'Peluquería Éxito Prueba' then
    raise exception 'PARADA: hay % sede(s) por debajo del minimo y el propietario solo autorizo subir la de la Peluqueria Exito. No se toco nada.', v_cuantas;
  end if;

  update public.branch_subscriptions
  set price_cop = private.beautyos_cobro_minimo_cop(),
      price_reason = 'Precio de prueba del propietario para el paso 9.8. Subido de $4.500 a $10.000 el 23-sep: el cobro mínimo de una sede es $10.000 (D-265, hallazgo BO).',
      updated_at = now()
  where branch_id = v_bs.branch_id;

  -- Que quede escrito que cambio, y de cuanto a cuanto.
  select ts.id into v_ts from public.tenant_subscriptions ts where ts.tenant_id = v_bs.tenant_id;
  insert into public.subscription_events (
    tenant_id, tenant_subscription_id, event_type, provider, provider_event_id, payload
  ) values (
    v_bs.tenant_id, v_ts, 'precio_de_sede_al_minimo', 'system',
    'bo_minimo_' || v_bs.branch_id,
    jsonb_build_object(
      'branch_id', v_bs.branch_id,
      'precio_anterior', v_bs.price_cop,
      'motivo_anterior', v_bs.price_reason,
      'precio_nuevo', private.beautyos_cobro_minimo_cop(),
      'decision', 'D-265'
    )
  );

  raise notice 'BO: la sede de % pasa de $% a $10.000.', v_bs.negocio, v_bs.price_cop;
end
$exito$;

-- ---------------------------------------------------------------------------
-- 4. BO: nadie pacta por debajo del minimo, por ninguna puerta
-- ---------------------------------------------------------------------------

create or replace function private.beautyos_precio_de_sede_no_baja_del_minimo()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if new.price_cop is not null and new.price_cop < private.beautyos_cobro_minimo_cop() then
    raise exception 'El precio de una sede no puede ser menor de $10.000, que es el cobro mínimo. Déjalo vacío para usar la tarifa de lista.'
      using errcode = '22023';
  end if;
  return new;
end;
$$;

revoke all on function private.beautyos_precio_de_sede_no_baja_del_minimo() from public, anon, authenticated;

drop trigger if exists branch_subscriptions_precio_minimo on public.branch_subscriptions;
create trigger branch_subscriptions_precio_minimo
  before insert or update of price_cop on public.branch_subscriptions
  for each row execute function private.beautyos_precio_de_sede_no_baja_del_minimo();

comment on function private.beautyos_precio_de_sede_no_baja_del_minimo() is
  'D-265 (hallazgo BO): ninguna sede se pacta por debajo del cobro minimo, porque su pago no la activaria. '
  'Disparador y no funcion de precio, para que valga por todas las puertas. NO ELIMINAR.';

commit;
