# Tramo D0 — inventario previo al retiro de compatibilidad

**Fecha:** 20 de julio de 2026
**Estado:** completado; solo lectura y documentación
**Producción modificada:** no

## 1. Objetivo

Determinar qué debe ocurrir antes de hacer obligatorio `branch_id`, retirar los puentes temporales del Tramo B y revocar rutas heredadas. D0 no crea migraciones ni cambia datos: fija el orden seguro del endurecimiento.

## 2. Evidencia de producción

La inspección de solo lectura confirmó:

- Las 15 tablas operativas del alcance B–D conservan `branch_id` nullable por compatibilidad.
- Ninguna fila productiva de esas tablas tiene `branch_id` nulo.
- Los 15 triggers temporales `*_set_branch` están habilitados.
- Existen 30 funciones públicas `_v2` conscientes de sede.
- Existen 52 funciones públicas no `_v2` ejecutables por `authenticated`; no todas deben eliminarse, porque varias pertenecen a catálogos de tenant o identidad global y requieren clasificación individual.

Tablas verificadas: `business_hours`, `appointment_policies`, `tickets`, `ticket_services`, `ticket_history`, `ticket_service_history`, `ticket_service_change_history`, `ticket_payments`, `stylist_commissions`, `inventory_movements`, `purchases`, `purchase_items`, `expenses`, `work_photos` y `reviews`.

## 3. Dependencia encontrada en Flutter

`BranchContextService` todavía crea un contexto heredado con `branchId = null` cuando `get_my_branch_context_v2` no existe. A partir de ese valor, once familias de servicios conservan una selección condicional entre RPC heredada y RPC `_v2`: agenda administrativa, agenda de estilista, tickets, cierre diario, comisiones, resumen financiero, ventas, compras, detalles de compra, gastos e inventario.

Esta salida de emergencia fue correcta durante el despliegue progresivo del Tramo C, pero ahora impide retirar de forma segura las rutas antiguas. Si se hiciera primero `branch_id NOT NULL` o se revocaran funciones heredadas, una instalación desactualizada o una falla de contexto podría degradarse hacia una ruta incompatible.

## 4. Clasificación de compatibilidad

### Operación por sede

Debe usar exclusivamente `branch_id` explícito y RPC `_v2`: reservas, tickets, agendas, pagos, caja, reportes, compras, gastos e inventario.

### Catálogo del tenant

Clientes, servicios, profesionales, productos base, usuarios e identidad pueden seguir siendo de alcance tenant cuando así lo determine el modelo rector. No deben renombrarse ni revocarse automáticamente solo por no usar el sufijo `_v2`.

### Puentes de escritura

Los 15 triggers temporales continúan siendo una red de seguridad hasta que Flutter estricto haya sido probado y publicado. Los triggers derivados desde ticket o compra también protegen coherencia, por lo que su retiro se evaluará separando compatibilidad de integridad.

## 5. Microcompuertas aprobables

1. **D1 — Flutter estricto de sede:** eliminar el contexto heredado, exigir una sede real en las once familias operativas y mostrar un bloqueo claro cuando no exista sede autorizada.
2. **D2 — obligatoriedad de datos:** crear y probar una migración que compruebe cero nulos y aplique `branch_id NOT NULL` por familias.
3. **D3 — retiro controlado:** clasificar cada trigger y RPC heredada; retirar solo compatibilidad demostrablemente sin consumidores, conservando reglas de integridad necesarias.
4. **D4 — seguridad y ensayo:** probar roles, Tenant A/A1/A2, Tenant B, aplicación desactualizada, reversión y asesores.
5. **D5 — producción:** respaldo, vista previa exacta, autorización, despliegue, auditoría y publicación.

## 6. Decisión D0

No corresponde comenzar el Tramo D con una migración `NOT NULL`. El siguiente paso seguro y pequeño es D1: hacer que Flutter falle de manera explícita y comprensible si no obtiene una sede autorizada, sin recurrir silenciosamente al contrato heredado. D1 se implementará y verificará localmente antes de diseñar cualquier cambio productivo.
