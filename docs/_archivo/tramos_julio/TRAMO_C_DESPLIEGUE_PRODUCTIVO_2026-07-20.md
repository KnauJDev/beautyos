# Tramo C — despliegue y validación productiva

**Fecha:** 20 de julio de 2026
**Proyecto Supabase:** `eogppgbdnwxdtcbctaol`
**Estado:** aprobado en producción
**Alcance:** contexto efectivo de sede, reservas, agendas, operación de tickets, pagos, caja, reportes e inventario por sede

## 1. Dictamen

El Tramo C fue desplegado correctamente en producción después de aprobar su cadena completa en una restauración aislada. Supabase registró las cuatro migraciones previstas, las auditorías productivas C1–C4 terminaron sin excepciones, la paridad de la Sede principal se conservó y Flutter mantuvo análisis y pruebas limpios.

El despliegue no retiró firmas heredadas, no ejecutó datos semilla, no hizo un reinicio remoto y no convirtió todavía `branch_id` a `NOT NULL`. La compatibilidad permite volver temporalmente a la versión anterior de la aplicación si fuera necesario.

## 2. Respaldo anterior al cambio

Se creó un respaldo nuevo fuera del repositorio:

`C:\Users\Tercero\OneDrive\Documents\BeautyOS Backups\BeautyOS_Backup_2026-07-20_11-23-05`

| Archivo | Tamaño | SHA-256 |
|---|---:|---|
| `roles.sql` | 297 bytes | `25873CEC56A2CC6514E204F420231777F85C03DA818CAA7090CDCDFA89776ECD` |
| `schema.sql` | 222.145 bytes | `724F3CC16B19576AAD2B93711C1E9AAD7F262155B62288186B166518F2CDDBA7` |
| `data.sql` | 81.187 bytes | `CF3B88133C5072BAA48BA99704DF0C316B58FF523FB2AE8B878E642973A23083` |

No se guardaron contraseñas ni cadenas de conexión en el repositorio.

## 3. Vista previa y migraciones aplicadas

Supabase CLI `2.109.1` confirmó que el remoto estaba sincronizado hasta el Tramo B. La simulación propuso únicamente:

1. `20260720123813_tramo_c1_contexto_sede_efectiva.sql`;
2. `20260720130708_tramo_c2a_reservas_agendas_por_sede.sql`;
3. `20260720135200_tramo_c2b_operacion_ticket_por_sede.sql`;
4. `20260720152000_tramo_c3_caja_reportes_inventario_por_sede.sql`.

Las cuatro fueron aplicadas en ese orden con `db push --linked`. El historial remoto posterior contiene las quince migraciones locales y remotas esperadas.

## 4. Auditorías productivas

| Evidencia | Resultado |
|---|---|
| `112_verify_tramo_c1_branch_context.sql` | aprobado |
| `114_verify_tramo_c2a_reservas_agendas_por_sede.sql` | aprobado |
| `116_verify_tramo_c2b_operacion_ticket_por_sede.sql` | aprobado |
| `118_verify_tramo_c3_caja_reportes_inventario_por_sede.sql` | aprobado |
| `119_test_tramo_c4_paridad_sede_principal.sql` | aprobado y revertido |
| `120_verify_tramo_c4_criterios_salida.sql` | aprobado |

La auditoría final observó:

- 1 tenant activo;
- 1 sede activa;
- 30 funciones públicas `_v2`;
- 12 tickets;
- pagos vigentes por 250.000;
- comisiones vigentes por 100.000;
- stock agregado de sede por 2.530.

Estos valores coinciden con la línea base usada en el ensayo y no fueron creados por las auditorías.

## 5. Seguridad e integridad

- Las funciones nuevas son `SECURITY DEFINER`, fijan `search_path=pg_catalog`, deniegan `anon` y validan identidad, rol, tenant y sede antes de operar.
- El helper sensible permanece en `private` y no es ejecutable directamente por `authenticated`.
- Las 15 tablas operativas conservan sede no nula y coherente con su tenant.
- Las claves foráneas multisede están validadas y los 15 triggers de compatibilidad continúan presentes.
- No aparecieron alertas de nivel `ERROR` en los asesores oficiales.

### Línea base de asesores

- Seguridad: 29 avisos informativos por RLS sin políticas directas. Es deliberado porque esas tablas se mantienen cerradas y la aplicación opera mediante RPC autorizadas.
- Seguridad: 82 advertencias sobre RPC `SECURITY DEFINER` ejecutables por `authenticated`. La exposición es intencional; los contratos C fueron auditados con permisos mínimos, `search_path` fijo y validaciones internas. El inventario completo de RPC heredadas seguirá bajo revisión de endurecimiento.
- Seguridad: 1 recomendación pendiente para activar protección contra contraseñas filtradas.
- Rendimiento: 2 recomendaciones para optimizar políticas RLS de `user_profiles` con evaluación única de `auth.uid()`.
- Rendimiento: 76 índices sin uso registrado. No se retiraron porque varios son nuevos o preventivos y la muestra productiva aún es pequeña.

Referencias de remediación: lints `0008`, `0029`, protección de contraseñas, `0003` y `0005` en la documentación oficial de Supabase.

## 6. Aplicación Flutter

- `flutter analyze`: sin hallazgos.
- `flutter test`: 3 pruebas aprobadas.
- El contexto de sede, el cambio de sede y la compatibilidad temporal permanecen activos.

## 7. Reversión y límites

La reversión inmediata prevista es volver a la versión anterior de Flutter, que conserva las firmas heredadas. No se debe eliminar todavía ninguna firma antigua ni los triggers puente. Una reversión física de base de datos solo se considerará ante una falla real y partiría del respaldo verificado.

El Tramo C no completa por sí solo la Fase 1. Continúan pendientes, entre otros, el consolidado autorizado A1+A2, Customer, operador de plataforma, suscripciones/entitlements y el cierre integral de seguridad.

## 8. Resultado

**Tramo C aprobado en producción.** BeautyOS ya posee una base operativa consciente de sede para administración, estilistas, reservas, agenda, tickets, pagos, caja, reportes e inventario, manteniendo compatibilidad con la Sede principal existente.
