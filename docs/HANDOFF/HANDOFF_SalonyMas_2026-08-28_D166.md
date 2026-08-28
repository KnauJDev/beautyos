# HANDOFF Salón y Más — 28 de agosto de 2026 (dirección física, Google Maps y flujo limpio de reserva, D-166)

**Bloque documentado:** decisión **D-166** · Bloque de mejoras clave a la
Página Pública (D-165) y al flujo de Agendar Cita, pedido por el
propietario: dirección física editable con botón de Google Maps, selección
de servicio y profesional en dos pasos desacoplados con "Cualquiera
disponible", y una pantalla de éxito con acciones de salida (WhatsApp,
Google Calendar, volver al salón).

**Estado:** `flutter analyze` 100% limpio (0/0), **168 de 168 pruebas en
verde** (sin pruebas nuevas: este bloque es UI/estado sin modelos nuevos
que amerite probar por unidad, ver punto 2.4). Código de Flutter completo y
en producción tras el `git push` de este bloque. **La migración de base de
datos (`20260828180000_direccion_sede_y_ajustes_reserva.sql`) y su control
(`186_test_direccion_sede_y_contacto.sql`) están escritos y revisados línea
por línea, pero NO están aplicados en Supabase todavía — eso lo hace el
propietario.** Hasta que se aplique, guardar una dirección en Configuración
no tiene efecto y el botón de Google Maps no aparece en la página pública.
**Sigue pendiente también la migración de D-165** (`20260827160000`) si no
se aplicó todavía — sin ella, la página pública sigue mostrando solo el
encabezado de contacto de D-164.

---

## 1. Dónde estamos

D-165 (mismo 28-ago) dejó la página pública completa: servicios, portafolio,
equipo, reseñas, horarios y el botón "Agendar Cita". El propietario probó
el flujo y pidió tres ajustes puntuales pero con peso real de producto: que
la dirección física realmente exista y sea editable (hoy solo se leía de
`branches.address`, pero nada la escribía desde Configuración), que elegir
servicio y estilista deje de ser una sola lista de chips difícil de leer, y
que la pantalla de éxito no sea un callejón sin salida.

---

## 2. Qué pasó en este bloque

### 2.1 Dirección física y Google Maps

`update_tenant_contact_info` ganó un séptimo parámetro, `p_address`, con
`default null` **al final** — no cambió el orden ni el tipo de los
parámetros que ya existían, así que **no hizo falta `drop function`** (a
diferencia de casi todos los demás cambios de este proyecto sobre
funciones con `RETURNS TABLE`, que sí lo exigen). La función ahora escribe
en dos tablas: `tenants` como siempre, y `branches.address` de la sede
**principal activa** del tenant — mismo criterio que ya usaba
`get_public_salon_by_slug` (D-164) para leerla.

`get_business_settings` sí cambió su forma de retorno (gana `address`), así
que **sí exigió `drop function` primero** — mismo motivo repetido en
D-162/D-164/D-165: `create or replace` no admite cambiar lo que una función
devuelve.

En Flutter: `_ContactInfoEditor` gana el campo "Dirección física";
`BusinessSettings`/`BusinessSettingsService.updateContactInfo` ganan
`address`. La página pública (`_HoursLocationSection`) muestra
"📍 Ver en Google Maps" cuando el salón tiene dirección, con el enlace
estándar `google.com/maps/search/?api=1&query=<dirección, ciudad>`.

### 2.2 Reserva en dos pasos desacoplados

Se retiró `_buildTeamSection()` de `PublicBookingPage` — mostrar el equipo
ahí era redundante ahora que la página del negocio (D-165) ya lo hace, y
mejor.

La lista combinada de chips ("Corte · Paola Jara · $30.000") se separó en:

- **Paso 1 — Elige un servicio:** `DropdownButtonFormField` con los
  servicios **deduplicados por `serviceId`** (todos los estilistas que
  ofrecen el mismo servicio comparten precio y duración, porque vienen de
  la misma fila de `branch_services` — deduplicar por nombre no habría
  sido seguro, por `serviceId` sí).
- **Paso 2 — Elige profesional:** otro dropdown, filtrado a los estilistas
  que ofrecen ESE servicio, con **"Cualquiera disponible" como opción por
  defecto** (no hay que tocarlo para avanzar).

**La parte no trivial:** el backend (`public_get_available_slots`) exige un
`stylist_id` concreto — no existe "cualquiera" a nivel de RPC. "Cualquiera
disponible" se resuelve enteramente en Flutter: se consulta en paralelo
(`Future.wait`) la disponibilidad de **cada** estilista que ofrece el
servicio y se combinan en una sola lista de horarios (`_SlotOption`), donde
cada horario recuerda internamente de qué estilista salió aunque en
pantalla solo se vea la hora. Si dos estilistas coinciden en el mismo
horario, se muestra una sola vez (se queda con el primero). Al reservar, se
usa el `stylistId` que ese horario específico traía guardado.

Botón final renombrado de "Confirmar reserva" a **"Solicitar cita"**.

### 2.3 Pantalla de éxito con salida

Tres botones nuevos en `_BookingSuccessCard`:

- **"📲 Avisar al salón por WhatsApp"** — mensaje precargado con el nombre
  del cliente, el servicio y la fecha, al WhatsApp de la sede
  (`branchInfo.whatsapp`). Solo aparece si el salón tiene uno cargado.
