# HANDOFF BeautyOS — pasos 1135–1148

**Fecha:** 20 de julio de 2026
**Bloque documentado:** implementación y validación en ensayo del Tramo B — contexto operacional por sede
**Estado:** ensayo aprobado; producción y publicación remota pendientes
**Modelo recomendado para la siguiente compuerta productiva:** GPT-5.6 Sol, esfuerzo Alto; Terra Medio para pruebas visuales y documentación posterior

## Resumen ejecutivo

El Tramo B fue implementado completamente en un PostgreSQL aislado restaurado desde el respaldo de BeautyOS. Se añadió contexto de sede a 15 tablas operativas mediante una migración aditiva, restricciones compuestas y un puente temporal seguro para la aplicación heredada. La migración fue aplicada, auditada, revertida y reaplicada, conservando las 139 filas y todos los valores financieros e inventarios de la línea base.

No se modificó la aplicación Flutter, no se tocó producción y no se hizo `push`.

## Pasos registrados

**1135.** El propietario aprobó implementar el Tramo B en su totalidad, manteniendo fuera de alcance producción y publicación remota.

**1136.** Se revisaron las reglas permanentes del repositorio y las prácticas actuales de Supabase/PostgreSQL para seguridad, RLS, funciones privilegiadas, restricciones e índices.

**1137.** Se creó la migración administrada `20260720111110_tramo_b_contexto_operacional_sede.sql` y los scripts SQL 107–110 de auditoría, aislamiento, reversión y compatibilidad.

**1138.** La migración añadió `branch_id` a 15 tablas y rellenó las 139 filas históricas desde la Sede principal, ticket, servicio de ticket o compra según la regla aprobada.

**1139.** Se incorporaron claves compuestas, claves foráneas validadas, índices exactos y 15 triggers de compatibilidad. Los helpers privados revocan ejecución a clientes y no confían en una sede enviada por Flutter.

**1140.** Se restauró el respaldo del 19/07/2026 en un contenedor PostgreSQL aislado. Como el artefacto local no contenía `auth.users`, la preparación del ensayo omitió únicamente esa referencia privada al aplicar el Tramo A; el esquema público y sus datos se conservaron.

**1141.** La primera aplicación del Tramo B detectó que PostgreSQL no admite `min(uuid)` en el helper de sede. La prueba evitó avanzar con un defecto y el helper se corrigió mediante conteo y selección explícitos.

**1142.** La migración corregida se aplicó satisfactoriamente y la auditoría confirmó cero nulos, cero cruces y alineación completa entre hijos y padres.

**1143.** La reversión protegida retiró solo el Tramo B; posteriormente se reaplicó sin divergencias. La secuencia se repitió después del ajuste final de índices.

**1144.** Los totales permanecieron intactos: pagos vigentes $250.000, pagos anulados $115.000, comisiones vigentes $100.000, comisiones anuladas $36.000 y stock derivado 2.530 unidades.

**1145.** Las pruebas negativas rechazaron sedes, clientes, servicios, estilistas, productos e hijos pertenecientes a otro tenant o sede, así como el traslado directo de tickets históricos.

**1146.** Las RPC heredadas de creación de ticket, adición de servicio, resúmenes, opciones y disponibilidad siguieron funcionando y completaron la sede de forma segura.

**1147.** La auditoría de índices de claves foráneas encontró una deuda residual, se añadieron los índices exactos necesarios y el resultado final fue cero claves foráneas sin apoyo. `flutter analyze` no reportó problemas y todas las pruebas Flutter aprobaron.

**1148.** Se actualizaron el Plan Maestro, registro de decisiones, criterios de salida, auditoría del Tramo B e índice documental. El bloque queda listo para commit local, sin despliegue productivo ni `push`.

## Evidencia técnica

- Migración: `supabase/migrations/20260720111110_tramo_b_contexto_operacional_sede.sql`
- Auditoría: `supabase/sql/107_verify_tramo_b_branch_context.sql`
- Aislamiento y compatibilidad: `supabase/sql/108_test_tramo_b_compatibility_and_isolation.sql`
- Reversión exclusiva de ensayo: `supabase/sql/109_rollback_tramo_b_test_only.sql`
- RPC heredadas: `supabase/sql/110_test_tramo_b_legacy_rpcs.sql`
- Informe rector: `docs/01_arquitectura/auditorias/TRAMO_B_DISENO_BACKFILL_OPERACIONAL_2026-07-20.md`

## Próxima compuerta

El despliegue productivo del Tramo B requiere autorización expresa separada. Antes de aplicarlo se debe crear un respaldo fresco posterior al Tramo A; después se ejecutarán las auditorías 107 y 110. Si la evidencia coincide, el usuario realizará la prueba visual heredada y solo entonces se propondrá publicar los commits en GitHub.
