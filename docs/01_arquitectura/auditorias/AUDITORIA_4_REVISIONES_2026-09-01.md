# Auditoría pre-lanzamiento en 4 revisiones — expediente de verificación

**Abierto:** 1 de septiembre de 2026 · **Estado:** en curso (2 de 4 revisiones recibidas)

> **Este documento NO manda sobre el plan.** No dice qué falta ni en qué orden:
> eso sigue siendo `PLAN_MAESTRO.md` (regla de D-126 / D-131). Aquí solo se
> guarda **la evidencia**: qué afirmó cada revisión, qué se comprobó contra el
> código real, y qué quedó confirmado, matizado o refutado.
>
> Cuando las 4 revisiones estén cerradas, lo que sobreviva a la verificación
> entra al Plan Maestro como pasos o como hallazgos, con su `D-XXX`. Entonces
> **este archivo deja de tener autoridad y queda como expediente**.

---

## 1. De dónde viene esto

El propietario abrió una auditoría en cuatro revisiones antes de lanzar
comercialmente. Las revisiones amplias las hace **Antigravity** (ventana de 2M
tokens, lee el repo entero); **Claude Code verifica cada hallazgo contra el
código real** antes de que se convierta en trabajo.

**Regla acordada, y es la razón de ser de este archivo:** ningún hallazgo de
Antigravity se ejecuta sin pasar por verificación — con prioridad absoluta en
auth, RPC y pagos.

Parte del contexto llegó en un `HANDOFF_SalonYMas_Auditoria.md` traído de un
chat de claude.ai (que no comparte memoria con Claude Code). Ese archivo se
absorbió aquí; **su contenido está corregido en el apartado 2 y no debe usarse
como fuente**.

---

## 2. Correcciones al handoff importado

El handoff de claude.ai describe un proyecto más pequeño y más atrasado del que
existe. Nada de esto es culpa de ese chat: no tenía el repositorio delante.

| Afirmación del handoff | Realidad verificada hoy |
|---|---|
| "llegó al paso 1.085 de una bitácora" | La bitácora va por el **paso 1.430** (`HANDOFF_BeautyOS_pasos_1418_1430.txt`, 17-ago) |
| "22.000+ líneas de código" | **50.840 líneas** en 197 archivos `.dart` bajo `lib/` |
| `tickets_page.dart` ~3.699 líneas | **4.787 líneas** |
| "`TicketRow` en ~1172-1205" | Ahí está su **invocación**. La clase vive en **3985**, su `build()` en **4012** |
| "`CreateAppointmentDialogState` corta en 1370" | El `build()` empieza en **1674** y termina en **2042**. Está entero en el repositorio |
| Revisión 1 (técnica, TL-01..TL-20) "ya guardada" | ⚠️ **No existe en ninguna parte del disco.** Ver apartado 6 |
| Estado del producto | **Fases 0 a 7 cerradas.** Fase 8 con 7 de 8 pasos cerrados. 180 decisiones registradas (D-001 a D-180). `flutter analyze` 0/0 y 262/262 pruebas al 30-ago |

**Consecuencia práctica:** varias líneas citadas por la Revisión 2 apuntan a
código que se movió. Los hallazgos se verificaron **por nombre de clase**, no
por número de línea.

---

## 3. Revisión 2 (UX Lead) — verificación contra el código real

Los tres hallazgos que el handoff dejó abiertos ya están cerrados. No hizo falta
pedirle nada más a Antigravity: el código está en este repositorio.

### UX-01 — Cita express · ✅ **CONFIRMADO, y con una agravante que la auditoría no vio**

`CreateAppointmentDialogState.build()`, `tickets_page.dart:1674-2042`.

Es secuencial-obligatorio, y no de forma sutil: **está numerado en la propia
interfaz**: `1. Servicio`, `2. Estilista disponible`, `3. Fecha y hora
disponible`, `4. Cliente`.

- El desplegable de estilista tiene `onChanged: selectedServiceId == null ? null : ...` — **deshabilitado por completo** hasta elegir servicio (1690-1737).
- Elegir estilista dispara `_loadAvailableSlots()`, que es **ida y vuelta a red** con `CircularProgressIndicator` y el texto *"Calculando disponibilidad..."* (1789).
- Los chips de hora solo se dibujan si hay servicio **y** estilista **y** fecha (1778-1780).
- Cambiar el servicio **borra** estilista, hora y disponibilidad (1707-1713).

