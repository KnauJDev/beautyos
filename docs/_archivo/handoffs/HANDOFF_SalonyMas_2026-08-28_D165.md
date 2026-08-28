# HANDOFF Salón y Más — 28 de agosto de 2026 (página pública completa del negocio, D-165)

**Bloque documentado:** decisión **D-165** · Paso 5.5 del Plan Maestro: la
página pública del negocio (D-098, D-164) se completa con servicios,
portafolio de fotos, equipo, reseñas, horarios/ubicación y el botón
"Agendar Cita".

**Estado:** `flutter analyze` 100% limpio (0/0), **168 de 168 pruebas en
verde** (sube de 162 por las 6 pruebas nuevas de los modelos públicos).
Código de Flutter completo y en producción tras el `git push` de este
bloque. **La migración de base de datos
(`20260827160000_perfil_publico_completo.sql`) y su control
(`185_test_perfil_publico_completo.sql`) están escritos y revisados línea
por línea, pero NO están aplicados en Supabase todavía — eso lo hace el
propietario.** Hasta que se aplique, `salonymas.com/<slug>` sigue mostrando
solo el encabezado de contacto de D-164: sin servicios, portafolio, equipo
ni reseñas.

---

## 0. Antes de empezar este bloque: se cerró un hueco de documentación

El HANDOFF vigente al arrancar (D-164, 27-ago) era más viejo que el
`git log`: había dos commits del propio propietario corrigiendo
`184_test_slugs_publicos.sql` (le faltaba `contact_email` y `whatsapp` en
los tenants de prueba — resultaron ser `NOT NULL` en `tenants`, el supuesto
original de D-164 estaba mal). Se confirmó con el propietario (`AskUserQuestion`)
que la migración de D-164 quedó **aplicada y verificada** en Supabase antes
de construir sobre ella, y se corrigió el registro de D-164 con el estado
real. Detalle en `REGISTRO_DE_DECISIONES.md`, fila D-164.

---

## 1. Dónde estamos

D-164 dejó `PublicSalonPage` con un encabezado de contacto (portada, logo,
nombre, ubicación, WhatsApp/llamar/redes) y un aviso de "muy pronto" donde
iría el resto. Este bloque construye exactamente ese resto: paso 5.5 del
Plan Maestro, la última pieza pendiente de la Fase 5 antes de 5.6 (cuenta
del cliente final) y 5.7 (permiso de publicación).

---

## 2. Qué pasó en este bloque

### 2.1 Dos campos del encargo no existen en el esquema real

Antes de escribir cada función se verificó en el código (regla 8.1 del Plan
Maestro), y aparecieron dos huecos entre lo pedido y lo que realmente
existe:

- `stylists.color_code` **no existe**. Se sustituyó por `photo_url` y `bio`
  (D-084), columnas reales que ya estaban pensadas para verse en
  superficies públicas — mejor resultado visual que un simple color plano.
- `services.description` **no existe**. Se sustituyó por `services.category`,
  devuelta con el nombre de salida `description` (documentado en el
  comentario de la función SQL y en el modelo de Flutter) porque cumple el
  mismo papel: una línea de contexto bajo el nombre del servicio.

Ninguno de los dos cambios se consultó con el propietario porque son
detalles de implementación con una sustitución obvia y sin ambigüedad de
negocio, no decisiones de producto.

### 2.2 Base de datos

**`get_public_salon_by_slug` ampliada** — cambia la forma del retorno,
exigió `drop function` primero (mismo motivo que D-162/D-164 con otras
funciones). Gana `primary_branch_id` (lo necesita el botón "Agendar Cita")
y `business_hours` (jsonb agregado de la sede principal).

**Cuatro RPC públicas nuevas**, todas `anon`/`authenticated`, todas a nivel
de **tenant** (no de sede — mismo criterio de D-164, la Fase 5 sigue siendo
un perfil por negocio):

- `get_public_salon_services` — activo y `visible_to_customer`, por nombre.
- `get_public_salon_portfolio` — `approved_for_portfolio` **y**
  `visible_to_customer` a la vez. Las dos banderas son independientes desde
  D-119 (H-09): una foto puede estar aprobada para el ticket del cliente
  pero no para el portafolio público, o al revés. Últimas 24.
- `get_public_salon_team` — solo estilistas activos.
- `get_public_salon_reviews` — promedio y total calculados aparte del
  límite de la lista y **repetidos en cada fila** que sí llega (últimas
  10). Sin reseñas visibles, la función devuelve cero filas: no hizo falta
  una segunda función solo para el resumen, Flutter interpreta "cero filas"
  como promedio 0 / total 0.

### 2.3 Frontend

Modelos nuevos: `PublicSalonServiceItem`, `PublicSalonPhotoItem`,
`PublicSalonTeamMember`, `PublicSalonReviewItem`/`PublicSalonReviewsSummary`.
`PublicSalonProfile` ganó `primaryBranchId`/`businessHours` — este último
reutiliza el modelo `BusinessHour` que ya existía para Configuración (mismas
columnas, cero duplicación).

