# Recorrido completo de un cliente — del registro al borrado

> **Para qué sirve esto.** Recorrer de punta a punta, con personas y correos
> reales, todo lo que hará un salón: registrarse, ser aprobado, poner sus
> datos, invitar a su equipo, atender a una clienta y cobrarle. Y al final,
> borrarlo sin dejar rastro.
>
> **Se hace una vez antes de invitar a los diez socios de diseño, y otra vez
> cada vez que cambie algo del camino de entrada.**

---

## Por qué existe este documento

El **17 de septiembre de 2026** se descubrió que **nadie podía registrarse
desde el 1 de septiembre**: `register_tenant` pedía un plan cuyo código había
sido jubilado dieciséis días antes (D-245).

No lo encontró ninguna de las 404 pruebas ni ninguno de los 15 controles. Lo
encontró **una persona invitada a probar la aplicación**, y llegó por captura
de pantalla.

> **Un camino que nadie recorre no avisa de que está roto: avisa el primero
> que lo recorre, y suele ser un cliente.**

Había controles del cobro, de las sedes, de los precios y de los permisos. Del
camino por el que entran todos los clientes, ninguno. Este documento es la
otra mitad del arreglo: el control 214 vigila la función, y esto vigila **el
recorrido de una persona**, que es donde viven los fallos que ninguna función
ve por separado.

---

## El reparto

| Papel | Nombre | Correo / teléfono | Estado |
|---|---|---|---|
| **Propietaria** | Alicia Propietaria | `elboga008@gmail.com` | ✅ cuenta creada y dentro |
| **Negocio** | Peluquería Éxito Prueba | — | ✅ `TRIALING`, vence 24-sep |
| **Sede 1** | *(se crea sola al registrarse)* | `elboga009@gmail.com` | ✅ con sus datos cargados |
| **Administradora** | Segunda Alicia Administradora | `elboga012@gmail.com` | ✅ aceptó y entró |
| **Asistente** | Carolina Asistente | `elboga011@gmail.com` | ✅ aceptó y entró |
| **Estilista** | Erick Estilista *(en el catálogo)* · Erick Estilista Rodriguez *(en su cuenta)* | `elboga013@gmail.com` | ✅ aceptó y entró — **con dos nombres, hallazgo AN** |
| **Clienta del salón** | David Alonso Cliente 1 | WhatsApp `3506815629` | ⏳ **pendiente** |

> **El correo del reparto cambió sobre la marcha** y aquí queda el real, no el
> planeado. `elboga021` a `elboga025` **no se usaron**; se usaron 008, 009, 011,
> 012 y 013. Un guion que dice otros correos que los de la base no sirve para
> retomar nada.

> Los tres roles que acepta una invitación son exactamente **`admin`**,
> **`assistant`** y **`stylist`**. No hay más.

---

## Antes de empezar

- [ ] **Mirar los registros de Auth** (hallazgo AH). Supabase → **Logs →
      Auth**, los `verify` del último invitado. **Si hay dos por cada enlace**,
      uno desde una IP de Google, está confirmado que **el buzón gasta el
      enlace antes que la persona**.
      *(Hasta el 18-sep esta casilla decía "revisar la caducidad" y mandaba a
      **Authentication → Email**. **Estaba mal:** el enlace no caduca por
      tiempo — falló a los dos minutos — y subir ese plazo no arregla nada.)*
- [ ] Tener claro que **un enlace fallido no avisa** (**AM**): el invitado ve
      una pantalla de acceso normal. Si alguien dice "no pude entrar", **mirar
      su barra de direcciones** antes que nada.
- [ ] Tener a mano las bandejas de los cinco correos.
- [ ] **Ctrl+F5** en `salonymas.com` para no estar probando una versión vieja.

---

## El recorrido

En cada paso: **lo que haces**, **lo que debe pasar** y **qué avisar si no**.

### 1. El propietario se registra

Entra a `salonymas.com` **en ventana de incógnito** con `elboga008@gmail.com` y regístrate como negocio
nuevo: **Peluquería Éxito Prueba**.

- **Debe pasar:** llega el correo de confirmación, y tras pulsarlo aparece el
  formulario *"Cuéntanos sobre tu negocio"*. Al enviarlo, queda en espera.
- **Avisar si:** sale *"No hay un plan disponible para registrar la
  solicitud"*. **Eso sería D-245 otra vez y se para todo.**
