# HANDOFF Salón y Más — 29 de agosto de 2026 ("Tu negocio en palabras", D-168)

**Bloque documentado:** decisión **D-168** · Paso **6.1** de la **FASE 6 — El
plan Profesional**: ⭐ "Tu negocio en palabras", el Dashboard contado en un
párrafo.

**Estado:** `flutter analyze` 100% limpio (0/0), **197 de 197 pruebas en
verde** (sube de 176). Bloque **100% Flutter, sin migración de base de
datos** — no hay nada pendiente de aplicar en Supabase. Falta únicamente el
`git push` (ver punto 5).

---

## 1. Dónde estamos

Con la Fase 5 completa (D-164 a D-167, cerrada el 29-ago), el propietario
pidió arrancar la Fase 6 por el paso de más valor con menos trabajo: una
tarjeta narrativa en el Dashboard que cuente el día en un párrafo, sin IA
—todo el dato ya lo carga el Dashboard para los indicadores numéricos que ya
existían.

---

## 2. Qué se construyó

### 2.1 El motor narrativo (`lib/widgets/tu_negocio_en_palabras_card.dart`)

`NarrativaNegocioBuilder`: lógica pura, **separada del widget a propósito**
—mismo criterio de testabilidad que `PeriodoDashboard` (D-110)—, recibe
`ahora`/`hoy` por parámetro en vez de leer el reloj del sistema.

**Saludo por hora** (cruza la medianoche, se compara en minutos desde las
00:00): 05:00–11:59 "🌅 Buenos días", 12:00–18:29 "☀️ Buenas tardes",
18:30–04:59 "🌙 Buenas noches" — de noche el verbo cambia a pasado
("tuviste"/"atendiste" en vez de "tienes"/"atendiste").

**El párrafo cubre, en orden:**
1. Ritmo de citas del día (o el mensaje de día cero si no hay ninguna, con
   sugerencia de poner al día el catálogo o el portafolio).
2. Citas sin confirmar, con mención a resolverlas por WhatsApp.
3. Dinero pendiente por cobrar, formateado con `formatCOP` (ya existente en
   `ticket_board.dart`, reutilizado por import cruzado).
4. Clientas en riesgo que solían venir seguido.
5. Tendencia de ventas del período — **solo si hay historia suficiente y el
   movimiento es de al menos 1 %** (regla de oro de D-110: no mostrar una
   precisión que el dato no soporta).

Todas las frases singularizan/pluralizan correctamente (1 cita/N citas,
1 ticket/N tickets, 1 clienta/N clientas).

**Tres chips de acción** (`📅 X por confirmar`, `💵 Cobrar $XX.XXX`,
`👥 X en riesgo`) navegan a Agenda/Tickets/Clientes.

### 2.2 Navegación desde un módulo hermano (`lib/main.dart`)

`DashboardPage` vive en el mismo `IndexedStack` del shell que Agenda,
Tickets y Clientes (mismo criterio de D-163: no hay una ruta a la que
empujar). Se agregó un helper `_irAModulo(modules, titulo)` que busca el
índice del módulo por su título — a diferencia de D-163 (un solo destino
adyacente fijo), aquí el llamador puede apuntar a cualquiera de tres
destinos distintos, así que fijar tres índices a mano habría sido más
frágil que buscarlos por nombre.

**Hallazgo de Dart durante la construcción:** la lista `modules` no podía
seguir declarada como `final modules = [...]`, porque los propios closures
de navegación del Dashboard, dentro de ese mismo literal, la referenciaban
— Dart no permite que una variable local se referencie dentro de su propio
inicializador, aunque sea desde un closure que solo se ejecuta después.
**Fix:** se separó la declaración de la asignación
(`late final List<BeautyModule> modules;` seguido de `modules = [...]`).

### 2.3 Integración en el Dashboard (`lib/pages/dashboard_page.dart`)

La tarjeta se integra justo antes de los 4 indicadores protagonistas,
reutilizando la misma `Future<DashboardHoy>` que ya cargaba
`AgendaDeHoy`/`AvisosDelDia` más abajo en la pantalla — no dispara una
segunda consulta. El saludo usa el nombre del titular
(`profile.fullName`) o, si su perfil aún no tiene nombre cargado, el
nombre del negocio; y solo se usa el primer nombre, para que suene a
conversación y no a formulario.

### 2.4 Pruebas (`test/tu_negocio_en_palabras_test.dart`, 21 nuevas)

Límites exactos de las tres franjas horarias; ritmo de citas en sus
variantes de mañana/noche/singular/todas-atendidas; alerta de cobro con
formato COP en montos chicos y grandes; alerta de clientas en riesgo en
singular y plural; día cero en sus tres variantes (con/sin dinero
pendiente, de noche); tendencia de ventas arriba/abajo/sin-historia/
movimiento-insignificante/sin-datos; y el primer nombre del saludo con
nombre completo y con nombre vacío.

También se ajustó `test/tramo_d3_2_branch_contracts_test.dart`, que
construía `DashboardPage` sin el nuevo parámetro requerido
`nombreParaSaludo` (agregado con un valor de prueba fijo).

---

## 3. Qué quedó a medias / fuera de este bloque

- Nada bloqueante. El bloque es 100% Flutter, sin migración, así que no hay
  ningún paso pendiente del propietario en Supabase para que esto tenga
  efecto — ya está activo apenas se haga el `git push`.
- El Plan Maestro no tenía, hasta ahora, ningún paso de la Fase 6
  construido. Con este bloque queda **1 de 6 pasos cerrados** (6.1); los
  cinco restantes (6.2 a 6.6) siguen sin construir y varios dependen de
  aprobaciones externas (Meta) o de decidir cuándo se activa la IA.

## Qué NO hacer

- **No** mover `NarrativaNegocioBuilder` a leer `DateTime.now()`
  directamente si se le agrega lógica nueva — el patrón de recibir `ahora`
  por parámetro es lo que permite probarlo sin depender de la hora real de
  quien corre la prueba. Seguir el mismo criterio que ya usa
  `PeriodoDashboard` (D-110).
- **No** volver a declarar `modules` como `final modules = [...]` en
  `main.dart` si se agregan más callbacks de navegación dentro del mismo
  literal — Dart no permite la autorreferencia dentro del propio
  inicializador. Mantener `late final List<BeautyModule> modules;` seguido
  de la asignación aparte.
- **No** asumir que la tarjeta necesita su propia consulta a
  `DashboardHoy` — comparte la `Future` que ya usan `AgendaDeHoy` y
  `AvisosDelDia`; duplicarla sería una segunda llamada de red innecesaria
  cada vez que se reconstruye el Dashboard.

---

## 4. Prompt exacto para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (bloque D-168: "Tu negocio en
palabras", paso 6.1 de la Fase 6). El codigo esta completo, flutter analyze
0/0, flutter test 197/197. Es un bloque 100% Flutter sin migracion, asi que
no hay nada pendiente en Supabase.

PENDIENTE: confirmar que el git push de este bloque ya se hizo (deberia
estar hecho al cierre de esta sesion; si no, hacerlo antes de seguir).

Con este bloque queda 1 de 6 pasos de la Fase 6 cerrado (6.1). El siguiente
paso sin construir es el 6.2 (Estudio de publicacion: foto estandarizada +
resena + datos, lista para Instagram) -- preguntarle al propietario si sigue
por ahi o prefiere otro orden antes de proponer nada.
```
