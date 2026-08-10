# HANDOFF BeautyOS — pasos 1173–1184

**Fecha:** 20 de julio de 2026  
**Bloque documentado:** Tramo C2a–C2b — reservas, tickets, agenda y pagos conscientes de sede  
**Estado:** backend C2 implementado y aprobado en ensayo; conexión Flutter pendiente; producción no modificada; cambios locales pendientes de publicación  
**Modelo recomendado para la siguiente compuerta:** GPT-5.6 Sol, esfuerzo Alto durante la introducción del contexto global de sede; Terra Medio para pruebas visuales repetitivas

## Resumen ejecutivo

BeautyOS ya dispone, fuera de producción, de contratos seguros `_v2` para ejecutar el flujo reserva → ticket → servicio → agenda → estados → pago con sede explícita y revalidada en Supabase. C2a cubrió consultas, disponibilidad y creación; C2b cubrió la operación posterior del ticket y la barrera final de choques.

Las pruebas demostraron separación entre A1/A2 y Tenant B, uso de catálogos por sede, cruces permitidos entre sedes y prohibidos dentro de la misma sede, así como historial financiero correctamente ligado a la sede. Las firmas heredadas permanecen intactas para permitir una migración gradual de Flutter.

## Pasos registrados

**1173.** Se inventariaron las RPC heredadas de reservas, tickets, agenda, estados, servicios y pagos, identificando sus dependencias por tenant y las zonas horarias fijas.

**1174.** Se implementó `get_ticket_service_options_v2(...)`, filtrando servicios, precios, duraciones y estilistas habilitados por la sede autorizada.

**1175.** Se implementó `get_available_appointment_slots_v2(...)`, calculando franjas desde horario, política, duración y zona horaria de la sede, y descartando cruces existentes.

**1176.** Se implementó `create_scheduled_ticket_with_service_v2(...)` como operación atómica con validación de cliente, servicio, estilista, horario, disponibilidad y sede.

**1177.** Se versionaron los resúmenes `get_tickets_summary_v2(...)`, `get_agenda_summary_v2(...)` y `get_my_stylist_agenda_by_date_v2(...)`, todos con `p_branch_id` obligatorio y contexto C1.

**1178.** La prueba reversible 113 aprobó creación, opciones, disponibilidad y lecturas de agenda en A1/A2, junto con denegaciones de sede y tenant ajenos.

**1179.** La auditoría 114 confirmó existencia, `SECURITY DEFINER`, `search_path=pg_catalog`, ejecución autenticada y ausencia de acceso anónimo en las seis RPC C2a.

**1180.** Se reforzó `enforce_stylist_schedule_conflict()` para serializar por sede y comparar exclusivamente servicios de la misma sede, evitando tanto carreras como falsos choques entre sedes.

**1181.** Se crearon trece RPC C2b para agregar, cambiar, retirar y consultar servicios; reprogramar; cambiar estados; corregir finalizaciones; consultar, registrar y anular pagos.

**1182.** Las operaciones C2b toman precio/duración desde `branch_services`, validan capacidad desde `branch_stylist_services` y exigen que ticket, servicio, profesional y movimientos pertenezcan a la sede efectiva.

**1183.** La prueba reversible 115 aprobó el flujo completo, permitió una franja equivalente en otra sede, rechazó el choque dentro de la misma sede y bloqueó IDs de sede/tenant ajenos.

**1184.** La auditoría 116 confirmó las trece firmas C2b, permisos mínimos, `search_path` seguro y la barrera de agenda aislada por sede. No se ejecutó `db push`, no se modificó producción y no se hizo `git push`.

## Evidencia técnica

- Migración C2a: `supabase/migrations/20260720130708_tramo_c2a_reservas_agendas_por_sede.sql`
- Prueba C2a: `supabase/sql/113_test_tramo_c2a_reservas_agendas_por_sede.sql`
- Auditoría C2a: `supabase/sql/114_verify_tramo_c2a_reservas_agendas_por_sede.sql`
- Migración C2b: `supabase/migrations/20260720135200_tramo_c2b_operacion_ticket_por_sede.sql`
- Prueba C2b: `supabase/sql/115_test_tramo_c2b_operacion_ticket_por_sede.sql`
- Auditoría C2b: `supabase/sql/116_verify_tramo_c2b_operacion_ticket_por_sede.sql`
- Ensayo desechable: PostgreSQL local `beautyos-tramo-c-test`, restaurado desde `BeautyOS_Backup_2026-07-20_06-57-21`

## Próxima compuerta

Crear el contexto de sede en Flutter, seleccionar automáticamente cuando exista una sola opción y migrar primero Tickets y Agenda a las RPC `_v2`. Después se implementará C3 para caja, reportes e inventario por sede y se ejecutará C4 con paridad heredada e integral por rol. Las alertas operativas continúan pausadas.
