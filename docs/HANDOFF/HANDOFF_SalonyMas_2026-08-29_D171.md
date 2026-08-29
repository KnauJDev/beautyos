# HANDOFF Salón y Más — 29 de agosto de 2026 ("Blog de artículos", D-171)

**Bloque documentado:** decisión **D-171** · Paso **6.6** de la **FASE 6 — El
plan Profesional**: "Blog de artículos de belleza y estética" — **blog por
cada salón, sin url propia por artículo todavía**.

**Estado:** `flutter analyze` 100% limpio (0/0), **222 de 222 pruebas en
verde** (sube de 216). **La migración de base de datos
(`20260829180000_blog_de_articulos.sql`) y su control
(`190_test_blog_de_articulos.sql`) están escritos y revisados línea por
línea, pero NO están aplicados en Supabase todavía — eso lo hace el
propietario.** Hasta que se aplique: el módulo "Blog" es visible en el
panel, pero el servidor rechaza cada llamada con "function does not
exist".

---

## 0. El paso más vago de la Fase 6 hasta ahora — dos decisiones antes de escribir código

El Plan Maestro solo decía: *"Blog de artículos de belleza y estética"*, sin
una sola línea más de contexto en ningún documento. A diferencia de 6.1-6.3
(donde solo había una bifurcación técnica: determinista vs. IA real), aquí
ni el alcance básico estaba definido. Se resolvieron dos preguntas con el
propietario antes de tocar código:

1. **¿Blog por cada salón, o único de la plataforma Salón y Más?**
   (`AskUserQuestion`) → **Por cada salón.** Cada negocio escribe sus
   propios artículos y aparecen en su página pública — coherente con el
   resto de la Fase 6, donde todo es una función que cada salón usa para
   su propio marketing.
2. **¿El artículo individual tiene su propia URL desde ya?** (pregunta en
   texto, confirmación directa) → **Todavía no.** Se navega solo desde
   dentro de la página del negocio; un enlace directo a un artículo queda
   para un bloque futuro si hace falta.

---

## 1. Qué se construyó

### 1.1 Tabla y storage (migración `20260829180000`)

`blog_posts`: a nivel de **tenant, no de sede** (mismo criterio que
portafolio/reseñas de D-165) — `title`, `content` (texto plano por
párrafos, sin editor enriquecido), `cover_photo_url` opcional, `published`
boolean. **Sin políticas de RLS para `authenticated`/`anon`** a propósito,
mismo criterio que `reviews`/`work_photos`: todo pasa por RPC `security
definer`.

Bucket nuevo `blog-covers` (público, 5 MB), mismo patrón que
`tenant-covers`/`stylist-photos`: `private.beautyos_can_manage_blog_post
(tenant_id)` autoriza insert/delete a `tenant_owner`/`admin` del tenant
exacto de la carpeta.

### 1.2 RPC — autoservicio, sin `p_branch_id`

`create_blog_post`, `update_blog_post`, `delete_blog_post`,
`get_blog_posts_summary`: mismo criterio que `update_tenant_contact_info`/
`update_tenant_slug` — el blog es un dato de **tenant**, resuelto con
`get_my_tenant_id()` + `is_owner_or_admin()`, no de sede.

`get_public_salon_blog_posts(p_tenant_id)`: rol `anon`, sin sesión, solo
`published = true`, últimos 20, **con el contenido completo en la misma
fila** — al no haber URL propia por artículo (decisión 2 de arriba), no
hace falta una segunda función de detalle.

### 1.3 Frontend

- **`BlogPost`** (panel del salón, incluye borradores) y
  **`PublicSalonBlogPost`** (público, solo publicados) — modelos separados
  a propósito, mismo criterio que `ReviewSummary`/`PublicSalonReviewItem`.
  `PublicSalonBlogPost.excerpt` corta el contenido en un límite de
  palabra, nunca a mitad de una.
- **Módulo "Blog"** (`lib/pages/blog_page.dart`, owner/admin, categoría
  Portafolio junto a "Fotos de trabajos" y "Reseñas"): tarjetas con
  portada, interruptor rápido publicar/despublicar, editar y eliminar (con
  limpieza de la portada en Storage antes de borrar la fila, mismo orden
  que D-119 usa para fotos). El diálogo de edición sube la portada con
  `BlogCoverUploadService` (mismo patrón que `TenantCoverUploadService`).
