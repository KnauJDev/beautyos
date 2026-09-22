# HANDOFF Salón y Más — 22 de septiembre de 2026 ("El precio es de la sede", D-252)

**Bloque documentado:** decisión **D-252** · Fase **9**, pasos **9.55** y **9.56** (los dos cerrados) · hallazgo **AG** cerrado · hallazgo **BB** nuevo.

**Estado:** ✅ Aplicado y publicado. Controles en verde contra la base real.
`flutter analyze` **0/0** · **453 pruebas** · Controles **220** (7/7) y **221** (9/9) · Guardián en verde.

> ⚠️ **Falta una confirmación en pantalla.** Ver §7.
> El bloque anterior está en `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-20_D251.md`.

---

## 1. Lo que hay que leer si solo se lee una cosa

**AG decía "hay dos precios que confunden". Eran dos botones de pago, y el de
arriba cobraba por un camino que no activa nada.**

En la Configuración del salón convivían *Pagar y Activar Plan con ePayco*
(cobraba el negocio) y, justo debajo, *Activar esta sede*. El de arriba **no
cubría ningún caso** que el de abajo no cubriera — la lista de sedes incluye la
principal — y lo único que hacía era ofrecer pagar por un camino que **no
activa ninguna sede**. Se pagaba y no pasaba nada.

Por eso *NO PAGAR NADA* era la regla correcta, y hay una cifra que lo prueba:

> **2 cobros en toda la historia, los dos por ese camino, los dos de negocios
> de prueba del propietario. Cero clientes reales afectados.**

Esa cifra es lo que hizo este trabajo barato hoy y caro mañana.

---

## 2. La decisión

### D-252 — El precio es de la sede, que es quien cobra

De los dos caminos que AG ofrecía —rotular o retirar—, el propietario eligió un
tercero: *"retirar el precio acordado por negocio y dejarlo por sede, al final
es así como se haría en la realidad"*. Un salón no negocia un precio del
negocio: negocia cada local.

**No se retiró la función de cobro: se cerró la puerta.** El webhook usa ese
mismo cálculo para **liquidar** un pago, así que borrarlo habría hecho que un
pago confirmado por ePayco dejara de registrarse — la clienta paga y el sistema
no se entera. Se bloquea solo el punto por donde se **inicia** un cobro.

---

## 3. El 50% tenía seis escondites

D-221 declaró el 07-sep que **el pionero es una etiqueta, no un 50%**, lo quitó
de `platform_update_tenant_pricing` y nació el **control 207** para vigilarlo.

El mismo número seguía vivo en:

| # | Dónde | Gravedad |
|---|---|---|
| 1 | El `× 0.5` de `platform_tenant_summary.dart` | El panel podía enseñar $75.000 y la factura decir $150.000 |
| 2 | Un cartel que le prometía al salón *"50% de descuento de por vida"* | **De cara al cliente** |
| 3 | **Dos pruebas que lo afirmaban** | Por eso nadie lo vio: la prueba era cómplice |
| 4 | **`platform_approve_tenant`** | **La función que aprueba clientes nuevos** |
| 5 y 6 | Los dos diálogos del panel | El interruptor ya decía *"NO aplica ningún descuento (D-221)"* |

**Y explica un dato que llevaba días sin explicación:** *Prueba Barberia Elite*
tenía el motivo `'Pionero (50% de por vida)'` con `is_founder` en false. **No lo
escribió nadie a mano: lo escribió la aprobación.**

---

## 4. Las dos reglas que costaron el día

> ### Un control que vigila **una función** no vigila **una regla**.
>
> El 207 hacía bien su trabajo, y este mismo 50% le pasó por al lado quince
> días — por la puerta que nadie le dijo que mirara. El **control 221** vigila
> **las dos**.

> ### Una prueba puede defender un fallo.
>
> Las dos que afirmaban el 50% sobrevivieron a D-188 y a D-221 sujetando en la
> aplicación justo lo que se había quitado del servidor. Verde, y cómplice.

---

## 5. Dónde se toca cada cosa ahora

| Quiero… | Dónde |
|---|---|
| Cambiar el **plan** o marcar pionero | Ficha del negocio → **Cambiar plan o etiqueta** |
| **Cambiar lo que paga una sede** | Ficha del negocio → las sedes → botón **Pago** de esa sede |
| Precios **distintos** en dos sedes del mismo negocio | Lo mismo, una por una. **Antes no se podía** |

**Hoy solo hay un plan** (*Todo Incluido*, D-188 jubiló los otros tres), así que
lo que de verdad se negocia es el precio de cada sede.

---

## 6. Lo que NO hay que hacer

