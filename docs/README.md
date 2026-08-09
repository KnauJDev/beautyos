# Documentación de Salón y Más

> **Nota de nombre.** El producto se llama **Salón y Más** de cara al cliente
> desde D-089. El código, el repositorio (`KnauJDev/beautyos`) y el proyecto de
> Supabase siguen diciendo `beautyos` **a propósito**: no lo lee ningún usuario
> y renombrarlos costaría más de lo que aporta.

---

## 1. Si llegas nuevo, lee en este orden

Da igual si eres una persona o una inteligencia artificial. Con cuatro
documentos entiendes el proyecto:

| # | Documento | Te responde |
|---|---|---|
| 1 | `HANDOFF/` — **el más reciente por fecha** | ¿Dónde quedamos? Trae el prompt exacto para retomar |
| 2 | `00_producto/BARRIDO_Y_PLAN_MAESTRO_2026-08-08.md` | ¿Qué hay construido y qué falta, módulo por módulo? |
| 3 | `00_producto/PLAN_DE_LANZAMIENTO_2026-08-06.md` | ¿Cuál es el camino hasta vender? |
| 4 | `00_producto/REGISTRO_DE_DECISIONES.md` | **¿Por qué está hecho así?** Empieza por el final |

**No empieces por el código.** Este proyecto tiene 120 decisiones registradas
con su porqué; leer el código sin ellas es reconstruir a ciegas razonamientos
que ya están escritos.

---

## 2. Qué significan los códigos

Verás referencias como `D-102`, `H-09` o "hallazgo G" dentro del código, en los
mensajes de commit y en los documentos. **Son sistemas distintos:**

| Código | Qué es | Dónde vive |
|---|---|---|
| **D-001 … D-120** | **Decisiones.** El porqué de cada cosa, con lo que se descartó y por qué | `00_producto/REGISTRO_DE_DECISIONES.md` |
| **H-01 … H-13** | **Hallazgos** de la auditoría integral del 6 de agosto | `01_arquitectura/auditorias/AUDITORIA_INTEGRAL_2026-08-06.md` |
| **A … P** | **Anotado en el camino**: lo que salió sin etapa asignada | `PLAN_DE_LANZAMIENTO`, apartado 11 |
| **2.4, 3.6…** | **Números de tarea** del plan de lanzamiento | `PLAN_DE_LANZAMIENTO` |
| **Tramo A, D3.5.2…** | Trabajo de arquitectura multisede de julio | `01_arquitectura/auditorias/` |

> **Cuando el código cita un código, no lo inventes: búscalo.** Un comentario
> que dice `(D-097, D-102)` está señalando dónde está el razonamiento completo.
> Que una cita no tuviera respaldo fue exactamente el fallo de D-102, que el
> código citaba y el registro no tenía.

---

## 3. Qué documento manda sobre qué

Cada uno tiene un trabajo y **no se pisan**. Fue una decisión explícita (D-063)
después de tener dos mapas compitiendo entre sí.

| Documento | Responde | ¿Crece o se reemplaza? |
|---|---|---|
| **REGISTRO_DE_DECISIONES** | ¿Por qué es así? | **Solo crece.** Nunca se borra una fila; una decisión nueva corrige a la vieja citándola |
| **PLAN_DE_LANZAMIENTO** | ¿Qué falta y en qué orden? | Se actualiza al cerrar cada tarea |
| **HANDOFF** | ¿Dónde quedamos? | **Se reemplaza.** Cada uno sustituye al anterior |
| **ESPECIFICACION_\*** | ¿Cómo debe funcionar exactamente? | Contrato de una tarea concreta |
| **AUDITORIA_\*** | ¿Qué está mal hoy? | Foto de un momento |
| **`.xlsx`** | ¿Cómo va el avance? | Lo actualiza el propietario |

---

## 4. Cómo se trabaja aquí

Reglas acordadas con el propietario. **No son negociables.**

1. **Verificar en el código antes de afirmar.** No asumir.
2. **Antes de construir, decir en dos líneas qué y por qué**, y esperar
   confirmación (acordado el 08-ago).
