# Especificación del Dashboard — Salón y Más

**Creado:** 8 de agosto de 2026 · **Decisión rectora:** D-110
**Reemplaza:** el Dashboard actual (6 tarjetas de conteo)
**Es el documento contra el que se construyen las tareas 2.5a, 2.5b y 2.5c.**

> Se escribe antes que el código por lo mismo que la Agenda (D-101): son cuatro
> vistas y una docena de indicadores, y a mitad de camino íbamos a estar
> discutiendo qué significa "cliente activo".

---

## 1. Qué responde el Dashboard

Una sola pregunta:

> **¿Cómo está mi negocio hoy y qué debería hacer ahora?**

Lo que hay hoy no la responde. Muestra seis conteos —clientes, servicios,
estilistas— y una tarjeta llega a decir *"Tickets confirmados en Supabase"*: el
nombre de la base de datos, en la cara del dueño de un salón.

### La tesis

**Un número solo no comunica. Un número comparado sí.**

`$1.280.000` no dice nada. `$1.280.000 ↑ 18,4%` es una historia. Por eso el
motor de comparación no es una tarjeta más: **es el cimiento, y se construye
primero.**

### Los tres niveles de lectura

| Nivel | Tiempo | Qué entiende |
|---|---|---|
| 1 | 5 segundos | ¿Estoy bien o estoy mal? |
| 2 | 30 segundos | ¿Por qué? |
| 3 | 2 minutos | ¿Qué profesional, qué servicio, qué día, qué sede? |

La Vista 1 cubre los niveles 1 y 2. Las vistas 2, 3 y 4 cubren el 3.

---

## 2. Las dos reglas de oro

### Regla 1 — Nunca mostrar una precisión que los datos no soportan

Esta regla nació de descartar *"dinero potencial perdido"*. Decirle a una
peluquería **"perdiste $3.240.000"** cuando en realidad Erick libraba ese día,
María estaba de vacaciones y el negocio decidió no abrir, **no es un error de
cálculo: es una mentira que destruye la confianza en todo lo demás**. Y la nota
al pie que lo explica no la lee nadie después de leer la cifra.

Cuando no se pueda ser exacto:

- se dice **estimado**, con esa palabra;
- se muestra **de dónde salió el número**;
- o **no se muestra**.

### Regla 2 — Todo número importante puede decir de dónde salió

Junto a cada indicador sensible, un ⓘ que explique el cálculo en lenguaje de
persona:

> **Horas vendidas · 156 h** ⓘ
> Suma de la duración de los servicios de tickets cobrados entre el 1 y el 8 de agosto.

Esto no es adorno. Es lo que permite que el día que existan horarios por
profesional, un indicador pase de *estimado* a *real* sin que nadie tenga que
adivinar qué cambió.

---

## 3. Diccionario de indicadores

**Ningún indicador se programa sin estar en esta tabla.** Si aparece uno nuevo,
primero entra aquí.

### 3.1 Dinero

| Indicador | Fórmula exacta | Fuente | Estado |
|---|---|---|---|
| **Ventas** | Suma de `ticket_payments.amount` con estado `registrado`, en el período | `ticket_payments` | ✅ existe |
| **Por cobrar** | Tickets `finalizado` con saldo pendiente | `tickets` + `ticket_payments` | ✅ existe |
| **Compras** | Suma de `purchases.total_amount` | `purchases` | ✅ existe |
| **Gastos** | Suma de `expenses.amount` | `expenses` | ✅ existe |
| **Comisiones** | Suma de `stylist_commissions.commission_amount` con estado `generada` | `stylist_commissions` | ✅ existe |
| **Resultado estimado** | Ventas − Compras − Gastos − Comisiones | derivado | ✅ existe |
| **Margen** | Resultado ÷ Ventas | derivado | ⬜ trivial |
| **Ticket promedio** | Ventas ÷ tickets cobrados | derivado | ⬜ trivial |

> **Ventas es dinero cobrado, no facturado.** Un servicio terminado y sin
> cobrar **no suma a ventas**: vive en *Por cobrar*. Hay que decirlo en la
> pantalla, o el propietario va a jurar que el dashboard le resta plata. Es
> además coherente con la regla del cero de la Agenda (D-101).

