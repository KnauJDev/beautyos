# Tramo D3.5.2 - reconciliacion de RPC heredadas

**Fecha:** 20 de julio de 2026
**Estado:** implementado y verificado en ensayo local
**Produccion modificada:** no
**Conexiones Supabase remotas:** ninguna
**Base Git:** `6168d44 Endurecer triggers de sede del Tramo D`

## 1. Objetivo

Cerrar localmente NC-D-03 en su parte de privilegios: reconciliar las 46 RPC
heredadas restantes clasificadas en D3.0, reduciendo ejecucion externa sin
eliminar funciones ni romper consumidores actuales de Flutter o dependencias
internas.

## 2. Matriz aplicada

| Grupo | Cantidad | Decision |
|---|---:|---|
| Operativas retirables | 24 | Revocar `PUBLIC`, `anon` y `authenticated`; conservar `service_role`. |
| Implementaciones internas | 6 | Revocar `PUBLIC`, `anon` y `authenticated`; conservar `service_role` y llamadas desde wrappers `_v2`. |
| Tenant/catalogo | 13 | Revocar `PUBLIC` y `anon`; conservar `authenticated` y `service_role`. |
| Helpers heredados | 3 | Revocar `PUBLIC` y `anon`; conservar `authenticated` y `service_role` hasta migrar dependencias a memberships. |

La consulta previa sobre `beautyos-tramo-c-test` confirmo que las 46 funciones
existian, eran `SECURITY DEFINER`, estaban cerradas para `PUBLIC` directo y
seguian abiertas para `anon` y `authenticated`.

## 3. Implementacion

Archivos creados:

- `supabase/migrations/20260720225344_tramo_d3_5_2_reconciliar_rpc_heredadas.sql`;
- `supabase/sql/130_test_tramo_d3_5_2_reconciliar_rpc_heredadas.sql`;
- `supabase/sql/131_verify_tramo_d3_5_2_reconciliar_rpc_heredadas.sql`.

La migracion no hace `DROP FUNCTION`, no cambia cuerpos, no modifica tablas,
RLS ni datos. Su reversibilidad operativa es un `GRANT EXECUTE` por firma al
rol que se quiera restaurar temporalmente.

El changelog oficial de Supabase fue revisado el 20/07/2026; no se encontro un
cambio aplicable que altere esta estrategia de `REVOKE`/`GRANT EXECUTE` sobre
funciones PostgreSQL expuestas por PostgREST.

## 4. Dependencias preservadas

La inspeccion de cuerpos de funciones confirmo:

- las seis funciones internas siguen referenciadas por sus wrappers `_v2`;
- `get_my_tenant_id` e `is_owner_or_admin` siguen referenciadas por funciones
  heredadas de lectura y administracion;
- `get_my_role` se conserva como helper de identidad hasta una decision
  posterior.

Por eso D3.5.2 reduce superficie anonima y externa sin retirar las piezas que
aun sirven como soporte de transicion.

## 5. Evidencia de ensayo

Sobre `beautyos-tramo-c-test`:

1. la migracion se aplico correctamente;
2. la prueba transaccional `130` valido la matriz de las 46 firmas y termino en
   `ROLLBACK`;
3. la verificacion read-only `131` no reporto desajustes;
4. la verificacion `124` confirmo que las RPC `_v2` del subconjunto D3.2/D3.4
   continuan con acceso esperado;
5. la verificacion `129` confirmo que D3.5.1 sigue vigente;
6. la verificacion `121` confirmo que D2 conserva `branch_id NOT NULL` en las
   15 tablas operativas;
7. la auditoria `120` conservo conteos y huellas financieras.

## 6. Limites

NC-D-03 queda cerrada localmente para privilegios de las 46 RPC restantes, pero
no elimina funciones. El retiro fisico queda para Tramo F o para una decision
posterior con evidencia de cero consumidores externos.

NC-D-04 sigue abierta: la autorizacion heredada basada en `user_profiles` debe
migrarse a memberships o reubicarse formalmente mediante decision
arquitectonica. D5 permanece en NO-GO hasta resolver identidad productiva,
respaldo fresco, ventana y paquete completo.

## 7. Siguiente micro-paso

D3.5.3 debe decidir el tratamiento de la autorizacion basada en `user_profiles`:
migracion gradual a memberships dentro de D o reubicacion formal como deuda
arquitectonica posterior, con decision registrada antes de rehacer D4/D5.
