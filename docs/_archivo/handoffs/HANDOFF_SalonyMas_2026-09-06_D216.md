# HANDOFF Salón y Más — 6 de septiembre de 2026 ("Nace la Fase 9: puesta a punto antes del cliente cero", D-216)

**Bloque documentado:** decisión **D-216** · **FASE 9**, bloque A cerrado.

**Estado:** ✅ **Bloque A cerrado (4 de 5 pasos; el 9.5 es 👤).** Quedan los bloques B a F, 17 pasos.

> El bloque anterior (D-215, misma fecha) está archivado en
> `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-06_D215.md`.

---

## 1. Por qué existe la Fase 9

El MVP está listo, el cobro funciona desde hoy (D-215) y **no hay ni un cliente real: todos los negocios de la base son de prueba.** Es el momento más barato de toda la vida del producto para ordenar la estructura: con un salón real dentro, cada cambio arriesga las citas y el dinero de otra persona.

Son **21 pasos en seis bloques**, con dos reglas de orden que no se negocian:

- **A va primero**, porque no se puede planificar sobre documentos que mienten.
- **C (ensayo general) va antes que D (refactor)**, porque recorrer el producto entero como una dueña nueva dice qué duele de verdad. Refactorizar sin esa información es adivinar caro.

---

## 2. Qué se cerró hoy (bloque A)

**9.1 — El §6 del README, archivado, no borrado.** Eran 248 entradas cronológicas mantenidas a mano. Están íntegras en `_archivo/REGISTRO_CRONOLOGICO_HASTA_2026-09-06.md`. El §6 pasa a explicar las tres órdenes de `git log` que responden lo mismo sin desincronizarse nunca. **El README baja de 371 a 135 líneas.**

**9.2 — Marcadores de estado contradictorios.** Eran **cinco**, no las tres que se habían visto: 8.8, 8.10, 8.11, 8.12 y 8.13 empezaban la celda en 🔄 y la terminaban en ✅ CERRADO.

> ⚠️ **Y aquí hubo un susto que conviene no olvidar.** El primer reemplazo arrastró también al **paso 8.9, que SÍ está abierto** — es TL-01, pendiente de verificar contra una transacción real. Se detectó al releer lo escrito (regla 6 del apartado 8) y se devolvió a 🔄. **Un reemplazo por patrón sobre una tabla de estados es exactamente el tipo de cambio que hay que releer antes de dar por bueno.**

**9.3 — Un número, un sitio.** Los recuentos copiados se **quitaron** en vez de actualizarse, que es lo que manda D-131: los números exactos viven en su fuente y los índices dejan de repetirlos. Apareció de paso que la "Regla de actualización" del README mandaba actualizar el `PLAN_DE_LANZAMIENTO`, **archivado el 09-ago por D-126**: una regla apuntando a un documento que ya no manda.

**9.4 — Fuera los tamaños caducados** de la tabla de módulos: decía que Tickets tenía 3.699 líneas (tiene 5.121) y Agenda 234 (tiene 1.797).

**Además:** el paso 8.38 ahora apunta a 9.6 en vez de duplicarlo, y 8.9 anota que se desplegó el 06-sep y que su verificación pasa a ser el 9.7.

---

## 3. Dónde seguir

**El siguiente paso es el 9.5, y es tuyo:** decidir qué pasa con los 51 `.txt` de OneDrive que cuentan la misma historia que los 61 `.md` de `_archivo/handoffs/` con otra numeración.

Después, el bloque B (red donde pasa el dinero), en este orden:

| Paso | Qué | Quién |
|---|---|---|
| 9.6 | `deno check` en el CI | 🤖 |
| 9.7 | 🔴 Verificar TL-01 contra una transacción real | 👤 |
| 9.8 | Ciclo completo de cobro: pago → webhook → activación | 👤 |
| 9.9 | Pruebas de precios y aprobaciones en el Panel de Plataforma | 🤖 |
| 9.10 | Decidir el hallazgo W | 👤 |
| 9.11 | Sacar `activar_pago_naguara.sql` de los scripts de verificación | 🤖 |

---

## 4. Lo que NO hay que hacer

- **No saltar al bloque D.** Es tentador partir `tickets_page.dart` ya. El ensayo general (9.12) puede decir que hay algo que duele más.
- **No dar por cerrado el paso 8.9 / 9.7.** Está desplegado, no verificado. Son cosas distintas.
- **No volver a copiar un recuento en un índice.** Es la enfermedad que D-126, D-131 y ahora D-216 tratan, y siempre vuelve por el mismo sitio: alguien escribe "las 216 decisiones" en un encabezado y a la semana son 219.

---

## 5. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-216: nace la Fase 9, puesta a punto
antes del cliente cero; bloque A cerrado).

El cobro funciona (D-215) y no hay clientes reales todavía: la base es de prueba.

Próximo paso: el 9.5 lo decide el propietario. Luego el bloque B, empezando por el
9.6 (deno check en el CI), que es el que habría cazado el fallo de D-215.
```