- **Avisar también si:** el enlace del correo dice *"invalid or has expired"*
  — **mira la barra de direcciones aunque consigas entrar**, porque ahí sale
  y en pantalla no (**AH** y **AM**). Es lo que hay que resolver antes de los
  diez socios.

### 2. Se crea su primera sede sola

No hay nada que hacer: se comprueba en el paso siguiente.

- **Debe pasar:** el negocio nace con **exactamente una sede**, y es la
  principal (D-239).

### 3. Tú lo apruebas desde el Panel

Panel de Plataforma → filtro **Por Aprobar** → *Aprobar Negocio*.

- **Debe pasar:** pasa a **EN PRUEBA** con sus 21 días, y en su tarjeta de la
  lista aparece `1 sede · 1 en prueba` (D-244).

### 4. **Alicia** pone los datos de su sede, desde su propia Configuración

> **Este orden importa y se corrigió el 17-sep.** Antes este paso decía que
> los cargaba el dueño de plataforma desde su Panel, y eso enseña lo
> contrario de lo que debe pasar: **el salón carga sus propios datos**. La
> puerta del Panel (D-241) es la **puerta de servicio**, para cuando el
> cliente llame y no pueda. La puerta principal es la del salón (D-242).

Entra como `elboga008@gmail.com` → **Configuración → Datos de esta sede** →
**Editar**. Correo de la sede `elboga009@gmail.com` y una dirección.

- **Debe pasar:** se guarda y se ve en la tarjeta.
- **Y fíjate en que** *"Datos del negocio"* **ya no tiene dirección**: se mudó
  a la sede, porque antes escribía siempre en la sede principal (hallazgo AF).
- **Prueba a propósito:** un correo **sin arroba**. Debe rechazarlo, y el
  mensaje del servidor debe llegar a la pantalla.

### 5. Y tú lo ves desde tu Panel — la puerta de servicio

En su ficha, pestaña de la sede. Debe salir **lo mismo que escribió ella**.

- **Debe pasar:** dos puertas, un solo dato (D-241 y D-242 escriben las mismas
  siete columnas).
- Prueba también el botón **Datos** desde tu lado: es lo que harás el día que
  un cliente te llame porque no encuentra dónde cambiar su dirección.

### 6. Invita al administrador

Como propietaria → **Usuarios → invitar** a `elboga012@gmail.com`, rol
**administrador**.

- **Debe pasar:** se crea la invitación **y llega el correo**.
- **Avisar si:** la invitación aparece en la lista pero **el correo no llega**.
  Ese es el eslabón que más sospecho de todo el recorrido.

### 7. La administradora acepta

Abre `elboga012@gmail.com`, pulsa el enlace y crea su cuenta.

- **Debe pasar:** entra y ve la sede. **No debe ver el Panel de Plataforma.**

### 8. Invita a la asistente

Igual, con `elboga011@gmail.com` y rol **asistente**. *(El guion decía `024`; se usó `011`.)*

- **Debe pasar:** lo mismo que en 6 y 7.
- **Y comprueba:** Carolina **no** debe poder invitar a nadie ni ver
  Configuración.

### 9. Crea al estilista en el catálogo **antes** de invitarlo

**Estilistas → nuevo** → *Erick Santiago Estilista*.

> **Este orden importa.** La regla "un estilista, una cuenta" exige que el
> estilista exista en el catálogo para poder enlazarlo a su invitación. Al
> revés no se puede.

- **Debe pasar:** el formulario pide **cuatro cosas** — nombre, teléfono,
  especialidad y biografía — y solo el nombre es obligatorio.
- **Y fíjate en lo que NO pide: dinero.** Ninguna casilla de comisión. Eso
  parece bueno y es lo contrario: el estilista **nace heredando el 40% del
  negocio** que nadie confirmó nunca. Es **AJ otra vez, ahora por persona**.
- **Esta ventana sí está bien hecha** (no tiene AK): con el nombre vacío
  rechaza **sin cerrarse y sin borrar lo escrito**. Sirve de modelo para
  arreglar las cuatro que sí lo pierden.
- **La foto solo se sube al editar**, no al crear. Es correcto: necesita que el
  estilista ya exista.

### 10. Invítalo

**Usuarios → invitar** a `elboga013@gmail.com`, rol **estilista**, enlazado a
Erick. *(El guion decía `025`; se usó `013`.)*

- **Debe pasar:** al aceptar, Erick ve **solo lo suyo**: **cuatro** entradas
  — Mi agenda, Mis fotos, Mis reseñas y Mi panel financiero — y ninguna más.
  *"Mi panel financiero" es suyo*, sus comisiones: no es el dinero del salón.
