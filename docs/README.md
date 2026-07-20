# Documentación de BeautyOS

Esta carpeta es la fuente oficial viva de la arquitectura, producto y operación del proyecto. Todo documento relevante se versiona con Git y se publica junto al código.

## Estructura

- `00_producto/`: visión, Plan Maestro, decisiones y alcance.
- `01_arquitectura/`: modelo multisede, roles, suscripciones, migración y ADR.
- `02_operacion/`: flujos y procedimientos operativos (se crea cuando se documenten).
- `03_referencias/`: benchmarking y fuentes externas (sin copiar contenido protegido).
- `04_pruebas/`: criterios de salida y evidencias de calidad.

## Documentos rectores actuales

1. `00_producto/BEAUTYOS_EXPEDIENTE_TECNICO_Y_PLAN_MAESTRO.md`
2. `00_producto/REGISTRO_DE_DECISIONES.md`
3. `01_arquitectura/FASE_1_MODELO_MULTISEDE.md`
4. `01_arquitectura/ROLES_Y_PERMISOS.md`
5. `01_arquitectura/SUSCRIPCION_Y_ENTITLEMENTS.md`
6. `01_arquitectura/IMPACTO_Y_MIGRACION_MULTISEDE.md`
7. `04_pruebas/CRITERIOS_SALIDA_FASE_1.md`
8. `01_arquitectura/auditorias/TRAMO_0_LINEA_BASE_2026-07-19.md`
9. `02_operacion/RESPALDO_Y_RESTAURACION_SUPABASE.md`
10. `../scripts/crear_respaldo_supabase.ps1` (asistente local; no contiene secretos)
11. `01_arquitectura/auditorias/TRAMO_A_ESTRUCTURA_MULTISEDE_2026-07-20.md`
12. `../supabase/migrations/20260720102317_tramo_a_estructura_multisede.sql`
13. `../supabase/migrations/20260720102806_tramo_a_indexar_claves_foraneas.sql`
14. `HANDOFF/HANDOFF_BeautyOS_pasos_1086_1115.md`
15. `HANDOFF/HANDOFF_BeautyOS_pasos_1116_1126.md`
16. `HANDOFF/HANDOFF_BeautyOS_pasos_1127_1134.md`
17. `01_arquitectura/auditorias/TRAMO_B_DISENO_BACKFILL_OPERACIONAL_2026-07-20.md`
18. `../supabase/migrations/20260720111110_tramo_b_contexto_operacional_sede.sql`
19. `HANDOFF/HANDOFF_BeautyOS_pasos_1135_1148.md`

Los ADR dentro de `01_arquitectura/ADR/` explican por qué se tomó cada decisión estructural. No se reescriben para ocultar el pasado: una decisión futura la reemplaza mediante otro ADR.

## Regla de actualización

Una modificación de arquitectura, alcance, rol, plan o flujo exige actualizar el Plan Maestro, el registro de decisiones y el documento especializado correspondiente en el mismo cambio.

Los respaldos editables, capturas y exportaciones Word/PDF se conservan adicionalmente en la carpeta personal de OneDrive del proyecto.
