# Tramo D3.5.3 — autorización de RPC heredadas hacia tenant_memberships

**Fecha:** 22 de julio de 2026
**Estado:** completado localmente; sin conexión remota
**Producción modificada:** no
**Conexiones remotas realizadas:** ninguna
**Base Git:** `3523041 Reconciliar privilegios RPC heredadas del Tramo D`

## 1. Objetivo

Cerrar NC-D-04 (`TRAMO_D5_PRE_2_AUDITORIA_NO_CONFORMIDADES_2026-07-20.md`): la
autorización heredada basada en `user_profiles.role` seguía activa en paralelo
al modelo de membresías (ADR-002, D-010), sin ventana de vigencia y sin
sincronización con `tenant_memberships`.

## 2. Alcance de la migración

`supabase/migrations/20260722175530_tramo_d3_5_3_autorizacion_memberships.sql`
reescribe seis funciones para que autoricen contra `tenant_memberships`
(`active`, `starts_at`, `ends_at`), igual que `beautyos_resolve_branch_access`:

1. `get_my_tenant_id()`, `get_my_role()`, `is_owner_or_admin()`: los tres
   helpers de autorización pasan de `user_profiles` a `tenant_memberships`.
2. `get_tenant_users()` y `update_tenant_user_access()`: la verificación
   "solo el propietario" pasa a apoyarse en los helpers reescritos.
   `update_tenant_user_access()` ahora también sincroniza
   `tenant_memberships` en cada cambio: crea o reactiva la membresía cuando el
   nuevo rol es `admin`/`assistant`/`stylist`, y la desactiva (nunca la borra)
   cuando el nuevo rol es `client`. Antes de esta migración, esa RPC escribía
   solo en `user_profiles`, dejando `tenant_memberships` desactualizado frente
   a cualquier cambio de acceso hecho desde esta pantalla.
3. `create_client()`: su verificación inline de `user_profiles.role in
   ('owner','admin','assistant')` pasa a la misma condición sobre
   `tenant_memberships` (`tenant_owner`, `admin`, `assistant`).

Los seis privilegios (`authenticated, service_role`; `anon`/`public`
revocados) se reafirman explícitamente sin cambiar la superficie existente.

## 3. Fuera de alcance (decisión explícita)

- `user_profiles` sigue siendo identidad global (D-010): nombre, rol legado
  para visualización y el join con `auth.users` en `get_tenant_users` y
  `get_my_profile` no se tocan.
- Las 24 rutas operativas heredadas sin consumidor (`create_ticket`,
  `add_ticket_service`, `get_available_appointment_slots`, etc.) siguen
  citando `user_profiles` en su cuerpo, pero ya perdieron `EXECUTE` para
  `authenticated`/`anon` desde D3.5.2 y están propuestas para retiro
  completo (Tramo D3.0, §3.1). Reescribirlas ahora duplicaría trabajo que su
  propio retiro hará innecesario.

## 4. Hallazgo y corrección durante la prueba

`update_tenant_user_access` declara `returns table (..., user_id uuid, ...)`.
En PL/pgSQL, las columnas de `returns table` se vuelven variables implícitas
del cuerpo de la función. El `on conflict (tenant_id, user_id)` del nuevo
`insert` sobre `tenant_memberships` usa `user_id` sin calificar, y Postgres
lo rechazó como ambiguo (`ERROR: column reference "user_id" is ambiguous`)
porque coincidía con esa variable implícita. Se corrigió agregando la
directiva `#variable_conflict use_column` al inicio del cuerpo de la función,
que le indica a PL/pgSQL preferir siempre la columna de la tabla en esa
función. No cambia ningún comportamiento externo: solo desambigua la
resolución interna.

Este hallazgo se detectó únicamente porque la migración se ejecutó de
verdad contra Postgres real (ver sección 5), no por revisión visual.

## 5. Metodología de prueba y su límite conocido

El repositorio no contiene una migración basal para `tenants`,
`user_profiles`, `clients`, `stylists` ni `user_profile_access_history`:
nacieron antes de versionar migraciones (Tramo 0, §6.1). Por eso
`supabase start` / `db reset` no puede reconstruir el esquema completo en un
Postgres local vacío — se comprobó en este mismo bloque: falla en la primera
migración (`20260710192241`) con `relation "public.tickets" does not exist`.

Para probar la lógica nueva contra Postgres real (no solo revisión visual),
se construyó un Postgres desechable a partir de la misma imagen que usa
Supabase (`public.ecr.aws/supabase/postgres:17.6.1.127`, que ya trae el
esquema `auth` y `pgcrypto`), y se agregaron dos scripts nuevos en
`supabase/sql/`:

- `132_test_tramo_d3_5_3_autorizacion_memberships.sql`: crea copias mínimas
  y fieles (mismas columnas, documentadas en `supabase/sql/033, 035-037, 056,
  085` y en la migración Tramo A) de las tablas que las seis funciones tocan.
  No reconstruye el esquema completo ni sustituye una prueba contra el
  esquema vivo.
- `133_verify_tramo_d3_5_3_autorizacion_memberships.sql`: 12 verificaciones
  transaccionales (`raise exception` si fallan) que cubren: helpers con
  membresía vigente, membresía con `ends_at` vencido (endurecimiento nuevo:
  `user_profiles` nunca tuvo ventana de vigencia), `create_client` para
  owner vigente y para un usuario sin membresía, aislamiento
  propietario-vs-admin en `get_tenant_users`/`update_tenant_user_access`,
  creación de una membresía nueva al promover, desactivación (no borrado) al
  degradar a `client`, y auditoría en `user_profile_access_history`.

**Resultado: 12 de 12 verificaciones aprobadas.**

El contenedor sintético se destruyó al terminar; no se tocó ningún proyecto
Supabase remoto. También se retiró un contenedor Docker local ya detenido
(`beautyos-tramo-c-test`, de un ensayo anterior) para liberar el puerto;
no contenía datos vivos ni estaba en uso.

## 6. Otras pruebas

- `flutter analyze`: sin hallazgos.
- `flutter test`: 5 pruebas aprobadas (mismo conteo que el cierre de
  D5-pre.2; sin regresión, no se tocó código Dart).

## 7. Estado de NC-D-04 y del Tramo D

NC-D-04 queda cerrada localmente. De las no conformidades bloqueantes de
`TRAMO_D5_PRE_2_AUDITORIA_NO_CONFORMIDADES_2026-07-20.md`, quedan abiertas:

- **NC-D-01** (crítica): identidad productiva contradictoria de
  `eogppgbdnwxdtcbctaol`. El propietario decidió verificarla directamente en
  el panel de Supabase antes de continuar; D4/D5 permanecen en NO-GO hasta
  esa confirmación.
- **NC-D-06**: condiciones operativas de despliegue (proyecto inequívoco,
  respaldo fresco, ventana, evidencia Flutter D1) — dependen de resolver
  NC-D-01 primero.

Esta migración **no se aplicó** a `beautyos-dev` ni a ningún entorno
conectable; queda lista y probada para cuando se reabra D4/D5 sobre el
alcance completo, tal como exige el dictamen de D5-pre.2.

## 8. Siguiente paso recomendado

1. El propietario confirma en el panel de Supabase (nombre de proyecto,
   facturación, referencia) cuál `ref` es productivo real, cerrando NC-D-01.
2. Con esa confirmación, rehacer D4/D5 sobre el alcance completo (D2, D3.2,
   D3.4, D3.5.1, D3.5.2, D3.5.3) contra el proyecto correcto, con respaldo
   fresco restaurado antes de tocar producción.