- **"📅 Guardar en Google Calendar"** — enlace de plantilla estándar de
  Google (`calendar.google.com/calendar/render?action=TEMPLATE...`) con
  fecha/hora formateadas a mano al formato UTC que exige
  (`YYYYMMDDTHHMMSSZ`, sin punto ni guion) — **sin depender de ningún
  paquete de calendario nuevo**. La duración sale del servicio elegido
  (`durationMinutes`, pasado desde el estado de la página al no venir en
  `PublicBookingResult`); la ubicación es la dirección de la sede.
- **"🏠 Volver a la página del salón"** — `Navigator.pop()`, **visible solo
  si `Navigator.canPop()` es verdadero**. Si se llegó por el enlace directo
  `?reservar=<uuid>` (D-005) en vez de empujado desde la página del negocio
  (D-165), no hay a dónde volver — el botón se oculta en vez de fallar o
  quedar muerto.

### 2.4 Por qué no hay pruebas nuevas

Los cambios de este bloque son de UI y estado interno de un widget
(`_PublicBookingPageState`), sin modelos nuevos con lógica pura que valga
la pena aislar en una prueba unitaria — mismo criterio que ya tenía
`PublicBookingPage` antes de este bloque (nunca tuvo pruebas propias,
porque depende de RPC reales sin un punto de inyección para simularlas,
a diferencia de `AgendaPage`, que sí recibe su servicio por constructor).
`BusinessSettings.address` es un campo más en un modelo que tampoco tenía
pruebas dedicadas desde que se le agregó `slug` en D-164.

**Verificado:** `flutter analyze` (0/0), `flutter test` (168/168, sin
cambios de número). La migración y el control están escritos y revisados
línea por línea contra las funciones que modifican, pero **no ejecutados
contra Supabase** — eso es lo pendiente de este bloque.

---

## 3. Qué quedó a medias / fuera de este bloque

- **Bloqueante para que la dirección/Google Maps funcionen de verdad:**
  aplicar `supabase/migrations/20260828180000_direccion_sede_y_ajustes_reserva.sql`
  en Supabase y correr `supabase/sql/186_test_direccion_sede_y_contacto.sql`.
  Instrucciones en el punto 4.
- **Si no se hizo todavía:** aplicar también la migración de D-165
  (`20260827160000_perfil_publico_completo.sql`) y su control
  (`185_test_perfil_publico_completo.sql`) — sin ella la página pública no
  muestra servicios, portafolio, equipo ni reseñas.
- Pasos 5.6 (cuenta del cliente final) y 5.7 (permiso de publicación,
  legal) siguen sin construir.
- Heredado de D-161: el selector de sedes del header no se refresca solo
  tras crear una sede desde Configuración.

## Qué NO hacer

- **No** intentar "cualquiera disponible" como un parámetro nuevo del RPC
  de disponibilidad — el backend siempre exige un `stylist_id` concreto.
  Se resuelve combinando en Flutter los horarios de todos los estilistas
  elegibles, no cambiando la función.
- **No** asumir que `update_tenant_contact_info` siempre necesita
  `drop function` al cambiar — solo cuando cambia la **forma del
  retorno**. Agregar un parámetro nuevo con `default` al final (como
  `p_address` en este bloque) no la necesita.
- **No** mostrar "Volver a la página del salón" sin comprobar
  `Navigator.canPop()` primero — `PublicBookingPage` también se llega por
  el enlace directo `?reservar=<uuid>` sin página previa a la que volver.

---

## 4. Prompt exacto para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (bloque D-166: direccion
fisica editable con boton de Google Maps, reserva en dos pasos
desacoplados con "Cualquiera disponible", y pantalla de exito con
WhatsApp/Google Calendar/volver al salon). El codigo de Flutter esta
completo, flutter analyze 0/0, flutter test 168/168, y el git push ya se
hizo.

PENDIENTE BLOQUEANTE: la migracion 20260828180000_direccion_sede_y_ajustes_reserva.sql
todavia no esta aplicada en Supabase. Antes de aplicarla:

  1. Respaldar: powershell -ExecutionPolicy Bypass -File scripts\respaldo_supabase.ps1
  2. Aplicar la migracion:
     powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
       -Archivo "supabase\migrations\20260828180000_direccion_sede_y_ajustes_reserva.sql"
  3. Correr el control (termina en ROLLBACK, no deja rastro):
     powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
       -Archivo "supabase\sql\186_test_direccion_sede_y_contacto.sql"
  4. Confirmar los casos "OK" en la salida antes de darlo por cerrado.

Si la migracion de D-165 (20260827160000_perfil_publico_completo.sql) no
se aplico todavia, aplicarla tambien -- sin ella la pagina publica no
muestra servicios, portafolio, equipo ni resenas.

Los pasos 5.6 (cuenta del cliente final) y 5.7 (permiso de publicacion,
legal) siguen sin construir -- son el siguiente punto natural de la Fase 5.

No intentes agregar "cualquiera disponible" como parametro del RPC de
disponibilidad -- se resuelve combinando en Flutter los horarios de todos
los estilistas elegibles (Future.wait), el backend siempre exige un
stylist_id concreto.
```