### 3.2 Operación

| Indicador | Fórmula exacta | Estado |
|---|---|---|
| **Citas** | Tickets con fecha en el período, **excluyendo** `cancelado` | ⬜ |
| **Atendidas** | Tickets en `finalizado` o `cerrado` | ⬜ |
| **Pendientes** | Tickets en `solicitado`, `cotizado`, `apartado`, `confirmado`, `en_espera`, `en_proceso` | ⬜ |
| **Canceladas** | Tickets en `cancelado` | ⬜ |
| **No asistió** | Tickets en `no_asistio` | ⬜ |
| **Horas vendidas** | Suma de la duración de los servicios de tickets cobrados | ⬜ |

**Cancelado y no asistió se cuentan aparte, nunca dentro de "Citas".** No es lo
mismo *18 citas* que *20 citas, 18 atendidas, 2 no asistió*: la segunda es una
historia y la primera es un dato.

### 3.3 Clientes

| Indicador | Definición exacta | Estado |
|---|---|---|
| **Cliente atendido** | Tiene al menos un servicio cobrado dentro del período | ⬜ |
| **Cliente nuevo** | Su **primera** atención registrada cae dentro del período | ⬜ |
| **Cliente recurrente** | Ya tenía una atención anterior al período y volvió dentro de él | ⬜ |
| **Tasa de retorno** | Recurrentes ÷ atendidos | ⬜ |
| **Cliente en riesgo** | Sin atención en más de 45 días, habiendo tenido dos o más antes | ⬜ |
| **Valor del cliente (CLV)** | Total histórico cobrado ÷ clientes con al menos una atención | ⬜ |

> **Atendido ≠ registrado.** Un cliente creado y nunca atendido no cuenta. Hoy
> el Dashboard muestra "Clientes del negocio: 4", que son los registrados —
> justamente el número que no sirve.

---

## 4. La comparación

### 4.1 Una sola regla para cualquier largo

El propietario elige un rango —un día, una semana, uno o varios meses, un año,
o **dos fechas cualesquiera**— y el sistema busca **el rango anterior del mismo
tamaño**. No hay una tabla de casos: hay una regla.

Pero esa regla tiene **dos formas**, y cada atajo declara cuál usa, porque
*"¿cómo voy este mes?"* y *"¿cómo vengo últimamente?"* son dos preguntas
distintas.

#### Calendario — "cómo voy este mes"

Se compara contra **el mismo tramo** del período calendario anterior.

| Atajo | Hoy es 8 de agosto | Se compara contra |
|---|---|---|
| Hoy | 8 ago | 7 ago |
| Esta semana | lun 4 – vie 8 | lun 28 jul – vie 1 ago |
| Este mes | 1 – 8 ago | **1 – 8 jul** |
| Este año | 1 ene – 8 ago | 1 ene – 8 ago del año pasado |

**Nunca contra el período anterior completo.** Comparar el 1–8 de agosto contra
todo julio haría que cualquier negocio pareciera hundirse los primeros veinte
días de cada mes.

Cuando el día no existe en el mes anterior (31 de marzo contra "31 de febrero")
se usa el último día de ese mes.

#### Rodante — "cómo vengo últimamente"

Se compara contra **la ventana inmediatamente anterior del mismo largo**.

| Atajo | Rango | Se compara contra |
|---|---|---|
| Últimos 30 días | 10 jul – 8 ago | 10 jun – 9 jul |
| Últimos 3 meses | 8 may – 8 ago | 8 feb – 7 may |
| Rango libre | lo que elija | los mismos días, justo antes |

Los atajos de **2, 3, 4… hasta 12 meses** y el **rango libre** son rodantes.

### 4.2 Cuando no alcanza la historia

Son **dos situaciones distintas y se dicen distinto**:

| Situación | Qué se muestra |
|---|---|
| El rango anterior empieza **antes de que el negocio existiera** | *"Para comparar trimestres necesitas 6 meses de historia. Llevas 1. **Mira el último mes →**"* |
| El negocio ya existía pero **no hubo movimiento** | *"El período anterior no tuvo movimiento"* |

