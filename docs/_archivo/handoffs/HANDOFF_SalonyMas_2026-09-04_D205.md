# HANDOFF Salón y Más — 4 de septiembre de 2026 ("El Dashboard hace caso a la sede", D-205)

**Bloque documentado:** decisión **D-205** · Paso **8.28** de la **FASE 8**.

**Estado:** ✅ **CERRADO.** `flutter analyze` 0/0 y **365 de 365 pruebas en
verde** (7 nuevas). Sin migración SQL ni Edge Function.

> El bloque anterior (D-204) está en
> `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-04_D204.md`.

---

## 1. Dos de las tres premisas del encargo no coincidían con el código

Se comprobaron **antes** de escribir nada. Queda escrito porque quien lea el
encargo original va a buscar cosas que no están donde dice.

| Lo que decía el encargo | Lo que había de verdad |
|---|---|
| «El Dashboard no permite alternar entre sede y consolidado» | **Sí permitía.** Tenía un `DropdownButton<String?>` con "Todas las sedes" + una entrada por sede, visible con más de una sede |
| «Al cambiar de sede el Dashboard no se remonta» | **Ya lo arreglaba D-201**: al cambiar de sede se limpia `_visitasPorModulo`, cambia la llave del `KeyedSubtree` y el módulo visible se remonta |
| «Agregar pruebas en `test/dashboard_page_test.dart`» | Ese archivo **no existía**. Se creó |

**Lo que sí era cierto, y es el fondo del asunto:** el Dashboard arrancaba en
consolidado (`_sedeElegida = null`) e **ignoraba la píldora de sede de la
cabecera**. Se cambiaba de sede arriba y los números seguían siendo los del
negocio entero.

> **Sobre la llave de `main.dart`.** Se puso igual
> (`ValueKey('dashboard-${branch.branchId}')`) y merece la pena: la iguala a
> los otros 17 módulos y deja de depender de un efecto lateral del contador de
> visitas de D-201. Pero **no arregla un fallo vivo**, y decirlo importa: dar
> por arreglado algo que ya lo estaba es como se pierde la pista de lo que de
> verdad cambió.

---

## 2. El arreglo de fondo: el ámbito por defecto

`_sedeElegida` (un `String?`) se sustituye por `_consolidado` (un `bool`), **el
mismo nombre y el mismo significado que en `ReportesPage`** desde D-194.
Arranca en `false`, o sea en la sede activa.

Es **menos estado**: la sede sale de `widget.branchId` en el momento de
consultar, no de una copia guardada en el `State`, así que no puede quedarse
vieja. Y hace que la píldora de la cabecera sea la única que decide **qué**
sede se mira.

---

## 3. El desplegable se sustituye, no se acompaña

Añadir el `SegmentedButton` **encima** del desplegable habría dejado **dos
controles para el mismo estado**, y el segmentado no sabría qué enseñar cuando
el desplegable elige una sede que no es la activa. Eso es un fallo esperando.

Se le dieron al propietario las tres salidas —sustituir, no añadir el
segmentado, o los dos con el desplegable subordinado— y eligió **sustituir**.

> **Lo que cuesta, dicho claro:** hoy un dueño con tres sedes puede mirar el
> Dashboard de la sede 2 con la píldora puesta en la 1. Después tiene que
> cambiar la píldora. **No es una capacidad perdida, es un clic en otro
> sitio** — y a cambio desaparece un control que duplicaba lo que la píldora ya
> hacía.

---

## 4. "Primeros pasos" no se recarga al cambiar de ámbito

El encargo lo pedía. **No se hizo, y es deliberado.**

Esa lista se pide con `widget.branchId` y **no depende del ámbito**: es el
progreso de puesta en marcha de *esta* sede, mire uno los números de una o de
todas. Recargarla en cada toque del botón sería una consulta de más sin ningún
efecto visible.

Al cambiar de **sede** sí se recarga, porque entonces la página entera se
remonta por la llave.

---

## 5. Las 7 pruebas nuevas

`test/dashboard_page_test.dart`, y **ejercitan comportamiento**:

- **El ámbito (3).** Que "esta sede" consulte la sede activa, y que el
  consolidado mande la lista **vacía**. Esta segunda es la trampa: colar ahí la
  sede activa enseñaría los números de una sola sede bajo el rótulo "Todas", y
  el resultado sería **plausible pero incompleto** — o sea, invisible.
- **El control (4).** Se monta y se toca de verdad: que con una sede no se
  dibuje, que con dos arranque en "Esta sede", y que los dos toques avisen con
  el valor correcto.

