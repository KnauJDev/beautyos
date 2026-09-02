# HANDOFF Salón y Más — 2 de septiembre de 2026 ("Velocidad Operativa de Mostrador", D-195)

**Bloque documentado:** decisión **D-195** · Paso **8.17** de la **FASE 8**.

**Estado:** `flutter analyze` limpio (0/0) y **297 de 297 pruebas en verde** (5
nuevas de este bloque). Las tres mejoras del Bloque 1 quedaron implementadas y
probadas: cita express, cobro directo desde Agenda y WhatsApp pre-armado.

> El bloque anterior (D-188 a D-194, "un solo plan por sede" y los reportes
> consolidados) está en
> `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-02_D191.md`. Sigue siendo
> la referencia de cómo quedó el cobro por sede y los reportes.

---

## 1. Lo que cambió: velocidad de mostrador, no arquitectura

El propietario pidió tres mejoras de UX citando `UX-01`, `UX-03`, `UX-04`,
`UX-05` y `UX-10`. **Antes de tocar código se contrastó ese encargo contra
`docs/01_arquitectura/auditorias/AUDITORIA_4_REVISIONES_2026-09-01.md`**, que
ya había verificado esos mismos hallazgos contra el código real el 01-sep, y
la numeración no coincidía:

| Lo que citaba el encargo | Lo que dice la auditoría verificada |
|---|---|
| UX-04 = WhatsApp pre-armado | **UX-04 ahí es Onboarding.** El WhatsApp no tiene hallazgo con ese código |
| UX-05 = falta un botón de cobro destacado | **Quedó REFUTADO.** `TicketRow` ya mostraba "Pagos y saldo" como único botón relleno, abriendo el pago directo sin la Ficha Completa |
| UX-03 = cobrar desde Agenda no funciona | **Parcialmente resuelto desde D-163** (27-ago): la tarjeta ya abre la Ficha Completa con un toque |
| UX-10 = falta caja rápida | **Nunca se verificó contra código.** No bloqueaba nada |

Esto no se resolvió por iniciativa propia: se le devolvieron al propietario
**dos preguntas de fondo que sí cambiaban el riesgo** (`AskUserQuestion`)
antes de escribir una línea. Sus respuestas son las que quedaron
implementadas:

### 1. Cita express — reutiliza "Cualquiera disponible", no se salta el cálculo

La otra opción sobre la mesa era asignar la hora actual sin verificar la
agenda del estilista. Se descartó: **podía duplicar una cita sobre el mismo
estilista**, contra el invariante de "protección contra choques a nivel de
base de datos" de `AGENTS.md`.

En su lugar, `CreateAppointmentDialog` (`lib/pages/tickets_page.dart`) gana la
misma lógica que `PublicBookingPage` usa desde D-166:

- El desplegable de estilista ofrece **"⚡ Cualquiera disponible"** como
  opción (antes bloqueaba la carga de horarios hasta elegir uno a mano).
- Botón nuevo **"Atender ya (walk-in)"**: fija la fecha de hoy, consulta
  disponibilidad real de **todos** los estilistas del servicio en paralelo
  (`Future.wait`, mismo patrón que la reserva pública) y selecciona el
  horario más próximo desde ahora.
- Sigue siendo el mismo cálculo de disponibilidad de siempre — solo con menos
  toques para llegar a él. Cierra la mitad barata del hallazgo **C-01** de la
  auditoría del 01-sep: la reserva pública tenía mejor flujo que el
  mostrador; ahora tienen el mismo.

### 2. Botón de cobro — se modificó el existente, no se duplicó

`TicketRow`, en la lista principal de Tickets, **ya** abría `_PaymentsDialog`
directo desde "Pagos y saldo" sin pasar por la Ficha Completa — por eso la
auditoría refutó UX-05. Lo que faltaba de verdad era el mismo atajo en la
**tarjeta de cita de Agenda**, que solo abría la Ficha Completa vía el salto
de pestaña de D-163.

Se agregó ahí un botón **"Cobrar $XX.XXX"** — visible solo con saldo
pendiente y en un estado que admite pagos
(`AccionesDeTicket.puedeGestionarPagos`) — que reutiliza el mecanismo de
D-163: nuevos `collectTicketId` / `onCollectTicketOpened` en `TicketsPage`,
cableados en `main.dart`, abren el diálogo de pago directo al cambiar de
pestaña, sin pasar por la Ficha Completa.

### 3. WhatsApp con mensaje pre-armado

Nueva función pública `buildAppointmentReminderMessage` en `agenda_page.dart`
(mismo patrón que `buildWhatsAppUri`, para quedar testeable sin abrir un
navegador — regla de H-03), usada en la tarjeta de cita del Nivel 2 de
Agenda:

> *"Hola {cliente} 👋, te recordamos tu cita de {servicio} hoy a las {hora}
> en {negocio}."*

El nombre del negocio llega como `BranchContext.tenantName`, nuevo parámetro
`businessName` en `AgendaPage`.

### Lo que NO se hizo

- **UX-10 (caja rápida) queda fuera de este bloque.** Nunca se verificó
  contra código y la auditoría dijo explícitamente que no bloqueaba nada.
  Si el propietario la quiere, hay que verificarla primero.
- No se tocó `_TicketDetailSheet` ni la lista principal de `TicketRow`: ya
  estaban bien.

---

## 2. Bookkeeping que se sincronizó de paso

