# HANDOFF Salón y Más — 23 de agosto de 2026 (contacto titular e historial completo, D-161)

**Bloque documentado:** decisión **D-161** · Píldora de plan activo en el header, edición del nombre de contacto titular (Panel de Plataforma y autoservicio del salón desde Configuración) e historial de suscripción con período comprometido y medio de pago, a pedido del propietario tras pruebas reales del 23-ago y un bosquejo visual suyo.

**Estado:** `flutter analyze` 100% limpio (0/0), **156 de 156 pruebas en verde**. Migración `20260823160000` **aplicada en Supabase** por el propietario, Control 181 **en verde contra la base real** (incluye aserciones de aislamiento entre tenants para la RPC de autoservicio). `git push` **pendiente de confirmar en producción al cerrar este documento** — ver abajo.

---

## 1. Dónde estamos

Este bloque nace de un pedido nuevo del propietario, apoyado en un bosquejo visual, distinto de la línea de trabajo de ePayco/facturación de D-159/D-160 (aunque toca el mismo módulo de plataforma, fila 4.11 del `PLAN_MAESTRO.md`, ya actualizada). Cuatro mejoras pedidas: header con plan/vencimiento visible, quitar el botón suelto de sede del header, que "+ Nueva Cita" abra el diálogo real, edición del nombre de contacto del titular (plataforma y autoservicio), e historial de transacciones con 4 columnas.

---

## 2. Qué pasó en este bloque

Antes de escribir código se hizo un plan por escrito (regla 8 del Plan Maestro) y se verificó contra el código real, no se asumió nada:

- El botón de "agregar sede" del header era **el único punto de entrada** a `CreateBranchDialog` en todo el repo — no existía ninguna sección de "Sedes" en Configuración pese a que el pedido lo daba por hecho.
- El diálogo real de "Nueva Cita" (`_CreateAppointmentDialog`/`_openCreateAppointmentDialog`) era **privado** a `tickets_page.dart` y necesitaba clientes/servicios precargados con el `branchId`.
- No existía ninguna RPC para que el propio salón editara sus datos de contacto (`BusinessSettingsService` solo tenía logo/portada/tema).
- Ya existía `platform_get_tenant_subscription_history` (D-158) pero la Tarjeta 4 no la usaba: armaba dos filas sintéticas en memoria.

Tres decisiones se confirmaron explícitamente con el propietario antes de construir: (1) dos RPC de contacto separadas — `platform_update_tenant_contact` (solo `platform_owner`) y `update_tenant_contact_info` (autoservicio, owner **o admin** del propio tenant); (2) una tarjeta "Sedes" nueva en Configuración para reubicar "Agregar sede"; (3) extraer el diálogo de nueva cita a una función/clase pública en vez de duplicar el código en `main.dart`.