- **Al unirse le piden su nombre otra vez.** Lo que escriba **no** pisa al del
  catálogo: quedan los dos (**AN**). Si escribe uno distinto, la clienta
  seguirá viendo el del catálogo.
- **Avisar si** la dirección del navegador trae `error_code=otp_expired`
  **aunque consigas entrar**: es **AH**, y la aplicación **no lo dice**
  (**AM**). Se entra igual escribiendo la contraseña recién creada.

### 11. La clienta

**Clientes → Nuevo cliente** → *David Alonso Cliente 1*, WhatsApp `3506815629`.

- **Prueba a propósito, y cuesta veinte segundos:** créalo **dos veces igual**.
  Es lo que pasa cuando dos personas atienden el mismo mostrador.
- **Hoy lo permite sin avisar** (**AO**), y **no hay forma de borrar** el
  sobrante: solo apagar *Cliente activo*, que lo manda al final de la lista
  pero no lo quita. El daño no es la fila repetida: **parte en dos el
  historial de valor** y esa clienta ya no llega a VIP.

### 11b. El catálogo: un servicio, y dárselo a Erick

> **Este paso faltaba, y sin él el 12 no se puede hacer.** Se añadió el 18-sep
> al comprobar en `tickets_page.dart` que *Nueva Cita* **construye su lista de
> estilistas a partir del servicio elegido**: si no hay servicios, o el
> servicio no está vinculado a Erick, el desplegable sale vacío. El guion daba
> por hecho un catálogo que ningún paso creaba.

1. **Servicios → nuevo.** Uno cualquiera, con su precio y su duración.
2. **Estilistas → en la tarjeta de Erick, *Gestionar servicios*** → marca ese
   servicio.

- **Debe pasar:** la tarjeta de Erick deja de decir *"Sin servicios asignados"*
  y el contador **Servicios vinculados** sube de 0.

### 12. Una cita, y cobrarla

> **Este paso se reescribió el 18-sep: le faltaba decir QUIÉN hace cada
> tramo, y sin eso no se puede terminar.** Lo destapó leer el código antes de
> recorrerlo: **el dueño no puede dar por terminado un servicio** (**AP**).

**a) Como Alicia** — *Nueva Cita*: elige **el servicio primero** (es lo que
destapa la lista de estilistas), luego Erick, luego David, fecha y hora.

- **Debe pasar:** nace el ticket **#0000001** en estado *Solicitado*.
- **Y míralo bien:** saldrán **dos David idénticos** en el desplegable, porque
  el paso 11 los duplicó a propósito. **¿Se pueden distinguir?** Si no, es el
  segundo filo de **AO**: no es solo que las cifras se partan, es que **quien
  agenda no sabe cuál elegir**.

**b) Como Alicia** — botón **Estado**: llévalo a *Confirmado* y luego a
*En proceso*.

- **Debe pasar:** ahí el botón **Estado se queda sin opciones**. No es un
  fallo de la pantalla: es **AP**. Desde aquí no se puede llegar a *Por
  cobrar*.

**c) Como ERICK** (`elboga013@gmail.com`, otra ventana o incógnito) →
**Mi agenda** → marca su servicio como terminado.

- **Debe pasar:** el ticket pasa a **Por cobrar**. **Es el único camino que
  existe hoy en toda la aplicación.**

**d) Como Alicia** → **Tickets & Caja** → *Pagos y saldo* → cobra los $18.000.

- **Debe pasar:** al quedar el saldo en cero el ticket **se cierra solo** y
  **nace la comisión de Erick**. Las dos cosas exigen que (c) se haya hecho.
- **Compruébalo desde los dos lados:** en tu Dashboard, y en el **Mi panel
  financiero** de Erick, que debería enseñar su comisión **al 40% que nadie
  confirmó** (**AJ**). Es la primera vez en todo el recorrido que ese 40% se
  convierte en dinero de una persona.
- **Ojo:** esto es dinero **del salón**, no de la plataforma. No pasa por
  ePayco ni te cobra a ti.

**Lo que salió el 18-sep, y conviene repetirlo igual:**

- ✅ **El camino completo funciona**, de la cita al cobro, y el dinero apareció
  en los tres sitios: caja, Dashboard y el panel de Erick.
- 🔴 **$7.200 sobre $18.000 = el 40% exacto.** Es **AJ** convertido en una
  cuenta por pagar a una persona. **Y el estilista la ve antes que el dueño**,
  porque el dueño no tiene esa pantalla.