**Matiz a favor del código, que la auditoría no registró:** el paso 4 (Cliente)
**no está bloqueado** — se puede elegir en cualquier momento, y tiene *"Crear
cliente rápido"* en línea (1867-1885). O sea: son 3 pasos encadenados, no 4.

**La agravante:** `PublicBookingPage` — la pantalla que usa **la clienta desde la
calle** — sí ofrece *"Cualquiera disponible"* combinando horarios de todo el
equipo (D-166, 28-ago). El mostrador del salón **no tiene esa opción**. Hoy la
clienta que reserva sola tiene mejor flujo que la recepcionista que la atiende de
frente. Eso abarata el arreglo: la lógica de "cualquiera disponible" **ya está
escrita y probada**, solo no se reutilizó aquí.

### UX-05 — Jerarquía visual de `TicketRow` · ❌ **REFUTADO como problema de UX** (sí hay un hallazgo técnico menor)

`TicketRow.build()`, `tickets_page.dart:4012-4278`.

La tarjeta **no muestra 8 ni 9 botones compitiendo**. Muestra **como mucho 3**, y
con jerarquía correcta y deliberada:

1. `Ver ficha` — `OutlinedButton` (secundario)
2. `Pagos y saldo` — **`FilledButton.tonalIcon`**, el único relleno: es la acción de dinero y **visualmente domina**
3. `Estado` — `OutlinedButton` (secundario)

**El hallazgo original está mal leído:** confundió los *callbacks del
constructor* con *botones dibujados*. Las demás acciones no viven aquí, viven en
la Ficha Nivel 3 (`_TicketDetailSheet`, D-152).

**Lo que sí aparece, y es hallazgo nuevo:** de los 8 callbacks que `TicketRow`
exige como `required`, **cinco no se usan jamás** dentro de la clase
(`onManageServices`, `onReschedule`, `onCorrectCompletion`, `onCopyReviewLink`,
`onAddWorkPhoto`), y `onAddService` solo aparece en la condición de visibilidad
del bloque, nunca como botón. Es superficie muerta de API: obliga a cada llamada
a construir seis cierres que no se ejecutan. **Severidad: baja.** Es limpieza, no
un fallo. Encaja en la Fase 8.

### UX-02 — Los 4 destinos del móvil · ⚠️ **CONFIRMADO EN EL HECHO, EQUIVOCADO EN EL DIAGNÓSTICO**

`_MobileNavBar`, `main.dart:1450-1540`.

Cierto: `static const _visibles = 4;` y el resto va a `_abrirMas()`.

Falso: que estén *"apelmazados sin agrupar"*. `_abrirMas()` construye
`groupedRestantes` **agrupado por `BeautyCategory`** (OPERACIÓN / FINANZAS Y
GESTIÓN / PORTAFOLIO / CATÁLOGO Y AJUSTES), con encabezado por grupo.

**Y esto importa:** ese diseño **es** el cierre del hallazgo D y del paso 4.10
(D-157, 22-ago). La recomendación de Antigravity — *"simplificar `_MobileNavBar`
agrupando el Más en un grid moderno"* — pide algo que ya se hizo hace diez días.

**Lo que sí falta de verdad:** un buscador dentro de la hoja "Más". Eso es menor,
no crítico.

### UX-04 — Onboarding · ⚠️ **CONFIRMADO EN EL HECHO, PERO CHOCA CON UNA DECISIÓN DE NEGOCIO**

`complete_tenant_setup_page.dart` (441 líneas) pide 8 campos: nombre del negocio,
tipo, nombre del titular, WhatsApp, ciudad, sedes, tamaño de equipo y *"¿Cómo nos
conociste?"*. Cinco son obligatorios.

Pero esa pantalla **no es un onboarding**: se titula *"Solicitud de Registro"* y
**es el filtro de aceptación del paso 3.7 (D-138)**. El modelo de venta escrito
en el Plan Maestro es *"salón por salón, de forma personalizada — **nadie entra
solo**"*, con 25 pioneros al 50% de por vida. Ese formulario es la ficha de
venta, no una barrera accidental.

Tratarlo como fricción a eliminar **contradice el go-to-market completo**. Si
Antigravity insiste en la Revisión 3, ese es el punto exacto donde hay que
obligarlo a defender la contradicción.

