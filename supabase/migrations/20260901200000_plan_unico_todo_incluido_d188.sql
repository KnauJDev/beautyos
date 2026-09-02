-- BeautyOS / Salón y Más — Un solo plan: "Todo Incluido" (D-188)
--
-- ETAPA 1 DE 3. Ver el plan completo de migración en D-188.
--
-- QUÉ CAMBIA Y POR QUÉ
--
-- Se retira la escalera de tres planes (Básico / Business / Profesional, D-124)
-- y queda **un solo plan con todo dentro**. El eje de monetización deja de ser
-- "qué módulos te dejo usar" y pasa a ser **cuántas sedes tienes activas**.
--
-- El fundamento, en corto: enamorar al salón desde el día cero con el producto
-- entero, quitar la sensación de mezquindad de los candados por módulo, y que
-- el ingreso crezca con el negocio del cliente en vez de con lo que se le
-- esconde.
--
-- **Esto resuelve la Idea I-14**, que llevaba desde el 12-ago esperando las
-- primeras cinco visitas a salones reales para decidir la matriz de 15
-- casillas. Ya no hay matriz que decidir: no hay casillas.
--
-- CORRIGE A: D-004 y D-124 (los tres planes), D-136 (los límites por plan) y
-- D-140 (la pantalla pública de tres columnas).
--
-- EL PRECIO, Y UNA CUENTA QUE NO CUADRABA
--
-- Lista $120.000 por sede al mes. Pionero $80.000 por sede.
--
-- **El pionero deja de ser un porcentaje y pasa a ser un precio pactado**, y
-- conviene entender por qué: hasta hoy el pionero era `discount_percent = 50`
-- (D-136). Pero $80.000 sobre $120.000 **no es el 50%, es el 33,33%**, y ese
-- número no cae redondo: `120000 * (1 - 33.33/100)` da **80.004**, no 80.000.
--
-- Cuatro pesos de nada, salvo que `beautyos_procesar_evento_epayco` compara el
-- monto pagado contra el calculado (D-159) y el checkout le mostraría al dueño
-- "$80.004". Así que el pionero se guarda como `price_cop = 80000` con su
-- `price_reason`, que es exactamente el mecanismo que D-136 dejó previsto:
-- "precio propio **o** descuento".
--
-- ⚠️ **Y por lo mismo, el descuento del pionero ya no se puede anunciar como
-- "50%": es un 33%.** Decir 50% sería falso.
--
-- LO QUE ESTA MIGRACIÓN NO HACE
--
-- **No toca el cobro.** Sigue siendo una suscripción por negocio, no por sede.
-- El cobro por sede es la Etapa 2 (suscripción por sede) y la Etapa 3 (ePayco
-- por sede), y tocan `beautyos_precio_efectivo`, el ciclo anclado de D-160, el
-- webhook y las intenciones de pago de D-182 — o sea, el código de dinero que
-- se acaba de blindar. No se mezclan con esto.
--
-- Hasta que llegue la Etapa 2, un negocio paga **una** suscripción y puede
-- crear las sedes que quiera sin que se le cobren. Con cero clientes pagando
-- hoy eso no cuesta dinero, pero **no se puede vender la segunda sede hasta
-- que la Etapa 3 esté hecha**.
--
-- POR QUÉ NO SE TOCA `get_my_entitlements`
--
-- El encargo pedía que devolviera todo en `true`. No hace falta tocarla, y es
-- mejor no hacerlo: `beautyos_resolve_entitlement` ya resuelve desde
-- `plan_features` más los `tenant_feature_overrides`. Si el plan único trae
-- todo incluido, **devuelve todo en `true` sola**, y se conserva:
--   - un solo sitio donde vive la verdad de qué cubre un plan, y
--   - la capacidad del panel de plataforma de conceder o revocar algo a un
--     cliente concreto (D-172), que la Etapa 2 va a necesitar para las sedes
--     que no estén al día.
--
-- Meterle un `true` a la fuerza dentro de la función habría roto las dos cosas.

begin;

-- ---------------------------------------------------------------------------
-- 1. El plan nuevo
-- ---------------------------------------------------------------------------

insert into public.plans (code, version, name, billing_period, price_cop, currency_code, status)
values ('pro', 1, 'Todo Incluido', 'monthly', 120000, 'COP', 'active')
on conflict (code, version) do update
  set name = excluded.name,
      price_cop = excluded.price_cop,
      status = 'active',
      updated_at = now();

