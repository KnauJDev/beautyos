# Tramo D4.6 — alineación versionada de `beautyos-dev`

**Fecha:** 20 de julio de 2026
**Estado:** completado en entorno no productivo
**Proyecto objetivo:** `beautyos-dev` (`eogppgbdnwxdtcbctaol`)
**Producción modificada:** no
**Entorno no productivo modificado:** sí
**Base Git:** `dfaac36 Preparar mecanismo versionado del Tramo D4.5`

## 1. Objetivo

Alinear `beautyos-dev` con las migraciones locales D3.2 y D3.4 usando un
mecanismo de migración versionado del conector Supabase, sin usar SQL directo
como ruta primaria y sin tocar producción.

## 2. Precondiciones verificadas

Antes de aplicar cambios se revisaron las fuentes canónicas del tramo, el estado
de Git y Supabase CLI:

- `git status --short`: limpio.
- `git log -1 --oneline`: `dfaac36 Preparar mecanismo versionado del Tramo D4.5`.
- Supabase CLI disponible: `2.109.1`.
- El changelog oficial de Supabase fue consultado el 20/07/2026; no se detectó
  un cambio reciente que altere el criterio de aplicación de migraciones para
  D4.6.
- El historial remoto de `beautyos-dev` llegaba hasta
  `20260720152000_tramo_c3_caja_reportes_inventario_por_sede`.

## 3. Migraciones aplicadas

Se aplicaron dos migraciones MCP separadas, en el orden aprobado:

| Orden | Migración local | Registro remoto MCP |
|---|---|---|
| 1 | `20260720183122_tramo_d3_2_reemplazos_lectura_por_sede.sql` | `20260720200109_tramo_d3_2_20260720183122_reemplazos_lectura_por_sede` |
| 2 | `20260720190528_tramo_d3_4_revocar_rpc_heredadas.sql` | `20260720200141_tramo_d3_4_20260720190528_revocar_rpc_heredadas` |

El conector registra sus propias versiones remotas; por eso se conservó el
número local dentro del nombre de cada migración MCP.

## 4. Verificación remota

La verificación posterior confirmó:

- Base remota: `postgres`.
- Usuario de ejecución: `postgres`.
- Versión Postgres: `17.6`.
- Las seis RPC `_v2` existen.
- Las seis RPC `_v2` son `SECURITY DEFINER`, tienen
  `search_path=pg_catalog`, usan `private.beautyos_resolve_branch_access` y
  reciben `p_branch_id`.
- Las seis RPC `_v2` no son ejecutables por `anon` ni `PUBLIC`.
- Las seis RPC `_v2` sí son ejecutables por `authenticated` y `service_role`.
- Las seis firmas heredadas existen para reversión, pero ya no son ejecutables
  por `PUBLIC`, `anon` ni `authenticated`.
- Las seis firmas heredadas conservan `EXECUTE` para `service_role`.

Se ejecutó además `124_verify_tramo_d3_2_reemplazos_lectura_por_sede.sql` contra
`beautyos-dev`; la validación terminó sin excepciones.

## 5. Fotografía agregada de datos operativos

Las 15 tablas operativas del tramo conservaron cero `branch_id` nulos:

| Tabla | Filas | `branch_id` nulos |
|---|---:|---:|
| `appointment_policies` | 1 | 0 |
| `business_hours` | 7 | 0 |
| `expenses` | 3 | 0 |
| `inventory_movements` | 5 | 0 |
| `purchase_items` | 4 | 0 |
| `purchases` | 2 | 0 |
| `reviews` | 3 | 0 |
| `stylist_commissions` | 8 | 0 |
| `ticket_history` | 42 | 0 |
| `ticket_payments` | 12 | 0 |
| `ticket_service_change_history` | 10 | 0 |
| `ticket_service_history` | 14 | 0 |
| `ticket_services` | 13 | 0 |
| `tickets` | 12 | 0 |
| `work_photos` | 3 | 0 |

## 6. Asesores Supabase

Se ejecutaron asesores de seguridad y rendimiento.

Hallazgos relevantes:

- Seguridad:
  - `INFO`: tablas con RLS activo y sin políticas directas. Este patrón ya
    existía en el modelo actual porque la operación se concentra en RPC.
  - `WARN`: RPC `SECURITY DEFINER` ejecutables por `authenticated`; en las RPC
    `_v2` de D3.2 esto es intencional y compensado por autorización backend de
    tenant, rol y sede.
  - `WARN`: protección de contraseñas filtradas desactivada en Supabase Auth.
- Rendimiento:
  - `WARN`: políticas de `user_profiles` pueden optimizar llamadas a `auth`.
  - `INFO`: índices sin uso detectado, esperable en un entorno pequeño de
    ensayo y no apto para eliminación automática.

No se realizó ningún cambio adicional por asesores en D4.6.

## 7. Cierre

D4.6 queda cerrado: `beautyos-dev` está alineado con D3.2 y D3.4 mediante
migraciones versionadas MCP. Producción no fue modificada.

La siguiente microcompuerta recomendada es D4.7: validar explícitamente el
comportamiento de cliente heredado y reversibilidad en `beautyos-dev`, ya con el
entorno alineado.
