# HANDOFF Salón y Más — 30 de agosto de 2026 ("Partners y Referidos", D-173)

**Bloque documentado:** decisión **D-173** · Paso **7.3** de la
**FASE 7 — Tu panel de dueño de la plataforma**, que con este bloque queda
**completa (7.1 a 7.4, D-172 y D-173)**. Sistema de Partners y Referidos, y
unificación visual del Panel de Plataforma (se retira la tarjeta de KPIs
redundante, dos pestañas: Salones/Partners).

**Estado:** `flutter analyze` 100% limpio (0/0), **257 de 257 pruebas en
verde** (sube de 238). **La migración de base de datos
(`20260830100000_sistema_partners_y_referidos.sql`) y su control
(`192_test_sistema_partners_fase7.sql`) están escritos y revisados línea
por línea, pero NO están aplicados en Supabase todavía — eso lo hace el
propietario.** Hasta que se aplique: la pestaña "Partners y Referidos", el
campo "Partner Vinculado" en la Ficha Nivel 3, y la generación automática
de comisiones no van a resolver ("function does not exist"); la pestaña
"Salones Clientes" sigue funcionando igual que antes de este bloque.

---

## 0. Tres verificaciones contra el código real antes de escribir nada (regla 8.1)

1. **El hook de comisión no podía ser una RPC aparte** — dependería de que
   alguien la llamara. Tenía que vivir DENTRO de
   `beautyos_procesar_evento_epayco` (D-160), la misma función que activa o
   renueva un pago. Se copió su cuerpo completo sin tocar una sola línea
   existente (regla 8.10) y se agregó el cálculo justo después de que el
   payload del evento ya tiene `monto_cop_recibido` — así el hook cuenta
   exactamente los mismos pagos que ya cuenta `platform_list_tenants` para
   LTV (D-172), no una cifra paralela.
2. **`register_tenant` gana `p_referral_code_used` al final, sin `drop
   function`** — mismo criterio que D-164 ya usó para `p_referral_source`:
   un parámetro nuevo con default al final no rompe nada porque
   `TenantRegistrationService` llama por parámetros nombrados. La firma
   vieja de 8 parámetros queda sin uso en la base, no se borra.
3. **Un salón `suspended` puede serlo por decisión manual o por gracia
   vencida** (mismo matiz que D-172 ya documentó para `debt_status`) — no
   se tocó de nuevo aquí, solo se confirmó que el hook de comisión no
   necesitaba distinguirlo: un salón demo o un partner inactivo ya bastan
   para bloquear la comisión, sin importar por qué esté suspendido.

---

## 1. Qué se construyó

### 1.1 Base de datos (migración `20260830100000`)

- **Tabla `partners`:** código único normalizado en mayúsculas sin
  espacios, canal de pago (Bre-B/Daviplata/Nequi/Bancolombia/Otro),
  comisión porcentual o fija, duración (`first_payment_only`/
  `first_n_months`/`recurring_lifetime`).
- **`tenants.partner_id`/`referral_code_used`**, y `platform_list_tenants()`
  extendida con el partner vinculado (drop+recreate, mismo patrón de
  D-172).
- **Tabla `partner_commissions`** (append-only: liquidar cambia `status`/
  `paid_at`, nunca borra una fila).
- **Hook de comisión** dentro de `beautyos_procesar_evento_epayco`: si el
  salón está vinculado a un partner activo, no es demo, y la regla de
  duración autoriza ESE pago concreto, inserta una comisión `pending`.
- **Siete RPC nuevas:** `platform_list_partners`, `platform_create_partner`,
  `platform_update_partner`, `platform_get_partner_detail`,
  `platform_set_tenant_partner` (solo `platform_owner`),
  `platform_settle_partner_commissions` (solo `platform_owner`, liquida
  TODAS las comisiones pendientes del partner de una vez),
  `platform_get_partners_summary`, y la pública `public_register_partner`
  (rol `anon`, comisión estándar 15%/primer pago, activo de inmediato — sin
  paso de aprobación porque el encargo no pidió uno).

### 1.2 Control de calidad (`sql/192_test_sistema_partners_fase7.sql`)

Simula pagos reales con `beautyos_procesar_evento_epayco` (no una versión
simplificada) para probar las tres reglas de duración, confirma que un
salón demo y un partner inactivo nunca comisionan, liquida comisiones con
referencia bancaria y confirma el delta exacto en
`platform_get_partners_summary`, y rechaza a un usuario sin rol de
plataforma en las cuatro operaciones administrativas. 22 casos en
`ROLLBACK`.

### 1.3 Frontend

- Modelos nuevos en `lib/models/platform_partner.dart`: `PlatformPartner`,
  `PlatformPartnerCommission`, `PlatformPartnerDetail`,
  `PlatformPartnersSummary`, `PlatformPartnerSettlementResult`,
  `PublicPartnerRegistrationResult`. `PlatformTenantSummary` gana
  `partnerId`/`partnerName`/`referralCodeUsed`.