-- ---------------------------------------------------------------------------
-- 2. Todo dentro, sin topes
-- ---------------------------------------------------------------------------
--
-- `limit_value = null` significa "sin límite" (D-136). Se activan las cuatro
-- capacidades de software y se quitan los topes de sedes y de cuentas de
-- equipo: estilistas ilimitados.
--
-- **`social_publishing` se queda FUERA a propósito.** Es Fase 6 y no está
-- construido, y el Plan Maestro tiene una regla explícita al pie de esa fase:
-- "Nada de la fase 6 se vende como disponible hasta que exista". Entrará el día
-- que exista, no antes.

insert into public.plan_features (plan_id, feature_id, enabled, limit_value)
select p.id, f.id, true, null::integer
from public.plans p
cross join public.features f
where p.code = 'pro'
  and f.key in (
    'inventory',
    'financial_reports',
    'portfolio',
    'reviews',
    'branches',
    'team_members'
  )
on conflict do nothing;

-- Por si alguna quedó de una corrida anterior con tope o desactivada.
update public.plan_features pf
set enabled = true,
    limit_value = null
from public.plans p, public.features f
where pf.plan_id = p.id
  and pf.feature_id = f.id
  and p.code = 'pro'
  and f.key in (
    'inventory', 'financial_reports', 'portfolio',
    'reviews', 'branches', 'team_members'
  );

-- `social_publishing`, explícitamente apagada mientras la Fase 6 no exista.
insert into public.plan_features (plan_id, feature_id, enabled, limit_value)
select p.id, f.id, false, null::integer
from public.plans p
cross join public.features f
where p.code = 'pro' and f.key = 'social_publishing'
on conflict do nothing;

update public.plan_features pf
set enabled = false
from public.plans p, public.features f
where pf.plan_id = p.id
  and pf.feature_id = f.id
  and p.code = 'pro'
  and f.key = 'social_publishing';

-- ---------------------------------------------------------------------------
-- 3. Los tres viejos se retiran, NO se borran
-- ---------------------------------------------------------------------------
--
-- `tenant_subscriptions.plan_id` los referencia y el histórico de pagos cuenta
-- lo que cada quien pagó. Borrarlos sería reescribir el pasado. `retired` los
-- saca de `list_public_plans()`, que filtra por `status = 'active'`, así que la
-- pantalla pública pasa a mostrar uno solo sin tocar la función.

update public.plans
set status = 'retired', updated_at = now()
where code in ('basico', 'business', 'profesional')
  and status <> 'retired';

-- ---------------------------------------------------------------------------
-- 4. Los negocios que ya existen pasan al plan nuevo
-- ---------------------------------------------------------------------------
--
-- Todos ganan capacidades; ninguno pierde. Un salón que estaba en Básico se
-- encuentra con inventario, reportes, fotos y reseñas encendidos.

update public.tenant_subscriptions ts
set plan_id = (select id from public.plans where code = 'pro' and version = 1),
    updated_at = now()
where ts.plan_id in (
  select id from public.plans where code in ('basico', 'business', 'profesional')
);

-- ---------------------------------------------------------------------------
-- 5. Los pioneros: precio pactado, no porcentaje
-- ---------------------------------------------------------------------------
--
-- Ver la cuenta en la cabecera: el 33,33% de 120.000 da 80.004. Se fija el
-- precio y se retira el porcentaje, para que el checkout diga $80.000 exactos
-- y la validación de monto de D-159 compare contra ese mismo número.
--
-- `price_reason` es obligatorio siempre que haya `price_cop` o
-- `discount_percent` (CHECK de D-136), así que va con motivo.

update public.tenant_subscriptions
set price_cop = 80000,
    price_reason = 'Pionero fundador: $80.000 por sede (lista $120.000). D-188.',
    discount_percent = null,
    discount_ends_at = null,
    updated_at = now()
where is_founder = true;

comment on column public.plans.price_cop is
  'Precio de lista en PESOS COLOMBIANOS ENTEROS (120000 = $120.000). No son centavos (D-136). '
  'Desde D-188 es el precio POR SEDE ACTIVA del plan unico Todo Incluido.';

commit;
