# HANDOFF Salón y Más — 23 de agosto de 2026 (auditoría y corrección de ePayco, D-159)

**Bloque documentado:** decisión **D-159** · Auditoría técnica de la integración ePayco Smart Checkout V2 y corrección de una regresión crítica de cobro introducida el mismo día.

**Estado:** `flutter analyze` 100% limpio (0 errores, 0 advertencias), **156 de 156 pruebas en verde** (`flutter test`). La migración SQL `20260823130000_epayco_validar_precio_por_plan.sql` **fue aplicada en Supabase por el propietario** (`aplicar_sql.ps1`) y el Control 179 corrió contra la base real: rechazó un pago de $10.000 COP en un tenant cuyo precio real (Profesional + 50% Pionero) es $120.000, y activó correctamente con $240.000. **Las 3 Edge Functions tocadas (`create-epayco-session` v6, `epayco-webhook` v5, `verify-epayco-transaction` v7) se desplegaron en este mismo bloque** — hasta ese momento seguían corriendo el código de antes de la auditoría (`functions list` mostró su último despliegue a las 12:37 del 23-ago, previo a estas correcciones); confirmado con `npx supabase functions list`.

---

## 1. Dónde estamos

La Fase 3 (Poder cobrar) sigue cerrada a nivel técnico desde el 17-ago; lo de hoy no abre paso nuevo, **corrige uno que ya se había dado por cerrado**. Ver el mapa completo en `PLAN_MAESTRO.md`, fila 3.10, que ya quedó actualizada con este bloque.

---

## 2. Qué pasó en este bloque

Antes de esta sesión, la conversación había avanzado (commits `a73562f`…`47bc121`, ninguno registrado individualmente como decisión) migrando el checkout de ePayco de una URL directa (V1) a **Smart Checkout V2**: Flutter pide una sesión a la Edge Function `create-epayco-session`, esa función se autentica contra `apify.epayco.co` con las llaves privadas del servidor y devuelve un `sessionId` para abrir el modal oficial. Se hizo un pago real de $10.000 COP que ePayco aprobó, y se desplegó una función `verify-epayco-transaction` para verificar el pago al volver de la pasarela sin depender del webhook asíncrono. Como parte de "robustecer" esa activación, se aplicó en Supabase la migración `20260823120000_epayco_activacion_robusta.sql`.

Se pidió una auditoría técnica de todo ese trabajo. Lo que encontró, leyendo el código real (no la narrativa del bloque anterior):

1. **Regresión crítica de cobro.** `20260823120000` **eliminó** la validación que existía desde el 17-ago (D-141) de `p_amount_cop` contra `private.beautyos_precio_efectivo(tenant_id)`, y la reemplazó por un piso plano de $10.000 COP. Cualquier pago aprobado de al menos $10.000 activaba un mes completo de **cualquier plan**, incluido el de $240.000/mes.
2. **`create-epayco-session` no verificaba dueño del negocio.** Aceptaba `tenantId` y `amount` directamente del body del cliente, sin comprobar que el usuario autenticado perteneciera a ese `tenantId` ni recalcular el monto. Combinado con (1): cualquiera —con o sin cuenta— podía activar la suscripción de **cualquier salón** pagando el mínimo.
3. **Fallback inseguro en `verify-epayco-transaction`.** Si no lograba resolver el tenant por `x_extra1` o por el prefijo de la factura, asociaba el evento de pago al `tenant_subscription` creado **más recientemente en toda la plataforma** — podía activar el negocio equivocado con el pago de otro.
4. **Bug adicional, no relacionado con seguridad pero igual de grave:** `20260823120000` insertaba en `subscription_events` con la columna `subscription_id`, que no existe (la real es `tenant_subscription_id`, definida el 22-jul). Todo evento de pago habría fallado con una excepción de Postgres desde que esa migración se desplegó, con o sin el problema de precio.

El propietario pidió aplicar las correcciones. Se hizo en el mismo bloque:

