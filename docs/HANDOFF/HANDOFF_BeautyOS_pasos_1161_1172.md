# HANDOFF BeautyOS — pasos 1161–1172

**Fecha:** 20 de julio de 2026  
**Bloque documentado:** diseño del Tramo C y validación aislada de C1 — contexto de sede efectiva  
**Estado:** C1 implementado y aprobado en ensayo; producción no modificada; cambios locales pendientes de publicación  
**Modelo recomendado para C2:** GPT-5.6 Sol, esfuerzo Alto para contratos de reservas/agenda y pruebas de aislamiento; Terra Medio para comprobaciones visuales repetitivas

## Resumen ejecutivo

El Tramo C quedó dividido en cuatro subcompuertas para migrar BeautyOS a operación multisede real sin romper la aplicación heredada. C1 implementó la raíz de confianza: Flutter podrá seleccionar una sede, pero Supabase vuelve a validar usuario, tenant, rol, vigencia, membresía y vínculo profesional en cada operación. La implementación es aditiva, mantiene intactas las RPC existentes y no fue enviada a producción.

La migración y sus pruebas se ejecutaron sobre una restauración local desechable del respaldo fresco. Aprobaron el aislamiento Tenant A/Tenant B, las diferencias Owner/Admin/Stylist, la revocación por desactivación y la ejecución como el rol `authenticated` usado por Flutter. El helper privado no quedó expuesto. Flutter mantuvo análisis y pruebas limpias.

## Pasos registrados

**1161.** El propietario autorizó continuar el Tramo C en modalidad Codex con GPT-5.6 Sol Alto, manteniendo ahorro de recursos y seguridad como condiciones rectoras.

**1162.** Se verificaron Plan Maestro, ADR, criterios de salida, HANDOFF 1149–1160 y Git. El punto de partida fue `main` limpio y sincronizado con `origin/main` en `46653bf`.

**1163.** Se inventariaron las RPC y servicios Flutter de tickets, reservas, disponibilidad, agendas, pagos, caja, reportes e inventario que todavía operan por tenant o zona horaria fija.

**1164.** Se cerró el contrato de sede efectiva: `tenant_owner` puede seleccionar las sedes activas de su tenant; `admin` y `assistant` requieren membresía activa; `stylist` requiere además vínculo profesional activo. Ningún identificador enviado por Flutter se acepta como autorización.

**1165.** Se creó ADR-005 y el diseño rector C1–C4. La sede se conserva en memoria de la aplicación, no en metadatos editables, JWT como fuente única ni variables de sesión persistentes. Las nuevas RPC usarán nombres `_v2` y `p_branch_id` obligatorio.

**1166.** Se creó la migración `20260720123813_tramo_c1_contexto_sede_efectiva.sql` con el resolver privado `private.beautyos_resolve_branch_access(...)` y la RPC pública `get_my_branch_context_v2()`.

**1167.** Se restringieron permisos: `anon` y `authenticated` no pueden ejecutar el resolver privado; sólo `authenticated` puede invocar el listado público. Ambas funciones fijan `search_path=pg_catalog` y califican sus objetos por esquema.

**1168.** Se prepararon `111_test_tramo_c1_branch_context.sql` y `112_verify_tramo_c1_branch_context.sql` para probar funcionalidad, cruces de tenant/sede, vigencias, ejecución autenticada y privilegios. Todas las mutaciones de la prueba 111 terminan en `ROLLBACK`.

**1169.** Se levantó PostgreSQL desechable y se restauraron roles, esquema y datos públicos desde `BeautyOS_Backup_2026-07-20_06-57-21`. La imagen local incluye una versión Auth anterior; para reproducir las claves foráneas se añadieron exclusivamente dos identidades ficticias dentro del ensayo.

**1170.** C1 se aplicó correctamente en el ensayo. Owner A recibió A1/A2 y fue bloqueado frente a Tenant B; Admin A1 no pudo seleccionar A2; Stylist A1 no recibió una sede sin `branch_stylists` aunque tuviera `branch_memberships`.

**1171.** La membresía desactivada perdió acceso en la siguiente llamada. La RPC pública aprobó bajo `SET ROLE authenticated` y la invocación directa del helper privado fue denegada. La auditoría confirmó `SECURITY DEFINER`, `search_path` fijo y grants mínimos.

**1172.** `flutter analyze` terminó sin hallazgos, `flutter test` aprobó y `git diff --check` no detectó errores. No se hizo `db push`, no se modificó producción y tampoco se hizo `git push`.

## Evidencia técnica

- ADR: `docs/01_arquitectura/ADR/ADR-005_CONTEXTO_DE_SEDE_EFECTIVA.md`
- Diseño: `docs/01_arquitectura/auditorias/TRAMO_C_DISENO_OPERACION_CONSCIENTE_SEDE_2026-07-20.md`
- Migración C1: `supabase/migrations/20260720123813_tramo_c1_contexto_sede_efectiva.sql`
- Prueba aislada: `supabase/sql/111_test_tramo_c1_branch_context.sql`
- Auditoría de permisos: `supabase/sql/112_verify_tramo_c1_branch_context.sql`
- Respaldo de origen: `C:\Users\Tercero\OneDrive\Documents\BeautyOS Backups\BeautyOS_Backup_2026-07-20_06-57-21`

## Próxima compuerta

Implementar C2 fuera de producción: versiones `_v2` de servicios/opciones, disponibilidad, creación de reserva y ticket, agendas administrativa y propia, reprogramación, asignaciones, estados y pagos, todas con `p_branch_id` validado por C1. Después se conectará el contexto Flutter por módulos y se probará el flujo completo en A1/A2 y contra Tenant B. Las alertas operativas continúan pausadas.
