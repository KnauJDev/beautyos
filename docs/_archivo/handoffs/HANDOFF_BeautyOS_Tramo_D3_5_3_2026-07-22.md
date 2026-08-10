# HANDOFF BeautyOS — Tramo D3.5.3

**Fecha:** 22 de julio de 2026
**Bloque documentado:** cierre de NC-D-04 (autorización heredada → memberships)
**Estado:** completado localmente; sin cambios remotos

## Nota sobre numeración

Este handoff no continúa la numeración estricta de "pasos" de los handoffs
anteriores (el último fue `HANDOFF_BeautyOS_pasos_1205_1215.md`). El Tramo D
completo (D0 a D5-pre.2, ~19 commits) se ejecutó sin handoffs intermedios
propios; reconstruir esa numeración retroactivamente no aporta valor y se
dejó fuera de este bloque a pedido explícito de consolidar documentación. La
auditoría `TRAMO_D5_PRE_2_AUDITORIA_NO_CONFORMIDADES_2026-07-20.md` ya cubre
esa historia con el detalle necesario.

## Resumen ejecutivo

Se cerró NC-D-04: la autorización heredada basada en `user_profiles.role`
convivía sin sincronización con el modelo de membresías (ADR-002). Seis
funciones (tres helpers, `get_tenant_users`, `update_tenant_user_access`,
`create_client`) ahora autorizan contra `tenant_memberships` con ventana de
vigencia. Se detectó y corrigió un error real de PL/pgSQL durante la prueba
(colisión de nombre entre una columna de `returns table` y un `on conflict`),
no un artefacto del entorno de prueba.

## Pasos registrados

**1.** Auditoría inicial compacta del repositorio real (`C:\Proyectos\BeautyOS`,
no la ruta genérica asumida por el encargo): 23 commits locales sin publicar,
Tramo D en curso, HEAD en `3523041` (D3.5.2).

**2.** Se detectó NC-D-01 (identidad productiva contradictoria de
`eogppgbdnwxdtcbctaol`) sin resolver; el propietario decidió verificarla por
su cuenta en el panel de Supabase antes de continuar. D4/D5 permanecen en
NO-GO por esa razón, no por este bloque.

**3.** El propietario autorizó D3.5.3 como siguiente bloque, consolidado en
un solo documento/commit y sin pausas internas, y delegó la decisión técnica
de alcance (migrar a memberships ahora, coherente con D3.5.1/D3.5.2).

**4.** Se ubicaron las siete referencias directas a `user_profiles` en RPC
heredadas y se contrastaron contra Flutter (`lib/services/*.dart`) y contra
la clasificación previa del propio Tramo D (`TRAMO_D3_INVENTARIO...md`):
solo `create_client` sigue viva con ese patrón; las otras seis ya estaban
retiradas de `authenticated`/`anon` desde D3.5.2.

**5.** Se revisaron los tres helpers (`supabase/sql/035-037`) y las RPC de
gestión de usuarios (`supabase/sql/085`, `033`) para confirmar que
`get_tenant_users`/`update_tenant_user_access` también autorizan de forma
inline contra `user_profiles.role`, y que `update_tenant_user_access` nunca
sincronizaba `tenant_memberships`.

**6.** Se escribió `supabase/migrations/20260722175530_tramo_d3_5_3_autorizacion_memberships.sql`.

**7.** Se intentó `supabase start` para probarla contra Postgres real; falló
como se esperaba en la primera migración heredada (`relation "public.tickets"
does not exist`), confirmando el hueco ya documentado en Tramo 0 §6.1.

**8.** Se construyó un Postgres desechable con la misma imagen de Supabase y
un esquema sintético mínimo (`supabase/sql/132`), y una prueba de
comportamiento de 12 verificaciones (`supabase/sql/133`).

**9.** La primera corrida encontró un error real: `column reference "user_id"
is ambiguous` en `update_tenant_user_access`, causado por la colisión entre
la columna de retorno `user_id` y el `on conflict (tenant_id, user_id)`. Se
corrigió con `#variable_conflict use_column`.

**10.** Segunda corrida: **12 de 12 verificaciones aprobadas**. `flutter
analyze` sin hallazgos; `flutter test` con 5 pruebas aprobadas (sin cambios
en Dart).

**11.** Se destruyó el contenedor sintético y un contenedor detenido de un
ensayo anterior (`beautyos-tramo-c-test`, sin datos vivos). No se tocó
ningún proyecto Supabase remoto.

**12.** Se documentó la decisión D-041, esta auditoría y este handoff.

## Evidencia principal

- Migración: `supabase/migrations/20260722175530_tramo_d3_5_3_autorizacion_memberships.sql`
- Prueba sintética: `supabase/sql/132_test_tramo_d3_5_3_autorizacion_memberships.sql`,
  `supabase/sql/133_verify_tramo_d3_5_3_autorizacion_memberships.sql`
- Auditoría: `docs/01_arquitectura/auditorias/TRAMO_D3_5_3_AUTORIZACION_MEMBRESIAS_2026-07-22.md`
- Decisión: `D-041` en `docs/00_producto/REGISTRO_DE_DECISIONES.md`

## Próximo azimut

D4/D5 siguen en NO-GO. El siguiente paso depende del propietario: confirmar
en el panel de Supabase cuál `ref` es realmente productivo (NC-D-01). Con esa
confirmación, rehacer D4/D5 sobre el alcance completo (D2, D3.2, D3.4,
D3.5.1, D3.5.2, D3.5.3) contra el proyecto correcto, con respaldo fresco
restaurado antes de tocar producción.
