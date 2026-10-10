# HANDOFF Salón y Más — 7 al 10 de octubre de 2026 ("Los pedidos de David, la contraseña y las sedes que se cierran", D-318 a D-329)

**Bloque documentado:** decisiones **D-318** a **D-329**. El 08-oct el propietario visitó a
**David Rojas** (Inspirant, el primer cliente real) y salieron sus pedidos: la página
pública nueva, las redes, elegir el servicio por cuadritos, cuándo vuelve cada clienta, el
catálogo ordenado, los estilistas con sus servicios y los precios *"desde"*. El 09-oct se
cerró **CO** (nadie podía recuperar ni cambiar su contraseña) y apareció **CQ** (cerrar una
sede: el único botón borraba el negocio entero). **El 10-oct se construyó y se probó de
verdad cerrar una sede sin borrar nada (D-328)**, y de esa prueba salieron y se cerraron
**CR** (una sede reabierta quedaba gratis, D-329) y **CS** (la tarjeta del Panel no se
actualizaba).

**Estado:** ✅ Todo lo escrito está **aplicado, publicado y comprobado en vivo**: siete
migraciones con sus controles en verde y a la primera (**246** 6/6, **247** 4/4, **248**
8/8, **249** 7/7, **250** 8/8, **251** 6/6) y tres cambios de datos de David (D-324, D-325,
D-326). La app publicada es **`634a607`**. `flutter analyze` sin avisos · **867 pruebas** ·
guardián (`verificar_documentos.py`) en verde.

**Sincronía:** al cerrar el 10-oct, **todo subido a GitHub**, también los documentos (lo
pidió el propietario: *"que no se pierda el más mínimo pedacito"*). Subir solo documentos
saca la franja de *"versión nueva"* sin motivo (**CH**); esta vez se aceptó.

**Hallazgos: 88 en total, 72 cerrados o decididos, 16 abiertos** (los cuenta
`python scripts/verificar_documentos.py`).

> El HANDOFF anterior está en `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-10-09_D328.md`
> (D-318 a D-328, escrito el 09-oct). Lo que de él sigue valiendo está copiado aquí.

---

## 1. Lo que hay que saber si solo se lee una cosa

**David Rojas es el primer cliente real y quiere solo agenda.** Su negocio tiene la caja
apagada: agenda de tres estados (Confirmado → En proceso → Cerrado), toda cita nace
confirmada, y **"Cerrado" es atendida, no cobrada** (D-312). **No se inventan pagos** (D-314).

**Peluquería Éxito Prueba es su ESPEJO**: tiene apagado lo mismo. Todo se prueba ahí
primero. Cuando algo nuevo le aparecería a David al publicarse, **se le apaga en el Panel
mientras se prueba** (si no hay interruptor, se le pregunta al propietario antes de subir,
como con D-323).

**Una sede se cierra, no se borra** (D-328): *Cerrar sede* en la ficha de la sede en el
Panel o en *Tus sedes* del salón (solo el dueño). Queda sin uso y sin cobro, conserva sus
clientas, su historial y sus pagos, sigue en los reportes, y con citas pendientes no se deja
cerrar. **Al volver a abrirla queda como estaba al cerrarse** (D-329).

| Decisión | Qué | Estado |
|---|---|---|
| D-318 | **Los cinco lugares** (*Agenda · Clientes · Mi negocio · Mi vitrina · Ajustes*), detrás de un interruptor | ✅ Entregas 1 y 2. Encendido en Éxito y a David. ⬜ **Entrega 3**: *Mi agenda* de la estilista en tarjetas |
| D-319 | **TikTok** y el **código QR** del enlace | ✅ Control 246 en 6/6 |
| D-320 | **La página pública, rediseñada** | ✅ Vista en Éxito y en la de David |
| D-321 | **Las redes, como usuario o enlace**; el Panel ve el TikTok | ✅ Control 247 en 4/4. ⬜ David: su Facebook y su TikTok |
| D-322 | **Elegir el servicio por cuadritos** (reserva en línea y Nueva cita); **"Pregunta por WhatsApp"** si no hay estilista | ✅ Probado por el propietario en los dos sitios |
| D-323 | **Cuándo vuelve cada clienta**: la hoja al cerrar (Agenda, Tickets y Caja, *Mi agenda*), con el interruptor *"Invitar a volver"*; la tarjeta en la ficha de Clientes | ✅ Control 248 en 8/8, publicada. ⬜ **Probarla en Éxito** |
| D-324 | **El catálogo de David en 8 categorías** y con la ortografía corregida | ✅ Aplicado. Keratina en 180 min y Extensiones confirmado |
| D-325 | **Los 4 estilistas de David hacen los 28 servicios** (la asesoría, solo David) | ✅ 28 servicios reservables en línea (eran 3) |
| D-326 | **Precios "desde", por categoría**; a David, Color | ✅ Control 249 en 7/7, visto en su página |
| D-327 | **Recuperar y cambiar la contraseña**, para todos los roles. Cierra **CO** | ✅ Probado de verdad. ⬜ Con la cuenta de dueño de la plataforma (verificación en dos pasos) |
| D-328 | **Una sede que se cierra no se borra**. Cierra **CQ** | ✅ Control 250 en 8/8, publicada y **probada de verdad** con *Prueba Dos Sedes* (cerrar desde el salón y desde el Panel, volver a abrir, y con citas no deja) |
| D-329 | **Una sede que se vuelve a abrir queda como estaba**. Cierra **CR** | ✅ Control 251 en 6/6, publicada (`1b266ad`) y **probada de verdad**: Sede Norte, sin pagar, se cerró y se reabrió, y siguió *Sin pagar* |

