# HANDOFF Salón y Más — 4 de septiembre de 2026 ("Blindaje total de excepciones en UI, sanitización de breadcrumbs en Sentry y guardián ampliado", D-210)

**Bloque documentado:** decisión **D-210** · Paso **8.33** de la **FASE 8**.

**Estado:** ✅ **CERRADO.** `flutter analyze` 0/0 y **383 de 383 pruebas en verde** (7 en la suite de monitoreo). Sin migración SQL ni Edge Function.

> El bloque anterior (D-209) está archivado en
> `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-04_D209.md`.

---

## 1. Qué cambió

D-209 instrumentó `MonitoreoService.capturar` y saneó `snapshot.error.toString()` en 16 páginas. Una auditoría técnica exhaustiva sobre ese cambio identificó tres frentes de mejora para completar el blindaje de producción:

1. **Sanitización de Breadcrumbs en Sentry (Ley 1581):**
   - El SDK `sentry_flutter` captura automáticamente llamadas a `debugPrint` o logs como *breadcrumbs*.
   - Se extendió `MonitoreoService._limpiar` para sanitizar `evento.breadcrumbs` (ocultando correos y números telefónicos) y se agregó `_telefonoConEspacios` para reconocer formatos colombianos con espacios o guiones (ej. `300 123 4567`, `+57 300 123 4567`).
   - Se expuso el helper `@visibleForTesting static SentryEvent limpiarEventoParaPruebas(SentryEvent evento)` para probar de punta a punta el saneamiento.

2. **Erradicación de Fugas Residuales en UI:**
   - Se sanearon 6 archivos que aún mostraban `${snapshot.error}` o excepciones crudas en widgets y diálogos:
     - `lib/pages/dashboard_page.dart`: línea 256 en carga de KPIs.
     - `lib/pages/settings_page.dart`: línea 2014 en `_SedesCard`.
     - `lib/pages/authenticated_router.dart`: línea 62 en fallo de enrutamiento.
     - `lib/widgets/publication_studio_dialog.dart`: línea 146 en fallo de carga de estudio.
     - `lib/main.dart`: línea 818 en fallo de carga de sedes.
     - `lib/widgets/security_settings_dialog.dart`: línea 234 en fallo de autenticación de seguridad.

3. **Guardián de Excepciones Ampliado:**
   - `test/monitoreo_service_test.dart` amplió su búsqueda a `lib/pages/`, `lib/widgets/` y `lib/main.dart` para detectar cualquier variante de `snapshot.error` (`.toString()`, `${snapshot.error}`, etc.).
   - Mantiene una lista blanca explícita y documentada con su motivo únicamente para paneles de diagnóstico de superadministrador de plataforma (`platform_panel_page.dart`, `platform_tenant_detail_page.dart`).

---

## 2. Los guardianes vigentes

La suite [`test/monitoreo_service_test.dart`](file:///c:/Proyectos/salonymas/test/monitoreo_service_test.dart) (7 pruebas en verde) valida:
- Retorno de valor exitoso y relanzamiento (`rethrow`) intacto de excepciones.
- Sanitización de correos electrónicos.
- Sanitización de números telefónicos de 7 a 15 dígitos y con espacios.
- Preservación de identificadores técnicos legítimos (códigos de estado, nombres de RPC).
- Limpieza integral de un `SentryEvent` completo (`message`, `exceptions[].value`, `breadcrumbs[].message`).
- Guardián recursivo de UI sobre páginas, widgets y `main.dart`.

---

## 3. Qué NO hacer

- **No exponer `snapshot.error` ni variantes `${snapshot.error}` en interfaces de cara al salón o al público.**
- **No deshabilitar la sanitización de breadcrumbs ni elevar `sendDefaultPii` a `true`.**
- **No omitir `MonitoreoService.capturar` en nuevas llamadas asíncronas de servicios.**

---

## 4. Lo que sigue abierto

1. La otra mitad de **UX-07** (Nequi vs. Daviplata en BD y Reportes).
2. El tercio de **TL-09**: acotar la consulta histórica de Tickets.
3. **HSTS** en el panel de Cloudflare — paso 8.25, 👤 propietario.
4. Fase 3 con dos casillas de 👤 abiertas (3.2 DIAN/IVA, 3.4 Supabase a Pro).
5. **De D-207, sin comprobar todavía:** dejar la pestaña más de una hora sin tocar y darle a renovar.

---

## 5. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-210: blindaje total de
excepciones en UI, sanitización de breadcrumbs en Sentry y guardián ampliado).

flutter analyze 0/0 y 383/383 pruebas en verde. Sin migración SQL.

Lo que sigue abierto, por orden de prioridad:
1. La otra mitad de UX-07 (Nequi vs Daviplata en BD y Reportes).
2. El tercio de TL-09: acotar la consulta histórica de Tickets.
3. HSTS (paso 8.25), del propietario en Cloudflare.
4. De D-207: probar en vivo dejar la pestaña >1h y renovar sesión.
```
