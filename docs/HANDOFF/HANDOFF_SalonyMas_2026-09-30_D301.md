# HANDOFF Salón y Más — 30 de septiembre de 2026 ("El cobro, probado en pantalla", D-289 a D-301)

**Bloque documentado:** decisiones **D-289** a **D-301**. Cierra el **turno C** en lo
que se puede cerrar, arranca el **turno D** (9.33 vigente, 9.26 investigado),
resuelve tres fallos del cobro que aparecieron al probarlo en pantalla (**BY**,
**BZ** y **CA**) y cierra dos pasos que se habían quedado fuera del turno A:
**AD** (D-299) y **9.9** (D-300), que destapó **CB**. Y la ficha del Panel enseña
el precio de la sede y no el acuerdo viejo del negocio (D-301).

**Estado:** ✅ Todo aplicado, publicado en `main` y **verificado en pantalla**.
**Nada escrito queda sin aplicar ni sin desplegar.** `flutter analyze` **0/0** ·
**609 pruebas** · Guardián en verde.
**Hallazgos: 71 en total, 57 cerrados o decididos, 14 abiertos** (los cuenta el
guardián: `python scripts/verificar_documentos.py`).

> El HANDOFF anterior está en
> `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-29_D288.md`.

---

## 1. Lo que hay que saber si solo se lee una cosa

**El cobro de una sede se probó de punta a punta en pantalla y aparecieron tres
fallos que ningún control veía.** Los tres están cerrados y verificados.

| Decisión | Qué | Estado |
|---|---|---|
| D-289 | **I-18 + I-20**: la agenda abre en *Cada 1 hora* y en la hora actual, con los encabezados fijos | ✅ |
| D-290 | **BT**: *"1 ticket pendiente"* en singular. **BV**: la página pública traduce el tipo de negocio, con una sola lista | ✅ |
| D-291 | **BV**, la otra mitad: el Panel y Configuración también enseñan el texto; si no se toca el campo, se conserva el código guardado | ✅ verificado 30-sep |
| D-292 | **AN**: el nombre del estilista lo manda el catálogo | ✅ |
| D-293 | **9.30**: la URL del webhook de ePayco sale de `SUPABASE_URL` | ✅ verificada idéntica 30-sep |
| D-294 | **9.17**: HSTS en Cloudflare, 6 meses, sin subdominios ni preload | ✅ comprobado desde fuera |
| D-295 | **9.33**: el protocolo de bienvenida queda vigente con las palabras del propietario. La factura electrónica pasa al buzón como **I-21** | ✅ con dos preguntas abiertas |
| D-296 | 🔴 **BY**: el alta de una sede cerca del corte cobraba menos de $5.000 y ePayco lo rechazaba. Ahora cobra como mínimo $5.000 | ✅ migración aplicada, control 236 6/6, ePayco abrió con $5.000 |
| D-297 | **BZ**: quien cierra ePayco sin pagar leía *"estamos validando tu pago"*. Ahora lee que no se completó ningún pago y no se cobró nada. **En la base, cancelar no es un rechazo** | ✅ verificado 30-sep |
| D-298 | **CA**: el `?ref_payco=` se quedaba en la dirección y el aviso se repetía en cada recarga. Ahora se lee una vez y se quita | ✅ verificado 30-sep |
| D-299 | **AD**, la otra mitad: el error de un enlace de correo vencido (`?error=…otp_expired`) se quita de la dirección en cuanto se lee | ✅ verificado 30-sep sin sesión, por el asistente |
| D-300 | **9.9** (pruebas del Panel en precios y aprobaciones) y **CB**: los tres campos de dinero del Panel leían mal *"15.000"* —el precio de una sede se borraba, el precio al aprobar se perdía, la comisión fija de un aliado quedaba en $15— | ✅ verificado 30-sep |
| D-301 | La ficha del Panel enseña **"Precio de esta sede"** (pactado o de lista) en vez de *"Acuerdo del negocio: $4.500 — no se cobra"*, que el propietario leyó como vigente. La lista de clientes ya no enseña el precio del negocio | ✅ verificado 30-sep |

---

## 2. Lo que se aprendió (y quedó escrito para no repetirlo)

1. **Probar el cobro en pantalla encontró lo que los controles no ven.** El mínimo
   de ePayco (BY), el estado *Cancelada* (BZ) y la dirección que no se limpia (CA)
   salieron uno detrás de otro, en una sola mañana, de pulsar *Activar esta sede*.
2. **Antes de anotar un hallazgo, se busca por lo que describe.** CA resultó ser
   **AD**, anotado el 09-sep con el mismo síntoma. Se vio al listar los abiertos
   (nota en D-298).
