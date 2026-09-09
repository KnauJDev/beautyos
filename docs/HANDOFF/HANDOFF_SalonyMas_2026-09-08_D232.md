# HANDOFF Salón y Más — 8 de septiembre de 2026 ("El primer cobro real, la interfaz al día y el dinero de las sedes", D-228 a D-232)

**Bloque documentado:** decisiones **D-228** a **D-232** · Fase **9**, turnos **1**, **2** y paso **9.34**.

**Estado:** ✅ Todo aplicado y verificado. ⚠️ **Falta un solo pago: el de una segunda sede.**

> El bloque anterior está en `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-08_D227.md`.

---

## 1. El primer cobro real del producto

**Prueba Barbería Elite pagó 10.000 el 08-sep y quedó activa hasta el 08-10.** Fue el primer cobro que funciona de punta a punta desde que el proyecto existe, y probó cuatro cosas de una vez:

| | |
|---|---|
| **D-222** | Cobró la tarifa pactada — 10.000, no los 150.000 de lista |
| **D-227** | El cálculo funcionó de verdad: sin fallback, si hubiera fallado no habría abierto la pasarela |
| **El ciclo** | pago → verificación → webhook → activación |
| **D-225** | El panel muestra **MRR $0** con tres salones «1 mes pagado». Correcto: los tres son demo |

---

## 2. Lo que se decidió y arregló

**D-228 — El DSN de Sentry va en el código a propósito.** No contradice el invariante de `AGENTS.md`: es de solo escritura, y sobre todo **una app web no puede esconderle nada al navegador**. Mismo caso que la `publishableKey` (D-197). **La regla, dicha entera: una llave puede ir en el cliente solo si no puede hacer daño desde el cliente.**

**D-229 y D-230 — La interfaz de tarifas mentía.** El interruptor seguía prometiendo *«50% de por vida»* que D-221 había retirado 24 horas antes; el campo de descuento decía «opcional» cuando en realidad **se multiplica**; el rótulo del listado anunciaba `★ PIONERO 50%` sin mirar si existía descuento; y el diálogo **autorellenaba el motivo, sobrescribiendo el pactado** — Exportadora tenía escrito su acuerdo y un clic lo habría borrado.

**D-231 y D-232 — El dinero de las sedes no contaba en ninguna cifra.** El MRR sumaba el precio del negocio una vez por negocio, y el pago de sede no escribía `monto_cop_recibido`, la clave que leen el cobrado histórico **y las comisiones de partners**. Un partner que refiriera un salón de tres sedes cobraba por una. **Eso no era un número mal pintado: era dinero que se le debe a un tercero y no aparecía.**

Arreglado y aplicado, con el **control 208 en verde**: dos sedes activas suben el MRR 60.000 y no 30.000, un demo no aporta, una sede desactivada no aporta, y el evento del pago trae la cifra correcta.

---

## 3. La regla nueva: 16-ter

> **Cuando una decisión cambia lo que hace el servidor, la pantalla que lo ofrece cambia en el mismo bloque.**

Pasó **tres veces el mismo día**: los mensajes de D-227 llegaban envueltos en la traza de la excepción, el interruptor prometía un descuento retirado, y el rótulo anunciaba un 50% inexistente. **Incluye los rótulos, los textos de ayuda y lo que se autorellena**, no solo los botones.

---

## 4. Lo que falta, y es un solo pago

**El de una segunda sede** (pasos 9.7 y 9.8). Es lo único que verifica el P0 de D-224 contra dinero real.

Naguara de Uñas ya tiene dos sedes —la principal y **«Uñas Naguara»**— ambas al día hasta el 22-sep a 10.000. Pagarla ahora sería una **renovación anticipada**: extiende su período al 22-oct sin mover el del negocio, y sirve igual para la prueba.

**Después, el turno 3:** paso **9.35** (ver el estado de cada sede en el Panel) y **9.6** (la mitad que falta del `deno check`), y **9.9** (pruebas del Panel).

---

## 5. Lo que NO hay que hacer

- **No poner precio y descuento a la vez.** Se multiplican (D-222, probado en el control 207).
- **No fiarse del rótulo de un negocio para saber su precio.** Ahora dice solo `★ PIONERO`, sin cifra, porque la cifra vive en la tarifa pactada.
- **No mover el DSN de Sentry a una variable de entorno «por seguridad».** No añade ninguna y rompe la publicación (D-228).
- **No escribir un control sin leer antes la definición completa de las tablas que toca.** El control 208 necesitó **tres corridas**, y las dos primeras fallaron por el fixture y no por lo que probaba: `branches.slug` es obligatorio, y un disparador ya crea la suscripción de cada sede. Ninguna de las dos cosas se leyó antes de escribir.
- **No dar por probado el camino del dinero sin un pago real.** Sigue valiendo, y ahora solo falta el de sede.

---

## 6. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-228 a D-232).

Antes de tocar documentación: python scripts/verificar_documentos.py

Todo está aplicado. Falta un solo pago real: el de una segunda sede, que es lo
único que verifica el P0 de D-224. Naguara de Uñas tiene dos sedes al día hasta
el 22-sep; pagar "Uñas Naguara" sería una renovación anticipada y sirve igual.

Después: paso 9.35 (el estado de cada sede en el Panel), 9.6 (deno check) y 9.9
(pruebas del Panel de Plataforma).
```
