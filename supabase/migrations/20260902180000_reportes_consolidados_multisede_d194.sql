-- BeautyOS / Salón y Más — Reportes consolidados de todas las sedes (D-194)
--
-- QUÉ RESUELVE
--
-- Un dueño con dos locales no tenía forma de ver su negocio entero: tenía que
-- mirar una sede, apuntar, cambiar de sede en el selector y sumar a mano. Ahora
-- puede pedir el consolidado.
--
-- POR QUÉ ES UNA FUNCIÓN QUE LLAMA A LA OTRA, Y NO UNA COPIA CON `in (...)`
--
-- Lo cómodo habría sido duplicar `get_branch_reports_v3` cambiando
-- `branch_id = p_branch_id` por `branch_id = any(...)`. Serían **250 líneas
-- duplicadas** con las mismas seis subconsultas de ventas, compras, gastos,
-- comisiones, arqueo y comparación con el período anterior — y el día que
-- alguien corrija un criterio en una, la otra se queda atrás y **los dos
-- números dejan de cuadrar sin que nadie se entere**. Es exactamente lo que
-- pasó con las siete copias de `_formatCop` (TL-12) y con los seis sitios donde
-- estaban escritas las reglas de trabajo (D-131).
--
-- Así que esta llama a la de siempre, sede por sede, y suma. La lógica de qué
-- es una venta y qué es un egreso vive **en un solo sitio**, y de paso el
-- desglose por sede sale gratis: ya se calculó cada una por separado.
--
-- El costo es una consulta por sede en vez de una sola. Con dos o tres locales
-- —que es de lo que se está hablando— no se nota. El día que un salón tenga
-- veinte, esto se reescribe con su medición delante.
--
-- QUIÉN PUEDE PEDIRLO
--
-- Solo `tenant_owner` y `admin`, y **cada uno ve exactamente las sedes que ya
-- podía ver**: se recorre `get_my_branch_context_v2()`, que es la misma función
-- que alimenta el selector de sedes del encabezado. Un `admin` asignado a una
-- sola sede recibe el "consolidado" de esa sede, no del negocio entero.
--
-- Eso no es una limitación: es lo correcto. Y conviene tenerlo escrito, porque
-- **solo el `tenant_owner` ve todas las sedes sin que nadie se las asigne**
-- (`beautyos_resolve_branch_access` lo exceptúa por rol); el `admin` necesita su
-- fila en `branch_memberships`, que es lo que D-179 dejó gestionable desde
-- Usuarios.
--
-- **El estado de pago de una sede NO influye aquí.** Una sede en mora sigue
-- apareciendo en el consolidado: sus ventas ocurrieron. Cobrar y reportar son
-- dos cosas distintas.

begin;

