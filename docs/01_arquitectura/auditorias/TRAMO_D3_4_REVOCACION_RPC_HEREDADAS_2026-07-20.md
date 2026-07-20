# Tramo D3.4 — Revocación local reversible de RPC heredadas

**Fecha:** 20 de julio de 2026
**Estado:** verificado localmente
**Producción modificada:** no
**Base Git:** `718ca3e Documentar inventario final del Tramo D3.3`

## 1. Alcance

Se cerró el acceso externo de seis RPC heredadas ya sustituidas por contratos
`_v2` por sede, sin eliminarlas ni tocar datos, triggers, Flutter o Supabase en
producción:

- `get_appointment_policy()`;
- `get_business_hours()`;
- `get_dashboard_metrics()`;
- `get_my_stylist_work_photos()`;
- `get_reviews_summary()`;
- `get_work_photos_summary()`.

## 2. Cambio aplicado en ensayo aislado

La migración `20260720190528_tramo_d3_4_revocar_rpc_heredadas.sql` revoca
`EXECUTE` a `PUBLIC`, `anon` y `authenticated`, y conserva temporalmente el
permiso solo para `service_role`. Las seis funciones permanecen presentes para
una reversión controlada; no se realiza `DROP FUNCTION`.

La migración se aplicó dos veces sobre `beautyos-tramo-c-test` sin errores.

## 3. Verificaciones

1. `125_test_tramo_d3_4_revocacion_rpc_heredadas.sql` confirmó, mediante
   invocación real, que `anon` y `authenticated` reciben
   `insufficient_privilege` en las seis firmas heredadas.
2. `124_verify_tramo_d3_2_reemplazos_lectura_por_sede.sql` ahora exige que las
   firmas heredadas sigan presentes, pero sin `EXECUTE` para `PUBLIC`, `anon`
   ni `authenticated`, y con permiso para `service_role`.
3. `123_test_tramo_d3_2_reemplazos_lectura_por_sede.sql` pasó después de la
   revocación: las seis RPC `_v2` conservaron autorización por rol y sede,
   aislamiento entre tenants y pruebas negativas.

Matriz final en el ensayo aislado: las seis firmas heredadas tienen
`PUBLIC=false`, `anon=false`, `authenticated=false` y `service_role=true`.

## 4. Reversión y límite

La reversión consiste únicamente en reotorgar `EXECUTE` a los roles que se
decida restaurar; no requiere recuperar datos ni reinstalar fallbacks Flutter.
No se autoriza esa restauración ni un cambio productivo mediante este informe.

El asesor de seguridad de Supabase no pudo conectarse al contenedor restaurado,
porque no es una pila local completa gestionada por la CLI. La verificación de
catálogo, permisos e invocaciones se ejecutó directamente contra PostgreSQL y
pasó; antes de una acción productiva deberá repetirse la revisión sobre un
entorno Supabase conectable y el esquema vivo.

## 5. Cierre

D3.4 queda cerrado como paso local y reversible. El siguiente tramo deberá
ampliar el ensayo de seguridad, reversión y compatibilidad antes de proponer
cualquier cambio en producción.
