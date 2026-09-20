# HANDOFF Salón y Más — 19 de septiembre de 2026 ("La puerta y la llave", D-248 y D-249)

**Bloque documentado:** decisiones **D-248** y **D-249** · Fase **9**, pasos **9.50**, **9.51** y **9.52** (los tres cerrados) · hallazgos **AY**, **AZ** y **BA** nuevos y cerrados.

**Estado:** ✅ Todo aplicado, publicado y **verificado en producción por el propietario**.
`flutter analyze` **0/0** · **429 pruebas** · Controles **216** y **217** en verde · Guardián en verde.

> El bloque anterior está en `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-18_D247.md`.

---

## 1. Lo que hay que leer si solo se lee una cosa

Ayer el recorrido dejó **doce hallazgos y ninguno arreglado**. Hoy se arreglaron **siete**, y el marcador bajó por primera vez:

| | Ayer por la mañana | Ahora |
|---|---|---|
| Hallazgos abiertos | 31 | **26** |
| Cerrados | 9 | **17** |

Y hay un patrón que salió **tres veces en dos días**, siempre igual:

> **Un valor que vive en otra parte no se escribe a mano donde se usa.**
>
> - `'profesional'` dentro de `register_tenant` → **dieciséis días sin poder registrar a nadie** (D-245)
> - el `6` del código de confirmación → el correo traía **ocho** (**AY**)
> - el largo del celular → habría sido el tercero

Las tres veces el número vivía en un sitio que no era el código. **Las tres las cazó el propietario probando, no una prueba.**

---

## 2. Las dos decisiones

### D-248 — La puerta: el correo lleva un código, no un enlace

El enlace de confirmación **llegaba gastado**: es de un solo uso y el escáner del buzón lo visita antes que la persona. Ahora el correo trae un código y la pantalla lo pide.

**Y se descartó el arreglo que estaba escrito:** subir el plazo de caducidad en Supabase no habría cambiado nada, porque el enlace no se agota por tiempo sino por uso.

Cierra **AH**, **AM**, **AY**, **AZ**, **BA** y media **AL**.

### D-249 — La llave: un teléfono, una persona

Decisión del propietario, y su argumento es el que manda:

> *"Un numero de telefono no se puede compartir (ni con la hermana ni con la mama ni con nadie)... cuando un usuario del numero autorice datos del otro, ahi que?"*

**No es higiene de datos, es consentimiento.** El celular ya abre el portal donde la clienta ve sus citas y sus fotos (D-167): compartir la llave es compartir el permiso.

Cierra el paso **9.52**, el hallazgo **AO** entero y **dos de los seis diálogos de AK**.

---

## 3. Dónde vive cada regla, y por qué importa

| Regla | Dónde está escrita | Cuántas veces |
|---|---|---|
| El largo del código de confirmación | En ningún sitio — **lo decide Supabase** | 0 |
| El largo del celular | `private.beautyos_celular_valido` (base) y `CelularColombiano` (app) | **2, y las dos comentadas** |
| Un celular, una clienta | `clients_tenant_phone_uidx` | 1 |

**Si alguien reparte cualquiera de esos números por el código, está reabriendo D-245.**

---

## 4. Lo que quedó verificado en producción

- Registro de cero con `elboga014`: código recibido, uno caducado **rechazado sin perder lo escrito**, reenvío, y entrada.
- **Confirmación desde el teléfono de algo empezado en el computador** — imposible con el enlace de PKCE.
- Crear una clienta con un celular repetido: **se niega y dice de quién es**.
- Reserva pública con letras o con trece dígitos: **se niega antes de enviar**.
- **Control 216** (6/6) y **Control 217** (8/8) contra la base real.

---

## 5. Lo que NO hay que hacer

- 🔴 **NO pagar la suscripción.** La sede dice **$150.000** y `EPAYCO_TEST_MODE` es `false`. Primero **AG**.
- **NO borrar la Peluquería Éxito Prueba.** Es el banco de pruebas.
- **NO subir el plazo del enlace en Supabase.** Ese arreglo lo descartó D-247.
- **NO escribir el largo del celular ni el del código en ningún sitio nuevo.** Hay dos sitios y están comentados.
- **NO tocar AE, I-17, Ñ ni el fondo de AC**: son material del **9.25** y rehacerlos ahora es trabajo tirado.

---

## 6. Por dónde seguir

**La puerta y los duplicados están cerrados, así que ya se puede invitar a los diez socios** en lo que a la entrada se refiere. Lo que queda del bloqueo es dinero.

| Orden | Qué | Por qué |
|---|---|---|
| **1º** | **AP** — el dueño no puede finalizar un servicio | Sin eso el ticket no cierra y **no nace la comisión aunque la clienta pague**. Rompe la operación diaria de cualquier salón que no le dé cuenta a cada estilista. **El servidor ya lo autoriza: falta el botón** |
| **2º** | **AJ** — el 40% que nadie confirma | Probado con dinero real: $7.200 sobre $18.000 |
| **3º** | **AG** — dos precios para lo mismo | Es lo que impide cobrar la primera suscripción |
| **4º** | **Paso 9.48** — que la clienta autorice sus fotos y su reseña | Lo pidió el propietario. **Toca Ley 1581: quiere diseño con calma** |
| Sueltos | **AV**, **AR**, **I-18**, los **cuatro AK** que quedan | Media hora cada uno. El patrón de AK ya está escrito en `clients_page.dart` |

**Y lo que no es código:** el **9.24** — entrevistar salones reales con
`docs/03_referencias/GUION_ENTREVISTA_SALONES_9.24.txt` — sigue bloqueando el **9.25**, la reestructuración a cinco módulos. Lleva parado desde el 07-sep.

**Estado de los hallazgos: 43 en total, 26 abiertos, 17 cerrados.**

---

## 7. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-248 y D-249).

Antes de tocar documentación: python scripts/verificar_documentos.py

DÓNDE ESTAMOS
La puerta de entrada y los duplicados de clientas quedaron cerrados y
verificados en produccion. Lo que bloquea ahora es dinero: AP, AJ y AG.

CÓMO SE TRABAJA CON ÉL
Va paso a paso y confirma cada uno antes del siguiente. No es técnico: hay
que decirle QUÉ hace, CÓMO y POR DÓNDE, con los nombres exactos de los
botones. Los comandos se le dan en bloques bash de una sola línea, y los
ejecuta él. Encuentra fallos reales probando: en dos días cazó tres veces
el mismo patrón --un valor escrito a mano que vive en otra parte-- que
ninguna prueba vio.

ORDEN ACORDADO
  1. AP - el dueño no puede finalizar un servicio, y sin eso no hay comision
  2. AJ - el 40% que nadie confirma
  3. AG - dos precios para lo mismo, y por eso no se puede cobrar
  4. Paso 9.48 - que la clienta autorice sus fotos y su resena (Ley 1581)
  Sueltos: AV, AR, I-18 y los cuatro dialogos de AK que quedan

NO PAGAR NADA. NO borrar la Peluqueria Exito Prueba: es el banco de pruebas.
NO escribir a mano el largo del celular ni el del codigo: hay dos sitios
para el primero y ninguno para el segundo, y estan comentados.

43 hallazgos: 26 abiertos, 17 cerrados. 249 decisiones. analyze 0/0 y
429 pruebas. Controles 216 y 217 en verde. Guardian en verde.
```
