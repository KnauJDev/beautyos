# Tramo 0 — Auditoría y línea base antes de multisede

**Fecha de captura:** 19 de julio de 2026  
**Proyecto Supabase:** `beautyos-dev` (`eogppgbdnwxdtcbctaol`)  
**Región:** `us-west-2`  
**PostgreSQL:** 17.6  
**Plan:** Free  
**Estado del tramo:** en curso; auditoría y línea base completadas, herramientas de respaldo instaladas, virtualización de firmware y respaldo restaurable pendientes.

## 1. Propósito y alcance

Esta fotografía permite comprobar que la migración multisede no altere registros, dinero, inventario ni aislamiento. La captura fue de solo lectura: no se modificó el esquema ni los datos vivos.

No se incluyen nombres, teléfonos, correos, documentos, UUID de usuarios ni otras piezas de información personal.

## 2. Resultado ejecutivo

- La base está activa y ocupa aproximadamente **13 MB**.
- Hay **24 tablas operativas** en `public`; todas tienen RLS habilitada.
- Los chequeos de referencias entre tenant, tickets, servicios, pagos, comisiones, inventario, fotos y reseñas dieron **cero inconsistencias**.
- El registro administrado de Supabase contiene solo **8 migraciones**, mientras el repositorio conserva scripts numerados hasta `102`. Esto es una diferencia de trazabilidad, no evidencia de pérdida de tablas.
- El acceso actual se apoya principalmente en RPC protegidas: hay **54 funciones públicas**, de las cuales **54** son `SECURITY DEFINER`; 53 pueden ser ejecutadas por `authenticated`, ninguna por `anon` ni `PUBLIC`.
- La base es apta para continuar preparando una migración aditiva, pero **no se aplicará DDL hasta generar y validar un respaldo restaurable externo**.

## 3. Inventario del esquema vivo

### 3.1 Objetos principales

| Objeto | Cantidad |
|---|---:|
| Tablas base en `public` | 24 |
| Vistas en `public` | 0 |
| Funciones en `public` | 54 |
| Triggers visibles en `public` | 3 |
| Índices en `public` | 64 |
| Restricciones en `public` | 322 |
| Políticas RLS | 3 |
| Edge Functions | 0 |

### 3.2 Tablas y filas

| Tabla | Filas |
|---|---:|
| `appointment_policies` | 1 |
| `business_hours` | 7 |
| `clients` | 8 |
| `commission_policies` | 1 |
| `expenses` | 3 |
| `inventory_movements` | 5 |
| `products` | 4 |
| `purchase_items` | 4 |
| `purchases` | 2 |
| `reviews` | 3 |
| `services` | 4 |
| `stylist_commissions` | 8 |
| `stylist_services` | 4 |
| `stylists` | 2 |
| `tenants` | 1 |
| `ticket_history` | 42 |
| `ticket_payments` | 12 |
| `ticket_service_change_history` | 10 |
| `ticket_service_history` | 14 |
| `ticket_services` | 13 |
| `tickets` | 12 |
| `user_profile_access_history` | 2 |
| `user_profiles` | 2 |
| `work_photos` | 3 |

### 3.3 Extensiones instaladas relevantes

- `plpgsql`
- `pgcrypto`
- `uuid-ossp`
- `pg_stat_statements`
- `supabase_vault`

## 4. Línea base financiera y operativa

### 4.1 Dinero e inventario

| Métrica | Conteo | Importe / unidades |
|---|---:|---:|
| Pagos registrados | 9 | $250.000 |
| Pagos anulados | 3 | $115.000 |
| Comisiones generadas | 6 | $100.000 |
| Comisiones anuladas | 2 | $36.000 |
| Compras activas | 2 | $91.000 |
| Gastos activos | 3 | $1.630.000 |
| Stock activo | — | 2.530 unidades |
| Valor de stock a costo | — | $88.052.000 |
| Precio acumulado en servicios de tickets | 13 líneas | $685.000 |

Los importes se registran como huellas de comparación, no como un informe contable definitivo.

### 4.2 Pagos vigentes por medio

| Medio | Importe |
|---|---:|
| Efectivo | $170.000 |
| Tarjeta | $35.000 |
| Transferencia | $45.000 |

### 4.3 Estados

| Entidad | Estado | Cantidad |
|---|---|---:|
| Tickets | `cancelado` | 2 |
| Tickets | `cerrado` | 6 |
| Tickets | `no_asistio` | 2 |
| Tickets | `solicitado` | 2 |
| Servicios de ticket | `cancelado` | 4 |
| Servicios de ticket | `finalizado` | 6 |
| Servicios de ticket | `pendiente` | 3 |
| Pagos | `anulado` | 3 |
| Pagos | `registrado` | 9 |

## 5. Integridad comprobada

Los siguientes chequeos devolvieron **0**:

- tickets sin tenant o sin cliente;
- cliente de otro tenant en un ticket;
- servicio o estilista de otro tenant en `ticket_services`;
- `ticket_services` sin ticket;
- pagos ligados a tickets de otro tenant;
- comisiones ligadas a tickets o servicios de otro tenant;
- capacidades `stylist_services` con servicio o estilista de otro tenant;
- movimientos de inventario con producto de otro tenant;
- items de compra con compra o producto de otro tenant;
- reseñas o fotos con ticket de otro tenant.

