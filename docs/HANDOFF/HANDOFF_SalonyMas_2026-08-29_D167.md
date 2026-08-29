# HANDOFF Salón y Más — 29 de agosto de 2026 (cierre de la Fase 5: Habeas Data y portal de la clienta, D-167)

**Bloque documentado:** decisión **D-167** · Cierre de la **FASE 5 — La cara
pública**: paso 5.7 (ninguna foto se publica en portafolio sin
consentimiento de la clienta, Ley 1581) y paso 5.6 (portal seguro "Mis
citas y fotos" con PIN de 4 dígitos).

**Estado:** `flutter analyze` 100% limpio (0/0), **176 de 176 pruebas en
verde** (sube de 168). Código de Flutter completo y en producción tras el
`git push` de este bloque. **La migración de base de datos
(`20260829120000_habeas_data_fotos_y_portal_cliente.sql`) y su control
(`187_test_habeas_data_y_portal_cliente.sql`) están escritos y revisados
línea por línea, pero NO están aplicados en Supabase todavía — eso lo hace
el propietario.** Hasta que se aplique: el checkbox de consentimiento en
`AddWorkPhotoDialog` no tiene efecto real en el servidor, y el botón
"Mis citas y fotos" / "Restablecer PIN del portal" van a fallar contra
funciones que todavía no existen en la base real.

---

## 0. Antes de empezar este bloque: una decisión de seguridad, no de código

El encargo original para el paso 5.6 pedía: *"si la clienta aún no tiene
PIN configurado, guarda el hash del nuevo PIN y le permite el ingreso"* —
es decir, autoservicio en el primer ingreso. **Se detuvo la construcción
antes de escribir una sola línea de SQL** porque eso es un hueco real de
apropiación de cuenta: cualquiera que supiera el celular de una clienta
real (un ex, un familiar, alguien que lo vio en un recibo) podría entrar al
portal, escribir ese celular con un PIN inventado, y quedarse con esa
cuenta antes de que la clienta real la usara — viendo su historial de citas
y sus fotos.

**Se consultó con el propietario (`AskUserQuestion`) antes de construir**,
presentando dos opciones: mantener el autoservicio con un freno de fuerza
bruta (el hueco de fondo seguía existiendo), o que **solo el salón asigne
el PIN**. Eligió la segunda, la recomendada. Esa decisión cambia el diseño
de raíz: `client_portal_authenticate` nunca crea un PIN, solo verifica uno
que el salón ya asignó desde la Ficha del cliente.

Dos refuerzos adicionales se agregaron sin consultarlos, porque son calidad
de implementación y no cambian el flujo que se acordó: el hash del PIN
lleva **sal por cliente** (SHA-256 sin sal es indefendible para 4 dígitos —
se precalculan las 10.000 combinaciones en un instante) y hay **bloqueo
tras 5 intentos fallidos** (sin esto, la RPC pública sería fuerza-bruteable
en segundos).

---

## 1. Dónde estamos

Con D-164 (slug), D-165 (página completa) y D-166 (dirección, reserva en
dos pasos, pantalla de éxito) ya construidos, quedaban los dos últimos
pasos de la Fase 5: el permiso legal para publicar fotos (5.7) y la cuenta
de la clienta para ver su propio historial (5.6). Este bloque cierra los
dos y, con ellos, la Fase 5 completa.

---

## 2. Qué pasó en este bloque

### 2.1 Paso 5.7 — Habeas Data (Ley 1581 de 2012)

`work_photos` gana `client_consent boolean not null default false` y
`client_consent_at timestamptz`. `create_work_photo` gana `p_client_consent`
como séptimo parámetro con `default false` (no hizo falta `drop function`).
`set_work_photo_portfolio_approval` (misma firma de 4 parámetros) rechaza
`p_approved = true` cuando `client_consent = false`, con el mensaje exacto
que pedía el encargo: *"No se puede publicar en portafolio sin
consentimiento de la clienta (Ley 1581)"*.

**Verificado antes de dar el bloque por seguro:** el orden de operación que
ya tenía D-119 ("primero la base, después mover el archivo al almacén
público") hace que este rechazo ocurra **antes** de que el archivo se
mueva — no hay ninguna ventana en la que una foto sin consentimiento quede
públicamente accesible por un momento.

En Flutter: `AddWorkPhotoDialog` gana el checkbox de autorización;
`FotosTrabajosPage` gana un indicador visual (`_ConsentBadge`, con
tooltip) que distingue "Autorizada" de "Solo archivo interno" en cada
tarjeta de la galería.

### 2.2 Paso 5.6 — Portal de la clienta

**Verificado en el código antes de escribir la función (regla 8.1):**
`admin_reset_client_portal_pin` se implementó **sin** el `p_branch_id` que
pedía el encargo. Los clientes son del **tenant**, no de una sede (D-011),
y `ClientesPage`/`ClientsService` nunca manejan `branchId` en ningún punto
real de la pantalla de Clientes — agregarlo habría sido inventar un dato
que la pantalla no tiene.

**Columnas nuevas en `clients`:** `portal_pin_hash`, `portal_pin_salt`
(refuerzo, no pedido), `portal_failed_attempts`/`portal_locked_until`
(refuerzo, no pedido), `portal_session_token`/`portal_session_expires_at`
(token opaco de 60 días, un `gen_random_uuid()`, no un JWT).

`client_portal_authenticate(p_tenant_id, p_phone, p_pin)` — compara el
celular **por dígitos** (sin importar `+57`, espacios o guiones), rechaza
si no hay PIN asignado, respeta el bloqueo, y devuelve un token nuevo en
cada ingreso correcto. `get_client_portal_data(p_tenant_id, p_phone,
p_portal_token)` devuelve un único `jsonb` con el nombre de la clienta y
tres listas de forma distinta (citas próximas, citas pasadas con
`already_reviewed`, y fotos) — no cabían en un solo `returns table`.

**Detalle verificado, no asumido:** las fotos del portal exigen además
`photo_url is not null`. Una foto puede tener `visible_to_customer = true`
sin estar aprobada para portafolio (D-119), y en ese caso vive en el
almacén **privado**, sin URL pública permanente. Mostrarla en un contexto
sin sesión (rol `anon`) exigiría generar URLs firmadas — infraestructura
nueva que queda **fuera de este bloque, documentada, no inventada a
medias**.

**Frontend:** `ClientPortalData` y sus tres modelos de detalle, más
`ClientPortalService` y `ClientPortalPage` (formulario de celular+PIN con
"recordarme" vía `SharedPreferences` — declarada como dependencia directa
en `pubspec.yaml`, ya venía transitiva, mismo criterio que `http` en
D-099 — y recuperación por WhatsApp con mensaje precargado). La vista del
portal usa scroll continuo, mismo criterio de D-165: Próximas citas,
Calificar servicios pendientes (solo aparece si hay alguno sin reseñar,
enlaza a `PublicReviewPage` con `Navigator.push`) y Mis fotos.

El grid de fotos con visor modal (zoom con `InteractiveViewer`) se extrajo
a un widget nuevo y compartido, `PhotoGridViewer`
(`lib/widgets/photo_grid_viewer.dart`), reutilizado también por el
portafolio público de D-165 — antes tenía su propia copia del mismo
código, ahora una sola fuente.

`_ClientDetailSheet` (Panel del Salón → Clientes) gana el botón
**"Restablecer PIN del portal"** con un diálogo dedicado
(`_ResetPortalPinDialog`) — misma RPC sirve para asignar el PIN la primera
vez y para restablecerlo.

**Verificado:** `flutter analyze` (0/0), `flutter test` (176/176). Control
`187_test_habeas_data_y_portal_cliente.sql` con 11 casos en `ROLLBACK`
contra un tenant real (con una clienta de prueba aislada, para no dejar
PINes ni consentimientos de prueba en clientes reales).

---

## 3. Qué quedó a medias / fuera de este bloque

- **Bloqueante para que todo esto tenga efecto real:** aplicar
  `supabase/migrations/20260829120000_habeas_data_fotos_y_portal_cliente.sql`
  en Supabase y correr `supabase/sql/187_test_habeas_data_y_portal_cliente.sql`.
  Instrucciones en el punto 4.
- **Si no se aplicó todavía:** la migración de D-165
  (`20260827160000_perfil_publico_completo.sql`) también sigue pendiente —
  sin ella la página pública no muestra servicios, portafolio, equipo ni
  reseñas, y el portal de la clienta no tiene desde dónde abrirse.
- **Fotos visibles pero no aprobadas para portafolio no llegan al portal**
  (necesitarían URLs firmadas para acceso anónimo). Si el propietario
  quiere que la clienta vea también esas, es un bloque nuevo aparte.
- Con este bloque, **la Fase 5 completa queda cerrada** (D-164 a D-167).
  El Plan Maestro no tiene un siguiente paso numerado todavía para después
  de la Fase 5 — revisar con el propietario qué sigue.

## Qué NO hacer

- **No** dejar que `client_portal_authenticate` cree un PIN por su cuenta,
  bajo ninguna circunstancia — es la decisión de seguridad central de este
  bloque, confirmada explícitamente con el propietario.
- **No** asumir que `admin_reset_client_portal_pin` necesita `p_branch_id`
  porque el encargo lo pedía — los clientes son del tenant, no de una
  sede. Verificarlo en el código, no en el encargo, si esto vuelve a
  aparecer en otra RPC de clientes.
- **No** mostrar en el portal una foto que no tenga `photo_url` — las
  fotos privadas-pero-visibles-al-cliente no tienen URL pública permanente
  y no se pueden mostrar sin sesión sin construir primero URLs firmadas.

---

## 4. Prompt exacto para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (bloque D-167: cierre de la
Fase 5 -- consentimiento Ley 1581 para publicar fotos, y portal seguro de
la clienta con PIN asignado solo por el salon). El codigo de Flutter esta
completo, flutter analyze 0/0, flutter test 176/176, y el git push ya se
hizo.

PENDIENTE BLOQUEANTE: la migracion 20260829120000_habeas_data_fotos_y_portal_cliente.sql
todavia no esta aplicada en Supabase. Antes de aplicarla:

  1. Respaldar: powershell -ExecutionPolicy Bypass -File scripts\respaldo_supabase.ps1
  2. Aplicar la migracion:
     powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
       -Archivo "supabase\migrations\20260829120000_habeas_data_fotos_y_portal_cliente.sql"
  3. Correr el control (termina en ROLLBACK, no deja rastro):
     powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
       -Archivo "supabase\sql\187_test_habeas_data_y_portal_cliente.sql"
  4. Confirmar los 11 casos "OK" en la salida antes de darlo por cerrado.

Si la migracion de D-165 (20260827160000_perfil_publico_completo.sql)
tampoco se aplico todavia, aplicarla tambien primero.

Con este bloque la Fase 5 completa queda cerrada (D-164 a D-167). No hay
un siguiente paso numerado en el Plan Maestro despues de la Fase 5 --
preguntarle al propietario que sigue antes de proponer algo.

No dejes que client_portal_authenticate cree un PIN por su cuenta bajo
ninguna circunstancia -- es la decision de seguridad central de este
bloque, confirmada explicitamente con el propietario.
```
