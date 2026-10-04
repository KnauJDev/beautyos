# HANDOFF Salón y Más — 2 y 3 de octubre de 2026 ("El primer cliente real", D-307 a D-313)

**Bloque documentado:** decisiones **D-307** a **D-313**, del 02 y el 03 de octubre.
El 02-oct entró el **primer cliente real, David Rojas**, y el trabajo pasó a ser su plan
(D-308, pasos 0 a 6). Están hechos y probados en pantalla los pasos **0, 1 y 2**. El 2 lo
amplió el propietario: la **agenda de tres estados** para los negocios con la caja
apagada (D-312). Y el 03-oct, el **enlace para reservar con el nombre del salón**, como
regla para todos (D-313).

**Estado:** ✅ Todo escrito está **aplicado y publicado**: tres migraciones, con sus
controles en verde (**239** 5/5, **240** 9/9 y **241** 6/6), y **todo visto en pantalla**
el 03-oct (§3). Solo queda mirar, sin prisa, la tarjeta *Reserva pública* de Configuración.
`flutter analyze` sin avisos · **695 pruebas** · guardián en verde.
**Hallazgos: 78 en total, 63 cerrados o decididos, 15 abiertos** (los cuenta
`python scripts/verificar_documentos.py`).

**Sincronía, comprobada el 03-oct por la tarde:** `main` local igual a GitHub (nada sin
subir ni sin bajar, ningún archivo sin guardar); Cloudflare publicó el último commit de
la app (`8585f98`, confirmado tres veces en `build-info.json`).

> El HANDOFF anterior está en `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-10-01_D306.md`
> (D-289 a D-306). Lo que de él sigue valiendo está copiado aquí.

---

## 1. Lo que hay que saber si solo se lee una cosa

**David Rojas es el primer cliente real.** Quiere **solo agenda**: sin dinero, sin
cobros ni comisiones. Desde el 02-oct la plataforma puede **apagarle módulos a un
negocio desde el Panel**, y lo apagado **desaparece** de su app. Desde el 03-oct, un
negocio con la caja apagada tiene una **agenda de tres estados** (Confirmado → En
proceso → Cerrado) en la que **toda cita nace confirmada**. **"Cerrado" significa
atendida, no cobrada:** no nace ningún pago ni comisión.

**Peluquería Éxito Prueba es el ESPEJO de David.** Tiene apagado lo mismo que él. Cada
paso nuevo se prueba ahí primero: con la cuenta del dueño de Éxito y con la de las
estilistas (*Ayudante segunda Linea Celular* y *Erick Estilista*).

| Decisión | Qué | Estado |
|---|---|---|
| D-307 | **CE**: la página pública de un salón también funciona con una sesión abierta (las seis funciones públicas, concedidas también a `authenticated`) | ✅ aplicada, control 238 en 3/3, **vista en el celular con sesión el 03-oct** |
| D-308 | **El primer cliente real cambia el orden.** El plan de David, pasos 0 a 6 (abajo). **Precio:** $50.000 al mes para los que el propietario visite y convenza; David, **$30.000**, revisable | ✍️ en curso |
| D-309 | **CF** (paso 0): el estilista de David no pudo entrar porque escribió el código de un correo viejo. *Ingresar* ya no manda un código solo; vale el del correo más reciente | ✅ verificado en pantalla con una cuenta nueva |
| D-310 | **Paso 1:** el Panel apaga módulos **por negocio** (*Caja y cobros, Finanzas, Inventario, Comisiones, Fotos, Reseñas, Blog*), y lo apagado desaparece en vez de salir con candado | ✅ control 239 en 5/5, probado en pantalla en el espejo |
| D-311 | **David conserva el Dashboard, pero sin dinero**, en cuatro bloques: citas, clientes, servicios, equipo y canal. Se construye **con el paso 5**. Mientras tanto, *Finanzas* apagada; *Fotos* y *Reseñas* se le quedan, a propósito | ✍️ decidida, sin construir |
| D-312 | **Paso 2, ampliado: agenda de tres estados** para los negocios con la caja apagada. Toda cita nace confirmada (enlace, salón y recurrentes); Iniciar, Cerrar, Cancelar y No asistió en la propia cita; Cerrar se puede pulsar desde Confirmado. **Arregló que, sin caja, la agenda no podía mover ninguna cita** | ✅ control 240 en 9/9, **probada de punta a punta** |
| D-313 | **El enlace para reservar lleva el nombre del salón** (`salonymas.com/<nombre>`), **regla para todos**, en la sede principal; las otras sedes, el enlace directo hasta tener `<salon>/<sede>`. Mismo bloque: **CJ** (la app en español y el calendario de un toque), el botón **Listo** al confirmar y dos textos viejos | ✅ control 241 en 6/6, **vista en pantalla el 03-oct** (enlace, calendario y *Listo*) |