**Respaldos del propietario de este bloque:** `Backup_2026-10-08_07-06-39`,
`Backup_2026-10-08_14-38-32`, `Backup_2026-10-08_17-47-03`, `Backup_2026-10-09_11-00-44`,
`Backup_2026-10-09_11-19-14`, `Backup_2026-10-09_11-33-28` (tiene *Prueba Barbería Elite*
entera, menos sus imágenes), **`Backup_2026-10-10_04-16-28`** (antes de D-328) y
**`Backup_2026-10-10_14-42-41`** (antes de D-329).

### El negocio de prueba de dos sedes

**_Prueba Dos Sedes_** (marcado de prueba; dueña de prueba *Ana Maria Dos Sedes Prueba*,
cuenta `elboga008+sedes@…`). **El propietario decidió guardarlo** para probar lo de varias
sedes sin tocar a Éxito ni a David. Quedó así: la principal *Pendiente de activar*; **Sede
Norte abierta y *Sin pagar***, con un servicio (*Corte de Prueba*), una estilista
(*Estilista de Prueba*), una clienta (*Cliente de Prueba*) y una cita **cancelada** del
lunes 12-oct. Borrarlo con *Borrar negocio de prueba* no toca la cuenta de Éxito
(`elboga008@…`), que es otra.

---

## 2. Lo que se aprendió (y quedó escrito para no repetirlo)

**Del 10-oct:**

1. **Probar con un caso que no sea el feliz.** El cierre de una sede pasó todas sus pruebas
   con sedes al día; bastó probar una **sin pagar** para ver que al reabrirla desde el
   Panel quedaba gratis (CR). Al probar un cambio de estado, se prueba también desde los
   estados raros (sin pagar, en mora, suspendida).
2. **El nombre del botón se saca del código, no de memoria.** Se le dijo al propietario
   *"elija Sin pagar"* y la lista de *Pago* dice *"Pendiente de pago"*: tuvo que volver.
   De ahí salió **CT** (el mismo estado tiene tres nombres).
3. **Una captura con la franja *"Hay una versión nueva"* es de la versión vieja.** Dos
   veces el propietario mandó una captura anterior o sin actualizar; se reconoce por la
   franja, la hora del reloj de Windows o la ventana (incógnito o normal). Se dice con
   amabilidad y se repite el paso.
4. **Dentro de un control, todo pasa a la misma hora** (`now()` es la de la transacción).
   Dos cierres de una misma sede empatarían; el control 251 usa una sede por caso.
5. **Una lectura viva sirve también para confirmar una función recién escrita.** La de
   D-329 confirmó que lo vivo era idéntico a la migración de D-328 antes de generar la
   siguiente.

**Del 07 al 09-oct:**

6. **Leer antes de escribir, también en una lectura.** Si la tabla no se ha listado, se
   lista primero (`branch_stylist_services` apunta a `branch_stylists` y
   `branch_services`).
7. **Un cambio de datos de un cliente se escribe como una migración:** lectura viva, cada
   fila por su id, **y solo si sigue como se leyó** (D-324, D-325, D-326).
8. **Lo que está en el panel de Supabase puede no ser lo que dice el documento.** Antes de
   dar por buena una plantilla, se mira en el panel.
9. **No se marca cerrado lo que no se ha probado.** 🟡 hasta la prueba de verdad; solo
   entonces ✅.
10. **En una página de prueba, `top` es una palabra del navegador.** Se prueba en el
    navegador antes de enseñarlo.
11. **Un botón que borra todo no debe ser el único que se ve** (CQ).
12. **Las letras raras en PowerShell (`Barber├¡a`) son la consola, no la base.**

