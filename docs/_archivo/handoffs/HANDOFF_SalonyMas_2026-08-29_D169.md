# HANDOFF Salón y Más — 29 de agosto de 2026 ("Estudio de publicación", D-169)

**Bloque documentado:** decisión **D-169** · Paso **6.2** de la **FASE 6 — El
plan Profesional**: "Estudio de publicación" (foto estandarizada + reseña +
datos, lista para Instagram) — **versión determinista, sin IA externa**.

**Estado:** `flutter analyze` 100% limpio (0/0), **205 de 205 pruebas en
verde** (sube de 197). **La migración de base de datos
(`20260829140000_estudio_de_publicacion.sql`) y su control
(`188_test_estudio_de_publicacion.sql`) están escritos y revisados línea
por línea, pero NO están aplicados en Supabase todavía — eso lo hace el
propietario.** Hasta que se aplique: el botón "Estudio de publicación" es
visible en la Galería de fotos, pero el servidor rechaza la llamada con
"function does not exist".

---

## 0. Dos decisiones del propietario antes de escribir código

El paso 6.2 del Plan Maestro solo decía: *"Estudio de publicación: foto
estandarizada + reseña + datos, lista para Instagram"*. Verificado en el
código (regla 8.1: nada de IA existe todavía en `supabase/functions/`),
eso escondía una bifurcación real de arquitectura y una decisión de
producto que no me tocaba inventar (regla 2):

1. **¿"Foto estandarizada" es composición determinista (recorte + logo +
   texto, sin costo) o mejora real con IA externa pagada (explicaría el
   tope de 50/mes que fijó D-124)?** El propietario eligió **empezar por
   la determinista**.
2. **D-124 definió este paso como exclusivo del plan Profesional**, pensado
   para cuando hubiera costo real de IA. Sin costo por uso en la versión
   determinista, ¿se restringe igual o se abre a todos? El propietario
   eligió **abrirlo a todos los planes por ahora** — el candado de plan se
   agrega el día que se sume la mejora con IA real y el tope tenga sentido.

---

## 1. Qué se construyó

### 1.1 El dato que faltaba (`get_publication_studio_data`, migración `20260829140000`)

Nueva RPC (`tenant_owner`/`admin`, mismo criterio de acceso que la galería
interna) que junta lo que Flutter no tenía suelto en ningún lado:

- **Nombre del o los servicios del ticket** (`ticket_services` → `services`,
  la foto solo guarda `ticket_id`, no el servicio).
- **Una reseña real del mismo ticket, solo si es de 4 o 5 estrellas**,
  aprobada y visible al público — una de 1-3 estrellas no se ofrece aunque
  exista, porque no tiene sentido en una pieza de marketing.

**Mismo candado legal que el portafolio público (D-167):** la función
rechaza una foto que no esté aprobada para portafolio o sin consentimiento
de la clienta, con el mensaje exacto *"Esta foto no esta aprobada para
portafolio o no tiene consentimiento de la clienta -- no se puede usar en
una publicacion."* — no se inventó un tercer estado de aprobación, se
reutilizó el que ya existía.

### 1.2 Composición 100% en el cliente (`lib/widgets/publication_studio_dialog.dart`)

Sin servidor de imágenes: `RepaintBoundary.toImage()` (nativo de Flutter)
captura una tarjeta **construida en tamaño real, 1080×1080** (mostrada más
chica en pantalla con `FittedBox`, que solo escala el pintado, no cambia lo
que hay dentro del boundary que se captura) con: la foto de fondo, un
degradado inferior para legibilidad, el logo y nombre del negocio arriba,
el nombre del servicio abajo, la reseña (opcional, con un interruptor
"Incluir reseña" para quitarla aunque exista) y un pie con el WhatsApp de
contacto.

**Antes de habilitar el botón "Descargar imagen"** se precachean la foto y
el logo (`precacheImage`) — sin esto, una red lenta podía dejar la captura
con la foto o el logo en blanco, porque `toImage()` captura lo que ya está
pintado, no lo que va a llegar después.

### 1.3 Descarga sin paquete nuevo

La imagen capturada se codifica a PNG, se arma como
`data:image/png;base64,...` y se abre en una pestaña nueva con
`launchUrl` (ya existente en el proyecto, mismo patrón que el enlace de
Google Calendar de D-166) — el navegador ofrece "Guardar imagen como"
desde ahí. **No se agregó ningún paquete de compartir/descargar.**

**No se conecta con Instagram.** Eso es el paso 6.4, aparte, y exige
aprobación de Meta — este paso entrega el archivo, no lo publica.

### 1.4 Entrada (`lib/pages/work_photos_page.dart`)

