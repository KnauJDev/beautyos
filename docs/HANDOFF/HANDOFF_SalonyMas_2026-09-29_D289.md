# HANDOFF Salón y Más — 29 de septiembre de 2026 ("9.48 cerrado y turno C empezado", D-281 a D-289)

**Bloque documentado:** decisiones **D-281** a **D-289**.
- **D-281 a D-288** cierran el **paso 9.48**: solo la clienta autoriza publicar su foto y su reseña.
- **D-289** es el primer paso del **turno C**: I-18 + I-20, cómo abre la agenda.

**Estado:** ✅ Todo aplicado y publicado en `main` (`0ab7841`).
- **9.48 verificado en pantalla.**
- **D-289 publicado, falta verlo en pantalla.**
- Nada escrito queda sin aplicar ni sin desplegar.
- `flutter analyze` **0/0** · **540 pruebas** · Guardián en verde.

**Hallazgos: 66 en total, 49 cerrados o decididos, 17 abiertos** (`python scripts/verificar_documentos.py`).

> El HANDOFF anterior está en
> `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-29_D288.md`, que a su vez
> reemplazó al del 26-sep (`..._2026-09-26_D280.md`).

---

## 1. Lo que hay que saber si solo se lee una cosa

**El 9.48 está cerrado.** El permiso de publicar una foto solo lo da la clienta, desde su enlace o su portal. El salón se lo pide por WhatsApp.

**El turno C empezó por la agenda (D-289).** Falta que el propietario la mire en pantalla.

| Pieza | Qué es | Decisión |
|---|---|---|
| Bloque 1 | Servidor. El enlace permanente de cada clienta, sus decisiones, la foto privada que puede ver antes de decidir | D-281 |
| Bloque 2 | Portal. Autoriza y **se arrepiente**: retirar una foto publicada la saca de internet. Elige cómo sale su nombre | D-282 |
| BU | Una reseña sin nombre sale como **"Reseña verificada"** | D-283 |
| **BW** 🔴 | Desde el 24-sep ningún salón veía sus fotos privadas | D-284 |
| **BX** 🔴 | Publicar en el portafolio **nunca había funcionado desde el 09-ago**. Ahora mueve la foto una función de servidor | D-285 |
| AU | "Mis fotos" del portal muestra toda foto visible para ella, con la marca *"En la página del salón"* o *"Solo para ti"* | D-286 |
| Bloque 3 | Página del enlace directo `?autorizar=`, con el nombre y los colores del salón | D-287 |
| Bloque 4 / **AQ** | **Sin casilla** al subir la foto, y el servidor ignora ese permiso. Botón *"Pedir autorización por WhatsApp"* para dueño, admin y **asistente**; nunca el estilista | D-288 |
| **I-18 + I-20** | La agenda abre **siempre en "Cada 1 hora"**. El tablero Día se desplaza por dentro con los encabezados fijos. Al abrir HOY, la fila de la hora actual queda la primera | D-289 |

---

## 2. Lo que se aprendió (ya escrito en `MAPA_TECNICO` §2 y §7)

1. **Comprobar una publicación preguntando por el commit**, no buscando textos:
   `(Invoke-RestMethod "https://salonymas.com/build-info.json?v=$(Get-Random)").commit`.
   Es lo mismo que muestra **Configuración → Versión**.
   - Buscar un texto con tildes da `False` aunque el texto esté publicado.
   - Buscar un nombre interno del código da `False`: la compilación lo renombra.
   - Las dos cosas pasaron esta semana.
2. **Al verificar, ventana nueva o *Actualizar*.** El ↻ de una pantalla recarga datos, no la app. Dos veces se probó con la versión vieja sin saberlo.
3. **Regla 10, leer el texto vivo antes de reescribir.** La primera migración del 9.48 falló por reescribir sin leer.
4. **Controles viejos que nadie corría estaban rotos:** el 187 (desde el 01-sep) y el 188 (desde el 26-sep). Ya están en verde.
5. **Dos trampas que ya estaban anotadas volvieron a morder.**
   - Tildes (D-249).
   - `pg_get_functiondef` con un agregado (D-252).

   Leer `MAPA_TECNICO` §7 **antes** de escribir una lectura o una comprobación.
6. **Las pruebas del tablero dependían de la hora** a la que se corrían. Ahora usan un reloj fijo (`AgendaPage.reloj`).

---

## 3. Lo que tienes que mirar en pantalla (regla 21)

