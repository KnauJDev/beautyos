# Especificación de la Agenda — tablero de tickets

**Fecha:** 7 de agosto de 2026 · **Decisión asociada:** D-101
**Se construye en:** tarea 2.6 del `PLAN_DE_LANZAMIENTO_2026-08-06.md`, después
de 2.2 y 2.3. **No antes**: montarla sobre los 302 colores sueltos y sin
componentes base obligaría a rehacerla entera.
**Origen:** bocetos a mano del propietario, 7 de agosto de 2026.

---

## 1. La idea en una frase

La agenda deja de ser un calendario y pasa a ser un **tablero de control de
tickets**: en vez de pintar citas una por una, cuenta cuántas hay en cada
estado, y deja profundizar hasta el detalle cuando hace falta.

### Por qué esto y no un calendario normal

1. **Es una lista de cierre, no una agenda.** La regla que lo define, en
   palabras del propietario: *"al final del día todas las columnas deberían
   quedar en cero excepto cerrado"*. Ninguna agenda de calendario responde
   "¿qué me falta hoy?" de un vistazo. Esta sí.
2. **Resuelve el choque de estilistas simultáneos.** Un calendario con celdas
   de hora × día se rompe cuando dos estilistas atienden a la misma hora:
   obliga a una columna por estilista, que en celular no cabe. Contando,
   un 2 es un 2 tenga un estilista o cuatro.
3. **Cabe en un teléfono.** Una cuadrícula de números entra; una de tarjetas
   con cliente, servicio y precio, no.

### Para quién

**Dueño, administrador y asistente.** Los tres controlan el negocio y esta es
su herramienta.

**El estilista NO usa esta pantalla.** Su pregunta es otra —*"¿a quién atiendo
y a qué hora?"*— y los contadores no la responden. Conserva su "Mi agenda"
actual, que es una lista de sus propias citas.

---

## 2. Regla común a las tres vistas

> **El tiempo va en las filas. Los estados van en las columnas.**

Es lo único que se mantiene idéntico entre vistas, y basta para que se lean
parecido sin tener que reaprender nada.

**Las columnas sí cambian entre vistas, a propósito.** Cada vista responde una
pregunta distinta, así que necesita información distinta: "en proceso" es
urgente hoy y es ruido en la semana.

**Al hacer clic en cualquier casilla** se abre la lista ampliada de esos
tickets (sección 6).

**Cancelados y no asistió nunca son columna.** Romperían la regla del cero: un
cancelado se queda ahí para siempre y parecería trabajo pendiente. Van como
contador aparte, fuera de la cuadrícula: *"2 canceladas · 1 no asistió"*.

---

## 3. Vista DÍA — *"¿qué me falta hoy?"*

**Filas:** las horas de atención del negocio (por ejemplo 8:00 a 20:00).
**Selector:** por defecto hoy, con opción de elegir otro día.

| Columna | Agrupa los estados | Qué te dice |
|---|---|---|
| **Por confirmar** | `solicitado`, `cotizado`, `apartado` | Alguien pidió algo y falta tu respuesta |
| **Confirmado** | `confirmado`, `en_espera` | Listo, va a pasar |
| **En proceso** | `en_proceso` | Está sucediendo ahora |
| **Por cobrar** | `finalizado` | Terminó y hay plata en la calle |
| **Cerrado** | `cerrado` | Cobrado y cerrado |

**Cómo se lee:** al final de la jornada, todas las columnas en cero salvo
"Cerrado". Cualquier número distinto de cero en las otras cuatro es trabajo
pendiente.

**Detalle visual:** los ceros se atenúan para que el ojo vaya solo a los
números que importan.

---

## 4. Vista SEMANA — *"¿qué tengo sin cerrar comercialmente?"*

**Filas:** los siete días de la semana. **Selector:** rango "del ▢ al ▢".

Aquí los estados van **separados, no agrupados**: el trabajo de la semana es
mover cada pedido de un estado al siguiente, así que hay que distinguirlos.

| Columna | Estado | Para qué |
|---|---|---|
| **Solicitado** | `solicitado` | Entró por el enlace público |
| **Cotizado** | `cotizado` | Se pasó precio, falta respuesta |
| **Apartado** | `apartado` | Reservado, falta confirmar |
| **Confirmado** | `confirmado` | Convertido |
| **Por cobrar** | `finalizado` | Que no quede nada sin cobrar |
| **Cerrado** | `cerrado` | Base para estadísticas y cierre de caja |

**"En proceso" no aparece:** es una foto de este instante, irrelevante a
escala de semana.

**Cómo se lee:** el objetivo de la semana es que las tres primeras columnas
vayan bajando y "Confirmado" vaya subiendo.

**Detalle visual:** el día de hoy se marca; los días pasados se atenúan. La
regla del cero **no aplica igual aquí**: en un día pasado, un cero es sano; en
uno futuro, un cero en "Confirmado" es mala señal, no buena.

