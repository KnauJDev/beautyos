# ADR-001 — Separar plataforma, tenant y sede

**Estado:** aceptada  
**Fecha:** 2026-07-19

## Contexto

BeautyOS debe administrar empresas clientes y cada empresa puede operar varias sedes. El modelo actual separa tenants, pero concentra la operación en un único nivel.

## Decisión

Usar tres fronteras explícitas: plataforma BeautyOS, tenant y sede. Los catálogos compartidos pertenecen al tenant; agenda, caja, inventario y operación pertenecen a sede.

## Consecuencias

- Se añade `branch_id` a datos operativos.
- Los reportes admiten sede o consolidado del tenant.
- La autorización comprueba tenant y sede.
- Bella Mujer se migra a una Sede principal.
- Aumenta la complejidad inicial, pero evita reconstruir el producto al incorporar multisede.

## Alternativas descartadas

- Un tenant por sede: duplica clientes, catálogos, facturación y reportes.
- Sede solo como etiqueta: no garantiza aislamiento ni integridad.

