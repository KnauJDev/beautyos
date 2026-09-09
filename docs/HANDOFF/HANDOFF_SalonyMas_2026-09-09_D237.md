# HANDOFF Salón y Más — 9 de septiembre de 2026 ("Red sobre las Edge Functions, y las sedes dejan de ser intocables", D-233 a D-237)

**Bloque documentado:** decisiones **D-233** a **D-237** · Fase **9**, pasos **9.6**, **9.11**, **9.35**, **9.36** y **9.37**.

**Estado:** ✅ Todo aplicado y verificado contra la base real. Controles **209** y **210** en verde.

> El bloque anterior está en `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-08_D232.md`.

---

## 1. La red que faltaba (D-234, paso 9.6)

`supabase/functions/` **no lo miraba nadie**. Y no era teórico: el 07-sep llegó a producción un `ReferenceError: calc is not defined` que tumbó el cobro.

Ahora el CI corre `deno check` **función por función con su propio `deno.json`**, en un trabajo aparte para que un fallo de Deno no tape uno de Flutter. **Primera corrida en verde:** las seis funciones están limpias.

**Se descartó** dejarlo en modo aviso. Un comprobador al que se le permite fallar no es un comprobador.

Y **D-233**: `activar_pago_naguara.sql` sale de entre los 199 controles idempotentes a `supabase/sql/intervenciones/`, con un LEEME que fija cuatro reglas. No se borra porque `AGENTS.md` pide trazabilidad sobre el historial financiero, y esa carpeta **es** la trazabilidad.

---

## 2. Las sedes, de invisibles a gobernables (D-235 a D-237)

Tres pasos que salieron uno del otro, cada uno destapado por una pregunta del propietario mientras probaba el anterior:

| | Qué faltaba | Cómo apareció |
|---|---|---|
| **9.35** | El Panel no dejaba ver el estado de cada sede | *"¿si aplico el pago a esa sede, dónde lo veré?"* |
| **9.36** | No había dónde tocar su precio | *"¿dónde modifico el precio del plan de la sede?"* |
| **9.37** | **No se podía QUITAR un precio pactado** | Borró el precio, guardó, y no pasó nada |

**El patrón, que ya va tres veces:** `platform_set_branch_subscription` existía desde D-190 y **no la llamaba nadie**. Antes pasó con `is_demo` (D-225) y con el lector de sedes. **Construir el motor y no el botón deja una función que envejece sin que nadie la pruebe** — y por eso D-222 prometía algo imposible de cumplir.

---

## 3. Los dos fallos de D-237, y lo que enseñan

**El que encontró el propietario:** `price_cop = coalesce(p_price_cop, price_cop)`. Pasar vacío **conserva** el valor, así que la función sabía poner y cambiar pero **nunca quitar**. Y el diálogo decía *"Vacío = tarifa vigente"*: la **regla 16-ter al revés** — la pantalla prometió algo que el servidor nunca supo hacer.

**El que apareció al arreglarlo, y era peor:** el campo se prellenaba con el precio **efectivo**, que sin acuerdo es el de lista. **Guardar sin tocar nada habría congelado el precio de lista como si alguien lo hubiera negociado**, y nadie lo habría notado hasta que la lista subiera.

Los dos arreglos son explícitos a propósito: un parámetro `p_limpiar_precio` en vez de darle a `null` un significado nuevo, y `tiene_precio_pactado` en el lector para que **la pantalla no deduzca un acuerdo comparando el texto "Precio de lista"** — una cadena pensada para leerse, decidiendo sobre dinero.

**Y una lección sobre los controles:** el 210 no cazó el fallo porque probaba **poner** precio y nunca **quitarlo**. *Un control que solo recorre el camino feliz tranquiliza igual que no tener ninguno.* Ahora tiene ocho comprobaciones y las dos nuevas son justo esas.

---

## 4. Lo que sigue

**Del propietario, y es lo único que bloquea el turno 2:**

- **9.7 y 9.8** — el pago de una **segunda sede**, lo único que verifica el P0 de D-224 contra dinero real. Naguara tiene dos sedes al día hasta el 22-sep.

**Mías, por orden de valor:**

- **9.9** — pruebas del Panel de Plataforma (4.230 líneas, y ahora con tres funciones nuevas encima).
- **9.30, 9.31, 9.32** — la URL quemada del webhook, el hallazgo AA, y `applies_after_discount`.
- **9.13 y 9.14** — sacar la lógica de dinero de las páginas grandes. **La ventana sigue abierta mientras no haya clientes reales.**

**Y bloqueando el rediseño:** **9.24**, observar un día en un salón. Sin eso, la reestructuración de D-219 es una hipótesis.

---

## 5. Lo que NO hay que hacer

- **No escribir un control que solo pruebe el camino feliz.** Lo que hay que vigilar es lo que la función **rechaza**.
- **No deducir estado de negocio comparando textos de interfaz.** «Precio de lista» es una etiqueta para leer, no una bandera (D-237).
- **`create or replace` no basta** si cambia el tipo de retorno o la lista de parámetros: exige `DROP`. Costó una corrida el 09-sep.
- **No dar por probado el camino del dinero sin un pago real.** Sigue en pie: falta el de sede.

---

## 6. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-233 a D-237).

Antes de tocar documentación: python scripts/verificar_documentos.py

Todo aplicado. Falta un pago real de una segunda sede (9.7 y 9.8), que es lo
único que verifica el P0 de D-224.

Siguiente trabajo de código: 9.9 (pruebas del Panel), y luego 9.30 a 9.32.
El rediseño de D-219 sigue bloqueado por el 9.24: observar un día en un salón.
```