La primera dice *espera*; la segunda dice *mejoraste*. **Nunca se muestra `↑ 0%`
ni `↑ ∞%`.**

> **Este aviso no es un caso raro: es el estado normal del primer año.** Los
> datos del negocio propio arrancan el 10 de julio de 2026 — poco más de un mes.
> Comparar un trimestre pide seis meses; comparar un año, dos. Lo mismo le pasa
> a cada negocio que se registre. Por eso el aviso **dice cuánto falta y ofrece
> el rango más largo que sí se puede mirar**, en vez de disculparse en gris.

### 4.4 Zona horaria

**Todos los cálculos usan la zona de la sede** (`branches.timezone`,
`America/Bogota`), nunca UTC ni la del navegador.

El Dashboard actual no la usa. Sin esto, un cobro de las 7:30 de la noche cae
en el día siguiente y el cierre de caja no cuadra sin que nadie entienda por
qué.

---

## 5. Alcance: sede o negocio

**Selector propio en el Dashboard**, arriba, con **"Todas las sedes" por
defecto** — porque "¿cómo va mi negocio?" para quien tiene dos locales son los
dos juntos.

**Todos los indicadores respetan lo elegido. Sin mezclas.** Hoy están mezclados
sin que nadie lo decidiera: las citas son de la sede seleccionada y los
clientes de todo el negocio. Con dinero de por medio eso es inaceptable.

### Quién ve qué

No es una regla de pantalla, es de servidor. `get_my_branch_context_v2` ya
devuelve **solo las sedes de las que cada quien es miembro**:

| Rol | Sedes que recibe |
|---|---|
| Propietario | Todas las del negocio, por su rol |
| Admin, asistente, estilista | Solo aquellas donde tiene membresía |

Un asistente no es que no vea el selector: **el servidor nunca le manda la otra
sede**. Con una sola sede accesible, el selector no se dibuja.

**El Dashboard sigue siendo de propietario y admin.** El estilista tiene su
propio "Mi panel financiero".

---

## 6. Vista 1 — Resumen

Lo único que se construye en 2.5a.

```
┌──────────────────────────────────────────┐
│ Buenos días, Yelimar                     │
│ Tu negocio va +12% este mes              │
│                     [Todas las sedes ⌄]  │
│                     [Mes ⌄]              │
├────────┬────────┬────────┬───────────────┤
│ Ventas │ Citas  │Clientes│ Ticket prom.  │
│ $24,8M │  428   │  361   │    $58K       │
│ ↑12,4% │ ↑6,0%  │ ↓2,1%  │   ↑11,0%      │
├──────────────────────────────────────────┤
│ [Ventas ⌄]        ← un solo gráfico      │
│                                          │
│         ╭──╮                             │
│   ╭─────╯  ╰──╮                          │
│                                          │
│ Tu mejor día fue el sábado con $2.450.000│
├──────────────────────────────────────────┤
│ Agenda de hoy                            │
│ 12 citas · 9 atendidas · 3 pendientes    │
│ 156 horas vendidas  ↑12% vs semana ant.  │
├──────────────────────────────────────────┤
│ Lo que deberías mirar                    │
│ El ticket promedio subió 11%             │
│ 47 clientes no vuelven hace 45 días      │
└──────────────────────────────────────────┘
```

**Cuatro indicadores protagonistas, un gráfico, la agenda y dos o tres avisos.
Nada más.** El resto de los indicadores existen, pero viven detrás, en las
vistas 2, 3 y 4.

**Un solo gráfico con selector** hace el trabajo de cuatro: Ventas, Citas,
Clientes o Ticket promedio.

---

## 7. Los estados, que son la mitad del trabajo

Tu negocio tiene hoy **1 cita y 4 clientes**. Todos los negocios que se
registren empiezan en cero, y **el Dashboard es la primera pantalla que ven**.
Un tablero de indicadores sobre datos vacíos no se ve elegante: se ve roto.

**Se diseña primero el día cero y después el negocio lleno**, no al revés.

### 7.1 La escalera

