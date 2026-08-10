# Tramo D2 — obligatoriedad de `branch_id`

**Fecha:** 20 de julio de 2026  
**Estado:** completado y verificado en ensayo; pendiente de producción  
**Producción modificada:** no

## 1. Alcance

D1 eliminó el fallback Flutter al contrato heredado en el commit local `a912394`. D2 agrega una migración separada que exige sede en las 15 tablas operativas inventariadas por D0. No retira triggers, RPC, políticas ni permisos; esa clasificación pertenece a D3.

Archivos:

- `supabase/migrations/20260720175139_tramo_d2_branch_id_not_null.sql`
- `supabase/sql/121_verify_tramo_d2_branch_id_not_null.sql`

## 2. Protección de la migración

La migración se ejecuta en una transacción, limita la espera de bloqueos a cinco segundos y se detiene antes de alterar el esquema si cualquiera de las 15 tablas conserva una fila con `branch_id` nulo. Solo después aplica `NOT NULL` por familias: configuración, tickets e historiales, finanzas e inventario, y evidencia/reputación.

## 3. Evidencia de ensayo

Sobre el contenedor aislado `beautyos-tramo-c-test` se comprobó:

- 15 columnas inicialmente anulables y cero filas sin sede;
- 15 columnas `NOT NULL` después de aplicar D2;
- segunda aplicación correcta;
- prueba negativa con una fila temporal sin sede: la precondición detuvo D2 y la transacción restauró columna, datos y trigger;
- verificación final de solo lectura correcta.

Invariantes conservadas:

| Huella | Resultado |
|---|---:|
| Tickets | 12 |
| Servicios de ticket | 13 |
| Filas en las 15 tablas | 139 |
| Pagos vigentes | $250.000 |
| Pagos anulados | $115.000 |
| Comisiones vigentes | $100.000 |
| Comisiones anuladas | $36.000 |
| Stock por sede | 2.530 unidades |

Los asesores de Supabase no reportaron errores. Mantuvieron dos advertencias de rendimiento preexistentes en políticas de `user_profiles`, ajenas a D2 y sin cambio de severidad.

## 4. Reversibilidad y límite

Antes de producción, la reversión consiste en retirar `NOT NULL` de las mismas 15 columnas dentro de una transacción. D2 no borra datos ni elimina puentes, por lo que una reversión restaura la nulabilidad sin reconstruir objetos. Cualquier despliegue productivo requerirá respaldo fresco, vista previa exacta y autorización explícita.

## 5. Puerta siguiente

D3 deberá inventariar consumidores y clasificar cada trigger y RPC heredada como compatibilidad temporal o integridad permanente. No se autoriza retirar objetos por nombre, sufijo o antigüedad sin demostrar que no tienen consumidores.
