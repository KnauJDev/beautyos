# Tramo A — Estructura aditiva multisede

**Fecha de validación:** 20 de julio de 2026  
**Estado:** aplicado y verificado en producción
**Migraciones:** `20260720102317_tramo_a_estructura_multisede.sql` y `20260720102806_tramo_a_indexar_claves_foraneas.sql`
**Base de ensayo:** restauración aislada del respaldo `BeautyOS_Backup_2026-07-19_19-12-48`

## 1. Resultado ejecutivo

El Tramo A quedó implementado como una migración exclusivamente aditiva. Crea la estructura necesaria para que un tenant pueda operar varias sedes, genera una **Sede principal** para cada tenant existente y copia allí las relaciones actuales de equipo, servicios, estilistas, capacidades e inventario.

La aplicación Flutter y las RPC actuales no cambian en este tramo. Las tablas originales continúan siendo la fuente de operación durante la ventana de compatibilidad. El 20 de julio de 2026 la estructura fue aplicada al proyecto vivo `beautyos-dev` después de comprobar Git, respaldo, historial remoto y línea base.

La migración fue instalada dos veces sobre una restauración local limpia. Entre ambas instalaciones se ejecutó y comprobó la reversión completa del Tramo A. Los conteos operativos y los totales financieros permanecieron invariantes.

En producción se ejecutó inmediatamente la verificación repetible. Supabase registró las migraciones administradas `20260720102317_tramo_a_estructura_multisede` y `20260720102806_tramo_a_indexar_claves_foraneas`.

## 2. Objetos creados

| Objeto | Propósito |
|---|---|
| `branches` | Sedes pertenecientes a un tenant. |
| `tenant_memberships` | Relación de una cuenta con un negocio y su rol dentro del tenant. |
| `branch_memberships` | Sedes concretas a las que puede acceder una membresía. |
| `branch_services` | Precio, duración, intervalo y visibilidad del servicio por sede. |
| `branch_stylists` | Asignación de profesionales a sedes con vigencia. |
| `branch_stylist_services` | Capacidades del profesional dentro de una sede. |
| `branch_products` | Existencias, mínimo, costo y precio de venta por sede. |
| `private.beautyos_set_updated_at()` | Mantenimiento interno de `updated_at`, fuera del esquema público de la API. |

También se agregaron índices únicos compuestos `(tenant_id, id)` a `services`, `stylists` y `products`. Estos índices permiten que las claves foráneas nuevas validen simultáneamente el tenant y el identificador del catálogo.

## 3. Controles de integridad

- Solo puede existir una sede principal por tenant.
- El `slug` de una sede es único dentro de su tenant.
- Una membresía de sede debe pertenecer al mismo tenant que la sede.
- Un servicio, estilista o producto de una sede debe pertenecer al mismo tenant.
- Una capacidad solo puede relacionar un profesional y un servicio de la misma sede.
- Los roles admitidos son `tenant_owner`, `admin`, `assistant` y `stylist`.
- Una membresía con rol `stylist` exige un estilista asociado.
- Precios, duración, intervalo, existencias, mínimos y costos no aceptan valores inválidos.
- Las relaciones históricas originales no se eliminan ni se recalculan.

## 4. Seguridad inicial

Las siete tablas nuevas tienen RLS habilitada desde su creación. En este Tramo A quedan cerradas por defecto a `anon` y `authenticated`; tampoco conservan grants directos para esos roles. El único acceso directo concedido es a `service_role`, reservado para procesos backend seguros.

Esta decisión es deliberada: las políticas de membresía y las nuevas RPC con contexto `branch_id` se introducirán juntas en el Tramo C. Así se evita publicar una ruta parcial que todavía dependa del rol antiguo de `user_profiles`.

La función de trigger está en el esquema `private`, fija un `search_path` seguro y no concede ejecución a clientes.

## 5. Backfill validado

| Relación | Anterior | Nueva | Resultado |
|---|---:|---:|---|
| Tenants / sedes principales | 1 | 1 | Coincide |
| Perfiles de equipo / membresías tenant | 2 | 2 | Coincide |
| Membresías tenant / membresías de sede | 2 | 2 | Coincide |
| Servicios / servicios de sede | 4 | 4 | Coincide |
| Estilistas / estilistas de sede | 2 | 2 | Coincide |
| Capacidades / capacidades de sede | 4 | 4 | Coincide |
| Productos / productos de sede | 4 | 4 | Coincide |

El tenant ficticio Bella Mujer quedó asociado a una sede denominada **Sede principal**, con zona horaria `America/Bogota` y moneda `COP`.

## 6. Invariantes operativas y financieras

Los siguientes valores fueron consultados después de cada instalación y después de la reversión:

| Control | Valor |
|---|---:|
| Tickets | 12 |
| Servicios asignados a tickets | 13 |
| Pagos vigentes | $250.000 |
| Pagos anulados | $115.000 |
| Comisiones vigentes | $100.000 |
| Comisiones anuladas | $36.000 |
| Stock activo anterior | 2.530 unidades |
| Stock activo copiado a sede | 2.530 unidades |

No hubo diferencias no explicadas.

## 7. Pruebas ejecutadas

### 7.1 Verificación repetible

`supabase/sql/104_verify_tramo_a_multisite.sql`

- exige una sede principal por tenant;
- exige correspondencia completa de usuarios y catálogos;
- verifica RLS en todas las tablas nuevas;
- verifica ausencia de grants para `anon` y `authenticated`;
- informa conteos e invariantes financieras.

Resultado: **APROBADO en dos ejecuciones independientes**.

### 7.2 Pruebas negativas de aislamiento

`supabase/sql/105_test_tramo_a_tenant_isolation.sql`

- intentó relacionar un servicio de otro tenant;
- intentó relacionar una membresía de otro tenant;
- intentó crear un rol no permitido;
- finalizó con `ROLLBACK`.

PostgreSQL bloqueó los tres intentos. Resultado: **APROBADO**.

### 7.3 Reversión protegida

`supabase/sql/106_rollback_tramo_a_test_only.sql`

1. Ejecutado sin autorización especial: fue bloqueado y conservó las siete tablas.
2. Ejecutado en ensayo con `beautyos.allow_destructive_test_rollback = 'yes'`: retiró únicamente los objetos del Tramo A.
3. Se comprobaron nuevamente los 12 tickets, 13 servicios, pagos, comisiones y stock originales.
4. La migración final se aplicó otra vez y todos los controles volvieron a pasar.

Resultado: **APROBADO y reproducible**.

### 7.4 Compatibilidad con la aplicación existente

Bajo el contexto autenticado del propietario se ejecutaron las RPC actuales de tickets, clientes, agenda, opciones de servicio, productos y usuarios. Respondieron correctamente después del Tramo A. La agenda devolvió cero elementos porque la consulta heredada depende de la fecha operativa del respaldo, no por una incompatibilidad estructural.

### 7.5 Asesores de seguridad y rendimiento

Antes y después de la aplicación se ejecutaron los asesores de Supabase. Las siete tablas nuevas quedaron con RLS habilitada, sin grants directos para `anon` o `authenticated` y sin políticas todavía, tal como exige la ventana cerrada del Tramo A.

El asesor de rendimiento identificó claves foráneas compuestas sin índice de apoyo completo. Se creó y aplicó una segunda migración exclusivamente aditiva con once índices. La comprobación final devolvió **cero claves foráneas nuevas sin índice**. Los avisos de índices sin uso son esperables porque las tablas acaban de crearse y Flutter todavía utiliza el modelo heredado.

## 8. Archivos del bloque

- `supabase/migrations/20260720102317_tramo_a_estructura_multisede.sql`
- `supabase/migrations/20260720102806_tramo_a_indexar_claves_foraneas.sql`
- `supabase/sql/104_verify_tramo_a_multisite.sql`
- `supabase/sql/105_test_tramo_a_tenant_isolation.sql`
- `supabase/sql/106_rollback_tramo_a_test_only.sql`

## 9. Alcance que permanece pendiente

El Tramo A no agrega `branch_id` a tickets, pagos, compras, gastos, horarios u otras tablas operativas. Tampoco cambia Flutter ni publica todavía selección de sede. Esos trabajos corresponden a los Tramos B y C.

Las alertas operativas continúan pausadas por decisión expresa del propietario.

## 10. Resultado de la compuerta de producción

La compuerta fue ejecutada y cerrada satisfactoriamente:

1. GitHub no contenía cambios paralelos y recibió los cuatro commits validados del Tramo 0 y Tramo A.
2. El historial remoto terminaba antes del respaldo y las siete tablas nuevas no existían.
3. La línea base viva coincidió con el respaldo: 12 tickets, 13 servicios asignados, pagos, comisiones y 2.530 unidades de stock.
4. Las dos migraciones fueron registradas por Supabase sin error.
5. `104_verify_tramo_a_multisite.sql` aprobó después de cada ajuste.
6. Se obtuvieron correspondencias exactas: 1 sede principal, 2 membresías tenant, 2 membresías de sede, 4 servicios, 2 estilistas, 4 capacidades y 4 productos.
7. Las siete tablas tienen RLS; existen cero grants directos para clientes y cero claves foráneas nuevas sin índice.

**Decisión:** Tramo A **APROBADO EN PRODUCCIÓN**. La siguiente puerta es el diseño detallado del Tramo B; no se mezclará su backfill operacional con este cierre.