| Momento | Qué dice el Dashboard |
|---|---|
| **Día 1** | "Bienvenida, Yelimar. Tu negocio está listo. Faltan 3 pasos." + lista de primeros pasos |
| **Primeros clientes** | "Ya tienes tus primeros clientes." |
| **Primera venta** | "¡Tu primera venta! Aquí empieza a crecer tu historia." |
| **10 ventas** | Aparece el gráfico de tendencia |
| **Primer mes cumplido** | Aparecen las comparaciones y los primeros avisos |

Esto conecta con la tarea 4.4 del plan (onboarding "Primeros pasos"), que
estaba pospuesta "hasta que la app esté visualmente terminada" (D-085). **Su
sitio natural es aquí dentro**, no en una pantalla aparte.

### 7.2 Cuándo cobra vida cada pieza

| Pieza | Umbral | Antes del umbral |
|---|---|---|
| Indicador | 1 dato | El paso pendiente que lo desbloquea |
| Gráfico | 10 ventas | "Aquí aparecerá tu tendencia de ventas." |
| Comparación | Un período anterior completo | "Todavía no hay con qué comparar" |
| Avisos | Un mes de historia | No se dibuja la sección |

### 7.3 Vacío y error son cosas distintas

Se usan `EmptyState` y `ErrorState` (D-107). **Vacío invita a crear; error se
ve en rojo y ofrece reintentar.** Hoy las dos situaciones se pintan igual y no
hay forma de distinguir "todavía no hay datos" de "no se pudieron cargar".

---

## 8. Fases

| Fase | Qué entra |
|---|---|
| **2.5a** | Motor de comparación · Vista 1 completa · estados y escalera · `fl_chart` |
| **2.5b** | Horas vendidas comparadas. **Sin porcentaje de ocupación** |
| **2.5c** | Vistas 2 (Negocio), 3 (Clientes) y 4 (Equipo) |
| **Etapa 4** | Intelligence: dato → interpretación → oportunidad → **acción** |

El botón **"Enviar campaña de reactivación"** pertenece a la Etapa 4: necesita
WhatsApp (4.1, aplazado dos veces) o correo (Resend, en sandbox hasta 3.10). El
aviso *"47 clientes no vuelven hace 45 días"* sí se puede dar en 2.5a. **El
aviso sí, el botón todavía no.**

---

## 9. Fuera de alcance, y por qué

| Idea | Por qué no |
|---|---|
| **Dinero potencial perdido** | Regla 1. Afirma una certeza que el sistema no tiene. Vuelve cuando existan horarios por profesional |
| **% de ocupación** | Mismo motivo. El horario está guardado **por negocio**, no por profesional: un estilista de medio tiempo aparecería al 40% aunque no tuviera un hueco libre |
| **Ocupación observada** | Se descartó al verificar: **no existe fichaje ni registro de horas trabajadas**. Sin denominador real no se puede |
| **Propinas** | No existe la columna. Es un cambio en el flujo de cobro, no en el Dashboard |
| **Horarios por profesional** | Es una pantalla nueva. Se decide cuando un negocio real lo pida |
| **Dashboard para estilista** | Ya tiene "Mi panel financiero" |

**La arquitectura se deja preparada** para que, cuando existan los horarios
individuales, el cálculo de capacidad entre sin rehacer nada: por eso las horas
vendidas se guardan como magnitud propia y no como el numerador de una fracción.

---

## 10. Dependencias

- **`fl_chart`** — única dependencia nueva prevista en todo el plan de
  lanzamiento.
- Componentes de D-107: `AppCard`, `EmptyState`, `ErrorState`, `LoadingCard`.
- Tema de D-109: **todos los gráficos leen los colores de marca del negocio**, y
  ninguno usa los colores de estado, que siguen fuera de la marca blanca
  (D-097).

## 11. En celular

Los cuatro indicadores pasan a dos columnas; el gráfico conserva su ancho y se
desplaza en horizontal dentro de su propia tarjeta, nunca la página. La barra
inferior sigue teniendo cuatro módulos y "Más" (D-105).

---

*Este documento se actualiza al cerrar cada fase. Si una definición cambia, se
registra primero en `REGISTRO_DE_DECISIONES.md`.*
