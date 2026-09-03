# HANDOFF Salón y Más — 2 de septiembre de 2026 ("Rendimiento, Resiliencia y Optimización de Carga", D-199)

**Bloque documentado:** decisión **D-199** · Paso **8.21** de la **FASE 8**.

**Estado:** ✅ **CERRADO.** `flutter analyze` 0/0 y **313 de 313 pruebas en
verde** (12 nuevas). Sin migración SQL ni Edge Function: el bloque es
enteramente de Flutter, así que no queda ningún paso manual pendiente y no
hace falta desplegar nada aparte del push.

> El bloque anterior (D-198, "Función canónica de moneda") está en
> `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-02_D198.md`.

---

## 1. Qué une a estos cuatro arreglos

No comparten código. Comparten el motivo: **ninguno de los cuatro es un fallo
visible.** Los cuatro son fallos silenciosos — cuestan dinero, o esconden un
error, sin que nadie se entere. Por eso van juntos y no en cuatro bloques.

| Hallazgo | Qué pasaba | Quién lo sufría |
|---|---|---|
| **TL-16** | Un `catch (_)` convertía "se cayó la red" y "no tienes permiso en esta sede" en "no hay tickets" | El salón, sin saberlo |
| **TL-20** | Las fotos subían tal cual salen del celular, hasta el tope de 10 MB | La clienta que abre la página pública desde su celular |
| **TL-09** | La lista de Tickets construía un widget por cada ticket del historial | El salón con dos años de operación |
| **C-03** | El salto Agenda→Tickets dependía de una adyacencia escrita solo en un comentario | Nadie todavía; la recepcionista el día que se rompa |

---

## 2. TL-16 — Se retiró el respaldo entero, no solo el `catch`

`TicketsService.getTicketsSummary` envolvía la llamada a
`get_ticket_board_list_v2` en un `catch (_)` sin tipo, y ante *cualquier*
excepción caía a `get_tickets_summary_v2`.

Ese respaldo nació para cubrir la migración al tablero de agenda (D-147).
Pero lo que hacía de verdad era tapar el error: el `FutureBuilder` de la
pantalla **nunca veía la excepción**, así que nunca la mostraba.

**Se quitó el respaldo completo, no solo el `catch`.** Dejar la caída viva
habría significado seguir teniendo dos caminos donde el segundo esconde el
fallo del primero. Ahora la llamada es limpia y la excepción sube, igual que
ya hacía `AgendaBoardService.getBoardList` con la misma RPC.

> **Hallazgo anotado, no resuelto (regla 20).** `get_tickets_summary_v2` se
> queda **sin ningún consumidor en Flutter**, pero sigue viva en la base y la
> usan los controles SQL `113`, `119`, `163` y `183`. **No se borró:** retirar
> una función de la base es una migración, y este bloque no toca SQL.

---

## 3. TL-20 — Compresión en un solo sitio, no repetida cinco veces

Los cinco servicios de subida —logo, portada del negocio, portada de blog,
foto de profesional y foto de trabajo— llamaban a
`ImagePicker().pickImage(source: ImageSource.gallery)` **sin ningún límite**.

El único techo era el `file_size_limit` de 10 MB del almacén, que **no
comprime nada: solo rechaza lo que se pase**. Por eso la propia auditoría
corrigió a la baja la urgencia del hallazgo — pero no lo refutó.

Lo que más se nota no es la factura de almacenamiento. Es que **la página
pública del salón la abre la clienta desde su celular**, y hoy se descarga la
imagen entera.

### Dónde quedó la política, y por qué ahí

`lib/services/image_compression.dart`, con `kLadoMaximoDeImagen` (1920),
`kCalidadDeImagen` (85) y `elegirImagenComprimida()`. Los cinco `pickImage()`
delegan ahí.

**Es la lección de D-198 aplicada antes de que duela:** tres cifras copiadas
en cinco servicios son cinco sitios que corregir el día que cambien, y cuatro
oportunidades de que una se quede atrás. Así fue como llegaron a existir 13
copias de `formatCOP`.

**Se descartó** meterlo en un `lib/utils/` nuevo, por la misma razón que D-198
dejó `formatCOP` en `ticket_board.dart`: el proyecto no tiene esa carpeta y no
hacía falta inventarla para esto.

### Se comprobó antes de aplicarlo: no rompe los logos con transparencia

Era el riesgo real de poner `imageQuality` sobre un logo PNG. Se leyó el
código del plugin instalado antes de tocar nada:

- **En web** (`image_picker_for_web` 3.1.1), `canvas.toBlob` recibe el
  `mimeType` del archivo original: un PNG sale PNG, y la calidad se ignora.
- **En Android** (`image_picker_android` 0.8.13+19), `ImageResizer` guarda
  como PNG en cuanto el mapa de bits tiene canal alfa.

En los dos casos la imagen **sí se reescala**, que es justo lo que más pesa.
Un logo con fondo transparente sigue saliendo transparente.

