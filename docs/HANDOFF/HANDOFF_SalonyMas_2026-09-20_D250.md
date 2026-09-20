# HANDOFF Salón y Más — 20 de septiembre de 2026 ("Faltaba el botón", D-250)

**Bloque documentado:** decisión **D-250** · Fase **9**, paso **9.53** (cerrado) · hallazgo **AP** cerrado.

**Estado:** ✅ Todo aplicado, publicado y **verificado en producción por el propietario**.
`flutter analyze` **0/0** · **436 pruebas** · **Control 218: 9 de 9** · Guardián en verde.

> El bloque anterior está en `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-19_D249.md`.

---

## 1. Lo que hay que leer si solo se lee una cosa

**Un hallazgo puede tener una segunda mitad que solo aparece al recorrerlo.**

AP decía *"no falta permiso, falta el botón"*. Era **exacto**: el servidor
autorizaba a dueño, admin y recepción desde julio, y el lector de servicios ya
existía. Esa mitad no costó ni una migración.

Pero poner el botón y parar ahí habría dejado sin comisión a **toda clienta que
paga por adelantado**. Eso lo encontró el **control 218 fallando en su primera
corrida**, no el hallazgo y no una prueba de Dart.

Y la causa es la más aleccionadora del día:

> **D-163 había previsto ese caso exacto, lo describió palabra por palabra, y
> puso el remedio en una puerta que no se puede abrir.**

El `perform` que cierra el ticket y genera la comisión estaba en
`change_ticket_status` — el cambio de estado **a mano** —, que para aceptar
`finalizado` exige que todos los servicios ya estén terminados. Y cuando eso se
cumple, `change_ticket_service_status` ya movió el ticket por su cuenta, así que
la llamada sale por el `return` de arriba. **Código correcto, inalcanzable.**

---

## 2. La decisión

### D-250 — No faltaba permiso, faltaba el botón

**El problema.** Un salón crea estilistas en el catálogo sin invitarlos: no todo
el mundo quiere dar cuentas a todos. Para esos, el único sitio de toda la
aplicación que terminaba un servicio era **Mi agenda**, la pantalla privada del
estilista — que no existe si no tiene cuenta. El ticket se quedaba en *En
proceso* **para siempre**: se le podía cobrar (D-163), pero no cerraba y **no
pagaba comisión**.

**Lo que se hizo.** Ventana *Atender servicios* en la ficha del ticket, con el
paso que toca por servicio y pregunta antes de finalizar. Migración
`20260920120000`, que le pone a `change_ticket_service_status` el remedio que
D-163 dejó en la puerta equivocada. **El de D-163 no se quita:** si algún día se
llama esa RPC directamente sigue siendo la red correcta.

Cierra el paso **9.53** y el hallazgo **AP** entero.

---

## 3. El patrón que lleva cuatro días seguidos

| Día | Dónde estaba escrito a mano | Qué costó |
|---|---|---|
| 17-sep | `'profesional'` dentro de `register_tenant` | **Dieciséis días sin registros** (D-245) |
| 19-sep | el `6` del código de confirmación | El correo traía ocho (**AY**) |
| 19-sep | el largo del celular | Se cortó antes (D-249) |
| **20-sep** | **la tabla de estados del servicio** | **Se cortó antes.** Vive en `AccionesDeTicket` y la pantalla del estilista la lee de ahí |

**Cuatro golpes, y los dos últimos ya no costaron nada.** Eso es lo que hay que
conservar.

---

## 4. Dónde vive cada regla

| Regla | Dónde está escrita | Cuántas veces |
|---|---|---|
| Del estado del servicio al siguiente | `AccionesDeTicket.siguienteEstadoDelServicio` | **1** (el servidor manda; esto es su espejo) |
| Quién puede atender un servicio | `change_ticket_service_status_v2` | 1 — la pantalla **no** filtra por rol, y es correcto |
| Cuándo cierra el ticket y nace la comisión | `beautyos_close_ticket_if_fully_paid` | 1, llamada desde **tres** sitios |

---

## 5. Lo que quedó verificado en producción

- El dueño inicia y termina un servicio desde **Tickets & Caja**, sin que ningún estilista entre.
- **El orden del anticipo:** pago por transferencia durante la atención, finalizado después **con el usuario del asistente**, ticket **cerrado** y comisión visible en *Mi panel financiero* del estilista (\$24.400 sobre 3 servicios, que cuadra al 40%).
- **Control 218: 9 de 9**, probando **los dos órdenes** de cobro contra la base real.