- 🔴 **Al subir la foto, el estilista marca él mismo la casilla de que la
  clienta autorizó** (**AQ**). Juez y parte.
- 🔴 **Los dos David eran indistinguibles** en el desplegable (**AO**).
- 🟡 En *Mi agenda* hay **dos columnas de estado** — *Ticket: En proceso* y
  *Servicio estado: Pendiente* — que no son lo mismo y se llaman parecido.
  Misma familia que el hallazgo **N**.
- 🟡 La agenda abre en *Cada 15 min*: 56 filas para encontrar una cita
  (**I-18**).

### 13. Mira los informes

**Dashboard** y **Reportes**, como dueño. Con una sola sede el interruptor
*"consolidado"* no se dibuja, y es correcto.

- **Debe cuadrar la resta:** *Ganancia Neta* = ingresos − compras − gastos −
  **comisiones**. El 18-sep dio **$10.800 = $18.000 − $7.200**, exacto.
- **Y comprueba el método de pago.** El *Arqueo de Efectivo* y el desglose
  (Efectivo / Transferencias / Tarjetas) salen **directos** de lo que se
  eligió al cobrar: el informe no transforma nada. Si no coincide con lo que
  marcaste, **el dinero está mal clasificado y hay que parar**.
- **Ojo con quién lo mira.** El 18-sep este paso se hizo **desde la cuenta de
  la administradora**, no la del dueño — y se vio **exactamente lo mismo**:
  *Ganancia Neta* y *Comisiones por Estilista* incluidas. Es evidencia directa
  de **I-17**: la administradora ve la rentabilidad del negocio y lo que gana
  cada persona.

### 14. Compruébalo todo desde tu Panel

Su ficha debe decir: **1 sede**, su estado, y **`6 colaboradores`** o los que
sean, con su desglose.

---

## Y ahora, bórralo

### 15. El seguro, antes de nada

En su ficha, mira *Acciones de Gestión*. **No debe haber ninguna zona roja**,
porque el negocio **no** está marcado como prueba.

> **Que el botón no esté es el paso más importante de los quince.** Es lo que
> impide borrar a un cliente real por pulsar la fila de al lado (D-246).

> **Si el negocio ya está marcado** — porque se adelantó el paso 16 — el orden
> es: **Quitar la marca** → comprobar que la zona roja desaparece → **volver a
> marcarlo**. Hecho así el 18-sep y **el seguro respondió en los dos sentidos**.

- **Y de paso se comprobó la trazabilidad que pide `AGENTS.md`:** cada marcado
  y cada desmarcado dejó su fila `demo_flag_updated` con fecha y hora en
  *Historial de Periodos Registrados*. **Nada de esto ocurre en silencio.**
- 🟡 **Mirando eso salió AR:** al quitar la marca, la tarjeta de arriba pasó
  de *0/0* a *0/1* y la píldora siguió diciendo *En Prueba (2)*. **La misma
  pantalla cuenta las pruebas de dos maneras.**

### 16. Márcalo como ensayo

*"Marcar como negocio de ensayo"*. **Ahora sí aparece la zona roja.**

> **Prueba extra del 18-sep: el borrado se estrenó contra otro negocio.**
> Antes de llegar aquí se borró **Exportadora** (de ensayo desde D-225, con
> prueba vencida y precio pactado desde el 21-ago). Se hizo a propósito:
> **la Peluquería tenía un día de vida y veinte filas**, y el descubrimiento
> de tablas por `information_schema` (D-246) solo se pone a prueba de verdad
> contra un negocio con historia. Cayó sin incidentes.
>
> **Y el propio diálogo confirma AS por escrito:** *"Las cuentas de correo y
> los archivos de fotos NO se borran."*
>
> Las cifras exactas **no se pierden aunque no se lea el aviso**: quedan en
> `deleted_demo_tenants` (`filas_por_tabla`, `pagos_registrados`, `dinero_cop`).
> Esa tabla es el único rastro que queda de un negocio borrado, y por eso
> existe. **Consultada:** 17 filas en 10 tablas, 0 pagos, $0.
>
> **Y el inventario contó algo que no se buscaba** (hallazgo **AT**): tras 28
> días, Exportadora tenía **0 clientas, 0 tickets, 0 servicios, 0 estilistas
> y 0 fotos**. Las 17 filas eran **todas de la máquina** — incluidas las 7 de
> `business_hours` y la `commission_policies` con el 40% de AJ —. **El único
> pionero real que ha entrado al producto se registró y no volvió.**

