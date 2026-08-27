# HANDOFF Salón y Más — 27 de agosto de 2026 (interactividad de Agenda/Tickets y abonos en citas activas, D-163)

**Bloque documentado:** decisión **D-163** · Bloque de mejoras de interactividad y
fluidez operativa pedido por el propietario: navegación directa desde el
Tablero de Agenda a la Ficha Completa del ticket, píldora de estado
interactiva, y abonos/anticipos habilitados en citas activas (no solo
`finalizado`/`cerrado`).

**Estado:** `flutter analyze` 100% limpio (0/0), **157 de 157 pruebas en
verde** (sube de 156 por la prueba nueva de abonos). Código de Flutter
completo y en producción tras el `git push` de este bloque. **La migración
de base de datos (`20260827100000_abonos_en_citas_activas.sql`) y su control
(`183_test_abonos_en_citas_activas.sql`) están escritos y revisados línea
por línea, pero NO están aplicados en Supabase todavía — eso lo hace el
propietario.** Hasta que se aplique, el botón "Registrar pago / Abono" es
visible en citas activas pero el servidor lo va a seguir rechazando con el
mensaje viejo ("Solo se pueden registrar pagos de tickets finalizados").

---

## 1. Dónde estamos

Bloque de tres pedidos concretos del propietario sobre Agenda y Tickets:

1. Desde la lista Nivel 2 de Agenda (la que se abre al tocar una celda), un
   toque sobre la tarjeta de un ticket debe abrir su Ficha Completa Nivel 3
   directamente, sin ir a la pestaña de Tickets a buscarlo.
2. La píldora de estado (`StatusPill`) del header de la Ficha Completa debe
   ser un botón interactivo ("Cambiar estado") que dispare el diálogo de
   cambio de estado.
3. `AccionesDeTicket.puedeGestionarPagos` restringía "Finanzas y Pagos" a
   `finalizado`/`cerrado`. En la operación real los clientes abonan o pagan
   anticipos desde que la cita se solicita — había que permitirlo en
   cualquier estado activo (`!{'cancelado','no_asistio'}`).

---

## 2. Qué pasó en este bloque

### 2.1 Navegación Agenda → Ficha Completa

`_TicketCardNivel2` (`lib/pages/agenda_page.dart`) usa el `onTap` que ya
traía `AppCard` — no hacía falta un `InkWell` propio, ya envuelve su
contenido en uno. Al tocarla, cierra el modal Nivel 2 y llama a
`onOpenTicket(item.id)`.

**Decisión de diseño encontrada al investigar, no asumida:** `AgendaPage` y
`TicketsPage` son páginas hermanas dentro de un `IndexedStack` en el shell
(`_BeautyOSHomeState._modulesForProfile` en `main.dart`), sin `Navigator`
propio entre ellas — no hay una ruta a la que "empujar". `TicketsPage`
tampoco tiene su propio `Scaffold`/`AppBar` (asume que vive dentro del
shell), así que un `Navigator.push` directo habría quedado sin chrome ni
forma de volver.

La solución: el shell guarda `_pendingOpenTicketId`, cambia `selectedIndex`
a la pestaña de Tickets (**siempre el índice siguiente al de Agenda**,
porque ambas comparten los mismos `allowedRoles` y son adyacentes en la
lista de módulos — invariante documentada en el comentario del código, no
buscada dinámicamente) y se lo pasa a `TicketsPage` como `openTicketId`.
`TicketsPage` gana `openTicketId`/`onTicketOpened`;
`_TicketsPageState._maybeOpenPendingTicket()` espera a que cargue
`ticketsFuture`, busca el ticket y abre `_openTicketDetailSheet` — el
`await` antes de avisar `onTicketOpened` es a propósito: avisarle al shell
de forma síncrona desde `initState`/`didUpdateWidget` del hijo dispara
"setState() called during build".

### 2.2 Píldora de estado interactiva

En `_TicketDetailSheet` (no en `TicketRow`, que es otra clase y no se tocó),
el `StatusPill` del header se envuelve en `InkWell` + `Tooltip('Cambiar
estado')` cuando `onChangeStatus != null`; si el ticket no admite más
transiciones (`AccionesDeTicket.siguientesEstados` vacío), se deja como
badge plano — no tiene sentido un tooltip de "Cambiar estado" sobre algo que
no se puede cambiar.

### 2.3 Abonos en citas activas — el hallazgo real estaba en el servidor

`AccionesDeTicket.puedeGestionarPagos` cambió de `_conDinero.contains(estado)`
a `!{'cancelado','no_asistio'}.contains(estado)`, y el botón "Finanzas y
Pagos" de `_TicketDetailSheet` muestra "Ver historial de pagos" cuando está
cerrado o pagado al 100%, si no "Registrar pago / Abono".

**Antes de tocar Flutter se verificó el RPC `register_ticket_payment`**
(regla del apartado 8.1 del Plan Maestro: verificar en el código antes de
afirmar) y aparecieron dos bloqueos reales que el pedido original no
contemplaba:

- Exigía `status = 'finalizado'` y sumaba el total a cobrar **solo** con
  `ticket_services.status = 'finalizado'` — en una cita `confirmado` sin
  atender el total daba 0 y el pago se habría rechazado igual aunque se
  aflojara solo la regla de Flutter.
- Si un pago dejaba el saldo en 0, cerraba el ticket **y generaba las
  comisiones de los estilistas en el mismo instante** — asumía que "saldo en
  cero" siempre significa "el servicio ya se prestó", falso para un anticipo
  del 100% pagado antes de atender.

