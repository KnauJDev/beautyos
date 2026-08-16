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

---

## 3. Estado técnico

- **Pruebas:** 98 en 12 archivos · `flutter analyze` 100% limpio
- **Migración nueva:** `supabase/migrations/20260816100000_filtro_aceptacion_registro.sql`
- **Script de prueba SQL:** `supabase/sql/168_test_filtro_aceptacion.sql`
- **Proyectos Supabase:** `beautyos-dev` (producción) y `salonymas-ensayo`

---

## 4. Instrucción para aplicar en producción (Propietario)

1. **Respaldar la base de datos:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\respaldo_supabase.ps1
   ```
2. **Aplicar la migración SQL:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" -Archivo "supabase\migrations\20260816100000_filtro_aceptacion_registro.sql"
   ```

---

## 5. Lo siguiente según el Plan Maestro

1. **3.8 — Pantalla pública de planes** (`list_public_plans` ya adaptada a `price_cop`).
2. **3.9 y 3.10 — Pasarela ePayco** (cobros y suscripciones automáticas).
3. **3.3 — Términos y privacidad** (Ley 1581, obligatorio).
4. **3.13 — Traducir correos de cuenta** (hallazgo W).