**Recorte defendible, y pequeño:** desde D-162 el panel de plataforma calcula
sedes y equipo **reales** (`real_branches_count`, `real_team_count`) en vez de
los estimados del formulario. Esos dos desplegables ya no alimentan ninguna
decisión: **son 2 de los 8 campos y se pueden quitar sin tocar el modelo de
venta.**

**Y lo que la auditoría pide de verdad ya está planificado:** el checklist guiado
es el **paso 8.8**, que el propietario reservó a propósito como el último del
todo. Lo mismo que el benchmarking contra AgendaPro ya había marcado como
prioridad alta el 28-jul.

### UX-03 — Cobrar desde Agenda · ⚠️ **PARCIALMENTE RESUELTO YA**

D-163 (27-ago) hizo que la tarjeta del Nivel 2 de Agenda **abra la Ficha Nivel 3
del ticket con un toque**, y habilitó cobrar abonos desde que la cita se solicita
— el bloqueo real estaba en el RPC `register_ticket_payment`, no en la interfaz.

Queda cierto que `onOpenTicket` **cambia de pestaña**: `selectedIndex + 1`
(`main.dart:331-336`). Lo que ya no es cierto es que rompa el flujo por completo.

**Riesgo latente detectado de paso (no es de Antigravity):** ese `+ 1` asume que
Tickets es siempre el módulo inmediatamente siguiente a Agenda. **Es una
suposición documentada a propósito** (comentario de D-163 en `main.dart:325-330`:
mismos `allowedRoles`, adyacentes en la lista). Es correcta hoy. Pero **ninguna
prueba la sostiene**: el día que alguien inserte un módulo entre ambos o cambie
los roles de uno de los dos, la app llevará al usuario al módulo equivocado y
`flutter analyze` no dirá nada. Cuesta una prueba de tres líneas.

### UX-07 — Atajos de cobro · ✅ **CONFIRMADO — y es más caro de lo que la auditoría cree**

`_PaymentsDialog`, `tickets_page.dart:3671-3846`. No hay atajo de monto exacto ni
denominaciones: el valor **se teclea a mano** y el método sale de un desplegable
de cuatro opciones: `efectivo / tarjeta / transferencia / otro`.

**Lo que la auditoría no vio:** esas cuatro opciones **no son una lista de la
interfaz, son un candado de base de datos**. Están validadas dentro del RPC
`register_ticket_payment`
(`20260728100000_comisiones_por_sede_estilista_servicio.sql:295` y
`20260827100000_abonos_en_citas_activas.sql:227`).

Por eso la recomendación *"inmediata"* de Antigravity — botones de un toque para
Nequi y Daviplata — **no es un cambio de interfaz.** Es migración + control SQL +
recálculo del desglose de Reportes, en código de dinero, que es exactamente donde
las reglas del proyecto prohíben improvisar. Reportes hoy los agrupa
honestamente como *"📱 Transferencias (Nequi / Daviplata)"*
(`reports_page.dart:506`), sin fingir un desglose que no puede existir.

**Separar las dos mitades:** el botón de *"monto exacto"* (rellenar el saldo con
un toque) es interfaz pura, cuesta minutos y no toca la base de datos. Distinguir
Nequi de Daviplata es un paso con migración propia. **Son dos trabajos distintos
y solo uno es inmediato.**

### Hallazgos de la Revisión 2 aún sin verificar

UX-06 (dashboard), UX-08 (jerga), UX-09 (Compras vs. Gastos), UX-10 (caja
rápida), UX-11 (consistencia visual), UX-12 (contraste WCAG). Ninguno es crítico
y ninguno bloquea la Revisión 3.

Dos notas de entrada, para no repetir el trabajo:
- **UX-08** propone renombrar *"Tickets"* → *"Caja y Cobros"*. El módulo **ya se
  llama `Tickets & Caja`** (`main.dart:341`) desde D-157.
- **UX-09** propone fundir Compras y Gastos. Ojo: **Compras mueve inventario y
  Gastos no.** Fundirlas en la interfaz es discutible; fundirlas en el modelo
  rompe el stock.

---

## 4. El patrón, que es el hallazgo más útil de todos

De los seis hallazgos verificados, **cuatro describen la aplicación de antes del
22 de agosto**: UX-02 pide lo que hizo D-157, UX-03 pide lo que hizo D-163, UX-04
pide lo que es el paso 8.8, UX-08 pide un nombre que ya se cambió. Y UX-05 está
directamente mal leído.

