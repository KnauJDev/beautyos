# HANDOFF Salón y Más — 3 y 4 de octubre de 2026 ("Los pasos 3, 4 y 5 de David", D-314 a D-317)

**Bloque documentado:** decisiones **D-314** a **D-317**, del 03 y el 04 de octubre. Siguen
los pasos del plan del primer cliente real, **David Rojas** (D-308). Quedan hechos y vistos
en pantalla el **4** (*Invitar a volver*), lo nuestro del **3** (su tema y la tarjeta de
WhatsApp de su enlace) y el **5** (el **Dashboard de atenciones**, sin pesos, con su propio
interruptor).

**Estado:** ✅ Todo lo escrito está **aplicado y publicado**: tres migraciones con sus
controles en verde (**242** 8/8, **243** 4/4 y **244** 10/10, este último a la primera) y
una función de Cloudflare Pages. **Todo visto en pantalla** el 03 y el 04-oct (§3).
`flutter analyze` sin avisos · **747 pruebas** · guardián en verde.

> **Actualizado el 07-oct con D-318 (paso 6, los cinco lugares).** El interruptor *Los cinco
> lugares* está aplicado (**control 245** 6/6) y **la app de la dueña quedó escrita y
> publicada, apagada para todos**: nadie ve nada nuevo hasta que el propietario la encienda
> en el Panel (*Novedades*). **Encendida en Éxito el 07-oct.** Al verla, el propietario
> decidió quitar el título y la explicación de **todas las pantallas del salón, en todos
> los salones** (las de la estilista los conservan hasta la entrega 3). Probando la campana
> salieron tres arreglos más, y en *Mi negocio* el filtro también abajo; al terminar, las
> tarjetas de números dos por fila en el celular y *Tu enlace* (ver D-318). **Revisión de
> los cinco lugares terminada en el espejo; a David, el 08-oct en persona.** **780 pruebas.**
> Lo siguiente está en §3 y §7.
**Hallazgos: 82 en total, 68 cerrados o decididos, 14 abiertos** (al 07-oct, con **CN**; los cuenta
`python scripts/verificar_documentos.py`).

**Sincronía, comprobada el 04-oct por la noche:** `main` local igual a GitHub (nada sin
subir ni sin bajar, ningún archivo sin guardar); Cloudflare publicó la última versión de la
app (`ba93326`, confirmada en `build-info.json` y en el `main.dart.js` publicado).

> El HANDOFF anterior está en `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-10-03_D313.md`
> (D-307 a D-313). Lo que de él sigue valiendo está copiado aquí.

---

## 1. Lo que hay que saber si solo se lee una cosa

**David Rojas es el primer cliente real y quiere solo agenda.** Su negocio tiene la caja
apagada desde el Panel: agenda de tres estados (Confirmado → En proceso → Cerrado), toda
cita nace confirmada, y **"Cerrado" es atendida, no cobrada** (D-312). **No se inventan
pagos** (D-314).

**Peluquería Éxito Prueba es su ESPEJO**: tiene apagado lo mismo. Todo se prueba ahí
primero. Cuando algo nuevo le aparecería a David al publicarse (un interruptor que nace
encendido), **se le apaga en el Panel mientras se prueba en el espejo** y se le enciende
después (así se hizo con el Dashboard el 04-oct).

