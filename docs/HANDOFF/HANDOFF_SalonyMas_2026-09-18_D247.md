# HANDOFF Salón y Más — 18 de septiembre de 2026 ("Doce fallos que ninguna prueba veía", D-247)

**Bloque documentado:** decisión **D-247** · Fase **9**, pasos **9.48** (nuevo, pendiente) y **9.49** (cerrado) · hallazgos **AM** a **AX**, e idea **I-18**.

**Estado:** ✅ Documentación aplicada y verificada. Guardián en verde.
🔴 **No se tocó una sola línea de código.** Todo lo de hoy son hallazgos y registro.

> El bloque anterior está en `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-17_D246.md`.

---

## 1. Lo que hay que leer si solo se lee una cosa

**AH estaba mal enunciado, y su arreglo también.** El 17-sep se anotó que *el enlace de confirmación caduca* y que se resolvía **subiendo el plazo en Supabase**.

**Las dos cosas eran falsas.** El enlace **llega ya gastado**: es de un solo uso y el escáner del buzón lo visita antes que la persona. Subir el plazo no habría cambiado nada.

Se vio así: correo enviado **12:38**, pulsado **12:40**, `otp_expired` — y **la cuenta quedó confirmada igual**, porque el estilista entró con su contraseña acto seguido.

> **Un enunciado de hallazgo es una hipótesis, no un hecho. AH llevaba un día escrito, con arreglo asignado, y era falso.**

---

## 2. La lección de método, que es la que vale

El 17-sep se aprendió que *una prueba que lee código comprueba la intención; una que lo ejecuta comprueba el hecho*. Hoy se añade el escalón siguiente:

> **Ejecutar una función comprueba esa función. Recorrer el camino comprueba el producto.**

**Ninguno de los doce hallazgos de hoy lo habría encontrado una prueba automática:**

- **AX** apareció porque el propietario **tardó en teclear**.
- **AT** apareció porque se miró **el inventario de un borrado**.
- **AO** apareció porque alguien creó **el mismo cliente dos veces a propósito**.

---

## 3. Los doce hallazgos nuevos, por lo que cuestan

### Dinero

| | Qué | Estado |
|---|---|---|
| **AJ** 🔴 | **Ya no es teoría: $7.200 sobre $18.000 es el 40% exacto.** La comisión que nadie confirmó es una cuenta por pagar a una persona — y **el estilista la ve antes que el dueño** | Abierto |
| **AP** 🔴 | **Solo el estilista puede dar por terminado un servicio**, desde *Mi agenda*. Sin eso el ticket no cierra y **no nace la comisión aunque la clienta pague**. El servidor SÍ autoriza a dueño, admin y recepción: **no falta permiso, falta el botón** | Abierto |

### Datos que se corrompen en silencio

| | Qué | Estado |
|---|---|---|
| **AO** 🔴 | **Clientas duplicadas sin freno y sin borrado, con tres filos:** parte el historial de valor, deja elegir a ciegas al agendar, y **el PIN de la ficha nueva no abre el portal jamás** (`order by created_at limit 1`) | Abierto |
| **AW** 🔴 | **La reserva pública FABRICA esos duplicados:** compara el teléfono como texto, el portal lo compara por dígitos. `350 681 56 29` creó ficha nueva | Abierto |
| **AN** 🟡 | Un estilista acaba con dos nombres y nadie los concilia | Abierto |

### La puerta de entrada

| | Qué | Estado |
|---|---|---|
| **AM** 🔴 | **Un acceso fallido no avisa de nada.** `main.dart` lee doce parámetros de la dirección y **ninguno es el error** | Abierto |
| **AT** 🔴 | **El único pionero real entró, no hizo nada y nadie se enteró.** 28 días, 0 clientas, 0 tickets, 0 servicios | Abierto — **se arregla preguntándole** |

### Consentimiento y ley

| | Qué | Estado |
|---|---|---|
| **AQ** 🔴 | **El estilista firma por la clienta** al marcar que ella autorizó publicar su foto | Abierto → **paso 9.48** |
| **AU** 🟡 | *Visible al cliente* no hace visible la foto al cliente | Abierto → **paso 9.48** |
| **AS** 🔴 | Al borrar un negocio, **las fotos de sus clientas se quedan públicas** y sin dueño conocido | Abierto |

### Lo barato

| | Qué | Estado |
|---|---|---|
| **AR** 🟡 | El Panel cuenta las pruebas de dos maneras: arriba 1, abajo 2. Dos líneas seguidas del mismo archivo | Abierto |
| **AV** 🟡 | **La pantalla de reseña no tiene una sola tilde**, y es de cara al público. La única página pública así | Abierto |
| **AX** 🟡 | La hora elegida caduca mientras se rellena el formulario, y **el aviso dice que no hay disponibilidad**, que no es lo que pasó | Abierto |

**Cinco enunciados corregidos:** **AH** (llega gastado, no caduca), **AK** (no son cuatro diálogos, son **seis**), **AL** (la mitad es código nuestro: `register_page.dart:99`), **AG** (el patrón correcto ya existe en la misma pantalla), **N** (evidencia en vivo).

---

## 4. Dónde quedó el recorrido

