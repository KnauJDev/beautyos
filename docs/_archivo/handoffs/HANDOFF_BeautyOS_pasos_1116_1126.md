# HANDOFF BeautyOS — pasos 1116–1126

**Proyecto:** BeautyOS
**Bloque documentado:** compuerta de producción y cierre del Tramo A
**Fecha de cierre:** 20 de julio de 2026
**Repositorio:** `https://github.com/KnauJDev/beautyos.git`
**Ruta local:** `C:\Proyectos\BeautyOS`
**Rama:** `main`
**Supabase:** `beautyos-dev` (`eogppgbdnwxdtcbctaol`)
**Estado:** Tramo A aplicado, verificado, documentado y publicado

## 1. Resumen ejecutivo

Este bloque trasladó a producción la estructura multisede que ya había sido probada sobre una restauración aislada. La operación se realizó como una compuerta controlada: primero se comprobó que GitHub, el historial remoto, el respaldo y la línea base seguían coincidiendo; después se aplicó una única migración estructural y se ejecutó inmediatamente la verificación repetible.

El asesor de Supabase señaló que varias claves foráneas nuevas podían beneficiarse de índices de apoyo. Se agregó una segunda migración exclusivamente aditiva. Al finalizar, las siete tablas nuevas conservaron RLS, no tenían grants directos para clientes y ninguna clave foránea del Tramo A quedó sin índice.

No se modificó Flutter, no se cambiaron las RPC existentes y no se alteró ningún total operativo, financiero o de inventario.

## 2. Bitácora paso a paso

**1116.** Se confirmó el uso de Codex con GPT-5.6 Sol, esfuerzo Alto, para ejecutar la compuerta de producción del Tramo A.

**1117.** Se releyeron las reglas permanentes del repositorio y las skills oficiales de Supabase. Se mantuvieron como límites: aislamiento estricto, RLS, privilegio mínimo, ausencia de secretos y prohibición de mezclar el Tramo B.

**1118.** La conexión integrada identificó el proyecto correcto `beautyos-dev`, activo y saludable, en PostgreSQL 17.6.

**1119.** La inspección previa comprobó que `branches`, `tenant_memberships`, `branch_memberships`, `branch_services`, `branch_stylists`, `branch_stylist_services` y `branch_products` todavía no existían. El historial administrado contenía las ocho migraciones esperadas y ninguna posterior al respaldo.

**1120.** La línea base viva coincidió exactamente con la restauración: 1 tenant, 2 perfiles, 4 servicios, 2 estilistas, 4 capacidades, 4 productos, 12 tickets, 13 servicios asignados, $250.000 en pagos vigentes, $115.000 anulados, $100.000 en comisiones vigentes, $36.000 anuladas y 2.530 unidades de stock activo.

**1121.** Se actualizó la referencia de GitHub, se confirmó que `origin/main` no tenía avances paralelos y se publicaron los cuatro commits validados del Tramo 0 y Tramo A, desde `25fa991` hasta `690a30c`.

**1122.** Supabase aplicó y registró `20260720102317_tramo_a_estructura_multisede`. Se creó una Sede principal para el tenant existente y se copiaron las relaciones actuales sin retirar el modelo heredado.

**1123.** Se ejecutó `104_verify_tramo_a_multisite.sql`. Las correspondencias fueron exactas: 1 sede principal, 2 membresías tenant, 2 membresías de sede, 4 servicios por sede, 2 estilistas por sede, 4 capacidades y 4 productos. Los totales históricos permanecieron invariantes.

**1124.** Los asesores de Supabase confirmaron la seguridad cerrada prevista. Las siete advertencias informativas de RLS sin política son intencionales: las tablas no se abrirán a usuarios autenticados hasta que existan RPC y políticas completas con contexto de sede en el Tramo C. El asesor de rendimiento encontró claves foráneas compuestas sin índice completo.

**1125.** Se creó y registró `20260720102806_tramo_a_indexar_claves_foraneas.sql` con once índices de apoyo. La verificación final devolvió cero claves foráneas nuevas sin índice, siete de siete tablas con RLS y cero grants para `anon` o `authenticated`.

**1126.** Se actualizó el expediente rector, el plan de migración, los criterios de salida y la auditoría del Tramo A. Se publicó el cierre en `main` y se fijó como siguiente compuerta el diseño detallado del Tramo B.

## 3. Invariantes finales

| Control | Resultado final |
|---|---:|
| Tickets | 12 |
| Servicios asignados a tickets | 13 |
| Pagos vigentes | $250.000 |
| Pagos anulados | $115.000 |
| Comisiones vigentes | $100.000 |
| Comisiones anuladas | $36.000 |
| Stock activo heredado | 2.530 |
| Stock activo de sede | 2.530 |
| Tablas nuevas con RLS | 7 de 7 |
| Grants directos a clientes | 0 |
| Claves foráneas nuevas sin índice | 0 |

## 4. Archivos principales

- `supabase/migrations/20260720102317_tramo_a_estructura_multisede.sql`
- `supabase/migrations/20260720102806_tramo_a_indexar_claves_foraneas.sql`
- `supabase/sql/104_verify_tramo_a_multisite.sql`
- `supabase/sql/105_test_tramo_a_tenant_isolation.sql`
- `supabase/sql/106_rollback_tramo_a_test_only.sql`
- `docs/01_arquitectura/auditorias/TRAMO_A_ESTRUCTURA_MULTISEDE_2026-07-20.md`

## 5. Decisiones que continúan vigentes

- Las tablas heredadas siguen siendo la fuente usada por Flutter durante la compatibilidad.
- Las tablas nuevas permanecen cerradas a `anon` y `authenticated` hasta el Tramo C.
- `service_role` nunca se incorpora al frontend.
- El Tramo B se diseñará y aprobará antes de aplicarlo; no se mezclará con cambios visuales.
- Las alertas operativas continúan pausadas por instrucción expresa del propietario.
- Los avisos heredados del asesor de Supabase se tratarán por bloques controlados; no se corregirán de forma masiva sin revisar cada RPC y flujo.

## 6. Próximo paso

Diseñar el **Tramo B — contexto operacional por sede**. El diseño debe enumerar las tablas que recibirán `branch_id`, establecer el backfill hacia la Sede principal, definir índices y claves foráneas compuestas, conservar los totales financieros y preparar pruebas negativas y reversión. Solo después de aprobar ese diseño se creará la migración.
