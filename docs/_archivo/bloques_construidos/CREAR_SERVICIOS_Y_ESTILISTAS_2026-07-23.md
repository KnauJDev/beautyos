# Crear servicios y estilistas

**Fecha:** 23 de julio de 2026
**Estado:** desplegado en el único proyecto real; verificado de extremo a extremo

## 1. Objetivo

Cerrar el hueco encontrado el 2026-07-22 probando el registro self-serve de
punta a punta: `ServiciosPage` y `EstilistasPage` eran de solo lectura — no
existía ninguna RPC de alta, porque todo tenant hasta ahora se sembraba a
mano por SQL. Un negocio nuevo (self-serve) no tenía forma de cargar su
propio catálogo.

## 2. Hallazgo de arquitectura antes de escribir código

`services`/`stylists` son catálogo del **tenant** (ADR-003), pero la
agenda y las reservas (Tramo C2a, `20260720130708`) solo consultan
`branch_services`/`branch_stylists`. Confirmado leyendo esa migración
directamente: `get_available_appointment_slots`-equivalente y las RPC de
agenda hacen `join public.branch_services` / `join public.branch_stylists`,
nunca `public.services`/`public.stylists` directamente. Esto significa que
crear solo la fila de catálogo del tenant habría dejado el servicio o
estilista **invisible para la agenda**, aunque apareciera en la lista.

Por eso `create_service` y `create_stylist` escriben en ambas tablas
(catálogo del tenant + fila de sede) en una sola transacción.

## 3. RPC nuevas

- `create_service(p_branch_id, p_name, p_category, p_duration_minutes, p_price, p_visible_to_customer default true, p_booking_interval_minutes default 15)`
- `create_stylist(p_branch_id, p_name, p_phone default null, p_specialty default null)`

Autorización: `private.beautyos_resolve_branch_access(p_branch_id,
array['tenant_owner','admin'], true)` — el patrón ya probado de Tramo C,
no el helper heredado `is_owner_or_admin()` (ese no valida que un admin
tenga la sede asignada; el nuevo sí).

## 4. Prueba contra el esquema real (no sintético)

Se usó el tenant de prueba real "Pelos y Tijeras" (creado el día anterior
durante las pruebas de registro), con `supabase db query --linked` y
`begin; ... rollback;` — sin dejar rastro:

- Crear un servicio deja `services` y `branch_services` consistentes
  (mismo precio/duración, mismo `branch_id`).
- Nombre vacío falla con el mensaje esperado.
- Crear un estilista deja `stylists` y `branch_stylists` consistentes.
- Un usuario sin membresía en ese tenant **no puede** crear nada ahí
  (`beautyos_resolve_branch_access` lo rechaza) — aislamiento entre
  tenants verificado, no asumido.

Evidencia: `supabase/sql/143_test_create_service_y_stylist.sql`,
`supabase/sql/143b_verify_create_service_stylist_results.sql`.

## 5. Flutter

- `ServicesService.createService()`, `StylistsService.createStylist()`.
- `ServiciosPage`/`EstilistasPage` ahora reciben `branchId` (antes no lo
  recibían, a diferencia del resto de páginas ya conscientes de sede) y
  tienen un botón "Agregar servicio"/"Agregar estilista" con diálogo de
  formulario, validación básica y recarga automática al guardar.
- `main.dart` actualizado para pasar `branch.branchId` a ambos módulos.

La gestión de qué estilista puede realizar qué servicio (`set_stylist_services`)
ya existía y no se tocó; solo faltaba poder crear el estilista y el
servicio en primer lugar.

`flutter analyze`: sin hallazgos. `flutter test`: 5 pruebas aprobadas.

Desplegado al único proyecto real con `supabase db push --linked` (la
migración solo agrega dos funciones nuevas, no modifica nada existente).

## 6. Fuera de alcance (bloques aparte)

- Editar o desactivar un servicio/estilista existente (hoy solo alta).
- Precio/duración distintos por sede para el mismo servicio (hoy se crean
  iguales; `branch_services` ya soporta el override, pero no hay UI para
  editarlo todavía).
- Entitlements: ninguna RPC de negocio los consulta todavía (D-044); crear
  servicios/estilistas no está limitado por plan.

## 7. Siguiente bloque

Con el registro self-serve y la carga de catálogo básico resueltos, el
candidato natural es la reserva pública de cliente (prioridad 7 del plan
maestro) — o completar más catálogo (clientes ya tiene alta vía
`create_client`, falta revisar si hace falta algo similar en otros
módulos antes de eso).
