# HANDOFF Salón y Más — 16 de agosto de 2026

**Bloque documentado:** decisión **D-138** · Paso 3.7: Filtro de Aceptación ("Nadie entra solo" - D-125)
**Estado:** migración SQL `20260816100000_filtro_aceptacion_registro.sql` aplicada y verificada en producción (`beautyos-dev`) por el propietario con solicitud real ("Prueba Barbería Élite" / `elboga007@gmail.com`). 98 pruebas unitarias en verde y `flutter analyze` 100% limpio.
**Reemplaza como handoff vigente a:** `HANDOFF_SalonyMas_2026-08-12.md` (archivado en `docs/_archivo/handoffs/`)

---

## 1. Dónde estamos

```
Fase 0  Que exista en internet        ✅
Fase 1  Que sea seguro compartirla    ✅
Fase 2  Seguridad                     ✅ CERRADA (12-ago) — 7 de 7
Fase 3  Poder cobrar                  🔄  ← AQUÍ
        3.1  ePayco admite recurrencia    ✅
        3.5  Precios y límites            ✅ CERRADO (12-ago)
        3.6  Precio por cliente           ✅ CERRADO (12-ago)
        3.7  Filtro de aceptación         ✅ CERRADO HOY (D-138)
        3.12 Correos de cuenta por Resend ✅
        3.8–3.11  Planes públicos, ePayco, avisos  ⬜ 🤖  ← LO SIGUIENTE
        3.2  Contador (DIAN, IVA)         ⬜ 👤
        3.3  Términos y privacidad        ⬜ 👥  Ley 1581, obligatorio
        3.4  Supabase Pro (~25 USD/mes)   ⬜ 👤
        3.13 Traducir los correos         ⬜ 👥  hallazgo W
Fase 4  Pulido módulo a módulo        🔄 4.1 ✅
```

---

## 2. Qué pasó en este bloque (Paso 3.7 / D-138)

El registro self-serve anterior permitía que cualquier persona que creara cuenta entrara de inmediato en prueba de 21 días (`trialing`). Si el equipo tardaba días en contactarlo, la prueba corría en vacío y se perdía la oportunidad de dar un onboarding de bienvenida guiado (D-125).

### Lo que se construyó:

1. **Base de Datos y Migración SQL (`supabase/migrations/20260816100000_filtro_aceptacion_registro.sql`):**
   - **Campos del cuestionario en `tenants`:** `city`, `estimated_branches`, `estimated_team_size`, `referral_source`, `rejection_reason`.
   - **Estado `rejected` en `tenant_subscriptions`:** añadido al check constraint de status.
   - **`register_tenant` actualizado:** recibe los datos del formulario, crea el negocio y su suscripción en estado `'pending'` con `trial_ends_at = NULL` (el reloj no corre).
   - **Bloqueo de compromisos:** `private.beautyos_tenant_accepts_new_commitments` devuelve `false` para tenants en estado `'pending'`, impidiendo citas prematuras.
   - **RPC `get_my_tenant_subscription_status()`:** consulta el estado de aprobación/suscripción del negocio en sesión.
   - **RPC `platform_approve_tenant(...)`:** el `platform_owner` aprueba la solicitud, arranca la prueba de 21 días (`now() + trial_days`), asigna el plan (Profesional por defecto) y aplica la bandera de Pionero (50% de por vida) o tarifas especiales con motivo.
   - **RPC `platform_reject_tenant(...)`:** rechaza la solicitud guardando el motivo de forma respetuosa sin borrado físico (D-051/D-056).
   - **`platform_list_tenants()`:** expone las columnas del cuestionario y prioriza solicitudes pendientes arriba.

2. **Frontend Flutter:**
   - **`CompleteTenantSetupPage`:** formulario enriquecido y visual con nombre de negocio, tipo, nombre del dueño, WhatsApp, ciudad, sedes, equipo y medio por el que conoció Salón y Más.
   - **`TenantApprovalStatusPage`:** pantalla dedicada para el solicitante cuando su cuenta está en revisión (`pending`), con botón para consultar si ya fue aprobado y botón para contactar a soporte vía WhatsApp/correo. Si fue rechazada, muestra el motivo.
   - **`PlatformPanelPage`:** barra de filtros con pestaña de solicitudes pendientes destacada, tarjeta con detalles completos del cuestionario, diálogo de aprobación con selector de plan / switch Pionero 50% / días de prueba, y diálogo de rechazo con motivo.
   - **`main.dart`:** integrado en el flujo de arranque de `BeautyOSHome`.

3. **Pruebas y Verificación:**
   - **Script SQL de prueba:** `supabase/sql/168_test_filtro_aceptacion.sql` valida en bloque aislado (`ROLLBACK`) los 9 controles del filtro de aceptación.
   - **Pruebas unitarias de Flutter:** `test/filtro_aceptacion_test.dart` añadido; suite total ejecutada con éxito: **98 de 98 pruebas en verde** (`flutter test`).
   - **`flutter analyze`:** 0 advertencias, 0 errores.

