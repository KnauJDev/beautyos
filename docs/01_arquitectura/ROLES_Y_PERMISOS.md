# Roles, permisos y fronteras de acceso

**Estado:** diseño rector aprobado para implementación  
**Fecha:** 19 de julio de 2026  
**Objetivo:** impedir privilegios ambiguos y separar plataforma, empresa, sede y cliente final.

## 1. Principio rector

BeautyOS no tendrá una “clave maestra” compartida. Toda acción se atribuye a una cuenta individual, un contexto y un permiso verificable. La interfaz puede ocultar botones, pero la autorización real siempre se valida en Supabase.

Las cuatro fronteras son:

1. **Plataforma:** operación de la SaaS BeautyOS.
2. **Tenant:** empresa que contrata BeautyOS.
3. **Sede:** lugar donde ocurre la operación.
4. **Cliente final:** persona que reserva y consulta únicamente sus propios datos.

## 2. Roles

### `platform_operator`

Equipo propietario de BeautyOS. Administra tenants, planes, suscripciones, soporte y auditoría desde un panel de plataforma separado. No pertenece automáticamente a ningún tenant ni puede leer su operación cotidiana por RLS.

El soporte excepcional requiere autorización temporal, tenant explícito, motivo, vencimiento y registro de auditoría. Nunca suplanta silenciosamente a un empleado.

### `tenant_owner`

Propietario del negocio cliente. Tiene alcance sobre todas las sedes de su tenant, facturación SaaS, configuración, usuarios, reportes y exportación. No puede operar otros tenants ni modificar reglas internas de BeautyOS.

### `admin`

Administra únicamente las sedes asignadas: agenda, clientes, servicios, profesionales, pagos, caja y módulos contratados. No cambia la propiedad del tenant, la suscripción ni concede el rol `tenant_owner`.

### `assistant`

Rol operativo para recepción o caja. Puede crear clientes, reservar, reprogramar, confirmar, registrar pagos y consultar la operación de sus sedes. No gestiona permisos, planes, políticas financieras sensibles ni reportes consolidados salvo concesión futura explícita.

### `stylist`

Profesional del centro. Consulta solicitudes y compromisos propios, crea clientes y citas dentro de sus sedes, inicia/finaliza servicios asignados y añade evidencia autorizada. No ve finanzas globales, comisiones de otros, inventario valorizado ni usuarios administrativos.

### `customer`

Cliente final. Reserva, cancela o reprograma dentro de las políticas; consulta sus propias citas; recibe comunicaciones y puede publicar reseña/evidencia cuando corresponda. No es miembro del equipo y no obtiene acceso por `tenant_memberships`.

## 3. Matriz de permisos

Leyenda: **T** tenant completo, **S** sedes asignadas, **P** datos propios, **—** denegado.

| Recurso o acción | Plataforma | Owner | Admin | Assistant | Stylist | Customer |
|---|---:|---:|---:|---:|---:|---:|
| Crear/activar/suspender tenant | T | — | — | — | — | — |
| Ver/cambiar plan SaaS | T | T | — | — | — | — |
| Crear y configurar sedes | soporte auditado | T | S, sin borrar | — | — | — |
| Invitar y gestionar equipo | soporte auditado | T | S, sin owner | — | — | — |
| Catálogo de servicios | — | T | S | lectura | lectura habilitada | lectura pública |
| Precio/duración por sede | — | T | S | lectura | lectura | lectura pública |
| Profesionales y capacidades | — | T | S | lectura | P | lectura pública |
| Crear/editar clientes | — | T | S | S | S, operación | P |
| Documento de identidad | — | restringido | restringido | mínimo necesario | — | P |
| Crear reserva | — | T | S | S | S/P | P |
| Confirmar/reprogramar/cancelar | — | T | S | S | P según política | P según política |
| Iniciar/finalizar servicio | — | corrección | supervisión | — | P | — |
| Registrar/anular pagos | — | T | S | S | — | — |
| Cierre y reportes financieros | — | T | S | caja asignada | solo comisión propia | — |
| Inventario, compras y gastos | — | T | S | operación delegada | consumo autorizado | — |
| Fotos, reseñas y redes | — | T | S | moderación | P/autorizado | P/consentido |
| Exportación y eliminación legal | soporte auditado | T | solicitud | — | solicitud propia | solicitud propia |

## 4. Contexto y comprobación

Cada operación protegida debe resolver:

1. usuario autenticado;
2. membresía activa en el tenant;
3. rol admitido;
4. acceso a la sede solicitada;
5. tenant y sede operativos;
6. funcionalidad incluida por suscripción;
7. propiedad del registro cuando el alcance sea propio.

El `tenant_id`, `branch_id`, rol o plan enviados por Flutter nunca constituyen prueba de autorización. Se revalidan en la base de datos.

## 5. Identidad y membresías

- `user_profiles`: identidad global mínima de la cuenta.
- `tenant_memberships`: relación usuario–tenant, rol y vigencia.
- `branch_memberships`: sedes autorizadas para esa membresía.
- `clients`: perfil comercial del cliente dentro de un tenant.
- una cuenta autenticada puede pertenecer a varios tenants;
- un cliente puede existir en varios tenants sin compartir historial entre ellos;
- celular normalizado es el identificador comercial principal del cliente en el tenant; el documento es opcional y sensible.

No se usarán metadatos modificables por el usuario como fuente de autorización. Las membresías y políticas de base de datos son la fuente vigente.

## 6. Soporte de plataforma

El acceso excepcional de soporte tendrá:

- solicitud y tenant explícitos;
- motivo obligatorio;
- alcance de solo lectura por defecto;
- fecha de inicio y vencimiento;
- aprobación del owner cuando sea posible;
- registro de quién, cuándo y qué consultó o modificó;
- revocación inmediata.

Las tareas de mantenimiento automatizadas usarán identidades de servicio separadas y secretos solo del servidor.

## 7. Reglas no negociables

- RLS activa en toda tabla expuesta.
- Permisos SQL mínimos además de RLS.
- RPC de dominio para operaciones sensibles.
- Auditoría en accesos, roles, pagos, estados, suscripciones y correcciones.
- Un owner no puede quedar eliminado accidentalmente sin transferencia controlada.
- Desactivar una membresía bloquea nuevas acciones pero conserva autoría e historia.
- Cualquier cambio de rol o sede invalida el contexto operativo anterior.

## 8. Pruebas obligatorias

- Un usuario de Tenant A no lee ni modifica Tenant B.
- Un admin de Sede A no opera Sede B sin asignación.
- Un stylist solo ve sus servicios, incluso dentro de su sede.
- Un customer solo ve sus citas y reseñas.
- Un `platform_operator` no accede a datos operativos por ser plataforma.
- Un rol desactivado pierde acceso sin borrar historia.
- Un plan sin entitlement no ejecuta la RPC aunque manipule la interfaz.

