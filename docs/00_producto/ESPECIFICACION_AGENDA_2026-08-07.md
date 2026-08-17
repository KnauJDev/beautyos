# Especificación de la Agenda — tablero de tickets

**Fecha:** 7 de agosto de 2026 · **Decisión asociada:** D-101
**Se construye en:** tarea 2.6 del `PLAN_DE_LANZAMIENTO_2026-08-06.md`, después
de 2.2 y 2.3. **No antes**: montarla sobre los 302 colores sueltos y sin
componentes base obligaría a rehacerla entera.
**Origen:** bocetos a mano del propietario, 7 de agosto de 2026.

---

## 0. Agenda y Tickets se separan por nivel, NO se fusionan

> ⚠️ **Corregido el 09-ago (D-116).** Este apartado decia que los dos modulos
> se fusionaban y que Tickets desaparecia del menu. **Ya no.** El propietario
> freno la fusion justo antes de ejecutarla y tenia razon: el argumento que la
> justificaba se cae solo en cuanto Agenda pasa a ser el tablero.
>
> | Modulo | La pregunta que responde | Nivel |
> |---|---|---|
> | **Agenda** | *"¿Que me falta hoy / esta semana / como viene el mes?"* | 1 — el tablero de este documento |
> | **Tickets** | *"Muestrame el detalle"* — desde el menu y desde la tarjeta de ticket promedio del Dashboard | 2 y 3 |
>
> **Por que dejo de aplicar el argumento de D-105:** era cierto que Agenda no
> devolvia ni una columna que Tickets no tuviera, y por eso eran dos puertas al
> mismo sitio. Pero **el tablero no lista tickets: los cuenta** por estado y por
> tiempo. Deja de ser un subconjunto y pasa a ser otro nivel. Y la regla del
> cero se resuelve con el tablero — donde "Cerrado" es una columna mas —, no
> con borrar el modulo.
>
> **La condicion que impide repetir el problema:** el listado de tickets tiene
> que ser **un solo componente de codigo con dos entradas**. Desde una casilla
> del tablero llega filtrado por dia y estado; desde Tickets llega sin filtro y
> con buscador. Dos listas separadas volverian a ser dos pantallas casi iguales
> que se desincronizan.
>
> Lo que sigue de este apartado es **el analisis original del 07-ago**, que se
> conserva porque explica por que los tres niveles son los que son.

**Lo decidido el 07-ago (D-105), y por que:** hasta entonces eran dos entradas
de menu, y al revisarlo resultaron ser lo mismo:

| | Agenda | Tickets |
|---|---|---|
| Filtra por estado | Solo `confirmado`, `en_espera`, `en_proceso` | Ninguno |
| Orden | Cronologico hacia adelante | Mas reciente primero |
| Columnas | cliente, fecha, estado, servicio, estilista, precio, duracion | **Las mismas** + canal, pagado, saldo, estado de pago |

La Agenda **no tenia ni una columna que Tickets no tuviera**: era un
subconjunto de los mismos tickets, filtrado a tres estados y sin la
informacion de dinero. Los propios bocetos del propietario decian "tickets" en
el titulo de lo que llamaba agenda.

**Se unifican en tres niveles:**

| Nivel | Que es | De donde sale |
|---|---|---|
| 1 | El tablero de dia, semana y mes | Lo nuevo de esta especificacion |
| 2 | La lista ampliada al tocar una casilla | Es la pantalla de Tickets de hoy |
| 3 | El ticket con sus acciones: cobrar, reprogramar, cambiar estado, agregar foto | Ya existe dentro de Tickets |

**Se llama "Agenda" en el menu**, que es la palabra que usa una duena de
peluqueria, aunque por dentro sea un tablero de tickets. El modelo de tickets
es el diferenciador del producto; el nombre debe ser el que busca el cliente.
**Esto sigue vigente.**

~~**Beneficio adicional:** deja de haber que adivinar cual de los dos abrir, y
se libera un puesto en el menu -- que en celular vale oro. Ademas la regla del
cero solo funciona asi: la Agenda de hoy oculta los cerrados, con lo cual nunca
se podria comprobar que todo quedo en cero.~~
**Anulado por D-116:** la regla del cero la resuelve el tablero, no la fusion.
El puesto de menu no se libera, y esta bien: la tarjeta del Dashboard necesita
un destino y el detalle del ticket merece pantalla propia.

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