- 🔴 **NO pagar la suscripción** sin decidirlo a conciencia. `EPAYCO_TEST_MODE` sigue en `false`. Lo que cambió es que ya **no se puede pagar por el camino equivocado**.
- **NO borrar la Peluquería Éxito Prueba.** Es el banco de pruebas, y ya tiene su sede a **\$4.500**.
- **NO retirar `beautyos_calcular_cargo_epayco` ni `beautyos_procesar_evento_epayco`.** Están cerradas o en desuso, pero **el webhook liquida con ellas**.
- **NO volver a escribir el 50% de pionero en ningún sitio.** Tenía seis; el control 221 vigila las dos puertas que quedan.
- **NO dar AI por cerrado.** `supabase db reset` sigue roto.
- **NO empezar I-19** (rehacer el layout) antes del 9.25: la cadena es **9.24 → 9.25 → I-19**.

---

## 7. ⚠️ Lo que quedó a medias

**Cuatro letreros corregidos y sin confirmar en pantalla.** Al cerrar la parte 2
quedaron cuatro textos prometiendo un precio que la ventana ya no fija
—*"Plan y Tarifa Mensual Fijada del Negocio"*, *"Modificar Precio o Plan"*,
*"o fija una tarifa especial en COP"*—. **Es la misma forma exacta del
interruptor de pionero**, y esta vez la dejó el asistente, el mismo día. Lo cazó
el propietario probando.

Están corregidos, publicados y verificados en el JavaScript servido, pero
**nadie los ha visto todavía en pantalla**. Es lo primero de la próxima sesión:
`Ctrl+F5` y mirar la ficha de un negocio en el panel.

---

## 8. Por dónde seguir

**Ya no queda nada bloqueando el cobro de la primera suscripción.**

| Orden | Qué | Por qué |
|---|---|---|
| **0º** | Confirmar los cuatro letreros (§7) | Dos minutos |
| **1º** | **Paso 9.48** — que la clienta autorice sus fotos y su reseña | Lo pidió el propietario. **Toca Ley 1581: quiere diseño con calma** |
| Sueltos | **AV**, **AR**, **I-18**, los **cuatro AK** que quedan | Media hora cada uno |

**Y lo que no es código:** el **9.24** — entrevistar salones reales con
`docs/03_referencias/GUION_ENTREVISTA_SALONES_9.24.txt` — sigue bloqueando el
**9.25**, y detrás de él **I-19**. Parado desde el 07-sep.

**Estado de los hallazgos: 43 en total, 24 abiertos, 19 cerrados.**

---

## 9. Una contradicción que sigue abierta

- **`RESPALDO_Y_RESTAURACION_SUPABASE.md` nombra dos scripts de respaldo
  distintos** — `respaldo_supabase.ps1` arriba y `crear_respaldo_supabase.ps1`
  más abajo — y **los dos existen**, con nombres de carpeta diferentes. El que
  ha hecho todos los respaldos es el primero. *(Viene de dos HANDOFF atrás.)*

---

## 10. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-252).

Antes de tocar documentación: python scripts/verificar_documentos.py

DÓNDE ESTAMOS
AG cerrado: el precio es de la sede y ya no hay forma de pagar por un camino
que no activa nada. Ya no queda nada bloqueando el cobro de la primera
suscripcion. Falta que el propietario confirme en pantalla cuatro letreros
corregidos (apartado 7 del HANDOFF): es lo primero.

CÓMO SE TRABAJA CON ÉL
Va paso a paso y confirma cada uno antes del siguiente. No es técnico: hay
que decirle QUÉ hace, CÓMO y POR DÓNDE, con los nombres exactos de los
botones. Los comandos se le dan en bloques bash de una sola línea, y los
ejecuta él. Encuentra fallos reales probando: en este bloque cazo cuatro
letreros que el asistente dejo mintiendo el mismo dia.

ANTES DE REESCRIBIR CUALQUIER FUNCION DE LA BASE
Extraer su texto vivo y compararlo linea por linea (D-119, D-122, D-123).
Hay varios guiones de ejemplo en supabase/sql/intervenciones/. El
repositorio NO es la fuente del esquema (hallazgo AI): en este bloque
aparecieron TRES versiones vivas de una funcion de cobro que ninguna
migracion menciona.

ORDEN ACORDADO
  0. Confirmar en pantalla los cuatro letreros del apartado 7
  1. Paso 9.48 - que la clienta autorice sus fotos y su resena (Ley 1581)
  Sueltos: AV, AR, I-18 y los cuatro dialogos de AK que quedan

NO borrar la Peluqueria Exito Prueba: es el banco de pruebas, y su sede ya
esta en $4.500.
NO retirar beautyos_calcular_cargo_epayco ni beautyos_procesar_evento_epayco:
estan cerradas o en desuso, pero el webhook liquida con ellas.
NO volver a escribir el 50% de pionero en ningun sitio: tenia seis
escondites y el control 221 vigila las dos puertas que quedan.
NO dar AI por cerrado: supabase db reset sigue roto.
NO empezar I-19 antes del 9.25: la cadena es 9.24 -> 9.25 -> I-19.

43 hallazgos: 24 abiertos, 19 cerrados. 252 decisiones. analyze 0/0 y
453 pruebas. Controles 220 (7/7) y 221 (9/9) en verde. Guardian en verde.
```
