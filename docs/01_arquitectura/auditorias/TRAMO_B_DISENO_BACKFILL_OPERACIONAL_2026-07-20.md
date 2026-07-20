# Tramo B — diseño del backfill operacional por sede

**Fecha:** 20 de julio de 2026  
**Estado:** diseñado; pendiente de implementación y validación en ensayo  
**Tipo de cambio:** aditivo, compatible y reversible por compuertas  
**Mutación de producción en este bloque:** ninguna

## 1. Decisión ejecutiva

El Tramo B incorporará `branch_id` a la operación histórica de BeautyOS y asignará todos los registros existentes a la **Sede principal** creada en el Tramo A. La aplicación actual seguirá funcionando mientras se preparan las RPC y pantallas conscientes de sede en el Tramo C.

Este tramo no crea una segunda sede operativa, no modifica Flutter, no cambia RLS, no retira rutas heredadas y no hace todavía `branch_id NOT NULL`. Tampoco recalcula pagos, comisiones, stock, compras ni gastos.

La migración deberá ejecutarse primero sobre una restauración reciente de producción y solo podrá llegar al proyecto vivo si conserva conteos, importes e historial.

## 2. Evidencia de partida

El inventario vivo leído después del Tramo A confirmó:

- un tenant y una Sede principal activa;
- una sola sede primaria por tenant;
- 15 tablas operativas objetivo y 139 filas históricas en total;
- RLS activa en todas las tablas objetivo;
- cero cruces tenant/ticket, tenant/servicio de ticket, tenant/compra o tenant/producto detectados;
- cero servicios de ticket fuera de la oferta de la Sede principal;
- cero estilistas asignados fuera de la Sede principal;
- tres fotos ligadas a ticket;
- una reseña ligada a ticket y dos reseñas históricas sin ticket;
- 32 funciones `security definer` que todavía operan con el modelo heredado y deberán conservar compatibilidad hasta el Tramo C.

La muestra es pequeña, pero las reglas se diseñan para el modelo SaaS futuro y no solo para los datos actuales.

## 3. Alcance exacto

### 3.1 Raíces operativas: sede derivada del tenant

| Tabla | Filas actuales | Fuente del backfill | Regla futura |
|---|---:|---|---|
| `business_hours` | 7 | Sede principal del tenant | horario por sede y día |
| `appointment_policies` | 1 | Sede principal del tenant | política por sede |
| `tickets` | 12 | Sede principal del tenant | toda cita pertenece a una sede |
| `inventory_movements` | 5 | Sede principal del tenant | movimiento y producto en la misma sede |
| `purchases` | 2 | Sede principal del tenant | compra contabilizada en una sede |
| `expenses` | 3 | Sede principal del tenant | gasto contabilizado en una sede |

### 3.2 Entidades heredadas: sede derivada de su padre

| Tabla | Filas actuales | Fuente del backfill | Regla futura |
|---|---:|---|---|
| `ticket_services` | 13 | ticket asociado | ticket, servicio y estilista en la misma sede |
| `ticket_history` | 42 | ticket asociado | historia conserva sede del ticket |
| `ticket_service_history` | 14 | ticket y servicio de ticket | ambos padres deben coincidir en sede |
| `ticket_service_change_history` | 10 | ticket y servicio de ticket | auditoría conserva sede original |
| `ticket_payments` | 12 | ticket asociado | caja por sede y fecha real de pago |
| `stylist_commissions` | 8 | ticket y servicio de ticket | comisión histórica conserva sede |
| `purchase_items` | 4 | compra asociada | compra, ítem y producto en la misma sede |
| `work_photos` | 3 | ticket si existe; sede principal durante transición | la foto conserva procedencia operacional |
| `reviews` | 3 | ticket si existe; sede principal durante transición | la reseña conserva procedencia operacional |

Total objetivo: **139 filas** distribuidas en **15 tablas**.

### 3.3 Entidades excluidas deliberadamente

| Tabla | Motivo |
|---|---|
| `clients` | catálogo del tenant; un cliente puede atenderse en varias sedes |
| `services` | catálogo del tenant; oferta, precio y duración por sede viven en `branch_services` |
| `stylists` | catálogo del tenant; asignación por sede vive en `branch_stylists` |
| `products` | catálogo del tenant; disponibilidad y stock por sede viven en `branch_products` |
| `stylist_services` | compatibilidad heredada; la relación futura es `branch_stylist_services` |
| `commission_policies` | política tenant actual; su evolución a sede/profesional/vigencias requiere un diseño financiero separado |
| `user_profile_access_history` | auditoría de identidad y tenant, no una operación propia de sede |

## 4. Reglas rectoras