> **DECISIÓN DEL PROPIETARIO, 18-sep: la Peluquería Éxito Prueba NO se borra
> todavía.** *"Dejemos el negocio de prueba para continuar con pruebas, ¿para
> qué borrarla en este momento?"*
>
> **El borrado ya quedó probado** — y contra un negocio mejor: Exportadora,
> con 28 días de historia, 17 filas y 10 tablas. Repetirlo aquí añadiría poco
> y costaría el único montaje completo que existe: clienta con PIN, cita
> cobrada, comisión, foto, reseña y partner. **Ese montaje es lo que permite
> seguir probando** — la reserva pública es la siguiente.
>
> **Los pasos 17 y 18 quedan pendientes, no descartados.** El 18 — volver a
> registrarse con el mismo correo — **sigue sin probarse con nadie**, y es lo
> que demuestra que un correo no se quema al borrar.

### 17. Bórralo

*"Borrar negocio de prueba"* → escribe **Peluquería Éxito Prueba** exacto.

- **Debe pasar:** desaparece de la lista y te dice cuántas filas cayeron y en
  cuántas tablas.
- **No se borran:** las cinco cuentas de correo (para poder repetir el
  recorrido) ni los archivos de fotos, que viven fuera de la base.

### 18. Repite el paso 1 con el mismo correo

Vuelve a registrarte con `elboga008@gmail.com`.

- **Debe pasar:** **funciona**. Es la prueba de que el borrado dejó la cuenta
  utilizable, que es lo que permite volver a ensayar sin quemar correos.

---

## Dónde anotar lo que salga

| # | Paso | ¿Pasó? | Qué salió |
|---|---|---|---|
| 1 | El propietario se registra | | |
| 3 | Aprobación desde el Panel | | |
| 4 | **Alicia** carga los datos de su sede | | ✅ |
| 5 | Tú los ves desde el Panel | | |
| 6 | Invitación al administrador | | ✅ correo en 1 min |
| 7 | La administradora acepta | | ✅ |
| 8 | Invitación a la asistente | | ✅ su menú son 3 entradas, no 15 |
| 9 | Crear al estilista en el catálogo | ✅ | **No pide comisión: hereda el 40% (AJ)**. El diálogo NO pierde lo escrito |
| 10 | Invitación al estilista | ✅ | Correo en 1 min. **Pero: enlace gastado (AH), sin aviso (AM), y dos nombres (AN)** |
| 10b | El estilista acepta y entra | ✅ | Su menú son **4 entradas**. Un correo cayó en **Promotions** |
| 11 | La clienta | ✅ | Se crea bien. **Pero admitía duplicado exacto (AO)**. Las fichas se separaron el 19-sep: ya no hay duplicados |
| 11b | Un servicio, y vincularlo a Erick | ✅ | 2 servicios creados y asignados a Erick |
| 12 | Cita y cobro | ✅ | **El camino entero funciona.** Y salió caro en hallazgos: **AP**, **AQ**, y **AJ probado con dinero** |
| 13 | Informes | ✅ | Venta $18.000, **Ganancia Neta $10.800 = 18.000 − 7.200**. Sin interruptor consolidado, correcto |
| 14 | Verlo desde el Panel | ✅ | **4 colaboradores: 1 dueño, 1 admin, 1 asistente, 1 estilista.** Y **AG** otra vez: $4.500 aquí, $150.000 la sede |
| 15 | **Sin marca, sin botón de borrar** | ✅ | **El seguro funciona.** Quitada la marca, la zona roja desaparece; devuelta, vuelve |
| 16 | Marcar como ensayo | ✅ | Y **cada marcado y desmarcado dejó su fila** `demo_flag_updated` con su hora |
| 17 | Borrado | ⏸ | **Aplazado a propósito.** Probado con **Exportadora**: 17 filas, 10 tablas, 0 pagos |
| 18 | Volver a registrarse con el mismo correo | ⏸ | **Pendiente de verdad.** Depende del 17 |
| 19 | Página pública y portal de la clienta | ✅ | **Añadido.** Funciona. **Pero AO deja fuera a la ficha nueva**, y salen **AU** y **AV** |
| 20 | Reserva pública | ✅ | **Añadido.** Funciona y respeta el horario. **Pero fabrica duplicados (AW)** |

---

## 19. La página pública y el portal de la clienta *(añadido el 18-sep)*

