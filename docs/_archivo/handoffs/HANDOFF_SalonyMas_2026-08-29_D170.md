# HANDOFF Salón y Más — 29 de agosto de 2026 ("Respuestas a reseñas asistidas", D-170)

**Bloque documentado:** decisión **D-170** · Paso **6.3** de la **FASE 6 — El
plan Profesional**: "Respuestas a reseñas asistidas" — **versión
determinista, sin IA externa**.

**Estado:** `flutter analyze` 100% limpio (0/0), **216 de 216 pruebas en
verde** (sube de 205). **La migración de base de datos
(`20260829160000_respuestas_a_resenas.sql`) y su control
(`189_test_respuestas_a_resenas.sql`) están escritos y revisados línea por
línea, pero NO están aplicados en Supabase todavía — eso lo hace el
propietario.** Hasta que se aplique: los botones "Responder"/"Editar
respuesta" son visibles en Reseñas, pero el servidor rechaza la llamada con
"function does not exist".

---

## 0. Misma bifurcación que D-169, misma elección

El paso 6.3 del Plan Maestro solo decía: *"Respuestas a reseñas
asistidas"*. Verificado en el código (regla 8.1): **no existía ningún
mecanismo de respuesta a reseñas** — `reviews` no tenía columna para eso y
`ReviewsPage` solo moderaba y ocultaba/mostraba. Eso escondía la misma
bifurcación que D-169: ¿"asistida" es una plantilla determinista (sin
costo) o una redacción con un modelo de lenguaje real (necesita proveedor,
llave en servidor, Edge Function)? El propietario eligió, otra vez,
**empezar por la determinista**.

---

## 1. Qué se construyó

### 1.1 El borrador (`lib/models/review_reply_draft.dart`)

`ReviewReplyDraftBuilder`: lógica pura, mismo criterio de testabilidad que
`NarrativaNegocioBuilder` (D-168) — sin `BuildContext`, sin llamadas de
red. Una plantilla por franja de calificación:

- **5★:** tono entusiasta, agradece por el nombre, invita a volver.
- **4★:** agradece y pregunta qué se puede mejorar la próxima vez.
- **3★:** tono neutral, agradece la opinión, invita a escribir.
- **1-2★:** tono de disculpa, toma la opinión en serio, invita a contactar
  para resolverlo.

Usa el primer nombre de la clienta y el nombre del servicio real del
ticket; si cualquiera de los dos no está disponible (`Cliente no
asociado`/`Servicio no asociado`, los mismos textos de respaldo que ya
usaba `ReviewSummary`), el borrador se ajusta con gracia en vez de insertar
un nombre genérico a mitad de frase.

**El salón siempre ve el borrador en un cuadro de texto editable antes de
guardar** — nunca se publica sin pasar por sus ojos.

### 1.2 Guardar/editar/quitar (`set_review_reply`, migración `20260829160000`)

RPC nueva, `tenant_owner`/`admin`, branch-scoped. Un texto vacío (o solo
espacios) **quita** la respuesta por completo (limpia `business_reply` y
`business_reply_at`). No exige que la reseña esté aprobada — el salón puede
redactar antes de terminar de moderar; la visibilidad pública de la
respuesta ya depende de que la propia reseña sea `visible_to_public`
(D-165), no se inventó una regla nueva.

`get_reviews_summary_v2` y `get_public_salon_reviews` (D-165) ganan
`business_reply`/`business_reply_at` — ambas cambiaron la forma del
retorno, exigieron `drop function` primero (mismo motivo que D-162 en
adelante).

### 1.3 Dónde se ve

- **Panel del salón** (`lib/pages/reviews_page.dart`, `_ReviewCard`): si ya
  hay respuesta, se muestra en un recuadro "Tu respuesta" con botón
  "Editar respuesta"; si no, botón "Responder". Ambos abren el mismo
  diálogo con el borrador precargado (o el texto ya guardado, en modo
  edición) y un botón "Quitar respuesta" cuando corresponde.
- **Página pública del negocio** (`lib/pages/public_salon_page.dart`,
  `_ReviewTile`, D-165): la respuesta aparece bajo la reseña en un
  recuadro con la etiqueta "Respuesta del negocio".

### 1.4 Pruebas (11 nuevas)

