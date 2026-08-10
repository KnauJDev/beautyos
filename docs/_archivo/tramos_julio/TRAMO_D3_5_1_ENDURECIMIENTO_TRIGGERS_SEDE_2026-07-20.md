# Tramo D3.5.1 — endurecimiento de triggers de sede

**Fecha:** 20 de julio de 2026
**Estado:** implementado y verificado en ensayo local
**Producción modificada:** no
**Conexiones Supabase remotas:** ninguna
**Base Git:** `e72757a Auditar no conformidades del Tramo D`

## 1. Objetivo

Cerrar NC-D-02 localmente: impedir que los seis triggers raíz y los dos
triggers de ticket opcional conviertan silenciosamente un `branch_id` nulo en
la Sede principal, sin retirar los siete triggers que derivan sede desde ticket
o compra como regla de integridad.

## 2. Implementación

Archivos creados:

- `supabase/migrations/20260720222044_tramo_d3_5_1_endurecer_triggers_sede.sql`;
- `supabase/sql/128_test_tramo_d3_5_1_endurecer_triggers_sede.sql`;
- `supabase/sql/129_verify_tramo_d3_5_1_endurecer_triggers_sede.sql`.

La migración reemplaza únicamente
`private.beautyos_resolve_branch(uuid, uuid)`:

- exige `tenant_id` y una sede real;
- rechaza sede nula con SQLSTATE `23502`;
- rechaza sede ajena o inexistente con SQLSTATE `23503`;
- valida pertenencia tenant/sede sin consultar `is_primary`;
- conserva `SECURITY DEFINER`, `search_path=pg_catalog` y ausencia de ejecución
  para `PUBLIC`, `anon` y `authenticated`.

PostgreSQL no permite retirar con `CREATE OR REPLACE` el valor predeterminado de
una función con dependencias. El primer ensayo se detuvo antes de aplicar
cambios. Se conservó la firma compatible `p_branch_id DEFAULT NULL`, pero el
cuerpo rechaza tanto el `NULL` explícito como la omisión del argumento. No
existe selección implícita de Sede principal.

## 3. Triggers preservados

Los 15 triggers continúan activos y vinculados a las mismas funciones:

- **6 raíces estrictos:** horarios, política, tickets, inventario, compras y
  gastos;
- **2 opcionales estrictos cuando no hay ticket:** fotos y reseñas;
- **6 derivados de ticket:** servicios, historiales, pagos y comisiones;
- **1 derivado de compra:** detalle de compra.

Los siete derivados siguen aceptando `branch_id` nulo en la fila hija solo para
copiar la sede obligatoria de su padre y rechazar cruces. Esto es integridad, no
fallback de compatibilidad.

## 4. Evidencia de ensayo

Sobre `beautyos-tramo-c-test`:

1. la línea base confirmó el fallback anterior y 15 triggers activos;
2. la migración corregida se aplicó dos veces satisfactoriamente;
3. el helper aceptó una sede válida y rechazó sede nula, omitida y ajena;
4. una inserción raíz sin sede fue rechazada;
5. una foto sin ticket ni sede fue rechazada;
6. los triggers derivados de ticket y compra repusieron la sede del padre;
7. todas las escrituras de prueba terminaron con `ROLLBACK`;
8. la verificación de solo lectura `129` aprobó;
9. las verificaciones `121` y `124` confirmaron D2 y D3.2/D3.4 intactos.

La auditoría integral `120` conservó:

| Huella | Resultado |
|---|---:|
| Tenants activos | 1 |
| Sedes activas | 1 |
| RPC públicas `_v2` | 36 |
| Tickets | 12 |
| Pagos vigentes | $250.000 |
| Comisiones vigentes | $100.000 |
| Stock por sede | 2.530 |

## 5. Seguridad y límites

El changelog oficial de Supabase fue revisado el 20/07/2026; no se encontró un
cambio aplicable que altere este diseño de PostgreSQL 17. La migración no crea
una función pública, no amplía grants, no toca RLS, datos ni producción.

Se intentó ejecutar `supabase db lint` 2.109.1 contra el puerto publicado del
contenedor, pero la CLI no logró establecer esa conexión. No se sustituyó por
el proyecto remoto ambiguo. La sintaxis y comportamiento sí quedaron probados
por aplicación real con `psql`, reaplicación, prueba transaccional y
verificaciones estructurales. Lint y asesores deben repetirse en el entorno no
productivo inequívoco antes de promover la migración.

NC-D-02 queda **cerrada localmente** y pendiente de repetición en el entorno no
productivo inequívoco antes de cualquier propuesta productiva.

## 6. Siguiente micro-paso

D3.5.2 debe reconciliar localmente las 46 RPC heredadas restantes por los cuatro
grupos ya definidos en D3.0 y preparar el cierre mínimo de privilegios sin
eliminar funciones con consumidores o dependencias.