3. **Al cerrar un turno, cada elemento de su fila se tacha o se mueve.** D-274 dio
   por cerrado el turno A y dejó fuera **9.40, AD y 9.9**, que siguen pendientes y
   nadie volvió a nombrar hasta el 30-sep.
4. **Para saber si Cloudflare ya publicó, se compara el archivo publicado con la
   compilación local.** Con D-298: `ref_payco` aparecía 2 veces en el `main.dart.js`
   publicado y 3 en el local; cuando el publicado dio 3, la versión nueva estaba
   fuera (unos dos minutos y medio después del `push`).
5. **Con HSTS activo, Cloudflare no se toca a ciegas** (D-294): nada de *DNS only*,
   pausar Cloudflare, cambiar los *nameservers* ni quitar el certificado.

---

## 3. Lo que tienes que mirar en pantalla (regla 21)

✅ Se vio en pantalla: D-291 y D-293 (30-sep por la mañana), BY, BZ y CA, y AD
sin sesión (el asistente, en el navegador integrado).

✅ **Y CB y D-301, vistos por el propietario el 30-sep:** escribió *"10.000"* con punto
en la ventana **Pago** de la sede de Éxito y siguió en $10.000 pactado; la tarjeta
"3. Plan del negocio" dice **"Precio de esta sede"**. **El botón Pago está en la
tarjeta "1. Esta sede"**, arriba del todo de la ficha; *Cambiar plan o etiqueta* no
toca precios, a propósito.

Y una cosa por probar cuando haya ocasión, sin urgencia (viene del bloque anterior):

- **El botón de WhatsApp con un celular guardado sin el 57.** Puede que WhatsApp
  no encuentre el número. Es la misma limitación que ya tienen los recordatorios
  de la agenda; no se cambió. Si pasa, se anota como hallazgo aparte.

---

## 4. Las decisiones que siguen siendo tuyas

| | Qué | Por qué importa |
|---|---|---|
| **c** | **Cuándo pasar a Supabase Pro** | D-088 decía *cuando cargue datos*, D-226 *cuando pague* |
| **d** | **I-13**: acceso de lectura a la base para el asistente | Hoy cada lectura es un comando tuyo con contraseña |
| **h** | **Las fotos: ¿quitamos los tipos *Final* y *Portafolio*?** | Es lo único que mantiene abierto el hallazgo **Ñ** |
| **i** | **BS**: revisar juntos el SMTP de Auth en el panel de Supabase | Antes de decidir si se arregla, hay que saber si Resend está puesto ahí |
| **j** | ~~**Dónde van 9.40, AD y 9.9**, que se quedaron fuera del turno A~~ **30-sep, decidido:** *"a, cierra AD y 9.9 primero"*. AD cerrado (D-299) y 9.9 cerrado (D-300, de ahí salió **CB**); **9.40 sigue pendiente** | 9.40 toca el camino del dinero y necesita una migración |
| **k** | **9.26 (Meta)**: ¿se intenta con el RUT o se espera al contador? | Salón y Más tiene RUT pero no matrícula mercantil, y Meta pide el negocio registrado |
| **l** | **9.33**: dónde guardaste la bitácora, y el visto bueno a la respuesta sobre factura electrónica (§8 del protocolo) | Son las dos preguntas abiertas del protocolo |
| **m** | **9.16** (contador: matrícula y factura electrónica de los salones), **9.20** (abogado) y **9.24** (entrevistas) | El 9.24 sigue bloqueando la estructura (turno E) |
| **n** | **CC**: cuándo arreglar el mismo fallo de CB del lado del salón (Servicios, Gastos, Inventario, Compras, anticipos) | *"35.000"* se guarda como $35. Con `CifraEscrita` ya hecho es una línea por campo |

---

## 5. Lo que quedó a medias

1. **AK**: seis diálogos de `tickets_page.dart` que se cierran antes de guardar.
   Van con el **9.13**.
2. **BR y BS**: en el buzón de ideas, sin fase.
3. **Señalado, no tocado:** `private.beautyos_resolve_consent_client` tiene
   `EXECUTE` para `PUBLIC`. No abre nada, porque `anon` y `authenticated` no
   tienen uso del esquema `private`, pero no es el patrón del resto (D-286).
4. **Señalado, no tocado:** la intención de pago de un intento cancelado queda en
   estado `verificada`. Ahí significa "ya se cruzó con una referencia de ePayco",
   no "pagada"; las cifras de cobro leen `monto_cop_recibido` (D-297).
5. **AI**: la mitad honesta ya estaba escrita (el repositorio dice que no contiene
   el esquema entero); la correcta, volcarlo a una migración, va en el turno E.

