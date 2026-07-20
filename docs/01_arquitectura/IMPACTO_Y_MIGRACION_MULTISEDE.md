# Impacto y migración segura a multisede

**Estado:** Tramos 0, A, B y C cerrados en producción; Tramo D0 completado sin modificar producción
**Fecha:** 20 de julio de 2026
**Fuente auditada:** SQL versionado `supabase/sql/001–106`, migración administrada y servicios Flutter actuales.

> Antes de aplicar cambios se realizará una fotografía del esquema vivo de Supabase. Este documento identifica el impacto desde el repositorio, pero no reemplaza esa comprobación.

**Avance 19/07/2026:** la fotografía lógica, los conteos, los totales y las comprobaciones de integridad quedaron registrados en `docs/01_arquitectura/auditorias/TRAMO_0_LINEA_BASE_2026-07-19.md`. El respaldo externo fue creado y restaurado en un entorno local aislado.

**Avance 20/07/2026:** el Tramo A fue creado como migración aditiva, aplicado dos veces sobre la restauración, sometido a pruebas negativas entre tenants y revertido de forma controlada. Después se aplicó al proyecto Supabase vivo mediante dos migraciones administradas: estructura y optimización de claves foráneas. Los datos operativos, financieros y de inventario permanecieron invariantes. Evidencia: `docs/01_arquitectura/auditorias/TRAMO_A_ESTRUCTURA_MULTISEDE_2026-07-20.md`.

**Diseño Tramo B 20/07/2026:** se delimitó el backfill a 15 tablas y 139 filas, se definió herencia de sede, claves compuestas, índices, invariantes y un puente temporal para que las RPC heredadas sigan escribiendo en la Sede principal hasta el Tramo C. No se mutó producción. Evidencia: `docs/01_arquitectura/auditorias/TRAMO_B_DISENO_BACKFILL_OPERACIONAL_2026-07-20.md`.

## 1. Objetivo

Agregar sedes, membresías y entitlements sin perder datos ni romper el flujo ya probado. La migración será aditiva, verificable, reversible por etapas y compatible temporalmente con el modelo actual.

## 2. Clasificación de datos actuales

| Entidad actual | Destino | Cambio requerido |
|---|---|---|
| `tenants` | tenant | conservar; relacionar sedes y suscripción |
| `user_profiles` | identidad global | retirar gradualmente autorización única `tenant_id/role/stylist_id` |
| `clients` | tenant | conservar; unicidad de celular normalizado por tenant |
| `services` | catálogo tenant | conservar nombre/categoría; mover precio/duración operativos a `branch_services` |
| `stylists` | catálogo tenant | conservar; asignar con `branch_stylists` |
| `stylist_services` | capacidad por sede | migrar a `branch_stylist_services` |
| `business_hours` | sede | agregar `branch_id`; unicidad por sede/día |
| `appointment_policies` | sede | agregar `branch_id`; una política por sede |
| `commission_policies` | tenant/sede/profesional | evolucionar a reglas con alcance y vigencia; preservar snapshots liquidados |
| `tickets` | sede | agregar `branch_id` obligatorio después del backfill |
| `ticket_services` | sede heredada | validar que servicio, profesional y ticket coincidan en sede |
| historiales de ticket/servicio | sede heredada | conservar inmutables; añadir sede para filtros/RLS si conviene |
| `ticket_payments` | sede heredada | no recalcular ni borrar; filtrar caja por fecha de pago y sede |
| comisiones liquidadas | sede heredada | conservar regla y valor aplicado históricamente |
| `products` | catálogo tenant | retirar gradualmente `current_stock` como fuente operativa |
| `branch_products` | nueva | stock, mínimo, costo y estado por sede |
| `inventory_movements` | sede | agregar `branch_id`; movimiento transaccional |
| `purchases` / items | sede | compra pertenece a sede; items heredan/validan sede |
| `expenses` | sede | agregar `branch_id` |
| `work_photos` / `reviews` | ticket/sede | heredar y validar sede del ticket; conservar consentimiento |
| reportes | sede o consolidado | recibir sede/rango; owner puede consolidar tenant |

## 3. Entidades nuevas

