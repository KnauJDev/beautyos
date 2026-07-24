# Registrar consumo interno de inventario

**Fecha:** 24 de julio de 2026
**Estado:** desplegado en el único proyecto real; verificado contra el esquema real y de punta a punta en Flutter

## 1. Objetivo

Hueco detectado tras cerrar inventario/compras/gastos (D-054 a D-056): no
había forma de sacar stock cuando un producto (para venta o insumo) se
usa dentro del negocio en vez de venderse — por ejemplo, usar una unidad
de un producto de venta en un puesto de trabajo. `inventory_movements`
ya preveía `movement_type = 'consumption'` desde antes de esta sesión,
pero ninguna función lo escribía.

## 2. Diseño

`create_stock_consumption(p_branch_id, p_product_id, p_quantity, p_notes)`:
descuenta `branch_products.current_stock` y crea un `inventory_movements`
(`movement_type = 'consumption'`) con el costo promedio del producto en
ese momento, como referencia histórica de valor. Disponible para
`tenant_owner` y `admin` (operación del día a día, igual que registrar
una compra). No hay edición ni anulación en este bloque.

### Decisión de alcance financiero (consultada con el propietario)

El propietario preguntó si el consumo interno debía "castigar" el
reporte financiero. Se verificó `get_branch_financial_summary_v2`
(`neto = ventas - compras - gastos - comisiones`) y se explicó la
disyuntiva: esa plata ya se restó del neto en el momento de la compra;
restarla de nuevo al consumir la contaría doble. El propietario eligió
la opción simple: **el consumo interno solo resta stock y queda en el
historial de movimientos; no toca el reporte financiero.** Migrar a un
modelo de costo-de-lo-realmente-usado (que sí reflejaría el consumo como
gasto) queda como posible bloque futuro, no implementado.

`average_cost` no se toca: consumir no cambia el costo del stock que
queda, solo comprar lo cambia (mismo principio que ya regía en compras).

## 3. Prueba

1. **SQL con rollback** contra el tenant real "Naguara de Uñas": 6 de 6
   verificaciones aprobadas (descuenta stock sin tocar costo promedio,
   movimiento registrado con la cantidad y costo correctos, bloquea
   consumir más de lo disponible, bloquea cantidad ≤ 0, aislamiento entre
   tenants). Sin bugs encontrados en esta prueba.
2. **Despliegue real**: `supabase db push --linked`.
3. **Prueba de punta a punta en Flutter**: el propietario registró un
   consumo real de 1 unidad de "Gel para Peinar" ("Prueba para Uso en
   puesto 2"). Se verificó por SQL que `current_stock` bajó de 10 a 9,
   `average_cost` se mantuvo en $10.000, y el movimiento quedó con
   `unit_cost = 10000` (el costo promedio en ese momento).

`flutter analyze`: sin hallazgos.

## 4. Flutter

- Nuevo ícono "Registrar consumo interno" en cada fila de producto
  activo con stock > 0 (`InventarioPage`), junto a editar y
  activar/desactivar.
- Diálogo simple: cantidad a descontar + motivo opcional, con aviso
  explícito de que no afecta el reporte financiero.
- Al guardar, recarga tanto la lista de productos (stock actualizado)
  como el historial de movimientos.
- `InventoryMovementsService.createStockConsumption()` nuevo;
  `get_inventory_movements_summary_v2` no necesitó cambios — ya mostraba
  cualquier `movement_type` de forma genérica.

## 5. Fuera de alcance

- Editar o anular un consumo ya registrado (si se necesita corregir un
  error, hoy no hay forma — se dejaría el stock descuadrado). Mismo tipo
  de brecha que se cerró para compras con `void_purchase`; se puede
  resolver igual más adelante si se pide.
- Reflejar el consumo como costo en el reporte financiero (ver decisión
  de alcance arriba).