**Lo que se construyó:**
- `supabase/migrations/20260823160000_contacto_titular_y_historial_completo.sql`: `platform_update_tenant_contact` (solo `platform_owner`, evento de auditoría `contact_updated`); `update_tenant_contact_info` (autoservicio, `get_my_tenant_id()` + `is_owner_or_admin()`, sin `p_tenant_id` — aislamiento por diseño); `platform_list_tenants()` y `get_business_settings()` extendidas con `contact_name` (join a `user_profiles` por `role = 'owner'`); `platform_get_tenant_subscription_history` reescrita con `plan_name`, `period_start`/`period_end` y `payment_detail` (franquicia/banco de ePayco + `provider_event_id` como referencia).
- **Hallazgo de arquitectura durante la construcción:** `get_my_tenant_id()`/`is_owner_or_admin()` leen en realidad de `tenant_memberships`/rol `tenant_owner` (redefinidas en `20260722175530_tramo_d3_5_3_autorizacion_memberships.sql`), **no** de `user_profiles`/rol `owner` como sugerían los archivos de referencia `035_get_my_tenant_id.sql`/`037_is_owner_or_admin.sql` (obsoletos desde esa migración, no se habían vuelto a consultar desde entonces). El control 181 falló en su primer intento por no crear también la fila de `tenant_memberships` que `register_tenant` sí crea siempre en paralelo — corregido antes de reintentar. **Si vuelves a simular un usuario como owner/admin de un tenant en un control SQL, crea ambas filas.**
- `supabase/sql/181_test_contacto_y_historial.sql`: control con `ROLLBACK`, incluye aserciones específicas de aislamiento (crea tenant A y B, confirma que `update_tenant_contact_info` autenticado como owner de B nunca toca a A).
- `lib/main.dart`: `_TrialHeaderBadge` gana la rama `status.isActive` (píldora verde con plan y fecha de corte); se retiró el `IconButton` de sede (y `_openCreateBranchDialog`, que quedó sin uso); "+ Nueva Cita" llama a `openCreateAppointmentDialog(context, branch.branchId)`.
- `lib/pages/tickets_page.dart`: `_CreateAppointmentDialog` → `CreateAppointmentDialog` (público); nueva función pública `openCreateAppointmentDialog(BuildContext, String branchId)` que la propia página y el header comparten sin duplicar la carga de clientes/servicios.
- `lib/pages/platform_panel_page.dart`: Tarjeta 1 con botón "Editar Contacto" (`handleUpdateContact`, mismo patrón que `handleUpdatePricing`) y `contact_name` real; Tarjeta 4 reescrita como `FutureBuilder<List<TenantSubscriptionHistoryEntry>>` con las 4 columnas del bosquejo.
- `lib/pages/settings_page.dart`: `BusinessSettingsCard` gana `_ContactInfoEditor` (nombre de contacto titular, tipo de negocio, teléfono, WhatsApp editables, visible para owner y admin) y una tarjeta nueva `_SedesCard` (solo owner) con el botón "Agregar sede" reubicado.
- Modelos/servicios nuevos: `TenantSubscriptionHistoryEntry`; `contactName` en `PlatformTenantSummary` y `BusinessSettings`; `PlatformService.updateTenantContact`/`getTenantSubscriptionHistory` (ahora tipado); `BusinessSettingsService.updateContactInfo`.

**Verificado:** `flutter analyze` (0/0), `flutter test` (156/156), migración aplicada en Supabase, Control 181 en verde contra la base real.

---

## 3. Qué quedó a medias / fuera de este bloque

- **El selector de sedes del header ya no se refresca solo tras crear una sede desde Configuración.** Antes vivía en el mismo estado que `homeContextFuture` y se recargaba de inmediato; ahora `_SedesCard` vive en `ConfiguracionPage`, sin acceso a ese estado. Es una acción poco frecuente — el propietario fue informado y no pidió resolverlo en este bloque. Si molesta en la práctica, pendiente para otro bloque.
- Los commits de la migración a Smart Checkout V2 (mencionado también en D-159/D-160) siguen sin registrarse individualmente como decisiones.

## Qué NO hacer

- **No** asumas que `get_my_tenant_id()`/`is_owner_or_admin()` leen `user_profiles` — leen `tenant_memberships`. Los archivos `supabase/sql/035_get_my_tenant_id.sql` y `037_is_owner_or_admin.sql` están **obsoletos** desde el 22-jul; la definición vigente está en `20260722175530_tramo_d3_5_3_autorizacion_memberships.sql`.
- **No** reintroduzcas el `contactEmail.split('@').first` como sustituto del nombre de contacto — ahora hay una columna real (`contact_name`, vía join a `user_profiles.full_name` del owner).
- **No** dupliques la lógica de abrir el diálogo de nueva cita — usa la función pública `openCreateAppointmentDialog` de `tickets_page.dart`, no reescribas el `showDialog` a mano.

---

## 4. Prompt exacto para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (bloque D-161: header con plan
activo, edición del nombre de contacto titular, historial de suscripción
completo). Quedó cerrado: migración 20260823160000 en Supabase, Control 181
contra la base real, flutter analyze 0/0, flutter test 156/156.

Pendiente conocido (no bloqueante): el selector de sedes del header no se
refresca solo tras crear una sede desde la nueva tarjeta "Sedes" en
Configuración — antes sí, porque vivía en el mismo estado. Resolver solo si
el propietario lo pide.

No asumas que get_my_tenant_id()/is_owner_or_admin() leen user_profiles: leen
tenant_memberships (ver "Qué NO hacer" arriba). No reintroduzcas el parche de
contactEmail.split('@').first para el nombre de contacto.
```