**De bloques anteriores, siguen valiendo:**

13. **Para una pantalla nueva, primero un prototipo**, y su sí.
14. **Dibujar la pantalla en una prueba caza lo que el análisis no ve.**
15. **El Postgres del computador trae solo el cliente**: no hay servidor local para probar
    SQL. Las migraciones se revisan a mano y las corre el propietario.
16. **Apagar algo también apaga lo que colgaba de ello** (D-312).
17. **Aquí no se formatea en bloque.**
18. **Para saber si Cloudflare publicó**, `build-info.json` y un texto nuevo en el
    `main.dart.js` publicado (con caché rota).
19. **Con HSTS activo, Cloudflare no se toca a ciegas** (D-294).
20. **Al guiar al propietario por una pantalla, un paso por mensaje, en español sencillo.**
21. **Los datos personales del propietario no se escriben completos en los documentos.**

---

## 3. Lo que tienes que mirar en pantalla (regla 21)

1. 🔲 **Cuándo vuelve, en Éxito** (D-323): cerrar una cita en la Agenda, jugar con los
   números y el interruptor, *Listo*; después abrir la ficha de esa clienta en Clientes y
   ver *Cuándo vuelve, por servicio*.
2. 🔲 **Recuperar la contraseña con la cuenta de dueño de la plataforma** (D-327): en una
   ventana de incógnito, *¿Olvidaste tu contraseña?* → código → **el de la app
   autenticadora** → contraseña nueva. Es el único camino de D-327 sin probar.
3. ✅ 10-oct: **cerrar y volver a abrir una sede** (D-328, D-329) desde el salón y desde el
   Panel, con citas y sin ellas; la tarjeta del Panel se actualiza sola (CS).
4. ✅ 09-oct: recuperar y cambiar la contraseña con una cuenta de prueba.
5. ✅ 08-oct: los cuadritos en la reserva y en Nueva cita.
6. ✅ 09-oct: la página de David con *Desde* en Color y los 28 servicios con *Reservar*.

---

## 4. Las decisiones que siguen siendo tuyas

| | Qué | Estado |
|---|---|---|
| **x** | **CT**: un solo nombre para la sede que no ha pagado (hoy *"Sin pagar"*, *"Pendiente de pago"* y *"Pendiente de activar"*) | Propuesta abierta; el texto lo decides tú |
| **v** | **CP**: el texto del campo del estilista en Nueva cita | Propuesta: *"2. Estilista"*, con *"Cualquiera disponible"* dentro de la lista |
| **c** | **Cuándo pasar a Supabase Pro** | El asistente aconsejó esperar |
| **d** | **I-13**: acceso de lectura a la base para el asistente | Hoy cada lectura es un comando tuyo |
| **k** | **9.26 (Meta)** | Esperar la matrícula mercantil o al contador |
| **l** | **9.33**: dónde guardas la bitácora de los socios | **No va al repositorio** |
| **m** | **9.16** (contador), **9.20** (abogado), **9.24** (entrevistas) | El 9.24 sigue bloqueando el turno E |
| **o** | **Las redes**: ¿TikTok o estados de WhatsApp? ¿se hizo el 9.23? | Sin respuesta |
| **p** | **CH**: que Cloudflare no publique cuando solo cambian documentos | Del panel de Cloudflare. Ojo con `functions/` |
| **t** | **El celular del propietario en el historial de git** | Sin decidir |
| **w** | **I-22, I-23, I-24** (tema propio, horario de cada estilista, cambiar el enlace desde el Panel) | En el buzón |
| ~~u~~ | ~~No recuperar *Prueba Barbería Elite*~~ (D-328) | ✅ 09-oct |
| ~~y~~ | ~~Cómo queda una sede reabierta~~ (D-329) | ✅ 10-oct: *"Como estaba"* |
| ~~z~~ | ~~Guardar o borrar *Prueba Dos Sedes*~~ | ✅ 10-oct: se guarda |

---

## 5. Lo que quedó a medias

### De David
- ⬜ Pegar el enlace de su **Facebook** y de su **TikTok** (D-321).
- ⬜ Subir las **fotos de su equipo** y confirmar que eligió el tema **Inspirant**.
- ⬜ Que **su equipo entre** (paso 0 de su plan).
- ⬜ Si alguien no hace un servicio (por ejemplo, maquillaje el barbero), quitárselo en
  *Estilistas* (D-325).

### De Éxito
- ⬜ Vaciar las **redes de prueba** (TikTok inventado, Instagram y Facebook de prueba).

