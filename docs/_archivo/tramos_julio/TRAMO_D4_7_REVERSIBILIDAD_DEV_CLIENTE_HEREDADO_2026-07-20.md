# Tramo D4.7 — reversibilidad en `beautyos-dev` con cliente heredado

**Fecha:** 20 de julio de 2026
**Estado:** completado en entorno no productivo
**Proyecto objetivo:** `beautyos-dev` (`eogppgbdnwxdtcbctaol`)
**Producción modificada:** no
**Entorno no productivo modificado:** sí, solo permisos temporales con estado final endurecido
**Base Git:** `b78d397 Documentar alineacion versionada del Tramo D4.6`

## 1. Objetivo

Validar en `beautyos-dev`, ya alineado con D3.2 y D3.4, que:

1. un cliente autenticado heredado queda bloqueado sobre las seis firmas sin
   sede;
2. un `GRANT` temporal permite una reversión controlada;
3. `anon` no obtiene acceso durante la reversión;
4. `service_role` conserva acceso temporal de emergencia;
5. el estado endurecido puede reaplicarse al final;
6. las seis RPC `_v2` permanecen intactas.

## 2. Precondiciones verificadas

Antes de ejecutar la prueba:

- `git status --short`: limpio.
- `git log -1 --oneline`: `b78d397 Documentar alineacion versionada del Tramo D4.6`.
- Se releyeron las fuentes canónicas del tramo.
- Se consultó el changelog oficial de Supabase el 20/07/2026; no se detectó un
  cambio reciente que modifique el criterio de permisos `GRANT`/`REVOKE` para
  esta prueba.
- El historial remoto de `beautyos-dev` contenía D3.2 y D3.4, y no se creó una
  nueva migración para D4.7 porque el micro-paso fue de reversibilidad, no de
  cambio permanente de esquema.

## 3. Prueba ejecutada

Se ejecutó una prueba remota controlada sobre estas seis firmas heredadas:

- `public.get_appointment_policy()`
- `public.get_business_hours()`
- `public.get_dashboard_metrics()`
- `public.get_my_stylist_work_photos()`
- `public.get_reviews_summary()`
- `public.get_work_photos_summary()`

Para cada firma se validó:

| Fase | Resultado esperado |
|---|---|
| Estado inicial | `authenticated` no tiene `EXECUTE` |
| Reversión temporal | `GRANT EXECUTE` a `authenticated` funciona |
| Control de exposición | `anon` no obtiene `EXECUTE` |
| Emergencia | `service_role` conserva `EXECUTE` |
| Simulación heredada | la llamada con rol `authenticated` deja de fallar por privilegio |
| Reaplicación | `REVOKE` vuelve a bloquear `authenticated` |

La prueba completó las seis firmas sin excepciones.

## 4. Resultado observado

En las seis firmas heredadas:

- `initial_authenticated_execute = false`
- `after_grant_authenticated_execute = true`
- `anon_execute_during_grant = false`
- `service_role_execute_during_grant = true`
- `invocation_still_blocked_after_grant = false`
- `final_authenticated_execute = false`

Esto confirma que la reversión temporal es viable y que el endurecimiento puede
reaplicarse sin dejar acceso heredado abierto.

## 5. Estado final independiente

Después de la prueba se ejecutó una verificación independiente del estado final:

- Las seis firmas heredadas existen.
- `PUBLIC`, `anon` y `authenticated` no tienen `EXECUTE` sobre las heredadas.
- `service_role` conserva `EXECUTE` sobre las heredadas.
- Las seis RPC `_v2` existen.
- `PUBLIC` y `anon` no tienen `EXECUTE` sobre las `_v2`.
- `authenticated` y `service_role` conservan `EXECUTE` sobre las `_v2`.
- Las seis RPC `_v2` conservan `search_path=pg_catalog`.

El historial remoto permaneció igual que al cierre de D4.6:

- `20260720200109_tramo_d3_2_20260720183122_reemplazos_lectura_por_sede`
- `20260720200141_tramo_d3_4_20260720190528_revocar_rpc_heredadas`

No se registró una migración nueva para D4.7.

## 6. Cierre

D4.7 queda cerrado. `beautyos-dev` permanece endurecido y con reversibilidad
demostrada para las seis firmas heredadas sustituidas.

La siguiente microcompuerta recomendada es D4.8: preparar la decisión de avance a
D5 o, si se prefiere máxima prudencia, repetir una fotografía completa de salida
en `beautyos-dev` y consolidar el paquete de criterios antes de cualquier acción
productiva.
