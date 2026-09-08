# HANDOFF Salón y Más — 8 de septiembre de 2026 ("El turno 1 cerrado y el cobro que deja de adivinar", D-226 y D-227)

**Bloque documentado:** decisiones **D-226** y **D-227** · Fase **9**, turnos **1** y **2**.

**Estado:** ✅ Turno 1 cerrado. ✅ Todo el código del turno 2 hecho y desplegado. ⚠️ **Quedan 9.7 y 9.8, que necesitan un pago real.**

> El bloque anterior está en `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-07_D225.md`.

---

## 1. Turno 1 — cerrado con tres decisiones del propietario (D-226)

| Paso | Decisión |
|---|---|
| **9.19** | **Los negocios de ensayo se quedan.** Marcados con `is_demo`, y con una razón mejor que archivarlos: son los ojos para ver las pantallas como las ve una clienta |
| **9.15** | **Supabase Pro se aplaza** hasta el primer cliente que pague. Riesgo evaluado antes de decidir: de los tres riesgos del plan gratuito, **solo uno es serio** — no hay recuperación a un punto en el tiempo, así que **el respaldo manual es la única red** |
| **9.17** | **La contraseña no se rota.** Solo la sabe el propietario y no hay fuga, coherente con lo que el hallazgo X ya decía. Su condición de urgencia sigue viva |

**Dos condiciones del 9.15 que no son negociables:** correr el respaldo **cada semana**, y mirar el almacenamiento — al pasar de **700 MB** se paga.

---

## 2. El hallazgo AC: por qué la app tarda en abrir

Medido contra producción, no estimado:

| Archivo | Peso |
|---|---|
| `main.dart.js` | **4,8 MB** |
| `canvaskit.wasm` | **7,2 MB** |

**12 MB antes de que la app pinte nada**, y `web/_headers` aplica `max-age=0, must-revalidate` a **todas** las rutas, así que el navegador los revalida en cada apertura (`cf-cache-status: REVALIDATED`).

**Lo importante del diagnóstico:** no es capacidad y **no empeora con más usuarios**. La app son archivos estáticos en Cloudflare; cien personas abriendo son cien cargas lentas independientes, no una fila. Lo que sí se estrecharía con concurrencia real es la base en plan gratuito.

**Y una consecuencia que cambia prioridades:** Flutter compila todo en un archivo, así que **el Panel de Plataforma — 4.230 líneas que solo usa el propietario — viaja al navegador de cada salón**. Partir la app en los cinco lugares de D-219 es lo que permite cargar cada pieza al abrirla: **el arreglo de la interfaz y el del rendimiento son el mismo trabajo.**

Dos arreglos pendientes, sin empezar: cachear `canvaskit/*` un año (barato, pero **afecta a `web_headers_security_test.dart`** y hay que verificar cómo se combinan las reglas en Cloudflare Pages antes de tocarlo), y la carga diferida por módulo.

---

## 3. El cobro deja de adivinar (D-227, paso 9.10 y hallazgo W)

El fallback se retira entero. Ahora: **503** si la RPC de cálculo falla, **409** si no hay cargo que calcular.

**Al ir a quitarlo aparecieron tres defectos que el hallazgo W no recogía:**

1. Leía `discount_ends_at` y **no lo miraba en ninguna condición** → aplicaba descuentos vencidos. Mismo patrón que `applies_after_discount` (D-220): un campo que se lee y se ignora. **Van dos en el camino del dinero.**
2. **Ignoraba `branchId`** → si fallaba el cálculo de una sede, le cobraba el monto del negocio entero.
3. Ignoraba el prorrateo y el anclaje de ciclo de D-160.

**Y la otra mitad:** los mensajes cuidados del servidor llegaban envueltos en `FunctionException(status: N, details: {...})` — literalmente lo que el propietario leyó el 07-sep. Ahora se extrae el campo `error` y se muestra tal cual.

**Tercer hallazgo de paso:** los informes a Sentry mandaban el texto literal `$branchId` porque el `$` estaba escapado. El identificador nunca llegó al monitoreo. Corregido.

**Desplegado el 08-sep.** `flutter analyze` 0/0 y **391 pruebas en verde**.

---

## 4. Lo que sigue — y son los dos tuyos

**Paso 9.7 y 9.8, y ahora valen más que ayer.**

Con el fallback retirado, **el cobro es más correcto y más frágil a la vez**: si el cálculo falla, ya no cobra un monto inventado — falla a la vista. Eso es lo que queremos, **pero significa que el próximo intento de cobro es también la prueba de D-227.**

Y el 9.8 debe incluir **el pago de una segunda sede**, que es lo único que prueba de verdad el arreglo del P0 (D-224).

Cuestan un cobro de 10.000 con la tarifa que ya tiene Prueba Barbería Elite.

**Después, el turno 3:** 9.6 (la mitad que falta, el `deno check`) y 9.9 (las pruebas del Panel).

---

## 5. Lo que NO hay que hacer

- **No dar por probado nada del camino del dinero sin un pago real.** Tres arreglos seguidos (D-224, D-227) están desplegados y verificados solo de forma estructural.
- **No tocar `web/_headers`** sin revisar antes `web_headers_security_test.dart` y cómo combina reglas Cloudflare Pages.
- **No poner `price_cop` y `discount_percent` a la vez** (D-222, probado en el control 207).
- **No aceptar un hallazgo sin verificarlo contra la fuente** — de Antigravity (D-220) o míos: en estos dos días, dos comprobaciones mal diseñadas dieron falsos positivos sobre cosas que estaban bien.

---

## 6. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-226 y D-227: turno 1 cerrado y
el cobro que deja de adivinar).

Antes de tocar documentación: python scripts/verificar_documentos.py

Los turnos 1 y 2 no tienen trabajo de código pendiente. Quedan 9.7 y 9.8, que
necesitan un pago real de 10.000 e incluyen el de una segunda sede.

Turno 3: paso 9.6 (deno check) y 9.9 (pruebas del Panel de Plataforma).
```
