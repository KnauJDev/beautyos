# Editar gastos

**Fecha:** 24 de julio de 2026
**Estado:** desplegado en el único proyecto real; verificado con prueba SQL contra el negocio real

## 1. Objetivo

Tercer y último sub-bloque de la ruta acordada (inventario/compras/gastos
editables). `GastosPage` era 100% de solo lectura.

## 2. Diseño

`expenses` es una tabla plana: no tiene ítems ni afecta stock ni costo
promedio de ningún producto. A diferencia de compras, aquí no hay ningún
cálculo en cascada que proteger, así que `update_expense` edita el
registro completo (categoría, descripción, valor, fecha, forma de pago,
notas) en vez de solo un encabezado.

Mismo criterio de gobernanza ya establecido en compras (D-055):

- `create_expense`: `tenant_owner` y `admin`.
- `update_expense` / `set_expense_active`: exclusivo de `tenant_owner`.
- `get_expenses_for_management`: muestra también los anulados.
- Sin borrado físico, solo `active = false`.

## 3. Prueba

SQL con `begin;...rollback;` contra el tenant real "Naguara de Uñas":
**8 de 8 verificaciones aprobadas** — crear, editar el registro completo,
anular, `get_expenses_for_management` muestra anulados, reactivar,
validaciones de categoría vacía y valor negativo, aislamiento entre
tenants. Sin bugs encontrados en esta prueba (a diferencia de productos y
compras). Desplegado con `supabase db push --linked` y confirmado que las
4 funciones existen en producción.

`flutter analyze`: sin hallazgos.

## 4. Flutter

- `GastosPage` ahora lee de `get_expenses_for_management` en vez de
  `get_expenses_summary_v2`.
- Botón "Registrar gasto" y formulario único reutilizado para crear y
  editar (mismo patrón que productos/servicios).
- Fila de cada gasto: columna "Estado" (Activo/Anulado) y, solo para
  `owner`, iconos de editar y anular/reactivar.
- `expense_summary.dart` y `ExpensesService.getExpensesSummary()` se
  eliminaron por quedar huérfanos.

## 5. Fuera de alcance

- Categorías predefinidas/catálogo de categorías de gasto (hoy es texto
  libre, igual que antes).

## 6. Cierre del bloque

Con esto se cierra la ruta acordada: inventario (D-054), compras
(D-055) y gastos (D-056) quedan editables con el mismo patrón de
seguridad (RPC `SECURITY DEFINER`, autorización por rol y sede, sin
borrado físico). Pendiente de decisión del propietario: siguiente punto
de la ruta general (reseñas/fotos de trabajo, o pasarela de pago cuando
esté lista la cuenta Wompi).