1. `branch_id` debe pertenecer al mismo `tenant_id` de la fila.
2. Los hijos heredan la sede de su padre; el cliente no puede elegir una sede distinta manualmente.
3. Un servicio asignado debe estar habilitado en `branch_services`.
4. Un estilista asignado debe estar habilitado en `branch_stylists`.
5. Un producto movido o comprado debe existir en `branch_products`.
6. Pagos, anulaciones, comisiones e historiales no se recalculan ni reescriben.
7. Las correcciones financieras continúan mediante eventos compensatorios.
8. Las claves foráneas históricas usarán `RESTRICT` o `NO ACTION`; no se introducirá borrado en cascada sobre libros financieros o auditorías.
9. Las dos reseñas actuales sin ticket se adscriben a la Sede principal porque hoy existe una sola sede; la decisión quedará registrada.
10. Ninguna nueva tabla o columna recibirá permisos directos adicionales desde el cliente.

## 5. Puente temporal de compatibilidad

Añadir columnas y rellenar las filas actuales no basta: las RPC y la aplicación heredadas continuarían creando registros sin `branch_id` hasta el Tramo C. Por ello, el Tramo B incluirá triggers de compatibilidad temporales.

### 5.1 Helper de Sede principal

Se creará un helper privado que:

- reciba `tenant_id`;
- encuentre exactamente una sede activa y primaria;
- devuelva su `id`;
- falle de forma explícita si no hay una o si hay más de una;
- no sea ejecutable directamente por `anon` ni `authenticated`;
- use privilegio mínimo y un `search_path` fijo.

### 5.2 Triggers para raíces

Antes de insertar o modificar una raíz operativa:

- si `branch_id` es nulo, se asigna la Sede principal del tenant;
- si viene informado, se comprueba que pertenezca al tenant;
- no se permite cambiar silenciosamente una fila histórica a otra sede.

### 5.3 Triggers para hijos

- Los hijos de ticket copian la sede del ticket.
- Los hijos de servicio de ticket validan también la sede del servicio padre.
- Los ítems de compra copian la sede de la compra.
- Fotos y reseñas copian la sede del ticket cuando existe; durante la ventana heredada usan la Sede principal si el ticket es nulo.
- Un valor enviado por un cliente nunca prevalece sobre la sede derivada del padre.

### 5.4 Retiro del puente

El puente se retirará únicamente en el Tramo D, después de que:

- todas las RPC operativas exijan o deriven sede explícita;
- Flutter transmita la sede seleccionada;
- las pruebas con dos sedes estén aprobadas;
- `branch_id` pueda pasar a `NOT NULL`.

## 6. Restricciones y relaciones previstas

### 6.1 Claves únicas de apoyo

Se prepararán claves compuestas para poder validar tenant y sede en una sola relación:

- `clients (tenant_id, id)`;
- `tickets (tenant_id, branch_id, id)`;
- `ticket_services (tenant_id, branch_id, id)`;
- `purchases (tenant_id, branch_id, id)`;
- `branch_services (tenant_id, branch_id, service_id)`;
- `branch_stylists (tenant_id, branch_id, stylist_id)`;
- `branch_products (tenant_id, branch_id, product_id)`.

### 6.2 Claves foráneas compuestas

- Toda raíz: `(tenant_id, branch_id)` → `branches (tenant_id, id)`.
- Ticket: `(tenant_id, client_id)` → `clients (tenant_id, id)`.
- Servicio de ticket: ticket → `tickets`; servicio → `branch_services`; estilista opcional → `branch_stylists`.
- Historiales, pagos y comisiones: ticket y, cuando corresponda, servicio de ticket dentro de la misma sede.
- Movimiento de inventario: producto → `branch_products` de la misma sede.
- Ítem de compra: compra → `purchases` y producto → `branch_products` de la misma sede.
- Fotos y reseñas: ticket opcional coherente con tenant y sede; referencias opcionales a servicio o estilista se validarán cuando existan.

Las nuevas claves se agregarán `NOT VALID` y luego se validarán expresamente dentro de la misma migración, de modo que las escrituras nuevas queden protegidas desde su creación y los datos históricos sean comprobados de manera observable.

### 6.3 Unicidad durante la transición

Se añadirán las futuras unicidades:

- `business_hours (tenant_id, branch_id, day_of_week)`;
- `appointment_policies (tenant_id, branch_id)`.

Las restricciones heredadas por tenant permanecerán temporalmente para no cambiar el comportamiento de la aplicación actual. Se retirarán solo cuando el Tramo C habilite escritura real en una segunda sede.

## 7. Índices previstos

Los nombres y planes finales se comprobarán con asesores y consultas reales, pero el mínimo es:

- tickets por tenant, sede y fecha programada, con variante parcial para estados activos;
- servicios de ticket por tenant, sede, estilista y estado activo;
- pagos vigentes por tenant, sede y `received_at`;
- comisiones vigentes por tenant, sede y `generated_at`;
- historiales por tenant, sede, ticket y fecha descendente;
- movimientos de inventario por tenant, sede y `created_at`;
- compras por tenant, sede y `purchase_date`;
- gastos por tenant, sede y `expense_date`;
- fotos y reseñas por tenant, sede y `created_at`;
- índices de apoyo para todas las nuevas claves foráneas.

