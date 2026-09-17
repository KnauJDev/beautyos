# HANDOFF Salón y Más — 16 de septiembre de 2026 ("El cobro se muda a la sede, y la sede empieza a existir", D-238 a D-244)

**Bloque documentado:** decisiones **D-238** a **D-244** · Fase **9**, pasos **9.38**, **9.39**, **9.42**, **9.43**, **9.44** y **9.45**.

**Estado:** ✅ Todo aplicado, publicado y verificado contra la base real. Controles **211**, **212** y **213** en verde a la primera.

> El bloque anterior está en `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-09_D237.md`.

---

## 1. Lo que hay que leer si solo se lee una cosa

**D-239: el que cobra pasa a ser la sede, no el negocio.** Todo dueño tiene mínimo una sede; cada sede lleva su propio historial de pagos y activaciones; el negocio queda como paraguas. Hacia arriba todo se suma.

**Y lo que NO cambia, preguntado explícitamente antes de escribir una línea:**

> Un socio de diseño de una sola sede **sigue pagando 50.000**. Los 50.000 congelados de D-222 se anotan ahora en su sede principal. **Cambia dónde se anota, no cuánto se cobra.**

La lectura alternativa —el negocio cobra *y además* cada sede— lo habría subido a **130.000**, rompiendo lo anunciado en público. Si alguien reabre esto, esa frase es la que hay que releer.

---

## 2. Dos fallos que la pantalla no delataba

**El de las sedes invisibles (D-238).** Crear una sede la guardaba en la base y no la enseñaba: el aviso prometía *"ya puedes asignarle servicios"* y el selector ni se enteraba. Peor: **con una sola sede ese selector no es un menú**, es una etiqueta muerta, así que no había nada que pulsar.

**El de las direcciones pisadas (D-242, hallazgo AF).** `get_business_settings` y `update_tenant_contact_info` resolvían la sede con `is_primary = true`, ignorando en cuál estabas. Dentro de la segunda sede veías la dirección de la primera **y corregirla escribía sobre la primera**, sin error y sin rastro.

Lo destapó el propietario con dos capturas que decían direcciones distintas de la misma sede. **Solo había datos de prueba;** con un cliente real de dos sedes habría borrado un dato bueno.

**Los dos tienen la misma forma:** nada falla, nada sale en rojo, y lo que ves no es lo que hay.

---

## 3. La cuarta capacidad construida sin puerta

`branches` nació el 20-jul con `contact_email`, `contact_phone`, `whatsapp`, `address`, `city` y `department`. **Dos meses vacías porque nadie las escribía.**

Antes pasó con `is_demo` (D-225), con el lector de sedes (D-235) y con `platform_set_branch_subscription`, que llevaba una semana sin que nadie la llamara (D-236).

> **Una columna que nadie escribe envejece igual que una función que nadie llama: parece que está y no está.**

Y las cuatro veces lo descubrió el propietario usando la app, no una prueba.

---

## 4. Lo que se construyó

| Paso | Qué |
|---|---|
| **9.38** (D-238) | Crear una sede recarga el contexto. Guardián que vigila que el cable siga conectado |
| **9.39** (D-240) | Panel maestro-detalle a partir de 1.000 px. La ficha ya no se cierra en cada acción |
| **9.42** (D-241) | La sede gana encargado, contacto y dirección propios. Puerta del **Panel** |
| **9.43** (D-242) | Puerta del **salón**, protegida por sede. Y la dirección **sale** de los datos del negocio |
| **9.44** (D-243) | La lista encabeza con la persona; el negocio y el precio se van con la sede |
| **9.45** (D-244) | La lista dice **cuántas sedes y en qué estado**; las pestañas de sede suben a la cabecera y la sede pasa a ser la tarjeta 1 |

**Las dos puertas escriben las mismas siete columnas, con la misma semántica:** siempre los siete campos, sin valores por defecto, vacío significa vacío. Dos puertas, una sola verdad.

Esa semántica viene de D-237, donde `coalesce(p_price_cop, price_cop)` hacía que `null` conservara y la función sabía poner y cambiar pero **nunca quitar**. Los controles 211 y 212 la vigilan explícitamente: si alguien mete un `coalesce` "para no perder datos", saltan.

---

