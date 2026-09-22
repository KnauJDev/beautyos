# HANDOFF Salón y Más — 20 de septiembre de 2026 ("El dinero de cada quien", D-250 y D-251)

**Bloque documentado:** decisiones **D-250** y **D-251** · Fase **9**, pasos **9.53** y **9.54** (los dos cerrados) · hallazgos **AP** y **AJ** cerrados · idea **I-19** nueva.

**Estado:** ✅ Todo aplicado, publicado y **verificado en producción por el propietario**.
`flutter analyze` **0/0** · **444 pruebas** · Controles **218** (9/9) y **219** (9/9) · Guardián en verde.

> El bloque anterior está en `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-20_D250.md`.

---

## 1. Lo que hay que leer si solo se lee una cosa

Los dos hallazgos del día eran el mismo problema por dos lados: **el dinero del
estilista dependía de cosas que nadie había decidido a propósito.**

| | Antes | Ahora |
|---|---|---|
| **AP** | La comisión **no nacía** si el estilista no tenía cuenta | El dueño cierra el servicio desde Tickets & Caja |
| **AJ** | La comisión **nacía al 40%** que nadie aprobó | Nace marcada *sin confirmar*, y se nota en tres sitios |

Y las dos veces, **la cosa que faltaba ya estaba escrita en alguna parte**:

- En AP, el remedio del cierre estaba puesto **en una puerta que no se puede abrir** (D-163).
- En AJ, el 40 estaba escrito en `supabase/sql/015`, que **sí está en el repositorio pero no es una migración** — nadie lee esa carpeta.

> **No era código que faltara: era código que nadie podía alcanzar ni leer.**

---

## 2. Las dos decisiones

### D-250 — No faltaba permiso, faltaba el botón

El único sitio que terminaba un servicio era **Mi agenda**, la pantalla privada
del estilista. Un salón que crea estilistas en el catálogo sin invitarlos se
quedaba sin nadie que pudiera pulsarlo. Ventana *Atender servicios*, cero
migraciones para esa parte.

**La segunda mitad la encontró el control, no el hallazgo:** la comisión solo se
calculaba al entrar un pago, así que un anticipo del 100% la mataba para
siempre.

### D-251 — Una cifra que decide un sueldo no nace decidida por un default

Medido antes de escribir: **3 políticas en la base, las 3 en el 40%, 0 tocadas
desde que nacieron.**

Se descartó que naciera en **0%**, y el argumento del propietario es el que
manda: *0% también es un número inventado, solo que más barato para el salón y
exactamente igual de mudo para el estilista.* Lo que había que arreglar era **el
silencio**, no la cifra.

---

## 3. Dónde vive cada regla

| Regla | Dónde está escrita | Cuántas veces |
|---|---|---|
| Del estado del servicio al siguiente | `AccionesDeTicket.siguienteEstadoDelServicio` | **1** (espejo del servidor) |
| Cuándo cierra el ticket y nace la comisión | `beautyos_close_ticket_if_fully_paid` | 1, llamada desde **tres** sitios |
| El **40%** por defecto | El default de `commission_policies`, **ahora en una migración y comentado** | 1 |
| Si alguien aprobó la comisión | `commission_policies.confirmed_at` | 1 |

---

## 4. Lo que quedó verificado en producción

- El dueño inicia y termina un servicio sin que ningún estilista entre.
- **El orden del anticipo:** pago durante la atención, finalizado después **con el usuario del asistente**, ticket cerrado y comisión visible en el panel del estilista.
- El aviso de comisión sin confirmar en **los tres sitios**, y **desaparece al confirmar sin cambiar ningún número**.
- Controles **218** (9/9) y **219** (9/9) contra la base real.

---

## 5. Lo que NO hay que hacer

- 🔴 **NO pagar la suscripción.** La sede dice **\$150.000** y `EPAYCO_TEST_MODE` es `false`. Primero **AG**.
- **NO borrar la Peluquería Éxito Prueba.** Es el banco de pruebas.
- **NO quitar el `perform` de `change_ticket_status`.** Hoy es inalcanzable, pero es la red correcta si alguien llama esa RPC directamente.
- **NO rellenar `confirmed_at` por deducción.** Se estudió usar `updated_at > created_at` y **no es evidencia**: el sembrado `016` mueve esa fecha con `on conflict do update`.
- **NO dar AI por cerrado.** La tabla de comisiones entró en una migración, pero `supabase db reset` sigue roto: migraciones anteriores insertan en ella.
- **NO tocar AE, I-17, Ñ ni el fondo de AC**: son material del **9.25**.

