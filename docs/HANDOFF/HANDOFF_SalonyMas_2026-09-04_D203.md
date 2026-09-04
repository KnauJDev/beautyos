# HANDOFF Salón y Más — 4 de septiembre de 2026 (🔴 Hotfix: Tickets caído en producción, D-203)

**Bloque documentado:** decisión **D-203** · Pasos **8.26** (cerrado) y **8.27**
(abierto) de la **FASE 8**. **Corrige a D-199.**

**Estado:** ✅ **ARREGLADO EN EL REPOSITORIO.** `flutter analyze` 0/0 y
**350 de 350 pruebas en verde** (3 nuevas). Sin migración SQL.

> ⚠️ **Falta desplegar.** Mientras no se publique, la pantalla de Tickets sigue
> caída para los negocios.

> El bloque anterior (D-202, "Blindaje de cabeceras web") está en
> `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-04_D202.md`.

---

## 1. El síntoma y la causa, que no son lo que parecían

**Síntoma:** al entrar a "Tickets & Caja" en `salonymas.com`,
`PostgrestException(message: Rango de fechas invalido., code: P0001)`.

**Lo que parecía:** que D-199 rompió algo.

**Lo que era:** `get_ticket_board_list_v2` valida esto **desde que se creó, el
17-ago (D-147)**:

```sql
if p_start_date is null or p_end_date is null or p_start_date > p_end_date then
  raise exception 'Rango de fechas invalido.';
```

Y `TicketsService.getTicketsSummary` la llamaba con las dos fechas en nulo.

> **La llamada principal de la pantalla de Tickets nunca funcionó. Ni una sola
> vez, en dos semanas y media.** Fallaba en cada carga, el `catch (_)` se
> tragaba la excepción, y la pantalla se servía **enteramente del respaldo**.

**D-199 no introdujo el error: lo destapó.** Quitar el `catch` era correcto — el
error era real y llevaba semanas oculto. **El fallo fue retirar también el
respaldo, que era lo único que sostenía la pantalla, sin comprobar antes que el
camino principal funcionara.** Es un fallo de verificación, no de criterio.

---

## 2. La lección cara: las pruebas de D-199 no podían ver esto

Aquel bloque escribió guardianes que **leen el código fuente**: comprobaban que
el `catch (_)` no estuviera, y que el respaldo no estuviera.

**Las dos cosas seguían siendo ciertas con la pantalla rota.** El verde de la
suite no significaba nada sobre lo único que importaba.

Una prueba que ejercitara el comportamiento —o que comparara los dos
artefactos— lo habría cazado el mismo día. Esa es la prueba que se añade ahora
(apartado 5).

---

## 3. El segundo fallo, silencioso, que este incidente destapa

`get_tickets_summary_v2` devuelve **menos columnas** que la del Tablero. Le
faltan `sale_number`, `sale_code`, `closed_at`, `client_id` y `client_phone`.

Todas son opcionales en `TicketSummary`, así que llegaban vacías **sin
quejarse**. Consecuencia real, durante 2,5 semanas, sin que nadie lo notara:

| Función | Estado real en producción |
|---|---|
| Chip del número de venta `VTA-0000045` (D-150/D-156) | **Nunca se mostró** en la lista |
| Botón de WhatsApp con mensaje pre-armado (D-195) | **Nunca apareció** — depende de `clientPhone` |
| Buscador universal por teléfono o número de venta | **Siempre devolvió vacío** |

Tres funciones construidas, desplegadas y jamás vistas. **Este hotfix no las
recupera** — eso es el paso 8.27.

---

## 4. El arreglo, y por qué el más conservador

Se llama **directo a `get_tickets_summary_v2`**, sin respaldo y sin `catch`.
Devuelve la pantalla exactamente a como estaba ayer: riesgo cero, ni un ticket
puede desaparecer.

### Lo que se descartó, y por qué importa

**Pasar a la RPC del Tablero con un rango de fechas amplio.** Habría arreglado
la caída **y los tres fallos del apartado 3** de un solo despliegue. Se
descartó por un riesgo que no se puede medir desde el repositorio:

```sql
-- get_ticket_board_list_v2
and tk.scheduled_at is not null      -- ← excluye
-- get_tickets_summary_v2
order by tk.scheduled_at desc nulls last   -- ← incluye
```

Si existen tickets sin fecha programada —y las decenas de guardas
`scheduled_at is not null` repartidas por las migraciones dicen que la columna
admite nulos— **desaparecerían de la lista. Y un ticket que no se ve es un
ticket que no se cobra.**