### Otros
1. **AK**: diálogos de `tickets_page.dart` que se cierran antes de guardar (9.13).
2. **AI**: el repositorio no tiene el esquema entero; lo barato es escribirlo en
   `MAPA_TECNICO.md`.
3. **BS**: los correos de cuenta a veces no llegan. Dato del 09-oct: el de recuperar
   llegó en el mismo minuto desde `hola@salonymas.com`.
4. **AL**: al empleado invitado le llega el correo del dueño.
5. **El control 250 se ajustó a D-329** (sus pasos 6 y 7 esperaban `pending` y `active`) y
   **no se ha vuelto a correr**. No es urgente: lo nuevo lo prueba el 251. Se corre cuando
   se toque algo de las sedes.
6. **Visto, sin investigar (no es hallazgo todavía):** una cita **cancelada** sale en
   Tickets & Caja como *"Sin servicios · Sin estilista · 0 min · $0"* (la de *Prueba Dos
   Sedes*, 10-oct). Puede ser que la lista solo sume los servicios no cancelados, y entonces
   se pierde de vista qué se canceló. Antes de anotarlo, una lectura de cómo se cancela y
   de cómo arma la lista `service_names`.
7. **Señalado, no tocado:** `private.beautyos_resolve_consent_client` tiene `EXECUTE` para
   `PUBLIC` (no abre nada; no es el patrón, D-286).
8. **Señalado, no tocado:** la ficha de la sede en el Panel dice *"Cerrada (D-328): no se
   ve…"*, con el código de la decisión a la vista. El Panel ya enseña otros (*D-221*,
   *D-173*) y solo lo ve el propietario; si molesta, se quita.
9. **Señalado, no tocado:** en la base, `public.reopen_branch` conserva su comentario de
   D-328 (*"Como una sede nueva: pendiente de pago"*). Desde D-329 eso solo vale cuando no
   se sabe cómo estaba la sede (sin rastro `sede_cerrada`); lo explica la cabecera de la
   migración `20261010200000`. Se corrige si algún día se regenera esa función.

---

## 6. Lo que NO hay que hacer

- **NO borrar un negocio para cerrar una sede** (D-328): se usa *Cerrar sede*.
- **NO borrar la Peluquería Éxito Prueba.** Es el banco de pruebas y el **espejo de David**.
- **NO borrar *Prueba Dos Sedes*** sin preguntarle al propietario: decidió guardarla.
- **NO probar cobros ni caja en Éxito mientras sea espejo.**
- **NO cambiarle nada a David sin probarlo antes en el espejo**, o sin su sí si no hay
  interruptor.
- **NO cambiar datos de un cliente sin lectura viva y sin la condición "si sigue como se
  leyó"** (D-324, D-325).
- 🔴 **NO pagar nada** sin decisión explícita del propietario.
- **NO inventar pagos** en un negocio sin caja (D-314).
- **NO pactar una sede por debajo de $10.000** (D-265).
- **NO reescribir una función de la base, ni suponer una columna, sin su lectura viva**
  (regla 10).
- **NO decirle al propietario el nombre de un botón o de una opción sin mirarlo en el
  código.**
- **NO formatear en bloque** (`dart format lib/`).
- **NO armar a mano la respuesta de `functions/[slug].js` para las personas**, ni poner una
  llave secreta en `functions/` (D-316).
- **NO escribir completos los datos personales del propietario** en documentos ni commits.
- **NO volver a poner una casilla de "la clienta autorizó"**, ni pegar en el chat el enlace
  `?autorizar=` de una clienta real.
- **NO meter la bitácora de los socios en el repositorio** (Ley 1581, D-295).
- **Con HSTS activo, NO** poner *DNS only*, pausar Cloudflare, cambiar los *nameservers* ni
  quitar el certificado (D-294).
- **NO dejar un `{{ .ConfirmationURL }}` en las plantillas de código** (*Confirm signup*,
  *Reset Password*): el escáner del buzón lo gasta.
- **NO contar hallazgos a mano**: `python scripts/verificar_documentos.py`.
- **NO publicar nada en las redes sin el sí del propietario**, pieza por pieza (D-305).

---

## 7. Por dónde seguir: el esquema de trabajo

**Pedido por el propietario el 09-oct.** Los puntos 1 y 2 quedaron hechos el 10-oct. En
orden:

1. ✅ ~~Su sí a no recuperar *Prueba Barbería Elite*~~ (D-328).
2. ✅ ~~**Paso 9.65**, cerrar una sede sin perder nada~~ (CQ, D-328), y lo que salió de su
   prueba: **9.66** (CR, D-329) y **CS**. Todo probado de verdad y cerrado.