> **Anotado, no resuelto (regla 20).** En **Android**, un PNG **sin** canal
> alfa sí se recomprime a JPEG, pero el archivo conserva su nombre `.png`
> (`scaled_<original>`). Como `_contentTypeFor()` deduce el tipo por la
> extensión, ese archivo se guardaría en el almacén declarado como
> `image/png` llevando bytes JPEG. **En la práctica no rompe nada** —los
> navegadores muestran la imagen igual, porque deducen el formato del
> contenido— y **hoy no aplica**: el producto se usa por web. Queda escrito
> por si algún día se publica la app en Android; el arreglo sería deducir el
> tipo de los bytes, no del nombre.

---

## 4. TL-09 — Por qué NO se usó `ListView.builder`

**Esto es lo más importante de este bloque para quien venga después.**

El encargo pedía literalmente cambiar el `...filteredTickets.map(` de la
`Column` por un `ListView.builder`. **Ese cambio no habría ahorrado nada, y se
dijo antes de tocar el archivo.**

`TicketsPage` se dibuja dentro de `AppPage`, que es un
`SingleChildScrollView` (`lib/widgets/app_widgets.dart:22`). Un `ListView`
dentro de un scroll sin altura acotada obliga a `shrinkWrap: true`, y
**`shrinkWrap` construye igualmente todos los hijos** para poder medirse.
Habría quedado igual de pesado, con una capa más de layout encima.

Se le devolvieron al propietario las tres salidas que sí funcionan —slivers,
tope con "Ver más", o lista de altura fija con scroll anidado— y **eligió el
tope, fijando la tanda en 10**.

### Cómo quedó

- `_ticketsPorTanda = 10`: la lista pinta 10 y crece de 10 en 10.
- La cabecera dice **"Tickets (10 de 240)"** cuando hay más, y "Tickets (240)"
  cuando ya se ven todos.
- El botón dice "Ver 10 más (230 pendientes)", y en la última tanda cambia a
  "Ver los 4 restantes".
- **`_reiniciarPaginacion()` en los siete `setState` que tocan un filtro** (y
  en el de refrescar la lista entera). Sin eso, quien amplió a 60 y después
  busca por nombre arrastra el tope viejo al resultado nuevo. Hay una prueba
  que recorre los `setState` del archivo y señala por línea el que se olvide,
  para que el filtro que se añada mañana no se quede fuera.

> **Sigue abierto el otro tercio de TL-09.** La consulta sigue pidiendo
> `p_start_date: null, p_end_date: null`: el historial completo viaja desde la
> base igual que antes. **Este bloque acota lo que se *pinta*, no lo que se
> *trae*.** Acotar la consulta es trabajo de otro paso.

---

## 5. C-03 — La prueba que faltaba

El salto de Agenda a la Ficha Completa (D-163) y el botón "Cobrar" (D-195)
navegan con `selectedIndex + 1`: dan por hecho que Tickets es el módulo
inmediatamente siguiente a Agenda **en la lista ya filtrada por rol**. Eso
estaba escrito solo en un comentario de `main.dart`.

`test/salto_agenda_tickets_test.dart` vigila **las dos mitades**:

1. **La adyacencia.** Que "Tickets & Caja" siga justo después de "Agenda".
2. **Que todo rol que ve Agenda vea también Tickets.** Esta es la que se rompe
   sin ruido: la lista se filtra por rol **antes** de navegar, así que
   quitarle `assistant` a Tickets haría que el botón "Cobrar" de una
   recepcionista abriera **Clientes**. Sin error, sin excepción: la pantalla
   equivocada.

---

## 6. Las 12 pruebas nuevas leen el código fuente, y es a propósito

| Archivo | Qué vigila |
|---|---|
| `test/salto_agenda_tickets_test.dart` | C-03: adyacencia y roles compartidos (4 pruebas) |
| `test/compresion_de_imagenes_test.dart` | TL-20: los tres límites, ningún `ImagePicker` suelto, los 5 servicios delegando (3 pruebas) |
| `test/tickets_rendimiento_y_resiliencia_test.dart` | TL-16 y TL-09: sin `catch` ciego, sin respaldo, tanda de 10, no se recorre la lista completa, y el reinicio de paginación en cada filtro (5 pruebas) |

**Por qué leen la fuente en vez de ejecutar el código.** `ImagePicker`
necesita canal de plataforma; `getTicketsSummary` necesita sesión de Supabase;
`_modulesForProfile` es privado del `State` de la pantalla principal y
construye páginas reales. Ninguna de las cuatro correcciones se puede
ejercitar en `flutter test` sin montar una inyección de dependencias que hoy
no existe. Lo que **sí** se puede vigilar es que ninguna vuelva sola — mismo
recurso que D-102 ya usa en `sin_colores_sueltos_test.dart`.

**Se probaron contra sí mismas.** Las dos pruebas de TL-16 fallaron en la
primera corrida **detectando los comentarios de documentación** que citan a
propósito el código viejo. Se acotaron a mirar solo código. Y se verificó que
el guardián de C-03 lee de verdad los 19 módulos, no una lista vacía.

---

## 7. Los archivos tocados

**Código (8):**

