# HANDOFF Salón y Más — 2 de septiembre de 2026 ("Velocidad de Caja y Feedback de Pasarela", D-200)

**Bloque documentado:** decisión **D-200** · Paso **8.22** de la **FASE 8**.

**Estado:** ✅ **CERRADO.** `flutter analyze` 0/0 y **333 de 333 pruebas en
verde** (20 nuevas). Bloque enteramente de interfaz: sin migración SQL ni
Edge Function, así que no queda ningún paso manual pendiente y no hace falta
desplegar nada aparte del push.

> El bloque anterior (D-199, "Rendimiento, Resiliencia y Optimización de
> Carga") está en
> `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-02_D199.md`.

---

## 1. Lo primero: tres premisas del encargo no coincidían con el código

Se comprobaron **antes** de escribir nada (regla 1 del apartado 8). Ninguna
cambió el alcance, pero las tres cambian lo que hay que buscar si alguien
vuelve sobre esto:

| El encargo decía | Lo que hay de verdad |
|---|---|
| Tocar `_TicketPaymentDialog` **y** `_PaymentsDialog` | **`_TicketPaymentDialog` no existe.** Hay un solo diálogo de cobro en todo el proyecto |
| El bloque `_verifyPendingEpaycoTransaction` de `main.dart` | **Ese método tampoco existe.** La verificación está en línea dentro de `_loadHomeContext()` |
| UX-07: "el valor se teclea a mano" (auditoría del 01-sep) | **No era exacto.** `initState` ya rellenaba el campo con el saldo desde D-163 |

Esa tercera es la que importa, porque cambia **qué** hay que arreglar.

---

## 2. UX-07 — El problema no era el valor inicial, era la vuelta atrás

El campo ya empezaba con el saldo. Lo que no había era forma de volver.

La secuencia real del mostrador es esta:

1. La clienta dice *"te abono 50"*. Se teclea `50000`.
2. Diez segundos después dice *"mejor lo pago todo"*.
3. Y ahí tocaba **borrar y volver a teclear la cifra completa de memoria** —
   con el riesgo de dejar un dígito fuera y cerrar el ticket con un saldo
   suelto de $900 que nadie vuelve a mirar.

### Cómo quedó

- Un `ActionChip` **"Pagar saldo exacto ($150.000)"**, con la cifra formateada
  por `formatCOP` (D-198), no escrita a mano.
- Va **encima** del campo, no al lado: "todo o una parte" es lo primero que se
  decide al cobrar.
- Al pulsarlo rellena el monto **entero exacto** (`toStringAsFixed(0)`, nada de
  `150000.0`) y **pasa el foco al botón "Registrar pago"**, para que quien
  cobra confirme sin volver a tocar la pantalla.

### `PaymentsDialog` pasó a ser público, y no es un descuido

En Dart lo privado lo es **para toda la biblioteca**: un `_PaymentsDialog` no
se puede montar desde `test/`. `TicketRow` ya era público por exactamente lo
mismo. Y aquí se cuenta dinero — el atajo rellena el monto que se va a
cobrar — que es literalmente lo que H-03 pedía poder comprobar sin abrir un
navegador.

---

## 3. ePayco — Lo importante es cómo se traduce el fallo

`_loadHomeContext` llamaba a `verify-epayco-transaction` y **tiraba el
resultado entero**. Ni el éxito ni el fallo llegaban a la pantalla: el dueño
acababa de pagar $150.000 y volvía a una aplicación muda.

> ### Un fallo de esta llamada NO es un pago fallido
>
> La vía autoritativa de activación es el **webhook servidor-a-servidor**
> (D-141). `verify-epayco-transaction` es solo el atajo para que la
> confirmación se vea sin esperar. Si falla —red caída, 401 por sesión
> vencida, 403 porque el pago es de otro negocio, 409 sin factura atribuible,
> 500 del servidor— **el pago sigue su curso y el webhook activa igual**.
>
> Por eso los cinco caminos de fallo dicen *"estamos validando tu pago"*,
> **nunca "error"**. La propia auditoría del 01-sep ya había corregido esa
> severidad. Asustar a alguien que acaba de pagar bien sería peor que el
> silencio que había antes.

### Y no se promete "activa" cuando la base no lo dice

Que ePayco acepte la transacción **no** significa que la suscripción quede
activa: si el negocio está en revisión (D-125 / D-138) o suspendido a mano por
la plataforma, la base **registra el pago pero no reactiva**.

| Lo que devuelve la pasarela | Lo que ve el dueño | Tono |
|---|---|---|
| Aceptada **y** `newStatus == active` | "Tu pago quedó confirmado y tu suscripción está al día" | Éxito |
| Aceptada, cualquier otro `newStatus` | "ePayco aprobó tu pago. Lo estamos registrando…" | Informativo |
| Rechazada / Fallida (cód. 2, 4) | "ePayco no aprobó el pago. Puedes intentarlo de nuevo…" | Aviso |
| Reversada (cód. 6) | "ePayco reversó este pago…" | Aviso |
| Pendiente, cuerpo raro, **o cualquier fallo** | "Estamos validando tu pago…" | Informativo |

### Dónde vive la traducción, y por qué ahí

`lib/models/aviso_de_pago.dart`. Misma razón que `AccionesDeTicket` (H-03):
metida en un método privado de un `State` no hay forma de probarla sin pagar
de verdad.

La clasificación de aceptada/rechazada/reversada está **copiada de
`beautyos_procesar_evento_epayco`** (migración `20260823150000`), que es quien
decide de verdad qué le pasa a la suscripción. Hay una prueba que fija los
tres juegos de valores: si allí se añade un estado y aquí no, el salón vería
un mensaje que no corresponde con lo que hizo la base.

### Esto no contradice a TL-16 (D-199)

Aquel `catch (_)` tapaba **el único camino que había**. Este cubre un camino
**redundante**, y ahora sí deja rastro: en monitoreo y en la pantalla.

---

## 4. C-02 — Se pudo retirar la condición sin cambiar comportamiento

`TicketRow` exigía **ocho** callbacks `required`. Cinco no aparecían en ningún
sitio del `build`, y `onAddService` solo figuraba dentro de la condición de
visibilidad de la barra de acciones, sin llegar a ser el `onPressed` de nada.

Quedaron de cuando la tarjeta tenía menú propio.

**No se perdió ninguna acción.** Reprogramar, gestionar servicios, corregir
finalización, copiar el enlace de reseña y agregar foto se siguen ofreciendo
en la Ficha Completa (`_TicketDetailSheet`), que sí usa las ocho, y a la que
se llega tocando la tarjeta o "Ver ficha".

### Por qué quitar `onAddService` de la condición era seguro

Se comprobó estado por estado antes de tocar nada. Los estados que admiten
agregar servicios (`_antesDeAtender`: solicitado, cotizado, apartado,
confirmado, en_espera) son un **subconjunto** de los que admiten cobrar
(`puedeGestionarPagos`, que solo excluye `cancelado` y `no_asistio`).

Es decir: **siempre que `onAddService` no era nulo, `onManagePayments` tampoco
lo era.** El término sobraba.

Eso quedó fijado en una prueba, porque si esa relación se rompiera algún día,
la barra de acciones desaparecería **en silencio** para algún estado.

---

## 5. Las 20 pruebas nuevas

| Archivo | Cuántas | Qué vigila |
|---|---|---|
| `test/aviso_de_pago_epayco_test.dart` | 10 | Cada desenlace de la pasarela; que un fallo **no** se cuente como pago fallido; que los estados no se desalineen de la migración |
| `test/saldo_exacto_en_cobro_test.dart` | 6 | El chip con `formatCOP`, la vuelta atrás tras un abono parcial, el foco en "Registrar pago", el monto entero, y que sin saldo o con cita cancelada no aparezca |
| `test/tickets_page_test.dart` (grupo nuevo) | 4 | C-02: la relación subconjunto entre agregar servicios y cobrar, y la barra de acciones en tres estados |

Las dos pruebas existentes de `TicketRow` se actualizaron a la firma nueva.

**A diferencia de D-199, estas no leen el código fuente:** ejercitan el
comportamiento de verdad. Se pudo porque las tres piezas se dejaron
alcanzables — `AvisoDePago` en `lib/models/`, `PaymentsDialog` público.

> **Lo que NO queda cubierto por pruebas:** el cableado del `SnackBar` en
> `main.dart` (que el aviso se encole una sola vez y sobreviva al
> `addPostFrameCallback`). Ejercitarlo pide una sesión de Supabase y un
> `?ref_payco=` en la URL. Lo que sí está probado es **qué** se dice; lo que
> no, es que llegue a verse.

---

## 6. Qué NO hacer

- **No convertir un fallo de `verify-epayco-transaction` en un mensaje de
  error.** Es el corazón de este bloque. El webhook activa igual; decirle
  "falló tu pago" a alguien que pagó bien es peor que el silencio anterior.
- **No prometer "suscripción activa" mirando solo `transactionState`.** Hace
  falta también `newStatus == 'active'`: un negocio en revisión registra el
  pago sin reactivar.
- **No añadir estados a `beautyos_procesar_evento_epayco` sin tocar
  `aviso_de_pago.dart`.** Hay una prueba que obliga a cambiar los dos a la vez,
  y está ahí a propósito.
- **No volver a hacer `_PaymentsDialog` privado.** Se hizo público para poder
  probar el atajo de saldo; en Dart lo privado lo es para toda la biblioteca.
- **No devolverle callbacks a `TicketRow` "por si acaso".** Si la tarjeta
  necesita una acción nueva, que sea porque va a pintar un botón.
- **No intentar el atajo de Nequi/Daviplata como cambio de interfaz.** Los
  métodos de pago son un `CHECK` de base de datos (C-04), no una lista de UI:
  necesita migración, control SQL y recalcular el desglose de Reportes.

---

## 7. Lo que sigue abierto

1. **Nuevo de este bloque:** la otra mitad de UX-07 — distinguir Nequi de
   Daviplata. Es migración + control SQL + Reportes, no interfaz.
2. **Heredado y sin cubrir:** el cableado del `SnackBar` de ePayco no tiene
   prueba (apartado 5).
3. **TL-10 sigue siendo el hallazgo más grande sin paso asignado:** el
   `IndexedStack` de `main.dart` construye todas las páginas autorizadas a la
   vez, y es **la causa raíz del Hallazgo Q** ("ningún módulo se actualiza
   solo"), abierta desde el 09-ago.
4. El otro tercio de TL-09: la consulta de Tickets sigue trayendo el historial
   completo (`p_start_date: null`). D-199 acotó lo que se pinta, no lo que se
   trae.
5. `get_tickets_summary_v2` quedó sin consumidores en Flutter pero sigue viva
   en la base y la usan 4 controles SQL. Decidir si se retira.
6. La pantalla pública de planes, la tarjeta de sedes y el desglose de
   reportes por sede siguen sin verse con los ojos (HANDOFF de D-195, 3.3).
7. El candado 2 de D-181 sigue sin ejercitarse contra un pago real de ePayco.
8. Del Plan Maestro: Fase 3 con dos casillas de 👤 abiertas (3.2 contador
   sobre DIAN/IVA, 3.4 subir Supabase a Pro).

> **Lo que el propietario tiene que ver con los ojos en este bloque:** el chip
> de saldo exacto en un cobro real (que la cifra cuadre y que al pulsarlo el
> botón de confirmar quede resaltado), y **el aviso al volver de ePayco** —
> que es lo único de D-200 que no se puede probar sin pagar de verdad. Sigue
> pendiente de D-199: la lista de Tickets con "Ver 10 más" y un logo con fondo
> transparente subido de nuevo.

---

## 8. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-200: Bloque 6 "Velocidad de
Caja y Feedback de Pasarela" -- atajo de saldo exacto al cobrar (UX-07), el
retorno de ePayco deja de ser mudo, y limpieza de TicketRow (C-02)).

Bloque enteramente de interfaz: sin migración SQL ni Edge Function.
flutter analyze 0/0 y 333/333 pruebas en verde.

Lo que sigue abierto, por orden de daño:
1. TL-10: el IndexedStack de main.dart construye todas las páginas a la vez,
   y es la causa raíz del Hallazgo Q ("ningún módulo se actualiza solo"),
   abierta desde el 09-ago. Es el hallazgo más grande que queda sin paso.
2. El otro tercio de TL-09: la consulta de Tickets sigue trayendo el
   historial completo (p_start_date: null).
3. La otra mitad de UX-07: distinguir Nequi de Daviplata. NO es interfaz --
   los métodos de pago son un CHECK de base de datos (C-04), así que pide
   migración, control SQL y recalcular el desglose de Reportes.
4. Pantalla pública de planes, tarjeta de sedes y desglose de reportes por
   sede sin verificar visualmente.
5. El candado 2 de D-181 sin ejercitar contra un pago real.
6. get_tickets_summary_v2 quedó sin consumidores en Flutter pero sigue viva
   en la base y la usan 4 controles SQL. Decidir si se retira.

Ojo con lo que NO hay que tocar: un fallo de verify-epayco-transaction NO se
le cuenta al dueño como pago fallido -- el webhook (D-141) activa igual, y
decirle "falló tu pago" a alguien que pagó bien es peor que el silencio que
había antes. Y no prometer "suscripción activa" mirando solo transactionState:
hace falta newStatus == 'active', porque un negocio en revisión registra el
pago sin reactivar.
```
