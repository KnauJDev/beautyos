# HANDOFF Salón y Más — 29 de septiembre de 2026 ("La llave es de ella: 9.48 cerrado", D-281 a D-288)

**Bloque documentado:** decisiones **D-281** a **D-288**. Cierra el **paso 9.48**
entero —que sea la clienta, y solo ella, quien autorice publicar su foto y su
reseña— y, de paso, dos fallos graves que la prueba destapó (**BW**, **BX**).

**Estado:** ✅ Todo aplicado, publicado en `main` y **verificado en pantalla**.
**Nada escrito queda sin aplicar ni sin desplegar.** `flutter analyze` **0/0** ·
**532 pruebas** · Guardián en verde.
**Hallazgos: 66 en total, 49 cerrados o decididos, 17 abiertos** (los cuenta el
guardián: `python scripts/verificar_documentos.py`).

> El HANDOFF anterior está en
> `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-26_D280.md`.

---

## 1. Lo que hay que saber si solo se lee una cosa

**El 9.48 está cerrado.** El permiso de publicar una foto ya no lo puede dar
nadie más que la clienta. Lo pide el salón por WhatsApp con su enlace, y ella
decide desde su celular, sin PIN.

| Pieza | Qué es | Decisión |
|---|---|---|
| Bloque 1 | Servidor: el enlace permanente de cada clienta, sus decisiones, la foto privada que puede ver antes de decidir | D-281 |
| Bloque 2 | Portal: autoriza, **se arrepiente** (retirar una foto publicada la saca de internet), elige cómo sale su nombre en la reseña | D-282 |
| BU | La reseña sin nombre sale como **"Reseña verificada"** (antes "Clienta verificada", femenino para todos) | D-283 |
| **BW** | 🔴 Desde el 24-sep ningún salón podía ver sus fotos privadas (BC metió en la política del almacén una función que `authenticated` no puede ejecutar) | D-284 |
| **BX** | 🔴 **Publicar en el portafolio no había funcionado nunca desde el 09-ago**: mover un archivo exige un permiso de Storage que nadie tenía. Ahora lo mueve una función de servidor | D-285 |
| AU | "Mis fotos" del portal muestra toda foto visible para ella, con la marca *"En la página del salón"* / *"Solo para ti"* | D-286 |
| Bloque 3 | La página del enlace directo `?autorizar=`, con el nombre y los colores del salón | D-287 |
| Bloque 4 / **AQ** | **Sin casilla al subir la foto**; el servidor ignora ese permiso; botón *"Pedir autorización por WhatsApp"* en la subida (Tickets), la galería y la ficha de la clienta. Dueño, administrador **y asistente**; nunca el estilista | D-288 |

---

## 2. Lo que se aprendió (y quedó escrito para no repetirlo)

1. **Leer el texto vivo antes de reescribir una función de la base (regla 10)
   no es burocracia.** La primera migración del 9.48 falló por reescribir
   `get_public_salon_reviews` desde el repositorio y quitarle `business_reply`.
   Desde entonces, cada migración se generó desde `intervenciones/extraer_*.sql`
   y se comparó con `diff`.
2. **Probar en pantalla destapa lo que los controles no ven.** BW y BX existían
   desde hacía semanas; salieron al usar la función de verdad. Y dos controles
   viejos llevaban rotos desde septiembre sin que nadie los corriera: **187**
   (desde D-183, 01-sep) y **188** (desde D-281, 26-sep). Ya están en verde.
3. **Al verificar algo recién publicado, abrir una ventana nueva** o pulsar
   *Actualizar* en el aviso de versión nueva. Dos veces una pestaña vieja mostró
   el comportamiento anterior (AU y la casilla del Bloque 4). El ↻ de una
   pantalla recarga los datos, no la app.
4. **Al comprobar la publicación con `Contains(...)`, buscar un texto sin
   tildes.** *"Ver la página de"* dio `False` estando publicado.
5. **`pg_get_functiondef` revienta con un agregado.** Una lectura que recorra
   funciones tiene que filtrar `prokind = 'f'` dentro de un `CASE`.

---

## 3. Lo que tienes que mirar en pantalla (regla 21)

✅ **Las dos comprobaciones del 29-sep, hechas el 30-sep:** D-291 (el tipo de negocio
se lee traducido en Configuración, el Panel y la página pública) y D-293 (la URL del
webhook llega idéntica a ePayco).

🔴 **Y salió un hallazgo nuevo, BY:** activar una sede nueva cerca de la fecha de corte
cobra menos de $5.000 y ePayco lo rechaza. **Espera la decisión del propietario**
sobre qué se cobra en ese caso (ver la fila BY del Plan Maestro).

Y una cosa por probar cuando haya ocasión, sin urgencia:

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

---

## 5. Lo que quedó a medias

1. **Nada del 9.48.** Está cerrado.
2. **AK** — seis diálogos de `tickets_page.dart` que se cierran antes de guardar;
   van con el **9.13**.
3. **BR y BS** — en el buzón de ideas, sin fase.
4. **Señalado, no tocado:** `private.beautyos_resolve_consent_client` tiene
   `EXECUTE` para `PUBLIC`. No abre nada, porque `anon` y `authenticated` no
   tienen uso del esquema `private`, pero no es el patrón del resto. Anotado en
   D-286.

