# Reseñas públicas de cliente y moderación

**Fecha:** 24-25 de julio de 2026
**Estado:** desplegado en el único proyecto real; verificado de extremo a
extremo (SQL con rollback + navegador real del propietario contra el
tenant de prueba "Naguara de Uñas")

## 1. Objetivo

Sub-bloque 1 de 3 de "Reseñas y fotos de trabajo" (D-058): hoy
`reviews_service.dart` era 100% de solo lectura en toda la app. Sin esto,
`get_reviews_summary_v2` (D3.2) mostraba una cola de moderación
permanentemente vacía porque nada podía crear una reseña.

## 2. Decisiones del propietario

- **Acceso del cliente:** enlace público por `ticket_id`
  (`?resena=<ticket_id>`), sin sesión, mismo patrón que la reserva pública
  (D-053). Sin envío automático (mismo límite conocido desde D-050); el
  negocio comparte el enlace manualmente vía el botón nuevo "Copiar enlace
  de reseña" en `TicketsPage`.
- **Fotos de trabajo:** quedan fuera de este bloque. Las sube solo el
  negocio (estilista/admin), nunca el cliente — se abordará en un
  sub-bloque aparte porque requiere Supabase Storage, inexistente hoy en
  el proyecto.
- **`ai_status` de `work_photos`:** confirmado que sí es una función
  planeada a futuro (corrección/ajuste de fotos por IA para un catálogo
  uniforme), no un campo muerto como `movement_type='consumption'` en
  D-057. Se deja sin tocar; es su propio sub-bloque futuro.
- **Visibilidad pública desacoplada de la moderación** (agregado el
  2026-07-25 tras la prueba en navegador): aprobar/rechazar sigue fijando
  `visible_to_public` por defecto, pero una reseña ya **aprobada** puede
  ocultarse/mostrarse de forma independiente sin cambiar su veredicto de
  moderación (ej. una queja privada del cliente, o mención de un
  ex-empleado, sin que eso implique que la reseña era falsa o inválida).

## 3. Diseño

Tres RPC nuevas más una de visibilidad:

- `public_get_ticket_for_review(p_ticket_id)` (`anon`): valida que el
  ticket exista, que esté `finalizado`/`cerrado`, si ya tiene reseña
  activa, y devuelve sus `ticket_services` (servicio + estilista) como
  `jsonb` para que el cliente pueda atribuir opcionalmente la reseña.
- `public_create_review(p_ticket_id, p_rating, p_comment, p_stylist_id,
  p_service_id)` (`anon`): revalida todo en servidor (ticket
  finalizado/cerrado, sin reseña previa, rating 1-5, estilista/servicio
  pertenecen a ese ticket), inserta con `moderation_status='pending'`,
  `visible_to_public=false`. `tenant_id`/`branch_id`/`client_id` se
  derivan siempre del ticket, nunca del cliente.
- `moderate_review(p_branch_id, p_review_id, p_approve)`
  (`tenant_owner`/`admin`): aprueba (`visible_to_public=true`) o rechaza
  (`visible_to_public=false`).
- `set_review_visibility(p_branch_id, p_review_id, p_visible)`
  (`tenant_owner`/`admin`): solo actúa si `moderation_status='approved'`;
  cambia únicamente `visible_to_public`.
- Índice único parcial `reviews_ticket_active_unique` (`ticket_id`,
  `where active`) para que un ticket no reciba dos reseñas.

`get_reviews_summary_v2` (D3.2, ya en producción) sigue siendo la cola de
lectura del admin; no se tocó.

## 4. Prueba

SQL con `begin;...rollback;` contra el proyecto real, con datos sintéticos
autocontenidos (tenant/sede/cliente/servicio/estilista/ticket de prueba):
ticket revisable → reseña creada → ya no revisable/`already_reviewed`,
duplicado bloqueado, rating fuera de 1-5 bloqueado (probado aislado, sin
que el bloqueo de duplicado lo enmascarara), ticket no
finalizado/cerrado bloqueado, `moderate_review` sin sesión bloqueado.
`set_review_visibility`: bloqueado mientras la reseña está `pending`,
funciona sobre `approved` sin alterar el veredicto.

Después de desplegar, el propietario repitió el flujo completo en su
propio Chrome contra el tenant real de pruebas "Naguara de Uñas": dejó una
reseña de 5 estrellas como cliente anónimo (incógnito), la vio como
"Pendiente" en el panel, la aprobó (pasó a "Aprobada" sin recargar),
confirmó el bloqueo de duplicado reabriendo el mismo enlace, y probó el
interruptor de visibilidad (lo apagó: quedó "Aprobada" + "Privada";
"Públicas" bajó a 0 y "Aprobadas" se mantuvo en 1).

`flutter analyze`: sin hallazgos.

## 5. Flutter

- Nuevo: `public_review_ticket.dart`, `public_review_service.dart`,
  `public_review_page.dart` (pantalla sin sesión, estrellas + servicio
  opcional + comentario).
- `main.dart`: resuelve `?resena=<ticket_id>` antes de `AuthGate`, mismo
  patrón que `?reservar=<branch_id>`.
- `reviews_service.dart`: `moderateReview()`, `setReviewVisibility()`.
- `reviews_page.dart`: botones "Aprobar"/"Rechazar" en pendientes,
  interruptor "Visible al público" en aprobadas, botón "Actualizar
  reseñas" (la página no tenía refresco manual ni automático).
- `tickets_page.dart`: botón "Copiar enlace de reseña" en tickets
  `finalizado`/`cerrado`.

## 6. Fuera de alcance / pendiente

- Envío automático del enlace de reseña (mismo límite de D-050).
- Fotos de trabajo (sub-bloque 2: infraestructura de Storage; sub-bloque
  3: crear/aprobar fotos) — pendientes, es su propio bloque.
- Corrección de fotos por IA — bloque futuro, después de que exista el
  módulo de fotos.
