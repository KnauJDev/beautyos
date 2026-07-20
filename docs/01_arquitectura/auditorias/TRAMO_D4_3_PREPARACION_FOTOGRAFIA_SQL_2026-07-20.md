# Tramo D4.3-pre — Preparación de fotografía SQL de solo lectura

**Fecha:** 20 de julio de 2026
**Estado:** preparado localmente; pendiente de validación antes de ejecución remota
**Producción modificada:** no
**Base Git:** `2ee9a2a Seleccionar entorno no productivo del Tramo D4.2`

## 1. Objetivo

Preparar el SQL exacto que se ejecutará en D4.3 contra `beautyos-dev`
(`eogppgbdnwxdtcbctaol`) únicamente si el usuario valida explícitamente que el
proyecto no es producción ni contiene datos productivos sensibles fuera del
alcance autorizado.

## 2. Archivo preparado

Se agregó `supabase/sql/127_snapshot_tramo_d4_3_entorno_no_productivo.sql`.

El archivo:

- abre una transacción `READ ONLY`;
- termina con `ROLLBACK`;
- no contiene DDL, DML, `GRANT`, `REVOKE` ni llamadas a RPC de negocio;
- consulta solo metadatos, privilegios, firmas, configuración de funciones y
  conteos agregados;
- evita retornar filas de negocio, nombres de clientes, teléfonos, documentos,
  correos, URLs de fotos o comentarios.

## 3. Controles incluidos

La fotografía preparada confirma:

1. Base, usuario de ejecución, versión Postgres y modo `transaction_read_only`.
2. Existencia de las seis RPC heredadas y sus seis reemplazos `_v2`.
3. Forma de respuesta esperada para las doce firmas.
4. Matriz `PUBLIC`, `anon`, `authenticated` y `service_role`.
5. Uso de `SECURITY DEFINER`, `search_path=pg_catalog` y helper de sede en las
   firmas `_v2`.
6. Presencia de `branch_id` en las tablas del alcance multisede.
7. Conteos agregados y nulos de `branch_id` en las 15 tablas operativas.

## 4. Límite de este micro-paso

No se ejecutó SQL remoto. D4.3 queda listo, pero bloqueado hasta la validación
explícita del entorno `beautyos-dev`.
