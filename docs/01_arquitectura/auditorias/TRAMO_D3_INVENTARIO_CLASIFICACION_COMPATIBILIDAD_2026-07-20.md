# Tramo D3.0 — inventario y clasificación de compatibilidad

**Fecha:** 20 de julio de 2026  
**Estado:** inventario y clasificación aprobados  
**Producción modificada:** no

## 1. Objetivo y fuentes

Clasificar individualmente los 15 triggers `*_set_branch` y las 52 funciones públicas no `_v2` ejecutables por `authenticated`, sin retirar objetos. Se contrastaron el repositorio en `094f0b8`, Flutter actual, las migraciones versionadas y la restauración aislada `beautyos-tramo-c-test`.

La clasificación aplica la regla vigente de Supabase: una función expuesta se controla por sus privilegios `EXECUTE`; el nombre o sufijo no define su seguridad. Las funciones `SECURITY DEFINER` requieren revisión individual porque ejecutan con privilegios del propietario.

## 2. Triggers de sede

Los 15 triggers están habilitados y usan cuatro funciones privadas. No corresponde eliminarlos en bloque.

| Clasificación | Triggers | Decisión propuesta |
|---|---|---|
| Raíces operativas | `business_hours_set_branch`, `appointment_policies_set_branch`, `tickets_set_branch`, `expenses_set_branch`, `inventory_movements_set_branch`, `purchases_set_branch` | Reescribir. Hoy aceptan `branch_id = null` y lo convierten en Sede principal. Deben exigir sede y conservar validación tenant/sede e inmutabilidad. |
| Hijos de ticket | `ticket_services_set_branch`, `ticket_history_set_branch`, `ticket_service_history_set_branch`, `ticket_service_change_history_set_branch`, `ticket_payments_set_branch`, `stylist_commissions_set_branch` | Conservar como integridad: derivan sede del ticket y rechazan cruces. |
| Hijos de compra | `purchase_items_set_branch` | Conservar como integridad: deriva sede de la compra y rechaza cruces. |
| Ticket opcional | `work_photos_set_branch`, `reviews_set_branch` | Reescribir: conservar herencia cuando existe ticket y exigir sede explícita cuando no existe. |

La función `private.beautyos_resolve_branch(tenant, branch)` es el fallback central: si no recibe sede, selecciona la sede principal activa. D3 deberá separar esa compatibilidad de la validación estricta; no debe perder la comprobación de pertenencia de sede al tenant.

## 3. Superficie RPC heredada

La restauración contiene 52 funciones públicas no `_v2` ejecutables por `authenticated`. Las 52 son `SECURITY DEFINER`, propiedad de `postgres`, y también tienen `EXECUTE` para `anon`; ninguna lo concede a `PUBLIC`. La exposición a `anon` no coincide con la intención expresada en los SQL históricos, que revocan ese rol, y debe corregirse en una migración futura después de confirmar el esquema vivo.

### 3.1 Retiro completo propuesto — 24

Flutter no las consume, no aparecen en vistas activas y ninguna función activa las invoca:

`add_ticket_service`, `create_scheduled_ticket_with_service`, `create_ticket`, `get_agenda_summary`, `get_available_appointment_slots`, `get_commission_summary`, `get_daily_close`, `get_expenses_summary`, `get_financial_summary`, `get_inventory_movements_summary`, `get_my_stylist_agenda`, `get_my_stylist_agenda_by_date`, `get_products_summary`, `get_purchase_items_summary`, `get_purchases_summary`, `get_sales_report_summary`, `get_ticket_payment_summary`, `get_ticket_payments`, `get_ticket_service_options`, `get_ticket_services_for_correction`, `get_ticket_services_for_management`, `get_tickets_summary`, `reschedule_ticket`, `update_ticket_service_assignment`.

Antes de retirarlas se debe repetir la búsqueda contra el esquema vivo y sustituir las pruebas históricas de compatibilidad `110`, `119` y `120`.

### 3.2 Revocar acceso externo y conservar implementación interna — 6

Flutter usa las variantes `_v2`, pero estas todavía delegan en la función heredada. No pueden eliminarse hasta incorporar la lógica en una función privada o en la propia `_v2`:

| Heredada | Consumidor interno |
|---|---|
| `change_ticket_service_status` | `change_ticket_service_status_v2` |
| `change_ticket_status` | `change_ticket_status_v2` |
| `register_ticket_payment` | `register_ticket_payment_v2` |
| `remove_ticket_service` | `remove_ticket_service_v2` |
| `reopen_finished_ticket_service` | `reopen_finished_ticket_service_v2` |
| `void_ticket_payment` | `void_ticket_payment_v2` |

Se propone revocar `EXECUTE` a `anon` y `authenticated`, manteniendo la función solo como implementación interna temporal del propietario.

### 3.3 Conservar por alcance tenant/catálogo — 13

Tienen consumidor Flutter actual y su alcance presente es tenant, catálogo o identidad: `create_client`, `get_business_settings`, `get_clients_management_summary`, `get_clients_summary`, `get_commission_policy`, `get_my_profile`, `get_stylist_service_options`, `get_stylist_services_summary`, `get_stylists_summary`, `get_tenant_users`, `set_stylist_services`, `update_client`, `update_tenant_user_access`.

`update_tenant_user_access` y las lecturas de identidad siguen dependiendo del modelo antiguo de `user_profiles`; se conservan hasta la migración explícita a memberships. Conservar no implica aceptar `anon`: el acceso anónimo debe revocarse.

### 3.4 Requieren reemplazo o decisión funcional — 6

Flutter todavía consume estas funciones, pero su autorización se basa en `user_profiles` y omite el contexto efectivo de sede:

| RPC | Hallazgo |
|---|---|
| `get_appointment_policy` | Lee una política del tenant aunque la política ya pertenece a sede. |
| `get_business_hours` | Mezcla horarios de todas las sedes del tenant. |
| `get_dashboard_metrics` | Combina catálogos de tenant con métricas operativas de tickets sin filtro de sede. |
| `get_my_stylist_work_photos` | Consulta por estilista/tenant sin membresías ni sede efectiva. |
| `get_reviews_summary` | Devuelve consolidado tenant a owner/admin basado en rol antiguo. |
| `get_work_photos_summary` | Devuelve consolidado tenant a owner/admin basado en rol antiguo. |

No se autoriza revocarlas hasta definir y publicar sus reemplazos conscientes de sede.

### 3.5 Helpers de autorización — 3

- `get_my_tenant_id` e `is_owner_or_admin` tienen 39 dependencias entre funciones y una política RLS; deben conservarse hasta migrar esas dependencias a memberships.
- `get_my_role` no tiene consumidor activo observado. Puede ser candidato posterior, pero se clasifica como identidad y no se retirará solo por ausencia de llamada Flutter.

## 4. Decisiones aprobadas

1. Dashboard: sede seleccionada por defecto; un consolidado futuro será explícito y solo para owner.
2. Reseñas y fotos administrativas: sede seleccionada por defecto; un consolidado futuro será explícito y solo para owner.
3. Fotos propias del estilista: sede seleccionada por defecto; una vista de varias sedes requerirá autorización explícita sobre todas ellas.

El backend resolverá y autorizará nuevamente la sede. La selección de Flutter no se considera prueba de autorización.

## 5. Siguiente microcompuerta propuesta

D3.1 debe resolver las tres decisiones anteriores y diseñar los seis reemplazos conscientes de sede. Solo después corresponde preparar una migración local que endurezca triggers, revoque las 30 rutas operativas heredadas y retire las 24 que no tienen dependencias.
