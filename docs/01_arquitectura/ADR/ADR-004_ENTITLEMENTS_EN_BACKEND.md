# ADR-004 — Planes y entitlements aplicados en backend

**Estado:** aceptada  
**Fecha:** 2026-07-19

## Contexto

BeautyOS tendrá planes Básico, Business y Profesional. Ocultar menús no impide llamadas manipuladas a la API.

## Decisión

Modelar planes y funcionalidades como datos y aplicar entitlements dentro de las RPC/políticas. Flutter solo refleja el permiso resuelto. La facturación SaaS queda separada de los pagos operativos.

## Consecuencias

- Cambiar planes no requiere recompilar la aplicación.
- Upgrade/downgrade conserva datos.
- Webhooks deben ser idempotentes y procesados en servidor.
- La suspensión será gradual y reversible.

## Alternativa descartada

Condiciones fijas en Flutter: son vulnerables, difíciles de versionar y no protegen la API.

