# Tramo D4.3 — Fotografía SQL remota de solo lectura

**Fecha:** 20 de julio de 2026
**Estado:** ejecutado; brecha detectada en entorno no productivo
**Proyecto:** `beautyos-dev` (`eogppgbdnwxdtcbctaol`)
**Producción modificada:** no
**Base Git:** `81ffd05 Preparar fotografia SQL del Tramo D4.3`

## 1. Objetivo

Ejecutar la fotografía SQL de solo lectura preparada en D4.3-pre sobre el
entorno Supabase no productivo `beautyos-dev`, sin aplicar migraciones, sin
modificar permisos y sin consultar filas sensibles de negocio.

## 2. Alcance ejecutado

Se ejecutaron consultas de solo lectura mediante el conector Supabase:

- contexto de base y transacción;
- matriz de las seis RPC heredadas y sus seis reemplazos `_v2`;
- existencia de tablas multisede y columna `branch_id`;
- conteos agregados y nulos de `branch_id` en las 15 tablas operativas.

El SQL ejecutado no contiene DDL, DML, `GRANT`, `REVOKE` ni llamadas a RPC de
negocio. Las consultas se ejecutaron con `transaction_read_only = on` y cierre
`ROLLBACK`.

## 3. Resultado de contexto

| Control | Resultado |
| --- | --- |
| Base | `postgres` |
| Usuario de ejecución | `postgres` |
| Postgres | `17.6` |
| Transacción | `READ ONLY` |

## 4. Resultado de tablas y datos agregados

Todas las tablas esperadas existen. Las 15 tablas operativas del alcance tienen
columna `branch_id` y reportaron cero nulos.

| Tabla | Filas | `branch_id` nulos |
| --- | ---: | ---: |
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

## 5. Resultado de RPC

La fotografía detectó que `beautyos-dev` no está alineado con D3.2-D3.4:

- las seis RPC heredadas existen y conservan forma de respuesta compatible;
- las seis RPC heredadas no son ejecutables por `PUBLIC` ni `anon`;
- las seis RPC heredadas sí siguen ejecutables por `authenticated`;
- las seis RPC heredadas sí siguen ejecutables por `service_role`;
- las seis RPC `_v2` de D3.2 no existen en este entorno;
- por lo tanto, tampoco está presente la matriz esperada de `_v2` con
  `authenticated = true`, `anon = false`, helper de sede y
  `search_path=pg_catalog`.

## 6. Interpretación

`beautyos-dev` parece tener aplicada la estructura multisede y el backfill de
datos, pero no contiene todavía los reemplazos `_v2` ni la revocación heredada
preparada y verificada localmente en D3.2-D3.4.

Esto no modifica producción ni cambia el estado local. Sí bloquea cualquier
ensayo remoto de cliente heredado D4 sobre `_v2`, porque el entorno no tiene las
funciones necesarias.

## 7. Cierre

D4.3 queda cerrado como fotografía remota de solo lectura. El siguiente
micro-paso debe decidir cómo alinear `beautyos-dev` con las migraciones locales
D3.2 y D3.4 antes de repetir pruebas de cliente heredado contra un entorno
conectable.
