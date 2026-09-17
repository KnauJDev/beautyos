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

| Papel | Nombre | Correo / teléfono |
|---|---|---|
| **Propietario** | *(el titular del negocio)* | `elboga021@gmail.com` |
| **Negocio** | Peluquería Éxito Prueba | — |
| **Sede 1** | *(la que se crea sola al registrarse)* | `elboga022@gmail.com` |
| **Administrador de sede** | Alvaro Enrique Administrador | `elboga023@gmail.com` |
| **Asistente** | Carolina Asistente | `elboga024@gmail.com` |
| **Estilista** | Erick Santiago Estilista | `elboga025@gmail.com` |
| **Clienta del salón** | David Alonso Cliente 1 | WhatsApp `3506815629` |

> Los tres roles que acepta una invitación son exactamente **`admin`**,
> **`assistant`** y **`stylist`**. No hay más.

---

## Antes de empezar

- [ ] **Revisar la caducidad del enlace de correo** (hallazgo AH). Supabase →
      **Authentication → Email**. Si el enlace dura poco, los invitados que
      abran el correo más tarde se caen en la puerta y **solo se ve que no
      entraron**. Este recorrido lo va a destapar en los pasos 6, 8 y 10.
- [ ] Tener a mano las bandejas de los cinco correos.
- [ ] **Ctrl+F5** en `salonymas.com` para no estar probando una versión vieja.

---

## El recorrido

En cada paso: **lo que haces**, **lo que debe pasar** y **qué avisar si no**.

### 1. El propietario se registra

Entra a `salonymas.com` con `elboga021@gmail.com` y regístrate como negocio
nuevo: **Peluquería Éxito Prueba**.

- **Debe pasar:** llega el correo de confirmación, y tras pulsarlo aparece el
  formulario *"Cuéntanos sobre tu negocio"*. Al enviarlo, queda en espera.
- **Avisar si:** sale *"No hay un plan disponible para registrar la
  solicitud"*. **Eso sería D-245 otra vez y se para todo.**
- **Avisar también si:** el enlace del correo dice *"invalid or has expired"*.
  Eso es el hallazgo AH, y es lo que hay que ajustar antes de los diez.

### 2. Se crea su primera sede sola

No hay nada que hacer: se comprueba en el paso siguiente.

- **Debe pasar:** el negocio nace con **exactamente una sede**, y es la
  principal (D-239).

### 3. Tú lo apruebas desde el Panel

Panel de Plataforma → filtro **Por Aprobar** → *Aprobar Negocio*.

- **Debe pasar:** pasa a **EN PRUEBA** con sus 21 días, y en su tarjeta de la
  lista aparece `1 sede · 1 en prueba` (D-244).

### 4. Pones los datos de la sede desde tu Panel

En su ficha, pestaña de la sede → botón **Datos**. Pon el correo de la sede:
`elboga022@gmail.com`, y una dirección cualquiera.

- **Debe pasar:** se guarda y se ve en la ficha (D-241).
- **Prueba a propósito:** escribe un correo **sin arroba** y guarda. Debe
  rechazarlo diciéndolo, y el mensaje debe llegar a la pantalla.

### 5. El propietario ve sus datos desde su propia Configuración

Entra como `elboga021` → **Configuración → Datos de esta sede**.

- **Debe pasar:** ve lo mismo que pusiste tú, y puede cambiarlo (D-242).
- **Y fíjate en que** *"Datos del negocio"* **ya no tiene dirección**: se mudó
  a la sede, porque antes escribía siempre en la sede principal (hallazgo AF).

### 6. Invita al administrador

Como propietario → **Usuarios → invitar** a `elboga023@gmail.com`, rol
**administrador**.

- **Debe pasar:** se crea la invitación **y llega el correo**.
- **Avisar si:** la invitación aparece en la lista pero **el correo no llega**.
  Ese es el eslabón que más sospecho de todo el recorrido.

### 7. Alvaro acepta

Abre `elboga023@gmail.com`, pulsa el enlace y crea su cuenta.

- **Debe pasar:** entra y ve la sede. **No debe ver el Panel de Plataforma.**

### 8. Invita a la asistente

Igual, con `elboga024@gmail.com` y rol **asistente**.

- **Debe pasar:** lo mismo que en 6 y 7.
- **Y comprueba:** Carolina **no** debe poder invitar a nadie ni ver
  Configuración.

### 9. Crea al estilista en el catálogo **antes** de invitarlo

**Estilistas → nuevo** → *Erick Santiago Estilista*.

> **Este orden importa.** La regla "un estilista, una cuenta" exige que el
> estilista exista en el catálogo para poder enlazarlo a su invitación. Al
> revés no se puede.

### 10. Invítalo

**Usuarios → invitar** a `elboga025@gmail.com`, rol **estilista**, enlazado a
Erick.

- **Debe pasar:** al aceptar, Erick ve **solo lo suyo**: su agenda y sus
  fotos. No ve el dinero del salón ni puede invitar.

### 11. La clienta

**Clientes → nueva** → *David Alonso Cliente 1*, WhatsApp `3506815629`.

### 12. Una cita, y cobrarla

Agenda → **Nueva Cita** para David con Erick → llévala hasta **Por cobrar** →
cobra el ticket.

- **Debe pasar:** el ticket recibe su número, y el cobro aparece en Tickets &
  Caja y en el Dashboard.
- **Ojo:** esto es dinero **del salón**, no de la plataforma. No pasa por
  ePayco ni te cobra a ti.

### 13. Mira los informes

**Dashboard** y **Reportes**, como dueño. Con una sola sede el interruptor
*"consolidado"* no se dibuja, y es correcto.

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

### 16. Márcalo como ensayo

*"Marcar como negocio de ensayo"*. **Ahora sí aparece la zona roja.**

### 17. Bórralo

*"Borrar negocio de prueba"* → escribe **Peluquería Éxito Prueba** exacto.

- **Debe pasar:** desaparece de la lista y te dice cuántas filas cayeron y en
  cuántas tablas.
- **No se borran:** las cinco cuentas de correo (para poder repetir el
  recorrido) ni los archivos de fotos, que viven fuera de la base.

### 18. Repite el paso 1 con el mismo correo

Vuelve a registrarte con `elboga021@gmail.com`.

- **Debe pasar:** **funciona**. Es la prueba de que el borrado dejó la cuenta
  utilizable, que es lo que permite volver a ensayar sin quemar correos.

---

## Dónde anotar lo que salga

| # | Paso | ¿Pasó? | Qué salió |
|---|---|---|---|
| 1 | El propietario se registra | | |
| 3 | Aprobación desde el Panel | | |
| 4 | Datos de la sede desde el Panel | | |
| 5 | El salón ve y edita su sede | | |
| 6 | Invitación al administrador | | |
| 7 | Alvaro acepta | | |
| 8 | Invitación a la asistente | | |
| 10 | Invitación al estilista | | |
| 12 | Cita y cobro | | |
| 15 | **Sin marca, sin botón de borrar** | | |
| 17 | Borrado | | |
| 18 | Volver a registrarse con el mismo correo | | |

---

## Lo que este recorrido NO cubre

Dicho para que nadie lo dé por probado:

- **El cobro de la suscripción por ePayco.** Sigue pendiente el pago real de
  una **segunda sede** (pasos 9.7 y 9.8), que es lo único que verifica el P0
  de D-224 contra dinero de verdad.
- **Las reservas públicas**, que todavía no existen.
- **La recuperación de contraseña.**

Los tres son caminos completos que tampoco recorre nadie hoy. **El mismo
riesgo que este documento viene a cerrar, todavía abierto en otros tres
sitios.**