Se consultó con el propietario antes de escribir la migración
(`AskUserQuestion`, dos opciones: "nueva migración de abono real" vs.
"dejar el RPC intacto y documentar el pendiente"). **Eligió la migración
real.**

**`supabase/migrations/20260827100000_abonos_en_citas_activas.sql`:**

1. Nuevo helper privado `private.beautyos_close_ticket_if_fully_paid(p_ticket_id, p_tenant_id)`
   — mismo bloque de cierre+comisiones que tenía `register_ticket_payment`
   inline, movido aparte para no duplicar lógica de dinero en dos sitios.
   Idempotente a propósito: si el ticket no está `finalizado`, o queda
   saldo, o ya está `cerrado`, no hace nada.
2. `register_ticket_payment` relajado: el total a cobrar ahora suma
   `ts.status <> 'cancelado'` (mismo criterio que ya usa
   `get_ticket_board_list_v2` para el "Total" que el salón ve en Agenda, no
   solo `finalizado`); el candado de estado pasa a
   `status in ('cancelado','no_asistio')`; el cierre/comisión se delega al
   helper, que solo actúa si el ticket ya está `finalizado` — un abono
   temprano nunca cierra la cita.
3. `change_ticket_status` gana una llamada al mismo helper justo después de
   fijar `status = 'finalizado'` — es el único punto donde el sistema se
   entera de que un ticket ya pagado al 100% por anticipado terminó de
   atenderse. Sin esta llamada se quedaría en `finalizado` con saldo 0 para
   siempre: la única otra vía a `cerrado` es un pago nuevo, que ya no iba a
   llegar porque el dinero ya estaba completo desde antes.

Firmas de ambas funciones públicas sin cambios (mismos parámetros que
tenían), así que **no** hizo falta `drop function` — a diferencia de
`update_tenant_contact_info` en D-162.

**`supabase/sql/183_test_abonos_en_citas_activas.sql`** — control con
`ROLLBACK` contra datos reales, 5 casos: (1) abono sobre una cita
`confirmado` con el servicio sin finalizar — antes esto fallaba con "sin
servicios finalizados para cobrar"; (2) el mismo abono llega al 100% y la
cita **no** se cierra ni genera comisión; (3) se atiende el servicio y se
finaliza — ahí sí se cierra sola y se genera la comisión; (4) una cita
`cancelado` sigue rechazando pagos; (5) regresión del camino de siempre
(cobrar tras finalizar sigue cerrando y generando comisión, sin cambios de
comportamiento).

También se corrigió `_PaymentsDialogState.canRegisterPayment` (el
formulario **dentro** del diálogo de pagos, en `lib/pages/tickets_page.dart`)
a la misma regla — sin este cambio el botón habría abierto un diálogo que
igual ocultaba el formulario de pago porque comprobaba `status == 'finalizado'`
por su cuenta. `test/dinero_y_roles_test.dart` con las nuevas aserciones.

**Verificado:** `flutter analyze` (0/0), `flutter test` (157/157). La
migración y el control están escritos y revisados línea por línea contra
los originales, pero **no ejecutados contra Supabase** — eso es lo
pendiente de este bloque.

---

## 3. Qué quedó a medias / fuera de este bloque

- **Bloqueante para que los abonos funcionen de verdad:** aplicar
  `supabase/migrations/20260827100000_abonos_en_citas_activas.sql` en
  Supabase y correr `supabase/sql/183_test_abonos_en_citas_activas.sql`
  para confirmar los 5 casos en verde contra la base real. Instrucciones en
  el punto 4.
- Heredado de D-161: el selector de sedes del header no se refresca solo
  tras crear una sede desde Configuración.

## Qué NO hacer

- **No** relajar `register_ticket_payment` sin recalcular también el total
  a cobrar — sumar solo `ts.status = 'finalizado'` da 0 en cualquier cita
  sin atender, aunque el candado de estado ya lo permita.
- **No** dejar que "saldo en 0" cierre la cita y genere comisión sin
  comprobar que el ticket ya está `finalizado` — un anticipo del 100%
  cobrado antes de atender no es un servicio prestado.
- **No** buscar dinámicamente el índice de la pestaña de Tickets desde
  Agenda — es siempre `selectedIndex + 1` porque ambas comparten
  `allowedRoles` y son adyacentes en `_modulesForProfile`; si algún día se
  inserta un módulo entre ellas con un `allowedRoles` distinto, este
  supuesto se rompe y hay que revisar `main.dart`.

---

## 4. Prompt exacto para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (bloque D-163: navegación
directa desde Agenda a la Ficha Completa del ticket, píldora de estado
interactiva, y abonos/anticipos en citas activas). El código de Flutter
está completo, flutter analyze 0/0, flutter test 157/157, y el git push ya
se hizo.

PENDIENTE BLOQUEANTE: la migración 20260827100000_abonos_en_citas_activas.sql
todavía no está aplicada en Supabase. Antes de aplicarla:

  1. Respaldar: powershell -ExecutionPolicy Bypass -File scripts\respaldo_supabase.ps1
  2. Aplicar la migración:
     powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
       -Archivo "supabase\migrations\20260827100000_abonos_en_citas_activas.sql"
  3. Correr el control (termina en ROLLBACK, no deja rastro):
     powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
       -Archivo "supabase\sql\183_test_abonos_en_citas_activas.sql"
  4. Confirmar los 5 casos "OK" en la salida antes de darlo por cerrado.

Hasta que esto se aplique, el botón "Registrar pago / Abono" es visible en
citas activas pero el servidor lo sigue rechazando con el mensaje viejo.

No busques dinámicamente el índice de la pestaña de Tickets desde Agenda —
es siempre selectedIndex + 1 (ver main.dart, comentario en onOpenTicket).
```
