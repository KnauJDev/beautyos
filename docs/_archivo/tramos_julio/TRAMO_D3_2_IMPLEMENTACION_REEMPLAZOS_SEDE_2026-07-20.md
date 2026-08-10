# Tramo D3.2 — Implementación de reemplazos por sede

Fecha: 2026-07-20
Estado: verificado y documentado localmente
Producción modificada: no
Base Git: `37c5788 Documentar reemplazos del Tramo D3.1`

## 1. Alcance ejecutado

Se implementaron de forma aditiva los seis contratos aprobados en D3.1:

- `get_appointment_policy_v2(uuid)`;
- `get_business_hours_v2(uuid)`;
- `get_dashboard_metrics_v2(uuid)`;
- `get_my_stylist_work_photos_v2(uuid)`;
- `get_reviews_summary_v2(uuid)`;
- `get_work_photos_summary_v2(uuid)`.

La migración está en
`supabase/migrations/20260720183122_tramo_d3_2_reemplazos_lectura_por_sede.sql`.
Las seis firmas heredadas permanecen intactas para conservar reversibilidad.

## 2. Seguridad aplicada

Cada RPC exige `p_branch_id`, usa
`private.beautyos_resolve_branch_access(...)`, declara `SECURITY DEFINER`, fija
`search_path = pg_catalog` y califica las relaciones por esquema. `PUBLIC`,
`anon` y el privilegio automático de `authenticated` se revocan antes de
conceder `EXECUTE` explícito solo a `authenticated` y `service_role`.

No se usa `user_profiles` para autorizar. Las respuestas ante sede inexistente,
inactiva, ajena o sin membresía reutilizan el error genérico del resolver para
no revelar su existencia.

## 3. Flutter

Los seis servicios Flutter exigen `branchId` y llaman únicamente el RPC `_v2`
con `p_branch_id`. `DashboardPage`, `MyStylistWorkPhotosPage`,
`FotosTrabajosPage`, `ResenasPage` y `ConfiguracionPage` reciben la sede desde
`main.dart` y usan una `ValueKey` dependiente de ella.

En Configuración solo horarios y política de agenda pasan a alcance de sede;
datos del negocio y política de comisiones continúan en el tenant. El dashboard
rotula clientes como catálogo del negocio y mantiene las demás métricas en la
sede seleccionada.

## 4. Evidencia SQL local

La migración se aplicó dos veces sin error sobre el contenedor aislado
`beautyos-tramo-c-test`.

`supabase/sql/123_test_tramo_d3_2_reemplazos_lectura_por_sede.sql` pasó dentro
de una transacción con `ROLLBACK` y verificó:

- Tenant A con A1 y A2, más Tenant B ajeno;
- métricas, horarios, política, reseñas y fotos diferenciadas por sede;
- owner autorizado en A1/A2;
- admin limitado a su membresía de sede;
- stylist limitado a su sede y a sus propias fotos;
- rechazo de `branch_id` nulo, sede inexistente, ajena o inactiva;
- rechazo de membresía vencida, estilista no asignado, rol incorrecto, sesión
  ausente y rol `anon`.

`supabase/sql/124_verify_tramo_d3_2_reemplazos_lectura_por_sede.sql` confirmó
las seis firmas, columnas y tipos compatibles, `SECURITY DEFINER`,
`search_path = pg_catalog`, dependencia del resolver, ausencia de
`user_profiles`, `authenticated = EXECUTE`, `anon = false`, `PUBLIC = false` y
permanencia de las seis firmas heredadas.

## 5. Regresión e invariantes

- `supabase/sql/121_verify_tramo_d2_branch_id_not_null.sql`: 15 tablas con
  `branch_id NOT NULL`.
- `supabase/sql/120_verify_tramo_c4_criterios_salida.sql`: aprobado; 36 RPC
  `_v2`, 12 tickets, pagos activos por 250.000, comisiones activas por 100.000 y
  stock de sede 2.530.
- `flutter test`: 5 pruebas aprobadas, incluidas las dos nuevas de contratos y
  reconstrucción por sede.
- `flutter analyze`: sin hallazgos.
- `git diff --check`: sin errores.

Los asesores locales de Supabase no reportaron errores. Persisten únicamente
dos advertencias de rendimiento ya existentes en políticas RLS de
`user_profiles` (`auth_rls_initplan`); D3.2 no modifica esa tabla ni sus
políticas.

## 6. Reversión

Antes de producción, D3.2 se revierte retirando los seis RPC `_v2` nuevos y
restaurando Flutter al commit anterior. No requiere modificar datos ni
reintroducir fallbacks: las seis firmas heredadas aún existen.

## 7. Resultado

D3.2 queda implementado, verificado y documentado localmente. No se ejecutó
migración, despliegue ni escritura sobre Supabase productivo, ni se hizo push.
El retiro de las seis firmas heredadas requiere una microcompuerta posterior y
una autorización nueva y explícita.