No es que Antigravity mienta: **es que 2M de tokens no distinguen entre código
vigente y decisiones vigentes.** Lee `lib/`, no lee `REGISTRO_DE_DECISIONES.md`
con sus 180 entradas.

**Corrección para la Revisión 3 y la 4:** exigirle en el prompt que **cite el
`D-XXX` que contradice** cada vez que proponga cambiar algo ya decidido, y que
declare *"esto ya está hecho en D-XXX"* cuando el código lo desmienta. Sin eso, la
Revisión 3 —que es estratégica y toca precios, planes y módulos— va a volver a
proponer cosas ya decididas con su porqué escrito. Y ahí el costo del error es
mayor, porque las decisiones de precio no se ven en el código.

---

## 5. Lo que Claude aporta de este barrido (no viene de Antigravity)

| # | Hallazgo | Severidad | Dónde |
|---|---|---|---|
| C-01 | La reserva pública ofrece *"Cualquiera disponible"* (D-166); el diálogo interno de cita no. La clienta tiene mejor flujo que la recepcionista, **y la lógica ya existe** | Media — pero es el arreglo más barato de UX-01 | `tickets_page.dart:1719` vs. `PublicBookingPage` |
| C-02 | `TicketRow` exige 8 callbacks `required`; 5 no se usan nunca y 1 solo en una condición | Baja (limpieza) | `tickets_page.dart:3985-4010` |
| C-03 | El salto Agenda→Tickets (`selectedIndex + 1`) depende de una adyacencia documentada pero **sin prueba que la sostenga** | Baja hoy, silenciosa el día que rompa | `main.dart:331-336` |
| C-04 | El método de pago del ticket es un `CHECK` de base de datos, no una lista de UI: cualquier atajo de Nequi/Daviplata necesita migración | Media — **cambia el coste estimado de UX-07** | migraciones `20260728100000` y `20260827100000` |
| C-05 | Los campos *sedes* y *equipo* del formulario de registro quedaron sin uso desde D-162 (el panel calcula los reales) | Baja | `complete_tenant_setup_page.dart:294-350` |

Ninguno se ejecuta todavía. Van al Plan Maestro cuando se consoliden las 4.

---

## 6. Estado de las 4 revisiones

| # | Revisión | Estado | Nota |
|---|---|---|---|
| 1 | Técnica (TL-01 a TL-20) | ✅ **Recibida 01-sep** · 20 de 20 verificados | Apartado 9 |
| 2 | UX Lead (UX-01 a UX-12) | ✅ Recibida · 6 de 12 verificados contra código | Apartado 3 |
| 3 | Product Manager / estrategia | ✅ **Recibida y corregida 01-sep** · verificada | Apartado 10 |
| 4 | **Crítica brutal + perímetro de seguridad y datos** | ✅ **Recibida y verificada 01-sep** | Apartados 7 y 11 |

**Las cuatro revisiones están cerradas.** Lo que sigue es consolidar el plan de
acción y llevarlo al Plan Maestro con sus `D-XXX`.

**El bloqueo real de la consolidación no es la Revisión 3: es que la Revisión 1
no existe en disco.** Conviene recuperarla antes de que se pierda el hilo con
Antigravity.

**Para la Revisión 3 hay munición que Antigravity probablemente no va a mirar
sola, y que cambia el análisis:**
- `BENCHMARKING_2026-07-28.md` — comparación **con cuenta de prueba real** contra AgendaPro, incluidos sus precios ($99.000 / $150.000 / $510.000 COP).
- Plan Maestro §3 — planes, precios pioneros y límites, con el porqué de cada uno (D-124, D-136).
- **Idea I-14** — la matriz de qué módulo lleva cada plan **está sin decidir a propósito**, esperando las primeras cinco visitas a salones reales. Es justo la pregunta central de una revisión de producto, y ya tiene una razón escrita para seguir abierta.

---

## 7. Revisión 4 — definida el 1-sep

**Enfoque acordado con el propietario: crítica brutal sin filtros, con el
perímetro de seguridad y datos como eje.** Une sus nueve ejes (lo que no
funciona, lo que no tiene sentido, lo débil, lo redundante, lo riesgoso, lo
incoherente, lo poco profesional, lo que cuesta dinero, lo que cuesta usuarios)
con la auditoría de perímetro, porque los dos críticos de la Revisión 1 salieron
justamente de ahí.