`PublicSalonService.getFullProfile(slug)` resuelve el slug primero (hace
falta el `tenant_id` para las otras cuatro llamadas) y trae servicios,
portafolio, equipo y reseñas **en paralelo con `Future.wait`**, tal como se
pidió.

`PublicSalonPage` reescrita por completo: encabezado con calificación en
estrellas y botón "📅 Agendar Cita", y cinco secciones en **scroll continuo**
(se descartaron pestañas a propósito: ninguna otra pantalla de la app usa
`TabBar` para contenido, y el scroll continuo es más simple en móvil y mejor
para SEO). Cada sección se oculta sola si no hay nada que mostrar — un
salón nuevo sin fotos ni reseñas no enseña secciones vacías.

**Navegación a la reserva:** el botón "Reservar" de cada servicio y
"Agendar Cita" del encabezado usan `Navigator.push` normal hacia
`PublicBookingPage`. **No hizo falta** el mecanismo de D-163
(`_pendingOpenTicketId` + cambiar `selectedIndex` de un `IndexedStack`) —
eso era específico del shell autenticado, donde las páginas viven como
pestañas persistentes sin `Navigator` propio entre ellas. Las páginas
públicas comparten un único `MaterialApp`/`Navigator`, así que un `push`
normal ya resuelve el botón "Atrás".

`PublicBookingPage` ganó `preselectedServiceId` opcional: como
`public_get_bookable_services` combina servicio+estilista en una sola
opción (`PublicServiceOption`), precargar solo un servicio selecciona la
**primera** combinación que lo ofrece — la persona puede cambiar el
estilista a mano si hay más de uno.

El portafolio usa `GridView` responsivo (`SliverGridDelegateWithMaxCrossAxisExtent`)
y un visor modal con `InteractiveViewer` (zoom nativo de Flutter, sin
paquete nuevo).

**Verificado:** `flutter analyze` (0/0), `flutter test` (168/168). La
migración y el control están escritos y revisados línea por línea contra
la función que modifican (`get_public_salon_by_slug`), pero **no
ejecutados contra Supabase** — eso es lo pendiente de este bloque.

---

## 3. Qué quedó a medias / fuera de este bloque

- **Bloqueante para que la página pública muestre contenido real:** aplicar
  `supabase/migrations/20260827160000_perfil_publico_completo.sql` en
  Supabase y correr `supabase/sql/185_test_perfil_publico_completo.sql`
  para confirmar los 6 casos en verde. Instrucciones en el punto 4.
- Paso 5.6 (cuenta del cliente final: ver sus fotos y su historial de
  visitas) y 5.7 (permiso de publicación de la clienta — legal, el campo no
  existe hoy) siguen sin construir.
- Heredado de D-161: el selector de sedes del header no se refresca solo
  tras crear una sede desde Configuración.

## Qué NO hacer

- **No** inventar columnas que el encargo pida pero no existan en el
  esquema (pasó con `color_code` y `description` en este bloque) —
  verificar en el código primero y, si hace falta sustituir por una
  columna real, dejarlo dicho en un comentario de la función y en el
  registro de decisiones.
- **No** copiar el mecanismo de `_pendingOpenTicketId` de D-163 para
  navegar entre páginas públicas — ese patrón resuelve un problema
  específico del `IndexedStack` del shell autenticado. Las páginas
  públicas comparten un solo `Navigator`: un `Navigator.push` normal basta.
- **No** mostrar una sección vacía en la página pública (portafolio sin
  fotos, reseñas sin reseñas) — cada sección se oculta sola si su lista
  viene vacía.

---

## 4. Prompt exacto para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (bloque D-165: pagina publica
completa del negocio -- servicios, portafolio, equipo, resenas, horarios y
boton de reserva). El codigo de Flutter esta completo, flutter analyze
0/0, flutter test 168/168, y el git push ya se hizo.

PENDIENTE BLOQUEANTE: la migracion 20260827160000_perfil_publico_completo.sql
todavia no esta aplicada en Supabase. Antes de aplicarla:

  1. Respaldar: powershell -ExecutionPolicy Bypass -File scripts\respaldo_supabase.ps1
  2. Aplicar la migracion:
     powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
       -Archivo "supabase\migrations\20260827160000_perfil_publico_completo.sql"
  3. Correr el control (termina en ROLLBACK, no deja rastro):
     powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
       -Archivo "supabase\sql\185_test_perfil_publico_completo.sql"
  4. Confirmar los 6 casos "OK" en la salida antes de darlo por cerrado.

Hasta que esto se aplique, salonymas.com/<slug> sigue mostrando solo el
encabezado de contacto de D-164, sin servicios, portafolio, equipo ni
resenas.

Los pasos 5.6 (cuenta del cliente final) y 5.7 (permiso de publicacion,
legal) siguen sin construir -- son el siguiente punto natural de la Fase 5.

No inventes columnas que el encargo pida pero no existan en el esquema:
verificalo en el codigo primero (paso justo lo que hizo falta con
stylists.color_code y services.description en este bloque).
```