> ⚠️ **Enmienda del 17-ago (D-147): granularidad de 15 minutos en vista Día.**
> Aunque el boceto original agrupaba por horas completas (8:00 a 20:00), el servidor y la interfaz admiten granularidad de 15 minutos (`'15min'`) por defecto para registrar servicios rápidos (cejas, barba, express) y slots de atención precisos sin perder la visión agregada.

**Filas:** las horas y cuartos de hora de atención del negocio (por ejemplo 8:00 a 20:00 en tramos de 15 min).
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
impresentable para un humano. Hace falta un **consecutivo legible**, decidido
el 07-ago:

- **Uno solo por negocio**, no por sede. Así el número dice cuántos servicios
  ha prestado el negocio en total.
- **Arranca en `0000001`** y no se reinicia por año ni por sede.
- **Sin prefijo de sede.**
- Los tickets que ya existen reciben número por orden de creación.

> ⚠️ **Corregido el 09-ago (D-117): el consecutivo SÍ se puede ajustar.**
> Aquí decía "no se reinicia **nunca**". El propietario pidió poder fijarlo,
> para seguir un consecutivo que ya trae de antes, un número propio, o una
> numeración autorizada DIAN si algún día la maneja. **Lo de arriba se conserva
> como valor por defecto, no como camisa de fuerza.** Las reglas del ajuste:
>
> 1. **Un número emitido no se reescribe jamás.** Ajustar afecta a los tickets
>    futuros. Protegido con un *trigger* en la base, no con una promesa.
> 2. **El nuevo punto de partida debe ser mayor que el último emitido.** Es la
>    única forma de que "único" siga siendo cierto, y el choque se rechaza en la
>    base y no a mitad de un cobro.
> 3. **Ajustar es exclusivo del propietario del negocio**, igual que el logo, la
>    portada y el tema (D-109): tiene consecuencias contables.
>
> Se guardan **dos** columnas: `ticket_number` (ordena y garantiza unicidad
> aunque el prefijo cambie) y `ticket_code` (lo que ve la persona, congelado con
> el prefijo y los ceros del día de emisión).
>
> **La pantalla para ajustarlo va en 2.11**, no aquí: lo que hay que dejar bien
> hecho desde el nacimiento es la estructura, porque cambiarla con tickets ya
> emitidos es carísimo.

> **Intención a futuro del propietario:** enlazarlo con el número de factura o
> la factura electrónica. **Aviso, para que nadie se confunda: esto NO es
> facturación electrónica.** La numeración autorizada real trae número de
> resolución, rango con fecha de vencimiento y reglas de agotamiento. Aquí solo
> queda el campo listo y limpio por si termina siendo su base. El paso real es
> la tarea **D4 del plan**: consultar al contador.

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

| # | Asunto | Estado |
|---|---|---|
| A | Formato del consecutivo de ticket | ✅ Resuelto — ver 8.1 |
| C | Horas sin actividad en la vista día | ✅ Resuelto — **se muestran igual**, con un `-` o un punto. El propietario lo argumentó bien: es raro que en una hora no haya *nada* en *ningún* estado, así que ocultar filas haría saltar la cuadrícula sin ganar casi espacio |
| B | Si el estilista recibe un resumen agregado de **su** día | ⬜ **Pendiente a propósito.** Se diseña aparte, mirando qué necesita ver de verdad, cómo y dónde. No se improvisa dentro de esta pantalla |

---

## 10. Lo que se descartó, y por qué

| Idea | Motivo |
|---|---|
| Cuadrícula hora × día con las citas dentro (primer boceto) | Se rompe con dos estilistas a la misma hora y no cabe en celular |
| Las mismas columnas en las tres vistas | Cada vista responde una pregunta distinta: "en proceso" es urgente hoy y ruido en la semana. La consistencia se mantiene en los ejes, no en las columnas |
| Números por estado escritos en cada casilla del mes | 35 casillas de 45 píxeles. Solo funcionaría en computador |
| Cancelado y no asistió como columnas | Romperían la regla del cero: nunca bajan |