- **`PublicSalonPage`** gana una sección "Blog" más (D-165): tarjetas de
  portada+título+resumen; tocar una abre **`PublicBlogPostPage`** (página
  nueva, `Navigator.push` dentro del único `MaterialApp` de las páginas
  públicas, mismo patrón que `PublicBookingPage`/`PublicReviewPage`).
  `PublicSalonService.getFullProfile` suma el blog como quinta lista
  cargada en paralelo con `Future.wait`.

### 1.4 Pruebas (6 nuevas)

`test/blog_test.dart`: `BlogPost.fromMap` (publicado, borrador sin
portada, formato de fecha) y `PublicSalonBlogPost.fromMap`/`excerpt`
(contenido corto sin recortar, contenido largo recortado en un límite de
palabra completa).

Control `supabase/sql/190_test_blog_de_articulos.sql` con 8 casos en
`ROLLBACK`: crear un artículo publicado y uno en borrador, título/contenido
vacío rechazado, el panel del salón ve ambos estados, la página pública
solo ve el publicado, aislamiento entre tenants (un artículo de otro
negocio no se filtra), editar actualiza los campos, borrar quita el
artículo (y borrarlo dos veces se rechaza), y un estilista sin acceso a
ninguna función de escritura.

---

## 2. Qué quedó a medias / fuera de este bloque

- **Bloqueante para que todo esto tenga efecto real:** aplicar
  `supabase/migrations/20260829180000_blog_de_articulos.sql` en Supabase y
  correr `supabase/sql/190_test_blog_de_articulos.sql`. Instrucciones en
  el punto 4.
- **Sin URL propia por artículo**, a propósito (decisión 2 de este
  bloque). Si el propietario más adelante quiere compartir un artículo
  suelto en redes con su propio enlace, es un bloque nuevo aparte (probar
  el mismo patrón de slug que D-164 usó para el negocio, pero por
  artículo).
- **Sin editor de texto enriquecido** — el contenido es texto plano por
  párrafos, coherente con el resto de la app. Si algún negocio pide
  negritas/listas/imágenes intercaladas, es una decisión de alcance nueva.
- Con este bloque quedan **4 de 6 pasos de la Fase 6 cerrados** (6.1, 6.2,
  6.3, 6.6). Solo faltan 6.4 (Instagram automático) y 6.5 (WhatsApp con
  agente), **ambos con la misma dependencia: requieren revisión/
  verificación de Meta**, así que probablemente no sean el siguiente paso
  natural sin esa gestión adelantada.

## Qué NO hacer

- **No** asumir que el blog necesita `p_branch_id` en ninguna RPC — es un
  dato de tenant, igual que el nombre del negocio o el slug. Verificarlo
  en el código si esto vuelve a surgir en otra función del blog.
- **No** construir una URL propia por artículo sin confirmarlo antes con
  el propietario — es la decisión explícita de este bloque, no un olvido.
- **No** dejar que `get_public_salon_blog_posts` devuelva artículos con
  `published = false` bajo ninguna circunstancia — es el único candado de
  privacidad de un borrador.

---

## 3. Prompt exacto para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (bloque D-171: "Blog de
artículos", paso 6.6 de la Fase 6, blog por cada salón, sin url propia por
articulo todavia). El codigo esta completo, flutter analyze 0/0, flutter
test 222/222.

PENDIENTE BLOQUEANTE: la migracion 20260829180000_blog_de_articulos.sql
todavia no esta aplicada en Supabase. Antes de aplicarla:

  1. Respaldar: powershell -ExecutionPolicy Bypass -File scripts\respaldo_supabase.ps1
  2. Aplicar la migracion:
     powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
       -Archivo "supabase\migrations\20260829180000_blog_de_articulos.sql"
  3. Correr el control (termina en ROLLBACK, no deja rastro):
     powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
       -Archivo "supabase\sql\190_test_blog_de_articulos.sql"
  4. Confirmar los 8 casos "OK" en la salida antes de darlo por cerrado.

Con este bloque quedan 4 de 6 pasos de la Fase 6 cerrados (6.1, 6.2, 6.3,
6.6). Solo faltan 6.4 (Instagram automatico) y 6.5 (WhatsApp con agente),
ambos requieren revision/verificacion de Meta -- preguntarle al
propietario si ya adelanto esa gestion o si prefiere resolver primero la
eleccion de proveedor de IA real para 6.2/6.3 antes de seguir.
```
