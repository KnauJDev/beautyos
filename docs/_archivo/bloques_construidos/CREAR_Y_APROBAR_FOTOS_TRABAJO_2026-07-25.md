# Crear y aprobar fotos de trabajo

**Fecha:** 25 de julio de 2026
**Estado:** desplegado en el único proyecto real; RPC verificadas con
`begin;...rollback;` contra datos reales y sintéticos

## 1. Objetivo

Sub-bloque 3 de 3 de "Reseñas y fotos de trabajo" (D-058/D-059/D-060) —
el último. Con esto se cierra por completo el punto 6 del plan original:
`work_photos_service.dart` y `my_stylist_work_photos_service.dart` eran
100% de solo lectura.

## 2. Decisiones del propietario

- Botón "Agregar foto" en **dos lugares**: `TicketsPage` (admin/owner,
  puede atribuir opcionalmente a un estilista del ticket) y "Mi agenda"
  (estilista, sobre sus propios servicios `en_proceso`/`finalizado`,
  siempre se autoatribuye).
- En `WorkPhotosPage`: **dos interruptores independientes** por foto
  ("Visible al cliente" y "Aprobada para portafolio"), no un solo
  botón de aprobar -- las columnas ya existían separadas en el esquema
  real y son audiencias distintas.

## 3. Diseño

`work_photos` no tiene columna `service_id` (solo `ticket_id` y
`stylist_id`), así que la atribución se resuelve según quién sube:

- `create_work_photo(p_branch_id, p_ticket_id, p_photo_url, p_photo_type,
  p_caption, p_stylist_id)`: para `tenant_owner`/`admin`/`stylist` con
  acceso a la sede. Si el que sube es `stylist`, **siempre se
  autoatribuye** (se ignora cualquier `p_stylist_id` que intente pasar
  por otra persona -- protección probada explícitamente). Si es
  `tenant_owner`/`admin`, puede atribuir opcionalmente a un estilista que
  sí tenga un `ticket_services` para ese ticket, o dejarla sin atribuir.
  Bloquea tickets `cancelado`/`no_asistio` y tipos de foto fuera de
  `before/after/final/portfolio`.
- `set_work_photo_customer_visibility` / `set_work_photo_portfolio_approval`
  (`tenant_owner`/`admin`): cada uno cambia solo su columna.

Flutter: `AddWorkPhotoDialog` (widget compartido en
`widgets/add_work_photo_dialog.dart`) sube el archivo con
`WorkPhotosUploadService` (sub-bloque 2) y luego llama a
`create_work_photo`. Se usa desde `TicketsPage` (con lista de
estilistas del ticket) y desde `MyStylistAgendaPage` (sin selector,
autoatribución).

Se simplificó la convención de ruta de Storage del sub-bloque 2, de
`{tenant_id}/{branch_id}/archivo` a solo `{branch_id}/archivo`
(migración `20260725170000`), porque `TicketsPage` y "Mi agenda" solo
reciben `branchId` hoy -- `tenant_id` se resuelve del lado servidor,
igual que en toda RPC del proyecto. Nadie había subido ningún archivo
real con la convención anterior, así que no hubo datos que migrar.

## 4. Prueba

`begin;...rollback;` contra el proyecto real, con datos sintéticos, 9
escenarios: sin sesión bloqueado, `tenant_owner` ajeno a otro tenant
bloqueado, `tenant_owner` real puede crear sin atribuir y atribuyendo a
un estilista real del ticket, estilista que no pertenece al ticket
bloqueado, tipo de foto inválido bloqueado, ticket cancelado bloqueado,
las dos aprobaciones aplicadas correctamente, y la protección clave: un
`stylist` que intenta pasar el `stylist_id` de otra persona por
parámetro queda igual autoatribuido a sí mismo.

No se probó la subida real de un archivo de extremo a extremo en este
chat (requiere sesión autenticada con contraseña); queda para que el
propietario lo pruebe en su navegador, igual que se hizo con reseñas.

`flutter analyze`: sin hallazgos.

## 5. Flutter

- `widgets/add_work_photo_dialog.dart` (nuevo): diálogo compartido.
- `services/work_photos_service.dart`: `createWorkPhoto()`,
  `setCustomerVisibility()`, `setPortfolioApproval()`.
- `pages/work_photos_page.dart`: interruptores de visibilidad/portafolio
  por foto, botón "Actualizar fotos" (no tenía refresco).
- `pages/tickets_page.dart`: botón "Agregar foto" (bloqueado en tickets
  `cancelado`/`no_asistio`).
- `pages/my_stylist_agenda_page.dart`: botón "Agregar foto" junto a
  Iniciar/Finalizar, visible en servicios `en_proceso`/`finalizado`.

## 6. Fuera de alcance / pendiente

- Corrección de fotos por IA (`ai_status`) -- bloque futuro aparte,
  confirmado en D-059 que sí es una función planeada.
- Verificación interactiva real de la subida de archivo (pendiente de
  que el propietario la pruebe en su navegador).

## 7. Cierre del punto 6 del plan original

Con este sub-bloque se completa "Reseñas y fotos de trabajo de punta a
punta" (D-058, punto 6): reseñas públicas + moderación (D-059),
infraestructura de Storage (D-060), y crear/aprobar fotos (este
documento). Pendiente de decisión del propietario: siguiente punto de
la lista de candidatos (envío automático de correo de invitación, crear
sedes adicionales, bloquear agenda de estilista, alcance de
`platform_owner`, o pasarela de pago Wompi).
