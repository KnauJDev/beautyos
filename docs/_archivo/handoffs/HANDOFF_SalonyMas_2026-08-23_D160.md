# HANDOFF Salón y Más — 23 de agosto de 2026 (ciclo de facturación anclado, D-160)

**Bloque documentado:** decisión **D-160** · Ciclos de facturación de 30 días anclados al primer pago, precedencia absoluta del plan/precio pactado por el owner, y dos bugs corregidos de paso (`plan_id` no se actualizaba; el candado de pactado no cubría descuento-sin-precio-fijo).

**Estado:** `flutter analyze` 100% limpio (0/0), **156 de 156 pruebas en verde**. Migración `20260823150000` **aplicada en Supabase** por el propietario, Control 180 (9 pruebas) **en verde contra la base real**. Edge Function `create-epayco-session` **redesplegada** (v7). `git push` **hecho y confirmado en producción** (commit `5aa9fce`): se descargó `main.dart.js` desde `salonymas.com` y el texto nuevo del checkout con precio pactado ("Tu plan y tarifa fueron acordados con Salón y Más") ya está publicado. **Este bloque quedó cerrado sin pendientes.**

---

## 1. Dónde estamos

Este bloque es una continuación directa de D-159 (mismo día, misma sesión): D-159 cerró el hueco de seguridad del cobro exacto; D-160 construye lo que el propietario pidió justo después — que ese cobro exacto respete ciclos anclados y el plan/precio que él defina, no un reinicio ciego cada vez que alguien paga. Ver `PLAN_MAESTRO.md`, fila 3.10, ya actualizada.

---

## 2. Qué pasó en este bloque

El propietario explicó en sus palabras cómo quiere que funcione la facturación (transcrito y confirmado con él antes de tocar código):

1. **Ancla de 30 días "comerciales"**, no meses calendario: el ciclo se cuenta desde el día del primer pago, siempre en bloques de 30 días — así se evita el problema de "día 31 no existe en febrero".
2. **Renovación anticipada** (paga mientras el período vigente sigue activo): el nuevo mes se acumula al final del vigente, precio completo. La ancla nunca se corre.
3. **Pago tardío dentro de gracia** (5 días, como ya existía D-141): se cobra proporcional a los días que faltan hasta la próxima fecha ancla, no un mes completo.
4. **Reactivación tras suspensión**: mes completo desde ese momento, se reancla — **excepto** si la suspensión fue manual del propietario (fraude, incumplimiento), en cuyo caso el pago se registra pero no reactiva, necesita su revisión.
5. **Plan/precio pactado**: si el propietario fijó un plan y/o precio específico para un tenant desde el panel, eso es lo que se cobra siempre, sin importar qué elija el tenant en el checkout.
6. Código promocional: **descartado explícitamente**, no se construye.

Antes de escribir una sola línea, se hizo una revisión de diseño en dos pasos (exploración del esquema real + un segundo análisis crítico) que encontró:

- **Bug A, del código anterior:** `plan_id` nunca se actualizaba al confirmar un pago. Un tenant sin precio pactado que pagaba Profesional en el dropdown seguía con los cupos (sedes/cuentas) de su plan viejo.
- **Bug B, del código anterior:** el candado de "precio pactado" solo miraba `price_cop`. Un pionero con solo descuento (`price_reason` puesto, `discount_percent` fijado, `price_cop` nulo) no quedaba cubierto — se podía mandar un `p_plan_code` distinto directo a la RPC y aplicar ese descuento a un plan que el owner no pactó.
- **Riesgo de condición de carrera** si se cotiza el monto comparando `now()` en vivo contra la fecha de gracia: una sesión de pago abierta justo cuando cruza el límite de 5 días podría cobrar de menos y luego ser rechazada, dejando a ePayco con el dinero cobrado y a Salón y Más sin activar. **Se resolvió decidiendo la rama por el `status` persistido** (`past_due`/`grace` vs `suspended`), no por comparar fechas en tiempo real — acota el riesgo a la ventana del cron diario (~24h) en vez de "cualquier segundo".
- **Bug C, adyacente, corregido de una vez porque comparte la misma columna:** `platform_reactivate_tenant` no restauraba `current_period_end`, así que reactivar a mano a alguien después de vencer su gracia lo dejaba con `status='active'` pero seguía bloqueado para agendar.

