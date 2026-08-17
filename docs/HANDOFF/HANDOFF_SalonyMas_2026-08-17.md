# HANDOFF Salón y Más — 17 de agosto de 2026

**Bloque documentado:** decisiones **D-140** y **D-141** · Pasos 3.8, 3.9 y 3.10 cerrados y blindados
**Estado:** 104 pruebas unitarias en verde (`flutter test`), `flutter analyze` 100% limpio (0 errores, 0 advertencias), Edge Function `epayco-webhook` con firma SHA-256 obligatoria (Fail-Closed) e idempotencia en base de datos.
**Reemplaza como handoff vigente a:** `HANDOFF_SalonyMas_2026-08-16.md` (archivado en `docs/_archivo/handoffs/`)

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
        3.7  Filtro de aceptación         ✅ CERRADO (16-ago / D-138)
        3.8  Pantalla pública de planes   ✅ CERRADO (17-ago / D-140)
        3.9  ePayco en servidor (webhook) ✅ CERRADO (17-ago / D-141)
        3.10 Pagos y suscripciones        ✅ CERRADO (17-ago / D-141)
        3.12 Correos de cuenta por Resend ✅
        3.11 Avisos por correo            ⬜ 🤖  ← LO SIGUIENTE
        3.2  Contador (DIAN, IVA)         ⬜ 👤
        3.3  Términos y privacidad        ⬜ 👥  Ley 1581, obligatorio
        3.4  Supabase Pro (~25 USD/mes)   ⬜ 👤
        3.13 Traducir correos de Auth     ⬜ 👥  hallazgo W
Fase 4  Pulido módulo a módulo        🔄 4.1 ✅
```

---

## 2. Qué pasó en este bloque (Pasos 3.8, 3.9 y 3.10 / D-140 y D-141)

### 2.1 Pantalla Pública de Planes (Paso 3.8 / D-140):
- **`PublicPlan` y `PublicPlanFeature`:** modelos dinámicos que agrupan filas de `list_public_plans()`, formatean precios en pesos colombianos (`$160.000`, `$200.000`, `$240.000 COP / mes`) y resuelven límites.
- **`PublicPlansService`:** consulta la base de datos pública con catálogo de respaldo estático (D-124 / D-136) y reporte automático a `MonitoreoService` para evitar fallos silenciosos.
- **`PublicPlansPage`:** interfaz pública moderna y responsiva con tarjetas comparativas (Business destacado como "MÁS ELEGIDO"), tabla punto a punto, acordeón de FAQ y enlaces directos a WhatsApp de asesoría y registro.
- **Enrutamiento público:** `?planes=1` / `?pricing=1` sin sesión en `main.dart` y botón contextual "Ir a mi negocio" si hay sesión activa.

### 2.2 Pasarela de Pagos ePayco y Gestión de Suscripciones (Pasos 3.9 y 3.10 / D-141):
- **Base de Datos (`20260817100000_epayco_suscripciones_y_gracia.sql`):**
  * `private.beautyos_procesar_evento_epayco(...)`: función protegida ejecutable solo por `service_role`. Implementa bloqueo de fila `FOR UPDATE` e inserción en `subscription_events` con candado único `(provider, provider_event_id)` para garantizar idempotencia total ante reintentos de ePayco.
  * **Guards de Estado (D-125 / D-138):** Un pago en `pending` o `rejected` no auto-activa el negocio; la activación exige aprobación de plataforma.
  * **Defensa en Profundidad:** Validación de monto pagado contra `beautyos_precio_efectivo` antes de extender la suscripción.
  * **Reactivación Automática:** Transiciona a `active` por 1 mes al confirmarse un pago aceptado. Si un cobro falla o se revierte sobre un cliente activo, pasa a `past_due` con 5 días de gracia (`grace_ends_at = now() + 5 days`).
  * **Blindaje de Citas:** `beautyos_tenant_accepts_new_commitments` verifica la vigencia de `current_period_end` y `grace_ends_at`.
- **Servidor (Edge Function `supabase/functions/epayco-webhook/index.ts`):**
  * Recibe POST de ePayco (servidor a servidor).
  * Validación criptográfica SHA-256 obligatoria (Fail-Closed) con `EPAYCO_P_CUST_ID` y la llave privada `EPAYCO_P_KEY`.
  * Invoca la RPC interna de Supabase con `SUPABASE_SERVICE_ROLE_KEY` y responde 200 OK.
- **Frontend Flutter:**
  * `EpaycoCheckoutService`: orquesta el Checkout multimetodo (PSE, Nequi, Daviplata, Tarjetas) con modo test dinámico (`!kReleaseMode`) y validación estricta de precio pactado.
  * `_TrialBanner` (`lib/main.dart`): adaptado con la cuenta regresiva día a día durante los 5 días de gracia ("Tienes X días de gracia para realizar tu pago y continuar disfrutando de tus servicios sin interrupción [Pagar ahora]") y avisos de renovación.
  * `settings_page.dart`: tarjeta destacada de "Suscripción y Facturación" para dueños con detalle de plan, precio efectivo (incluyendo insignia Pionero 50%), fecha de corte y botón de pago.

---

## 3. Estado técnico

- **Pruebas:** 104 pruebas unitarias automáticas en 14 archivos · `flutter test` y `flutter analyze` 100% limpios
- **Migraciones aplicadas / listas para producción:**
  * `supabase/migrations/20260816100000_filtro_aceptacion_registro.sql` (Paso 3.7 / D-138)
  * `supabase/migrations/20260816170000_blindaje_rls_tenants_y_guards_aprobacion.sql` (Blindaje / D-139)
  * `supabase/migrations/20260817100000_epayco_suscripciones_y_gracia.sql` (Pasos 3.9 y 3.10 / D-141)
- **Edge Functions:** `send-invitation-email`, `send-low-stock-alert`, `epayco-webhook`
- **Scripts de prueba SQL:** `168_test_filtro_aceptacion.sql`, `169_test_blindaje_rls_tenants.sql`, `170_test_epayco_transicion_y_gracia.sql`
- **Proyectos Supabase:** `beautyos-dev` (producción) y `salonymas-ensayo`

---

## 4. Instrucción para aplicar en base de datos (Propietario)

1. **Respaldar la base de datos:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\respaldo_supabase.ps1
   ```
2. **Aplicar la migración SQL:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" -Archivo "supabase\migrations\20260817100000_epayco_suscripciones_y_gracia.sql"
   ```

---

## 5. Lo siguiente según el Plan Maestro

1. **3.11 — Avisos de vencimiento por correo** (10, 5 y 3 días antes de corte y recordatorios en los 5 días de gracia).
2. **3.3 — Términos de Servicio y Política de Privacidad** (Ley 1581 / Habeas Data).
3. **3.13 — Traducir plantillas de correo de Auth a español** (hallazgo W).
4. **Fase 4 — Pulido módulo a módulo.**