Esta comprobación no sustituye las futuras claves compuestas tenant/sede: solo demuestra que los datos actuales no presentan esos cruces.

## 6. Diferencias y deuda técnica detectadas

### 6.1 Historial de migraciones incompleto

Supabase registra únicamente estas ocho migraciones administradas:

1. `20260710192241_fix_tickets_status_default_to_solicitado`
2. `20260710193648_create_client_rpc_sql`
3. `20260710200922_create_ticket_rpc`
4. `20260712012851_add_ticket_service_rpc`
5. `20260712013530_get_ticket_service_options_rpc`
6. `20260719095550_include_requested_in_my_stylist_agenda`
7. `20260719102316_create_scheduled_ticket_with_service`
8. `20260719162354_get_available_appointment_slots`

Los objetos iniciales y buena parte de la evolución existen en vivo y están documentados en `supabase/sql/001–102`, pero no forman un historial administrado completo. Antes de automatizar despliegues se deberá crear una migración basal verificable; no se fingirá que los 102 scripts fueron aplicados por el sistema de migraciones.

### 6.2 RLS y RPC

- Las 24 tablas tienen RLS activa.
- Solo `services` y `user_profiles` poseen políticas; las otras 22 quedan cerradas al acceso directo y se operan mediante RPC.
- Supabase informa 53 advertencias por funciones `SECURITY DEFINER` ejecutables por `authenticated`.
- Las funciones observadas fijan `search_path=public`, no otorgan ejecución a `anon` o `PUBLIC` y encajan con el patrón actual de backend por RPC.

No se cambiarán masivamente estas funciones durante la migración multisede. Se endurecerán de forma gradual: helpers privados, privilegio mínimo, autorización explícita de usuario/tenant/sede y pruebas negativas.

Referencias: [RLS sin política](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) y [funciones SECURITY DEFINER ejecutables](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable).

### 6.3 Rendimiento

El asesor de Supabase detectó 17 claves foráneas sin índice de cobertura en:

- `inventory_movements`: `product_id`, `tenant_id`;
- `products`: `tenant_id`;
- `purchase_items`: `product_id`, `purchase_id`, `tenant_id`;
- `purchases`: `tenant_id`;
- `reviews`: `service_id`;
- `stylist_services`: `service_id`;
- `ticket_history`: `ticket_id`;
- `ticket_service_history`: `ticket_id`, `ticket_service_id`;
- `ticket_services`: `service_id`, `stylist_id`, `ticket_id`;
- `tickets`: `client_id`;
- `work_photos`: `client_id`.

También reportó dos políticas de `user_profiles` que deben envolver `auth.uid()` como `(select auth.uid())` para evitar reevaluación por fila. Estas mejoras se incorporarán a una migración separada y probada; no se eliminarán índices señalados como “no usados” basándose en una base de prueba pequeña.

Referencia: [claves foráneas sin índice](https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys) y [RLS con funciones envueltas en SELECT](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select).

### 6.4 Autenticación

La protección contra contraseñas filtradas está deshabilitada. Debe activarse antes del piloto comercial y acompañarse de política de contraseña y MFA para operadores sensibles.

Referencia: [protección de contraseñas](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).

## 7. Respaldo y puerta de avance

El plan Free no ofrece copias diarias restaurables administradas. Supabase recomienda que estos proyectos exporten regularmente roles, esquema y datos con `supabase db dump` y mantengan una copia externa.

La preparación local avanzó de la siguiente forma:

- Docker Desktop 4.82.0 instalado;
- Node.js LTS 24.18.0 instalado;
- Supabase CLI 2.109.1 validado mediante `npx`;
- WSL y Plataforma de máquina virtual habilitados en Windows, con reinicio pendiente;
- CPU compatible con virtualización, pero la opción permanece desactivada en firmware;
- asistente `scripts/crear_respaldo_supabase.ps1` creado y validado sintácticamente.

Por tanto:

- la línea base lógica y de integridad quedó documentada;
- el SQL de auditoría repetible quedó versionado;
- el respaldo restaurable completo **todavía no puede marcarse validado**;
- no se aplicará el Tramo A hasta completar el procedimiento de `docs/02_operacion/RESPALDO_Y_RESTAURACION_SUPABASE.md`.

Referencia oficial: [Database Backups](https://supabase.com/docs/guides/platform/backups).

## 8. Decisión de avance

**GO condicionado para preparar archivos; NO-GO para aplicar cambios en vivo.**

Se permite:

- versionar esta auditoría;
- ejecutar nuevamente `supabase/sql/103_tramo_0_audit_multisite_baseline.sql`;
- preparar y revisar migraciones aditivas del Tramo A sin aplicarlas.

Se prohíbe hasta cerrar la puerta de respaldo:

- aplicar DDL multisede al proyecto vivo;
- añadir `NOT NULL` o retirar columnas actuales;
- cambiar firmas RPC usadas por Flutter;
- borrar, fusionar o recalcular datos históricos.

## 9. Evidencia de cierre pendiente

Para cerrar Tramo 0 deben existir:

1. `roles.sql`, `schema.sql` y `data.sql` fuera del repositorio.
2. Hash SHA-256 y fecha de cada archivo.
3. Una restauración de ensayo sin errores no explicados.
4. Reejecución de la línea base con los mismos conteos y totales.
5. Registro de dónde se conserva la copia, sin almacenar contraseñas en Git ni en la bitácora.
