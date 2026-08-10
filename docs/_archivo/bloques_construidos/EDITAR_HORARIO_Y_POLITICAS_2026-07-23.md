# Editar horario, política de citas y política de comisión

**Fecha:** 23 de julio de 2026
**Estado:** desplegado en el único proyecto real; verificado contra el esquema real

## 1. Objetivo

Tercer bloque de la ruta acordada: "Configuración" era de solo lectura
(datos del negocio, horario, política de citas, comisión). Este bloque
cubre exactamente lo pedido: horario, política de citas y comisión. Los
datos del negocio (nombre, contacto, redes) quedan fuera a propósito, sin
que se pidieran.

## 2. Hallazgo antes de escribir código

`business_hours` y `appointment_policies` tienen columna `branch_id`
(nullable en la tabla), pero `get_business_hours_v2`/
`get_appointment_policy_v2` (Tramo D3.2) exigen coincidencia **exacta**
(`branch_id = branch_id`, no aceptan nulo). Se verificó contra el esquema
real que las 0 filas de `business_hours`/`appointment_policies` tienen
`branch_id` nulo — `register_tenant()` (corregido el 2026-07-22) ya lo
sembraba correctamente. No hizo falta ningún backfill; solo confirmar que
la sospecha inicial era una falsa alarma antes de diseñar las RPC de
escritura con el mismo filtro exacto por sede.

`commission_policies` sigue siendo por tenant (sin columna `branch_id`,
consistente con que D2 no la incluyó entre las 15 tablas obligadas a sede
explícita).

## 3. RPC nuevas

- `update_business_hours(p_branch_id, p_hours jsonb)`: recibe los 7 días
  como arreglo y los actualiza en una sola llamada; exige los 7 días sin
  repetir y que la apertura sea antes que el cierre.
- `update_appointment_policy(p_branch_id, ...)`: anticipo, horas de
  cancelación/reagendamiento, confirmación manual, reagendamiento por el
  cliente.
- `update_commission_policy(p_branch_id, ...)`: tipo (`percentage`/`fixed`,
  únicos valores reales según el `CHECK` de la tabla), porcentaje o valor
  fijo, si se calcula antes o después de descuentos, notas.

Autorización: `beautyos_resolve_branch_access`, mismo patrón que los
bloques anteriores.

## 4. Prueba contra el esquema real

`supabase/sql/153_test_editar_horario_y_politicas.sql`, con
`begin; ... rollback;` contra el tenant real "Cortes y Barbas": **8 de 8
verificaciones aprobadas**:

1. Editar los 7 días de horario actualiza correctamente (domingo a medio
   día).
2. Enviar solo 6 días falla (exige los 7 completos).
3. Apertura después del cierre falla.
4. Editar la política de citas actualiza anticipo y horas.
5. Porcentaje de anticipo fuera de rango (0-100) falla.
6. Editar la política de comisión actualiza tipo y porcentaje.
7. Tipo de comisión inválido (fuera de `percentage`/`fixed`) falla.
8. Un usuario de otro tenant no puede editar nada aquí.

Desplegado al único proyecto real con `supabase db push --linked`.

## 5. Flutter

- `BusinessHoursService.updateBusinessHours`,
  `AppointmentPolicyService.updateAppointmentPolicy`,
  `CommissionPolicyService.updateCommissionPolicy` (este último ahora
  requiere `branchId` en el constructor, antes no lo tenía).
- `ConfiguracionPage`: cada tarjeta (Horario, Política de citas, Comisión)
  tiene botón "Editar" con diálogo propio; el horario usa selector de hora
  nativo por día con interruptor abierto/cerrado.

`flutter analyze`: sin hallazgos. `flutter test`: 5 pruebas aprobadas.

## 6. Fuera de alcance

- Editar datos del negocio (nombre, contacto, redes) — no se pidió en
  este bloque.
- Horario/políticas distintos por sede para negocios multi-sede más allá
  de lo que ya soporta el modelo de datos (branch_id ya existe; no hay UI
  para gestionar varias sedes todavía).

## 7. Siguiente bloque

Según la ruta acordada: reserva pública de cliente.