**Decisiones confirmadas explícitamente con el propietario antes de implementar:**
- Suspensión manual bloquea reactivación por pago automático — **sí**.
- Corregir el bug de `platform_reactivate_tenant` en este mismo bloque — **sí**.

**Lo que se construyó:**
- `supabase/migrations/20260823150000_ciclo_facturacion_ancla_y_plan_pactado.sql`: función pura `private.beautyos_calcular_cargo_epayco` en dos formas (con la fila bloqueada, para la RPC de confirmación; por `tenant_id` sin bloqueo, para cotizar en `create-epayco-session`) como fuente de verdad única; reescritura de `private.beautyos_procesar_evento_epayco` con las 4 ramas (primera activación, renovación anticipada, pago tardío prorrateado, reactivación) y el guard de suspensión manual; cada pago aceptado ahora también actualiza su propio `subscription_events` con el motivo/monto/período calculados (antes solo quedaba el payload crudo de ePayco); corrección de `platform_reactivate_tenant`; `get_my_tenant_subscription_status()` expone `has_pactado_price`/`price_reason`.
- `supabase/functions/create-epayco-session/index.ts`: ya no duplica la tabla de precios — cotiza con la misma función que valida el pago, y usa el plan **resuelto por el servidor** (ignora el que mandó el cliente cuando hay pactado) para la sesión de ePayco.
- `lib/models/tenant_subscription_status.dart` / `lib/services/epayco_checkout_service.dart`: nuevo campo `hasPactadoPrice`; el checkout oculta el selector de 3 planes y muestra un resumen fijo no editable cuando hay precio pactado.
- `supabase/sql/180_test_ciclo_facturacion_ancla.sql`: 9 aserciones contra la base real (con `ROLLBACK`) — las 4 ramas, la suspensión manual bloqueada, y los 2 bugs corregidos.

**Verificado:** `flutter analyze` (0/0), `flutter test` (156/156), migración aplicada en Supabase, Control 180 con las 9 pruebas en verde (incluye un pago prorrateado de $8.500 aceptado por debajo del piso viejo de $10.000, y uno de $1.000 correctamente rechazado). `create-epayco-session` redesplegada y confirmada en v7.

---

## 3. Qué quedó a medias / fuera de este bloque

- El `git push` que este HANDOFF marcaba como bloqueante **ya se hizo y se verificó en producción** (sesión del 23-ago, después de escrito este documento): `curl` sobre `https://salonymas.com/main.dart.js` + `grep` del texto nuevo del checkout confirmó 1 coincidencia. Procedimiento en `MAPA_TECNICO.md`.
- Los commits de la migración a Smart Checkout V2 (bloque anterior a D-159) siguen sin registrarse individualmente como decisiones — mencionado también en el HANDOFF de D-159, sigue pendiente si el propietario lo quiere.
- No se construyó código promocional — descartado a propósito, no es un pendiente.

## Qué NO hacer

- **No** volver a comparar `now()` en vivo contra `grace_ends_at` para decidir si un pago está "en gracia" o "ya suspendido" — se decidió a propósito usar el `status` persistido, para no cobrar de menos si una sesión de pago queda abierta justo cuando cruza el límite.
- **No** dejar que `create-epayco-session` vuelva a calcular el monto con su propia lógica duplicada — debe seguir llamando a `private.beautyos_calcular_cargo_epayco`, que es la misma fuente de verdad que usa la RPC de confirmación.
- **No** asumir que un cambio en Flutter ya está en producción sin el `git push` — a diferencia de las Edge Functions, que se despliegan aparte con `supabase functions deploy`.

---

## 4. Prompt exacto para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (bloque D-160, ciclo de
facturación anclado). Está cerrado sin pendientes: migración en Supabase,
Control 180 contra la base real, create-epayco-session redesplegada, y el
git push ya verificado en producción (curl + grep sobre main.dart.js
publicado).

Si quieres, sigue con el único hilo abierto que queda de D-159/D-160:
registrar los commits de la migración a Smart Checkout V2 (bloque anterior
a D-159) como decisiones separadas en REGISTRO_DE_DECISIONES.md.

No reintroduzcas comparación de now() en vivo contra grace_ends_at para
decidir la rama de facturación, ni dupliques la lógica de precio en
create-epayco-session: ambos son justo lo que D-160 corrigió.
```