No se crearán índices redundantes con los ya existentes sin comparar primero definición y orden de columnas.

## 8. Secuencia de la migración

La migración se diseñará como una unidad atómica porque hoy solo existen 139 filas objetivo y el bloqueo será corto:

1. comprobar que cada tenant tenga exactamente una Sede principal;
2. comprobar nuevamente orfandad y cruces de tenant;
3. añadir `branch_id uuid` nullable a las 15 tablas;
4. rellenar primero las seis raíces;
5. rellenar hijos desde ticket, servicio de ticket o compra;
6. rellenar fotos y reseñas históricas según la regla documentada;
7. verificar cero nulos y cero discrepancias;
8. crear claves únicas, índices y claves foráneas;
9. instalar helpers y triggers de compatibilidad;
10. repetir invariantes y cerrar la transacción.

Si cualquier comprobación falla, toda la migración revierte automáticamente. `branch_id` seguirá siendo nullable hasta el Tramo D aunque, al cerrar el Tramo B, no debe existir ninguna fila objetivo con valor nulo.

## 9. Invariantes de aceptación

Antes y después deberán coincidir:

- 12 tickets;
- 13 servicios de ticket;
- 139 filas totales en las 15 tablas objetivo;
- pagos vigentes: **$250.000**;
- pagos anulados: **$115.000**;
- comisiones vigentes: **$100.000**;
- comisiones anuladas: **$36.000**;
- stock derivado total de la línea base: **2.530 unidades**;
- conteos e importes de compras y gastos, separados por estado;
- historiales por ticket y servicio;
- fotos y reseñas existentes.

Además deberá resultar cero para:

- filas objetivo sin `branch_id`;
- sede perteneciente a otro tenant;
- hijo con sede distinta a su padre;
- servicio o estilista fuera de la sede;
- producto de inventario o compra fuera de la sede;
- claves foráneas inválidas;
- nuevas advertencias de claves foráneas sin índice.

## 10. Pruebas obligatorias en ensayo

1. Crear un respaldo fresco posterior al Tramo A.
2. Restaurarlo en un PostgreSQL aislado.
3. Aplicar el Tramo B una vez y verificar invariantes.
4. Ejecutar el flujo Flutter heredado y confirmar que los triggers completan sede.
5. Revertir el Tramo B mediante el script controlado de ensayo.
6. Aplicarlo de nuevo y obtener los mismos resultados.
7. Intentar insertar un ticket con sede de otro tenant: debe fallar.
8. Intentar asignar servicio, estilista o producto de otra sede: debe fallar.
9. Intentar forzar en un hijo una sede distinta a la del padre: debe fallar.
10. Verificar que fotos/reseñas con y sin ticket sigan siendo consultables.
11. Ejecutar `flutter analyze` y pruebas automáticas.
12. Verificar que las RPC heredadas principales siguen funcionando.
13. Ejecutar asesores de seguridad y rendimiento de Supabase.

## 11. Reversión

Se preparará un script exclusivo de ensayo que solo podrá retirar el Tramo B si:

- no existe operación real en una sede distinta de la principal;
- el Tramo C no está activo;
- todas las filas conservan una correspondencia válida con el modelo heredado.

El script retirará triggers, helpers, claves, índices y columnas creados por el Tramo B, sin tocar tablas del Tramo A ni datos históricos. En producción, la reversión destructiva solo sería admisible antes de habilitar escrituras multisede; después se corregirá hacia adelante.

## 12. Seguridad y exposición

- RLS permanecerá habilitada en todas las tablas.
- No se añaden grants a `anon` ni `authenticated`.
- Las funciones temporales vivirán fuera del esquema expuesto cuando sea posible.
- Toda función privilegiada tendrá `search_path` fijo, validaciones explícitas y ejecución revocada a `PUBLIC`.
- Las RPC seguirán siendo la frontera de escritura del cliente.
- El Tramo B no confiará en `branch_id` enviado desde Flutter.

## 13. Relación con los tramos siguientes

- **Tramo C:** versionará RPC, filtros, disponibilidad, agenda, caja y Flutter para sede explícita.
- **Tramo D:** hará `branch_id NOT NULL`, retirará el puente temporal y reemplazará restricciones heredadas.
- **Compensación:** salario fijo, porcentaje o valor fijo con vigencia se diseñará como libro financiero separado; no se improvisará dentro del backfill.
- **Alertas operativas:** continúan pausadas por decisión del producto.

## 14. Puerta para comenzar implementación

El diseño queda aprobado técnicamente cuando el propietario del producto autorice crear, sin aplicar a producción:

1. la migración administrada del Tramo B;
2. el script de auditoría antes/después;
3. el script de reversión protegido para ensayo;
4. las pruebas negativas de aislamiento y coherencia.

Hasta esa autorización, el estado correcto es **diseñado, no implementado**.