---

## 6. Lo que NO hay que hacer

- 🔴 **NO pagar la suscripción.** La sede dice **\$150.000** y `EPAYCO_TEST_MODE` es `false`. Primero **AG**.
- **NO borrar la Peluquería Éxito Prueba.** Es el banco de pruebas.
- **NO quitar el `perform` de `change_ticket_status`.** Está inalcanzable hoy, pero es la red correcta si alguien llama esa RPC directamente. Lo que estaba mal no era tenerlo: era tenerlo **solo** ahí.
- **NO escribir la tabla de estados del servicio en ninguna pantalla.** Hay un sitio y está comentado.
- **NO tocar AE, I-17, Ñ ni el fondo de AC**: son material del **9.25**.

---

## 7. Por dónde seguir

| Orden | Qué | Por qué |
|---|---|---|
| **1º** | **AJ** — el 40% que nadie confirma | Ahora que la comisión **sí nace**, esto pasa a ser lo siguiente de verdad. Probado con dinero real: \$7.200 sobre \$18.000 |
| **2º** | **AG** — dos precios para lo mismo | Es lo único que impide cobrar la primera suscripción |
| **3º** | **Paso 9.48** — que la clienta autorice sus fotos y su reseña | Lo pidió el propietario. **Toca Ley 1581: quiere diseño con calma** |
| Sueltos | **AV**, **AR**, **I-18**, los **cuatro AK** que quedan | Media hora cada uno. El patrón de AK está escrito en `clients_page.dart` y ahora también en `_AttendServicesDialog` |

**Y lo que no es código:** el **9.24** — entrevistar salones reales con
`docs/03_referencias/GUION_ENTREVISTA_SALONES_9.24.txt` — sigue bloqueando el
**9.25**, la reestructuración a cinco módulos. Lleva parado desde el 07-sep.

**Estado de los hallazgos: 42 en total, 25 abiertos, 17 cerrados.**

---

## 8. Dos contradicciones encontradas, sin resolver

Se anotan y no se tocan, según la regla de cierre:

1. **`RESPALDO_Y_RESTAURACION_SUPABASE.md` nombra dos scripts de respaldo
   distintos** en dos sitios — `respaldo_supabase.ps1` en la tabla de arriba y
   `crear_respaldo_supabase.ps1` más abajo — y **los dos existen**, con nombres
   de carpeta diferentes (`Backup_...` y `BeautyOS_Backup_...`). El que ha hecho
   todos los respaldos de las migraciones es el primero.
2. **El recuento de hallazgos venía derivado.** El HANDOFF anterior decía
   *43 en total, 26 abiertos*, y la tabla tiene **42 filas**. Sobraba uno en
   abiertos. Corregido aquí contándolo sobre la tabla.

---

## 9. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-250).

Antes de tocar documentación: python scripts/verificar_documentos.py

DÓNDE ESTAMOS
El dueño ya puede operar el dia entero sin depender de que sus estilistas
tengan cuenta: atiende, cierra y la comision nace. Lo que bloquea ahora es
dinero: AJ y AG.

CÓMO SE TRABAJA CON ÉL
Va paso a paso y confirma cada uno antes del siguiente. No es técnico: hay
que decirle QUÉ hace, CÓMO y POR DÓNDE, con los nombres exactos de los
botones. Los comandos se le dan en bloques bash de una sola línea, y los
ejecuta él. Encuentra fallos reales probando.

ORDEN ACORDADO
  1. AJ - el 40% que nadie confirma. Ahora que la comision nace, toca
  2. AG - dos precios para lo mismo, y por eso no se puede cobrar
  3. Paso 9.48 - que la clienta autorice sus fotos y su resena (Ley 1581)
  Sueltos: AV, AR, I-18 y los cuatro dialogos de AK que quedan

NO PAGAR NADA. NO borrar la Peluqueria Exito Prueba: es el banco de pruebas.
NO quitar el perform de change_ticket_status: hoy es inalcanzable, pero es
la red correcta si alguien llama esa RPC directamente.
NO escribir la tabla de estados del servicio en ninguna pantalla: hay un
sitio, AccionesDeTicket, y esta comentado.

42 hallazgos: 25 abiertos, 17 cerrados. 250 decisiones. analyze 0/0 y
436 pruebas. Control 218 en verde (9 de 9). Guardian en verde.
```
