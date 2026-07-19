# ADR-002 — Membresías en lugar de un rol único en el perfil

**Estado:** aceptada  
**Fecha:** 2026-07-19

## Contexto

`user_profiles` guarda actualmente tenant y rol únicos. Una misma cuenta deberá poder participar en varios tenants o sedes y el equipo de plataforma no debe mezclarse con los roles del salón.

## Decisión

Mantener `user_profiles` como identidad global y trasladar autorización a `tenant_memberships` y `branch_memberships`. El rol de plataforma se administra en un dominio separado.

## Consecuencias

- Una cuenta puede pertenecer a varios negocios.
- Los permisos se revocan sin borrar la identidad ni la autoría histórica.
- RLS consulta membresías activas.
- Flutter necesita selección de contexto cuando haya más de una opción.
- Los campos antiguos se conservan durante la migración y se retiran después.

## Alternativa descartada

Guardar una lista de tenants/roles en metadatos del token: puede quedar desactualizada y dificulta integridad, revocación y auditoría.

