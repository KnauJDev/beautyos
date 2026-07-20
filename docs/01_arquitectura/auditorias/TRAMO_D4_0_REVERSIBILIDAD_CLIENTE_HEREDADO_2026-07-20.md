# Tramo D4.0 — Reversibilidad y cliente heredado

**Fecha:** 20 de julio de 2026
**Estado:** verificado localmente
**Producción modificada:** no
**Base Git:** `966c83b Revocar acceso heredado del Tramo D3.4`

## 1. Objetivo

Comprobar que la revocación D3.4 bloquea una instalación autenticada antigua,
que el permiso puede restaurarse de forma controlada y que el estado revocado
puede reaplicarse sin afectar los contratos `_v2`.

## 2. Prueba reversible

`supabase/sql/126_test_tramo_d4_reversion_cliente_heredado.sql` se ejecutó sobre
`beautyos-tramo-c-test` con `ROLLBACK`:

1. confirmó inicialmente que las seis RPC heredadas no tienen `EXECUTE` para
   `authenticated`;
2. reotorgó temporalmente `EXECUTE` a `authenticated` y comprobó que una
   invocación de cliente heredado ya no falla por privilegio;
3. verificó que `anon` siguió bloqueado y `service_role` conservó acceso;
4. revocó de nuevo `authenticated` y confirmó el estado endurecido;
5. comprobó que las seis RPC `_v2` conservaron `authenticated=true` y
   `anon=false`.

La transacción terminó con `ROLLBACK`, por lo que el contenedor quedó en el
estado D3.4: acceso heredado externo revocado y funciones aún presentes.

## 3. Conclusión de compatibilidad

Un cliente autenticado desactualizado no obtiene un fallback silencioso: queda
bloqueado de manera explícita al invocar las firmas heredadas. La reversión es
operativa mediante un `GRANT` temporal, pero requiere una decisión separada y
no se ensaya ni se aplica sobre producción.

## 4. Límite pendiente

El asesor de Supabase continúa pendiente de un entorno local conectable a la
CLI; el contenedor restaurado solo permitió validación directa por PostgreSQL.
Antes de cualquier puerta productiva debe repetirse la matriz en un entorno
Supabase conectable y con una fotografía de solo lectura del esquema vivo.

## 5. Cierre

D4.0 queda cerrado como prueba local de reversibilidad y compatibilidad
heredada. El siguiente micro-paso será preparar esa comprobación conectable y
la matriz de clientes desactualizados, sin cambios productivos.
