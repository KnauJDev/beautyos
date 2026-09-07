# HANDOFF Salón y Más — 7 de septiembre de 2026 ("La auditoría verificada y el pionero sin 50%", D-220 y D-221)

**Bloque documentado:** decisiones **D-220** y **D-221** · Fase **9**, paso **9.28**.

**Estado:** ✅ Documentación al día y migración escrita. ⚠️ **La migración no está aplicada en Supabase.**

> El bloque anterior (D-217 a D-219) está en `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-07_D219.md`.

---

## 1. La auditoría de Antigravity, verificada (D-220)

Primera revisión bajo D-218. **Se comprobó cada afirmación contra el código antes de aceptarla**, y el resultado justifica las dos mitades de esa decisión.

| | |
|---|---|
| **Real** | 6 hallazgos, incluido un **P0 que nadie había visto** |
| **Dormido** | 1 — `applies_after_discount`, inofensivo hasta que existan descuentos |
| **Inventado** | 2 detalles falsos y 2 archivos que no existen |

**El P0:** `verify-epayco-transaction` no menciona `branch_id` ni una vez y llama siempre a `beautyos_procesar_evento_epayco`. El webhook sí bifurca a `beautyos_procesar_pago_de_sede`, pero llega después, encuentra el evento ya insertado y **aborta por idempotencia**. Resultado: **se paga una sede secundaria, el dinero sale, y la sede queda en `pending` para siempre.** Nadie lo había visto porque nadie ha pagado una segunda sede todavía. Es el paso **9.27**.

**Lo inventado, para que conste:** dijo que dos funciones repiten la cascada de `SERVICE_ROLE_KEY` (no la tocan); nombró la RPC del cálculo como `beautyos_obtener_monto_cobro` (no existe); y citó `02_audit_suite.sql` y `03_smoke_test.sql` como ejemplos de una carpeta donde no están.

**Y un hallazgo propio, peor que el denunciado.** Antigravity culpó al script de Naguara de contaminar las métricas. La consulta a producción mostró **los tres negocios en `is_demo = false`**, y el script solo tocó uno:

```
Naguara de Uñas        false   24-jul
Prueba Barbería Elite  false   16-ago
Exportadora            false   21-ago
```

La causa real: **D-120 creó la marca `is_demo` con un `update` a mano dentro de una migración y nunca dejó forma de ponerla** — no hay RPC ni botón. Los dos negocios posteriores nacieron con el `default false` y nadie los marcó. **Las métricas del SaaS llevan meses contando ensayos.** Es el paso **9.29**.

---

## 2. El pionero vuelve a ser una etiqueta (D-221, paso 9.28)

D-188 y D-189 abolieron el "50% de pionero" con su razón escrita: *deja de ser un porcentaje y pasa a ser precio pactado, uno a uno*. La migración de D-212 lo volvió a meter:

```sql
if p_is_founder is true then
  v_discount_percent := coalesce(v_discount_percent, 50.00);
```

**Marcar la casilla "Pionero" a un salón pactado en 80.000 le clavaba 75.000.** Y el 07-sep se anunció en público una tarifa preferencial para 10 salones (D-217): la primera vez que se usara esa casilla, habría roto el primer acuerdo.

**Ahora** `is_founder` no calcula nada, y marcar pionero **sin precio ni descuento explícito falla a propósito**, citando D-188 y D-189 en el mensaje. Mismo principio del hallazgo W: en el camino del dinero, adivinar es peor que fallar a la vista.

Se conserva el fallback de *plan* de D-212 — resolver un código retirado al plan activo no inventa dinero.

Migración: `20260907120000_pionero_sin_porcentaje_automatico_d221.sql`.

---

## 3. Lo siguiente, en orden

El Plan Maestro tiene ahora una tabla de **orden de ejecución** al principio de la Fase 9. Los bloques A-F agrupan por tema; la tabla dice en qué orden se hacen.

**Turno 1 — La puerta del piloto:**

1. 👤 **Aplicar `20260907120000`** con `scripts\aplicar_sql.ps1`, con respaldo previo.
2. 👤 **Paso 9.22 — fijar la tarifa pionera.** Ya no se sobrescribe sola.
3. **Paso 9.29 —** marcar los tres negocios de prueba **y** dar una forma de hacerlo desde el Panel.
4. 👤 **Paso 9.19 —** decidir qué pasa con los negocios de prueba antes de que entre uno real.
5. 👤 **Paso 9.15 —** Supabase a Pro. En el gratuito no hay recuperación a un punto en el tiempo.

**Turno 2 — El camino del dinero:** 9.27 (el P0), 9.10, 9.7, 9.8.

---

## 4. Lo que NO hay que hacer

- **No marcar a nadie como Pionero hasta aplicar la migración.** Hasta entonces la base sigue clavando el 50%.
- **No fiarse de las métricas del SaaS** hasta cerrar el 9.29. Cuentan tres negocios de ensayo con sus tickets falsos.
- **No aceptar un hallazgo de Antigravity sin verificarlo contra el código.** Un tercio de esta auditoría eran detalles inventados, escritos con el mismo aplomo que los reales.
- **No implementar los 5 lugares antes del 9.24** (sigue vigente de D-219).

---

## 5. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-220 y D-221: la auditoría
verificada y el pionero sin 50%).

La migración 20260907120000 está escrita pero NO aplicada. Hasta aplicarla, marcar
"Pionero" sigue pisando el precio pactado.

Orden vigente: la tabla de "orden de ejecución" al principio de la Fase 9 del Plan
Maestro. Turno 1 son cinco pasos y tres son del propietario.
```
