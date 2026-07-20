# Tramo C — diseño de operación consciente de sede

**Fecha:** 20 de julio de 2026  
**Estado:** diseño cerrado; C1 implementado y aprobado en ensayo aislado; producción no autorizada  
**Antecedentes:** Tramos A y B aplicados y auditados en producción

## 1. Objetivo

Permitir que BeautyOS opere realmente más de una sede sin mezclar agenda, reservas, caja, reportes ni permisos. El Tramo C introduce contexto explícito de sede en Supabase y Flutter, manteniendo temporalmente intacta la aplicación heredada.

No pertenece a este tramo: hacer `branch_id NOT NULL`, retirar `user_profiles`, eliminar firmas antiguas, implementar suscripciones o reanudar alertas operativas.

## 2. Frontera de seguridad

El cliente envía `p_branch_id`; Supabase resuelve tenant, membresía, rol, vigencia y permiso. Nunca se acepta `tenant_id`, rol, `stylist_id` o plan enviado por Flutter como evidencia.

| Rol | Sede efectiva | Alcance inicial |
|---|---|---|
| `tenant_owner` | cualquier sede del tenant de su membresía | operación y consolidación autorizada |
| `admin` | sede asignada activa | operación, caja y reportes de esa sede |
| `assistant` | sede asignada activa | recepción/caja según RPC |
| `stylist` | sede asignada y vínculo profesional activo | agenda y registros propios |
| `platform_operator` | ninguna por defecto | panel de plataforma separado |
| `customer` | sede pública elegida | flujo público posterior, con contrato propio |

Las vigencias usan `starts_at <= now()` y `ends_at is null or ends_at > now()`. Las nuevas escrituras exigen sede activa. Las lecturas históricas de una sede inactiva se diseñarán con permiso explícito, nunca mediante una excepción silenciosa.

## 3. Componentes del Tramo C

### C1 — Contexto y autorización

1. Helper privado para resolver sede efectiva.
2. RPC `get_my_branch_context_v2()` para listar sedes accesibles.
3. Modelo Flutter de sede y controlador de selección.
4. Selección automática si solo existe una opción.
5. Selector obligatorio si existen varias.
6. Recarga de módulos al cambiar de contexto.

### C2 — Reservas, tickets y agenda

Versionar con `p_branch_id`:

- resumen de tickets;
- opciones de servicio/profesional de sede;
- creación de ticket y reserva completa;
- disponibilidad y choque de horario;
- agenda administrativa;
- agenda propia del estilista;
- agregar, reasignar o retirar servicios;
- reprogramación y cambios de estado;
- pagos y correcciones ligados al ticket de la sede.

Precio y duración se toman de `branch_services`; capacidad de `branch_stylist_services`; horario y política se filtran por sede. Cada hijo copia `branch_id` desde el ticket.

### C3 — Caja, reportes e inventario

Versionar con sede explícita:

- cierre diario y comisiones;
- resumen financiero y ventas;
- pagos por fecha contable real;
- compras, gastos y movimientos;
- stock desde `branch_products`.

Solo `tenant_owner` tendrá una ruta consolidada futura; no se representará la consolidación usando `NULL` como si fuera una sede. La consolidación será una RPC separada y autorizada.

### C4 — Compatibilidad y observación

- firmas heredadas permanecen disponibles;
- `_v2` produce el mismo resultado para Sede principal en datos equivalentes;
- los triggers del Tramo B siguen completando rutas antiguas;
- Flutter se migra por módulos, sin mezclar firmas dentro de una misma transacción;
- métricas y comprobaciones comparan conteos, totales y estados.

## 4. Orden de implementación

1. Crear C1 y probar aislamiento del helper.
2. Crear dos sedes A1/A2 en ensayo y un Tenant B ficticio.
3. Migrar C2 y probar reservas/agenda en A1/A2.
4. Migrar Flutter a contexto de sede para tickets y agendas.
5. Migrar C3 y probar caja/reportes/stock separados.
6. Ejecutar flujo integral por rol y sede.
7. Comparar ruta heredada y `_v2` en Sede principal.
8. Ejecutar asesores, análisis Flutter, pruebas y respaldo fresco.
9. Solicitar autorización separada antes de producción.

### Avance verificado de C1