**La migración** que haría a la RPC aceptar nulos es la solución más limpia y
no pierde ningún ticket, pero las migraciones las aplica el propietario
(regla 16) y producción no podía esperar.

---

## 5. La prueba nueva es de otra especie

`test/contrato_rpc_fechas_test.dart` **lee los dos lados y los compara**:

1. En el SQL, que las RPC del Tablero siguen rechazando los nulos.
2. En `lib/`, que ningún archivo las llama con una fecha nula.

No vigila una cadena de texto: vigila un **contrato entre dos artefactos que
ninguna prueba leía a la vez**. El contrato existía desde el 17-ago, escrito en
dos archivos que nadie comparaba.

**Se verificó mutándolo:** metiendo `'p_start_date': null` en
`agenda_board_service.dart`, la prueba falla y señala archivo, RPC y parámetro.

> **Y escribirla destapó algo más:** `get_ticket_board_counts_v2` rechaza los
> nulos exactamente igual. El mismo error cabía ahí y nadie lo miraba. El
> guardián cubre las dos.

También se **reescribió** la guardiana de D-199, que afirmaba justo lo
contrario de lo cierto (que llamar a `get_tickets_summary_v2` era el error).
Ahora vigila lo que de verdad importa: que se llame **una sola** RPC de
listado, sin una segunda tapando el fallo de la primera.

---

## 6. Qué NO hacer

- **No volver a poner un respaldo** en `getTicketsSummary`. Un segundo camino
  que cubre el fallo del primero es exactamente lo que escondió esto 2,5
  semanas.
- **No volver a `get_ticket_board_list_v2` sin contar antes los tickets con
  `scheduled_at` nulo.** Ver el paso 8.27.
- **No dar por buena una prueba que solo lee código fuente** cuando lo que se
  quiere comprobar es que algo funciona. Las de D-199 estaban en verde con la
  pantalla rota.
- **No retirar un respaldo sin ejecutar antes el camino que cubre.** Si no se
  puede ejecutar en `flutter test`, hay que probarlo contra la base o dejarlo.

---

## 7. Lo que sigue abierto

1. **Desplegar este hotfix.** Hasta entonces, Tickets sigue caído.
2. **Paso 8.27:** recuperar el chip del número de venta, el botón de WhatsApp y
   la búsqueda por teléfono. Necesita primero **contar en la base cuántos
   tickets tienen `scheduled_at` nulo**:
   ```sql
   select count(*) from public.tickets where scheduled_at is null;
   ```
   Si es 0, se puede pasar a la RPC del Tablero con un rango de fechas sin
   perder nada. Si no, hace falta la migración. Cierra además el tercio
   pendiente de **TL-09**.
3. **Paso 8.25:** activar **HSTS** en el panel de Cloudflare. 👤
4. **Heredado de D-201 y todavía sin verificar con los ojos:** el armazón de
   navegación (carga perezosa y refresco al entrar).
5. La otra mitad de **UX-07** (Nequi vs. Daviplata): es migración, no interfaz.
6. Hallazgos **Z** y **X** de la Fase 8.

> **Lo que el propietario tiene que ver, en cuanto se despliegue:**
> 1. Que **Tickets abre** y la lista sale completa.
> 2. Que el **número de tickets cuadra** con lo que había antes — es la forma
>    de confirmar que no se perdió ninguno.
> 3. Que **cobrar sigue funcionando** desde la lista.

---

## 8. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-203: hotfix de producción,
la pantalla de Tickets caía con "Rango de fechas invalido." -- corrige a
D-199).

flutter analyze 0/0 y 350/350 pruebas en verde. Sin migración SQL.

Lo primero: preguntar si el hotfix ya está desplegado y si Tickets abre bien.

Lo que sigue, por orden:
1. Paso 8.27: recuperar el chip del número de venta, el botón de WhatsApp y
   la búsqueda por teléfono, que llevan 2,5 semanas sin verse porque el
   respaldo devuelve menos columnas. ANTES hay que contar en la base:
   select count(*) from public.tickets where scheduled_at is null;
   Si es 0 se puede pasar a get_ticket_board_list_v2 con un rango de fechas;
   si no, hace falta migración. Cierra también el tercio pendiente de TL-09.
2. Paso 8.25: activar HSTS en Cloudflare (del propietario).
3. El armazón de navegación de D-201 sigue sin verificarse con los ojos.

La lección de este incidente, que vale para todo lo que venga: una prueba que
solo lee código fuente puede estar en verde con la pantalla rota. Las de D-199
lo estaban. Si hay que comprobar que algo FUNCIONA, hay que ejercitarlo o
comparar contrato entre artefactos, como hace contrato_rpc_fechas_test.dart.
```
