# HANDOFF Salón y Más — 7 de septiembre de 2026 ("El guardián de la documentación y el P0 de las sedes", D-223 y D-224)

**Bloque documentado:** decisiones **D-222**, **D-223** y **D-224** · Fase **9**, pasos **9.22**, **9.27** y media de **9.6**.

**Estado:** ✅ Documentación consistente (guardián en verde, 0 avisos). ⚠️ **Dos cosas escritas y sin desplegar.**

> El bloque anterior está en `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-07_D221.md`.

---

## 1. Qué se cerró

**Paso 9.22 (D-222) — La tarifa de los diez primeros: 50.000 fijos**, congelados de por vida, por el negocio; las sedes adicionales van a tarifa vigente. **No son "pioneros": son socios de diseño**, que prueban la app como está y la pulen. Se aplica con `price_cop = 50000` y **`discount_percent` vacío** — se acumulan, no se eligen: los dos juntos darían 25.000.

**Paso 9.27 (D-224) — El P0 de las sedes.** `verify-epayco-transaction` ahora resuelve la intención de pago por número de factura, saca de ahí negocio, sede y plan, y bifurca a `beautyos_procesar_pago_de_sede` cuando hay sede — igual que el webhook. Antes aplicaba todo cobro al negocio, el webhook llegaba después, encontraba el evento puesto y abortaba por idempotencia: **el dinero salía y la sede se quedaba en `pending` para siempre.**

De paso endurece el perímetro: el negocio deja de salir de `x_extra1` —que viaja fuera de la firma de ePayco, y por eso existe D-182— y sale de la intención que escribió el servidor. La comprobación de pertenencia de D-181 se mantiene sobre el negocio ya resuelto.

**Media de 9.6 (D-223) — El guardián de la documentación.** `scripts/verificar_documentos.py`, ya en el CI. Falla si hay caracteres de control o BOM, si el índice del registro no cuadra con el cuerpo, si una tabla tiene filas de distinto ancho, si hay más de un HANDOFF vigente, o si el Plan Maestro cita una decisión que no existe.

---

## 2. Por qué nació el guardián

El propietario preguntó por qué tantos errores en una sesión. Se contaron cuatro y **los cuatro son el mismo**: afirmar desde una señal —un nombre de archivo, una coincidencia de `grep`— en vez de desde el contenido.

La regla ya existía: la número 1 del apartado 8, *"Verificar en el código antes de afirmar"*. No faltaba una herramienta para pensar; faltaba cumplir lo escrito. El guardián hace que dejar de cumplirla tenga consecuencia mecánica.

**Encontró al primer intento** tres BOM en handoffs archivados y cinco filas de tabla mal formadas. Y su primera versión daba tres falsos positivos —contaba los `|` escapados dentro de código— así que **se afinó antes de aceptarlo**: un guardián que grita en falso se acaba ignorando.

**Y cazó un quinto error mientras se escribía su propia decisión:** al redactar D-223 se coló otro carácter de control, por escribir una ruta con contrabarra a través de tres capas de escapado. Falló, se reparó, quedó en verde.

**Lo que el guardián NO hace:** no lee el sentido de nada. No habría cazado lo de OneDrive ni lo del hallazgo AA. Para eso sigue haciendo falta abrir el archivo.

---

## 3. Lo que falta desplegar — 👤 propietario

Dos cosas escritas que **todavía no están en producción**:

1. **La migración `20260907120000`** (D-221, el pionero sin 50%). No urge: se puede cobrar sin marcar la casilla.
2. **La Edge Function `verify-epayco-transaction`** (D-224, el P0 de las sedes). **Esta sí conviene**, porque hasta desplegarla una sede pagada sigue sin activarse.

---

## 4. Lo siguiente

**Turno 1 — la puerta del piloto:** 9.29 (nadie puede marcar un negocio como de prueba, y los tres cuentan como reales), 9.19 (la base limpia) y 9.15 (Supabase a Pro).

**Turno 2 — el camino del dinero:** 9.10 (fallar cerrado en vez de cobrar 150.000 a ciegas), 9.7 y **9.8, que ahora incluye probar el cobro de una segunda sede** — es lo único que verifica D-224 de verdad.

---

## 5. Lo que NO hay que hacer

- **No dar por probado el arreglo de las sedes.** Está verificado estructuralmente, no contra un pago real. `deno` no está instalado, así que ni siquiera pasó un comprobador de tipos: la mitad del paso 9.6 sigue abierta.
- **No poner `price_cop` y `discount_percent` a la vez.** Se acumulan (D-222).
- **No marcar a nadie como Pionero** hasta aplicar la migración de D-221.
- **No aceptar un hallazgo de Antigravity sin verificarlo** contra el código (D-220).

---

## 6. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-223 y D-224: el guardián de la
documentación y el P0 de las sedes).

Quedan dos cosas sin desplegar: la migración 20260907120000 y la Edge Function
verify-epayco-transaction. La segunda importa: hasta desplegarla, una sede pagada
no se activa.

Antes de tocar documentación, corre: python scripts/verificar_documentos.py
Debe salir en verde.

Turno 1 de la Fase 9: pasos 9.29, 9.19 y 9.15.
```