- `branches`
- `tenant_memberships`
- `branch_memberships`
- `branch_services`
- `branch_stylists`
- `branch_stylist_services`
- `branch_products`
- `plans`, `features`, `plan_features`
- `tenant_subscriptions`, `subscription_events`, `tenant_feature_overrides`
- auditoría de soporte y acceso excepcional

## 4. Impacto en RPC y servicios

Las funciones actuales que obtienen solo `tenant_id` mediante el usuario deben evolucionar. Se agrupan así:

| Grupo | Cambio |
|---|---|
| clientes/catálogos tenant | validar membresía tenant; sede solo como contexto de uso |
| creación/listado de tickets | exigir `p_branch_id`, derivar tenant y validar acceso |
| agregar/editar servicios de ticket | validar oferta, capacidad y profesional de la misma sede |
| disponibilidad/choques/reprogramación | buscar horarios, ausencias y citas exclusivamente en la sede |
| agenda administrativa | sede obligatoria o consolidado autorizado; rango explícito |
| agenda de profesional | todas sus sedes autorizadas o sede seleccionada |
| pagos/cierre/comisiones | sede y fecha contable explícitas; no mezclar fecha de cita con fecha de pago |
| inventario/compras/gastos | sede obligatoria y movimientos atómicos |
| usuarios | membresías tenant/sede; dejar de leer rol desde perfil único |
| fotos/reseñas | validar cliente/ticket/profesional/tenant/sede |
| reportes | rango, zona horaria, sede o consolidación del tenant |

Cada RPC operativa seguirá la secuencia: autenticar → resolver sede → comprobar membresía/rol → comprobar suscripción/entitlement → ejecutar transacción → auditar.

## 5. Plan de migración por tramos

### Tramo 0 — Inventario y respaldo

1. Confirmar repositorio limpio y publicar documentación aprobada.
2. Exportar esquema, funciones, políticas, grants e índices del proyecto Supabase vivo.
3. Registrar conteos y huellas de tablas críticas.
4. Crear respaldo recuperable y probar que puede restaurarse en entorno de ensayo.
5. Congelar cambios paralelos de esquema durante la migración.

**Puerta:** esquema vivo coincide o sus diferencias quedan documentadas.

### Tramo A — Estructura aditiva

1. Crear `branches` y tablas de membresía.
2. Crear índices, restricciones y políticas iniciales.
3. Crear `Sede principal` para cada tenant existente.
4. Crear membresías desde `user_profiles` sin retirar campos actuales.
5. Crear relaciones de servicios, profesionales y productos para la sede principal.

**Puerta:** todo usuario y catálogo existente tiene una correspondencia nueva, sin cambiar la aplicación.

### Tramo B — Backfill operacional

1. Añadir `branch_id` inicialmente nullable a tablas operativas.
2. Asignar la Sede principal a registros históricos por tenant.
3. Verificar pagos, historiales, comisiones, fotos y movimientos.
4. Detectar huérfanos o cruces de tenant; resolverlos antes de avanzar.
5. Crear claves foráneas e índices compatibles con datos ya validados.

**Puerta:** cero registros operativos sin sede y conteos financieros invariantes.

**Diseño cerrado:** el alcance exacto comprende `business_hours`, `appointment_policies`, `tickets`, `ticket_services`, los tres historiales de ticket/servicio, `ticket_payments`, `stylist_commissions`, `inventory_movements`, `purchases`, `purchase_items`, `expenses`, `work_photos` y `reviews`. La implementación queda pendiente de respaldo fresco, restauración y pruebas en ensayo.

### Tramo C — Compatibilidad y doble validación

1. Incorporar helpers privados de autorización.
2. Crear versiones nuevas de RPC con `p_branch_id`.
3. Actualizar Flutter para seleccionar y transmitir sede.
4. Durante una ventana corta, mantener compatibilidad con la Sede principal.
5. Registrar métricas y comparar resultados antiguos/nuevos.

**Puerta:** flujo integral funciona en dos sedes de ensayo y los resultados coinciden.