`ControlesDelDashboard` y `sedesDelDashboard` pasaron a ser públicos para poder
probarlos, misma razón que `PaymentsDialog` en D-200.

> **Lo que NO queda cubierto:** que `_consolidado` arranque en `false` **dentro
> del `State`**. Ese campo vive en `_DashboardPageState`, cuyo `initState`
> llama a Supabase, así que no se puede montar en `flutter test` sin una
> inyección de dependencias que hoy no existe. Lo que sí está probado es el
> contrato del que depende: dado `consolidado: false`, el control dibuja "Esta
> sede" seleccionada.

---

## 6. Qué NO hacer

- **No volver a poner un desplegable de sedes en el Dashboard** junto al botón
  de ámbito. Serían dos controles para el mismo estado, que es justo lo que se
  evitó aquí.
- **No recargar "Primeros pasos" al cambiar de ámbito.** No depende del ámbito;
  sería una consulta por toque sin efecto.
- **No guardar la sede en el `State` del Dashboard.** Sale de
  `widget.branchId`, y así no puede quedarse vieja respecto a la píldora.
- **No dar por hecho que la lista vacía es "ninguna sede".** En este servicio
  significa **todas** las que el usuario alcance: `DashboardService` la traduce
  a `p_branch_ids: null` y el SQL lo lee como sin filtro.

---

## 7. Lo que sigue abierto

1. **El armazón de navegación de D-201 sigue sin verificarse con los ojos.**
   Van **cinco sesiones**. Es el cambio grande más reciente que nadie ha
   ejercitado a mano, toca las 16 pantallas, y esta semana hemos visto dos
   veces lo que cuesta un camino verificado solo sobre el papel (D-203, D-204).
2. El tercio de **TL-09**: la consulta de Tickets sigue trayendo el historial
   completo. Necesita decidir qué significa "todos" para el salón.
3. Los tickets con `scheduled_at` nulo desaparecerían de la lista de Tickets en
   silencio. Hoy hay cero. Arreglo durable = migración (D-204).
4. **HSTS** en el panel de Cloudflare — paso 8.25, 👤 propietario.
5. La otra mitad de **UX-07** (Nequi vs. Daviplata), que **no es interfaz**:
   los métodos de pago son un `CHECK` de base de datos (C-04).
6. Fase 3 con dos casillas de 👤 abiertas (3.2 contador sobre DIAN/IVA, 3.4
   subir Supabase a Pro).
7. Hallazgos **Z** (recuperación de fotos tras restaurar) y **X** (la
   contraseña de la base nunca se ha rotado).

> **Lo que el propietario tiene que ver con los ojos, y solo tiene sentido con
> dos sedes:**
> 1. Que al **cambiar de sede en la píldora**, los números del Dashboard
>    cambien. Es el arreglo de fondo.
> 2. Que el botón **"Esta sede" / "Todas las sedes"** aparezca en la cabecera y
>    que el consolidado dé una cifra **mayor o igual** que la de una sola sede.
> 3. Que con **una sola sede** ese botón no aparezca.

---

## 8. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-205: el Dashboard hace caso a
la píldora de sede, y su desplegable de sedes se sustituye por el botón de dos
posiciones de Reportes).

flutter analyze 0/0 y 365/365 pruebas en verde. Sin migración SQL.

Antes de abrir un bloque nuevo, preguntar por lo que lleva CINCO sesiones
pendiente: el armazón de navegación de D-201 sigue sin verificarse con los
ojos. Toca las 16 pantallas y esta semana ya hubo dos incidentes por caminos
verificados solo sobre el papel (D-203 tumbó Tickets en producción, D-204
encontró dos diferencias silenciosas entre dos RPC que parecían iguales).

Lo que sigue abierto, por orden de daño:
1. Verificar a mano el armazón de navegación de D-201 (apartado 9 de aquel
   HANDOFF, archivado).
2. El tercio de TL-09: la consulta de Tickets trae el historial completo.
3. Los tickets con scheduled_at nulo desaparecerían de la lista. Hoy hay cero.
4. HSTS (paso 8.25), del propietario.
5. La otra mitad de UX-07 (Nequi vs Daviplata), que NO es interfaz.

Ojo con lo que NO hay que tocar: no volver a poner un desplegable de sedes en
el Dashboard junto al botón de ámbito -- serían dos controles para el mismo
estado. Y la lista vacía de branchIds significa TODAS las sedes, no ninguna.
```