3. **Registrar cada decisión con su porqué**, incluyendo lo que se descartó.
4. **Regla de hallazgos:** lo que aparezca en el camino se anota y se ataca
   donde le corresponde en el plan. Si no cabe, va al apartado 11.
5. **Pedir permiso antes de tocar Supabase, Cloudflare o hacer push.**
6. **Cualquier instalación en el computador del propietario la ejecuta él.**
   Los procesos del asistente corren aislados: lo que instalan no llega a su
   máquina (D-111).
7. **Respaldar antes de cualquier sesión con migraciones:**
   `scripts/respaldo_supabase.ps1`
8. **El propietario prueba en producción y reporta.** El asistente no ve la
   interfaz.

---

## 5. Estructura de carpetas

- `00_producto/` — visión, plan, decisiones, especificaciones y alcance
- `01_arquitectura/` — modelo multisede, roles, suscripciones, ADR y auditorías
- `02_operacion/` — respaldo, restauración y procedimientos
- `03_referencias/` — benchmarking y fuentes externas
- `04_pruebas/` — criterios de salida y evidencias
- `HANDOFF/` — el punto de retomada de cada sesión

---

## 6. Registro cronológico

Lo que sigue es el **historial completo** de documentos y migraciones, en el
orden en que se fueron creando. **No se reescribe para ocultar el pasado.**

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
80. `../supabase/migrations/20260727140000_logo_negocio_marca_blanca.sql` (logo por negocio, D-077)
81. `00_producto/BENCHMARKING_2026-07-28.md` (benchmarking contra AgendaPro y orden de ejecución acordado)
82. `../supabase/migrations/20260728100000_comisiones_por_sede_estilista_servicio.sql` (excepciones de comisión, D-078)
83. `../supabase/migrations/20260728120000_bloqueo_agenda_recurrente.sql` (bloqueos recurrentes, D-080)
84. `../supabase/migrations/20260728130000_citas_recurrentes_agenda_interna.sql` (citas recurrentes, D-081)
85. `../supabase/migrations/20260804100000_saldo_acumulado_cliente.sql` (saldo acumulado del cliente, D-083)
86. `../supabase/migrations/20260805100000_portada_y_perfil_profesional.sql` (portada y foto/bio del profesional, D-084)
87. `../supabase/migrations/20260806100000_marca_producto_y_alarma_stock.sql` (marca de producto y alarma de stock, D-086)
88. `../supabase/functions/send-low-stock-alert/index.ts` (correo de alarma de stock bajo, D-086)
89. `01_arquitectura/auditorias/AUDITORIA_INTEGRAL_2026-08-06.md` (**auditoría completa del aplicativo**: arquitectura verificada, matriz de perfiles, integridad Flutter↔BD y 14 hallazgos priorizados, D-087)
90. `00_producto/PLAN_DE_LANZAMIENTO_2026-08-06.md` (**mapa de lanzamiento vigente**: 5 etapas de proyecto a negocio, hosting/dominio/ePayco decididos, D-088 — reemplaza a `RUTA_A_PRODUCCION_2026-07-25.md`, que queda archivado)
91. `00_producto/ESPECIFICACION_AGENDA_2026-08-07.md` (**la Agenda como tablero de tickets**: tres vistas, regla del cero, numero de ticket consecutivo, D-101 — contrato de la tarea 2.6)
92. `../supabase/migrations/20260806140000_tope_reserva_publica.sql` (tope antiabuso de la reserva publica, H-02, D-092)
93. `../supabase/migrations/20260806160000_asistente_lectura_agenda_tickets_clientes.sql` (acceso de lectura del asistente, D-094)
94. `../supabase/migrations/20260806190000_asistente_lista_clientes.sql` (regresion de Clientes corregida, D-095)
95. `../lib/theme/` (**sistema de diseno**: `AppColors`, `AppSpacing`, `AppRadius`, `AppTheme`, `AppBrand` — D-102, D-109)
96. `../test/sin_colores_sueltos_test.dart` (**guardian del sistema de diseno**: falla si alguien escribe un color a mano fuera del tema, D-102)
97. `../supabase/migrations/20260807120000_tema_por_negocio_marca_blanca.sql` (marca blanca por colores: 5 temas mas uno personalizado, D-109)
98. `00_producto/ESPECIFICACION_DASHBOARD_2026-08-08.md` (**el Dashboard como historia**: diccionario de indicadores con su formula, reglas de comparacion, estados del dia cero, D-110)
99. `../supabase/migrations/20260808120000_dashboard_resumen_comparado.sql` (resumen comparado del Dashboard, D-110)
100. `../supabase/migrations/20260808160000_dashboard_serie_del_grafico.sql` (serie del grafico protagonista, D-110)
101. `../supabase/migrations/20260809100000_dashboard_hoy_y_avisos.sql` (agenda de hoy y avisos, D-113)
102. `../supabase/migrations/20260809140000_dashboard_horas_vendidas.sql` (horas vendidas, sin porcentaje de ocupacion, D-114)
103. `../scripts/respaldo_supabase.ps1` y `../scripts/respaldo_archivos.ps1` (**respaldo vigente**, sin Docker — reemplazan a `crear_respaldo_supabase.ps1`, D-111)
104. `../lib/services/monitoreo_service.dart` (**monitoreo de errores sin datos personales**, D-115)
105. `00_producto/GUIA_TECNICA_PARA_PRODUCCION_2026-08-08.md` (**sobre que corre, cuanto cuesta y que falta para vender**, en lenguaje sin tecnicismos)
106. `00_producto/BARRIDO_Y_PLAN_MAESTRO_2026-08-08.md` (**barrido completo del 08-ago**: estado real de los 16 modulos, lo huerfano y el plan hasta produccion)
107. `00_producto/PLAN_DE_TRABAJO_A_PRODUCCION.xlsx` (**hoja de seguimiento del propietario**: 26 acciones en 5 etapas)
108. `HANDOFF/HANDOFF_SalonyMas_2026-08-08.md` (**handoff vigente**, con el prompt exacto para retomar)
109. `../supabase/migrations/20260809160000_numero_de_ticket_consecutivo.sql` (**numero de ticket consecutivo y ajustable**, tarea 2.6a, D-117)
110. `../supabase/sql/161_verify_numero_de_ticket.sql` (verificacion del consecutivo, con prueba de escritura en `ROLLBACK`)
111. `../test/numero_de_ticket_test.dart` (el consecutivo viaja intacto hasta la pantalla)
112. `../scripts/aplicar_sql.ps1` (**ejecuta un archivo SQL contra la base**, hermano de `respaldo_supabase.ps1`: codifica la contrasena igual que el, que es lo unico que funciona con la contrasena de este proyecto)
113. `../supabase/migrations/20260809180000_fotos_privadas_hasta_aprobar.sql` (**las fotos de trabajo nacen privadas y aprobarlas es lo que las publica**, accion A4, cierra H-09, D-119)
114. `../supabase/sql/162_verify_fotos_privadas.sql` (verificacion de los almacenes y de la coherencia entre aprobada y publicada)
115. `../lib/services/work_photo_storage.dart` (los dos almacenes y el movimiento entre ellos)
116. `../lib/services/storage_cleanup.dart` (**borrar archivos**: el anterior al reemplazar logo o portada, y el que el dueno elimina a mano)
117. `../supabase/migrations/20260809200000_negocio_de_prueba.sql` (**marcar un negocio como de prueba**, accion A5, D-120)

Los ADR dentro de `01_arquitectura/ADR/` explican por qué se tomó cada decisión
estructural. No se reescriben para ocultar el pasado: una decisión futura la
reemplaza mediante otro ADR.

## Regla de actualización

Una modificación de arquitectura, alcance, rol, plan o flujo exige actualizar el
plan de lanzamiento, el registro de decisiones y el documento especializado
correspondiente **en el mismo cambio**.

Los respaldos, capturas y exportaciones se conservan además en la carpeta
personal de OneDrive del proyecto.
