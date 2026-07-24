# Auditoría de roles y brechas pendientes

**Fecha:** 24 de julio de 2026
**Estado:** análisis completado y verificado contra el código real; ninguna brecha aquí listada está implementada todavía

## 1. Objetivo

Con la ruta de inventario/compras/gastos + consumo interno cerrada
(D-054 a D-057), el propietario planteó su conceptualización completa de
los 5 roles del producto y preguntó por qué el dueño/admin de un negocio
no puede crear directamente el login de un estilista. Este documento
consolida esa conversación y la contrasta contra el código real,
verificado (no de memoria), para que sirva de punto de partida a
cualquier chat nuevo.

## 2. Los 5 roles según el propietario

1. **Dueño de la plataforma (el propietario de BeautyOS)** — autorización completa y absoluta.
2. **Dueño de negocio (tenant_owner)** — crea sedes adicionales a la principal; control total en todas sus sedes.
3. **Administrador de sede (admin)** — crea/edita/activa-desactiva servicios, estilistas, asignación de servicios a estilistas, clientes, tickets, agendas, compras, ventas (pagos), gastos; ve panel financiero de su sede; autoriza publicación de reseñas y fotos de trabajos.
4. **Estilista** — ve su agenda, inicia/finaliza sus servicios (para que admin cobre), ve sus reseñas y fotos, bloquea su agenda cuando no puede atender.
5. **Cliente final** — reserva citas, ve disponibilidad, deja reseñas y fotos, ve reseñas/puntuación de estilistas y del negocio.

## 3. Aclaración central: dos cosas distintas que se estaban mezclando

**Crear la ficha del estilista (catálogo)** — ya funciona hoy, sin
invitación (`create_stylist`, D-048). Un negocio puede tener estilistas
en su catálogo, asignarles servicios y agendarles citas sin que esa
persona tenga jamás una cuenta propia.

**Crear el LOGIN de esa persona** (para que ella entre a la app y use
"Mi agenda") — esto sí requiere invitación + autoregistro (D-050),
porque una contraseña la debe poner la propia persona; el proyecto
decidió explícitamente no manejar la Admin API de Supabase desde
Flutter (evita exponer `service_role`, un riesgo de seguridad real). La
invitación es la prueba de que el dueño autorizó a ese correo a entrar a
su negocio en vez de crear uno propio al registrarse
(`register_tenant` siempre crea un negocio nuevo si no hay invitación
pendiente con ese correo).

La brecha real no es el mecanismo de invitación en sí — es que **el
aviso no le llega a nadie por correo automáticamente** (ya identificado
en D-050).

## 4. Contraste verificado, rol por rol

| Rol | Pedido del propietario | Estado real (verificado en código) |
|---|---|---|
| 1. Dueño plataforma | Autorización completa y absoluta | `platform_operators` existe (D-046), pero **por diseño explícito** (D-009) el dueño de la plataforma NO tiene acceso implícito a los datos privados de cada tenant (clientes, tickets, finanzas) — solo control comercial (plan, suspender, prueba gratis). Pendiente de confirmar con el propietario si esto debe seguir así o si su intención real incluye ver/tocar datos de cualquier negocio. |
| 2. Dueño de negocio | Crear sedes adicionales; control total en todas | Control total en todas sus sedes: **sí existe**. Crear una sede adicional a la principal: **no existe ninguna función** (`create_branch` no existe en `supabase/migrations/` ni en `lib/`). Solo existe la sede principal creada por `register_tenant`. |
| 3. Admin de sede | Servicios, estilistas, clientes, tickets, agenda, compras, gastos, panel financiero, autorizar reseñas/fotos | Casi todo coincide. Matiz ya decidido por el propietario en D-055: en compras, admin crea pero solo `tenant_owner` edita/anula. **Autorizar publicación de reseñas y fotos: no existe nada** — ni reseñas ni fotos tienen forma de crearse en ningún punto de la app (ver sección 5). |
| 4. Estilista | Ver agenda, iniciar/finalizar servicio, ver sus reseñas/fotos, bloquear agenda | Ver agenda: ✓. Iniciar/finalizar servicio: ✓ ya funciona (`change_ticket_service_status_v2`, `MyStylistAgendaService.changeTicketServiceStatus`). Bloquear agenda cuando no puede atender: **no existe** (sin tabla ni RPC de ausencias/bloqueos de estilista). Ver sus reseñas/fotos: la lectura existe pero, al no poder crearse nunca, hoy siempre está vacía. |
| 5. Cliente final | Reservar, ver disponibilidad, dejar reseñas/fotos, ver puntuación | Reservar y ver disponibilidad: ✓ (D-053). Dejar reseñas/fotos: **no existe**. Ver reseñas/puntuación: la lectura existe pero sobre datos que nunca se pueden crear. |

