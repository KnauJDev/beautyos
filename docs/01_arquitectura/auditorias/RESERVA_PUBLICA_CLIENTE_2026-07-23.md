# Reserva pública de cliente

**Fecha:** 23 de julio de 2026
**Estado:** desplegado en el único proyecto real; verificado contra el esquema real; datos de prueba limpiados

## 1. Objetivo

Cuarto bloque de la ruta acordada tras invitar usuarios, editar catálogo y
editar horario/políticas: reserva pública de cliente (D-005). Hasta este
bloque no existía ninguna superficie accesible sin sesión — toda RPC de
agenda exigía `auth.uid()` vía `beautyos_resolve_branch_access`.

## 2. Hallazgo antes de escribir código: la protección anti-choque ya existía

AGENTS.md exige "protección contra choques a nivel de base de datos" para
las reservas. Antes de diseñar una nueva, se probó una migración propia
(exclusion constraint / trigger nuevo) contra el proyecto real dentro de
`begin; ... rollback;`. La prueba de reprogramar un ticket firme sobre uno
"solicitado" falló con un mensaje que no era el mío: reveló el trigger
`enforce_stylist_schedule_conflict` (Tramo C2b, `20260720135200`), ya
desplegado en producción sobre `tickets` y `ticket_services`, con
`pg_advisory_xact_lock` por sede. Se descartó la migración propia por
redundante — la reserva pública hereda esa protección automáticamente al
insertar en las mismas tablas con el mismo patrón que
`create_scheduled_ticket_with_service_v2`.

Se auditó además si existían choques reales de agenda ya en producción: el
único "choque" encontrado (ticket `06a7855e...`, clienta Yelimar Elina) era
el mismo ticket con dos servicios simultáneos del mismo estilista (Tinte
básico + Cepillado), no un error. Cero traslapes reales entre tickets
distintos.

## 3. Decisiones del propietario

- **Enlace público:** UUID de la sede (`branch_id`) directamente, sin slug
  global nuevo. `branches.slug` solo es único por tenant y toda sede nueva
  nace con slug `'principal'` (visto en `register_tenant`/
  `complete_tenant_setup`) — no sirve como identificador público sin romper
  datos existentes.
- **Confirmación:** toda reserva pública queda siempre en `solicitado`
  (pendiente de confirmación manual), sin importar `branch.booking_mode` ni
  `appointment_policies.requires_deposit`, hasta que exista pasarela de pago
  (Wompi).

## 4. RPC nuevas (`anon`, sin sesión)

- `public_get_branch_booking_info(p_branch_id)`: datos mínimos de una sede
  activa (nombre del negocio, sede, dirección, ciudad, WhatsApp, zona
  horaria, moneda). Falla si el tenant o la sede no están activos.
- `public_get_bookable_services(p_branch_id)`: catálogo servicio+estilista
  visible al cliente. Filtra `services.active`, `branch_services.active` y
  **ambos** `visible_to_customer` (ver hallazgo de bug abajo).
- `public_get_available_slots(p_branch_id, p_service_id, p_stylist_id, p_date)`:
  mismo cálculo que `get_available_appointment_slots_v2` (Tramo C2a) sin
  exigir sesión, con el mismo filtro `visible_to_customer`.
- `public_create_booking(...)`: valida sede/tenant activos, servicio y
  estilista bookeable, horario aún libre (pre-chequeo de aplicación), busca
  o crea el cliente por teléfono (identidad principal, D-006) y crea el
  ticket en `solicitado` + su `ticket_service` en `pendiente`. La protección
  real contra choques la da el trigger ya existente, no esta función.

Autorización: ninguna (rol `anon`). Se reemplaza
`beautyos_resolve_branch_access` (exige `auth.uid()`) por una resolución
manual de `tenant_id`/`branch_id` que exige `tenants.active` y
`branches.active`.

## 5. Bug propio encontrado y corregido antes de desplegar