**El encuadre que ordena esa revisión, y que no se sabía antes de contar el
inventario:** hay **25 tablas con RLS activado y solo 18 políticas**, con **302
apariciones de `security definer`** repartidas en **176 RPC públicas**. Es decir:
**el RLS no es la frontera de seguridad de este proyecto — es un "denegar todo"
por defecto, y la frontera real son las 176 RPC**, cada una saltándose el RLS a
propósito (ADR-004). Auditar las políticas sería auditar lo que no protege.
TL-01 (RPC de pagos sin comprobar el comercio) y TL-04 (RPC anónima que permite
enumerar clientas) son las dos primeras grietas de esa superficie.

La revisión debe entregar además **un control SQL ejecutable** contra la base
real, porque las 105 migraciones podrían no describir toda la base: el proyecto
viene de una etapa en la que se crearon objetos desde el panel de Supabase.

**Justificación del enfoque frente a rendimiento o QA:** con 262 pruebas en
verde y sin un solo cliente pagando, el riesgo caro no es la latencia. Es que un
salón vea los datos de otro, o que una suscripción se active sin que el dinero
llegue — que es exactamente lo que TL-01 permite hoy.

### Recomendación original (1-sep, antes de acordarla)

Para cerrar la auditoría, la cuarta debería cubrir lo que ninguna de las otras
tres toca: **seguridad y datos de extremo a extremo** — RLS por tenant y por
sede, superficie de las RPC `SECURITY DEFINER`, Edge Functions, y qué pasa el día
que haya que restaurar (hallazgo Z: `storage.objects` no vuelve).

Rendimiento y QA quedan por debajo: con 262 pruebas en verde y sin un solo
cliente pagando todavía, el riesgo caro no es la latencia, es que un salón vea
los datos de otro.

Decisión del propietario.

---

## 9. Revisión 1 (Técnica, TL-01 a TL-20) — verificación contra el código

Entregada el 1-sep tras el prompt correctivo. **Verificados los 20 contra el
código real.** Es una revisión buena: mucho mejor que la 2 y que la 3.

### Confirmados sin reservas — y dos son de verdad graves