| Decisión | Qué | Estado |
|---|---|---|
| D-314 | **Paso 4, Invitar a volver.** 4A: Clientes sin dinero en los negocios sin caja y el WhatsApp con el nombre del salón y su enlace. 4B: un recordatorio **por servicio** (cada uno con su tiempo de volver; 45 días por defecto del salón), registro de invitaciones, *"Para invitar hoy"* arriba de la Agenda y los filtros *Para invitar* / *No volvieron* en Clientes. Y **no se inventan pagos** | ✅ control 242 en 8/8, visto en el espejo. De ahí salió **CK** (WhatsApp sin el 57), cerrado y visto con un número real |
| D-315 | **Paso 3, el tema "Inspirant"** (barra dorada, títulos negros, el rosa de las flores del local de David), **sexto tema para todos**. El tema propio de tres elecciones, al buzón (**I-22**) | ✅ control 243 en 4/4, elegido en Éxito y visto en la app y en la página pública |
| D-316 | **La tarjeta de WhatsApp de cada salón**: al compartir `salonymas.com/<nombre>` salen el nombre, *"Agenda tu cita en línea · <ciudad>"* y la **portada** (o el logo). Una **función de Cloudflare Pages** (`functions/[slug].js`) que solo responde a los lectores de vistas previas de las redes; a las personas, la página como siempre. Y fuera los emojis 📅 y 👤 de la página pública | ✅ en vivo (comprobado con `curl`, cabeceras de seguridad idénticas) y **visto en un WhatsApp de verdad** el 04-oct |
| D-317 | **Paso 5, el Dashboard de atenciones**: en los negocios sin caja, un Dashboard nuevo que cuenta la historia del negocio en citas, clientas, servicios y equipo, **sin un peso**, con **su propio interruptor** en el Panel (*Finanzas* se queda con Reportes). Diseñado en un prototipo que el propietario aprobó (*"me encantó"*). En el mismo cambio, lo que quedaba del paso 5: Configuración sin comisiones ni numeración, *Semana* entero en el celular y los textos de dinero de Clientes | ✅ control 244 en 10/10, **visto en el espejo en computador y celular**, seis arreglos el mismo día, y **encendido para David el 04-oct por la noche** |
| D-318 | **Paso 6, los cinco lugares**: *Agenda · Clientes · Mi negocio · Mi vitrina · Ajustes*, diseñados con el propietario vista por vista en el prototipo y aprobados. La Agenda abre en su Tablero de siempre, con *Nueva cita*, *Llegó sin cita* y una sola tarjeta de citas; *Mi negocio* con el Dashboard arriba; la campana con lo básico. **Detrás de un interruptor que nace apagado** | ✅ entrega 1 (control 245 en 6/6) y ✅ entrega 2 (la app de la dueña, publicada y **apagada para todos**). ⬜ Encenderla en Éxito y mirarla; ⬜ entrega 3 (*Mi agenda* de la estilista) |
| D-319 | **El enlace se comparte también en TikTok y en papel**: TikTok en Configuración y en la página pública (pedido de David), y el botón *Código QR* en *Tu enlace*, que lo descarga para imprimir. Lectura viva hecha; migración `20261007200000_tiktok_del_salon_d319.sql` y **control 246** escritos | ✅ **Aplicada el 08-oct** (respaldo `Backup_2026-10-08_07-06-39`), **control 246 en 6/6**, y la app publicada después. ✅ TikTok y el QR vistos en Éxito |
| D-320 | **La página pública, rediseñada** con un prototipo aprobado (https://claude.ai/artifact/H4GUdBqnaVu1h3rhzTgGPF): portada que manda, *abierto ahora* en hora de Colombia, botones redondos, el trabajo arriba, servicios por categoría, equipo y reseñas en tarjetas, *Agendar cita* siempre a mano. Sin servidor; cambia la página de **todos** los salones | ✅ Publicada el 08-oct y vista por el propietario en Éxito y en la de David; el pie se queda. Portada *Champán* y emblema como logo, elegidos por David (los sube él) |
| D-321 | **Las redes se escriben como usuario o enlace**: David había puesto los *nombres* de sus cuentas en Facebook y TikTok, y los botones llevaban a cuentas inexistentes. Configuración avisa y no guarda un nombre con espacios; la página no enseña un botón roto; el Panel ve el TikTok | ✅ App publicada. ✅ Migración aplicada (respaldo `Backup_2026-10-08_14-38-32`), **control 247 en 4/4**. ⬜ David: pegar el enlace de su Facebook y de su TikTok |
| D-322 | **Elegir el servicio por cuadritos** (reserva de la clienta y Nueva cita / Llegó sin cita) y, en la página pública, **"Pregunta por WhatsApp"** para los servicios sin estilista, que le avisa al salón a cuál le falta. Pedidos de David del 08-oct, prototipo aprobado (*"están espectaculares"*). Sin servidor | ✅ App publicada el 08-oct; probada en el navegador con los datos de David (3 cuadritos, el servicio y su precio). ⬜ El propietario: probar Nueva cita en Éxito. ⬜ David: asignar estilistas en *Estilistas* y corregir sus categorías repetidas |


**Hallazgos de estos dos días:** **CK** (cerrado: WhatsApp sin el 57) · **CL** (abierto: la
cabecera dice *"BeautyOS"* bajo el nombre del salón, en pantalla ancha; qué poner lo
decide el propietario) · **CM** (abierto: *"Precio medio $24333"* sin punto de miles en
Servicios, Gastos y Compras; sin decisión de producto).

**Respaldos del propietario:** `Backup_2026-10-03_15-45-21`, `Backup_2026-10-03_19-15-32`
y `Backup_2026-10-04_19-32-49`.

---

## 2. Lo que se aprendió (y quedó escrito para no repetirlo)

**De estos dos días:**

1. **Para una pantalla nueva, primero un prototipo.** El Dashboard se dibujó con datos de
   ejemplo y el propietario lo aprobó antes de tocar la base
   (https://claude.ai/artifact/Ptnrpy3N23NbSATn2n3BP3). Lo mismo los cinco lugares (D-304).
2. **Dibujar la pantalla en una prueba caza lo que el análisis no ve.** La prueba que pinta
   el tablero a lo ancho de un celular y de un computador encontró que la línea de
   tendencia reventaba (`reduce(math.max)` sobre una `List<int>` declarada de `num`).
   A David le habría salido esa tarjeta en rojo.
3. **La regla 10 otra vez: no suponer columnas.** La lectura del paso 5 falló por suponer
   `reviews.status`; la columna es `moderation_status`, y la propia lectura ya la había
   traído en su sección de columnas.
4. **El Postgres del computador trae solo el cliente** (`psql`, `pg_dump`): no hay servidor
   local para probar SQL. Las migraciones y los controles se revisan a mano y los corre el
   propietario.
5. **WhatsApp arma la tarjeta en el celular de quien comparte**, y tarda unos segundos: hay
   que pegar el enlace con `https://` y esperar. Guarda la tarjeta por dirección: para
   probar de nuevo, agregar `?v=2` al final.
6. **Un interruptor que nace encendido le cambia la app a David al publicarse.** Se le apaga
   en el Panel mientras se prueba en el espejo.
7. **Los datos personales del propietario no se escriben completos en los documentos.** En
   la nota de CK quedó su celular; se tapó el 03-oct, pero sigue en el historial de git
   (borrarlo de ahí exige reescribir la historia: decisión suya, no tomada).

**Del 07-oct:**

- **Lo que va detrás de un interruptor también puede cambiar cosas para todos.** Antes de
  subir se lee el diff buscando qué cambia con el interruptor apagado. Así salió un
  subtítulo cambiado sin pedirlo (*clientas* → *clientes*), que se devolvió.
- **En modo automático, la revisión de seguridad de cada acción puede quedarse sin
  respuesta** y bloquear toda escritura (pasó el 07-oct). No es GitHub ni el proyecto: el
  propietario cambia el modo a *Preguntar* y se sigue aprobando cada acción.

**Del bloque anterior, siguen valiendo:**

8. **Apagar algo también apaga lo que colgaba de ello** (sin *Tickets & Caja*, la agenda se
   quedó sin botones: D-312).
9. **La regla 10 vale también para las políticas de seguridad** (D-313).
10. **Aquí no se formatea en bloque** (`dart format lib/` tocó 112 archivos ajenos).
11. **Después de un `git checkout`, los archivos vuelven con CRLF** y algunas pruebas fallan
    en local (`MAPA_TECNICO` §7).
12. **El aviso *"Hay una versión nueva"* trae el enlace *Actualizar* pequeño, a la derecha.**
13. **Una búsqueda cortada da una cifra falsa.** Afirmar exige prueba (regla 25).
14. **Al cerrar cada bloque, decirle al propietario qué se subió** y comprobar la sincronía.
15. **Probar en pantalla encuentra lo que los controles no ven.**
16. **Para saber si Cloudflare publicó, se mira `build-info.json`** y se busca en el
    `main.dart.js` publicado un texto nuevo (con tildes escritas como `\xe1`).
17. **Con HSTS activo, Cloudflare no se toca a ciegas** (D-294).
18. **Al guiar al propietario por una pantalla, un paso por mensaje.**

---

## 3. Lo que tienes que mirar en pantalla (regla 21)

0. 🔲 **07-oct: los cinco lugares en el espejo.** ✅ Encendido en Éxito; vistos la Agenda
   (celular y computador), Clientes, Servicios con su *"← Ajustes"*, la tarjeta *Para
   invitar hoy*, la campana y el número de *Clientes*. De ahí salieron tres arreglos (el
   filtro de la campana, los números que no se enteraban de un cambio y los filtros
   cortados), ✅ **vistos**. ✅ *Mi negocio* en el celular, con el filtro también abajo,
   junto a *Ver el Dashboard completo*. ✅ *Mi vitrina*. **Revisión terminada.** De ella
   salieron, **sin mirar todavía en pantalla**: las tarjetas de números dos por fila en el
   celular y la tarjeta única *Tu enlace* en Configuración y *Mi vitrina*, sin *Modificar
   enlace* (I-24). **A David, el 08-oct en persona** (decisión del propietario). Lo que se miró: en el computador y en el celular: el menú (lateral / barra de abajo, sin
   *Más*), la Agenda con *Nueva cita*, *Llegó sin cita* y la tarjeta de citas, *Mi negocio*
   (filtrar un servicio y ver crecer las barras sin que la página suba), *Mi vitrina*,
   *Ajustes*, el *"← volver"* y la campana. **Solo después, a David.** Apagarlo devuelve
   la app de antes.
1. 🔲 **05-oct: las capturas de David** con su Dashboard encendido (el propietario las manda
   a primera hora). Mirar con lupa lo mismo que en el espejo: la historia, los números
   contra sus citas reales, y el celular.
2. ✅ **04-oct: el Dashboard en el espejo**, computador y celular. Los seis arreglos que
   salieron de ahí están publicados (`ba93326`); no se volvieron a mirar en pantalla, pero
   los vigilan dos pruebas nuevas.
3. ✅ **04-oct: la tarjeta de WhatsApp de David** en un WhatsApp de verdad.
4. ✅ **03-oct: Inspirant** en la app y en la página pública del espejo.
5. 🔲 **Que David elija Inspirant** en *Configuración → Colores de tu negocio → Guardar tema*
   (solo el dueño del salón puede) y suba las **fotos de su equipo** (*Estilistas → lápiz →
   Subir foto*). El propietario tiene el mensaje para enviárselo (se le dio el 04-oct); no
   consta que lo haya enviado.

---

## 4. Las decisiones que siguen siendo tuyas

| | Qué | Estado |
|---|---|---|
| **c** | **Cuándo pasar a Supabase Pro** | El asistente aconsejó esperar (no acelera la app) y seguir con el respaldo semanal |
| **d** | **I-13**: acceso de lectura a la base para el asistente | Hoy cada lectura es un comando tuyo con contraseña |
| **h** | **Ñ**: quitar los tipos de foto *Final* y *Portafolio* | Decidido: sí. Se hace con la reestructura (9.25, paso 6) |
| **i** | **BS**: revisar juntos el SMTP de Auth en Supabase | Abierto |
| **k** | **9.26 (Meta)** | Esperar la matrícula mercantil o al contador |
| **l** | **9.33**: dónde guardas la bitácora de los socios y la respuesta sobre factura | Abierto. **No va al repositorio** |
| **m** | **9.16** (contador), **9.20** (abogado), **9.24** (entrevistas) | El 9.24 sigue bloqueando el turno E |
| **o** | **Las redes:** ¿TikTok o estados de WhatsApp? ¿se hizo el 9.23? | Sin respuesta |
| **p** | **CH**: que Cloudflare no publique cuando solo cambian documentos (*Build watch paths*) | Del panel de Cloudflare: lo decides tú. Cuidado: desde D-316 hay una carpeta `functions/` que **sí** debe publicarse |
| **q** | ~~**Juntar las dos tarjetas de enlaces de Configuración**~~ | ✅ **07-oct: *Tu enlace***, una sola, y sin *Modificar enlace* (cambiarlo, desde el Panel: **I-24**) |
| **s** | ~~**CL**: qué poner bajo el nombre del salón en la cabecera~~ | ✅ **06-oct: nada** (marca blanca). Hecho |
| **t** | **El celular del propietario en el historial de git** (nota de CK, 03-oct) | Tapado en los documentos; borrarlo del historial exige reescribirlo. Sin decidir |

**Ya decidido:** el Dashboard tiene su propio interruptor (pregunta **r**, cerrada por
D-317); la tarjeta de WhatsApp muestra la portada y, si no hay, el logo (WhatsApp muestra
una sola imagen); el tema propio de cuatro colores no, uno de tres elecciones con el
contraste corregido, en el buzón (I-22).

---

## 5. Lo que quedó a medias

### El plan de David (D-308)

| Paso | Qué | Estado |
|---|---|---|
| 0 | Que su equipo pueda entrar (CF) | ✅ D-309. **Falta que su equipo entre** por *Ingresar* pidiendo un código nuevo |
| 1 | Interruptores por negocio | ✅ D-310. A David: apagados *Caja y cobros, Finanzas* (Reportes)*, Inventario, Comisiones, Blog*; encendidos *Dashboard* (desde el 04-oct), *Fotos* y *Reseñas* |
| 2 | Agenda de tres estados | ✅ D-312 |
| 3 | Su tema y su página | ✅ lo nuestro (D-315, D-316, paso 9.60). **Falta de David:** elegir Inspirant y subir las fotos de su equipo (§3.5) |
| 4 | Invitar a volver | ✅ D-314 (paso 9.59). Corte de Cabello y Pedicure Basico, de vuelta en vacío (45 días del salón). Pedicure se puso un rato en 1 día el 07-oct para probar la campana, y **el propietario lo devolvió a vacío** el mismo día |
| 5 | Agenda sin cobro y Dashboard de atenciones | ✅ D-317 (paso 9.61). Falta solo mirar las capturas de David (§3.1) |
| 6 | **Los cinco lugares** (9.25) | **07-oct, en diseño. Decidido por el propietario:** los nombres son **Hoy · Clientes · Mi negocio · Mi vitrina · Ajustes** ("Clientes" sirve también a barberías; "Mi negocio" le sirve a David, sin dinero); **el Dashboard va arriba de *Mi negocio*** y debajo lo que el salón tenga encendido (Reportes, Gastos, Compras, Inventario, Comisiones); y **la campana de avisos se construye en este paso**, con lo básico (citas de hoy por confirmar, clientas para invitar hoy, inventario bajo, sede por vencer). **Prototipo actualizado el 07-oct** en el mismo enlace de D-304 (https://claude.ai/artifact/1ESsefBVb3dhH6iSYEgqPb, versión 3): los nombres nuevos, *Mi negocio* con el Dashboard arriba (sin caja, el de atenciones; con caja, el de pesos y debajo Reportes, Gastos, Compras, Inventario y Comisiones), la campana con lo básico, *Clientes* con los filtros *Para invitar* y *No volvieron*, la agenda de la estilista **en tarjetas con Día / Semana / Mes**, y una franja solo del prototipo para alternar **con caja / sin caja (como David)**, **Morado / Inspirant** y **dueña / estilista**. Sin caja, la estilista tiene 3 lugares (sin *Mi plata*). **07-oct, al revisarlo, el propietario corrigió:** la agenda que ya existe le gusta porque deja planear (una fecha, el día siguiente, la semana, el mes) y el prototipo la había reducido a *hoy*. **Decidido:** el primer lugar se llama **Agenda** (no *Hoy*) y abre en **su Tablero de Agenda de siempre**, con Día / Semana / Mes, *Hoy*, flechas y calendario, y arriba *Nueva cita*, *Llegó sin cita* y las tarjetas del día; y la estilista conserva **Mi agenda** (no *Mi día*), que gana fecha, día siguiente, semana y mes, en tarjetas. Nombres: **Agenda · Clientes · Mi negocio · Mi vitrina · Ajustes**; estilista: **Mi agenda · Mis fotos · Mis reseñas** (y *Mi plata* con caja). **Lo que ya funciona no se reduce** (regla 25). **Revisión vista por vista (07-oct), lo acordado:** **(1) Agenda:** las tarjetas *Atendidas* y *Citas de hoy* se repetían: una sola tarjeta **"Citas de hoy 9 · atendidas 3 · pendientes 5 · canceladas o no asistieron 1"** (con caja, *Caja de hoy* al lado); **sin tarjeta de Equipo**, porque la app no sabe el horario de cada estilista (idea **I-23** en el buzón). **(2) Mi negocio:** la historia, citas, clientes, asistencia y horas se quedan; se agregan **dos gráficos que se filtran entre sí**, *¿Qué piden?* (servicios) y *¿Quién lo presta?* (estilistas), como en el Dashboard de D-317 (no toca el servidor). **(3) Mi negocio, ronda 2:** faltaba **elegir el periodo**: lleva el mismo filtro del Dashboard real (*Hoy, Esta semana, Este mes, Este año, Últimos 7 / 30 días, Últimos meses* y **Otras fechas** para un rango); y al filtrar las gráficas **la página no debe volver arriba** y **las barras deben crecer con una animación**, para que el cambio se note (el propietario: *"no se perciben los cambios… que es lo que atrae al cliente final"*). **Para construir:** el Dashboard real ya conserva la posición al filtrar, pero sus barras cambian de golpe: animarlas. Prototipo versión 6. ✅ **Revisión terminada y aprobada el 07-oct (D-318):** Clientes, Mi vitrina, Ajustes, la campana y la app de la estilista, bien. **Se construye en tres entregas, detrás del interruptor *Los cinco lugares* que nace apagado:** (1) el interruptor (migración `20261007100000_cinco_lugares_interruptor_d318.sql`, control 245) ✅ **aplicado el 07-oct, control 245 en 6/6** (respaldo `Backup_2026-10-07_12-40-22`), (2) la app de la dueña ✅ **escrita y publicada el 07-oct, apagada para todos** (770 pruebas; de paso se cerró el hallazgo **CN**, los atajos del Dashboard que abrían otro módulo), (3) *Mi agenda* de la estilista en tarjetas. Se prueba encendiéndolo primero en Éxito (§3.0). **Lo siguiente.** Con él: la agenda de la estilista en tarjetas, con semana y mes (hoy es una tabla ancha); sus flechas de fecha descuadradas; juntar las tarjetas de enlaces de Configuración (**q**); quitar los tipos de foto *Final* y *Portafolio* (**h**). El prototipo de D-304 está en https://claude.ai/artifact/1ESsefBVb3dhH6iSYEgqPb. **Antes de proponer, preguntar** (regla 25) |

### Otros

1. **Multisede:** la dirección con nombre por sede (`salonymas.com/<salon>/<sede>`), y el
   riesgo de que un salón cambie su dirección y rompa los enlaces ya repartidos (D-313).
2. ~~**CG**: borrar el aviso de términos al marcar la casilla.~~ ✅ 06-oct.
3. ~~**La lista del Panel no se refresca** al mover un interruptor.~~ ✅ 06-oct: se
   refresca sola, sin que la ficha abierta parpadee.
4. **AK**: seis diálogos de `tickets_page.dart` que se cierran antes de guardar (9.13).
5. **BR y BS**: en el buzón, sin fase.
6. **Señalado, no tocado:** `private.beautyos_resolve_consent_client` tiene `EXECUTE` para
   `PUBLIC` (no abre nada; no es el patrón, D-286).
7. **AI**: el repositorio no tiene el esquema entero (`get_my_branch_context_v2`, las
   tablas de citas). Volcarlo va en el turno E.
8. ~~**CM**: el punto de miles en *Precio medio*, Gastos y Compras.~~ ✅ 06-oct.
9. **Visto una vez, sin confirmar:** justo después de guardar un tema, la cabecera y el menú
   siguieron con el color anterior hasta cambiar de pantalla. Falta verlo otra vez.
10. **La portada de Éxito pesa 474 KB**: WhatsApp podría no mostrarla. La de David (43 KB)
    sí sale. Si un salón sube una portada pesada, su tarjeta puede salir sin imagen.

---

## 6. Lo que NO hay que hacer

- **NO borrar la Peluquería Éxito Prueba.** Es el banco de pruebas y el **espejo de David**.
- **NO probar cobros ni caja en Éxito mientras sea espejo.**
- **NO apagarle ni cambiarle nada a David sin probarlo antes en el espejo.** Si una
  publicación le cambiaría la app, apagárselo en el Panel mientras se prueba.
- 🔴 **NO pagar nada** sin decisión explícita del propietario.
- **NO inventar pagos** en un negocio sin caja (D-314).
- **NO pactar una sede por debajo de $10.000** (D-265).
- **NO tratar *Cancelada* como rechazo en la base** (D-297).
- **NO reescribir una función de la base, ni suponer una columna o una política de
  seguridad, sin su lectura viva** (regla 10; D-313, D-317).
- **NO formatear en bloque** (`dart format lib/`).
- **NO armar a mano la respuesta de `functions/[slug].js` para las personas**: debe salir de
  `env.ASSETS.fetch`, que aplica `_headers` (la seguridad) y `_redirects` (D-316).
- **NO poner nunca una llave secreta en `functions/`**: solo la publicable, la de `lib/main.dart`.
- **NO escribir completos los datos personales del propietario** (celular, nombre) en los
  documentos ni en los mensajes de commit.
- **NO volver a poner una casilla de "la clienta autorizó"** en ninguna pantalla del salón.
- **NO pegar en el chat el enlace `?autorizar=` de una clienta real**: abre sin PIN.
- **NO meter la bitácora de los socios en el repositorio** (Ley 1581, D-295).
- **Con HSTS activo, NO** poner *DNS only*, pausar Cloudflare, cambiar los *nameservers*
  ni quitar el certificado (D-294).
- **NO contar hallazgos a mano**: `python scripts/verificar_documentos.py`.
- **NO publicar, responder, borrar ni cambiar nada en las redes sin el sí del
  propietario**, pieza por pieza (D-305).
- **NO repetir *"Multi-sede… sin pagar de más"*** en piezas nuevas (D-189).

---

## 7. Por dónde seguir

**Pedidos de David del 08-oct** (pasos **9.62** y **9.63** del Plan Maestro):
1. **Cuándo vuelve cada clienta — LO SIGUIENTE (9.63)** (https://claude.ai/artifact/N48aApd2qmN17Fxc5kHTne): al cerrar
   una cita, preguntar en cuántos días invitar a volver a **esa clienta** para cada servicio,
   ya lleno (su número si ya tiene; si no, el del servicio o los 45 del salón), y
   **recordarlo** en su ficha. Decidido por el propietario: se recuerda; sale siempre ya
   lleno; lo ponen dueño, recepción **y estilista** (al terminar en *Mi agenda*); se puede
   cambiar en la ficha de Clientes. La llave es la ficha de la clienta (un celular, una
   clienta por salón, D-249). **Lleva servidor** (lectura viva, migración, control): un número
   por clienta y servicio, y que *Para invitar hoy* lo use. **Añadido el 08-oct a pedido del
   propietario:** cada servicio trae un interruptor *"Invitar a volver"*; apagado, ese servicio
   no la invita esta vez **y su número no se borra**; cuando vuelva a hacérselo, se pregunta
   otra vez con el interruptor prendido. En la ficha dice *"esta vez no se invita"*. Prototipo
   versión 2. En la base, además del número, una marca de *"esta vez no"* que deja de
   valer sola en el próximo cierre de ese servicio. **08-oct: lectura viva corrida;
   migración `20261008200000_cuando_vuelve_cada_clienta_9_63.sql` y control 248 escritos
   (D-323).** ✅ **Aplicada** (respaldo `Backup_2026-10-08_17-47-03`), **control 248 en 8/8**.
   ✅ **App escrita** (la hoja al cerrar en la Agenda y en *Mi agenda*; la tarjeta en la ficha
   de Clientes; 841 pruebas). ✅ También al *Finalizar* de Tickets y Caja (decidido el
   08-oct). ✅ **Publicada el 08-oct, sin interruptor** (el propietario: *"súbela ya"*).
   ⬜ Probarla en Éxito: cerrar una cita, la hoja, y la tarjeta en la ficha.
2. ✅ **Elegir servicio por cuadritos — HECHO (D-322, 9.62)** (https://claude.ai/artifact/2NAFZNYbz3fqxwAX6H7qaQ):
   en la reserva en línea **y** en *Nueva cita* / *Llegó sin cita*. Publicado el 08-oct.
3. **Por qué solo salían 3 servicios para agendar:** de sus 28, solo 3 tienen estilista
   asignado (la reserva solo ofrece lo que alguien hace). **David los asigna en *Estilistas***
   (decisión del propietario: no se agrega en *Servicios*). En la página pública, **los
   servicios sin estilista se ven con "Pregunta por WhatsApp"** en vez de *Reservar* (y así
   sirven de control) — ✅ **hecho con D-322**. **Las categorías repetidas las corrige David**
   (no la app: los cuadritos juntan *Peluquería* y *peluquería*, pero *peluqueria* sin tilde
   sale aparte).

**Lo inmediato (08-oct): la visita a David, en persona.** Con él: (1) encenderle *Los cinco
lugares* (Panel → Inspirant → *Novedades*) y enseñárselos; (2) que elija el tema
**Inspirant** (*Configuración → Colores de tu negocio*); (3) que suba como logo **el emblema
*DM*** que se le preparó (recortado de su mismo logo, sin cambios) y, si quiere, el logo
completo como portada; (4) las fotos de su equipo; (5) sus categorías de servicios repetidas
(*peluquería* / *peluqueria*): si las corrige él o si la página las junta (lo dirá el
propietario); (6) las capturas de su Dashboard y que su equipo entre. La página pública
nueva (D-320) ya la vio el propietario en Éxito y en la de David; **el pie se queda**. **En Éxito quedaron redes de prueba** (un TikTok
inventado, Instagram y Facebook de prueba): vaciarlas al terminar, para que su página no
tenga botones a perfiles que no existen. **El 08-oct, en persona con David**, encenderle *Los cinco lugares* en
el Panel (*Novedades*) y enseñárselo. Mientras tanto, **la entrega 3**: *Mi agenda* de la
estilista en tarjetas, con fecha (*Hoy*, flechas, calendario) y *Día / Semana / Mes*
(`my_stylist_agenda_page.dart`; *Mi plata* solo con caja). Sus pantallas conservan el
título hasta que el propietario decida.

**Pendiente de David** (no se vio con él el 06-oct): las capturas de su Dashboard (§3.1),
elegir Inspirant y subir las fotos de su equipo (§3.5), y que su equipo entre (paso 0).

**El orden general** (PLAN_MAESTRO §5): los pasos de David van primero (D-308). Después
siguen los turnos B (**9.20** y **9.16**, del propietario), D (**9.26** espera la decisión
**k**; **9.24** es suyo) y E (9.13, 9.14 e I-19), bloqueado por el **9.24**.

**Las redes van en su propio chat** (D-305, D-306, paso 9.57). **Los detalles personales del
propietario no se escriben en el repositorio.**

---

## 8. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-314 a D-317).

Antes de nada: la REGLA 25 del PLAN_MAESTRO §8. Afirmar exige prueba; lo
aprobado no se cambia sin avisar; el producto se pregunta aunque haya
permiso general; lo que corre el propietario se copia de algo que ya
funcionó; un letrero rancio se busca por lo que llama.

Y: python scripts/verificar_documentos.py (cuenta los hallazgos por ti).

SI ESTE CHAT ES DE REDES: lee 02_operacion/REDES_SOCIALES.md, D-305, D-306 y
el paso 9.57. Nada se publica sin su sí, pieza por pieza.

DÓNDE ESTAMOS
El primer cliente real, David Rojas, quiere solo agenda. De su plan (D-308)
están hechos y vistos los pasos 0 a 5: interruptores por negocio (D-310),
agenda de tres estados (D-312), su tema Inspirant y la tarjeta de WhatsApp
de su enlace (D-315, D-316), Invitar a volver (D-314) y el Dashboard de
atenciones sin pesos, con su propio interruptor (D-317). Peluquería Éxito
Prueba es su ESPEJO: todo se prueba ahí primero. Paso 6 (D-318, los cinco
lugares): el interruptor y la app de la dueña están publicados y APAGADOS
para todos; se encienden en el Panel, sección Novedades.

LO PRIMERO
D-322 (servicio por cuadritos y "Pregunta por WhatsApp") publicada el 08-oct.
Lo siguiente es "Cuándo vuelve cada clienta" (paso 9.63): prototipo con el
interruptor "Invitar a volver" esperando el sí del propietario; después,
lectura viva de get_return_invitations y del cierre de citas, migración y
control. D-319 (TikTok y el código QR): aplicada el 08-oct, control 246 en
6/6, app publicada y vista en Éxito. Los cinco lugares ya se revisaron en Éxito. El 08-oct el propietario se los
enciende a David en persona. Mientras tanto, la entrega 3 (Mi agenda de la
estilista en tarjetas). Pendientes de David: sus capturas del Dashboard,
Inspirant, fotos.

CÓMO SE TRABAJA CON ÉL
Paso a paso, un paso por mensaje, en español claro y con los nombres exactos
de los botones. Los comandos van en bloques y los ejecuta él (PowerShell).
ANTES DE TOCAR LA BASE: una lectura en intervenciones/, y la migración
GENERADA desde ese texto vivo (o, si solo agrega, copiando el patrón vivo).
Respaldo antes de cada migración. Una pantalla nueva: primero un prototipo.
ANTES DE PEDIRLE QUE PRUEBE ALGO: push hecho, build-info.json con el commit
nuevo, y que pulse "Actualizar" (a la derecha de la franja rosada) si sale.
AL CERRAR CADA BLOQUE: decirle qué se subió y comprobar la sincronía con GitHub.
NUNCA dart format en bloque.
```

---

## 9. Pruebas al cerrar

> **08-oct, con D-322: 827 pruebas, todas en verde** (`flutter test` completo), `flutter
> analyze` sin avisos y `flutter build web` compila. 12 nuevas en
> `elegir_servicio_d322_test.dart`; dos viejas ajustadas porque buscaban la lista desplegable
> del servicio (`create_appointment_walkin_test.dart` y una línea de
> `cinco_lugares_d318_test.dart`).

**780 pruebas, todas en verde**, en la corrida completa del 07-oct con la entrega 2 de
D-318 y todo lo que salió de la revisión en el espejo (`flutter test`, 5 min 26 s), y
`flutter build web` compila. 27 son de los cinco lugares (`cinco_lugares_d318_test.dart`); tres viejas se
actualizaron porque cuentan piezas que ahora aparecen una vez más (Mi negocio y Mi vitrina
reciben las mismas que la Agenda y Configuración; el Panel avisa también desde
*Novedades*), y una porque buscaba el título *Tablero de Agenda*, que ya no se pinta.