create or replace function public.get_tenant_reports_v3(
  p_start_date date,
  p_end_date date
)
returns table (
  start_date date,
  end_date date,
  total_received numeric,
  payments_count integer,
  paid_tickets_count integer,
  cash_received numeric,
  card_received numeric,
  transfer_received numeric,
  other_received numeric,
  total_purchases numeric,
  cash_purchases numeric,
  total_expenses numeric,
  cash_expenses numeric,
  total_commissions numeric,
  commission_services_count integer,
  expected_cash numeric,
  net_result numeric,
  prev_total_received numeric,
  prev_net_result numeric,
  prev_payments_count integer,
  commissions_by_stylist jsonb,
  sales_by_service jsonb,
  branches_count integer,
  by_branch jsonb
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_sede record;
  v_r record;
  v_comisiones jsonb := '[]'::jsonb;
  v_servicios jsonb := '[]'::jsonb;
  v_por_sede jsonb := '[]'::jsonb;
  v_sedes integer := 0;
begin
  if p_start_date is null or p_end_date is null then
    raise exception 'Las fechas de inicio y fin son obligatorias.';
  end if;

  if p_end_date < p_start_date then
    raise exception 'La fecha de fin no puede ser anterior a la fecha de inicio.';
  end if;

  start_date := p_start_date;
  end_date := p_end_date;

  total_received := 0;
  payments_count := 0;
  paid_tickets_count := 0;
  cash_received := 0;
  card_received := 0;
  transfer_received := 0;
  other_received := 0;
  total_purchases := 0;
  cash_purchases := 0;
  total_expenses := 0;
  cash_expenses := 0;
  total_commissions := 0;
  commission_services_count := 0;
  expected_cash := 0;
  net_result := 0;
  prev_total_received := 0;
  prev_net_result := 0;
  prev_payments_count := 0;

  for v_sede in
    select c.branch_id, c.branch_name, c.role, c.is_primary
    from public.get_my_branch_context_v2() c
    order by c.is_primary desc, c.branch_name
  loop
    -- Solo las sedes donde manda. Un estilista o un asistente no consolida
    -- nada: la funcion de una sola sede ya los rechaza, y aqui se saltan antes
    -- de que reviente.
    if v_sede.role not in ('tenant_owner', 'admin') then
      continue;
    end if;

    select * into v_r
    from public.get_branch_reports_v3(v_sede.branch_id, p_start_date, p_end_date);

    if v_r is null then
      continue;
    end if;

    v_sedes := v_sedes + 1;

    total_received := total_received + coalesce(v_r.total_received, 0);
    payments_count := payments_count + coalesce(v_r.payments_count, 0);
    paid_tickets_count := paid_tickets_count + coalesce(v_r.paid_tickets_count, 0);
    cash_received := cash_received + coalesce(v_r.cash_received, 0);
    card_received := card_received + coalesce(v_r.card_received, 0);
    transfer_received := transfer_received + coalesce(v_r.transfer_received, 0);
    other_received := other_received + coalesce(v_r.other_received, 0);
    total_purchases := total_purchases + coalesce(v_r.total_purchases, 0);
    cash_purchases := cash_purchases + coalesce(v_r.cash_purchases, 0);
    total_expenses := total_expenses + coalesce(v_r.total_expenses, 0);
    cash_expenses := cash_expenses + coalesce(v_r.cash_expenses, 0);
    total_commissions := total_commissions + coalesce(v_r.total_commissions, 0);
    commission_services_count :=
      commission_services_count + coalesce(v_r.commission_services_count, 0);
    expected_cash := expected_cash + coalesce(v_r.expected_cash, 0);
    net_result := net_result + coalesce(v_r.net_result, 0);
    prev_total_received := prev_total_received + coalesce(v_r.prev_total_received, 0);
    prev_net_result := prev_net_result + coalesce(v_r.prev_net_result, 0);
    prev_payments_count := prev_payments_count + coalesce(v_r.prev_payments_count, 0);

    v_comisiones := v_comisiones || coalesce(v_r.commissions_by_stylist, '[]'::jsonb);
    v_servicios := v_servicios || coalesce(v_r.sales_by_service, '[]'::jsonb);

    -- El desglose por sede sale gratis: ya se calculo cada una por separado.
    v_por_sede := v_por_sede || jsonb_build_array(
      jsonb_build_object(
        'branch_id', v_sede.branch_id,
        'branch_name', v_sede.branch_name,
        'is_primary', v_sede.is_primary,
        'total_received', coalesce(v_r.total_received, 0),
        'net_result', coalesce(v_r.net_result, 0),
        'total_expenses', coalesce(v_r.total_expenses, 0),
        'total_purchases', coalesce(v_r.total_purchases, 0),
        'total_commissions', coalesce(v_r.total_commissions, 0),
        'expected_cash', coalesce(v_r.expected_cash, 0),
        'payments_count', coalesce(v_r.payments_count, 0)
      )
    );
  end loop;

  if v_sedes = 0 then
    raise exception 'No autorizado. Solo owner o admin consulta reportes, y de las sedes que tiene asignadas.';
  end if;

  branches_count := v_sedes;
  by_branch := v_por_sede;

  -- Una misma estilista puede trabajar en dos sedes: se agrupa por nombre para
  -- que el consolidado diga cuanto se llevo EN TOTAL, no dos veces la mitad.
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'stylist_name', x.nombre,
        'services_count', x.cnt,
        'service_sales', x.ventas,
        'commission_total', x.comision
      )
      order by x.comision desc, x.nombre
    ),
    '[]'::jsonb
  )
  into commissions_by_stylist
  from (
    select
      e ->> 'stylist_name' as nombre,
      sum(coalesce((e ->> 'services_count')::integer, 0)) as cnt,
      sum(coalesce((e ->> 'service_sales')::numeric, 0)) as ventas,
      sum(coalesce((e ->> 'commission_total')::numeric, 0)) as comision
    from jsonb_array_elements(v_comisiones) e
    group by e ->> 'stylist_name'
  ) x;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'service_name', y.servicio,
        'stylist_name', y.estilista,
        'tickets_count', y.cnt,
        'total_sales', y.ventas,
        'total_duration_minutes', y.minutos
      )
      order by y.ventas desc, y.servicio
    ),
    '[]'::jsonb
  )
  into sales_by_service
  from (
    select
      e ->> 'service_name' as servicio,
      e ->> 'stylist_name' as estilista,
      sum(coalesce((e ->> 'tickets_count')::integer, 0)) as cnt,
      sum(coalesce((e ->> 'total_sales')::numeric, 0)) as ventas,
      sum(coalesce((e ->> 'total_duration_minutes')::integer, 0)) as minutos
    from jsonb_array_elements(v_servicios) e
    group by e ->> 'service_name', e ->> 'stylist_name'
  ) y;

  return next;
end;
$$;

comment on function public.get_tenant_reports_v3(date, date) is
  'Reporte consolidado de TODAS las sedes que el usuario puede ver (D-194). Llama a get_branch_reports_v3 sede '
  'por sede y suma, en vez de duplicar sus 250 lineas: la logica de que es una venta vive en un solo sitio, y el '
  'desglose por sede sale gratis. Un admin recibe el consolidado de SUS sedes, no del negocio entero. '
  'El estado de pago de una sede no influye: sus ventas ocurrieron. NO ELIMINAR.';

revoke all on function public.get_tenant_reports_v3(date, date) from public, anon;
grant execute on function public.get_tenant_reports_v3(date, date) to authenticated;

commit;
