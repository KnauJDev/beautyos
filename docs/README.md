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
20. `HANDOFF/HANDOFF_BeautyOS_pasos_1149_1160.md`
21. `01_arquitectura/ADR/ADR-005_CONTEXTO_DE_SEDE_EFECTIVA.md`
22. `01_arquitectura/auditorias/TRAMO_C_DISENO_OPERACION_CONSCIENTE_SEDE_2026-07-20.md`
23. `../supabase/migrations/20260720123813_tramo_c1_contexto_sede_efectiva.sql`
24. `HANDOFF/HANDOFF_BeautyOS_pasos_1161_1172.md`
25. `01_arquitectura/auditorias/TRAMO_D5_PRE_2_AUDITORIA_NO_CONFORMIDADES_2026-07-20.md` (no conformidades bloqueantes del Tramo D, incluye NC-D-01 abierta)
26. `01_arquitectura/auditorias/TRAMO_D3_5_3_AUTORIZACION_MEMBRESIAS_2026-07-22.md`
27. `../supabase/migrations/20260722175530_tramo_d3_5_3_autorizacion_memberships.sql`
28. `HANDOFF/HANDOFF_BeautyOS_Tramo_D3_5_3_2026-07-22.md`
29. `01_arquitectura/auditorias/TRAMO_D_CIERRE_PRODUCTIVO_2026-07-22.md` (Tramo D desplegado en el único proyecto real)
30. `01_arquitectura/auditorias/SUSCRIPCIONES_ENTITLEMENTS_FUNDACION_2026-07-22.md`
31. `../supabase/migrations/20260722184914_suscripciones_entitlements_fundacion.sql`
32. `01_arquitectura/auditorias/REGISTRO_SELF_SERVE_TENANT_2026-07-22.md`
33. `../supabase/migrations/20260722190130_registro_self_serve_tenant.sql`
34. `01_arquitectura/auditorias/PANEL_PLATAFORMA_FUNDACION_2026-07-22.md`
35. `../supabase/migrations/20260722220616_panel_plataforma_fundacion.sql`
36. `01_arquitectura/auditorias/FLUTTER_REGISTRO_Y_PANEL_PLATAFORMA_2026-07-22.md`
37. `../supabase/migrations/20260722232511_registro_self_serve_datos_base.sql`
38. `01_arquitectura/auditorias/CREAR_SERVICIOS_Y_ESTILISTAS_2026-07-23.md`
39. `../supabase/migrations/20260723152713_crear_servicio_y_estilista.sql`
40. `01_arquitectura/auditorias/SINCRONIZAR_BRANCH_STYLIST_SERVICES_2026-07-23.md`
41. `../supabase/migrations/20260723163835_sincronizar_branch_stylist_services.sql`
42. `01_arquitectura/auditorias/INVITAR_USUARIOS_DEL_NEGOCIO_2026-07-23.md`
43. `../supabase/migrations/20260723173701_invitar_usuarios_del_negocio.sql`
44. `01_arquitectura/auditorias/EDITAR_Y_DESACTIVAR_CATALOGO_2026-07-23.md`
45. `../supabase/migrations/20260723175921_editar_y_desactivar_catalogo.sql`
46. `01_arquitectura/auditorias/EDITAR_HORARIO_Y_POLITICAS_2026-07-23.md`
47. `../supabase/migrations/20260723185020_editar_horario_y_politicas.sql`
48. `01_arquitectura/auditorias/RESERVA_PUBLICA_CLIENTE_2026-07-23.md`
49. `../supabase/migrations/20260723200000_reserva_publica_cliente.sql`
50. `00_producto/PROMPT_MAESTRO_IA.md` (prompt para arrancar cualquier chat nuevo de IA en este proyecto)
51. `01_arquitectura/auditorias/EDITAR_PRODUCTOS_INVENTARIO_2026-07-23.md`
52. `../supabase/migrations/20260723210000_editar_productos_inventario.sql`
53. `01_arquitectura/auditorias/REGISTRAR_COMPRAS_2026-07-24.md`
54. `../supabase/migrations/20260724130000_registrar_compras.sql`
55. `01_arquitectura/auditorias/EDITAR_GASTOS_2026-07-24.md`
56. `../supabase/migrations/20260724150000_editar_gastos.sql`
57. `01_arquitectura/auditorias/CONSUMO_INTERNO_2026-07-24.md`
58. `../supabase/migrations/20260724170000_registrar_consumo_interno.sql`
59. `01_arquitectura/auditorias/AUDITORIA_ROLES_Y_BRECHAS_2026-07-24.md`
60. `01_arquitectura/auditorias/RESENAS_PUBLICAS_Y_MODERACION_2026-07-25.md`
61. `../supabase/migrations/20260724180000_resenas_publicas_y_moderacion.sql`
62. `../supabase/migrations/20260725120000_visibilidad_resenas_desacoplada.sql`
63. `01_arquitectura/auditorias/STORAGE_FOTOS_DE_TRABAJO_2026-07-25.md`
64. `../supabase/migrations/20260725140000_storage_fotos_de_trabajo.sql`
65. `../supabase/migrations/20260725170000_simplificar_ruta_storage_fotos.sql`
66. `01_arquitectura/auditorias/CREAR_Y_APROBAR_FOTOS_TRABAJO_2026-07-25.md`
67. `../supabase/migrations/20260725160000_crear_y_aprobar_fotos_trabajo.sql`
68. `00_producto/RUTA_A_PRODUCCION_2026-07-25.md` (mapa de negocio/lanzamiento, Fase Final, pausado)
69. `00_producto/RUTA_GENERAL_2026-07-25.md` (mapa único vigente: fase MVP primero, orden a seguir)
70. `../supabase/migrations/20260725180000_correo_automatico_invitacion.sql`
71. `../supabase/functions/send-invitation-email/index.ts` (correo automático de invitación, D-062/D-065)
72. `../supabase/migrations/20260725190000_panel_personal_estilista.sql` (Mis reseñas y Mi panel financiero, D-067)
73. `../supabase/migrations/20260726100000_hacer_cumplir_prueba_gratis.sql` (bloqueo de compromisos nuevos con prueba vencida, D-068)
74. `../supabase/migrations/20260726110000_hacer_cumplir_planes_por_funcionalidad.sql` (Básico no puede usar funciones de plan superior, D-069)
75. `../supabase/migrations/20260726120000_admin_gestiona_usuarios.sql` (admin también gestiona usuarios, D-071)
76. `../supabase/migrations/20260727100000_crear_sedes_adicionales.sql` (crear sedes adicionales, D-072)
77. `../supabase/migrations/20260727110000_choque_agenda_entre_sedes.sql` (choque de agenda entre sedes, D-073)
78. `../supabase/migrations/20260727120000_bloqueo_agenda_estilista.sql` (bloqueo de agenda del estilista, D-075)
79. `../supabase/migrations/20260727130000_panel_plataforma_solo_lectura.sql` (acceso de solo lectura del dueño de plataforma, D-076)

Los ADR dentro de `01_arquitectura/ADR/` explican por qué se tomó cada decisión estructural. No se reescriben para ocultar el pasado: una decisión futura la reemplaza mediante otro ADR.

## Regla de actualización

Una modificación de arquitectura, alcance, rol, plan o flujo exige actualizar el Plan Maestro, el registro de decisiones y el documento especializado correspondiente en el mismo cambio.

Los respaldos editables, capturas y exportaciones Word/PDF se conservan adicionalmente en la carpeta personal de OneDrive del proyecto.
