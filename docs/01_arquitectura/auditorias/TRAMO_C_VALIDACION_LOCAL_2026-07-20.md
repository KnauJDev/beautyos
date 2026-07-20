# Tramo C — validación local de operación por sede

**Fecha:** 20 de julio de 2026  
**Estado:** aprobado en ensayo aislado; pendiente de autorización productiva  
**Base de ensayo:** restauración de `BeautyOS_Backup_2026-07-20_06-57-21`  
**Entorno:** contenedor PostgreSQL desechable `beautyos-tramo-c-test`  

## 1. Dictamen

Los componentes C1–C4 cumplen el objetivo local del Tramo C: el cliente Flutter transmite una sede autorizada y Supabase vuelve a resolver tenant, membresía, rol, vigencia y pertenencia de cada recurso antes de leer o escribir. Las operaciones nuevas de reservas, tickets, agenda, pagos, caja, reportes e inventario quedan separadas por sede.

La ruta heredada sigue disponible durante la ventana de compatibilidad. En la Sede principal restaurada, once familias heredadas y sus equivalentes por sede devolvieron resultados idénticos.

Este dictamen no autoriza producción, no elimina contratos antiguos, no convierte todavía `branch_id` a `NOT NULL` y no declara terminada la Fase 1 completa.

## 2. Componentes verificados

### C1 — contexto de sede

- Resolver privado `private.beautyos_resolve_branch_access(...)`.
- Listado seguro `get_my_branch_context_v2()`.
- Owner con A1/A2, Admin restringido y Stylist condicionado por membresía y vínculo profesional.
- Pérdida inmediata del contexto al desactivar membresía, sede o relación profesional.

### C2 — operación

- Opciones de servicio y profesional por sede.
- Disponibilidad con zona horaria de la sede.
- Reserva atómica y barrera final contra choques concurrentes.
- Tickets y agendas administrativa/propia.
- Agregar, reasignar y retirar servicios.
- Reprogramar y cambiar estados.
- Corregir finalizaciones.
- Registrar y anular pagos.

### C3 — caja y stock

- Cierre diario y comisiones por fecha local de la sede.
- Resumen financiero y ventas por sede.
- Compras, detalle de compras y gastos por sede.
- Productos, existencias y movimientos desde `branch_products`.
- A1 permaneció sin cambios mientras A2 recibió movimientos sintéticos con importes exactos.

### C4 — compatibilidad

- Once firmas heredadas permanecen registradas.
- Las firmas por sede producen paridad exacta en la Sede principal cuando el conjunto heredado pertenece íntegramente a ella.
- Los 15 triggers puente del Tramo B continúan disponibles.
- Las claves foráneas multisede están validadas.
- Los índices críticos de agenda, pagos, compras, gastos e inventario están presentes.

## 3. Evidencia ejecutada

| Evidencia | Resultado |
|---|---|
| `111_test_tramo_c1_branch_context.sql` | aprobado |
| `112_verify_tramo_c1_branch_context.sql` | aprobado |
| `113_test_tramo_c2a_reservas_agendas_por_sede.sql` | aprobado |
| `114_verify_tramo_c2a_reservas_agendas_por_sede.sql` | aprobado |
| `115_test_tramo_c2b_operacion_ticket_por_sede.sql` | aprobado |
| `116_verify_tramo_c2b_operacion_ticket_por_sede.sql` | aprobado |
| `117_test_tramo_c3_caja_reportes_inventario_por_sede.sql` | aprobado |
| `118_verify_tramo_c3_caja_reportes_inventario_por_sede.sql` | aprobado |
| `119_test_tramo_c4_paridad_sede_principal.sql` | aprobado |
| `120_verify_tramo_c4_criterios_salida.sql` | aprobado |
| `flutter analyze` | sin hallazgos |
| `flutter test` | 3 pruebas aprobadas |
| `git diff --check` | sin errores |

La auditoría final observó en la restauración: un tenant activo, una sede activa, 12 tickets, pagos vigentes por 250.000, comisiones vigentes por 100.000 y stock agregado de sede por 2.530. Son valores de referencia del respaldo, no datos creados por C4.

## 4. Paridad demostrada

`119_test_tramo_c4_paridad_sede_principal.sql` compara ambas direcciones con `EXCEPT ALL`, por lo que detecta filas faltantes, filas adicionales y duplicados diferentes. Se aprobaron:

1. tickets;
2. agenda administrativa;
3. cierre diario;
4. comisiones diarias;
5. resumen financiero;
6. ventas por servicio y estilista;
7. compras;
8. detalle de compras;
9. gastos;
10. productos y stock;
11. movimientos de inventario.

Antes de comparar, la prueba exige que los datos heredados del tenant estén en la Sede principal. Si existieran operaciones reales en A2, la ruta antigua abarcaría el tenant entero y la equivalencia dejaría de ser un criterio válido.

## 5. Seguridad e integridad

- 29 contratos públicos C1–C3 existen, usan `SECURITY DEFINER`, fijan `search_path=pg_catalog`, niegan `anon` y conceden ejecución a `authenticated`.
- El resolver privado no es ejecutable directamente por `authenticated`.
- Once contratos heredados críticos continúan presentes.
- Las 15 tablas operativas del Tramo B no contienen `branch_id` nulo ni una sede ajena a su tenant.
- Cada tenant activo tiene exactamente una Sede principal.
- Las pruebas negativas bloquearon Tenant B y objetos de otra sede sin revelar su existencia.
- Las escrituras sintéticas de las pruebas 111, 113, 115 y 117 terminaron con `ROLLBACK`.

## 6. Cambios Flutter

- `BranchContext` modela la sede efectiva.
- La aplicación carga contextos, selecciona automáticamente una única sede y permite cambiar entre opciones autorizadas.
- Tickets, Agenda, Mi agenda, Reportes, Compras, Gastos e Inventario se reconstruyen al cambiar de sede.
- Los servicios Flutter usan firmas `_v2` cuando reciben `branchId` y conservan compatibilidad temporal mientras C1 no exista en producción.

## 7. Exclusiones y pendientes reales

- No existe todavía un reporte consolidado A1+A2 para Owner; se diseñará como RPC separada y autorizada.
- Cliente público, operador de plataforma, suscripciones, entitlements y pagos recurrentes pertenecen a tramos posteriores.
- Catálogos compartidos y asignaciones por sede permanecen bajo la arquitectura definida; no se duplicarán sin necesidad.
- Las alertas operativas continúan pausadas por decisión del propietario.
- No se retirarán funciones heredadas ni triggers puente en el mismo despliegue de C.

## 8. Puerta productiva siguiente

Antes de proponer producción se requiere, en una autorización separada:

1. verificar que el repositorio siga limpio y sincronizado;
2. crear un respaldo fresco y verificar sus tres archivos;
3. revisar la vista previa exacta de migraciones C1–C3;
4. confirmar que solo se aplicarán las cuatro migraciones previstas de C;
5. obtener autorización expresa del propietario;
6. aplicar migraciones;
7. repetir auditorías de solo lectura y pruebas Flutter;
8. conservar la reversión compatible mediante la versión anterior de la aplicación.

## 9. Historial local

- `08b98d1` — contexto seguro de sede C1.
- `a84113b` — reservas, tickets y agenda C2.
- `8a83f98` — conexión Flutter al contexto de sede.
- `eca3cfe` — caja, reportes e inventario C3.
- `9360f6e` — compatibilidad y criterios de salida C4.

No se ejecutó `supabase db push`, no se modificó Supabase productivo y no se hizo `git push` durante el Tramo C.
