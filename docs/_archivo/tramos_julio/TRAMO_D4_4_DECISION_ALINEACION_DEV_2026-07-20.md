# Tramo D4.4 — Decisión de alineación de `beautyos-dev`

**Fecha:** 20 de julio de 2026
**Estado:** decidido; sin cambios remotos
**Proyecto objetivo:** `beautyos-dev` (`eogppgbdnwxdtcbctaol`)
**Producción modificada:** no
**Base Git:** `1accbcb Documentar fotografia remota del Tramo D4.3`

## 1. Objetivo

Decidir cómo alinear el entorno Supabase no productivo `beautyos-dev` después de
la brecha detectada en D4.3, sin ejecutar todavía cambios remotos.

## 2. Evidencia

D4.3 confirmó:

- estructura multisede presente;
- 15 tablas operativas con `branch_id` y cero nulos;
- seis RPC heredadas todavía ejecutables por `authenticated`;
- seis RPC `_v2` de D3.2 ausentes.

En D4.4 se revisó además, solo lectura, el historial remoto de migraciones:

- existe `supabase_migrations.schema_migrations`;
- no hay registros para `20260720183122` ni `20260720190528`;
- las últimas migraciones registradas llegan hasta
  `20260720152000 tramo_c3_caja_reportes_inventario_por_sede`;
- la tabla de historial contiene `version`, `statements`, `name`,
  `created_by`, `idempotency_key` y `rollback`.

## 3. Decisión

`beautyos-dev` debe alinearse con las migraciones locales:

1. `20260720183122_tramo_d3_2_reemplazos_lectura_por_sede.sql`
2. `20260720190528_tramo_d3_4_revocar_rpc_heredadas.sql`

El orden es obligatorio: primero crear los seis reemplazos `_v2`, luego revocar
el acceso externo de las seis firmas heredadas.

## 4. Restricción de mecanismo

La alineación debe preservar trazabilidad de migración. El mecanismo preferido
para D4.5 será uno de estos, en orden:

1. **Mecanismo versionado de Supabase/CLI**, si puede vincularse a
   `beautyos-dev` sin exponer secretos en el repositorio.
2. **Mecanismo MCP equivalente que registre historial**, si está disponible.
3. **Fallback por SQL directo**, solo si el usuario autoriza explícitamente que
   el entorno no productivo sea alineado sin historial automático o con registro
   manual documentado.

No se insertará manualmente en `supabase_migrations.schema_migrations` sin una
microdecisión separada.

## 5. Verificación requerida después de alinear

D4.5 debe ejecutar, como mínimo:

- la fotografía D4.3;
- `124_verify_tramo_d3_2_reemplazos_lectura_por_sede.sql`;
- prueba de revocación equivalente a D3.4 sin exponer datos sensibles;
- asesores de seguridad/performance si el conector o CLI lo permite.

## 6. Cierre

D4.4 queda cerrado como decisión de alineación. No se ejecutó DDL, DML, `GRANT`,
`REVOKE` ni cambios remotos. El siguiente micro-paso es preparar o ejecutar el
mecanismo versionado de D4.5 con autorización explícita.
