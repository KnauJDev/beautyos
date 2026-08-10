# Tramo D4.9 — fotografía de salida no productiva

**Fecha:** 20 de julio de 2026
**Estado:** completado; solo lectura
**Proyecto objetivo:** `beautyos-dev` (`eogppgbdnwxdtcbctaol`)
**Producción modificada:** no
**Base Git:** `6af1cfb Decidir fotografia final del Tramo D4.8`

## 1. Objetivo

Consolidar una evidencia única, posterior a D4.6 y D4.7, antes de preparar
cualquier acción productiva del Tramo D.

D4.9 no aplica migraciones, no ejecuta DDL/DML, no cambia permisos y no toca
producción. Todas las consultas remotas fueron de lectura contra `beautyos-dev`.

## 2. Fuentes verificadas

- Fuentes canónicas del producto, decisiones, migración multisede e inventario D0.
- Estado local de Git: limpio al inicio sobre `6af1cfb`.
- Changelog oficial de Supabase consultado el 20/07/2026; no se detectó un cambio
  reciente que altere el criterio usado para migraciones, permisos o funciones
  `SECURITY DEFINER` en este micro-paso.
- Metadatos del proyecto Supabase:
  - nombre: `beautyos-dev`;
  - ref: `eogppgbdnwxdtcbctaol`;
  - región: `us-west-2`;
  - estado: `ACTIVE_HEALTHY`;
  - motor: PostgreSQL 17.

## 3. Identidad de base verificada

Consulta de lectura:

| Campo | Valor |
|---|---|
| Base | `postgres` |
| Usuario | `postgres` |
| Versión servidor | `17.6` |
| Captura UTC | `2026-07-20 21:42:40.312989` |

## 4. Historial remoto de migraciones

El historial remoto de `beautyos-dev` termina con las migraciones esperadas:

| Versión | Nombre |
|---|---|
| `20260710192241` | `fix_tickets_status_default_to_solicitado` |
| `20260710193648` | `create_client_rpc_sql` |
| `20260710200922` | `create_ticket_rpc` |
| `20260712012851` | `add_ticket_service_rpc` |
| `20260712013530` | `get_ticket_service_options_rpc` |
| `20260719095550` | `include_requested_in_my_stylist_agenda` |
| `20260719102316` | `create_scheduled_ticket_with_service` |
| `20260719162354` | `get_available_appointment_slots` |
| `20260720102317` | `tramo_a_estructura_multisede` |
| `20260720102806` | `tramo_a_indexar_claves_foraneas` |
| `20260720111110` | `tramo_b_contexto_operacional_sede` |
| `20260720123813` | `tramo_c1_contexto_sede_efectiva` |
| `20260720130708` | `tramo_c2a_reservas_agendas_por_sede` |
| `20260720135200` | `tramo_c2b_operacion_ticket_por_sede` |
| `20260720152000` | `tramo_c3_caja_reportes_inventario_por_sede` |
| `20260720200109` | `tramo_d3_2_20260720183122_reemplazos_lectura_por_sede` |
| `20260720200141` | `tramo_d3_4_20260720190528_revocar_rpc_heredadas` |

No se creó migración nueva durante D4.7 ni D4.9.

## 5. Matriz final de permisos RPC

Las seis firmas heredadas sustituidas existen solo como reversión controlada:

| RPC heredada | `PUBLIC` | `anon` | `authenticated` | `service_role` |
|---|---:|---:|---:|---:|
| `get_appointment_policy()` | no | no | no | sí |
| `get_business_hours()` | no | no | no | sí |
| `get_dashboard_metrics()` | no | no | no | sí |
| `get_my_stylist_work_photos()` | no | no | no | sí |
| `get_reviews_summary()` | no | no | no | sí |
| `get_work_photos_summary()` | no | no | no | sí |

Las seis firmas `_v2` por sede están activas para el cliente autenticado y
conservan `search_path=pg_catalog`:

| RPC `_v2` | Argumento | `PUBLIC` | `anon` | `authenticated` | `service_role` | `search_path` |
|---|---|---:|---:|---:|---:|---|
| `get_appointment_policy_v2` | `p_branch_id uuid` | no | no | sí | sí | `pg_catalog` |
| `get_business_hours_v2` | `p_branch_id uuid` | no | no | sí | sí | `pg_catalog` |
| `get_dashboard_metrics_v2` | `p_branch_id uuid` | no | no | sí | sí | `pg_catalog` |
| `get_my_stylist_work_photos_v2` | `p_branch_id uuid` | no | no | sí | sí | `pg_catalog` |
| `get_reviews_summary_v2` | `p_branch_id uuid` | no | no | sí | sí | `pg_catalog` |
| `get_work_photos_summary_v2` | `p_branch_id uuid` | no | no | sí | sí | `pg_catalog` |

## 6. Conteos operativos y `branch_id`

Las 15 tablas del alcance B-D conservan cero `branch_id` nulos:

| Tabla | Filas | `branch_id` nulos |
|---|---:|---:|
| `appointment_policies` | 1 | 0 |
| `business_hours` | 7 | 0 |
| `expenses` | 3 | 0 |
| `inventory_movements` | 5 | 0 |
| `purchase_items` | 4 | 0 |
| `purchases` | 2 | 0 |
| `reviews` | 3 | 0 |
| `stylist_commissions` | 8 | 0 |
| `ticket_history` | 42 | 0 |
| `ticket_payments` | 12 | 0 |
| `ticket_service_change_history` | 10 | 0 |
| `ticket_service_history` | 14 | 0 |
| `ticket_services` | 13 | 0 |
| `tickets` | 12 | 0 |
| `work_photos` | 3 | 0 |

## 7. Asesores Supabase

### Seguridad

Hallazgos vigentes:

- `INFO rls_enabled_no_policy`: varias tablas tienen RLS habilitado sin políticas.
  Es deuda conocida del modelo actual, porque el acceso operativo se canaliza por
  RPC autorizadas y no por exposición directa de tablas.
- `WARN authenticated_security_definer_function_executable`: existen funciones
  `SECURITY DEFINER` ejecutables por `authenticated`. Las RPC `_v2` autorizadas
  por sede entran en este patrón esperado; el resto queda como deuda de revisión
  gradual.
- `WARN auth_leaked_password_protection`: protección contra contraseñas filtradas
  deshabilitada. No bloquea D4, pero debe resolverse antes de piloto real.

### Rendimiento

Hallazgos vigentes:

- `WARN auth_rls_initplan` en políticas de `user_profiles`.
- `INFO unused_index` sobre varios índices, esperable en un entorno de bajo uso y
  datos de prueba. No se retira ningún índice en D4.9.

## 8. Decisión

D4.9 deja consolidada la evidencia de salida no productiva:

- `beautyos-dev` está alineado con D3.2 y D3.4;
- las seis rutas heredadas sustituidas están cerradas para clientes externos;
- las seis rutas `_v2` por sede están disponibles para `authenticated`;
- no hay filas operativas sin sede en las 15 tablas revisadas;
- la deuda de asesores queda registrada y no se corrige automáticamente;
- producción no fue modificada.

La siguiente microcompuerta recomendada es D4.10: preparar el paquete de
autorización de D5, con respaldo, vista previa exacta, alcance de cambios
productivos, plan de reversión y criterio explícito de parada. D5 sigue pendiente
y no autorizado.