3. **Las dos pruebas en pantalla** de §3 (cuándo vuelve en Éxito; la contraseña con la
   cuenta de dueño de la plataforma). Las hace el propietario cuando pueda.
4. 🔴 **AK**: los diálogos que se cierran y borran lo escrito (9.13).
5. 🟡 **Los correos de cuenta**: **AL** (el correo del empleado invitado) y **BS** (los que a
   veces no llegan), de una vez, porque son las mismas plantillas.
6. 🟢 **CP** y **CT**: dos textos (el campo del estilista en Nueva cita; un solo nombre para
   la sede sin pagar), cuando el propietario decida las palabras. Van juntos, son cortos.
7. **Entrega 3 de los cinco lugares**: *Mi agenda* de la estilista en tarjetas, con fecha y
   *Día / Semana / Mes* (*Mi plata* solo con caja). Primero se revisa el prototipo de D-304.
8. **AI**, la parte barata: escribir en `MAPA_TECNICO.md` que el repositorio no es la fuente
   del esquema.
9. **Lo de David y Éxito** de §5, cuando el propietario hable con él.

**El orden general** (PLAN_MAESTRO §5): los pasos de David van primero (D-308). Después
siguen los turnos B (**9.20** y **9.16**), D (**9.26** espera la decisión **k**; **9.24** es
del propietario) y E (9.13, 9.14 e I-19), bloqueado por el **9.24**.

**Las redes van en su propio chat** (D-305, D-306, paso 9.57).

---

## 8. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-318 a D-329).

Antes de nada: la REGLA 25 del PLAN_MAESTRO §8. Afirmar exige prueba; lo
aprobado no se cambia sin avisar; el producto se pregunta aunque haya
permiso general; lo que corre el propietario se copia de algo que ya
funcionó; un letrero rancio se busca por lo que llama.

Y: python scripts/verificar_documentos.py (cuenta los hallazgos por ti).

DÓNDE ESTAMOS
El primer cliente real, David Rojas (Inspirant), quiere solo agenda.
Peluquería Éxito Prueba es su ESPEJO: todo se prueba ahí primero. Del 07 al
10-oct salieron y se publicaron sus pedidos (D-318 a D-326), se cerró CO
(recuperar y cambiar la contraseña, D-327) y se construyó y probó de verdad
cerrar una sede sin borrar nada (D-328) y reabrirla como estaba (D-329):
CQ, CR y CS cerrados. Prueba Dos Sedes se guarda para probar varias sedes.

LO PRIMERO
El esquema de trabajo de §7, desde el punto 3: las dos pruebas en pantalla
(cuándo vuelve en Éxito; recuperar la contraseña con la cuenta de dueño de
la plataforma), y después AK.

CÓMO SE TRABAJA CON ÉL
En español sencillo (él lo pidió: su inglés es limitado). Paso a paso, un
paso por mensaje, con los nombres exactos de los botones SACADOS DEL CÓDIGO.
Los comandos van en bloques y los ejecuta él (PowerShell). ANTES DE TOCAR LA
BASE: una lectura en intervenciones/, y la migración GENERADA desde ese texto
vivo. Respaldo antes de cada cambio. Una pantalla nueva: primero un prototipo.
ANTES DE PEDIRLE QUE PRUEBE ALGO: push hecho, build-info.json con el commit
nuevo, y que pulse "Actualizar" si sale la franja. Si su captura trae la
franja "Hay una versión nueva", es de la versión vieja.
AL PROBAR UN CAMBIO DE ESTADO: también desde los estados raros (sin pagar,
en mora, suspendida), no solo el feliz.
AL CERRAR CADA BLOQUE: decirle qué se subió y comprobar la sincronía.
NUNCA dart format en bloque.
```

---

## 9. Pruebas al cerrar

**867 pruebas, todas en verde**, en la corrida completa del 10-oct con el arreglo de CS
(`flutter test`), `flutter analyze` sin avisos. Nuevas en este bloque:
`elegir_servicio_d322_test.dart` (12), `cuando_vuelve_9_63_test.dart` (14),
`precios_desde_d326_test.dart` (7), `contrasena_co_test.dart` (11) y
`cerrar_sede_d328_test.dart` (8; una ajustada a D-329 y otra ampliada con CS). Ajustadas
porque buscaban lo de antes: `create_appointment_walkin_test.dart` (la lista desplegable del
servicio) y una línea de `cinco_lugares_d318_test.dart`.

**Controles SQL de este bloque:** 246 (6/6), 247 (4/4), 248 (8/8), 249 (7/7), 250 (8/8;
ajustado después a D-329, sin volver a correr) y 251 (6/6).