---

## 6. Lo que NO hay que hacer

- **NO borrar la Peluquería Éxito Prueba.** Es el banco de pruebas, con datos del
  9.48 que sirven: Juan Carlos (foto retirada, enlace generado), Gabriel (foto
  publicada), David Alonso (foto sin responder).
- 🔴 **NO pagar nada** sin decisión explícita del propietario.
- **NO pactar una sede por debajo de $10.000** (D-265). Y el cobro mínimo de ePayco
  es $5.000 (D-296): son dos mínimos distintos.
- **NO tratar *Cancelada* como rechazo en la base**: un rechazo puede empujar a
  mora (D-297).
- **NO reescribir una función de la base sin su lectura viva** (regla 10).
- **NO volver a poner una casilla de "la clienta autorizó"** en ninguna pantalla
  del salón. El permiso es de ella (D-260, D-288).
- **NO pegar en el chat el enlace `?autorizar=` de una clienta real**: abre sin PIN.
- **NO meter la bitácora de los socios en el repositorio**: lleva datos de
  personas reales (Ley 1581, D-295).
- **Con HSTS activo, NO** poner *DNS only*, pausar Cloudflare, cambiar los
  *nameservers* ni quitar el certificado (D-294).
- **NO contar hallazgos a mano**: `python scripts/verificar_documentos.py`.

---

## 7. Por dónde seguir

El orden aprobado el 23-sep (PLAN_MAESTRO §5, *El orden de ejecución*) está así:

1. ✅ **Turno A**, cerrado el 24-sep, **salvo 9.40, AD y 9.9**, que se quedaron
   fuera (decisión **j**).
2. **Turno B**: ✅ 9.48, BC y AS. Quedan **9.20** y **9.16**, los dos tuyos.
3. ✅ **Turno C**, cerrado el 29-sep en lo que se puede cerrar. AA pasó a la
   Fase 8 y los seis AK van con el 9.13.
4. **Turno D**: ✅ 9.33 vigente; **9.26** espera la decisión **k**; **9.24** es tuyo.
5. **Turno E** (9.25, luego 9.13 y 9.14, luego **I-19**, el layout): bloqueado por
   el **9.24**.

**El 30-sep el propietario pidió evaluar qué se puede cerrar sin él y, si no hay
nada, explorar el layout.** Salieron dos, AD y 9.9, y los cerró primero (D-299,
D-300). **Lo siguiente que pidió es explorar el layout.** **I-19 dice que el rediseño va *después* del 9.25**
(rediseñar quince pantallas que luego se reagrupan en cinco es hacerlo dos veces).
Explorar y bocetar no lo contradice; construir, sí. Preguntarle qué quiere explorar
antes de proponer nada.

---

## 8. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-289 a D-301).

Antes de nada: la REGLA 25 del PLAN_MAESTRO §8. Afirmar exige prueba; lo
aprobado no se cambia sin avisar; el producto se pregunta aunque haya
permiso general; lo que corre el propietario se copia de algo que ya
funcionó; un letrero rancio se busca por lo que llama.

Y: python scripts/verificar_documentos.py (cuenta los hallazgos por ti).

DÓNDE ESTAMOS
El turno C está cerrado y el D, en manos del propietario. El cobro de una
sede se probó de punta a punta en pantalla el 30-sep: salieron y se
cerraron BY (mínimo de $5.000 de ePayco), BZ (cerrar sin pagar ya no dice
"validando") y CA (el ref_payco ya no se queda en la dirección). CA era un
duplicado de AD, y AD ya está cerrado entero (D-299). El 9.9 (pruebas del
Panel) destapó CB: los campos de dinero leían mal "15.000"; cerrado, y
anotado CC, el mismo fallo del lado del salón.

LO PRIMERO
Mira la sección 4 del HANDOFF: casi todo lo pendiente es decisión suya.
Pidió explorar el layout (I-19): pregúntale qué quiere ver. El Plan lo
pone después del 9.25, así que explorar sí, construir no.

CÓMO SE TRABAJA CON ÉL
Paso a paso, en español claro y con los nombres exactos de los botones. Los
comandos van en bloques de una sola línea y los ejecuta él (PowerShell).
ANTES DE REESCRIBIR UNA FUNCIÓN DE LA BASE: una lectura en
intervenciones/extraer_*.sql, y la migración GENERADA desde ese texto vivo,
comparada con diff.
ANTES DE PEDIRLE QUE PRUEBE ALGO EN PANTALLA: que haya hecho git push a main,
que el main.dart.js publicado ya traiga el cambio (compararlo con la
compilación local) y que abra una ventana nueva.
```