---

## 5. Vista MES — *"¿cómo viene el negocio?"*

**Cuadrícula de calendario** (domingo a sábado). **Selector:** mes y año.

Cada día muestra:

- **Un número grande:** el total de tickets de ese día.
- **Una barra delgada de colores** debajo, con la mezcla de estados en
  proporción.
- Los días sin actividad muestran un punto, no un cero.
- **Hoy** se marca con borde morado.

**Por qué así y no con los números escritos por estado:** un mes son 35
casillas; en un celular cada una mide unos 45 píxeles de ancho. Ahí no caben
cuatro líneas de texto. La barra conserva toda la información en un formato
que el ojo procesa de un golpe.

**Cómo se lee:**

- Días pasados **casi todo gris** = mes sano, lo que pasó se cerró.
- Coral o ámbar en un día pasado = **algo quedó abandonado**.
- En días futuros no hay gris, y está bien. Lo que se busca es que el ámbar
  baje y el verde suba.

**Al tocar un día** se abre la vista de día completa.

---

## 6. La lista ampliada (al hacer clic en una casilla)

Lista de los tickets de esa casilla, con:

| Campo | Estado |
|---|---|
| **Número de ticket** | ⚠️ **NO EXISTE, hay que construirlo** (ver 8) |
| Cliente | ✅ ya existe |
| Servicio | ✅ |
| Estilista | ✅ |
| Valor del servicio | ✅ |
| Pagos o abonos | ✅ |
| Saldo | ✅ |
| Estado exacto | ✅ — aquí se ve si es `cotizado` o `apartado`, que en la vista día van agrupados |

---

## 7. Colores de estado

Independientes de la marca blanca (D-097): significan lo mismo en todos los
negocios, tengan el tema que tengan.

| Estado | Color | Por qué |
|---|---|---|
| Por confirmar / solicitado | Ámbar `#EF9F27` | Requiere tu atención |
| Confirmado | Verde `#639922` | Todo bien |
| En proceso | Azul `#378ADD` | Sucediendo ahora |
| **Por cobrar** | **Coral `#D85A30`** | Requiere acción, **pero no es un error** |
| Cerrado | Gris `#888780` | Ya no requiere nada |
| Cancelado / no asistió | Rojo | Algo salió mal |

**Por qué "Por cobrar" es coral y no rojo:** si ambos fueran rojos, un día con
muchos cobros pendientes parecería un desastre cuando en realidad es un buen
día de trabajo sin cerrar caja.

---

## 8. Lo que hay que construir en el servidor

Esto **no es rediseño, es funcionalidad nueva**. Hoy la agenda es una lista
plana sin filtro de fecha.

### 8.1 Número de ticket (bloqueante para la lista ampliada)

Los tickets solo tienen identificador interno (`3f2b8c1a-9d4e-…`),
impresentable para un humano. Hace falta un **consecutivo legible por
negocio**, y decidir:

- ¿Se reinicia cada año? ¿Lleva prefijo de sede?
- ¿Qué número reciben los tickets que ya existen?

### 8.2 Dos funciones nuevas, no seis

Las tres vistas se sirven con una sola función de conteo, cambiando la
agrupación:

| Función | Devuelve |
|---|---|
| `get_ticket_board_counts_v2(sede, desde, hasta, granularidad)` | Filas de `(bucket, estado, cantidad)`, donde el bucket es la hora, el día o la fecha según la vista |
| `get_ticket_board_list_v2(sede, desde, hasta, estados)` | La lista ampliada del punto 6 |

Ambas deben autorizar `tenant_owner`, `admin` y `assistant` — y **la
autorización se extiende, no se reescribe** (regla de D-095).

### 8.3 Filtro de fecha en la agenda

Hoy no existe para ningún rol (hallazgo del 06-ago). Queda cubierto por estas
funciones.

---

## 9. Pendiente de decidir

| # | Asunto |
|---|---|
| A | Formato del consecutivo de ticket y qué pasa con los ya existentes |
| B | Si el estilista recibe algún resumen agregado de **su** día, o se queda solo con su lista actual |
| C | Si las horas sin actividad se ocultan en la vista día o se muestran vacías |

---

## 10. Lo que se descartó, y por qué

| Idea | Motivo |
|---|---|
| Cuadrícula hora × día con las citas dentro (primer boceto) | Se rompe con dos estilistas a la misma hora y no cabe en celular |
| Las mismas columnas en las tres vistas | Cada vista responde una pregunta distinta: "en proceso" es urgente hoy y ruido en la semana. La consistencia se mantiene en los ejes, no en las columnas |
| Números por estado escritos en cada casilla del mes | 35 casillas de 45 píxeles. Solo funcionaría en computador |
| Cancelado y no asistió como columnas | Romperían la regla del cero: nunca bajan |
