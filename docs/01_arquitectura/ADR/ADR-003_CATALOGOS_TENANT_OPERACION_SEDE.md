# ADR-003 — Catálogos de tenant y operación de sede

**Estado:** aceptada  
**Fecha:** 2026-07-19

## Contexto

Clientes, servicios, profesionales y productos pueden compartirse entre sedes, pero precio, duración, capacidad, horario y stock varían por ubicación.

## Decisión

Conservar clientes, servicios, profesionales y productos como catálogos del tenant; crear relaciones de sede para configuración y disponibilidad. Los tickets guardan snapshots históricos.

## Consecuencias

- No se duplican identidades ni historiales entre sedes del mismo negocio.
- `branch_services`, `branch_stylists`, capacidades y `branch_products` guardan diferencias locales.
- El stock deja de depender de `products.current_stock`.
- Una modificación futura no altera el precio o comisión histórica del ticket.

## Alternativa descartada

Duplicar catálogos por sede: genera inconsistencias, clientes repetidos y consolidación costosa.