**Cierre Tramo C 20/07/2026:** el contexto efectivo, las RPC `_v2`, Flutter por sede, reservas, tickets, agendas, pagos, caja, reportes e inventario fueron aprobados en ensayo y producción. D0 verificó después cero filas operativas sin sede, 15 puentes temporales activos y una dependencia Flutter todavía heredada. La siguiente microcompuerta es D1: retirar solo esa salida de emergencia antes de endurecer la base.

### Tramo D — Endurecimiento

1. Hacer `branch_id NOT NULL` donde corresponda.
2. Activar claves compuestas que impidan cruces tenant/sede.
3. Reemplazar políticas antiguas por membresías y sede.
4. Revocar permisos heredados innecesarios.
5. Migrar autorización de `user_profiles` a memberships.
6. Convertir stock operativo a `branch_products`.

**Puerta:** pruebas negativas de aislamiento pasan y no existe ruta antigua insegura.

### Tramo E — Suscripciones y entitlements

1. Crear planes y funcionalidades sin bloquear al piloto.
2. Asignar al tenant ficticio un plan/override de ensayo.
3. Aplicar comprobación backend primero en módulos nuevos.
4. Extenderla gradualmente al resto de RPC.
5. Integrar proveedor de pago solo después de validar webhooks en sandbox.

**Puerta:** el plan controla backend y UI; una suscripción vencida no pierde datos.

### Tramo F — Retiro controlado

Solo después de varios ciclos estables:

- retirar campos de autorización antiguos;
- dejar `products.current_stock` como obsoleto y luego eliminarlo;
- retirar firmas RPC antiguas;
- archivar scripts de transición y actualizar la fuente canónica.

## 6. Reglas de integridad

- `branch.tenant_id` debe coincidir con cada registro operativo.
- Una membresía de sede debe pertenecer al mismo tenant.
- Servicio y profesional asignados al ticket deben estar habilitados en esa sede.
- Todo ticket conserva snapshots de nombre, precio, duración y regla financiera aplicada.
- Los pagos, anulaciones, comisiones y movimientos son históricos; se corrigen con eventos compensatorios.
- Citas de sedes distintas no chocan entre sí; citas del mismo profesional sí pueden chocar si trabaja en varias sedes y el traslado lo exige.
- Fechas contables usan zona horaria de sede y el instante real del movimiento.

## 7. Índices mínimos previstos

- `branches (tenant_id, active)` y único `(tenant_id, slug)`.
- memberships activas por `user_id`, `tenant_id` y `branch_id`.
- tickets `(tenant_id, branch_id, scheduled_at)` y parcial para estados activos.
- ticket services por profesional y rango temporal activo.
- pagos no anulados por `(tenant_id, branch_id, paid_at)`.
- movimientos, compras y gastos por `(tenant_id, branch_id, occurred_at)`.
- relaciones de catálogo únicas por sede y entidad.

El diseño final de índices se validará con consultas reales y `EXPLAIN`, no solo por intuición.

## 8. Validaciones de conservación

Antes y después de cada tramo se compararán:

- número de tenants, usuarios, clientes, tickets y servicios;
- suma de pagos vigentes y anulados por separado;
- suma de comisiones liquidadas;
- stock derivado por producto;
- compras y gastos;
- tickets por estado;
- historiales por entidad;
- registros sin tenant, sede o referencia válida.

Cualquier diferencia no explicada detiene el despliegue.

## 9. Reversión

Los tramos A–C son aditivos: la aplicación anterior permanece disponible mientras las nuevas columnas no sean obligatorias. Si una verificación falla, se detiene la escritura nueva, se vuelve a la versión anterior de Flutter/RPC y se conservan tablas nuevas para diagnóstico. No se ejecutarán eliminaciones ni conversiones irreversibles en el mismo despliegue que introduce el modelo.

## 10. Riesgos abiertos

- El esquema base inicial contiene objetos creados fuera de los scripts actuales: requiere introspección viva.
- Un profesional en varias sedes exige definir tiempo de traslado o bloqueo global.
- Comisiones por salario fijo necesitan periodo de nómina, no solo ticket.
- La consolidación financiera debe diferenciar fecha de servicio, pago, anulación y cierre.
- Migrar clientes por celular requiere normalización y resolución de duplicados, nunca fusión automática.
