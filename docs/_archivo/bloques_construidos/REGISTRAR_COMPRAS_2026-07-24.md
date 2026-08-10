# Registrar compras

**Fecha:** 24 de julio de 2026
**Estado:** desplegado en el único proyecto real; verificado contra el esquema real y de punta a punta en Flutter

## 1. Objetivo

Segundo sub-bloque de la ruta acordada (inventario/compras/gastos
editables). `ComprasPage` era 100% de solo lectura; no existía forma de
registrar una compra, así que el stock y el costo promedio de los
productos nunca se actualizaban desde una operación real.

## 2. Diseño

- `create_purchase`: en una sola transacción crea `purchases`, sus N
  `purchase_items`, un `inventory_movements` por ítem
  (`movement_type = 'purchase'`) y actualiza `branch_products.current_stock`
  (suma) y `average_cost` (costo promedio ponderado, redondeado al peso
  COP más cercano). El `total_amount` de la compra se calcula en el
  servidor a partir de los ítems, nunca se confía en un total enviado por
  Flutter. Disponible para `tenant_owner` y `admin`.
- `update_purchase_header`: edita solo proveedor, fecha, factura, forma
  de pago y notas — nunca cantidades, costos ni stock. Exclusivo de
  `tenant_owner`, por decisión explícita del propietario: los errores de
  digitación los corrige solo el dueño, no admin/asistente/estilista.
  Solo funciona sobre compras activas.
- `void_purchase`: anula la compra (`active = false`) y revierte el
  stock/costo que generó, pero **solo si es seguro**: si ya existe otra
  compra activa y posterior del mismo producto que recalculó el
  promedio encima de esta, se bloquea con un mensaje claro en vez de
  descuadrar el costo. Exclusivo de `tenant_owner`. No hay borrado
  físico — la compra y sus movimientos de inventario quedan como
  historial (AGENTS.md: no alterar historial financiero sin
  trazabilidad).
- `get_purchases_for_management`: muestra también las compras anuladas
  (grises, con etiqueta "Anulada" en la UI).
- Se agregó `inventory_movements.source_purchase_id` (nullable, FK a
  `purchases`): sin esto no había forma de saber con certeza qué
  movimiento pertenece a qué compra, y `void_purchase` no podría
  revertir con seguridad ni decidir cuándo bloquear.

### Fórmula de costo promedio ponderado (aprobada por el propietario)

```
nuevo_promedio = (stock_actual * costo_actual + cantidad_comprada * costo_de_esta_compra)
                 / (stock_actual + cantidad_comprada)
```

Si `stock_actual = 0`, el nuevo promedio es simplemente el costo de esta
compra. Redondeado a pesos enteros (sin decimales), coherente con
"dinero en enteros COP" de AGENTS.md.

### Alcance de edición (decisión explícita)

El propietario pidió poder corregir errores de digitación. Se decidió
**no** permitir editar cantidades/costos de ítems ya guardados dentro de
la misma compra — la corrección es: anular (si es seguro) y crear una
compra nueva correcta. Editar in-place cantidades ya usadas para calcular
un costo promedio que compras posteriores ya heredaron es
matemáticamente frágil; anular+recrear es más simple y trazable. El
propietario mencionó que más adelante convendría pensar en un "documento
reverso" formal para este caso — queda como posible bloque futuro, no
implementado aún.

## 3. Prueba

1. **SQL con rollback** contra el tenant real "Naguara de Uñas"
   (registrado por el propietario en el bloque anterior). **10 de 10
   verificaciones aprobadas**: costo promedio ponderado correcto en dos
   compras sucesivas (8.000 → 9.000 tras una segunda compra a 11.000),
   `total_amount` calculado en servidor, bloqueo de anulación cuando hay
   compra posterior activa, anulación exitosa cuando es segura (revierte
   stock y costo exactamente), `get_purchases_for_management` muestra
   anuladas, `update_purchase_header` rechaza editar una compra ya
   anulada, aislamiento entre tenants.
2. **Bug real encontrado y corregido durante la prueba**: el chequeo de
   bloqueo de `void_purchase` no filtraba por `purchases.active` en la
   compra "posterior" — bloqueaba una anulación válida solo porque
   existía un movimiento de una compra que **ya estaba anulada**. Se
   corrigió agregando `join public.purchases p2 ... and p2.active` al
   chequeo antes de desplegar.
3. **Nota de metodología de prueba**: dentro de una misma transacción de
   prueba, `now()` es constante (hora de inicio de transacción), así que
   dos compras creadas en la misma prueba quedan con el mismo
   `created_at`. Se simuló el paso del tiempo desplazando manualmente el
   `created_at` de la segunda compra (`+ interval '1 second'`) solo para
   la prueba; en producción cada RPC es su propia transacción con su
   propio `now()`, así que esto no aplica al comportamiento real.
4. **Despliegue real**: `supabase db push --linked`.
5. **Prueba de punta a punta en Flutter**: el propietario registró una
   compra real (proveedor "Almacenes Exito", factura "001", 10 unidades
   de "Gel para Peinar" a $10.000, efectivo). Se verificó por SQL de
   solo lectura que `purchases`, `purchase_items` y `branch_products`
   quedaron sincronizados (`current_stock = 10`, `average_cost = 10000`,
   `total_amount = 100000`).

## 4. Flutter

- `ComprasPage` ahora lee de `get_purchases_for_management` (ve activas
  y anuladas) en vez de `get_purchases_summary_v2`.
- Botón "Registrar compra" abre un formulario con encabezado (proveedor,
  fecha, factura, forma de pago, notas) y una lista dinámica de líneas
  (producto, cantidad, costo unitario) con agregar/quitar producto y
  total estimado en vivo.
- Fila de cada compra: columna "Estado" (Activa/Anulada) y, solo si el
  usuario es `owner`, iconos de editar encabezado y anular. `admin` ve
  la tabla pero sin esos botones.
- Rol se obtiene con `MyProfileService().getMyProfile()` dentro de la
  página (gating solo visual; la autorización real está en las RPC).
- La tabla "Detalle de productos comprados" no se tocó (sigue leyendo
  `get_purchase_items_summary_v2`, que solo muestra ítems de compras
  activas — al anular una compra, sus ítems desaparecen de esa tabla,
  comportamiento esperado, no un bug).
- `purchase_summary.dart` y `PurchasesService.getPurchasesSummary()` se
  eliminaron por quedar huérfanos (reemplazados por
  `purchase_management_item.dart` y `getPurchasesForManagement`).

`flutter analyze`: sin hallazgos.

## 5. Fuera de alcance

- Editar cantidades/costos de ítems ya guardados (ver "Alcance de
  edición" arriba).
- Ver el detalle de ítems de una compra ya anulada (desaparecen de la
  tabla de detalle, aunque el encabezado sigue visible marcado como
  anulado).
- Riesgo aceptado y documentado: el orden usado para decidir "compra más
  reciente" es `inventory_movements.created_at`; si dos compras del
  mismo producto se registraran en el mismo microsegundo exacto (dos
  transacciones concurrentes empatadas), el desempate no está
  garantizado. Extremadamente improbable en el uso real (carga manual
  por un humano), no se resolvió con una columna de secuencia adicional
  para no ampliar el alcance.

## 6. Siguiente bloque

Sub-bloque 3 de la ruta acordada: Gastos (`create_expense`,
`update_expense`, `set_expense_active`). Ver `EDITAR_GASTOS_2026-07-24.md`.
