# HANDOFF Salón y Más — 16 de septiembre de 2026 ("El cobro se muda a la sede, y el Panel deja de ser una lista con ventanitas", D-238 a D-240)

**Bloque documentado:** decisiones **D-238** a **D-240** · Fase **9**, pasos **9.38** y **9.39**.

**Estado:** ✅ D-238 **verificado en producción**. D-239 y D-240 escritos y en verde local — **falta publicar D-240**.

> El bloque anterior está en `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-09_D237.md`.

---

## 1. Lo que de verdad pasó hoy: una decisión de producto, no una pantalla

El propietario pidió partir el Panel en dos y, al explicar qué quería ver, dijo otra cosa:

> *"Los pagos estarán amarrados a cada sede, no al negocio en sí."*

Eso es **D-239**, y es lo más importante del día. El modelo, en cinco frases:

1. Todo dueño tiene mínimo una sede, y se le crea al inscribirse.
2. **El que cobra es la sede.**
3. Cada sede lleva su propio historial de pagos y activaciones.
4. Hacia arriba todo se suma: el dueño ve sus sedes juntas o por separado.
5. El dueño de plataforma elige **qué módulos ve cada sede**, aunque el plan dé derecho a todos.

**Y lo que NO cambia, preguntado explícitamente antes de escribir una línea:** un socio de diseño de una sola sede **sigue pagando 50.000**. Los 50.000 congelados de D-222 se anotan ahora en su sede principal. La lectura alternativa —el negocio cobra *y además* cada sede— lo habría subido a **130.000**, rompiendo lo prometido en público. El propietario confirmó la primera.

**Si alguien vuelve a abrir esto, esa frase es la que hay que releer.**

---

## 2. Los $80.000 contra los $10.000 no eran un fallo

Llevaban días sin explicación. El lector de sedes hace `coalesce(bs.price_cop, p.price_cop)`: esa sede no tiene precio pactado y **cae al de lista, que es 80.000** (D-188). El negocio sí tiene uno pactado: 10.000.

**Las dos cifras eran ciertas a la vez, porque no estaba decidido quién paga.** Un modelo a medio migrar no es neutral: produce pantallas que no mienten y aun así no se pueden creer. Esa fue la prueba de que D-239 hacía falta.

---

## 3. Medir antes de escribir ahorró el 80% del trabajo

Antes de proponer nada se verificó pieza por pieza qué existía ya:

| Lo pedido | Estado real |
|---|---|
| Al inscribirse se crea su sede | Ya pasa (`register_tenant`) |
| El cobro va amarrado a la sede | **Ya existe entero**: `branch_id` en el intento (D-191), `beautyos_procesar_pago_de_sede` (D-192), checkout (D-224) |
| Precio, estado y vencimiento por sede | Ya existe (D-190, D-236, D-237) |
| El MRR cuenta las sedes | Ya existe (D-232) |
| Informes consolidados multisede | Ya existe (D-194) |
| **Historial que diga de qué sede** | ❌ Falta — paso **9.40** |
| **Módulos por sede** | ❌ No existe en ninguna capa — paso **9.41** |

**La tubería estaba puesta al 80%.** Lo que faltaba no era construirla: era decidirlo y enseñarlo.

---

## 4. D-240: el Panel partido en dos (paso 9.39)

Las cinco secciones del bosquejo **ya existían** dentro de `_TenantDetailSheet`. El trabajo no era crearlas: era sacarlas de la hoja emergente.

**La trampa que se buscó antes de empezar:** cada acción hacía `Navigator.pop()`. Empotrada, eso cerraría el Panel entero. Resultó que esos cierres viven en los *callbacks del llamador*, no en el cuerpo de la ficha —dentro solo había uno, el botón X—, así que **las 1.100 líneas del cuerpo no se tocaron**.

**Tres cuidados que no se ven pero deciden si funciona:**

- **`ValueKey` por negocio.** Sin ella, cambiar de negocio reaprovecha el estado y `initState` no vuelve a correr: verías **las sedes y los pagos del anterior bajo el nombre del nuevo, sin un solo error en rojo**. Es D-211 otra vez, ahora con dinero.
- **La selección se revalida por identificador en cada construcción.** Tras aprobar o suspender, `reload()` trae objetos nuevos y el guardado seguiría diciendo "POR APROBAR" después de aprobarlo. Se busca en la lista **sin filtrar**, para que cambiar de filtro no vacíe la ficha.
- **La tarjeta izquierda pierde los botones de gestión.** Su fila de cinco se desborda en 400 px, sí — pero sobre todo: **un botón que toca dinero desde una fila de lista no deja ver a quién se lo estás tocando.** La lista elige; la derecha actúa.

**Y las sedes suben a tarjeta propia**, desde donde estaban enterradas dentro de la tarjeta 1. Con el cobro yendo por sede, tenerlas tres pantallazos por debajo del nombre era esconder lo único que hay que mirar.

Por debajo de **1.000 px no cambia nada**: dos columnas en 400 px no son dos columnas.

---

## 5. Lo que sigue

**Del propietario:**

- **Publicar D-240** (`git push`) y mirar el Panel en una ventana ancha.
- **9.7 y 9.8** — sigue pendiente el pago real de una **segunda sede**, lo único que verifica el P0 de D-224 contra dinero real.

**Mías, por orden:**

- **9.40** — el historial desglosado por sede. El dato existe desde D-191 y el modelo lo tira. **Toca dinero: lleva control propio.**
- **9.41** — módulos por sede. Servidor primero; la app son 3 archivos. **Ojo:** al cambiar de sede hay que volver a resolver los módulos, que es la misma costura de D-238.
- **9.9** — pruebas del Panel (4.700 líneas y ahora con maestro-detalle encima).
- **9.30, 9.31, 9.32** y **AD** (el `ref_payco` que se reverifica en cada recarga).

**Y bloqueando el rediseño:** **9.24**, observar un día en un salón. El hallazgo **AE** de hoy —que "ver todas las sedes" son dos interruptores sueltos en dos de dieciséis pantallas, y que la pantalla del dueño de negocio debería ser distinta de la del encargado de sede— **es material de D-219, no un parche.**

---

## 6. Lo que NO hay que hacer

- **No tocar lo que se cobra al mudar dónde se anota.** 50.000 siguen siendo 50.000 (D-239, D-222).
- **No quitar la `ValueKey` de la ficha.** El fallo que evita no da error: enseña el dinero de otro cliente. Hay guardián.
- **No escribir una prueba que busque texto en el código sin quitar los comentarios antes.** Pasó hoy: la primera versión del guardián de D-238 **dio verde con la llamada comentada**. Ya había pasado verificando un precio contra un `50.00` escrito en una explicación.
- **No dar por probado el camino del dinero sin un pago real.** Sigue en pie: falta el de sede.

---

## 7. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-238 a D-240).

Antes de tocar documentación: python scripts/verificar_documentos.py

D-239 decidió que el cobro va por SEDE, no por negocio, sin cambiar lo que
paga nadie. La tubería ya existía al 80%; falta enseñarlo.

Siguiente trabajo: 9.40 (historial desglosado por sede, con control propio)
y luego 9.41 (módulos por sede, servidor primero).

D-240 está sin publicar: hay que hacer git push y mirarlo en ventana ancha.
El rediseño de D-219 sigue bloqueado por el 9.24.
```
