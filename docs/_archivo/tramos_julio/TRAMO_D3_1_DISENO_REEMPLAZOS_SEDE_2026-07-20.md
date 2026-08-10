# Tramo D3.1 — Diseño de reemplazos por sede

Fecha: 2026-07-20
Estado: aprobado y documentado localmente
Alcance: diseño; sin migración, despliegue ni cambio en producción

## 1. Objetivo

Cerrar el contrato técnico de los seis RPC heredados que todavía leen datos
operativos sin una sede explícita. Cada reemplazo exigirá `p_branch_id uuid`,
validará la autorización efectiva y conservará la forma de respuesta que hoy
consume Flutter.

Este documento desarrolla el criterio aprobado en D3.0: dashboard, reseñas,
fotos y fotos del estilista usan por defecto la sede seleccionada. Una vista
consolidada futura deberá ser explícita, autorizada en backend y exclusiva del
rol `tenant_owner`.

## 2. Fuentes y restricciones

- `BEAUTYOS_EXPEDIENTE_TECNICO_Y_PLAN_MAESTRO.md`.
- `REGISTRO_DE_DECISIONES.md`, en especial D-020.
- `IMPACTO_Y_MIGRACION_MULTISEDE.md`.
- `TRAMO_D0_INVENTARIO_RETIRO_COMPATIBILIDAD_2026-07-20.md`.
- `TRAMO_D3_INVENTARIO_CLASIFICACION_COMPATIBILIDAD_2026-07-20.md`.
- Helper vigente `private.beautyos_resolve_branch_access(...)` del Tramo C1.
- Estado Git revisado sobre `main`, con base `e2d2a69` y árbol limpio al
  iniciar D3.1.

No se modifica Supabase productivo. D3.1 tampoco elimina ni revoca funciones:
solo fija el diseño que deberá implementarse y verificarse localmente en un
micro-paso posterior.

## 3. Contratos propuestos

Todos los RPC conservan las columnas, tipos, orden y límite funcional del
contrato heredado correspondiente.

| RPC nuevo | Roles admitidos | Alcance obligatorio | Resultado compatible |
| --- | --- | --- | --- |
| `get_appointment_policy_v2(p_branch_id uuid)` | `tenant_owner`, `admin` | política activa de la sede autorizada | `AppointmentPolicy` actual |
| `get_business_hours_v2(p_branch_id uuid)` | `tenant_owner`, `admin` | horarios activos de la sede autorizada, ordenados por día | lista `BusinessHour` actual |
| `get_dashboard_metrics_v2(p_branch_id uuid)` | `tenant_owner`, `admin` | métricas de la sede autorizada, salvo catálogo de clientes indicado en §4 | `DashboardMetrics` actual |
| `get_my_stylist_work_photos_v2(p_branch_id uuid)` | `stylist` | fotos del estilista autenticado dentro de su sede autorizada | lista `MyStylistWorkPhoto` actual, máximo 100 |
| `get_reviews_summary_v2(p_branch_id uuid)` | `tenant_owner`, `admin` | reseñas activas de la sede autorizada | lista `ReviewSummary` actual |
| `get_work_photos_summary_v2(p_branch_id uuid)` | `tenant_owner`, `admin` | fotos activas de la sede autorizada | lista `WorkPhotoSummary` actual |

Reglas comunes:

1. `p_branch_id` no acepta `null` ni sustitución por sede primaria.
2. La función obtiene `tenant_id`, rol y contexto de sede exclusivamente desde
   `private.beautyos_resolve_branch_access(...)`.
3. `tenant_owner` puede operar sus sedes activas; `admin` y `stylist` requieren
   membresía vigente en la sede. El estilista también requiere asignación
   operativa vigente.
4. Toda tabla operativa se filtra simultáneamente por `tenant_id` y
   `branch_id`; los cruces con ticket conservan ambos campos.
5. Una sede inexistente, inactiva, ajena o no autorizada produce error y nunca
   una respuesta vacía que oculte el fallo de autorización.

## 4. Semántica del dashboard

Se conserva el objeto de seis métricas para no romper Flutter:

- `active_services_count`: filas activas de `branch_services` para la sede,
  enlazadas a servicios activos del tenant.
