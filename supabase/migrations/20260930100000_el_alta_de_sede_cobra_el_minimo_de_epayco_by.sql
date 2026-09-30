-- ==============================================================================
-- HALLAZGO BY: el alta de una sede cobra al menos el minimo de ePayco ($5.000)
-- Decision del propietario del 30-sep (D-296).
-- ==============================================================================
--
-- QUE PASABA
--
-- `beautyos_calcular_cargo_sede` cobra el alta de una sede nueva solo por los
-- dias que faltan hasta la fecha de corte del negocio (precio x dias / 30,
-- motivo `alta_de_sede_prorrateada`). A pocos dias del corte eso podia dar
-- menos de $5.000, y ePayco lo rechaza: "[VALIDATION_ERROR] - property Amount
-- must be between 5000 and 5000000". Visto el 30-sep con "Barberia Barber
-- Elite": $10.000 al mes, 9 dias, $3.000. La sede no se podia activar.
--
-- QUE CAMBIA, Y QUE NO
--
--   1. Nace `private.beautyos_cobro_minimo_pasarela_cop()` = 5000, el minimo de
--      ePayco en un solo sitio (mismo patron que `beautyos_cobro_minimo_cop`,
--      D-265).
--   2. `beautyos_calcular_cargo_sede`, generada desde su texto vivo, cambia
--      UNA linea: el alta prorrateada cobra `greatest(prorrateo, 5000)`.
--      Los demas motivos ya cobran el mes completo, que tiene su propio minimo
--      de $10.000 (D-265): no se tocan.
--
-- `beautyos_procesar_pago_de_sede` NO se toca. Su texto vivo (leido el 30-sep)
-- exige, para un alta prorrateada, exactamente lo que calcula esta funcion: un
-- pago de $5.000 activa la sede sin mas cambios. El control 236 lo recorre.
--
-- La sede sigue pagada solo hasta la fecha de corte del negocio; el salon paga
-- como mucho unos pesos de mas, una sola vez.
--
-- COMO SE APLICA (lo aplica el propietario, regla 16)
--
--   1. Esta migracion con scripts\aplicar_sql.ps1
--   2. El control: supabase\sql\236_test_el_alta_de_sede_cobra_el_minimo_de_epayco_by.sql
--   3. En pantalla (regla 21): Configuracion -> Tus sedes -> Activar esta sede
--      en "Barberia Barber Elite". ePayco debe abrir con $5.000. NO PAGAR:
--      cerrar la ventana.
-- ==============================================================================

set client_encoding = 'UTF8';

begin;

-- ---------------------------------------------------------------------------
-- 1. El minimo de la pasarela, en un solo sitio
-- ---------------------------------------------------------------------------

create or replace function private.beautyos_cobro_minimo_pasarela_cop()
returns bigint
language sql
immutable
set search_path = pg_catalog
as $$
  -- El minimo que acepta ePayco por cobro. Lo dijo su propia respuesta el
  -- 30-sep: "Amount must be between 5000 and 5000000". Si ePayco lo cambia,
  -- se cambia aqui y solo aqui (hallazgo BY, D-296).
  select 5000::bigint;
$$;

revoke all on function private.beautyos_cobro_minimo_pasarela_cop() from public, anon;
grant execute on function private.beautyos_cobro_minimo_pasarela_cop() to authenticated, service_role;

comment on function private.beautyos_cobro_minimo_pasarela_cop() is
  'BY, D-296: el minimo que acepta ePayco por cobro, en pesos. El alta prorrateada de una sede '
  'no cobra menos que esto. NO ELIMINAR.';

-- ---------------------------------------------------------------------------
-- 2. El calculo: una linea, generada desde el texto vivo
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
      -- BY (30-sep): ePayco no acepta cobros de menos de $5.000, y un alta a
      -- pocos dias del corte podia dar menos (una sede de $10.000 a 9 dias
      -- daba $3.000): la sede no se podia activar. El propietario decidio
      -- cobrar el minimo de la pasarela en ese caso.
      monto_cop := greatest(
        ceil(v_precio * v_dias / 30.0),
        private.beautyos_cobro_minimo_pasarela_cop()
      );
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

commit;
