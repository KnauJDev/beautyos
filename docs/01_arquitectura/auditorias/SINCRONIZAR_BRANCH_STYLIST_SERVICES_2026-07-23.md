# Sincronizar asignaciones estilista-servicio con la sede

**Fecha:** 23 de julio de 2026
**Estado:** desplegado en el único proyecto real; asignación real reparada

## 1. Objetivo

El propietario probó de punta a punta: creó un servicio, un estilista, le
asignó el servicio desde "Gestionar servicios", y al intentar crear un
ticket la agenda no mostró ninguna hora disponible después de elegir
fecha.

## 2. Causa raíz (confirmada con datos reales, no supuesta)

`set_stylist_services()` (`091_manage_stylist_capabilities_and_enforce_schedule.sql`,
anterior a esta sesión) solo escribe `stylist_services` — catálogo del
tenant. La agenda y las reservas (Tramo C2a) solo consultan
`branch_stylist_services` — fila de sede. Se verificó con
`supabase db query --linked` contra el tenant real "Cortes y Barbas":
la asignación "Nicolas Alonso → Corte de Pelo" existía en
`stylist_services` pero `branch_stylist_services` tenía **0 filas** para
esa combinación, y `get_available_appointment_slots_v2` devolvía 0
horarios en consecuencia.

Es el mismo patrón ya corregido ese mismo día en `create_service`/
`create_stylist` (`20260723152713`), pero en una función que ya existía
antes de esta sesión y que nadie había ejercitado de punta a punta hasta
ahora (todo tenant previo se sembraba con datos ya consistentes por SQL).

## 3. Corrección

`set_stylist_services()` ahora, además de sincronizar `stylist_services`,
sincroniza `branch_stylist_services` para cada sede donde el estilista
esté activo (`branch_stylists`) y el servicio tenga fila de sede
(`branch_services`): desactiva combinaciones que ya no aplican e
inserta/reactiva las nuevas. No cambia la firma ni la autorización de la
función original (sigue usando el patrón heredado `user_profiles.role`,
no memberships — coherente con que nunca pasó por D3.5.3).

## 4. Prueba y reparación

`supabase/sql/146_test_sincronizar_branch_stylist_services.sql` (con
`rollback`): reafirmar la misma asignación deja **47 horarios
disponibles** para el día siguiente (antes: 0).

`supabase/sql/147_reparar_asignacion_real_cortes_y_barbas.sql` (sin
rollback, a propósito): se volvió a ejecutar `set_stylist_services` para
el tenant real "Cortes y Barbas", reparando la asignación existente sin
que el propietario tenga que rehacerla a mano.

`supabase/sql/148_auditar_asignaciones_sin_sede.sql`: se auditaron
**todos** los tenants reales buscando asignaciones activas sin fila de
sede — **0 resultados** además del caso ya reparado. Bella Mujer y el
resto de tenants de prueba no estaban afectados.

Desplegado al único proyecto real con `supabase db push --linked`
(`create or replace function`, conserva los privilegios existentes).

## 5. Siguiente paso para el propietario

Con esto reparado, la creación de un ticket para "Cortes y Barbas" con
Nicolas Alonso / Corte de Pelo debería mostrar horarios disponibles al
elegir fecha, sin necesidad de reabrir "Gestionar servicios".
