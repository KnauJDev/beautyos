# HANDOFF Salón y Más — 27 de agosto de 2026 (Fase 5 Bloque 1: enlace público del negocio, D-164)

**Bloque documentado:** decisión **D-164** · Arranque formal de la **FASE 5 —
La cara pública**, Bloque 1 (pasos 5.1 a 5.4): cada negocio recibe un enlace
propio, `salonymas.com/<slug>`, decidido en D-098 (07-ago) y construido
ahora.

**Estado:** `flutter analyze` 100% limpio (0/0), **162 de 162 pruebas en
verde** (sube de 157 por las 5 pruebas nuevas de `PublicSalonProfile`).
Código de Flutter completo y en producción tras el `git push` de este
bloque. **La migración de base de datos
(`20260827140000_slugs_publicos_y_perfil_comercial.sql`) y su control
(`184_test_slugs_publicos.sql`) están escritos y revisados línea por línea,
pero NO están aplicados en Supabase todavía — eso lo hace el propietario.**
Hasta que se aplique: ningún tenant tiene columna `slug` en producción, así
que la tarjeta "Enlace web de tu negocio" en Configuración y la página
pública no van a tener nada que mostrar.

---

## 1. Dónde estamos

D-098 (07-ago) ya había decidido la arquitectura completa del enlace propio
de cada negocio: ruta por defecto (`salonymas.com/<slug>`) para todos desde
el registro, sin configurar nada por negocio, con dominio propio como
funcionalidad de pago para más adelante (Fase 5, fuera de este bloque). Ese
mismo día quedó escrito qué piezas hacían falta: "columna de identificador
único por negocio, generación automática desde el nombre, función pública
que lo resuelva sin sesión, enrutado por ruta en Flutter y un `_redirects`
para que Cloudflare Pages devuelva la aplicación en cualquier ruta." Este
bloque construye exactamente esas piezas, más la gestión del enlace desde
Configuración que el propietario pidió explícitamente hoy.

---

## 2. Qué pasó en este bloque

### 2.1 Slug: transformación pura + reglas de negocio, separadas a propósito

`private.beautyos_slugify(text)` es una función **pura**: minúsculas, sin
acentos ni eñe (mapeo explícito de caracteres con `translate`, sin depender
de la extensión `unaccent` — evita sumar una dependencia nueva al proyecto
para 24 caracteres), separadores colapsados en un solo guion. No valida
longitud, unicidad ni palabras reservadas — eso lo hace quien la llama.

`private.beautyos_generate_unique_tenant_slug(business_name)` envuelve esa
transformación con las reglas que la función pura no debe cargar: un nombre
sin nada aprovechable (solo símbolos/emoji) cae a un id corto y único en vez
de fallar; un slug de más de 50 caracteres se trunca; un slug que coincide
con una palabra reservada gana el sufijo `-salon`; una colisión con un slug
ya existente suma un sufijo numérico (`-2`, `-3`...).

**Palabras reservadas** (`login`, `register`, `auth`, `planes`, `pricing`,
`terminos`, `privacidad`, `terms`, `privacy`, `admin`, `dashboard`,
`settings`, `soporte`, `api`) están **repetidas a propósito en 4 sitios**
dentro de la migración (el `CHECK` de la columna, `check_slug_availability`,
`update_tenant_slug` y el generador) y una quinta vez en `lib/main.dart`. Un
`CHECK` de Postgres no admite subconsulta contra otra tabla, así que no hay
forma de compartir una única fuente de verdad en SQL puro para esa lista. Si
se agrega una ruta reservada nueva, hay que tocar los 5 sitios (buscar
`'login'`, `'register'`, `'auth'` para encontrarlos todos).

**Backfill:** cada tenant existente sin slug lo recibe en la misma migración,
vía un `do $$` que reutiliza el generador. **`register_tenant`** (misma
firma, 8 parámetros — no hizo falta `drop function`) genera el slug del
nombre al nacer el tenant, para que sea automático desde el registro también
para los negocios nuevos, tal como pedía D-098.

### 2.2 Función pública, sin sesión

`get_public_salon_by_slug(p_slug)` — rol `anon`. Solo datos de vitrina:
nombre, slug, tipo de negocio, logo, portada, tema/color de marca, ciudad,
WhatsApp, teléfono, Instagram, Facebook. **Nunca correo ni nada operativo.**

**Verificado en el código antes de escribir la función (regla 8.1 del Plan
Maestro):** `address` no vive en `tenants`, solo en `branches`. Se toma de
la sede principal activa del tenant vía `left join` — es la única dirección
física con sentido hoy, porque la Fase 5 sigue siendo un perfil público por
**tenant**, no por sede.

`check_slug_availability(p_slug)` y `update_tenant_slug(p_new_slug)`
(autoservicio, exclusivo owner/admin vía `is_owner_or_admin()`, mismo
criterio que `update_tenant_contact_info` de D-162) completan la gestión.

`get_business_settings()` gana la columna `slug` — cambia la forma del
retorno, así que exigió `drop function` primero (mismo motivo que
`update_tenant_contact_info` en D-162: `create or replace` no admite cambiar
lo que la función devuelve).

### 2.3 Enrutado