> **No estaba en el guion.** Salió de un botón que el propietario encontró por
> su cuenta en la ficha de una clienta — *Restablecer PIN del portal* — y que
> abría una puerta **que no había recorrido nadie**. Se probó antes de borrar
> el negocio, porque hacía falta el montaje entero: clienta con PIN, cita
> cerrada, foto y comisión.

**a)** Configuración → copia el **enlace web de tu negocio**
(`salonymas.com/tu-slug`) y ábrelo en incógnito.

- ✅ **18-sep:** la página pública existe y se ve entera — servicios con
  precio y duración, equipo con su biografía, horarios, Google Maps, WhatsApp.

**b)** Pulsa **«Mis citas y fotos»** → celular y PIN de 4 dígitos.

- ✅ Entra, saluda por su nombre, y enseña la cita del día con su botón
  **Calificar**. La reseña se envía y queda **pendiente de moderación**.
- 🔴 **Pero antes hay que asignar el PIN, y ahí está AO:** con dos fichas del
  mismo teléfono **solo abre el PIN de la más vieja**. Se probó con `1234` y
  `5678` a propósito: el de la ficha nueva devuelve *«Celular o PIN
  incorrectos»* siendo correcto. **No hay aviso, y cada intento gasta una de
  las cinco vidas antes del bloqueo de 15 minutos.**
- 🟡 **Mis fotos sale vacío aunque se active «Visible al cliente»** (**AU**).

**c) De paso, la prueba del candado legal:** intenta aprobar para portafolio
una foto sin consentimiento.

- ✅ **Debe negarse**, y se negó: *«No se puede publicar en portafolio sin
  consentimiento de la clienta (Ley 1581)»*. **El servidor sí protege**, que
  es la contracara buena de **AQ**.

**d)** Mira el texto con ojos de clienta.

- 🟡 **La pantalla de reseña no tiene una sola tilde** (**AV**): *resena*,
  *opinion*, *quedara*, *Calificacion*.

## 20. La reserva pública *(añadido el 18-sep)*

Desde la página pública, en incógnito: **Reservar** en un servicio → elige
profesional, fecha y hora → nombre y celular → **Solicitar cita**.

- ✅ **Funciona de punta a punta.** La cita nace **«Solicitado»**, aparece en
  la columna *Por confirmar* del Tablero de Agenda y en Tickets & Caja con su
  número. La pantalla final ofrece **avisar por WhatsApp** y **guardar en
  Google Calendar**.
- ✅ **El horario está protegido:** el servidor rechaza una hora que ya no esté
  libre (*«Ese horario ya no está disponible»*).
- 🟡 **Pero ese mismo aviso sale cuando simplemente se te hizo tarde**
  (**AX**): la lista solo ofrece horas `> now()`, así que elegir las 18:15 a
  las 18:14 y enviar a las 18:15 lo rechaza **diciendo que no hay
  disponibilidad**, que no es lo que pasó.

**Y ahora la prueba que importa — házla siempre, son dos minutos:**

1. Reserva con el teléfono **tal cual** está guardado (`3506815629`).
2. Reserva otra vez con **el mismo número espaciado** (`350 681 56 29`).

- 🔴 **18-sep: la primera reutilizó la ficha; la segunda creó una nueva**
  (**AW**). El salón terminó con **cuatro fichas de cliente para dos personas**.
  La reserva compara el teléfono **como texto**; el portal lo compara **por
  dígitos**. Dos reglas para la misma pregunta.
- **Encadenado con AO:** esa clienta nueva tiene su cita en una ficha que su
  PIN del portal **nunca va a abrir**.

---

## Lo que este recorrido NO cubre

Dicho para que nadie lo dé por probado:

- **El cobro de la suscripción por ePayco.** Sigue pendiente el pago real de
  una **segunda sede** (pasos 9.7 y 9.8), que es lo único que verifica el P0
  de D-224 contra dinero de verdad.
- **La reserva pública se queda a medio probar, y este documento decía algo
  falso sobre ella.** Hasta el 18-sep aquí ponía *"todavía no existen"*. **Sí
  existen:** la página pública trae **Agendar Cita** y un **Reservar** por
  servicio, y detrás hay `public_get_available_slots` y `public_create_booking`.
  Lo que sigue sin probarse es **reservar de verdad** y ver si la cita aterriza
  en la agenda del salón. *(Queda señalado, no resuelto: decidir si la función
  está terminada o a medias es del propietario.)*
- **La recuperación de contraseña.**

Los tres son caminos completos que tampoco recorre nadie hoy. **El mismo
riesgo que este documento viene a cerrar, todavía abierto en otros tres
sitios.**
