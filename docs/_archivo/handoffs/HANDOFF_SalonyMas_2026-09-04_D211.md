# HANDOFF Salón y Más — 4 de septiembre de 2026 ("Guardián de lista blanca, sanitización de fijos/Postgres y FutureBuilder blindado", D-211)

**Bloque documentado:** decisión **D-211** · Paso **8.34** de la **FASE 8**.

**Estado:** ✅ **CERRADO.** `flutter analyze` 0/0 y **385 de 385 pruebas en verde** (9 en la suite de monitoreo). Sin migración SQL ni Edge Function.

> El bloque anterior (D-210) está archivado en
> `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-04_D210.md`.

---

## 1. Qué cambió

Se resolvieron los cuatro puntos de auditoría sobre D-210:

1. **Guardián de excepciones muertas para la lista blanca:**
   - Se añadió la prueba `las excepciones de la lista blanca siguen haciendo falta` en `test/monitoreo_service_test.dart`.
   - Vigila que cada archivo en la lista blanca (`platform_panel_page.dart`, `platform_tenant_detail_page.dart`) contenga activamente al menos una ocurrencia de `snapshot.error`. Si se limpian en el futuro, la prueba falla sola exigiendo remover la excepción.
   - Se eliminó código muerto inalcanzable en el scanner del guardián.

2. **Residuos de sanitización cubiertos (Ley 1581):**
   - `_telefonoConEspacios` se amplió para cubrir números fijos colombianos formateados con espacios (`601 765 4321`, `604 123 4567`, etc.) además de celulares.
   - Se añadió `_postgresKeyDetails` para sanitizar detalles de violaciones de restricción de unicidad de base de datos (`Key (nombre)=(María Restrepo)` -> `Key ([campo])=([valor oculto])`), evitando que nombres de clientas o datos de negocio viajen a Sentry en excepciones de Postgres.

3. **Blindaje contra re-disparos en FutureBuilder:**
   - Se convirtieron `_Level2Sheet` (`lib/pages/agenda_page.dart`) y `_TenantDetailSheet` (`lib/pages/platform_panel_page.dart`) a `StatefulWidget`, inicializando sus `Future` (`_boardListFuture` y `_historyFuture`) en `initState()`.
   - Esto garantiza que arrastrar o redimensionar los modales no recree los futures ni genere llamadas a base de datos ni reportes duplicados a Sentry.

---

## 2. Los guardianes vigentes

La suite [`test/monitoreo_service_test.dart`](file:///c:/Proyectos/salonymas/test/monitoreo_service_test.dart) (9 pruebas en verde) valida:
- Retorno de valor exitoso y relanzamiento (`rethrow`) intacto de excepciones.
- Sanitización de correos electrónicos.
- Sanitización de celulares y teléfonos fijos con espacios.
- Sanitización de violaciones de claves en errores de Postgres (`Key constraint`).
- Preservación de identificadores técnicos legítimos.
- Saneamiento integral de un `SentryEvent` (`message`, `exceptions`, `breadcrumbs`).
- Guardián recursivo de UI sobre páginas, widgets y `main.dart`.
- Guardián de excepciones muertas para la lista blanca.

---

## 3. Qué NO hacer

- **No crear Futures inline en el `builder` de un `FutureBuilder` dentro de hojas modales o widgets con scroll.** Deben inicializarse en `initState()`.
- **No exponer `snapshot.error` en interfaces de cara al salón.**

---

## 4. Lo que sigue abierto

1. **Revisión prioritaria de Pagos y Generación de Precios** (reportado por el propietario).
2. La otra mitad de **UX-07** (Nequi vs. Daviplata en BD y Reportes).
3. El tercio de **TL-09**: acotar la consulta histórica de Tickets.
4. **HSTS** en el panel de Cloudflare — paso 8.25, 👤 propietario.
5. Fase 3 con dos casillas de 👤 abiertas (3.2 DIAN/IVA, 3.4 Supabase a Pro).

---

## 5. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-211: guardián de lista blanca,
sanitización de fijos/Postgres y FutureBuilder blindado).

flutter analyze 0/0 y 385/385 pruebas en verde. Sin migración SQL.

Prioridad inmediata:
- Revisar y diagnosticar el flujo de cobros/pagos y generación de precios
  reportado por el propietario antes de continuar con la hoja de ruta general.
```