| Cód. | Veredicto | Lo que se comprobó |
|---|---|---|
| **TL-01** | ✅ **CONFIRMADO · CRÍTICO** | `verify-epayco-transaction` es público (`verify_jwt = false`, D-177), acepta cualquier `ref_payco` del que llama, lo consulta contra el endpoint **público** de validación de ePayco y **nunca comprueba que la transacción sea del comercio de Salón y Más** (`x_cust_id_cliente`). Camino de ataque real: abrir una cuenta de comercio ePayco propia, generar un pago con `x_extra1 = <uuid del tenant víctima>`, y llamar a este endpoint. La validación de monto de D-159 obliga a pagar el precio real — **pero a la cuenta del atacante**. Activa suscripción sin que el dinero llegue |
| **TL-02** | ✅ **CONFIRMADO · CRÍTICO** | `epayco-webhook:128` firma `p_cust_id ^ p_key ^ x_ref_payco ^ x_transaction_id ^ x_amount ^ x_currency_code`. Es la fórmula estándar de ePayco y está bien implementada, **pero no cubre `x_extra1` (tenant) ni `x_extra2` (plan)**. Un pago legítimo propio se puede reenviar con `x_extra1` cambiado y la firma sigue siendo válida. **Atenuante:** el `UNIQUE(provider, provider_event_id)` de D-141 lo bloquea si el webhook real llegó primero — es una carrera, no una puerta abierta. Sigue siendo crítico |
| **TL-04** | ✅ CONFIRMADO | `client_portal_authenticate` devuelve **cuatro mensajes distinguibles**: celular no es cliente / es cliente sin PIN / bloqueado / PIN incorrecto. Con el slug público se resuelve el tenant sin sesión, así que cualquiera puede preguntar "¿este celular es clienta de este salón?". **Y el contador de intentos no lo frena:** solo se incrementa cuando el cliente existe *y* tiene PIN, así que la enumeración es ilimitada. Ley 1581 |
| **TL-06** | ✅ CONFIRMADO (las dos mitades) | `encode(sha256((pin \|\| salt)::bytea),'hex')`, una sola vuelta, PIN de 4 dígitos: 10.000 combinaciones se agotan al instante **si la tabla se filtra**. La segunda mitad no necesita filtración ninguna: 5 PIN errados bloquean 15 minutos a la clienta real, y basta con saber su celular |
| **TL-09** | ✅ CONFIRMADO (los 3 puntos) | `tickets_service.dart:20-22` pide `p_start_date: null, p_end_date: null` — historial completo. `tickets_page.dart:1172` hace `...filteredTickets.map(` dentro de una `Column`: **sin `ListView.builder`**, se construye un widget por ticket |
| **TL-10** | ✅ CONFIRMADO — **y es el mejor hallazgo de las tres revisiones** | `main.dart:896` usa `IndexedStack`, que construye **todas** las páginas autorizadas a la vez. Y de ahí sale el diagnóstico que faltaba: **explica el Hallazgo Q** ("ningún módulo se actualiza solo", abierto desde el 09-ago sin causa raíz identificada). Los `initState` ya corrieron; volver a la pestaña no recarga nada. Es la primera explicación real de Q en tres semanas |
| **TL-12** | ✅ CONFIRMADO — **7 copias**, y el bug se reproduce | `_formatCop` está duplicado en 7 archivos. El bug es exacto: con `-100`, el bucle escribe el `-` en la posición 4, que cumple `pos % 3 == 1`, y mete el punto justo después → **`$-.100 COP`**. Afecta a utilidad neta negativa, sobrepagos y saldos |
| **TL-16** | ✅ CONFIRMADO | `catch (_)` ciego visible en `tickets_service.dart:34`, tragando cualquier fallo de red o de permisos de sede antes del respaldo |
| **TL-19** | ✅ CONFIRMADO — **y la severidad "Medio" se queda corta** | `BeautyModule` (`main.dart:960-974`) tiene **solo `allowedRoles`. No existe ninguna dimensión de plan.** Y `grep -rn "entitlement" lib/` devuelve **cero resultados**: la interfaz nunca llama a `get_my_entitlements()`, que existe en SQL desde el 22-jul. Consecuencia: un salón en Básico **ve** Inventario, Compras, Gastos y Reportes avanzados, entra, y recibe una excepción de PostgreSQL. **El backend hace cumplir los planes correctamente (D-124, D-136) y la interfaz ni se entera.** Es a la vez bug, fallo de UX y venta perdida: toda la escalera de precios es invisible dentro del producto |
| **TL-20** | ✅ CONFIRMADO | `ImagePicker().pickImage(source: ImageSource.gallery)` sin `maxWidth`, `maxHeight` ni `imageQuality` en al menos 3 servicios (`blog_cover`, `stylist_photo`, `tenant_cover`) |

### Confirmados, pero con la descripción corregida

| Cód. | Corrección |
|---|---|
| **TL-03** | El fondo es cierto: **no hay CSP, ni HSTS, ni `X-Frame-Options`/`frame-ancestors`**. Pero `web/_headers` **no está vacío**: ya trae `X-Content-Type-Options: nosniff` y `Referrer-Policy: strict-origin-when-cross-origin` (más el `Cache-Control` de D-096). **Y antes de escribir HSTS a mano:** en Cloudflare eso se activa desde el panel, no desde `_headers`. Comprobar ahí primero para no duplicarlo |
| **TL-05** | Cierto que no hay índice funcional sobre `regexp_replace(phone...)`. Pero **no es "un escaneo de toda la tabla `clients`"**: la consulta filtra antes por `tenant_id`, así que recorre los clientes de **ese** salón — cientos, no millones. Severidad real: **media**, y lo que la agrava no es el tamaño sino que la enumeración de TL-04 no tiene tope |
| **TL-07** | **La mitad de CI es correcta y vale:** no existe `.github/workflows`, verificado. **La mitad de "credenciales quemadas" es falsa y alarmista:** `main.dart:53` lleva una **`publishableKey`** (`sb_publishable_...`), que por diseño es pública y va protegida por RLS — no es un secreto y no debe ir en `--dart-define`. La preocupación legítima que sí queda es otra: **desarrollo y producción usan la misma base de datos**, existiendo ya `salonymas-ensayo` (D-134) |
| **TL-18** | Dice "163 archivos". Son **197**. (Curiosamente, 163 es el número que trae desactualizado el `CLAUDE.md` global del equipo) |

