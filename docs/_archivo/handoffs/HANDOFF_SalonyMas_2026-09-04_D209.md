# HANDOFF Salón y Más — 4 de septiembre de 2026 ("Reporte a Sentry y adiós a las excepciones en pantalla", D-209)

**Bloque documentado:** decisión **D-209** · Paso **8.32** de la **FASE 8**.

**Estado:** ✅ **CERRADO.** `flutter analyze` 0/0 y **382 de 382 pruebas en verde** (6 nuevas). Sin migración SQL ni Edge Function.

> El bloque anterior (D-208) está archivado en
> `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-04_D208.md`.

---

## 1. Qué cambió

D-208 resolvió que los paneles de error no nombraran funciones de base de datos al salón, pero dejó anotado un problema de fondo: **los paneles descartaban `snapshot.error`**. El salón veía una tarjeta amigable, pero nadie en el equipo se enteraba de qué había fallado en producción.

Además, una auditoría automatizada destapó que **16 pantallas le mostraban `snapshot.error.toString()` en crudo al salón** (Agenda, Blog, Clientes, Gastos, Comisiones, Agenda Estilista, Reseñas Estilista, Fotos Estilista, Compras, Reportes, Reseñas, Servicios, Estilistas, Tickets, Usuarios, Fotos Trabajos e Inventario).

### La solución de arquitectura en tres partes:

1. **Helper `MonitoreoService.capturar<T>(accion, motivo: ...)`:**
   - Envuelve las llamadas asíncronas en los servicios (`lib/services/`).
   - Si la llamada falla, reporta la excepción a Sentry **exactamente una sola vez**, en el instante en que ocurre el fallo.
   - **Evita el spam de reportes:** no vive dentro de los `builder` de los widgets de Flutter, por lo que las reconstrucciones de interfaz (rebuilds) no disparan reportes duplicados.
   - Relanza (`rethrow`) la excepción intacta para que los `FutureBuilder` sigan detectando `hasError == true` y dibujen el estado visual correspondiente.

2. **Erradicación total de excepciones en pantalla:**
   - Se reemplazaron todas las llamadas a `snapshot.error.toString()` en las 16 pantallas por textos claros y orientados a la acción del salón:
     > *«Revisa tu conexión a internet o intenta nuevamente más tarde.»*

3. **Privacidad reforzada (Ley 1581):**
   - `MonitoreoService._limpiar` ahora sanitiza no solo los mensajes de evento, sino también los textos de excepción (`evento.exceptions[].value`), tapando correos y números telefónicos antes de que salgan a la red.

---

## 2. Los guardianes nuevos

Se incorporó la suite [`test/monitoreo_service_test.dart`](file:///c:/Proyectos/salonymas/test/monitoreo_service_test.dart) (6 pruebas):
- **Comportamiento:** verifica que `MonitoreoService.capturar` retorna datos limpios en éxito y relanza la excepción exacta en fallo.
- **Privacidad:** valida que correos (`[correo oculto]`) y números telefónicos (`[número oculto]`) se enmascaran automáticamente.
- **Guardián de interfaz:** analiza todo `lib/pages/` y **falla de inmediato** si alguna pantalla vuelve a pasar `snapshot.error.toString()` a un widget visual.

---

## 3. Qué NO hacer

- **No poner `snapshot.error.toString()` en la interfaz.** Hay un guardián que vigila todas las páginas.
- **No llamar a `MonitoreoService.reportarError` dentro del `builder` de un `FutureBuilder`**, porque dispararía en cada frame o reconstrucción del árbol de widgets. El reporte va en la capa asíncrona mediante `MonitoreoService.capturar`.
- **No enviar datos personales o PII a Sentry.** `sendDefaultPii` se mantiene estrictamente en `false`.

---

## 4. Lo que sigue abierto

1. El tercio de **TL-09**: la consulta de Tickets trae el historial completo (acotar rango o paginar).
2. Los tickets con `scheduled_at` nulo (hoy hay cero, D-204).
3. **HSTS** en el panel de Cloudflare — paso 8.25, 👤 propietario.
4. La otra mitad de **UX-07** (Nequi vs. Daviplata en BD y Reportes).
5. Fase 3 con dos casillas de 👤 abiertas (3.2 DIAN/IVA, 3.4 Supabase a Pro).
6. **De D-207, sin comprobar todavía:** dejar la pestaña más de una hora sin tocar y darle a renovar.

---

## 5. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-209: reporte sistemático de
errores técnicos a Sentry con MonitoreoService.capturar, saneamiento de
excepciones crudas en 16 pantallas y refuerzo de privacidad Ley 1581).

flutter analyze 0/0 y 382/382 pruebas en verde. Sin migración SQL.

Lo que sigue abierto, por orden de prioridad:
1. La otra mitad de UX-07 (Nequi vs Daviplata en BD y Reportes).
2. El tercio de TL-09: acotar la consulta histórica de Tickets.
3. HSTS (paso 8.25), del propietario en Cloudflare.
4. De D-207: probar en vivo dejar la pestaña >1h y renovar sesión.
```