**`docs/04_pruebas/RECORRIDO_COMPLETO_DE_UN_CLIENTE.md`**, ahora con **20 pasos**: se añadieron el **11b** (el catálogo, sin el cual el 12 no se puede hacer), el **19** (página pública y portal de la clienta) y el **20** (reserva pública).

| Pasos | Estado |
|---|---|
| 1 a 16 | ✅ **Hechos** |
| 19 y 20 | ✅ **Hechos** — no estaban en el guion |
| **17 y 18** | ⏸️ **Aplazados a propósito** |

**Por qué se aplazaron:** el borrado ya se probó contra **Exportadora** — 28 días de historia, **17 filas en 10 tablas**, 0 pagos — y repetirlo con la Peluquería habría costado el único montaje completo que existe. **El paso 18 sigue sin probarse con nadie.**

### Lo que existe ahora mismo en producción

| | |
|---|---|
| Negocio | **Peluquería Éxito Prueba** — `TRIALING`, vence **24-sep**, marcado como ensayo |
| Enlace público | `salonymas.com/peluqueria-exito-prueba` |
| Equipo | 4 cuentas: dueña, administradora, asistente, **estilista** (`elboga013`) |
| Catálogo | 2 servicios, ambos asignados a Erick |
| Clientas | **4 fichas para 2 personas** — dejadas así a propósito, son la evidencia de AO y AW |
| Tickets | 4: uno cobrado y cerrado, dos solicitados por reserva pública, uno confirmado |
| Dinero | $18.000 cobrados · comisión $7.200 · **ganancia neta $10.800** |
| Borrado hoy | **Exportadora** (Miguel Elías), negocio de ensayo desde D-225 |

---

## 5. Lo que NO hay que hacer

- 🔴 **NO pagar la suscripción.** La sede dice **$150.000** y `EPAYCO_TEST_MODE` es `false`: sería dinero real. Primero **AG**.
- 🔴 **NO invitar a los diez socios** hasta cerrar **AH + AM**. Si el enlace llega gastado y nadie avisa, **se caen en la puerta y solo se ve que no entraron**.
- 🔴 **NO abrir la reserva pública** a nadie hasta cerrar **AW**. Cada clienta que escriba su teléfono con espacios estrena ficha.
- **NO borrar la Peluquería Éxito Prueba.** Es el banco de pruebas y su montaje costó una tarde entera.
- **NO limpiar las cuatro fichas de David.** Son la evidencia de AO y AW.
- **NO subirle el plazo de caducidad al enlace en Supabase.** Es el arreglo que D-247 descartó.

---

## 6. Por dónde seguir, en orden de valor

| Orden | Qué | Por qué |
|---|---|---|
| **1º** | **Escribirle a Miguel Elías** (**AT**) | Gratis, y puede cambiar el orden de todo lo demás. Es la única persona ajena al proyecto que ha cruzado la puerta |
| **2º** | **AH + AM** — la puerta | Todo lo demás da igual si la gente no entra |
| **3º** | **AW + AO** — los duplicados | La otra puerta que se va a abrir, y corrompe datos en silencio |
| **4º** | **AJ + AP** — el dinero | |
| **5º** | **Paso 9.48** — el consentimiento de la clienta | Lo pidió el propietario. **Toca Ley 1581: quiere diseño con calma** |
| Suelto | **AV**, **AR**, **I-18** | Media hora cada uno |

**Estado de los hallazgos: 40 en total, 31 abiertos, 9 cerrados.**

---

## 7. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-247), y con él
docs/04_pruebas/RECORRIDO_COMPLETO_DE_UN_CLIENTE.md.

Antes de tocar documentación: python scripts/verificar_documentos.py

DÓNDE ESTAMOS
Terminado el recorrido con personas reales (pasos 1-16, 19 y 20). Salieron
DOCE hallazgos nuevos, AM a AX, y ninguno lo habría encontrado una prueba.
Hoy toca EMPEZAR A CORREGIR. No se ha tocado código todavía.

CÓMO SE TRABAJA CON ÉL
Va paso a paso y confirma cada uno antes del siguiente. No es técnico: hay
que decirle QUÉ hace, CÓMO y POR DÓNDE, con los nombres exactos de los
botones. Los comandos se le dan en bloques bash de una sola línea, y los
ejecuta él. Encuentra fallos reales mirando pantallas: cuando dice "esto no
es", casi siempre tiene razón — verificarlo antes de defender el código.

ORDEN ACORDADO
  1. Escribirle a Miguel Elias (AT) - gratis y puede cambiarlo todo
  2. AH + AM - la puerta: el enlace llega gastado y nadie avisa
  3. AW + AO - los duplicados de clientas
  4. AJ + AP - el dinero: el 40% y la comision que no llega a existir
  5. Paso 9.48 - que la clienta autorice sus fotos y su resena (Ley 1581)

NO PAGAR NADA. NO borrar la Peluqueria Exito Prueba: es el banco de pruebas.
NO subir el plazo del enlace en Supabase: ese arreglo lo descarto D-247.

40 hallazgos: 31 abiertos, 9 cerrados. 247 decisiones. Guardian en verde.
```