**Hallazgos de estos dos días:** **CE** y **CF** (cerrados con D-307 y D-309) · **CG**
(abierto: el aviso de términos no se borra al marcar la casilla) · **CH** (abierto: cada
commit solo de documentos hace que la app anuncie *"Hay una versión nueva"*) · **CI**
(cerrado: la tarjeta de la cita y el recordatorio de WhatsApp daban la hora en UTC,
14:00 por 09:00) · **CJ** (cerrado: los calendarios salían en inglés).

**Respaldos del propietario:** `Backup_2026-10-02_18-05-00`, `Backup_2026-10-03_08-49-43`
(el semanal), `Backup_2026-10-03_13-34-45`, `Backup_2026-10-03_15-45-21` y `Backup_2026-10-03_19-15-32`.

---

## 2. Lo que se aprendió (y quedó escrito para no repetirlo)

**De estos dos días:**

1. **Apagar algo también apaga lo que colgaba de ello.** Al esconderle *Tickets & Caja*
   a David (D-310), su agenda se quedó sin manera de confirmar, iniciar ni cancelar
   citas: todo eso vivía allí. Lo vio la lectura del paso 2, no las pruebas. Al apagar
   un módulo hay que preguntar qué otras pantallas lo usaban.
2. **Un espejo vale más que las capturas del cliente.** Éxito con los mismos módulos
   apagados que David deja probar todo sin depender de él (02-oct, idea del
   propietario).