- `clients_count`: clientes activos del tenant. Es la única métrica de catálogo
  global, porque el modelo vigente no define membresía cliente-sede. La interfaz
  deberá presentarla como total del negocio, no como total exclusivo de sede.
- `confirmed_tickets_count`: tickets confirmados de la sede.
- `today_tickets_count`: tickets de la sede dentro del día local calculado con
  la zona horaria devuelta por el contexto efectivo de sede.
- `active_stylists_count`: asignaciones activas y vigentes de
  `branch_stylists` para la sede, enlazadas a estilistas activos.
- `active_stylist_services_count`: capacidades activas de
  `branch_stylist_services` cuyos `branch_stylists` y `branch_services` también
  estén activos y vigentes en la misma sede.

No se introduce un modo consolidado en D3.1.

## 5. Seguridad y permisos

La implementación posterior deberá aplicar el mismo patrón endurecido del
Tramo C:

- `SECURITY DEFINER` solo para encapsular la lectura autorizada y saltar RLS de
  forma controlada.
- `SET search_path = pg_catalog` y referencias totalmente calificadas.
- validación de sesión, rol, tenant y sede antes de consultar datos.
- `REVOKE ALL` para `PUBLIC` y `anon`.
- `GRANT EXECUTE` explícito únicamente a `authenticated` y `service_role`.
- ningún RPC público auxiliar ni resolución mediante `user_profiles`.
- mensajes de error sin revelar si una sede ajena existe.

El permiso a `service_role` mantiene las verificaciones administrativas y no
convierte al cliente Flutter en poseedor de dicha credencial.

## 6. Adaptación prevista en Flutter

Las páginas `DashboardPage`, `MyStylistWorkPhotosPage`, `FotosTrabajosPage`,
`ResenasPage` y `ConfiguracionPage` recibirán un `branchId` no nulo desde el
selector ya existente. Sus servicios exigirán ese valor en el constructor y
enviarán `p_branch_id` al RPC `_v2` correspondiente.

`main.dart` les asignará una `ValueKey` dependiente de la sede para reconstruir
el estado al cambiar la selección. En Configuración solo horarios y política de
citas pasan a sede; ajustes del negocio y política de comisiones permanecen en
el ámbito del tenant.

No habrá fallback al RPC heredado, a sede primaria ni a una consulta sin
`branch_id`.

## 7. Verificación exigida para la implementación

La prueba local aislada deberá incluir dos tenants y, para el primero, dos
sedes con datos distintos:

1. propietario con acceso correcto a ambas sedes;
2. administrador permitido solo en su membresía de sede;
3. estilista permitido solo en su sede y solo sobre sus propias fotos;
4. rechazo de `anon`, sesión ausente, rol incorrecto, sede ajena, inactiva o
   inexistente, membresía vencida y estilista no asignado;
5. separación observable entre las dos sedes en horarios, política, tickets,
   métricas, reseñas y fotos;
6. conservación exacta de las formas que deserializan los modelos Flutter;
7. cambio de sede que reconstruye y recarga las cinco páginas afectadas;
8. análisis estático y pruebas Flutter sin errores;
9. inventario de privilegios que confirme cero ejecución para `anon` y
   `PUBLIC` sobre los seis reemplazos;
10. asesores locales de seguridad y rendimiento revisados antes de publicar la
    migración.

## 8. Secuencia reversible propuesta

1. Crear los seis RPC `_v2`, las pruebas SQL aisladas y la adaptación Flutter
   en un único micro-paso local verificable.
2. Mantener temporalmente los seis RPC heredados para que el cambio sea
   reversible y no mezclar creación con retiro.
3. Tras validar el consumo exclusivo de `_v2`, revocar o eliminar los contratos
   heredados en el micro-paso de retiro definido por D3.0.

La reversión inmediata del primer paso consiste en restaurar Flutter al commit
anterior y retirar únicamente los seis RPC `_v2`; no requiere reintroducir
fallbacks ni alterar datos.

## 9. Cierre de D3.1

El contrato fue validado y quedó registrado en las fuentes canónicas. D3.1 se
cierra como diseño local independiente. La implementación seguirá como D3.2 y
no podrá tocar producción sin una autorización nueva y explícita.