## 4-bis. Tres rondas sobre la misma pantalla, y por qué está bien

El Panel se rehizo tres veces en un día (D-240, D-243, D-244). **Las tres salieron de que el propietario miró y dijo "no es eso"**, con capturas:

1. *"a la derecha solo una sede... lo que deseo separar"* → la sede gana vida propia.
2. *"el nombre del negocio debe ir en la tarjeta de la sede"* → cada dato a su altura.
3. *"aún salen las dos sedes dentro de la misma tarjeta"* → las pestañas suben a la cabecera.

**Ninguna de las tres se podía deducir leyendo código.** Y en la tercera ronda se le preguntó explícitamente qué datos quería en la tarjeta, en vez de adivinar por cuarta vez — la respuesta trajo un requisito que nadie tenía escrito: el **desglose por estado de las sedes**.

> Una pantalla que se rehace tres veces con el dueño delante cuesta menos que una que se rehace
> una sola vez, seis meses después, con clientes encima.

## 5. Lo que sigue

**Del propietario:**

- **9.7 y 9.8** — el pago real de una **segunda sede**, lo único que verifica el P0 de D-224 contra dinero real.

**Mías, por orden de valor:**

- **9.40** — el historial desglosado por sede. `subscription_payment_intents.branch_id` existe desde D-191 y `TenantSubscriptionHistoryEntry` **no tiene campo de sede**: el dato se tira. Es literalmente lo que el propietario no supo explicar al pagar Barbería Elite. **Toca dinero: lleva control propio.**
- **9.41** — módulos por sede. `get_my_entitlements()` resuelve por negocio vía `get_my_tenant_id()` y no sabe qué es una sede. Servidor primero; la app son 3 archivos. **Ojo:** al cambiar de sede hay que volver a resolverlos — misma costura que D-238.
- **9.9** — pruebas del Panel (4.700 líneas, ahora con maestro-detalle y pestañas encima).
- **9.30, 9.31, 9.32**, y los hallazgos **AD** (`ref_payco` se reverifica en cada recarga) y **los dos scripts de respaldo**, de los que solo uno funciona.

**Y bloqueando el rediseño:** **9.24**, observar un día en un salón. El hallazgo **AE** —que "ver todas las sedes" son dos interruptores sueltos en dos de dieciséis pantallas, y que la pantalla del dueño debería ser distinta de la del encargado de sede— **es material de D-219, no un parche.**

---

## 6. Lo que NO hay que hacer

- **No tocar lo que se cobra al mudar dónde se anota.** 50.000 siguen siendo 50.000 (D-239, D-222).
- **No devolver la dirección a "Datos del negocio".** Mientras dos casillas escriban `branches.address`, una pisa a la otra. El control 212 lo caza.
- **No preguntar el permiso por negocio cuando el dato es de la sede.** `is_owner_or_admin()` solo pregunta *"¿mandas en algún sitio?"*; con eso un admin de la sede A escribe la B. **Parece seguridad y no lo es.**
- **No quitar la `ValueKey` de la ficha del Panel.** Sin ella verías las sedes y los pagos de otro cliente bajo el nombre del que miras, sin un solo error (D-240).
- **No escribir una prueba que busque texto en el código sin quitar los comentarios antes.** Pasó hoy: la primera versión del guardián de D-238 **dio verde con la llamada comentada**.
- **No migrar antes de publicar** cuando la migración cambia una función que usa la app. De los dos huecos posibles, app-nueva contra base-vieja degrada con un aviso; al revés, revienta el guardado.
- **No dar por probado el camino del dinero sin un pago real.** Sigue en pie: falta el de sede.

---

## 7. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-238 a D-244).

Antes de tocar documentación: python scripts/verificar_documentos.py

D-239 decidió que el cobro va por SEDE, no por negocio, sin cambiar lo que
paga nadie. La sede ya tiene datos propios y dos puertas para escribirlos:
la del Panel (D-241) y la del salón (D-242), con la misma semántica.

Siguiente trabajo: 9.40 (historial desglosado por sede, con control propio)
y luego 9.41 (módulos por sede, servidor primero).

Todo aplicado y publicado. Controles 211, 212 y 213 en verde.
El rediseño de D-219 sigue bloqueado por el 9.24.
```