## 5. Brechas confirmadas (ninguna implementada)

Verificado con `grep` sobre `supabase/migrations/` y `lib/`:

- **`create_branch` (o equivalente) no existe** — un `tenant_owner` no puede crear una segunda sede.
- **Reseñas y fotos de trabajo son 100% de solo lectura** en toda la app: `reviews_service.dart`, `work_photos_service.dart` y `my_stylist_work_photos_service.dart` solo tienen métodos `get*`. No hay `create_review`, `submit_review`, `create_work_photo`, `upload_work_photo`, ni ninguna función de aprobar/publicar. Este es el punto 6 del plan original ("Reseñas/Fotos de trabajo") — es más grande de lo que se había descrito antes ("cosmético"): es un módulo completo sin construir, no un ajuste menor.
- **No existe bloqueo/ausencia de agenda para estilistas** — sin tabla ni RPC (`stylist_time_off`, `stylist_block` o similar no existen).
- **El correo de invitación de equipo no se envía automáticamente** (gap ya documentado en D-050, sigue pendiente).
- **El alcance del rol `platform_owner`** frente a los datos privados de cada tenant (D-009) necesita reconfirmación explícita del propietario — no es una brecha técnica, es una decisión de producto/privacidad que puede o no seguir vigente.

## 6. Pendiente del plan original (recordatorio)

Del plan original de seis puntos:

1. Invitar usuarios — ✓ D-050 (con la brecha del correo automático pendiente).
2. Editar/desactivar servicios y estilistas — ✓ D-051.
3. Configuración editable — ✓ D-052.
4. Reserva pública de cliente — ✓ D-053.
5. Inventario/Compras/Gastos editables — ✓ D-054 a D-057.
6. Reseñas/Fotos de trabajo — **pendiente**, y resultó ser un módulo completo, no un ajuste cosmético.
7. Pasarela de pago (Wompi) — **pendiente**, bloqueada hasta que el propietario tenga la cuenta comercial lista (D-046).

## 7. Candidatos para el siguiente chat (cada uno es su propio bloque)

En orden sugerido por impacto/riesgo, sin decidir todavía cuál sigue:

1. **Envío automático del correo de invitación** — cierra una brecha ya identificada, riesgo bajo, no toca datos financieros.
2. **Reseñas y fotos de trabajo de punta a punta** (crear + moderar/publicar) — el gap más grande, toca a los roles 3, 4 y 5 a la vez.
3. **Crear sedes adicionales** para `tenant_owner` — habilita el modelo multi-sede real que la arquitectura ya soporta mas nunca se expuso.
4. **Bloquear agenda del estilista** (ausencias/no disponibilidad).
5. **Reconfirmar el alcance de `platform_owner`** frente a D-009 — es una decisión de producto/privacidad, no una migración; conviene resolverla antes de tocar los puntos 2-4 si cambia algo de fondo.
6. **Pasarela de pago (Wompi)** — bloqueada hasta que el propietario tenga la cuenta lista.

Cada uno debe empezar, igual que los bloques anteriores, verificando el
esquema real antes de proponer código (`AGENTS.md`, sección "Nunca
asumas").