---

## 6. Por dónde seguir

| Orden | Qué | Por qué |
|---|---|---|
| **1º** | **AG** — dos precios para lo mismo | **Es lo único que impide cobrar la primera suscripción.** Ya no hay nada del dinero del estilista por delante |
| **2º** | **Paso 9.48** — que la clienta autorice sus fotos y su reseña | Lo pidió el propietario. **Toca Ley 1581: quiere diseño con calma** |
| Sueltos | **AV**, **AR**, **I-18**, los **cuatro AK** que quedan | Media hora cada uno |

**Y lo que no es código:** el **9.24** — entrevistar salones reales con
`docs/03_referencias/GUION_ENTREVISTA_SALONES_9.24.txt` — sigue bloqueando el
**9.25**. Lleva parado desde el 07-sep, y hoy se le sumó otra cosa detrás.

### Lo nuevo del día: I-19, y por qué NO se hace ya

El propietario pidió el 20-sep **rehacer el layout de todas las pantallas, para
todos los roles**. Está anotado como **I-19**, y conviene no confundirlo con el
9.25:

> **El 9.25 cambia dónde se entra** (15 módulos → 5 lugares). **I-19 cambia qué
> hay dentro de cada pantalla.**

**Va después, no antes.** Rediseñar quince pantallas que luego se reagrupan en
cinco sitios es hacer el trabajo dos veces. La cadena es
**9.24 → 9.25 → I-19**, y quien la rompa va a pagarlo dos veces.

**Estado de los hallazgos: 42 en total, 24 abiertos, 18 cerrados.**

---

## 7. Una contradicción que sigue abierta

Se anota y no se resuelve por iniciativa propia:

- **`RESPALDO_Y_RESTAURACION_SUPABASE.md` nombra dos scripts de respaldo
  distintos** — `respaldo_supabase.ps1` en la tabla de arriba y
  `crear_respaldo_supabase.ps1` más abajo — y **los dos existen**, con nombres
  de carpeta diferentes (`Backup_...` y `BeautyOS_Backup_...`). El que ha hecho
  todos los respaldos de las migraciones es el primero. *(Venía del HANDOFF
  anterior; sigue sin tocarse.)*

---

## 8. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-250 y D-251).

Antes de tocar documentación: python scripts/verificar_documentos.py

DÓNDE ESTAMOS
El dinero del estilista quedo cerrado por los dos lados: la comision nace
(AP) y ya no nace decidida por nadie (AJ). Lo unico que bloquea cobrar la
primera suscripcion es AG.

CÓMO SE TRABAJA CON ÉL
Va paso a paso y confirma cada uno antes del siguiente. No es técnico: hay
que decirle QUÉ hace, CÓMO y POR DÓNDE, con los nombres exactos de los
botones. Los comandos se le dan en bloques bash de una sola línea, y los
ejecuta él. Encuentra fallos reales probando.

ANTES DE REESCRIBIR CUALQUIER FUNCION DE LA BASE
Extraer su texto vivo y compararlo linea por linea (D-119, D-122, D-123).
Hay dos guiones de ejemplo en supabase/sql/intervenciones/. El repositorio
NO es la fuente del esquema (hallazgo AI).

ORDEN ACORDADO
  1. AG - dos precios para lo mismo, y por eso no se puede cobrar
  2. Paso 9.48 - que la clienta autorice sus fotos y su resena (Ley 1581)
  Sueltos: AV, AR, I-18 y los cuatro dialogos de AK que quedan

NO PAGAR NADA. NO borrar la Peluqueria Exito Prueba: es el banco de pruebas.
NO rellenar confirmed_at por deduccion: updated_at lo mueve el sembrado 016.
NO dar AI por cerrado: supabase db reset sigue roto.
NO empezar I-19 (rehacer el layout de todas las pantallas) antes del 9.25:
la cadena es 9.24 -> 9.25 -> I-19, y saltarsela es hacerlo dos veces.

42 hallazgos: 24 abiertos, 18 cerrados. 251 decisiones. analyze 0/0 y
444 pruebas. Controles 218 y 219 en verde (9 de 9 cada uno). Guardian en
verde.
```
