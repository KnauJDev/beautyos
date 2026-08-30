-- BeautyOS - Paso 8.2 (H-08): unifica la regla de dinero en pesos enteros.
--
-- POR QUÉ
--
-- Colombia opera en pesos enteros, sin centavos (D-055, ratificado en
-- D-121 y D-136). La mayoría de funciones que calculan dinero ya
-- redondean con `round(x)` sin decimales -- confirmado en
-- `create_purchase`/`void_purchase` (costo promedio ponderado),
-- `beautyos_precio_efectivo`, `beautyos_calcular_cargo_epayco` y el hook
-- de comisión de partners (D-173). Pero se encontró UNA excepción real:
-- `private.beautyos_close_ticket_if_fully_paid` calcula la comisión
-- porcentual del estilista con `round(x, 2)`, dejando pasar centavos que
-- ninguna otra parte del sistema produce. Es el descuadre invisible que
-- describe H-08.
--
-- Se corrige la única función con el bug (sin tocar una sola línea más de
-- su cuerpo, regla 8.10) y se blinda la invariante con un `CHECK` en cada
-- columna de dinero verificada contra el código real -- no contra tipos:
-- `numeric`/`numeric(12,2)` se conservan tal cual, no se migra ningún tipo
-- de columna (ver conversación previa: alterar tipos es el camino caro y
-- arriesgado para un problema que se resuelve con disciplina de escritura
-- reforzada por un candado en la base).
--
-- Los `CHECK` se agregan con `NOT VALID` a propósito: protegen cada
-- INSERT/UPDATE nuevo de inmediato, sin escanear ni bloquear la tabla por
-- filas históricas que todavía no se han revisado. El control
-- `194_test_regla_dinero_entero_h08.sql` reporta si existe alguna fila
-- vieja que hoy violaría la regla; si el conteo da cero en todas, un
-- `ALTER TABLE ... VALIDATE CONSTRAINT` posterior las deja completamente
-- selladas (paso manual, no incluido aquí a propósito).
--
-- QUEDA FUERA A PROPÓSITO (no son columnas de dinero en pesos):
--   - `commission_percentage`, `discount_percent`, `partners.commission_value`
--     cuando es porcentaje: son tasas, no montos.
--   - `public.plans.price_cop`, `public.tenant_subscriptions.price_cop`,
--     `public.partner_commissions.amount_cop`/`payment_event_amount_cop`:
--     ya son `bigint` (D-136, D-173) -- no admiten fracción por tipo, un
--     CHECK ahí sería redundante.
--   - `public.tickets`: no persiste total/pagado/saldo como columna propia;
--     se calculan siempre a partir de `ticket_services.price` y
--     `ticket_payments.amount`, que sí quedan cubiertas aquí.

begin;

