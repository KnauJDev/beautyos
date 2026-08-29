# HANDOFF Salón y Más — 29 de agosto de 2026 ("Panel de plataforma, Fase 7", D-172)

**Bloque documentado:** decisión **D-172** · Pasos **7.1, 7.2 y 7.4** de la
**FASE 7 — Tu panel de dueño de la plataforma**: cabecera ejecutiva del
SaaS, visión 360° financiera por salón y gestión visual de excepciones de
límites.

**Estado:** `flutter analyze` 100% limpio (0/0), **238 de 238 pruebas en
verde** (sube de 222). **La migración de base de datos
(`20260829200000_panel_plataforma_metricas_y_overrides.sql`) y su control
(`191_test_panel_plataforma_fase7.sql`) están escritos y revisados línea
por línea, pero NO están aplicados en Supabase todavía — eso lo hace el
propietario.** Hasta que se aplique: la cabecera ejecutiva, los campos
financieros de cada tarjeta/ficha y la Tarjeta 5 de excepciones no van a
resolver ("function does not exist"); el resto del Panel de Plataforma
sigue funcionando exactamente igual que antes de este bloque.

---

## 0. Tres correcciones al encargo, verificadas en el esquema real antes de escribir código

El encargo llegó con una especificación muy detallada, pero tres supuestos
no coincidían con el código actual (regla 8.1: verificar antes de afirmar).
Se corrigieron antes de escribir la migración:

1. **`private.beautyos_precio_efectivo` recibe un solo parámetro**
   (`p_tenant_id`), no `(plan_id, tenant_id)` como asumía el encargo.
2. **`subscription_events` no tiene columna de monto.** El cobro real de
   un pago de ePayco que sí activó/renovó la suscripción vive en
   `payload->>'monto_cop_recibido'` — el mismo campo que ya usa
   `platform_get_tenant_subscription_history` (D-161) para el historial de
   cada salón. MRR, LTV y recaudo histórico de este bloque cuentan
   exactamente lo mismo que el propietario ya ve ahí, no una cifra
   paralela. Un evento de ePayco rechazado o de monto insuficiente no
   tiene ese campo, así que no cuenta como período pagado.
3. **`tenant_feature_overrides` referencia `feature_id`, no
   `feature_key`.** Las RPC nuevas resuelven `feature_id` desde
   `features.key` internamente, para que Flutter siga hablando en
   `feature_key` (`branches` = Sedes, `team_members` = Cuentas de equipo,
   ya sembradas desde D-136).

Un cuarto matiz, no pedido por el encargo pero necesario para no mostrar
cobranza donde no corresponde: un salón `suspended` puede serlo por
decisión manual del propietario (evento `suspended_by_platform`, sin
relación con dinero) o por vencimiento automático del período de gracia
(evento `auto_suspended_grace_expired`, sí es mora). `debt_status =
'en_mora'` solo se marca en el segundo caso.

---

## 1. Qué se construyó

### 1.1 Base de datos (migración `20260829200000`)

- **`platform_list_tenants()` extendida** (cambia `RETURNS TABLE`, exige
  `drop function` primero): seis columnas nuevas por salón —
  `paid_periods_count`, `total_paid_cop` (LTV), `effective_monthly_price`
  (server-side, vía `beautyos_precio_efectivo`), `debt_status`
  (`al_dia`/`en_prueba`/`en_mora`), `debt_amount_cop`,
  `active_overrides_count`. Todo lo que ya devolvía se conservó línea por
  línea.
- **`platform_get_saas_metrics()`** (nueva, lectura para cualquier rol de
  plataforma): jsonb con `mrr_cop`, `total_collected_cop`, conteo
  `active`/`trialing`/`past_due`(+`grace`)/`cancelled`, y
  `conversion_rate_percent`. **Los salones `is_demo` (D-112) se excluyen
  de todos los agregados del SaaS**, aunque su propia ficha sigue
  mostrando su actividad real.
- **Tres RPC para `tenant_feature_overrides`:**
  `platform_get_tenant_feature_overrides` (lectura, cualquier rol),
  `platform_set_tenant_feature_override` (solo `platform_owner`, motivo
  obligatorio, `p_ends_at` opcional debe ser futuro) y
  `platform_delete_tenant_feature_override` (solo `platform_owner`;
  **finaliza** la excepción con `ends_at = now()` en vez de borrarla —
  sigue viéndose en el historial, solo deja de estar activa). Ambas
  mutaciones registran su evento en `subscription_events` para auditoría.

### 1.2 Control de calidad (`sql/191_test_panel_plataforma_fase7.sql`)

Como `platform_get_saas_metrics()` agrega sobre **toda** la tabla de
tenants (que ya tiene negocios reales), el control mide el **delta exacto
antes/después** de insertar seis salones de prueba propios, en vez de
afirmar un total absoluto. 17 casos en `ROLLBACK`: delta de MRR/recaudo/
conteos por salud, exclusión del salón demo (el delta de recaudo es
720.000, no 960.000 — esa es la prueba real de que su pago no se cuenta),
fila exacta de cada salón para los seis escenarios de mora, conceder/
listar/revocar una excepción (con su rastro histórico), motivo vacío
rechazado, y autorización en las cuatro combinaciones: `platform_owner`
(todo permitido), `platform_operator` (lee, no puede conceder/revocar) y
un usuario sin rol de plataforma (todo rechazado).