3. **La regla 10 vale también para las políticas de seguridad, no solo para las
   funciones.** D-313 dio por hecho que una estilista podía leer la tabla `tenants`
   por una política del 16-ago. En vivo se niega (*"permission denied for table
   tenant_memberships"*). La lectura `verificar_enlace_con_nombre_d313.sql` lo cazó
   antes de que llegara a David.
4. **Aquí no se formatea en bloque.** `dart format lib/` reformateó 112 archivos ajenos.
   Se deshizo con git antes de subir nada. Trampa anotada en `MAPA_TECNICO` §7.
5. **Después de un `git checkout`, los archivos vuelven con CRLF** y algunas pruebas
   fallan en local aunque el código esté bien. Se deja la copia de trabajo en LF
   (`MAPA_TECNICO` §7).
6. **El aviso *"Hay una versión nueva"* trae el enlace *Actualizar* pequeño, a la
   derecha.** Dos pruebas seguidas se hicieron con la versión vieja porque no se tocó.
7. **Una búsqueda cortada da una cifra falsa.** Se dijeron 11 calendarios y eran 15: la
   búsqueda se cortó a los diez resultados (D-313). Afirmar exige prueba (regla 25).
8. **El propietario quiere saber qué se subió.** El 03-oct preguntó si se estaba
   haciendo *commit* y *push*. Al cerrar cada bloque se le dice qué se subió y se
   comprueba la sincronía con GitHub.

**Del bloque anterior, siguen valiendo:**

9. **Probar en pantalla encuentra lo que los controles no ven** (BY, BZ y CA en una
   mañana, el 30-sep; CI y CJ el 03-oct).
10. **Antes de anotar un hallazgo, se busca por lo que describe** (CA era AD).
11. **Al cerrar un turno, cada elemento de su fila se tacha o se mueve** (D-274 dejó
    fuera 9.40, AD y 9.9).
12. **Para saber si Cloudflare publicó, se mira `build-info.json`** (el commit) o se
    compara el `main.dart.js` publicado con el local.
13. **Con HSTS activo, Cloudflare no se toca a ciegas** (D-294).
14. **Las pruebas de lo que entra destapan lo que las de lo que sale no ven** (CB → CC).
15. **"Archivado en el scratchpad" significa perdido.** Lo que sirve para mañana va al
    repositorio, salvo lo que no puede ir (la bitácora, por la Ley 1581).
16. **Un arreglo en una pieza no arregla la hermana** (la bandera 🇨🇴 de las redes).
17. **Al guiar al propietario por una pantalla, un paso por mensaje** (regla 3).

---

## 3. Lo que tienes que mirar en pantalla (regla 21)

1. ✅ **03-oct: la estilista copia `https://salonymas.com/peluqueria-exito-prueba`.** Queda la otra mitad. **D-313, el enlace con el nombre.** En el celular, con la sesión de Erick:
   **Actualizar** si sale el aviso → *Mi agenda* → **"Copiar enlace"** → pegarlo en un
   chat sin enviarlo. Debe salir `salonymas.com/<nombre de Éxito>`, sin el código. Y en
   el computador, como dueño de Éxito: *Configuración* → *Reserva pública* debe dar la
   misma dirección.
2. ✅ **03-oct: visto.** **D-313, el calendario y el *Listo*.** Al reservar por el enlace, el calendario sale
   en español y se cierra al tocar el día. Al confirmar, **Listo** devuelve a la página
   del salón.
3. ✅ **03-oct: visto** (reservó con la sesión de Erick abierta, desde el enlace de WhatsApp). **CE en el celular con la sesión abierta.** El 03-oct se reservó desde el celular,
   pero no consta si la pestaña tenía sesión. Basta una reserva en una pestaña normal
   del navegador donde esté abierta la sesión de Erick.
4. ✅ **03-oct: era un fallo de verdad (hallazgo CK)** y está cerrado: los botones de WhatsApp
   mandaban el celular sin el 57. ✅ **Visto con un número real** (el del propietario): abre su chat
   con *"Hola Juan, te escribimos de Peluquería Éxito Prueba."*

---

## 4. Las decisiones que siguen siendo tuyas

| | Qué | Estado |
|---|---|---|
| **c** | **Cuándo pasar a Supabase Pro** | El asistente aconsejó esperar (no acelera la app) y seguir con el respaldo semanal |
| **d** | **I-13**: acceso de lectura a la base para el asistente | Hoy cada lectura es un comando tuyo con contraseña |
| **h** | **Ñ**: quitar los tipos de foto *Final* y *Portafolio* | **02-oct: decidido, sí.** Se hace con la reestructura (9.25) |
| **i** | **BS**: revisar juntos el SMTP de Auth en Supabase | Abierto |
| **k** | **9.26 (Meta)** | Esperar la matrícula mercantil o al contador |
| **l** | **9.33**: dónde guardas la bitácora de los socios y la respuesta sobre factura (§8 del protocolo) | Abierto. La bitácora con la fila de David se te envió el 02-oct; **no va al repositorio** |
| **m** | **9.16** (contador), **9.20** (abogado), **9.24** (entrevistas) | El 9.24 sigue bloqueando el turno E |
| **o** | **Las redes:** ¿TikTok o estados de WhatsApp? ¿se hizo el 9.23? | Sin respuesta |
| **p** | **CH**: que Cloudflare no publique cuando solo cambian documentos (*Build watch paths*) | Es del panel de Cloudflare: lo decides tú |
| **q** | **Juntar las dos tarjetas de enlaces de Configuración** (*Enlace web* y *Reserva pública*, que en un salón de una sede dan el mismo) | Propuesto para el paso 6 |
| **r** | **Paso 5:** cómo se separan el Dashboard sin dinero y *Reportes*, que comparten interruptor | Se pregunta al llegar al paso 5 (D-311) |

**Ya decidido el 03-oct:** **no se inventan pagos** en un negocio sin caja (D-314: crearía ventas numeradas y comisiones); el Panel tiene *"Ver su página pública"* (D-314); ver la app como la ve el dueño, más adelante (Ley 1581). La tarjeta de WhatsApp con el logo y el nombre del salón va
con el **paso 3**; la agenda de la estilista en tarjetas, con semana y mes, va con el
**paso 6**.

---

## 5. Lo que quedó a medias

### El plan de David (D-308)

| Paso | Qué | Estado |
|---|---|---|
| 0 | Que su equipo pueda entrar (CF) | ✅ D-309. **Falta que su equipo entre** por *Ingresar* pidiendo un código nuevo (sus cuentas estaban sin confirmar) |
| 1 | Interruptores por negocio | ✅ D-310. A David: apagados *Caja y cobros, Finanzas, Inventario, Comisiones, Blog*; encendidos *Fotos* y *Reseñas* (D-311). Se le pasó el mensaje para que actualice y mande captura |
| 2 | Citas confirmadas → **agenda de tres estados** | ✅ D-312, probada |
| 3 | **Su tema** (blanco, dorado, rosado, negro) | ✅ **El tema, hecho y visto en el espejo el 03-oct (D-315, paso 9.60):** el propietario eligió *Inspirant* en Éxito y se ve en Configuración, Agenda, Clientes, Reseñas, Servicios y Estilistas (barra y botones dorados, títulos negros, selecciones rosa; los estados, igual). De esas capturas salieron **CL** y **CM**. ✅ **Visto también en la página pública del espejo, en el celular.** **La tarjeta de WhatsApp y los íconos (D-316), escritos el 03-oct:** `functions/[slug].js` (función de Cloudflare Pages: solo a los lectores de vistas previas de las redes les cambia título, texto y portada; a las personas, la página como siempre) y `web/_routes.json`; fuera los emojis 📅 y 👤 de la página pública (y el 📅 de *Guardar en Google Calendar*). 728 pruebas. ✅ **En vivo el 03-oct** (`a8c2040`): con `curl`, WhatsApp recibe la tarjeta y las personas la página idéntica, con las mismas cabeceras. **Quedan del paso 3:** verla en un WhatsApp de verdad (el celular guarda la tarjeta vieja de un enlace ya compartido: probar con `?v=1` al final), que David elija el tema (solo el dueño del salón puede) y lo que quede por pulir de la página pública. **El tema propio de tres elecciones quedó en el buzón como I-22.** *Lo de antes:* David mandó su logo (monograma *DM*, café sobre champán) y una foto del local (el rosa es el de las flores del techo; dorado en las grecas y la recepción; mostrador negro). **El propietario eligió:** barra **dorada** (#8C6A2E), títulos **negros** (#2B2522), fondos y selecciones con el **rosa de las flores** (#F6DDE4…), como **sexto tema para todos**, con el nombre **"Inspirant"**. Lectura viva: `intervenciones/extraer_tema_inspirant_paso3.sql` (la lista de temas vive en la restricción `tenants_theme_key_valido` y en `update_tenant_theme`). **Al buzón:** un *personalizado de tres elecciones* (barra, títulos, color suave) con corrección automática de contraste, que el propietario pidió como "4 colores que el salón seleccione"; toca las funciones públicas.  (Antes: en espera del logo.) **Escritos el 03-oct:** migración `20261003230000_tema_inspirant_paso3.sql` (desde el texto vivo: solo agrega 'inspirant' a la restricción y a `update_tenant_theme`), **control 243** y `AppBrand.inspirant` (las pruebas de contraste pasan). ✅ **Aplicada el 03-oct, control 243 en 4/4** (respaldo `Backup_2026-10-03_19-15-32`). Falta elegirlo en Configuración (solo el dueño del salón puede) y verlo. *(El `data.sql` de ese respaldo pesó 41 KB menos que el de las 15:45; comparadas tabla por tabla, solo bajaron las sesiones vencidas `auth.refresh_tokens`, 407 → 199, que Supabase limpia sola; los datos del negocio, iguales, más 3 invitaciones de prueba.)* **Pista:** su página ya tiene su portada (negra, con su firma *"David Marin"* en blanco) y su logo (beige o dorado). **Y le faltan las fotos de sus estilistas**: se suben en *Estilistas → editar → Subir foto*. Con él: la **tarjeta de WhatsApp** con logo y nombre del salón (una función pequeña en Cloudflare, sin tocar DNS) y **pulir la página pública** del salón |
| 4 | **Invitar a volver** a quien ya atendió (D-314, paso 9.59) | ✅ **4A escrita y vista en el espejo el 03-oct**: Clientes sin dinero en los negocios sin caja y el WhatsApp con el nombre del salón y su enlace. Textos menores pendientes: *"Cada ~1 días"*, el filtro VIP cortado, *"historial de valor"* y *"Retorno y Valor (RFM)"*. **4B, diseño decidido el 03-oct** (D-314): un recordatorio **por cada servicio** que se hizo la clienta (rubber a 20 días no borra el tinte a 60-90), invitar eligiendo el servicio; las invitadas que no volvieron, aparte y con *"última invitación hace N días"*; 45 días por defecto, por salón; la lista arriba de la Agenda y como filtro en Clientes. Lectura corrida el 03-oct. **Escritas:** migración `20261003200000_invitar_a_volver_por_servicio_d314.sql` (solo agrega: dos columnas, una tabla cerrada como `clients` y cinco funciones nuevas) y **control 242** (8 comprobaciones). ✅ **Aplicada el 03-oct, control 242 en 8/8** (respaldo `Backup_2026-10-03_15-45-21`). **App escrita y vista en pantalla el 03-oct** en el espejo (con Pedicure a 1 día: *"Para invitar hoy (4 clientas)"*, el WhatsApp con salón, servicio y enlace, *"Invitada hoy · Invitar otra vez"*). De ahí salió **CK** (WhatsApp sin el 57), cerrado. **En Éxito, Corte de Cabello y Pedicure Basico quedaron en 1 día de prueba**: devolverlos a vacío cuando ya no hagan falta. **Decidido: no se inventan pagos** |
| 5 | **Agenda sin cobro** | Pendiente, ya en parte hecha por D-312. Queda: el **Dashboard sin dinero** (D-311); *Configuración* le sigue mostrando la política de comisiones y la numeración de ventas; en el celular el tablero tiene el botón *Semana* partido |
| 6 | **Los cinco lugares** (9.25) | Pendiente. Con él: **la agenda de la estilista en tarjetas, con semana y mes** (hoy es una tabla ancha), sus flechas de fecha descuadradas, y juntar las tarjetas de enlaces de Configuración |

### Otros

1. **Multisede:** darle a cada sede su dirección con nombre (`salonymas.com/<salon>/<sede>`).
   Necesita el servidor. Hoy solo un negocio, de demostración, tiene dos sedes (D-313).
2. **El riesgo de la dirección con nombre:** si un salón cambia su dirección, los enlaces
   y QR ya repartidos dejan de servir. Se puede resolver guardando las direcciones
   viejas (D-313).
3. **CG** (menor): borrar el aviso de términos al marcar la casilla (`register_page.dart`).
4. **La lista del Panel no se refresca** al mover un interruptor; se ve con ↻ (D-310).
5. **AK**: seis diálogos de `tickets_page.dart` que se cierran antes de guardar. Van con el 9.13.
6. **BR y BS**: en el buzón, sin fase.
7. **Señalado, no tocado:** `private.beautyos_resolve_consent_client` tiene `EXECUTE` para
   `PUBLIC` (no abre nada; no es el patrón, D-286). La intención de pago de un intento
   cancelado queda `verificada` (significa "cruzada con ePayco", D-297).
8. **AI**: el repositorio no tiene el esquema entero. Ejemplo del 03-oct:
   `get_my_branch_context_v2` no está en ninguna migración. Volcarlo va en el turno E.
9. **CL** (la cabecera dice *"BeautyOS"* bajo el nombre del salón, en pantalla ancha): qué
   poner ahí lo decide el propietario. **CM** (*"Precio medio $24333"* sin punto de miles en
   Servicios; igual en Gastos y Compras): sin decisión de producto.
10. **Visto una vez, sin confirmar:** justo después de guardar el tema, la primera captura
   tenía la vista previa dorada pero la cabecera y el menú todavía con los colores del tema
   anterior; en las siguientes ya estaba todo dorado. Puede ser que la cabecera solo se
   repinte al cambiar de pantalla. No se abrió hallazgo: falta verlo otra vez.

---

## 6. Lo que NO hay que hacer

- **NO borrar la Peluquería Éxito Prueba.** Es el banco de pruebas y el **espejo de David**.
- **NO probar cobros ni caja en Éxito mientras sea espejo.** Para eso se enciende *Caja y
  cobros* desde el Panel: todo reaparece, porque no se borra nada.
- **NO apagarle ni cambiarle nada a David sin probarlo antes en el espejo.**
- 🔴 **NO pagar nada** sin decisión explícita del propietario.
- **NO pactar una sede por debajo de $10.000** (D-265). El mínimo de ePayco es $5.000 (D-296).
- **NO tratar *Cancelada* como rechazo en la base** (D-297).
- **NO reescribir una función de la base, ni dar por hecha una política de seguridad,
  sin su lectura viva** (regla 10; D-313).
- **NO formatear en bloque** (`dart format lib/`).
- **NO armar a mano la respuesta de `functions/[slug].js` para las personas**: debe salir de
  `env.ASSETS.fetch`, que es lo que aplica `_headers` (la seguridad) y `_redirects` (D-316).
- **NO poner nunca una llave secreta en `functions/`**: solo la publicable, la de `lib/main.dart`.
- **NO volver a poner una casilla de "la clienta autorizó"** en ninguna pantalla del salón.
- **NO pegar en el chat el enlace `?autorizar=` de una clienta real**: abre sin PIN.
- **NO meter la bitácora de los socios en el repositorio** (Ley 1581, D-295).
- **Con HSTS activo, NO** poner *DNS only*, pausar Cloudflare, cambiar los *nameservers*
  ni quitar el certificado (D-294).
- **NO contar hallazgos a mano**: `python scripts/verificar_documentos.py`.
- **NO publicar, responder, borrar ni cambiar nada en las redes sin el sí del
  propietario**, pieza por pieza (D-305). Las contraseñas las escribe él.
- **NO buscar la página de Facebook desde el perfil de Chrome de IL Profumo**: se maneja
  desde el perfil **"J"** (D-305).
- **NO repetir *"Multi-sede… sin pagar de más"*** en piezas nuevas (D-189).
- **NO dejar la fuente de una pieza gráfica fuera de `docs/00_producto/marca/plantillas/`.**

---

## 7. Por dónde seguir

**Lo inmediato:** lo que queda del **paso 3 de David** (el tema ya está, D-315): ver
*Inspirant* en la página pública del espejo, la tarjeta de WhatsApp con su logo y su
nombre, y pulir la página pública. Antes de proponer, **preguntar** (regla 25: el
producto se pregunta).

**El orden general** (PLAN_MAESTRO §5): el primer cliente real lo cambió (D-308). Los
pasos de David van primero. Después siguen los turnos: B (**9.20** y **9.16**, del
propietario), D (**9.26** espera la decisión **k**; **9.24** es suyo) y E (9.25, 9.13,
9.14 e I-19, el layout), que sigue bloqueado por el **9.24**. El prototipo de los cinco
lugares (D-304) está en https://claude.ai/artifact/1ESsefBVb3dhH6iSYEgqPb (privado) y
se usa **después** de las entrevistas, no en ellas.

**Las redes van en su propio chat** (D-305, D-306, paso 9.57): plantillas en
`marca/plantillas/`, entrevistas por contacto directo con el mensaje de
`REDES_SOCIALES.md` §7, y la publicación fija *"Por qué nació Salón y Más"*. **Los
detalles personales del propietario no se escriben en el repositorio.**

---

## 8. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-307 a D-316).

Antes de nada: la REGLA 25 del PLAN_MAESTRO §8. Afirmar exige prueba; lo
aprobado no se cambia sin avisar; el producto se pregunta aunque haya
permiso general; lo que corre el propietario se copia de algo que ya
funcionó; un letrero rancio se busca por lo que llama.

Y: python scripts/verificar_documentos.py (cuenta los hallazgos por ti).

SI ESTE CHAT ES DE REDES: lee 02_operacion/REDES_SOCIALES.md, D-305, D-306 y
el paso 9.57. Nada se publica sin su sí, pieza por pieza.

DÓNDE ESTAMOS
El primer cliente real, David Rojas, quiere solo agenda. Su plan (D-308) va
por el paso 3: el 0 (que su equipo entre, D-309), el 1 (interruptores por
negocio, D-310), el 2 (agenda de tres estados, D-312) y el 4 (invitar a
volver, D-314) están hechos y probados; del 3, el tema Inspirant (D-315).
Peluquería Éxito Prueba es su ESPEJO: todo se prueba ahí primero.
El enlace para reservar lleva el nombre del salón (D-313), visto en pantalla.

LO PRIMERO
Lo que queda del paso 3 de David (el tema Inspirant ya está, D-315): la
tarjeta de WhatsApp con su logo y pulir la página pública. Preguntar antes
de proponer.

CÓMO SE TRABAJA CON ÉL
Paso a paso, un paso por mensaje, en español claro y con los nombres exactos
de los botones. Los comandos van en bloques y los ejecuta él (PowerShell).
ANTES DE TOCAR LA BASE: una lectura en intervenciones/, y la migración
GENERADA desde ese texto vivo. Respaldo antes de cada migración.
ANTES DE PEDIRLE QUE PRUEBE ALGO: push hecho, build-info.json con el commit
nuevo, y que pulse "Actualizar" (a la derecha de la franja rosada) si sale.
AL CERRAR CADA BLOQUE: decirle qué se subió y comprobar la sincronía con GitHub.
NUNCA dart format en bloque.
```
