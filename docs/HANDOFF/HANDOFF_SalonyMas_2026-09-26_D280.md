# HANDOFF Salón y Más — 26 de septiembre de 2026 ("AS cerrado del todo, con un negocio real", D-267 a D-280)

**Bloque documentado:** decisiones **D-267** a **D-280**. Cierra el resto del
**turno B** de la Fase 9: BC del todo, BQ (el pago real), y AS —archivos y
cuentas huérfanas al borrar un negocio de prueba— verificado en pantalla de
verdad, no solo escrito.

**Estado:** ✅ Todo publicado y aplicado. **Nada escrito queda sin aplicar ni
sin desplegar.** `flutter analyze` **0/0** · **494 pruebas** · Guardián en
verde · CI en verde.
**Hallazgos: 61 en total, 44 cerrados o decididos, 17 abiertos** (los cuenta
el guardián).

> El HANDOFF anterior está en
> `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-23_D266.md`.

---

## 1. Lo que hay que saber si solo se lee una cosa

**El turno A y casi todo el turno B de la Fase 9 están cerrados.** Lo que
queda del turno B es trabajo nuevo (9.48) o decisiones que no dependen de
escribir código (9.16, 9.20).

| Hallazgo / paso | Estado |
|---|---|
| BI, 9.7, 9.8, BP (turno A) | ✅ Cerrados (D-262, D-272, D-274) |
| BC — acceso de soporte a los datos de un negocio | ✅ Cerrado del todo (D-275–D-277): se queda igual para siempre, sin vencimiento |
| BQ — el webhook de ePayco no llegaba | ✅ Cerrado (D-271): la `EPAYCO_P_KEY` guardada no era la real; corregida y comprobada con un pago real reenviado |
| **AS — archivos y cuentas huérfanas al borrar un negocio de prueba** | ✅ **Cerrado del todo hoy (D-278–D-280), verificado en pantalla con un negocio real** — ver §2 |
| 9.48 — que la clienta apruebe su propia foto | 🔲 Aprobado por el propietario, **sin empezar** |
| 9.20 — documento legal para el abogado | ✅ Publicado; falta que el propietario lo envíe y traiga la respuesta |
| 9.16 — contador | ⏸️ Aplazado por el propietario hasta que empiece a facturar |

---

## 2. AS, contado completo (para no releer D-278 a D-280 entero)

**El hallazgo (18-sep) decía que borrar un negocio de prueba dejaba sus fotos
huérfanas en dos almacenes.** Al leer el patrón completo de Storage
aparecieron **cinco almacenes** con el mismo problema, no dos. El propietario
pidió arreglar los cinco.

**El mecanismo son dos funciones de servidor nuevas** (con `service_role`,
mismo patrón que `create-epayco-session`), no una ampliación de las
políticas de Storage — eso habría dado al operador de plataforma permiso de
**borrar** en el Storage de cualquier negocio, un salto mayor que el de solo
leer que ya tiene desde BC:

- **`platform-delete-tenant-storage`**: borra los archivos de los cinco
  almacenes (`work-photos`, `work-photos-private`, `tenant-logos`,
  `tenant-covers`, `stylist-photos`) **antes** de que se borren las filas, y
  captura la lista del equipo del negocio (`equipoUserIds`) mientras el
  negocio todavía existe.
- **`platform-delete-orphaned-accounts`**: borra de Supabase Auth las
  cuentas de esa lista que se queden sin ningún otro negocio, **después** de
  que `platform_delete_demo_tenant` borra las filas. **El orden no es una
  preferencia**: `tenant_memberships.user_id` es `on delete restrict` contra
  `auth.users` — mientras la fila de membresía exista, Postgres se niega a
  borrar la cuenta. Se encontró releyendo el esquema antes de desplegar, no
  al fallar en pantalla.

**La verificación en pantalla salió a la segunda, y la primera vez enseñó
algo importante.** El primer intento de borrar (Naguara de Uñas, la
original) se hizo con el sitio **todavía sirviendo el código de antes de
hoy** — nada se había subido con `git push`, así que las funciones nuevas
nunca corrieron. Las filas se fueron (por `deleteDemoTenant`, que no es
nuevo), pero los archivos quedaron huérfanos de verdad: la prueba reprodujo
el problema que AS existe para evitar. Se corrigió el camino (push, y un
barrido de Storage encontró 11 archivos sueltos — 5 de esa Naguara y 6 de
**Exportadora**, un negocio borrado antes de esta sesión — que el
propietario limpió a mano desde el panel). La segunda vuelta sí probó AS de
verdad: una Naguara nueva, con logo, portada, foto y equipo reales,
borrada de nuevo. El aviso final: *"Borrado 'Naguara de Uñas': 53 filas en
28 tablas, 2 archivos y 2 cuentas de correo"*, confirmado con capturas de
Storage y Authentication.

**De esa verificación salieron dos hallazgos nuevos, sin relación con AS ni
entre sí, en el buzón de ideas (sin fase):**

- **BR** — subir una foto de trabajo sin ticket puede dejarla huérfana en
  Storage desde el primer día, **en cualquier negocio**, sin que nadie borre
  nada: `create_work_photo` exige un ticket, el archivo se sube primero y la
  fila se crea después en una llamada aparte, y si esa segunda llamada
  falla, nadie lo detecta ni lo limpia.
- **BS** — el código de verificación de Supabase Auth (registro, invitación
  aceptada) no siempre llega, mientras los correos propios de la aplicación
  sí. **La causa no está confirmada**: `ARQUITECTURA_Y_EVOLUCION.md` dice
  que Resend ya es el SMTP de Auth, así que la explicación fácil
  ("Auth usa el remitente de pruebas de Supabase") puede estar mal. Antes de
  suponer nada, hay que mirar Authentication → Emails → SMTP Settings en el
  panel de Supabase.

