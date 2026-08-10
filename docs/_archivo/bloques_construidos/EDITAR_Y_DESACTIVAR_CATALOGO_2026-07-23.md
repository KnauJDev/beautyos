# Editar y desactivar servicios y estilistas

**Fecha:** 23 de julio de 2026
**Estado:** desplegado en el único proyecto real; verificado contra el esquema real

## 1. Objetivo

Segundo bloque de la ruta acordada: hasta ahora solo se podía crear un
servicio o estilista (bloque `20260723152713`), sin forma de corregir un
precio mal escrito ni de retirar uno sin borrarlo.

## 2. Diseño

Mismo patrón que crear: toda escritura sincroniza el catálogo del tenant
(`services`/`stylists`) y la fila de sede (`branch_services`/
`branch_stylists`) a la vez, porque la agenda (Tramo C2a) solo consulta
las tablas de sede.

- `update_service` / `update_stylist`: editan nombre y demás campos.
- `set_service_active` / `set_stylist_active`: desactivan o reactivan en
  ambas tablas juntas.
- `get_services_for_management` / `get_stylists_for_management`: lectura
  nueva que muestra **también los inactivos** (para poder reactivarlos).
  Las lecturas existentes (`get_active_visible_services` vía RLS,
  `get_stylists_summary`) solo devuelven activos a propósito para el
  catálogo operativo/público; no se tocaron.
- Autorización: `beautyos_resolve_branch_access`, igual que crear.

## 3. Prueba contra el esquema real

`supabase/sql/151_test_editar_y_desactivar_catalogo.sql`, con
`begin; ... rollback;` contra el tenant real "Cortes y Barbas": **8 de 8
verificaciones aprobadas**:

1. Editar un servicio actualiza `services` y `branch_services` a la vez.
2. Desactivar deja `active = false` en ambas tablas.
3. `get_services_for_management` sí muestra el inactivo.
4. Reactivar lo vuelve a dejar disponible.
5. Editar un estilista actualiza `stylists`.
6. Desactivar deja `active = false` en `stylists` y `branch_stylists`.
7. (Reactivar, verificado sin aserción aparte por consistencia con 4.)
8. Un usuario de otro tenant no puede editar nada aquí.

Desplegado al único proyecto real con `supabase db push --linked`.

## 4. Flutter

- `ServiciosPage`/`EstilistasPage` ahora leen de las RPC de gestión (ven
  activos e inactivos) en vez de las de catálogo público.
- Formularios de crear/editar unificados (`_ServiceFormDialog`,
  `_StylistFormDialog`) para no duplicar validación.
- Botones de editar y activar/desactivar por fila; los inactivos se ven
  atenuados con una etiqueta "inactivo".

`flutter analyze`: sin hallazgos. `flutter test`: 5 pruebas aprobadas.

## 5. Fuera de alcance

- Editar precio/duración distintos por sede para negocios con más de una
  sede (hoy edita la sede actual; `branch_services` ya lo soporta pero no
  hay UI multi-sede).
- Eliminar (borrado físico) un servicio o estilista — desactivar es la
  única vía, coherente con "no borrar, revertir con eventos" del proyecto.

## 6. Siguiente bloque

Según la ruta acordada: configuración editable (horario, políticas), o
adelantar a la reserva pública de cliente.
