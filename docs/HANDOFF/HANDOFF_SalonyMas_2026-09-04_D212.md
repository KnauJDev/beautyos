# HANDOFF Salón y Más — 4 de septiembre de 2026 ("Corrección integral de Panel de Plataforma, Precios Pro y Checkout ePayco", D-212)

**Bloque documentado:** decisión **D-212** · Paso **8.35** de la **FASE 8**.

**Estado:** ✅ **CERRADO Y APLICADO.** `flutter analyze` 0/0 y **386 de 386 pruebas en verde** (1 nueva). Migración SQL `20260904180000_platform_pricing_fallback_pro_d212.sql` aplicada exitosamente en Supabase por el propietario.

> El bloque anterior (D-211) está archivado en
> `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-04_D211.md`.

---

## 1. Qué cambió

Se resolvieron los cuatro problemas identificados por el propietario en las capturas de producción:

1. **Chips de filtro en PlatformPanelPage sin truncamiento horizontal (Imagen 1):**
   - Se reemplazó la inclusión directa de emojis en el texto por la propiedad nativa `avatar: Icon(...)`.
   - Se configuraron `showCheckmark: false`, `labelPadding: EdgeInsets.symmetric(horizontal: 6)` y `visualDensity: VisualDensity.compact`.
   - El texto ya no se desborda en Flutter Web ni CanvasKit.

2. **Estado de prueba vencida dinámico (Imagen 1):**
   - Se incorporaron los getters `isTrialExpired` e `isTrialActive` en `PlatformTenantSummary` y `TenantSubscriptionStatus`.
   - `PlatformPanelPage` muestra la etiqueta `PRUEBA VENCIDA` en color naranja advertencia (`AppColors.warning`) cuando `trialEndsAt < now()`.
   - El banner superior de `main.dart` para el salón en prueba vencida muestra `⚠️ Prueba vencida · Activar plan` con fondo de advertencia.

3. **Fallback y unificación de Plan 'pro' ("Todo Incluido") en Tarifas Personalizadas (Imagen 2):**
   - Se unificó `PlatformPanelPage` para asignar el plan `pro` ("Todo Incluido — $150.000/mes por sede"), coherente con D-188.
   - Migración SQL `20260904180000_platform_pricing_fallback_pro_d212.sql` actualiza la RPC `platform_update_tenant_pricing`:
     * Mapea códigos de planes legacy (`profesional`, `basico`, `business` -> `pro`).
     * Realiza fallback automático al plan activo por defecto (`pro`) si el código no coincide.
     * Permite al propietario fijar cualquier precio pactado (ej. $10.000 COP) y motivo sin errores de plan inexistente.

4. **Resiliencia ante error 401 en ePayco Checkout (Imagen 3):**
   - En `lib/services/sesion_supabase.dart`, se añadieron `forzarRefresco()` y evaluación de márgenes de caducidad (< 5 min) en `necesitaRefresco()`.
   - En `lib/services/epayco_checkout_service.dart`, ante una respuesta HTTP 401 de la Edge Function, se ejecuta automáticamente un reintento transparente con `forzarRefresco()`.
   - Si persiste un fallo, se muestran mensajes claros en español amigables para el usuario.

---

## 2. Verificación y Suite de Pruebas

- **Análisis estático:** `flutter analyze` 0/0 (0 errores, 0 advertencias).
- **Suite de pruebas:** **386 de 386 pruebas en verde** (`flutter test`).
- **Migración en base de datos:** `20260904180000_platform_pricing_fallback_pro_d212.sql` aplicada mediante `scripts\aplicar_sql.ps1` contra producción.

---

## 3. Acciones para el Propietario

- Todas las acciones de este bloque están completadas. Probar el cambio de tarifa y el checkout en la aplicación web en producción.

---

## 4. Lo que sigue abierto

1. La otra mitad de **UX-07** (Nequi vs. Daviplata en BD y Reportes).
2. El tercio de **TL-09**: acotar la consulta histórica de Tickets.
3. **HSTS** en el panel de Cloudflare — paso 8.25, 👤 propietario.
4. Fase 3 con dos casillas de 👤 abiertas (3.2 DIAN/IVA, 3.4 Supabase a Pro).

---

## 5. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-212: corrección integral de panel
de plataforma, estado de prueba vencida, fallback plan pro y resiliencia ePayco).

flutter analyze 0/0 y 386/386 pruebas en verde.
Migración SQL aplicada en Supabase: 20260904180000_platform_pricing_fallback_pro_d212.sql

Próximo paso según Plan Maestro: continuar con las tareas de la Fase 8 o atender
observaciones de verificación en producción.
```
