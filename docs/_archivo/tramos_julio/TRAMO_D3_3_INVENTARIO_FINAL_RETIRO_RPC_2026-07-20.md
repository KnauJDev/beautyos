# Tramo D3.3 — Inventario final previo al retiro de RPC heredadas

Fecha: 2026-07-20
Estado: aprobado y documentado localmente
Alcance: solo lectura y documentación; sin migración ni producción
Base Git: `ba8897a Implementar reemplazos por sede del Tramo D3.2`

## 1. Objetivo

Confirmar que las seis RPC heredadas sustituidas en D3.2 no mantienen
consumidores Flutter, dependencias SQL activas ni una obligación de
compatibilidad interna antes de preparar una revocación reversible.

RPC objetivo:

- `get_appointment_policy()`;
- `get_business_hours()`;
- `get_dashboard_metrics()`;
- `get_my_stylist_work_photos()`;
- `get_reviews_summary()`;
- `get_work_photos_summary()`.

## 2. Inventario de consumidores

| Fuente | Resultado |
| --- | --- |
| Flutter actual (`lib/`) | cero llamadas a las seis firmas heredadas; los seis servicios usan únicamente `_v2` con `p_branch_id` |
| Pruebas Flutter (`test/`) | cero llamadas heredadas |
| Migraciones administradas | cero referencias a las seis firmas heredadas |
| Funciones PostgreSQL activas | cero referencias textuales y cero dependencias `pg_depend` hacia las seis firmas |
| Vistas, políticas RLS y triggers | cero referencias o dependencias hacia las seis firmas |
| Prueba D3.2 `124_verify...` | única referencia activa deliberada: comprueba que las firmas heredadas aún existen; debe cambiar antes de revocar |
| SQL histórico no administrado | recetas originales `008`, `011`, `013`, `028`, `030`, `038`, `049` y prueba histórica `050`; no son migraciones y no representan un consumidor de ejecución actual |

La inspección se realizó sobre `beautyos-tramo-c-test`, que contiene el esquema
restaurado con D3.2 aplicado. No sustituye la comprobación equivalente sobre el
esquema vivo antes de una futura producción.

## 3. Exposición observada

En el entorno aislado, las seis firmas heredadas todavía conceden `EXECUTE` a
`anon`, `authenticated` y `service_role`. Es coherente con el hallazgo D3.0:
la compatibilidad heredada conserva exposición externa aunque Flutter ya no la
use. Esta exposición debe cerrarse antes de considerar el retiro completo.

Las seis variantes `_v2` ya tienen autorización de sede y privilegios mínimos
verificados en D3.2; no dependen de estas funciones heredadas.

## 4. Recomendación reversible

El siguiente micro-paso no debe eliminar funciones. Debe crear y ensayar una
migración local que, para las seis firmas objetivo:

1. ejecute `REVOKE ALL` para `PUBLIC`, `anon` y `authenticated`;
2. conserve temporalmente `EXECUTE` solo para `service_role`;
3. no toque las firmas `_v2`, los 15 triggers ni datos;
4. actualice `124_verify...` para comprobar la ausencia de acceso heredado en
   lugar de exigir que las firmas sigan presentes para clientes;
5. pruebe que `anon` y `authenticated` reciben denegación, mientras las seis
   RPC `_v2` continúan funcionando por rol y sede.

La revocación es reversible reotorgando los permisos, sin restaurar datos ni
fallbacks Flutter. La eliminación física de las seis funciones deberá esperar
una ventana estable posterior a publicación y evidencia de que no existen
clientes externos desactualizados.

## 5. Riesgo pendiente de autorización

El repositorio y el ensayo local no pueden demostrar que no haya aplicaciones
Flutter antiguas, llamadas directas a PostgREST u otra integración externa
contra producción. Por eso D3.3 no autoriza revocar ni eliminar en producción.
Antes de ese paso se requerirá inventario del esquema vivo, respaldo, una
ventana de compatibilidad comunicada y autorización explícita.

## 6. Cierre de D3.3

El inventario fue validado y quedó registrado en las fuentes canónicas. D3.3
se cierra como auditoría local independiente. La revocación reversible seguirá
como D3.4 y no podrá tocar producción sin una autorización nueva y explícita.