---

## 6. Lo que NO hay que hacer

- **NO borrar la Peluquería Éxito Prueba.** Es el banco de pruebas, y ahora
  tiene datos del 9.48 que sirven: Juan Carlos (foto retirada, enlace
  generado), Gabriel (foto publicada), David Alonso (foto sin responder).
- 🔴 **NO pagar nada** sin decisión explícita del propietario.
- **NO pactar una sede por debajo de $10.000** (D-265).
- **NO reescribir una función de la base sin su lectura viva** (regla 10).
- **NO volver a poner una casilla de "la clienta autorizó"** en ninguna pantalla
  del salón. El permiso es de ella (D-260, D-288).
- **NO pegar en el chat el enlace `?autorizar=` de una clienta real**: abre sin
  PIN.
- **NO contar hallazgos a mano**: `python scripts/verificar_documentos.py`.

---

## 7. Por dónde seguir

Lo que el propietario ya dejó decidido: **en cuanto cerrara el 9.48, el turno C**
(PLAN_MAESTRO §5, *"Lo que ve el cliente, barato"*), empezando por:

1. ✅ **I-18 + I-20** — la agenda abre en *Cada 1 hora* y en la hora actual, con
   los encabezados de columna fijos al bajar (**D-289**).
2. ✅ **BT** — *"1 ticket pendiente"* en singular (**D-290**).
3. ✅ **BV** — la página pública traduce el tipo de negocio; una sola lista (**D-290**).
   Ampliado a la ficha del Panel y a Configuración (**D-291**): enseñan el texto y,
   si no se toca el campo, se guarda el código original.
4. ✅ **AN** — el nombre del catálogo manda (**D-292**). ✅ **9.30** — la URL del
   webhook sale de `SUPABASE_URL` (**D-293**).
5. ✅ **9.17** — HSTS activado en Cloudflare, 6 meses, sin subdominios ni preload
   (**D-294**), comprobado desde fuera.
6. **El turno C queda cerrado en lo que se puede cerrar hoy:** **AA** pasó a la
   Fase 8 (decidido el 29-sep: no está roto) y **los seis AK** de `tickets_page.dart`
   van con el 9.13. AV, BD, AR, AX y BH ya estaban cerrados. **Lo siguiente es
   preguntarle al propietario por el turno D** (regla 8: no asumir el paso).
7. **Turno D, en curso (29-sep).** El propietario eligió **9.26 (Meta)** y **9.33
   (protocolo)**. **9.33:** borrador escrito en
   `02_operacion/PROTOCOLO_DE_BIENVENIDA_SOCIOS_DE_DISENO.md`, pendiente de que lo
   valide (§9 del documento). **9.26:** investigado en la ayuda oficial de Meta; **no
   puede arrancar hasta saber si Salón y Más está registrado como negocio** (Meta lo
   exige). Detalle en la fila 9.26 del Plan Maestro. **9.24** (entrevistas) sigue
   siendo suyo y bloquea el turno E.
8. **30-sep.** **9.33 vigente (D-295)**, con dos preguntas abiertas: dónde va la
   bitácora y qué se dice de factura electrónica. **9.26:** Salón y Más tiene RUT
   pero no matrícula mercantil; eso y la factura electrónica de los salones son
   ahora preguntas para el contador (9.16). La factura electrónica quedó como
   **I-21** en el buzón de ideas.

**Equipo antes que Portafolio** en la página pública está anotado en **I-19**
(rediseño de layout), no en el turno C: no se toca antes.

---

## 8. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-281 a D-288).

Antes de nada: la REGLA 25 del PLAN_MAESTRO §8. Afirmar exige prueba; lo
aprobado no se cambia sin avisar; el producto se pregunta aunque haya
permiso general; lo que corre el propietario se copia de algo que ya
funcionó; un letrero rancio se busca por lo que llama.

Y: python scripts/verificar_documentos.py (cuenta los hallazgos por ti).

DÓNDE ESTAMOS
El paso 9.48 está cerrado y verificado en pantalla: el permiso de publicar
una foto solo lo da la clienta, desde su enlace (?autorizar=) o su portal;
el salón se lo pide por WhatsApp (dueño, admin o asistente). En el camino se
arreglaron BW (fotos privadas invisibles desde el 24-sep) y BX (publicar en
el portafolio nunca había funcionado).

LO PRIMERO
El propietario ya decidió el siguiente paso: el turno C, empezando por
I-18 + I-20 (cómo abre la agenda) y los baratos BT y BV. Confírmaselo en una
línea y arranca.

CÓMO SE TRABAJA CON ÉL
Paso a paso, en español claro y con los nombres exactos de los botones. Los
comandos van en bloques de una sola línea y los ejecuta él (PowerShell).
ANTES DE REESCRIBIR UNA FUNCIÓN DE LA BASE: una lectura en
intervenciones/extraer_*.sql, y la migración GENERADA desde ese texto vivo,
comparada con diff.
ANTES DE PEDIRLE QUE PRUEBE ALGO EN PANTALLA: que haya hecho git push a main,
que la comprobación (con un texto SIN tildes) diga True, y que abra una
ventana nueva.
```