### Confirmados en el hecho, pero **no** son trabajo de pre-lanzamiento

**TL-11** (partir los 4 archivos grandes), **TL-17** (migrar a `go_router`) y **TL-18**
(reorganizar a `lib/features/`) describen deuda real. Pero son **refactores
grandes sobre una aplicación de 50.840 líneas que hoy funciona, con 262 pruebas
en verde, a días de vender**. Cambiar el enrutamiento entero o mover 197
archivos de sitio ahora es cambiar todo lo que ya está probado, sin que el
cliente note nada.

**Recomendación: post-lanzamiento.** TL-17 tiene además un beneficio real que
sí importa comercialmente (enlaces profundos, botón atrás), así que es el
primero de los tres cuando llegue su momento — no el último.

### Lo que la Revisión 1 acertó y conviene reconocer

Encontró dos fallos críticos reales de pagos que tres semanas de trabajo en la
Fase 8 no vieron, dio la causa raíz del Hallazgo Q —abierto desde el 09-ago— y
reprodujo un bug de formato con precisión de línea. Es una auditoría técnica de
verdad. Nada que ver con la Revisión 2.

---

## 10. Revisión 3 (Product Manager) — verificación de la versión corregida

Retiró los once puntos señalados, sin excusas, y las correcciones son correctas:
los costos ahora coinciden con el §10 (~$105.000 fijos que no escalan), el
análisis competitivo usa los precios reales del benchmarking, y la sección de
"supuestos a validar, no datos" separa bien lo proyectado de lo medido. Las
citas `D-125` / `D-138` (filtro de aceptación) y `D-124` / `D-136` (límites)
están **bien traídas**: verificadas en el Registro.

**Pero introduce una contradicción nueva sin declararla, y es justo lo que el
prompt le prohibía.** En la matriz de I-14, la fila 9 bloquea **Liquidación de
Comisiones** en el plan Básico y la llama *"gancho principal para obligar el
paso a Business"*. El Plan Maestro §3, que viene de **D-124**, dice lo
contrario: *"Pagos, caja y comisiones"* están **incluidas en los tres planes**.
Antigravity citó D-124 para el cambio de las fotos, pero **no para este**, que
es más grande: mover las comisiones fuera del Básico cambia la promesa del plan
de entrada (*"que no se me pierda ninguna cita ni ningún cobro"*) y toca lo que
el salón usa cada sábado.

**Queda a decisión del propietario**, con dos datos sobre la mesa: el Básico a
$160.000 de lista ya es más caro que AgendaPro a $99.000, y quitarle las
comisiones lo deja peor en la comparación, no mejor.

Lo demás de la matriz de I-14 (cuota de 20 fotos en Básico para resolver la
tensión de las exclusividades) es una propuesta razonable y bien argumentada:
resuelve el problema escrito en el buzón —que si las fotos bajan al Básico el
Profesional se queda sin nada exclusivo que exista— convirtiéndolo en un límite
de almacenamiento, que es de las cosas que el §3 sí permite limitar porque
cuesta plata.

---

## 11. Revisión 4 (Crítica Brutal + perímetro) — verificación

Entregada el 1-sep. **Es la mejor de las cuatro en estructura** y la única que
respondió lo que se le pidió: veredicto primero, bloqueadores ordenados, y la
lista explícita de lo que **no** hay que tocar. Absorbió bien el encuadre de que
la frontera son las RPC y no el RLS.

### Confirmado contra el código

| Afirmación | Veredicto |
|---|---|
| "301 funciones con `search_path` fijado" | ✅ **Exacto.** 302 apariciones de `security definer`, 301 `set search_path`. Un analizador propio encontró 298 definiciones de función y **todas** llevan `search_path` fijado. **No hay ninguna sin fijar** |
| `work-photos` es público y `work-photos-private` privado | ✅ Verificado: `public = true` en `20260725140000:28` y `public = false` en `20260809180000:75` |
| Los 5 servicios de subida de fotos | ✅ Exacto: `blog_cover`, `stylist_photo`, `tenant_cover`, `tenant_logo`, `work_photos` |
| `beautyos_require_entitlement` (el error crudo de TL-19) | ✅ Existe, en 5 migraciones |
| Fallo silencioso al volver de ePayco (`main.dart:224-234`) | ✅ **Confirmado.** La llamada va en un `try` que solo reporta a `MonitoreoService`: **el usuario no recibe ningún aviso**. Ver corrección de severidad abajo |
| Roles: sin escalada de tenant a plataforma | ✅ La conclusión es correcta — pero la evidencia está inventada, ver abajo |

