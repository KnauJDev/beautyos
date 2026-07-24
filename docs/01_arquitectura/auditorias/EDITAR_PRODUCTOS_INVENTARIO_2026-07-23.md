# Editar productos de inventario

**Fecha:** 23 de julio de 2026
**Estado:** desplegado en el único proyecto real; verificado contra el esquema real y de punta a punta en Flutter

## 1. Objetivo

Primer sub-bloque de la ruta acordada (inventario/compras/gastos editables).
`InventarioPage` era 100% de solo lectura (`get_products_summary_v2`); no
existía forma de dar de alta un producto, corregirlo o desactivarlo salvo
por SQL a mano.

## 2. Diseño

Mismo patrón que servicios/estilistas: toda escritura sincroniza el
catálogo del tenant (`products`) y la fila de sede (`branch_products`) a
la vez, porque `get_products_summary_v2`/`get_products_for_management`
solo leen stock, costo promedio, precio de venta y visibilidad desde
`branch_products`.

- `create_product` / `update_product`: crean o editan nombre, categoría,
  tipo, unidad, SKU (catálogo) y stock mínimo, costo de compra, precio de
  venta, visibilidad (sede). El stock (`current_stock`) nunca se edita a
  mano: todo producto nuevo inicia en 0 y solo cambiará al registrar
  compras (próximo sub-bloque) o ajustes, para no crear inventario sin
  movimiento que lo respalde.
- `set_product_active`: desactiva o reactiva en ambas tablas juntas.
- `get_products_for_management`: lectura nueva que muestra también los
  inactivos (para poder reactivarlos). `get_products_summary_v2` no se
  tocó (mismo criterio que D-051 con servicios/estilistas).
- Autorización: `beautyos_resolve_branch_access`, igual que el resto del
  catálogo.

### Limpieza de esquema

Se confirmó contra el esquema real que `products.current_stock`,
`minimum_stock`, `purchase_price`, `sale_price` y `visible_for_sale` eran
columnas muertas: ninguna función, vista ni política RLS las leía (todo
el módulo usa las equivalentes en `branch_products`), y la tabla no tenía
filas. Se eliminaron en la misma migración en vez de mantenerlas
sincronizadas sin uso real.

## 3. Prueba

1. **SQL con rollback** contra el único proyecto real: la migración
   completa (DDL + 4 RPC) se ejecutó dentro de `begin;...rollback;`,
   bootstrapeando un tenant desechable con `register_tenant()` (la base
   estaba vacía en ese momento — ver nota abajo). **11 de 11
   verificaciones aprobadas**: creación sincroniza ambas tablas con stock
   en 0, edición no toca el stock, desactivar/reactivar en ambas tablas,
   `get_products_for_management` muestra inactivos, validaciones de
   nombre vacío y precio negativo, aislamiento entre tenants. Rollback
   final: nada quedó persistido por esta prueba.
2. **Despliegue real**: `supabase db push --linked`.
3. **Prueba de punta a punta en Flutter** (no solo SQL, siguiendo el
   criterio de D-047): el propietario registró un negocio real
   ("Naguara de Uñas") por el flujo self-serve normal, agregó un producto
   ("Gel para Peinar", tipo venta, categoría Cabello, stock mínimo 5,
   costo 10.000, venta 25.000, visible) desde la UI nueva. Se confirmó
   por SQL de solo lectura que quedó sincronizado en `products` y
   `branch_products` con los valores correctos y stock en 0.
4. **Bug real encontrado en la prueba de punta a punta**: el primer
   intento de guardar falló con `Could not find the function
   public.create_product(...) in the schema cache` porque la migración
   solo se había probado con rollback, no desplegado todavía. Se corrigió
   aplicando `supabase db push --linked` antes de reintentar; no fue un
   error de la RPC en sí.

### Nota: estado de los datos del proyecto real

Al iniciar este bloque se detectó que `beautyos-dev` tenía el historial
de migraciones al día pero 0 filas en `tenants`, `branches`,
`tenant_memberships` y `products`, con solo 1 usuario en `auth.users` (el
`platform_owner`). El tenant de prueba "Cortes y Barbas" usado en D-047 a
D-053 ya no existía. No se determinó la causa (no fue una acción de esta
sesión). El propietario decidió registrar un negocio nuevo real
("Naguara de Uñas") por el flujo self-serve en vez de crear un usuario
por SQL directo.

## 4. Flutter

- `InventarioPage` ahora lee de `get_products_for_management` (ve activos
  e inactivos) en vez de `get_products_summary_v2`.
- Botón "Agregar producto" y fila editable con edición completa y
  activar/desactivar, mismo patrón visual que `ServiciosPage`.
- Sección "Movimientos recientes" se mantiene igual (solo lectura; es del
  sub-bloque 2).
- `product_summary.dart` y `ProductsService.getProductsSummary()` se
  eliminaron por quedar huérfanos (reemplazados por
  `product_management_item.dart` y `getProductsForManagement`).

`flutter analyze`: sin hallazgos (archivos nuevos y proyecto completo).

## 5. Fuera de alcance

- Carga de stock inicial o ajustes manuales de inventario
  (`movement_type = 'adjustment'` ya existe en el constraint de
  `inventory_movements` pero sin RPC todavía).
- Precio/stock distintos por sede para negocios multi-sede reales.
- El correo de invitación de equipo sigue sin enviarse automáticamente
  (limitación ya documentada en D-050, no es parte de este bloque).

## 6. Siguiente bloque

Sub-bloque 2 de la ruta acordada: Compras (`create_purchase`, con sus
ítems y el movimiento de inventario que generan, actualizando stock y
costo promedio en `branch_products`).