Botón "Estudio de publicación" en cada tarjeta de la Galería de fotos,
habilitado solo cuando `photo.estaPublicada` (aprobada para portafolio +
con URL pública) — la misma condición que D-119 ya usaba para saber si una
foto es alcanzable desde internet. Deshabilitado con un tooltip explicando
por qué, si la foto todavía no califica.

### 1.5 Pruebas

`test/publication_studio_test.dart` (8 nuevas): mapeo completo del modelo
con y sin reseña, conversión de `review_rating` desde texto (la RPC puede
mandarlo así), y los getters `tieneResena`/`servicioTexto` en sus casos
límite (comentario vacío, sin servicios).

Control `supabase/sql/188_test_estudio_de_publicacion.sql` con 6 casos en
`ROLLBACK`: datos completos con reseña de 5 estrellas y dos servicios
agregados (`string_agg`), ticket sin reseña, reseña de 3 estrellas excluida
por el filtro de calidad, foto sin aprobar rechazada con el mensaje del
candado legal, foto inexistente rechazada como "no existe" (no como error
interno), y un estilista sin acceso a la función.

**Hallazgo del propio `flutter analyze`/`flutter test` durante la
construcción:** un `Color(0xCC000000)` escrito a mano en el degradado de la
tarjeta rompió `test/sin_colores_sueltos_test.dart` (el guardián del
sistema de diseño, D-102) — corregido a `Colors.black.withValues(alpha:
0.8)`, que sí es un color con nombre y no un literal hexadecimal.

---

## 2. Qué quedó a medias / fuera de este bloque

- **Bloqueante para que todo esto tenga efecto real:** aplicar
  `supabase/migrations/20260829140000_estudio_de_publicacion.sql` en
  Supabase y correr `supabase/sql/188_test_estudio_de_publicacion.sql`.
  Instrucciones en el punto 4.
- **La mejora con IA real queda fuera de este bloque, a propósito.** El día
  que se elija un proveedor y se construya, ese es el momento de restringir
  el paso al plan Profesional (D-124) y activar el tope de 50/mes.
- **No probado con captura real en un navegador** (imágenes de red +
  `RepaintBoundary.toImage()` en Flutter Web puede tener matices según el
  renderer — CanvasKit vs HTML — y las cabeceras CORS del bucket de
  Supabase Storage). Si el propietario ve una captura en blanco o con la
  foto/logo faltante al probar en producción, es lo primero a revisar.
- Con este bloque queda **2 de 6 pasos de la Fase 6 cerrados** (6.1, 6.2).
  El siguiente sin construir es el 6.3 (Respuestas a reseñas asistidas).

## Qué NO hacer

- **No** restringir este paso al plan Profesional sin que antes se
  construya la mejora con IA real — es la decisión explícita del
  propietario en este bloque, y hacerlo unilateralmente le quitaría una
  función que ya prometió abierta.
- **No** escribir un `Color(0x........)` a mano en ningún archivo de
  `lib/` fuera de `lib/theme/` — `test/sin_colores_sueltos_test.dart` lo
  va a atrapar. Usar `Colors.<nombre>` o los tokens de `AppColors`.
- **No** llamar a `RepaintBoundary.toImage()` antes de que las imágenes de
  red estén precacheadas — la captura sale con lo que ya se pintó, no con
  lo que todavía está cargando.

---

## 3. Prompt exacto para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (bloque D-169: "Estudio de
publicación", paso 6.2 de la Fase 6, version determinista sin IA externa).
El codigo esta completo, flutter analyze 0/0, flutter test 205/205.

PENDIENTE BLOQUEANTE: la migracion
20260829140000_estudio_de_publicacion.sql todavia no esta aplicada en
Supabase. Antes de aplicarla:

  1. Respaldar: powershell -ExecutionPolicy Bypass -File scripts\respaldo_supabase.ps1
  2. Aplicar la migracion:
     powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
       -Archivo "supabase\migrations\20260829140000_estudio_de_publicacion.sql"
  3. Correr el control (termina en ROLLBACK, no deja rastro):
     powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
       -Archivo "supabase\sql\188_test_estudio_de_publicacion.sql"
  4. Confirmar los 6 casos "OK" en la salida antes de darlo por cerrado.

Con este bloque quedan 2 de 6 pasos de la Fase 6 cerrados (6.1, 6.2). El
siguiente sin construir es el 6.3 (Respuestas a reseñas asistidas) --
preguntarle al propietario si sigue por ahi o prefiere otro orden.

Recordar: este paso quedo ABIERTO A TODOS LOS PLANES a proposito (decision
del propietario), no exclusivo de Profesional como preveia D-124 -- no
restringirlo sin que antes exista la mejora con IA real.
```