### Correcciones y mejoras post-despliegue (mismo día):

1. **Fix: `column reference "status" is ambiguous` en `register_tenant`:**
   - Causa: la consulta `where status = 'active'` en `plans` se confundía con la columna de retorno `status text`.
   - Solución: calificar con alias `p.status` tanto en `register_tenant` como en `platform_approve_tenant`.

2. **Fix: `column "updated_at" of relation "tenants" does not exist` en `platform_approve_tenant`:**
   - Causa: la tabla `tenants` no tiene columna `updated_at` (la tabla `tenant_subscriptions` sí).
   - Solución: eliminar `updated_at = now()` del `UPDATE public.tenants` en `platform_approve_tenant` y `platform_reject_tenant`.

3. **Mejora UX: Botón "Contactar al equipo de soporte" ahora abre WhatsApp directo:**
   - Antes: copiaba texto al portapapeles (poco intuitivo).
   - Ahora: abre `wa.me/573159780158` con mensaje prellenado incluyendo el nombre del negocio.
   - Fallback: si WhatsApp no está disponible, abre `mailto:hola@salonymas.com`.
   - Se agregó `url_launcher: ^6.3.1` al proyecto.

4. **Mejora UX: Sección "Soporte" en Configuración (`settings_page.dart`):**
   - Nueva tarjeta con dos botones: WhatsApp (verde `AppColors.whatsapp`) y Correo.
   - Muestra el número y correo visualmente.
   - Permite a cualquier dueño de negocio contactar a soporte en cualquier momento, no solo en la pantalla de espera.

5. **Seguridad y Blindaje RLS (Decisión D-139 / Auditoría Claude Code):**
   - **`public.tenants` y `public.user_profiles`:** habilitado `ENABLE ROW LEVEL SECURITY` con política de aislamiento estricta (`tenant_isolation_select` y `user_profiles_isolation_select`) que solo permite lectura a los miembros del propio salón o al `platform_owner`.
   - **`platform_approve_tenant`:** guard de estado añadido; solo permite aprobar negocios en estado `'pending'` o `'rejected'`, impidiendo sobreescrituras accidentales de planes o reseteo de pruebas a clientes activos.
   - **`platform_reject_tenant`:** guard de estado añadido; solo permite rechazar solicitudes en estado `'pending'`.
   - **Migración:** `supabase/migrations/20260816170000_blindaje_rls_tenants_y_guards_aprobacion.sql`.
   - **Script de prueba:** `supabase/sql/169_test_blindaje_rls_tenants.sql`.

6. **Pantalla Pública de Planes y Precios (Paso 3.8 / Decisión D-140):**
   - **`PublicPlan` y `PublicPlanFeature`:** modelos que agrupan dinámicamente las filas de `list_public_plans()`, formatean precios en COP (`$160.000`, `$200.000`, `$240.000`) y resuelven límites.
   - **`PublicPlansService`:** servicio que consume la RPC pública con catálogo de respaldo estático (D-124 / D-136) para garantizar disponibilidad permanente.
   - **`PublicPlansPage`:** interfaz pública moderna y responsiva (grid de escritorio / lista en móvil), tarjetas comparativas con Business destacado como "MÁS ELEGIDO", tabla comparativa detallada, sección de FAQ y botones directos a WhatsApp de asesoría y registro rápido.
   - **Enrutamiento:** acceso sin sesión vía query param `?planes=1` / `?pricing=1` en `main.dart`, y enlaces directos en `LoginPage` y `RegisterPage`.
   - **Pruebas:** 2 pruebas unitarias añadidas en `test/public_plans_test.dart`. Total: **100 de 100 pruebas en verde**.

---

## 3. Estado técnico

- **Pruebas:** 100 en 13 archivos · `flutter test` y `flutter analyze` 100% limpios
- **Migraciones aplicadas en producción:**
  * `supabase/migrations/20260816100000_filtro_aceptacion_registro.sql` (Paso 3.7 / D-138)
  * `supabase/migrations/20260816170000_blindaje_rls_tenants_y_guards_aprobacion.sql` (Blindaje / D-139)
- **Scripts de prueba SQL:** `168_test_filtro_aceptacion.sql`, `169_test_blindaje_rls_tenants.sql`
- **Proyectos Supabase:** `beautyos-dev` (producción) y `salonymas-ensayo`

---

## 4. Lo siguiente según el Plan Maestro

1. **3.9 y 3.10 — Integración con Pasarela de Pago ePayco** (cobros, webhook seguro en el servidor y activación de suscripciones).
2. **3.3 — Términos de Servicio y Política de Privacidad** (Ley 1581 / Habeas Data).
3. **3.11 — Avisos de vencimiento por correo** (10, 5 y 3 días antes).
4. **3.13 — Traducir plantillas de correo de Auth** (hallazgo W).