- Ocho métodos nuevos en `PlatformService`; `PublicPartnerService` nuevo
  (rol `anon`, mismo patrón que `PublicReviewService`).
- **`PublicPartnerPage`** (`lib/pages/public_partner_page.dart`):
  accesible por `salonymas.com/partners` o `?partners=1` (ambas rutas
  soportadas en `main.dart`, mismo patrón que `?planes=1`). Formulario +
  pantalla de éxito con enlace para compartir por WhatsApp.
- **`CompleteTenantSetupPage`** captura `?ref=CODIGO` de `Uri.base` al
  enviar el registro — la URL del navegador no cambia entre pantallas
  internas de esta SPA, así que sigue disponible aunque el clic al enlace
  haya pasado por login antes de llegar aquí.
- **`PlatformPanelPage`:** se retiró `_PlatformKPIBanner` (duplicaba las
  píldoras de filtro) y el cuerpo pasó a `TabController` de dos pestañas
  (`🏪 Salones Clientes` / `🤝 Partners y Referidos`). La cabecera
  ejecutiva púrpura (D-172) se mantiene arriba de las pestañas. Pestaña
  Partners: KPIs, `+ Nuevo Partner`, tarjetas con saldo pendiente y botón
  "Liquidar Comisiones", "Copiar Resumen Consolidado". Ficha Nivel 3,
  Tarjeta 1: fila "Partner Vinculado" con botón Asignar/Cambiar (solo
  `platform_owner`).

### 1.4 Pruebas (19 nuevas)

`test/platform_partners_test.dart`: formato de canales de pago y
duraciones, `commissionLabel` en sus cuatro variantes (porcentaje entero,
porcentaje decimal, valor fijo, primeros N meses), serialización de los
seis modelos nuevos, y los tres campos nuevos de `PlatformTenantSummary`.

---

## 2. Qué quedó a medias / fuera de este bloque

- **Bloqueante para que todo esto tenga efecto real:** aplicar
  `supabase/migrations/20260830100000_sistema_partners_y_referidos.sql` en
  Supabase y correr `supabase/sql/192_test_sistema_partners_fase7.sql`.
  Instrucciones en el punto 3.
- **Sin edición de partner desde la UI** (existe `platform_update_partner`
  en el backend, pero no se construyó un diálogo de edición — el encargo
  solo pidió crear, listar, vincular y liquidar). Si hace falta editar el
  esquema de comisión de un partner ya creado, es un bloque nuevo pequeño
  sobre una RPC que ya existe.
- **Sin paso de aprobación para la postulación pública** — queda activa de
  inmediato. Si el propietario prefiere revisarlas antes, es una decisión
  de alcance nueva (agregar un estado `pending` a `partners`, similar al
  filtro de aceptación de tenants de D-125).
- **La Fase 7 completa (7.1 a 7.4) queda cerrada** con este bloque. La
  Fase 8 (Limpieza técnica) es la siguiente en el Plan Maestro.

## Qué NO hacer

- **No** generar comisión para un salón `is_demo` bajo ninguna
  circunstancia — el hook ya lo bloquea, no se debe "arreglar" para que
  los negocios de prueba del propietario también comisionen.
- **No** asumir que `platform_settle_partner_commissions` liquida una
  comisión suelta — liquida TODAS las pendientes del partner de una vez,
  a propósito (el encargo pidió liquidación consolidada).
- **No** construir una segunda forma de calcular el monto de una comisión
  fuera de `beautyos_procesar_evento_epayco` — es la única fuente de
  verdad, igual que `beautyos_precio_efectivo` lo es para el precio.

---

## 3. Prompt exacto para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (bloque D-173: "Partners y
Referidos", paso 7.3, cierra la Fase 7 completa). El código está completo,
flutter analyze 0/0, flutter test 257/257.

PENDIENTE BLOQUEANTE: la migración 20260830100000_sistema_partners_y_
referidos.sql todavía no está aplicada en Supabase. Antes de aplicarla:

  1. Respaldar: powershell -ExecutionPolicy Bypass -File scripts\respaldo_supabase.ps1
  2. Aplicar la migración:
     powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
       -Archivo "supabase\migrations\20260830100000_sistema_partners_y_referidos.sql"
  3. Correr el control (termina en ROLLBACK, no deja rastro):
     powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
       -Archivo "supabase\sql\192_test_sistema_partners_fase7.sql"
  4. Confirmar los 22 casos "OK" en la salida antes de darlo por cerrado.
  5. Probar en producción: abrir el Panel, confirmar que la pestaña
     Partners carga, crear un partner de prueba, vincularlo a un salón
     desde su Ficha, y (si hay forma de simular un pago) confirmar que
     genera una comisión.

Con este bloque la Fase 7 queda completa (7.1 a 7.4). La Fase 8 (Limpieza
técnica) es la siguiente en el Plan Maestro -- preguntarle al propietario
si quiere seguir por ahí o si prefiere resolver primero algo del buzón de
ideas.
```