---

## 3. Lo que tienes que mirar en pantalla (regla 21)

**Nada pendiente ahora mismo.** La verificación de AS ya se hizo hoy, en
vivo, con un negocio real — no queda una comprobación tuya suelta de este
bloque.

---

## 4. Las decisiones que siguen siendo tuyas

| | Qué | Por qué importa |
|---|---|---|
| **c** | **Cuándo pasar a Supabase Pro** | D-088 decía *cuando cargue datos*, D-226 *cuando pague* |
| **d** | **I-13**: acceso de lectura a la base para el asistente | Hoy cada lectura es un comando tuyo con contraseña |
| **h** | **Las fotos: ¿quitamos los tipos *Final* y *Portafolio*?** | Lo decía el hallazgo Ñ, y ya definiste el flujo |
| **i** | **BS**: ¿revisamos juntos el SMTP de Auth en el panel de Supabase?** | Antes de decidir si se arregla, hay que saber si Resend de verdad está puesto ahí o no |

---

## 5. Lo que quedó a medias

1. **AK — seis diálogos en `tickets_page.dart`** (agregar, cambiar y quitar
   servicio; reprogramar; cambiar estado; corregir) todavía se cierran antes
   de guardar. Van con el **9.13**, porque son flujos de caja.
2. **9.48** — que la clienta apruebe su propia foto desde su portal.
   **Aprobado por el propietario, sin una sola línea escrita todavía**: hoy
   el portal de la clienta solo **muestra** sus fotos, no tiene ningún botón
   de aprobar.
3. **BR y BS** — en el buzón de ideas, sin fase asignada, sin empezar.

---

## 6. Lo que NO hay que hacer

- **NO borrar la Peluquería Éxito Prueba.** Sigue siendo el banco de
  pruebas.
- 🔴 **NO pagar nada** sin decisión explícita del propietario para ese pago
  en concreto.
- **NO pactar una sede por debajo de $10.000**: la base lo niega a propósito
  (D-265).
- **NO reescribir una función de la base sin su lectura viva** (regla 10):
  hoy volvió a demostrarse con `tenant_memberships.user_id on delete
  restrict`, encontrado leyendo el esquema antes de escribir, no después de
  fallar.
- **NO suponer la causa de BS.** Ya se escribió mal una vez en esta misma
  sesión (que Auth usa el remitente de pruebas de Supabase) sin comprobarlo
  contra `ARQUITECTURA_Y_EVOLUCION.md`, que dice lo contrario. Se corrigió,
  pero la causa real sigue sin confirmarse.
- **NO contar hallazgos a mano**: `python scripts/verificar_documentos.py`.

---

## 7. Por dónde seguir

1. **9.48** es lo único que queda del turno B con trabajo real por hacer:
   construir el botón de aprobación en el portal de la clienta. Antes de
   escribir nada, presentar un plan (regla 8) — es una pantalla nueva para
   alguien que no es del salón, con datos sensibles de por medio.
2. **9.20** y **9.16** no necesitan acción tuya: esperan al propietario
   (enviar al abogado; empezar a facturar).
3. **BR y BS** quedan en el buzón — no se tocan hasta que el propietario los
   priorice.
4. Con el turno B cerrado en la práctica, toca preguntarle al propietario
   por el orden de los turnos **C, D, E** de la Fase 9 (regla 8: no asumir
   el siguiente paso).

---

## 8. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-267 a D-280).

Antes de nada: la REGLA 25 del PLAN_MAESTRO §8. Afirmar exige prueba; lo
aprobado no se cambia sin avisar; el producto se pregunta aunque haya
permiso general; lo que corre el propietario se copia de algo que ya
funcionó; un letrero rancio se busca por lo que llama.

Y: python scripts/verificar_documentos.py (cuenta los hallazgos por ti).

DÓNDE ESTAMOS
El turno A y casi todo el turno B de la Fase 9 están cerrados. AS (archivos
y cuentas huérfanas al borrar un negocio de prueba) se cerró hoy del todo,
con dos funciones de servidor nuevas y una verificación en pantalla real
-- que a la primera salió mal porque se probó sin hacer git push, y eso
mismo enseñó por qué siempre hay que confirmar que el sitio corre el código
que se acaba de escribir, no el de antes. De esa verificación salieron dos
hallazgos nuevos y menores, BR y BS, en el buzón de ideas.

Lo único del turno B con trabajo real pendiente es el 9.48 (que la clienta
apruebe su propia foto) -- aprobado por el propietario, sin empezar.

LO PRIMERO
Preguntarle si quiere seguir con el 9.48, o si prefiere primero decidir el
orden de los turnos C, D, E de la Fase 9.

CÓMO SE TRABAJA CON ÉL
Paso a paso, en español claro y con los nombres exactos de los botones. Los
comandos van en bloques bash de una sola línea y los ejecuta él.
ANTES DE REESCRIBIR UNA FUNCIÓN DE LA BASE: una lectura en
intervenciones/extraer_*.sql, y la migración GENERADA desde ese texto vivo.
ANTES DE PEDIRLE QUE PRUEBE ALGO EN PANTALLA: confirmar que lo que va a
probar es el código que se acaba de escribir, no el que ya estaba (si hubo
`git push` y ya se publicó).

NO PAGAR NADA sin su decisión explícita. NO borrar la Peluquería Éxito
Prueba. NO pactar una sede por debajo de $10.000. NO contar hallazgos a
mano. NO suponer la causa de BS sin mirar el panel de Supabase primero.
```