### 1.3 Frontend

- `PlatformTenantSummary` gana los seis campos nuevos más `ageLabel`
  ("Registrado hace N días/meses/años"), `isInDebt`, `formattedTotalPaid`,
  `formattedDebtAmount`.
- `PlatformSaasMetrics` y `PlatformTenantFeatureOverride` (modelos
  nuevos), cuatro métodos nuevos en `PlatformService`.
- `PlatformPanelPage` gana `_SaasMetricsHeader` (tarjeta con degradado de
  marca, cuatro KPI) **arriba y por fuera** de la `_PlatformKPIBanner` y
  los filtros de píldora existentes, que se conservan intactos, con su
  propio `FutureBuilder` independiente del listado de salones.
- `_TenantCard` gana antigüedad/períodos pagados/LTV, chip `⚙️ N límites
  especiales` si aplica, y un recuadro de mora con botón "Cobrar por
  WhatsApp" (mensaje precargado) cuando `debtStatus == 'en_mora'`.
- `_TenantDetailSheet` gana LTV/períodos pagados/mora en la Tarjeta 2, y
  una **Tarjeta 5 nueva** (`_TenantOverridesCard`, `StatefulWidget`
  propio para no convertir el resto de la ficha de `Stateless` a
  `Stateful`): lista las excepciones con su vigencia, diálogo "Conceder
  Excepción" (Sedes/Cuentas de equipo, límite numérico, motivo
  obligatorio, fecha de expiración opcional) y botón de papelera para
  revocar.

### 1.4 Pruebas (16 nuevas)

`test/platform_fase7_test.dart`: serialización de `PlatformSaasMetrics`
(incluye formato de miles y `.empty`), `PlatformTenantFeatureOverride`
(activa, revocada, sin límite = sin tope) y los campos nuevos de
`PlatformTenantSummary` (incluido `ageLabel` en sus cuatro variantes:
hoy, días, meses, sin fecha).

---

## 2. Qué quedó a medias / fuera de este bloque

- **Bloqueante para que todo esto tenga efecto real:** aplicar
  `supabase/migrations/20260829200000_panel_plataforma_metricas_y_overrides.sql`
  en Supabase y correr `supabase/sql/191_test_panel_plataforma_fase7.sql`.
  Instrucciones en el punto 3.
- **Paso 7.3 (sistema de referidos) sigue sin construir.** No se tocó en
  este bloque; `tenants.referral_source` existe desde D-125 pero no hay
  comisión ni seguimiento de quién trajo a quién.
- El archivo suelto `supabase/sql/activar_pago_naguara.sql` (visible en
  `git status` desde antes de este bloque) no se tocó ni se investigó —
  no es parte de este encargo. Señalarlo, no resolverlo por iniciativa
  propia (regla 8.20).

## Qué NO hacer

- **No** asumir que `beautyos_precio_efectivo` toma `(plan_id,
  tenant_id)` — toma un solo parámetro. Ya se corrigió aquí; si vuelve a
  aparecer ese supuesto en otro encargo, es un error de quien lo escribió,
  no del código.
- **No** sumar `subscription_events` por `provider = 'epayco'` sin filtrar
  por `payload ? 'monto_cop_recibido'` — un evento de pago rechazado
  también tiene `provider = 'epayco'` pero no debe contar como cobro.
- **No** marcar `en_mora` a un salón `suspended` sin revisar cuál fue el
  último evento de suspensión (`suspended_by_platform` vs
  `auto_suspended_grace_expired`) — es la diferencia entre un salón que el
  propietario pausó por otra razón y uno que de verdad no pagó.

---

## 3. Prompt exacto para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (bloque D-172: "Panel de
plataforma, Fase 7", pasos 7.1/7.2/7.4 -- cabecera ejecutiva del SaaS,
visión 360 financiera por salón y excepciones de límites). El código está
completo, flutter analyze 0/0, flutter test 238/238.

PENDIENTE BLOQUEANTE: la migración 20260829200000_panel_plataforma_
metricas_y_overrides.sql todavía no está aplicada en Supabase. Antes de
aplicarla:

  1. Respaldar: powershell -ExecutionPolicy Bypass -File scripts\respaldo_supabase.ps1
  2. Aplicar la migración:
     powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
       -Archivo "supabase\migrations\20260829200000_panel_plataforma_metricas_y_overrides.sql"
  3. Correr el control (termina en ROLLBACK, no deja rastro):
     powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
       -Archivo "supabase\sql\191_test_panel_plataforma_fase7.sql"
  4. Confirmar los 17 casos "OK" en la salida antes de darlo por cerrado.
  5. Probar en producción: abrir el Panel de Plataforma y confirmar que
     la cabecera ejecutiva carga, que una tarjeta de salón muestra
     antigüedad/LTV, y que se puede conceder y revocar una excepción real
     desde la Tarjeta 5 de la Ficha.

Con este bloque avanzan (no se cierran del todo, dependen de la
verificación en producción del propietario) los pasos 7.1, 7.2 y 7.4 de la
Fase 7. Sigue pendiente el 7.3 (sistema de referidos), sin construir.
```