Los pasos **8.15** y **8.16** del Plan Maestro seguían marcados 🔄 aunque
D-190 a D-194 ya estaban aprobados en el Registro y verificados contra
producción (según el HANDOFF anterior). Se marcaron ✅ **en este mismo
cambio, sin reabrir ninguna decisión** — es sincronizar el estado con lo que
ya era cierto, no una decisión nueva.

**Contradicción que queda señalada, sin resolver por iniciativa propia:**
`docs/_archivo/LEEME.md` dice que `handoffs/` tiene "12 documentos"; hoy tiene
**41** (42 tras archivar este bloque). Lleva desactualizado desde hace varias
sesiones — no se corrigió porque no es parte de este encargo, pero conviene
saberlo antes de citar esa cifra.

---

## 3. Lo que quedó a medias (hereda del bloque anterior, nadie lo tocó hoy)

### 3.1 Las alertas de vencimiento siguen siendo por negocio

`send-subscription-expiry-alerts` (D-143) avisa a los 10, 5 y 3 días mirando
`tenant_subscriptions`. Una sede secundaria que se atrase **no genera
aviso**. Sigue sin ser urgente mientras no haya salones con dos sedes
pagando.

### 3.2 El tope de equipo sigue siendo por NEGOCIO, no por sede

`create_team_invitation` cuenta las cuentas del tenant entero. La promesa de
*"10 por sede"* (D-189) **no es cierta para multi-sede**. Hoy juega a favor
del cliente, pero es una promesa comercial que el código no cumple.

### 3.3 La pantalla pública nunca se vio renderizada

`public_plans_page.dart`, la tarjeta de sedes de D-193 y el desglose por sede
de D-194 compilan y pasan pruebas, pero **nadie los ha visto con los ojos**:
no se pudo levantar el servidor web en las sesiones anteriores. Tampoco se
intentó en esta.

### 3.4 El candado 2 de D-181 sigue sin ejercitarse

La comparación de `x_cust_id_cliente` no se ha probado contra una transacción
real. En el próximo pago:

```bash
curl -s https://secure.epayco.co/validation/v1/reference/REF_PAYCO_REAL | python -m json.tool | grep -i cust
```

---

## 4. Qué NO hacer

- **No saltarse el cálculo de disponibilidad real para acelerar el
  walk-in.** Es justo la opción que el propietario descartó hoy: asignar la
  hora actual sin consultar la agenda del estilista puede duplicar una cita.
  Si algún día se pide "más rápido todavía", la respuesta es optimizar la
  consulta (por ejemplo cachear slots del día), no quitar la verificación.
- **No agregar un segundo botón de cobro en `TicketRow`.** Ya tiene el
  correcto ("Pagos y saldo", `FilledButton.tonalIcon`, abre el pago directo).
  Dos botones de dinero en la misma tarjeta es lo que la auditoría del 01-sep
  ya refutó como problema real.
- **No confiar en la numeración UX-01..UX-12 de un encargo sin contrastarla
  contra `AUDITORIA_4_REVISIONES_2026-09-01.md` primero.** Hoy UX-04 y UX-05
  no significan lo que un encargo nuevo podría asumir que significan.
- **No borrar los candados de plan de D-184 y D-187**, ni tocar
  `get_my_entitlements`, ni los tres planes `retired` — mismo motivo que el
  HANDOFF anterior: siguen siendo el mecanismo de la sede impaga y la fuente
  de verdad de qué cubre el plan.
- **No poner `verify_jwt = true` en `epayco-webhook`** (D-177, sigue vigente).

---

## 5. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-195: Bloque 1 "Velocidad
Operativa de Mostrador" -- cita express reutilizando "Cualquiera disponible",
cobro directo desde la tarjeta de Agenda, y WhatsApp con mensaje pre-armado).

El Bloque 1 está cerrado: flutter analyze 0/0 y 297/297 pruebas en verde.
Antes de construirlo se contrastó el encargo del propietario contra
docs/01_arquitectura/auditorias/AUDITORIA_4_REVISIONES_2026-09-01.md, porque
la numeración UX no coincidía (UX-04 ahí es Onboarding, UX-05 estaba
refutado) -- ese contraste es la parte que vale la pena releer si llega un
encargo nuevo citando esos códigos.

Lo que sigue abierto, heredado del bloque anterior (D-188 a D-194), por orden
de daño:
1. Alertas de vencimiento por sede (apartado 3.1). Una sede secundaria que se
   atrase no avisa a nadie.
2. El tope de equipo por sede (apartado 3.2). D-189 lo prometió "por sede" y
   create_team_invitation cuenta el tenant entero.
3. Mirar con los ojos la pantalla pública de planes, la tarjeta de sedes y el
   desglose de reportes por sede (apartado 3.3). Compilan y pasan pruebas;
   nadie las ha visto.
4. UX-10 (caja rápida), citado en el encargo de hoy pero descartado de este
   bloque por no estar verificado contra código. Si se retoma, verificarlo
   primero contra tickets_page.dart antes de construir nada.

Y fuera de esto, del Plan Maestro: la Fase 3 tiene dos casillas de 👤 abiertas
(3.2 consultar a un contador sobre DIAN e IVA, y 3.4 subir Supabase a Pro).

Ojo con lo que NO hay que tocar: el walk-in de CreateAppointmentDialog sigue
calculando disponibilidad real -- no se salta ese cálculo aunque parezca la
forma obvia de hacerlo "más rápido todavía". Y TicketRow no necesita un
segundo botón de cobro: ya tiene el correcto desde antes de este bloque.
```