`test/review_reply_draft_test.dart`: las cuatro franjas de calificación,
primer nombre extraído del nombre completo, y los dos casos de datos
faltantes (cliente y servicio no asociados) — más el mapeo de
`ReviewSummary.businessReply`/`businessReplyAt`/`tieneRespuesta` con y sin
respuesta. `test/public_salon_page_test.dart` ganó dos casos para
`PublicSalonReviewItem.businessReply` (con y sin respuesta), extendiendo
el grupo existente de D-165 en vez de crear un archivo aparte.

Control `supabase/sql/189_test_respuestas_a_resenas.sql` con 6 casos en
`ROLLBACK`: guardar recorta espacios, la respuesta de una reseña **pública**
aparece en `get_public_salon_reviews`, la respuesta de una reseña
**privada** NO se filtra en público (confirma que sumar la columna no abrió
una grieta nueva sobre el filtro de D-165), texto vacío quita la respuesta
por completo, reseña inexistente rechazada, y un estilista sin acceso a la
función.

---

## 2. Qué quedó a medias / fuera de este bloque

- **Bloqueante para que todo esto tenga efecto real:** aplicar
  `supabase/migrations/20260829160000_respuestas_a_resenas.sql` en
  Supabase y correr `supabase/sql/189_test_respuestas_a_resenas.sql`.
  Instrucciones en el punto 4.
- **La redacción con IA real queda fuera de este bloque, a propósito** —
  igual que en D-169, es la misma pregunta que tocará resolver el día que
  se elija un proveedor de IA para el proyecto (probablemente en el mismo
  momento para 6.2 y 6.3, ya que ambas comparten la decisión).
- Con este bloque quedan **3 de 6 pasos de la Fase 6 cerrados** (6.1, 6.2,
  6.3). El siguiente sin construir es el 6.4 (Publicación automática en
  Instagram) — **requiere revisión de Meta**, así que probablemente no sea
  el próximo paso natural sin esa gestión adelantada. El 6.6 (Blog de
  artículos) no tiene esa dependencia.

## Qué NO hacer

- **No** dejar que `set_review_reply` publique sin que el salón haya visto
  el texto en el diálogo — el borrador es un punto de partida, nunca se
  guarda automáticamente sin abrir el cuadro de edición.
- **No** asumir que solo las reseñas `approved` pueden tener respuesta —
  la RPC lo permite para cualquier reseña propia del tenant; lo que
  controla si el público la ve es `visible_to_public`, ya existente.
- **No** olvidar que tanto `get_reviews_summary_v2` como
  `get_public_salon_reviews` cambiaron de forma en este bloque — cualquier
  otro cambio futuro a sus columnas necesita `drop function` de nuevo.

---

## 3. Prompt exacto para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (bloque D-170: "Respuestas a
reseñas asistidas", paso 6.3 de la Fase 6, version determinista sin IA
externa). El codigo esta completo, flutter analyze 0/0, flutter test
216/216.

PENDIENTE BLOQUEANTE: la migracion 20260829160000_respuestas_a_resenas.sql
todavia no esta aplicada en Supabase. Antes de aplicarla:

  1. Respaldar: powershell -ExecutionPolicy Bypass -File scripts\respaldo_supabase.ps1
  2. Aplicar la migracion:
     powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
       -Archivo "supabase\migrations\20260829160000_respuestas_a_resenas.sql"
  3. Correr el control (termina en ROLLBACK, no deja rastro):
     powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
       -Archivo "supabase\sql\189_test_respuestas_a_resenas.sql"
  4. Confirmar los 6 casos "OK" en la salida antes de darlo por cerrado.

Nota: si la migracion 20260829140000_estudio_de_publicacion.sql (D-169)
tampoco se aplico todavia, aplicarla tambien -- van en orden.

Con este bloque quedan 3 de 6 pasos de la Fase 6 cerrados (6.1, 6.2, 6.3).
El 6.4 (publicacion automatica en Instagram) requiere revision de Meta, asi
que probablemente no sea el siguiente paso natural sin esa gestion --
preguntarle al propietario si sigue con el 6.5 (WhatsApp con agente,
tambien requiere Meta), el 6.6 (blog, sin esa dependencia), o si prefiere
resolver ya la eleccion de proveedor de IA real para 6.2/6.3.
```