### Inventado o mal citado

| # | Qué dice | Qué hay de verdad |
|---|---|---|
| **1** | El rol de plataforma vive en `platform_users`, con la guarda `is_platform_admin()` | ❌ **Ninguno de los dos existe** (0 apariciones en 105 migraciones). Lo real: tabla **`public.platform_operators`** (`20260722220616:32`) y guarda **`private.beautyos_current_platform_role()`**. Los valores de rol (`platform_owner`, `platform_operator`) sí son correctos, y **la conclusión de A3 se sostiene**: la identidad de plataforma vive en una tabla disjunta de `tenant_memberships` y no hay camino de escalada. Pero está sostenida con nombres inventados |
| **2** | 🔴 El procedimiento de restauración incluye ejecutar `scripts/restaurar_archivos_storage.ps1` | ❌ **Ese script no existe.** Y va dentro de un bloque de PowerShell presentado como ejecutable, en el runbook de recuperación de desastres. **Es el error más peligroso de la entrega:** se descubriría en mitad de una caída real. Los scripts que sí existen son 7 y ninguno sube archivos a Storage — **esa mitad del hallazgo Z sigue sin resolver, que es justo lo que se preguntó** |
| **3** | `_formatCop` está en `tickets_page.dart:1840` | ❌ **Cero apariciones** en ese archivo. Las 7 copias están en 6 modelos y en `platform_panel_page.dart` |
| **4** | El control SQL de A6 está "listo para ejecutar" | ❌ **No corre.** En el bloque 4, el `RAISE WARNING` referencia `n.nspname`, que no está en el `SELECT` del bucle ni declarado como variable. **Y el detalle fino:** el cuerpo del bucle solo se ejecuta si alguna función carece de `search_path` — o sea que **la comprobación falla exactamente en el caso que existe para detectar**, y pasa en silencio cuando todo está bien. Además le falta el punto 5 que se pidió: objetos que existen en la base y no en ninguna migración |
| **5** | "28 RPC reciben identificadores por parámetro" | ⚠️ **Incompleto.** La tabla de A1 trae **13 filas**, no 28. Se pidieron todas, más la lista de las que no hacía falta revisar |

### Severidades a corregir

- **El fallo silencioso de ePayco no bloquea el lanzamiento.** Es real, pero el
  webhook servidor-a-servidor es la vía autoritativa de activación (D-141): la
  suscripción se activa igual. Lo que falla es que **el dueño no ve la
  confirmación**. Es fallo de experiencia en un camino ya redundante, no pérdida
  de dinero. Y el motivo que da ("si el token expiró") es dudoso: esa función
  tiene `verify_jwt = false`, así que no depende de un token.
- **TL-20 tiene el número inflado.** El bucket tiene `file_size_limit` de
  **10 MB**, así que las fotos "de 8 a 12 MB" no pueden pasar de 10: Supabase las
  rechaza. Los 30 GB/mes son aproximadamente el doble de lo real. El hallazgo
  sigue siendo válido —sin compresión se sube al tope en vez de a ~300 KB— pero
  la urgencia es menor de la anunciada.

### Lo que esta revisión aporta de verdad

El veredicto **NO se puede vender la semana entrante**, con seis bloqueadores
ordenados y con el trabajo que implica cada uno, es utilizable tal cual. Y la
lista de lo que **no** hay que tocar (`go_router`, `lib/features/`, partir los 4
archivos grandes, WhatsApp de Meta) es la mitad que faltaba en las tres
revisiones anteriores.

---

## 8. Qué NO se ha hecho

- **No se tocó código.** Ni una línea.
- **No se tocó `PLAN_MAESTRO.md` ni `REGISTRO_DE_DECISIONES.md`.** Nada entra ahí hasta que las 4 revisiones estén consolidadas y el propietario apruebe el plan.
- **No se volvió a correr `flutter analyze` ni `flutter test`.** El 0/0 y el 262/262 son del 30-ago; después hay 2 commits (`8ea0984`, `21ec2cd`) sobre SQL y un control, sin Dart tocado. La afirmación se hereda del HANDOFF, no se verificó hoy.