-- -----------------------------------------------------------------------
-- 1. El único bug real encontrado: redondeo a 2 decimales en la comisión
--    porcentual del estilista. Se copia el cuerpo completo de la función
--    vigente (migración 20260827100000) sin cambiar nada más.
-- -----------------------------------------------------------------------
create or replace function private.beautyos_close_ticket_if_fully_paid(
  p_ticket_id uuid,
  p_tenant_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ticket public.tickets%rowtype;
  v_total numeric(12, 2);
  v_paid numeric(12, 2);
begin
  select *
    into v_ticket
  from public.tickets t
  where t.id = p_ticket_id
    and t.tenant_id = p_tenant_id
  for update;

  if not found or v_ticket.status <> 'finalizado' then
    return;
  end if;

  select coalesce(sum(ts.price), 0)::numeric(12, 2)
    into v_total
  from public.ticket_services ts
  where ts.ticket_id = v_ticket.id
    and ts.tenant_id = p_tenant_id
    and ts.status <> 'cancelado';

  select coalesce(sum(tp.amount), 0)::numeric(12, 2)
    into v_paid
  from public.ticket_payments tp
  where tp.ticket_id = v_ticket.id
    and tp.tenant_id = p_tenant_id
    and tp.status = 'registrado';

  if v_paid < v_total then
    return;
  end if;

  update public.tickets
     set status = 'cerrado'
   where id = v_ticket.id
     and tenant_id = p_tenant_id;

  insert into public.ticket_history (
    tenant_id, ticket_id, event_type, previous_status, new_status, reason, created_by
  ) values (
    p_tenant_id,
    v_ticket.id,
    'status_changed',
    'finalizado',
    'cerrado',
    'Saldo pagado completamente',
    auth.uid()
  );

  insert into public.stylist_commissions (
    tenant_id,
    ticket_id,
    ticket_service_id,
    stylist_id,
    commission_policy_id,
    commission_override_id,
    service_amount,
    commission_type,
    commission_percentage,
    fixed_commission_amount,
    applies_after_discount,
    commission_amount,
    generated_at,
    generated_by
  )
  select
    p_tenant_id,
    v_ticket.id,
    ts.id,
    ts.stylist_id,
    cp.id,
    ov.id,
    ts.price,
    coalesce(ov.commission_type, cp.commission_type),
    coalesce(ov.commission_percentage, cp.commission_percentage),
    coalesce(ov.fixed_commission_amount, cp.fixed_commission_amount),
    cp.applies_after_discount,
    case
      when coalesce(ov.commission_type, cp.commission_type) = 'fixed'
        then coalesce(ov.fixed_commission_amount, cp.fixed_commission_amount)
      else round(ts.price * coalesce(ov.commission_percentage, cp.commission_percentage) / 100)
    end,
    now(),
    auth.uid()
  from public.ticket_services ts
  join public.commission_policies cp
    on cp.tenant_id = p_tenant_id
   and cp.active = true
  left join public.stylist_service_commissions ov
    on ov.tenant_id = p_tenant_id
   and ov.branch_id = v_ticket.branch_id
   and ov.stylist_id = ts.stylist_id
   and ov.service_id = ts.service_id
   and ov.active
  where ts.ticket_id = v_ticket.id
    and ts.tenant_id = p_tenant_id
    and ts.status = 'finalizado'
    and ts.stylist_id is not null
    and not exists (
      select 1
      from public.stylist_commissions sc
      where sc.ticket_service_id = ts.id
        and sc.status = 'generada'
    );
end;
$$;

-- -----------------------------------------------------------------------
-- 2. CHECK "es peso entero" en cada columna de dinero verificada contra
--    el código real. `NOT VALID`: protege lo nuevo ya mismo, no escanea
--    filas viejas. Defensivo por columna: si alguna no existe o no es
--    `numeric` (no debería pasar, pero D-131 enseñó a no asumir), se
--    reporta con NOTICE y se sigue de largo en vez de tumbar la migración.
-- -----------------------------------------------------------------------
do $$
declare
  v_tabla text;
  v_columna text;
  v_objetivos text[][] := array[
    ['public', 'services', 'price'],
    ['public', 'branch_services', 'price'],
    ['public', 'ticket_services', 'price'],
    ['public', 'ticket_payments', 'amount'],
    ['public', 'branch_products', 'average_cost'],
    ['public', 'branch_products', 'sale_price'],
    ['public', 'purchases', 'total_amount'],
    ['public', 'purchase_items', 'unit_cost'],
    ['public', 'expenses', 'amount'],
    ['public', 'commission_policies', 'fixed_commission_amount'],
    ['public', 'stylist_service_commissions', 'fixed_commission_amount'],
    ['public', 'stylist_commissions', 'service_amount'],
    ['public', 'stylist_commissions', 'fixed_commission_amount'],
    ['public', 'stylist_commissions', 'commission_amount']
  ];
  v_fila text[];
  v_nombre_check text;
  v_tipo_dato text;
begin
  foreach v_fila slice 1 in array v_objetivos loop
    v_tabla := v_fila[2];
    v_columna := v_fila[3];
    v_nombre_check := v_tabla || '_' || v_columna || '_es_entero_check';

    select c.data_type into v_tipo_dato
    from information_schema.columns c
    where c.table_schema = v_fila[1]
      and c.table_name = v_tabla
      and c.column_name = v_columna;

    if v_tipo_dato is null then
      raise notice 'OMITIDO  %.%: la columna no existe (revisar a mano).', v_tabla, v_columna;
    elsif v_tipo_dato <> 'numeric' then
      raise notice 'OMITIDO  %.%: tipo "%", no numeric (probablemente ya es entero por tipo).', v_tabla, v_columna, v_tipo_dato;
    elsif exists (
      select 1 from pg_constraint
      where conname = v_nombre_check
        and conrelid = format('%I.%I', v_fila[1], v_tabla)::regclass
    ) then
      raise notice 'YA EXISTIA  %.% ya tenia el candado.', v_tabla, v_columna;
    else
      execute format(
        'alter table %I.%I add constraint %I check (%I = round(%I)) not valid',
        v_fila[1], v_tabla, v_nombre_check, v_columna, v_columna
      );
      raise notice 'AGREGADO  %.%', v_tabla, v_columna;
    end if;
  end loop;
end;
$$;

commit;