**D-289, la agenda.** En ventana nueva o tras *Actualizar*:
1. Abre en *Cada 1 hora*, con la fila de la hora actual arriba.
2. Al bajar dentro del tablero, los títulos de las columnas no se mueven.
3. Con la flecha al día siguiente, abre desde las 08:00.
4. Si el alto del tablero queda corto o largo, decirlo. Hoy es el 62 % del alto de la ventana, entre 320 y 900 px.

**Sin urgencia:** el botón de WhatsApp con un celular guardado **sin el 57**. Puede que WhatsApp no encuentre el número. Es la misma limitación que ya tienen los recordatorios.

---

## 4. Las decisiones que siguen siendo tuyas

| | Qué | Por qué importa |
|---|---|---|
| **c** | **Cuándo pasar a Supabase Pro** | D-088 decía *cuando cargue datos*, D-226 *cuando pague* |
| **d** | **I-13**: acceso de lectura a la base para el asistente | Hoy cada lectura es un comando tuyo con contraseña |
| **h** | **¿Quitamos los tipos de foto *Final* y *Portafolio*?** | Es lo único que mantiene abierto el hallazgo **Ñ** |
| **i** | **BS**: revisar juntos el SMTP de Auth en el panel de Supabase | Saber si Resend está puesto ahí antes de decidir |

---

## 5. Lo que quedó a medias

1. **D-289:** solo falta mirarlo en pantalla (§3).
2. **Turno C, lo que sigue**, en este orden:
   - **BT**: *"1 tickets pendientes"* debe decir "1 ticket pendiente".
   - **BV**: la página pública dice *"salon"* en vez del tipo de negocio. `complete_tenant_setup_page.dart` ya tiene la traducción.
   - El resto de la tabla del Plan Maestro §5: AV, BD, AR, AX, AN, los AK, 9.17, 9.30, AA, BH.
3. **AK**: los seis diálogos de `tickets_page.dart` van con el 9.13.
4. **BR y BS**: en el buzón de ideas, sin fase.
5. **Señalado, no tocado:** `private.beautyos_resolve_consent_client` tiene `EXECUTE` para `PUBLIC` (D-286). No abre nada, pero no sigue el patrón del resto.

---

## 6. Lo que NO hay que hacer

- **NO borrar la Peluquería Éxito Prueba.** Tiene datos útiles del 9.48:
  - Juan Carlos: foto retirada, enlace generado.
  - Gabriel: foto publicada.
  - David Alonso: foto sin responder.
- 🔴 **NO pagar nada** sin decisión explícita del propietario.
- **NO pactar una sede por debajo de $10.000** (D-265).
- **NO reescribir una función de la base sin su lectura viva** (regla 10).
- **NO volver a poner una casilla de "la clienta autorizó"** en pantallas del salón (D-260, D-288).
- **NO pegar en el chat el enlace `?autorizar=` de una clienta real**: abre sin PIN.
- **NO comprobar una publicación buscando nombres internos del código.** Usar `build-info.json`.
- **NO contar hallazgos a mano.**

---

## 7. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-281 a D-289).

Antes de nada: la REGLA 25 del PLAN_MAESTRO §8. Afirmar exige prueba; lo
aprobado no se cambia sin avisar; el producto se pregunta aunque haya
permiso general; lo que corre el propietario se copia de algo que ya
funcionó; un letrero rancio se busca por lo que llama.

Y: python scripts/verificar_documentos.py (cuenta los hallazgos por ti).
Y: MAPA_TECNICO §7 (las trampas que ya mordieron) ANTES de escribir una
lectura SQL o una comprobación de publicación.

DÓNDE ESTAMOS
El 9.48 está cerrado y verificado: la foto solo la autoriza la clienta.
El turno C empezó con D-289 (la agenda abre en "Cada 1 hora" y en la hora
actual, con encabezados fijos): publicado en 0ab7841, FALTA que el
propietario lo mire en pantalla.

LO PRIMERO
Preguntarle si ya miró la agenda (HANDOFF §3). Luego seguir el turno C:
BT y BV, que son baratos.

CÓMO SE TRABAJA CON ÉL
Paso a paso, en español claro y con los nombres exactos de los botones.
Los comandos van en bloques de una sola línea (PowerShell) y los ejecuta él.
Las decisiones de producto se le preguntan, con una opción recomendada.
ANTES DE REESCRIBIR UNA FUNCIÓN DE LA BASE: lectura en
intervenciones/extraer_*.sql y migración GENERADA desde ese texto, con diff.
PARA COMPROBAR UNA PUBLICACIÓN:
(Invoke-RestMethod "https://salonymas.com/build-info.json?v=$(Get-Random)").commit
y luego ventana nueva para mirar.
```
