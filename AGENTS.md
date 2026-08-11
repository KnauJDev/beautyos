# BeautyOS — Instrucciones permanentes del proyecto

## Propósito

BeautyOS es una SaaS multi-tenant y multi-sede para centros de estética, barberías, peluquerías y spas. Colombia es el primer mercado piloto.

## Fuente de verdad

- La documentación viva está en `docs/` y se versiona junto al código.
- Los acuerdos de arquitectura se registran en `docs/00_producto/`.
- Cada bloque significativo termina con un HANDOFF verificable.
- Las copias Word/PDF, capturas y bocetos viven fuera del repositorio, en el archivo personal del proyecto.

## Arquitectura y seguridad

- Nunca incluir secretos, `service_role`, contraseñas ni llaves privadas en Flutter, Git o documentos.
- Toda lectura y escritura sensible de Supabase se hace mediante RLS y/o RPC protegidas.
- Mantener aislamiento estricto por tenant y, cuando corresponda, por sede.
- El propietario de la plataforma SaaS no es el `owner` de un centro: son roles distintos.
- No alterar el historial financiero, pagos, comisiones o reservas sin trazabilidad.

## Producto

- Prioridad actual: convertir el núcleo interno existente en una SaaS multi-sede y preparar reservas públicas.
- Los módulos de alertas operativas están pausados hasta autorización explícita.
- Las reservas públicas deberán usar disponibilidad real y protección contra choques a nivel de base de datos.
- Las decisiones de UX deben reducir fricción sin debilitar seguridad ni trazabilidad.

## Forma de trabajo

**Las reglas están en `docs/00_producto/PLAN_MAESTRO.md`, apartado 8.**

Aquí no se copian: estaban en seis sitios y ya decían cosas distintas (D-131).
Lo que queda arriba en este archivo son **invariantes de arquitectura y
seguridad**, que es otra cosa y sí vive aquí.