- **`supabase/migrations/20260823130000_epayco_validar_precio_por_plan.sql`** (nueva, aún no aplicada en Supabase): restaura la validación de monto contra el precio pactado o el precio de lista del plan que se está pagando (ahora recibe `p_plan_code`, para respetar el selector de plan de D-158), con el piso de $10.000 como red adicional, no como sustituto. Corrige también el nombre de columna del punto 4.
- **`supabase/functions/create-epayco-session/index.ts`**: exige sesión autenticada (401 si no hay), resuelve `tenantId` **solo** desde `tenant_memberships` del usuario autenticado (403 si no tiene negocio activo), y ya no acepta `amount` del body.
- **`supabase/functions/epayco-webhook/index.ts`** y **`verify-epayco-transaction/index.ts`**: ahora extraen `x_extra2` (el plan elegido) y se lo pasan a la RPC como `p_plan_code`.
- **`verify-epayco-transaction/index.ts`**: se retiró el fallback de "última suscripción creada". Ahora falla cerrado (404) si no puede identificar el negocio con certeza; el webhook con firma SHA-256 sigue siendo la vía de respaldo para esos casos.
- **`lib/services/epayco_checkout_service.dart`**: ya no envía `tenantId` ni `amount` al invocar `create-epayco-session`, solo `planCode`. Se quitó la variable `finalAmount`, que quedó sin uso.
- **`supabase/sql/179_test_epayco_activacion_robusta.sql`**: reescrito. Antes "certificaba" el hueco (pagaba $10.000 y esperaba `active`). Ahora prueba que un pago insuficiente **no** activa y que el pago por el precio real del plan **sí** lo hace. Sigue con `ROLLBACK`, no toca datos reales.

Verificado con `flutter analyze` (0/0) y `flutter test` (156/156). **No se verificó la migración SQL contra Postgres real** porque no se aplicó — ver sección 4.

---

## 3. Qué quedó a medias / fuera de este bloque

- **La garantía escrita en D-158** ("los salones... con la tranquilidad de que el cobro exacto se reflejará en ePayco") **quedó restaurada** con este fix, pero no estuvo vigente entre el despliegue de `20260823120000` y el de `20260823130000`. Si hubo algún pago real en esa ventana (aparte del de prueba de $10.000 COP que motivó todo esto), revisar `subscription_events` filtrando por `provider = 'epayco'` en ese rango de tiempo antes de asumir que todo quedó bien facturado.
- El selector interactivo de planes (D-158) deja elegir un plan distinto al ya asignado en el checkout, pero **nada actualiza `tenant_subscriptions.plan_id`** cuando el pago se confirma — el tenant sigue formalmente en su plan anterior aunque haya pagado el precio de otro. No se tocó en este bloque por no haber sido parte de lo pedido; queda como hallazgo abierto.
- Los commits `a73562f`…`47bc121` (migración a Smart Checkout V2, activación de modo producción, auto-verificación al volver de la pasarela) nunca se registraron individualmente como decisiones — solo quedaron mencionados dentro de D-159 y en la fila 3.10 del Plan Maestro. Si el propietario quiere separarlos en sus propias entradas D-, decírmelo.
- **Limpieza de HANDOFF encontrada y corregida de paso:** `docs/HANDOFF/` tenía DOS archivos vigentes (18-ago y 22-ago) en vez de solo el más reciente, como pide `docs/README.md`. Se archivaron ambos en `docs/_archivo/handoffs/` en este mismo bloque.

## Qué NO hacer

- **No** volver a aceptar `amount` o `tenantId` del cliente en `create-epayco-session` "para simplificar" — es exactamente el hueco que se cerró hoy.
- **No** reintroducir un fallback de "adivinar el tenant" en `verify-epayco-transaction`. Si el negocio no se puede identificar con certeza, es mejor que falle y lo resuelva el webhook (con firma) que activar al tenant equivocado.
- **No** dar por buena la migración `20260823130000` sin aplicarla antes en Supabase y correr el control 179 contra la base real (ver siguiente sección).

---

## 4. Prompt exacto para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/. Quedaron dos cosas pendientes
del bloque D-159 (corrección de la activación de ePayco):

1. Aplicar en Supabase la migración
   supabase/migrations/20260823130000_epayco_validar_precio_por_plan.sql
   (usa el mismo mecanismo que las migraciones anteriores — revisa
   docs/02_operacion/MAPA_TECNICO.md para el camino de publicación vigente).

2. Correr supabase/sql/179_test_epayco_activacion_robusta.sql contra la base
   real (usa ROLLBACK, no deja rastro) y confirmar que:
   - un pago de $10.000 COP en un tenant cuyo plan cuesta más NO activa la
     suscripción,
   - un pago por el precio real del plan SÍ la activa.

Después de eso, decide con el propietario si quiere:
- revisar subscription_events (provider = 'epayco') por si hubo algún pago
  real procesado en la ventana sin validación de precio del 23-ago,
- registrar los commits de la migración a Smart Checkout V2 como sus propias
  decisiones D-,
- resolver el hallazgo abierto de que el selector de planes del checkout no
  actualiza tenant_subscriptions.plan_id al confirmar el pago.

No reintroduzcas validación de amount/tenantId desde el cliente en
create-epayco-session, ni un fallback que adivine el tenant en
verify-epayco-transaction: son exactamente los huecos que D-159 cerró.
```