`lib/main.dart`: se lee `Uri.base.pathSegments` (**un solo segmento**, para
no chocar con las subrutas que va a traer la página del negocio en el paso
5.5) y, si no está en la lista de rutas reservadas, se resuelve como slug —
con `?salon=<slug>` como respaldo. Mismo patrón que las demás rutas públicas
de `BeautyOSApp.build()` (reserva, reseña, planes, términos): se resuelve
**antes** de `AuthGate`, para que un visitante anónimo nunca pase por login.

`web/_redirects` con `/* /index.html 200` — **no existía ningún archivo de
fallback SPA en `web/`**, así que hoy Cloudflare Pages devuelve 404 en
cualquier ruta que no sea la raíz. Sin este archivo, `salonymas.com/lo-que-sea`
nunca llega a cargar la app de Flutter para que el enrutado de arriba pueda
actuar.

### 2.4 Frontend

`PublicSalonProfile`/`PublicSalonService` (nuevos, sirven solo a la página
pública) y `PublicSalonPage` (`lib/pages/public_salon_page.dart`) — mismo
patrón visual y de estados (cargando/error/no encontrado) que
`PublicBookingPage`, con `AppBrand.aplicar(themeKey, brandColor)` antes de
pintar (D-093d: el visitante ve los colores del salón, no los de Salón y
Más). Base lista para portafolio y catálogo del paso 5.5, con un aviso de
"muy pronto" en el lugar donde van a vivir.

`PublicSalonLinkCard` en Configuración (junto a `PublicBookingLinkCard`, el
enlace feo por UUID de la reserva directa, que sigue existiendo para otro
propósito): copiar, compartir por WhatsApp (`wa.me/?text=`, sin destinatario
fijo — a diferencia del botón de WhatsApp de contacto, que sí lleva un
número) y "Modificar enlace": diálogo con comprobación de disponibilidad en
vivo (`Timer` de 400 ms tras cada tecla, sin depender de ningún paquete de
debounce nuevo).

**Verificado:** `flutter analyze` (0/0), `flutter test` (162/162). La
migración y el control están escritos y revisados línea por línea contra
los originales que modifican (`register_tenant`, `get_business_settings`),
pero **no ejecutados contra Supabase** — eso es lo pendiente de este bloque.

---

## 3. Qué quedó a medias / fuera de este bloque

- **Bloqueante para que el enlace público funcione de verdad:** aplicar
  `supabase/migrations/20260827140000_slugs_publicos_y_perfil_comercial.sql`
  en Supabase y correr `supabase/sql/184_test_slugs_publicos.sql` para
  confirmar los 6 casos en verde contra la base real. Instrucciones en el
  punto 4.
- Paso 5.5 (portafolio, equipo, reseñas y reservar dentro de la misma
  página) sigue **sin especificar** — `PublicSalonPage` ya tiene el
  encabezado y el hueco listo para recibirlo.
- Heredado de D-161: el selector de sedes del header no se refresca solo
  tras crear una sede desde Configuración.

## Qué NO hacer

- **No** agregar una ruta reservada nueva en un solo sitio — son 5 (el
  `CHECK` de `tenants.slug`, `check_slug_availability`, `update_tenant_slug`,
  `private.beautyos_generate_unique_tenant_slug` y la lista de
  `lib/main.dart`). Un `CHECK` de Postgres no admite subconsulta contra otra
  tabla, así que no hay forma de compartir una única fuente de verdad para
  esto en SQL puro.
- **No** asumir que `tenants` tiene columna `address` — solo `branches` la
  tiene. La página pública la toma de la sede principal activa.
- **No** dejar que el enrutado por slug capture más de un segmento de ruta
  (`pathSegments.length == 1` a propósito) — el paso 5.5 va a necesitar
  subrutas como `/<slug>/reservar` dentro del mismo negocio, y capturar de
  más las rompería.

---

## 4. Prompt exacto para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (bloque D-164: Fase 5 Bloque 1
-- slug único por negocio, resolucion publica sin sesion, enrutado en
Flutter/_redirects, y gestion del enlace desde Configuracion). El codigo de
Flutter esta completo, flutter analyze 0/0, flutter test 162/162, y el git
push ya se hizo.

PENDIENTE BLOQUEANTE: la migracion 20260827140000_slugs_publicos_y_perfil_comercial.sql
todavia no esta aplicada en Supabase. Antes de aplicarla:

  1. Respaldar: powershell -ExecutionPolicy Bypass -File scripts\respaldo_supabase.ps1
  2. Aplicar la migracion:
     powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
       -Archivo "supabase\migrations\20260827140000_slugs_publicos_y_perfil_comercial.sql"
  3. Correr el control (termina en ROLLBACK, no deja rastro):
     powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
       -Archivo "supabase\sql\184_test_slugs_publicos.sql"
  4. Confirmar los 6 casos "OK" en la salida antes de darlo por cerrado.

Hasta que esto se aplique, la tarjeta "Enlace web de tu negocio" en
Configuracion y la pagina publica no tienen datos que mostrar (ningun tenant
tiene columna slug todavia en produccion).

El paso 5.5 (portafolio, equipo, resenas y reservar dentro de la pagina
publica) sigue sin especificar -- es el siguiente punto natural de la Fase 5.

No agregues una ruta reservada nueva en un solo sitio: son 5 (buscar
'login', 'register', 'auth' en la migracion de D-164 y en main.dart).
```