- Migración: `supabase/migrations/20260720123813_tramo_c1_contexto_sede_efectiva.sql`.
- Prueba funcional y negativa: `supabase/sql/111_test_tramo_c1_branch_context.sql`.
- Auditoría de permisos: `supabase/sql/112_verify_tramo_c1_branch_context.sql`.
- Ensayo restaurado desde `BeautyOS_Backup_2026-07-20_06-57-21` en PostgreSQL desechable.
- Aprobados: Owner A con A1/A2, bloqueo de Tenant B, Admin A1 sin A2, Stylist A1 condicionado por `branch_memberships` y `branch_stylists`, pérdida inmediata por desactivación y llamada pública como rol `authenticated`.
- El helper privado conserva `SECURITY DEFINER`, `search_path=pg_catalog` y no concede ejecución a `anon` ni `authenticated`.
- `flutter analyze` y `flutter test` aprobaron. Flutter todavía no invoca C1 porque las pantallas siguen consumiendo RPC heredadas del proyecto productivo; se conectará por módulos junto con C2 para mantener compatibilidad.

## 5. Contratos técnicos

### 5.1 Resolver privado

El resolver recibirá sede solicitada, roles permitidos y si la sede debe estar operativa. Devolverá tenant, sede, membresía, rol, `stylist_id`, zona horaria y moneda. Fallará de manera uniforme si el contexto no es válido.

### 5.2 Listado de contexto

`get_my_branch_context_v2()` solo devolverá sedes que la cuenta puede seleccionar. Incluye identificadores, nombres de tenant/sede, rol, zona, moneda, principal y cantidad total de opciones. No expone membresías de otros usuarios.

### 5.3 Fechas

- Instantes persistidos: UTC con `timestamptz`.
- Día operativo: calculado con `branches.timezone`.
- Disponibilidad: horarios locales de la sede convertidos a instantes.
- Caja: fecha del movimiento en la zona de la sede, no fecha de la cita.

### 5.4 Errores

- Sin sesión: acceso no autenticado.
- Sin sede o sin permiso: contexto de sede no disponible.
- Sede inactiva: no admite nueva operación.
- Objeto fuera de sede: recurso no disponible para esta sede.

No se revelará si el identificador manipulado existe en otro tenant.

## 6. Matriz mínima de pruebas

| Caso | Resultado esperado |
|---|---|
| Owner A selecciona A1 y A2 | permitido |
| Admin A1 selecciona A2 | denegado |
| Admin A1 usa ID de Tenant B | denegado sin filtrar datos |
| Stylist A1 ve servicios ajenos | denegado |
| Membresía desactivada durante sesión | siguiente RPC denegada |
| Sede inactiva recibe reserva | denegada; historia conservada |
| Servicio de A2 en ticket A1 | denegado |
| Estilista no habilitado en A1 | denegado |
| Choque de un profesional en la misma franja | denegado |
| Citas de profesionales distintos | permitido |
| Caja A1 y A2 | totales separados |
| Owner consolidado | suma exacta, sin duplicar |
| Sede principal, ruta vieja vs `_v2` | conteos y totales equivalentes |

## 7. Condiciones de detención

Se detiene el tramo si aparece cualquiera de estos casos:

- una RPC acepta una sede solo por el parámetro recibido;
- un registro hijo puede declarar sede distinta a su padre;
- una prueba A1/A2 o Tenant A/B filtra información;
- cambian pagos, comisiones o stock históricos;
- Flutter heredado deja de funcionar antes de completar su reemplazo;
- la vista previa de producción incluye objetos no previstos.

## 8. Reversión

Los objetos `_v2` y el controlador Flutter son aditivos. Ante fallo se vuelve a la versión anterior de la aplicación y se deja de invocar `_v2`; las firmas heredadas y triggers del Tramo B continúan operativos. No se borrarán datos ni columnas en el mismo despliegue.

## 9. Puerta productiva

Producción solo podrá proponerse cuando:

- C1–C3 estén verificadas en ensayo;
- Tenant A con A1/A2 y Tenant B aprueben pruebas negativas;
- el flujo cliente → reserva → agenda → atención → pago → cierre coincida;
- `flutter analyze` y `flutter test` aprueben;
- los asesores no tengan errores bloqueantes;
- exista respaldo fresco verificado;
- el propietario autorice expresamente la migración prevista.

Las alertas operativas permanecen pausadas.
