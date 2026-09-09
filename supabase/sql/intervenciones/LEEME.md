# Intervenciones manuales sobre datos reales

**Esto NO son controles.** Los archivos de `supabase/sql/` son verificaciones:
terminan en `ROLLBACK`, no cambian nada, y se pueden correr cien veces.

Lo que vive aquí es lo contrario: **parches quirúrgicos que modificaron datos
reales una sola vez**, casi siempre dinero o estado de suscripción.

## Por qué existe esta carpeta (D-233, paso 9.11)

`activar_pago_naguara.sql` estaba junto a los nueve controles numerados,
indistinguible de ellos. Procesa un pago real de ePayco —$10.000 COP, ref
382618073— y **cambia el estado de una suscripción**. Alguien podría haberlo
corrido creyendo que era una prueba, y con el control 208 al lado el riesgo de
confusión creció en vez de bajar.

Tu propio `AGENTS.md` dice: *"No alterar el historial financiero, pagos,
comisiones o reservas sin trazabilidad."* Esta carpeta **es** esa trazabilidad.

## Reglas

1. **Nada de aquí se vuelve a correr.** Ya cumplió su cometido. Se conserva
   para saber qué se tocó, cuándo y por qué.
2. **Ninguno lleva número.** Los números son de los controles, y son
   idempotentes. Estos no.
3. **Cada archivo dice arriba qué modificó y con qué autorización.** Si no lo
   dice, no debería estar aquí.
4. Antes de escribir uno nuevo, preguntarse si el arreglo no debería ser una
   **migración** — que se versiona, se aplica una vez y queda en el historial.
   Una intervención manual es la última opción, no la primera.