1. `lib/services/tickets_service.dart` (TL-16)
2. `lib/services/image_compression.dart` — **nuevo** (TL-20)
3. `lib/services/blog_cover_upload_service.dart`
4. `lib/services/stylist_photo_upload_service.dart`
5. `lib/services/tenant_cover_upload_service.dart`
6. `lib/services/tenant_logo_upload_service.dart`
7. `lib/services/work_photos_upload_service.dart`
8. `lib/pages/tickets_page.dart` (TL-09)

**Pruebas (3 nuevas):** las de la tabla del apartado 6.

**Documentación:** `REGISTRO_DE_DECISIONES.md` (D-199 + índice),
`PLAN_MAESTRO.md` (paso 8.21), `docs/README.md` y este HANDOFF.

---

## 8. Qué NO hacer

- **No volver a escribir `ImagePicker()` en un servicio nuevo.** Importar
  `image_compression.dart` y llamar a `elegirImagenComprimida()` cuesta una
  línea. Hay una prueba que lo impide, y está ahí porque así llegaron a ser
  cinco copias sin comprimir.
- **No "arreglar" TL-09 con un `ListView.builder` dentro de `AppPage`.** Ya se
  estudió: `shrinkWrap` construye todos los hijos igual. Si algún día hace
  falta pereza de verdad, la salida es convertir la página a slivers, no meter
  un `ListView` en un `SingleChildScrollView`.
- **No añadir un filtro nuevo a Tickets sin llamar a
  `_reiniciarPaginacion()`** dentro de su `setState`. Hay una prueba que lo
  detecta y dice en qué línea falta.
- **No mover un módulo entre Agenda y Tickets en `main.dart`,** ni quitarle un
  rol a Tickets que Agenda sí tenga. Si hay que hacerlo, hay que cambiar antes
  el salto de D-163 y D-195 a `_irAModulo` por título, como hace el Dashboard
  desde D-168.
- **No borrar `get_tickets_summary_v2` de la base** solo porque Flutter ya no
  la llame. Cuatro controles SQL la usan.

---

## 9. Lo que sigue abierto (heredado, más lo que este bloque deja escrito)

1. **Nuevo de este bloque:** el otro tercio de TL-09 — la consulta sigue
   trayendo el historial completo (`p_start_date: null, p_end_date: null`).
2. **Nuevo de este bloque:** `get_tickets_summary_v2` queda sin consumidores
   en Flutter, viva en la base y usada por 4 controles SQL. Decidir si se
   retira, y en qué migración.
3. La pantalla pública de planes, la tarjeta de sedes y el desglose de
   reportes por sede siguen sin verse con los ojos (HANDOFF de D-195,
   apartado 3.3).
4. El candado 2 de D-181 sigue sin ejercitarse contra un pago real de ePayco.
5. Del Plan Maestro: Fase 3 con dos casillas de 👤 abiertas (3.2 contador
   sobre DIAN/IVA, 3.4 subir Supabase a Pro).
6. De la auditoría técnica del 01-sep queda **TL-10** sin paso asignado: el
   `IndexedStack` de `main.dart:896` construye todas las páginas autorizadas a
   la vez, y es **la causa raíz del Hallazgo Q** ("ningún módulo se actualiza
   solo"), abierta desde el 09-ago.

> **Lo que el propietario tiene que ver con los ojos en este bloque:** la
> lista de Tickets con el botón "Ver 10 más" (que la cuenta cuadre y que al
> filtrar vuelva a 10), y que una foto subida desde el celular siga viéndose
> bien —sobre todo un **logo con fondo transparente**, que es el caso que se
> estudió antes de aplicar la compresión pero no se ha visto en pantalla.

---

## 10. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-199: Bloque 5 "Rendimiento,
Resiliencia y Optimización de Carga" -- cierra TL-16, TL-20 y TL-09 de la
auditoría técnica del 01-sep, y C-03 de los hallazgos propios).

Este bloque quedó cerrado sin pasos manuales pendientes: es enteramente
Flutter, sin migración SQL ni Edge Function. flutter analyze 0/0 y
313/313 pruebas en verde.

Lo que sigue abierto, por orden de daño:
1. TL-10: el IndexedStack de main.dart construye todas las páginas a la vez,
   y es la causa raíz del Hallazgo Q ("ningún módulo se actualiza solo"),
   abierta desde el 09-ago. Es el hallazgo más grande que queda sin paso.
2. El otro tercio de TL-09: la consulta de Tickets sigue trayendo el
   historial completo (p_start_date: null). D-199 acotó lo que se pinta,
   no lo que se trae.
3. Pantalla pública de planes, tarjeta de sedes y desglose de reportes por
   sede sin verificar visualmente.
4. El candado 2 de D-181 sin ejercitar contra un pago real.
5. get_tickets_summary_v2 quedó sin consumidores en Flutter pero sigue viva
   en la base y la usan 4 controles SQL. Decidir si se retira.

Ojo con lo que NO hay que tocar: no escribir ImagePicker() en ningún sitio
nuevo -- la política de compresión vive en lib/services/image_compression.dart
y hay una prueba que lo impide. Y no intentar "arreglar" TL-09 con un
ListView.builder dentro de AppPage: AppPage es un SingleChildScrollView, y
shrinkWrap construye todos los hijos igual. Ya se estudió.
```