El primer intento de filtrar el catálogo público usó
`coalesce(bs.visible_to_customer, s.visible_to_customer)`, copiado del
patrón visto en `editar_y_desactivar_catalogo` (`get_services_for_management`).
`branch_services.visible_to_customer` es `NOT NULL` (default `true`): el
`coalesce` nunca caía al valor del servicio, así que ocultar un servicio a
nivel de catálogo del tenant no lo ocultaba en la reserva pública. Se
corrigió a exigir `s.visible_to_customer AND bs.visible_to_customer`
explícito. Se detectó con una prueba real (servicio marcado oculto que
igual aparecía), no por inspección.

## 6. Prueba contra el esquema real

Dos rondas, ambas `begin; ... rollback;` contra el único proyecto real,
sin dejar datos:

**Antes de desplegar** (funciones definidas dentro de la misma transacción
desechable): 7 de 7 verificaciones aprobadas — info de sede activa/inexistente,
filtro `visible_to_customer` en catálogo y disponibilidad, reserva pública
creada en `solicitado`, **dos reservas públicas al mismo horario/estilista
bloqueadas por el trigger ya existente**, y una misma reserva por teléfono no
duplica cliente.

**Después de `supabase db push --linked`**, contra las funciones ya
desplegadas:

- Las tres RPC de lectura, contra una sede real y activa ("Bella Mujer",
  sede "Sede principal"): devuelven datos reales correctos.
- `public_create_booking`, contra un tenant de prueba desechable creado y
  borrado en esta misma sesión (nunca contra un negocio real, para no
  ensuciar datos de un cliente): crea un ticket real en `solicitado`.
  Limpieza verificada: `0` filas restantes del tenant de prueba.

## 7. Flutter

- Modelos: `PublicBranchInfo`, `PublicServiceOption`, `PublicBookingResult`
  (reutiliza `AvailableAppointmentSlot` ya existente).
- `PublicBookingService`: cliente `anon`, sin sesión, cuatro métodos que
  llaman a las RPC nuevas.
- `PublicBookingPage`: flujo servicio → fecha → horario → datos del cliente
  → confirmación, con pantalla de éxito ("solicitud enviada, pendiente de
  confirmación").
- `main.dart`: `Uri.base.queryParameters['reservar']` se resuelve **antes**
  de `AuthGate` — un cliente anónimo nunca pasa por login. Verificado con
  `print` temporal (retirado) que el enlace `?reservar=<uuid>` monta
  `PublicBookingPage` sin sesión y que, antes del `push`, el error visible
  era exactamente `PGRST202 function not found` (confirma que todo el
  camino Flutter → Supabase funcionaba; solo faltaba la migración).
- `ConfiguracionPage`: nueva tarjeta "Reserva pública" con el enlace
  completo y botón de copiar. No se generó imagen de QR (requeriría una
  dependencia nueva, `qr_flutter` u otra); el enlace copiado se puede
  convertir en QR con cualquier generador externo mientras tanto.
- `.claude/launch.json`: el puerto `8765` está en el rango excluido de
  Windows y no se podía usar para el servidor de vista previa; se cambió a
  `8090`.

`flutter analyze`: sin hallazgos (dos corridas, antes y después de agregar
la tarjeta de Configuración).

## 8. Fuera de alcance

- QR renderizado dentro de la app (solo el enlace copiable).
- Slug público bonito por sede (decisión explícita del propietario, ver
  sección 3).
- Confirmación automática o cobro de anticipo (depende de Wompi).
- Límite de frecuencia/anti-abuso más allá de la validación básica de
  datos; tampoco hay `unique` en `clients(tenant_id, phone)` (preexistente),
  así que dos reservas simultáneas de un cliente nuevo con el mismo
  teléfono podrían crear dos fichas de cliente (no afecta la agenda).

## 9. Siguiente bloque

Según la ruta acordada: inventario/compras/gastos editables, reseñas/fotos
de trabajo, o pasarela de pago (Wompi) cuando el propietario la tenga lista.
