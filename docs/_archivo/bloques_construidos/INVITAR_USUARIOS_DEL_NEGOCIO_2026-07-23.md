# Invitar usuarios del negocio

**Fecha:** 23 de julio de 2026
**Estado:** desplegado en el único proyecto real; verificado contra el esquema real

## 1. Objetivo

Hueco confirmado en la auditoría del mismo día: `UsuariosPage` solo
administraba cuentas que ya existían (`update_tenant_user_access`). No
había forma de que un propietario agregara una cuenta nueva para un
estilista, administrador o asistente — todas las cuentas hasta ahora se
sembraban a mano por SQL.

## 2. Diseño (sin Edge Function, sin Admin API)

Crear un usuario nuevo en Supabase Auth desde el cliente requiere
`service_role`, que nunca debe tocarse desde Flutter. En vez de construir
una Edge Function nueva (mayor superficie, secretos, despliegue aparte),
se reutiliza el flujo self-serve ya construido:

1. El propietario/admin crea una invitación (`create_team_invitation`):
   correo, rol (`admin`/`assistant`/`stylist`) y, si es estilista, a cuál
   fila del catálogo (`stylists`, ya creada con "Agregar estilista") se
   vincula. La invitación decide quién puede iniciar sesión; el catálogo
   operativo (quién trabaja aquí) es una cosa aparte.
2. El invitado se registra con `RegisterPage` normal (correo/contraseña,
   confirmación si aplica) — el mismo flujo de cualquier negocio nuevo.
3. Al tener sesión y no pertenecer a ningún negocio, `BeautyOSHome`
   pregunta primero `get_my_pending_invitation()`; si hay una invitación
   pendiente para su correo, ve `AcceptInvitationPage` (pide su nombre y
   se une) en vez de `CompleteTenantSetupPage` (crear negocio propio).
4. `accept_team_invitation(p_full_name)` crea `user_profiles`,
   `tenant_memberships` y `branch_memberships` coherentes en una sola
   transacción.

No hay envío automático de correo (mismo límite de Supabase Auth ya
conocido): el propietario le avisa al invitado por su cuenta que se
registre con ese correo exacto. La UI lo deja explícito tras crear la
invitación.

## 3. RPC nuevas

`create_team_invitation`, `list_team_invitations`, `cancel_team_invitation`
(autorización: `beautyos_resolve_branch_access`, mismo patrón de
`create_service`/`create_stylist`) y `get_my_pending_invitation`,
`accept_team_invitation` (para el invitado, antes de tener membresía).

## 4. Prueba contra el esquema real

`supabase/sql/150_test_invitar_usuarios.sql`, con `begin; ... rollback;`
contra el tenant real "Cortes y Barbas" (usando la cuenta real
`juankdev2026@gmail.com` como invitado de prueba — sin membresía en ese
momento, sin efecto permanente): **7 de 7 verificaciones aprobadas**:

1. Invitar un estilista vinculado a un estilista real del catálogo.
2. Invitar rol `stylist` sin `stylist_id` falla.
3. Invitación duplicada pendiente falla.
4. `list_team_invitations` la muestra.
5. El invitado ve su invitación con `get_my_pending_invitation`.
6. Aceptar deja `user_profiles`, `tenant_memberships` y
   `branch_memberships` consistentes (rol, `stylist_id` y sede correctos).
7. Un segundo intento de aceptar (ya con membresía) falla.

Desplegado al único proyecto real con `supabase db push --linked`.

## 5. Flutter

- `TeamInvitationsService`, modelos `TeamInvitation`/`PendingInvitation`.
- `UsuariosPage`: botón "Invitar usuario" (correo, rol, selector de
  estilista del catálogo si aplica) y lista de invitaciones pendientes
  con cancelar.
- `AcceptInvitationPage`: pantalla nueva para quien tiene una invitación
  pendiente al iniciar sesión por primera vez.
- `main.dart`: `BeautyOSHome` ahora consulta `get_my_pending_invitation()`
  antes de decidir entre `AcceptInvitationPage` y `CompleteTenantSetupPage`
  cuando no hay perfil; `UsuariosPage` recibe `branchId` (antes no lo
  recibía).

`flutter analyze`: sin hallazgos. `flutter test`: 5 pruebas aprobadas.

## 6. Fuera de alcance (bloques aparte)

- Envío automático de correo de invitación (requiere proveedor SMTP
  propio, ya identificado como pendiente para producción).
- Editar o reenviar una invitación existente (hoy solo crear/cancelar).
- Que un admin (no solo el propietario) invite equipo — el backend ya lo
  permite vía `beautyos_resolve_branch_access`, pero `UsuariosPage` sigue
  restringida a `allowedRoles: {'owner'}` en Flutter; se dejó así a
  propósito para no ampliar el alcance de este bloque sin decisión
  explícita.

## 7. Siguiente bloque

Editar/desactivar servicios y estilistas existentes, o configuración
editable (horario, políticas) — ambos ya identificados en la ruta
acordada.
