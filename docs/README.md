# Documentación de Salón y Más

> **Nota de nombre.** El producto se llama **Salón y Más** de cara al cliente
> desde D-089. El código, el repositorio (`KnauJDev/beautyos`) y el proyecto de
> Supabase siguen diciendo `beautyos` **a propósito**: no lo lee ningún usuario
> y renombrarlos costaría más de lo que aporta.

---

## 1. Si llegas nuevo, lee en este orden

Da igual si eres una persona o una inteligencia artificial. **Con tres
documentos entiendes el proyecto entero.**

| # | Documento | Te responde |
|---|---|---|
| 1 | `HANDOFF/` — **el más reciente por fecha** | ¿Dónde quedamos? Trae el prompt exacto para retomar |
| 2 | **`00_producto/PLAN_MAESTRO.md`** | **¿Qué es, qué falta y en qué orden?** El único que manda sobre el plan |
| 3 | `00_producto/REGISTRO_DE_DECISIONES.md` | **¿Por qué está hecho así?** Empieza por el final |

**No empieces por el código.** Este proyecto tiene 195 decisiones registradas
con su porqué; leer el código sin ellas es reconstruir a ciegas razonamientos
que ya están escritos.

> **Si encuentras un cuarto documento opinando sobre el plan, está mal.** Siete
> documentos compitiendo entre sí causaron dos desviaciones reales (D-063,
> D-118). Se fundieron en el Plan Maestro el 09-ago (D-126) y lo anterior vive
> en `_archivo/`, que **no manda sobre nada**.

---

## 2. Qué significan los códigos

Verás referencias como `D-102`, `H-09` o "hallazgo G" dentro del código, en los
mensajes de commit y en los documentos. **Son sistemas distintos:**

| Código | Qué es | Dónde vive |
|---|---|---|
| **D-001 … D-195** | **Decisiones.** El porqué de cada cosa, con lo que se descartó y por qué | `00_producto/REGISTRO_DE_DECISIONES.md` |
| **H-01 … H-13** | **Hallazgos** de la auditoría integral del 6 de agosto | `01_arquitectura/auditorias/AUDITORIA_INTEGRAL_2026-08-06.md` |
| **A … Z** | **Anotado en el camino** | `PLAN_MAESTRO`, sección 7 |
| **I-01 … I-14** | **Buzón de ideas**: lo que aún no tiene fase | `PLAN_MAESTRO`, sección 6 |
| **F3.7, 4.10…** | **Números de paso** del Plan Maestro | `PLAN_MAESTRO`, sección 5 |
| **Tramo A, D3.5.2…** | Trabajo de arquitectura multisede de julio | `01_arquitectura/auditorias/` |

> **Cuando el código cita un código, no lo inventes: búscalo.** Un comentario
> que dice `(D-097, D-102)` está señalando dónde está el razonamiento completo.
> Que una cita no tuviera respaldo fue exactamente el fallo de D-102, que el
> código citaba y el registro no tenía.

---

## 3. Qué documento manda sobre qué

**Tres documentos vivos, tres trabajos que no se pisan** (D-063, D-126).

| Documento | Responde | ¿Crece o se reemplaza? |
|---|---|---|
| **PLAN_MAESTRO** | ¿Qué es, qué falta y en qué orden? | Se actualiza al cerrar cada paso |
| **REGISTRO_DE_DECISIONES** | ¿Por qué es así? | **Solo crece.** Nunca se borra ni se resume una fila |
| **HANDOFF** | ¿Dónde quedamos hoy? | **Se reemplaza.** Cada uno sustituye al anterior |

**Y tres de apoyo, que no opinan sobre el plan:**

| Documento | Responde |
|---|---|
| `ESPECIFICACION_*` | ¿Cómo debe funcionar exactamente? Contrato de una tarea |
| `AUDITORIA_INTEGRAL_2026-08-06` | ¿Qué está mal hoy? Foto de un momento |
| `ADR/` | ¿Por qué la arquitectura es así? No se reescriben |

---

## 4. Cómo se trabaja aquí

> ### 👉 Las reglas están en **`00_producto/PLAN_MAESTRO.md`, apartado 8.**
>
> **Aquí no se copian, a propósito.** Hasta el 11-ago estaban escritas en seis
> sitios y ya decían cosas distintas: el Plan Maestro tenía 11 reglas y este
> README tenía 8, y a este le faltaba justo *"comparar línea por línea al
> reescribir una función"* — la que nació de tres fallos en un mismo día
> (D-119, D-122, D-123).
>
> Una regla copiada en seis sitios no está reforzada: **está a punto de
> contradecirse.** Es lo mismo que pasó con los siete planes (D-126).
> Corregido en **D-131**.

---

## 5. Estructura de carpetas

- `00_producto/` — **el Plan Maestro**, las decisiones y las especificaciones
- `01_arquitectura/` — modelo multisede, roles, suscripciones, ADR y auditorías
- `02_operacion/` — respaldo, restauración, **correo y dominio**, **el mapa
  técnico** (dónde está cada cosa y cómo se publica), procedimientos
- `03_referencias/` — benchmarking y fuentes externas
- `04_pruebas/` — criterios de salida y evidencias
- `HANDOFF/` — el punto de retomada (solo el vigente)
- `_archivo/` — **75 documentos históricos.** No mandan sobre nada; guardan el porqué

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
108. `HANDOFF/HANDOFF_SalonyMas_2026-08-08.md` (handoff del 08-ago, **reemplazado** por el del 09-ago)
109. `../supabase/migrations/20260809160000_numero_de_ticket_consecutivo.sql` (**numero de ticket consecutivo y ajustable**, tarea 2.6a, D-117)
110. `../supabase/sql/161_verify_numero_de_ticket.sql` (verificacion del consecutivo, con prueba de escritura en `ROLLBACK`)
111. `../test/numero_de_ticket_test.dart` (el consecutivo viaja intacto hasta la pantalla)
112. `../scripts/aplicar_sql.ps1` (**ejecuta un archivo SQL contra la base**, hermano de `respaldo_supabase.ps1`: codifica la contrasena igual que el, que es lo unico que funciona con la contrasena de este proyecto)
113. `../supabase/migrations/20260809180000_fotos_privadas_hasta_aprobar.sql` (**las fotos de trabajo nacen privadas y aprobarlas es lo que las publica**, accion A4, cierra H-09, D-119)
114. `../supabase/sql/162_verify_fotos_privadas.sql` (verificacion de los almacenes y de la coherencia entre aprobada y publicada)
115. `../lib/services/work_photo_storage.dart` (los dos almacenes y el movimiento entre ellos)
116. `../lib/services/storage_cleanup.dart` (**borrar archivos**: el anterior al reemplazar logo o portada, y el que el dueno elimina a mano)
117. `../supabase/migrations/20260809200000_negocio_de_prueba.sql` (**marcar un negocio como de prueba**, accion A5, D-120)
118. `../test/dinero_y_roles_test.dart` y `../lib/models/acciones_de_ticket.dart` (**primeras pruebas de dinero y roles**, accion A6, H-03, D-121)
119. `../supabase/sql/163_test_reglas_de_dinero.sql` (**las tres reglas de dinero contra la base real**, con `ROLLBACK`; hay que ejecutarlo a mano)
120. `_archivo/handoffs/HANDOFF_SalonyMas_2026-08-09.md` (handoff del 09-ago, **reemplazado**)
121. `00_producto/PLAN_MAESTRO.md` (**el documento rector unico**: vision, planes, precios, limites, los 16 modulos, 8 fases, buzon de ideas y hallazgos — reemplaza a siete documentos, D-126)
122. `_archivo/LEEME.md` (que hay en el archivo historico y por que se archivo cada cosa)
123. `_archivo/handoffs/HANDOFF_SalonyMas_2026-08-10.md` (handoff del 10-ago, **reemplazado**)
124. `02_operacion/CORREO_Y_DOMINIO.md` (**como esta montado el envio de correo**: dominio, los 4 registros DNS, remitente, por que el rastreo esta apagado, y que mirar cuando falle — D-128, D-130)
125. `02_operacion/MAPA_TECNICO.md` (**donde esta cada cosa y como se opera**: el proyecto de Supabase y la trampa de su nombre, los tres caminos de publicacion, la CLI, los guiones, que cubren las pruebas y que NO, y las diez trampas que ya mordieron — D-131)
126. `../supabase/migrations/20260811100000_un_estilista_una_cuenta_activa.sql` (**un estilista del catalogo, una sola cuenta ACTIVA**, hallazgo R — cierra los tres caminos y deja un indice unico como red; **solo cuentas activas a proposito**, para que cambiar de correo siga siendo posible — D-132)
127. `../supabase/sql/165_verify_un_estilista_una_cuenta.sql` (verificacion del candado: 7 controles y una prueba de escritura real en `ROLLBACK` que comprueba **las dos mitades** — que rechaza la segunda cuenta activa y que si acepta una suspendida)
128. `_archivo/handoffs/HANDOFF_SalonyMas_2026-08-11.md` (handoff del 11-ago, **reemplazado**)
129. `../scripts/restaurar_ensayo.ps1` y `../supabase/sql/166_censo_para_comparar.sql` (**la restauracion de ensayo del paso 2.2**: el guion que restaura en el proyecto de ensayo con dos candados contra tocar produccion, y el censo de 37 cifras que se ejecuta contra las dos bases y se compara — D-134)
130. `HANDOFF/HANDOFF_SalonyMas_2026-08-12.md` (**handoff vigente**, con el prompt exacto para retomar)
131. `../supabase/migrations/20260812100000_precios_limites_y_precio_por_cliente.sql` y `../supabase/sql/167_verify_precios_y_limites.sql` (**pasos 3.5 y 3.6**: precios en pesos, las capacidades de sedes y cuentas de equipo con sus topes **haciendose cumplir**, y el precio o descuento pactado con cada cliente — D-136)

> **A partir de aquí (D-138) las entradas agrupan en una sola línea la migración, su script de verificación y los archivos Flutter de una misma decisión**, en vez de darle una línea a cada archivo como antes: son 58 decisiones más y mantener el 1-a-1 habría triplicado esta lista sin añadir información nueva. Las decisiones sin ningún archivo propio (D-137, D-142, D-149, D-152, D-155, D-180 — reglas de trabajo, blindajes sobre una función ya citada, o correcciones del mismo día sin archivo nuevo) no tienen línea aparte: están en `REGISTRO_DE_DECISIONES.md`, que es quien de verdad manda sobre el porqué.

132. `../supabase/migrations/20260816100000_filtro_aceptacion_registro.sql`, `../supabase/sql/168_test_filtro_aceptacion.sql` y `../lib/pages/tenant_approval_status_page.dart` (**paso 3.7: Filtro de Aceptación** — "nadie entra solo" (D-125), la prueba gratis arranca al aprobar — D-138)
133. `_archivo/handoffs/HANDOFF_SalonyMas_2026-08-16.md` (handoff del 16-ago, reemplazado)
134. `../supabase/migrations/20260816170000_blindaje_rls_tenants_y_guards_aprobacion.sql` y `../supabase/sql/169_test_blindaje_rls_tenants.sql` (blindaje RLS en tenants y guardas de estado en `platform_approve_tenant`/`platform_reject_tenant` — D-139)
135. `../lib/pages/public_plans_page.dart` (**paso 3.8: pantalla pública de planes y precios** en COP, responsiva, con comparativa y FAQ — D-140)
136. `../lib/services/epayco_checkout_service.dart`, `../supabase/migrations/20260817100000_epayco_suscripciones_y_gracia.sql` y `../supabase/sql/170_test_epayco_transicion_y_gracia.sql` (**pasos 3.9/3.10: integración ePayco** — webhook en Edge Function, idempotencia, 5 días de gracia y reactivación — D-141, blindado en fail-closed el mismo día por D-142)
137. `_archivo/handoffs/HANDOFF_SalonyMas_2026-08-17_bloque_D143.md` (handoff del bloque D-143, reemplazado)
138. `../lib/pages/terms_and_privacy_page.dart` (**paso 3.3: Términos de Servicio y Política de Privacidad** — Ley 1581/Habeas Data, checkbox obligatorio en registro — D-144)
139. `_archivo/handoffs/HANDOFF_SalonyMas_2026-08-17_D144.md` (handoff de D-144, reemplazado)
140. `../supabase/migrations/20260817120000_alertas_vencimiento_suscripcion.sql` y `../supabase/sql/171_test_alertas_suscripcion_y_suspension.sql` (**paso 3.11: avisos de vencimiento** por Resend a 10/5/3 días, cuenta regresiva de gracia y auto-suspensión — D-143)
141. `../supabase/migrations/20260817140000_programar_alertas_suscripcion_diarias.sql` y `../supabase/sql/172_verify_disparador_alertas_suscripcion.sql` (cierre real del paso 3.11: disparador diario con `pg_cron`+`pg_net`, secreto `CRON_SECRET` en Supabase Vault — D-145)
142. `_archivo/handoffs/HANDOFF_SalonyMas_2026-08-17_D145.md` (handoff de D-145, reemplazado)
143. `../docs/02_operacion/PLANTILLAS_CORREO_AUTH.md` (**paso 3.13: las 6 plantillas de correo de Supabase Auth traducidas**, con marca de Salón y Más — hallazgo W, D-146)
144. `../supabase/migrations/20260817170000_tablero_agenda_conteos_y_lista.sql` y `../supabase/sql/173_test_tablero_agenda_conteos_y_lista.sql` (**paso 4.2: RPC del Tablero de Agenda** — `get_ticket_board_counts_v2`/`get_ticket_board_list_v2`, intervalos de 15 min en hora Colombia — D-147)
145. `../lib/models/ticket_board.dart` y `../lib/services/agenda_board_service.dart` (**paso 4.3: frontend del Tablero de Agenda** — vistas Día/Semana/Mes, lista Nivel 2 y WhatsApp directo — D-148; el mismo día se corrigieron el atenuado de días pasados y el "+" sobrante del teléfono, D-149)
146. `_archivo/handoffs/HANDOFF_SalonyMas_2026-08-17_D148.md` (handoff de D-148/D-149, reemplazado)
147. `../lib/models/sale_numbering.dart`, `../supabase/migrations/20260817210000_numero_de_venta_por_sede.sql` y `../supabase/sql/174_test_numero_de_venta_por_sede.sql` (**paso 4.4: número de venta consecutivo e inmutable por sede**, con soporte para Resolución DIAN — hallazgo P, D-150; blindado contra reaperturas el mismo día, D-151)
148. `_archivo/handoffs/HANDOFF_SalonyMas_2026-08-17_D150.md` (handoff de D-150/D-151, reemplazado)
149. `../supabase/migrations/20260818140000_clientes_metricas_retorno_y_valor.sql` y `../supabase/sql/175_test_clientes_metricas_retorno_y_valor.sql` (**paso 4.6: RFM, cadencia de visitas y Nivel 3 de Clientes** — D-153; el paso 4.5 de pulido de Tickets Nivel 2/3, buscador universal y StatusPill fue el mismo día, sin archivo nuevo — D-152)
150. `../lib/models/branch_report_v3.dart`, `../lib/services/branch_reports_service.dart`, `../supabase/migrations/20260818160000_reportes_v3_periodos_y_metodos.sql` y `../supabase/sql/176_test_reportes_v3_periodos_y_metodos.sql` (**paso 4.7: Reportes V3** por período, métodos de pago, arqueo de caja y comparación — D-154)
151. `../lib/services/branch_sale_numbering_service.dart`, `../supabase/migrations/20260818180000_galeria_con_consecutivo_y_filtros.sql` y `../supabase/sql/177_test_galeria_con_consecutivo_y_filtros.sql` (**paso 4.9: galería con consecutivo #0000701**, filtros por cliente/estilista y configuración de numeración DIAN — D-156; el paso 4.8 de pulido de Inventario/Compras/Gastos fue el mismo día, sin archivo nuevo — D-155)
152. `_archivo/handoffs/HANDOFF_SalonyMas_2026-08-18.md` (handoff del 18-ago, reemplazado)
153. `../lib/main.dart` (**paso 4.10: rediseño integral de navegación** — Header blanco minimalista y Sidebar categorizado estilo WeiBook/Fresha — hallazgo D, D-157)
154. `_archivo/handoffs/HANDOFF_SalonyMas_2026-08-22.md` (handoff del 22-ago, reemplazado)
155. `../supabase/migrations/20260822180000_platform_update_tenant_pricing.sql` y `../supabase/sql/178_test_platform_update_tenant_pricing.sql` (**paso 4.11, cierra la Fase 4**: rediseño del Panel de Plataforma, Ficha Nivel 3 de negocio, selector interactivo de planes en checkout y precio personalizado en caliente con historial — D-158)
156. `../lib/services/epayco_modal_launcher.dart` (SDK oficial `checkout.js` de ePayco integrado, la pasarela abre en modal sin salir de la app)
157. `../supabase/migrations/20260823120000_epayco_activacion_robusta.sql`, `20260823130000_epayco_validar_precio_por_plan.sql` y `../supabase/sql/179_test_epayco_activacion_robusta.sql` (**auditoría del 23-ago corrige una regresión crítica**: el monto se valida contra el precio real del plan, y `tenantId`/monto dejan de estar controlados por el cliente — D-159)
158. `_archivo/handoffs/HANDOFF_SalonyMas_2026-08-23.md` (handoff de D-159, reemplazado)
159. `../supabase/migrations/20260823150000_ciclo_facturacion_ancla_y_plan_pactado.sql` y `../supabase/sql/180_test_ciclo_facturacion_ancla.sql` (ciclos de 30 días anclados al primer pago, y plan/precio pactado del dueño con precedencia absoluta — D-160)
160. `_archivo/handoffs/HANDOFF_SalonyMas_2026-08-23_D160.md` (handoff de D-160, reemplazado)
161. `../lib/models/tenant_subscription_history_entry.dart`, `../supabase/migrations/20260823160000_contacto_titular_y_historial_completo.sql` y `../supabase/sql/181_test_contacto_y_historial.sql` (píldora de plan activo, edición del nombre de contacto titular e historial de suscripción — D-161)
162. `_archivo/handoffs/HANDOFF_SalonyMas_2026-08-23_D161.md` (handoff de D-161, reemplazado)
163. `../supabase/migrations/20260823170000_redes_sociales_y_equipo_real.sql` y `../supabase/sql/182_test_redes_y_equipo_real.sql` (el salón edita Instagram/Facebook desde Configuración, y el Panel de Plataforma muestra capacidad operativa real en vivo en vez del formulario estático — D-162)
164. `_archivo/handoffs/HANDOFF_SalonyMas_2026-08-23_D162.md` (handoff de D-162, reemplazado)
165. `../supabase/migrations/20260827100000_abonos_en_citas_activas.sql` y `../supabase/sql/183_test_abonos_en_citas_activas.sql` (navegación directa de Agenda a la Ficha Completa, píldora de estado interactiva y abonos habilitados en citas activas — D-163)
166. `_archivo/handoffs/HANDOFF_SalonyMas_2026-08-27_D163.md` (handoff de D-163, reemplazado)
167. `../lib/pages/public_salon_page.dart`, `../supabase/migrations/20260827140000_slugs_publicos_y_perfil_comercial.sql` y `../supabase/sql/184_test_slugs_publicos.sql` (**Fase 5, Bloque 1: el enlace propio de cada negocio**, `salonymas.com/<slug>` — D-164)
168. `_archivo/handoffs/HANDOFF_SalonyMas_2026-08-27_D164.md` (handoff de D-164, reemplazado)
169. `../lib/models/public_salon_photo_item.dart`, `../supabase/migrations/20260827160000_perfil_publico_completo.sql` y `../supabase/sql/185_test_perfil_publico_completo.sql` (**paso 5.5: la página pública completa del negocio** — servicios, portafolio con visor de fotos, equipo, reseñas y botón "Agendar Cita" — D-165)
170. `_archivo/handoffs/HANDOFF_SalonyMas_2026-08-28_D165.md` (handoff de D-165, reemplazado)
171. `../supabase/migrations/20260828180000_direccion_sede_y_ajustes_reserva.sql` y `../supabase/sql/186_test_direccion_sede_y_contacto.sql` (dirección física editable con Google Maps, y reserva pública en dos pasos con "Cualquiera disponible" — D-166)
172. `_archivo/handoffs/HANDOFF_SalonyMas_2026-08-28_D166.md` (handoff de D-166, reemplazado)
173. `../lib/pages/client_portal_page.dart`, `../supabase/migrations/20260829120000_habeas_data_fotos_y_portal_cliente.sql` y `../supabase/sql/187_test_habeas_data_y_portal_cliente.sql` (**cierra la Fase 5**: consentimiento Ley 1581 antes de publicar una foto, y portal seguro "Mis citas y fotos" con PIN — D-167)
174. `_archivo/handoffs/HANDOFF_SalonyMas_2026-08-29_D167.md` (handoff de D-167, reemplazado)
175. `../lib/widgets/tu_negocio_en_palabras_card.dart` (**paso 6.1: "Tu negocio en palabras"** — el Dashboard contado en un párrafo, sin IA — D-168)
176. `_archivo/handoffs/HANDOFF_SalonyMas_2026-08-29_D168.md` (handoff de D-168, reemplazado)
177. `../lib/widgets/publication_studio_dialog.dart`, `../supabase/migrations/20260829140000_estudio_de_publicacion.sql` y `../supabase/sql/188_test_estudio_de_publicacion.sql` (**paso 6.2: Estudio de publicación**, versión determinista sin IA externa — D-169)
178. `_archivo/handoffs/HANDOFF_SalonyMas_2026-08-29_D169.md` (handoff de D-169, reemplazado)
179. `../lib/models/review_reply_draft.dart`, `../supabase/migrations/20260829160000_respuestas_a_resenas.sql` y `../supabase/sql/189_test_respuestas_a_resenas.sql` (**paso 6.3: respuestas a reseñas asistidas**, versión determinista sin IA externa — D-170)
180. `_archivo/handoffs/HANDOFF_SalonyMas_2026-08-29_D170.md` (handoff de D-170, reemplazado)
181. `../lib/pages/blog_page.dart`, `../supabase/migrations/20260829180000_blog_de_articulos.sql` y `../supabase/sql/190_test_blog_de_articulos.sql` (**paso 6.6: blog de artículos**, por cada salón, sin url propia por artículo todavía — D-171)
182. `_archivo/handoffs/HANDOFF_SalonyMas_2026-08-29_D171.md` (handoff de D-171, reemplazado)
183. `../lib/models/platform_saas_metrics.dart`, `../supabase/migrations/20260829200000_panel_plataforma_metricas_y_overrides.sql` y `../supabase/sql/191_test_panel_plataforma_fase7.sql` (**Fase 7, pasos 7.1/7.2/7.4**: cabecera ejecutiva del SaaS, visión 360° financiera por salón y gestión de excepciones de límites — D-172)
184. `_archivo/handoffs/HANDOFF_SalonyMas_2026-08-29_D172.md` (handoff de D-172, reemplazado)
185. `../lib/pages/public_partner_page.dart`, `../supabase/migrations/20260830100000_sistema_partners_y_referidos.sql` y `../supabase/sql/192_test_sistema_partners_fase7.sql` (**paso 7.3, cierra la Fase 7**: sistema de Partners y Referidos, comisión configurable y unificación visual del Panel de Plataforma — D-173)
186. `_archivo/handoffs/HANDOFF_SalonyMas_2026-08-30_D173.md` (handoff de D-173, reemplazado)
187. `../supabase/migrations/20260830120000_alinear_permiso_storage_h11.sql` y `../supabase/sql/193_test_alinear_permiso_storage_h11.sql` (**paso 8.3, hallazgo H-11**: se revoca a `public`/`anon` el permiso suelto de subir fotos de trabajo — D-174)
188. `../supabase/migrations/20260830140000_regla_dinero_entero_h08.sql` y `../supabase/sql/194_test_regla_dinero_entero_h08.sql` (**paso 8.2, hallazgo H-08**: columnas de dinero unificadas en pesos colombianos enteros, con 14 candados `CHECK` — D-175)
189. `../supabase/migrations/20260830160000_purga_funciones_huerfanas_h05.sql` y `../supabase/sql/195_test_purga_funciones_huerfanas_h05.sql` (**paso 8.1, hallazgo H-05**: purga de 30 funciones huérfanas heredadas de julio, 6 internas blindadas con `COMMENT` — D-176)
190. `../supabase/config.toml` (**paso 8.4, hallazgo U**: `verify_jwt = true` en las Edge Functions con sesión de usuario, `false` solo en las que llama ePayco servidor-a-servidor — D-177)
191. `../lib/pages/login_page.dart` y `../lib/pages/register_page.dart` (**paso 8.5, hallazgo S**: la pantalla de acceso deja de hablarle solo al dueño del negocio — D-178)
192. `../lib/models/user_branch_access.dart`, `../supabase/migrations/20260830170000_gestion_sedes_usuarios_equipo_hallazgo_v.sql` y `../supabase/sql/196_test_gestion_sedes_usuarios_hallazgo_v.sql` (**paso 8.6, hallazgo V**: gestión de sedes para usuarios de equipo multi-sede — D-179)
193. `_archivo/handoffs/HANDOFF_SalonyMas_2026-08-30_D179.md` (handoff de los pasos 8.1 a 8.6, reemplazado)
194. `../supabase/functions/verify-epayco-transaction/index.ts` (**paso 8.9, cierra TL-01**: exige sesión, compara `x_cust_id_cliente` y saca el negocio de las membresías de quien llama, no del payload — D-181)
195. `../supabase/migrations/20260901120000_intenciones_de_pago_epayco_tl02.sql` y `../supabase/sql/197_test_intenciones_pago_epayco_tl02.sql` (**paso 8.10, cierra TL-02**: `subscription_payment_intents` — el negocio y el plan salen de la intención que el servidor escribe antes de mandar a pagar — D-182)
196. `_archivo/handoffs/HANDOFF_SalonyMas_2026-09-01_D182.md` (handoff de D-182, reemplazado)
197. `../supabase/migrations/20260901140000_portal_clienta_sin_enumeracion_tl04_tl05.sql` y `../supabase/sql/198_test_portal_clienta_sin_enumeracion_tl04_tl05.sql` (**paso 8.11, cierra TL-04 y TL-05**: un solo mensaje en el portal de la clienta, sin enumeración de celulares — D-183)
198. `../lib/models/tenant_entitlements.dart`, `../lib/pages/plan_locked_page.dart` y `../lib/services/entitlements_service.dart` (**paso 8.13, cierra TL-19**: la interfaz consulta `get_my_entitlements()` y el módulo se ve con candado en vez de reventar en crudo — D-184)
199. `../supabase/migrations/20260901160000_pin_portal_con_bcrypt_tl06.sql` y `../supabase/sql/199_test_pin_portal_con_bcrypt_tl06.sql` (**paso 8.12, cierra TL-06**: el PIN del portal pasa de SHA-256 a bcrypt con migración al vuelo, y el bloqueo pasa a escalonado — D-185)
200. `../lib/models/onboarding_progress.dart`, `../lib/widgets/primeros_pasos_card.dart`, `../supabase/migrations/20260901180000_onboarding_primeros_pasos.sql` y `../supabase/sql/200_test_onboarding_primeros_pasos.sql` (**paso 8.8, el broche de oro**: "Primeros pasos" del Dashboard pasa de texto estático a checklist real — D-186)
201. `../lib/widgets/candado_de_plan.dart` (**paso 8.14, cierra la auditoría de 4 revisiones**: candado por acción, no por módulo, en Fotos de trabajos y Reseñas — D-187)
202. `../01_arquitectura/auditorias/AUDITORIA_4_REVISIONES_2026-09-01.md` (**el expediente de verificación**: cuatro revisiones de Antigravity contrastadas contra el código real, hallazgos C-01 a C-05 y TL-01 a TL-20)
203. `../supabase/migrations/20260901200000_plan_unico_todo_incluido_d188.sql` y `../supabase/sql/201_test_un_solo_plan_por_sede.sql` (**se retira la escalera de tres planes**: un solo plan "Todo Incluido" cobrado por sede activa — D-188)
204. `../supabase/migrations/20260902100000_precio_150k_y_equipo_de_diez_d189.sql` (ajuste comercial de D-188: lista $150.000 por sede, equipo de 10 —el tope va en 9, el dueño no cuenta, D-136—, y el descuento pionero sale de la web para negociarse uno a uno — D-189)
205. `../supabase/migrations/20260902120000_suscripcion_por_sede_etapa2_d190.sql` y `../supabase/sql/202_test_suscripcion_por_sede_etapa2.sql` (**etapa 2 de D-188, paso 8.15**: `branch_subscriptions`, cada sede con su propio estado, período y precio — D-190)
206. `../supabase/migrations/20260902140000_cobro_por_sede_etapa3a_d191.sql` y `../supabase/sql/203_test_cobro_por_sede_etapa3a.sql` (**etapa 3a, paso 8.16**: `branch_id` en las intenciones de pago y `beautyos_calcular_cargo_sede` con prorrateo — D-191)
207. `_archivo/handoffs/HANDOFF_SalonyMas_2026-09-02_D191.md` (handoff del bloque D-188 a D-194, reemplazado)
208. `../supabase/migrations/20260902160000_pago_de_sede_etapa3b_d192.sql` y `../supabase/sql/204_test_pago_de_sede_etapa3b.sql` (**etapa 3b, servidor**: `beautyos_procesar_pago_de_sede` y las dos Edge Functions con `branchId` — D-192)
209. `../lib/models/branch_subscription.dart`, `../lib/services/branch_subscriptions_service.dart` y `../lib/widgets/sedes_suscripcion_card.dart` (**cierra la etapa 3b**: pantalla de sedes con su estado y botón de pago, y limpieza de `epayco_checkout_service.dart`, que enseñaba los tres planes retirados — D-193)
210. `../supabase/migrations/20260902180000_reportes_consolidados_multisede_d194.sql` y `../supabase/sql/205_test_reportes_consolidados_multisede.sql` (reportes consolidados de todas las sedes: `get_tenant_reports_v3` llama a la de una sede y suma, en vez de duplicar sus 250 líneas — D-194)
211. `../lib/pages/tickets_page.dart` y `../lib/pages/agenda_page.dart` (**Bloque 1 "Velocidad Operativa de Mostrador"**: cita express reutilizando "Cualquiera disponible", cobro directo desde la tarjeta de Agenda, y WhatsApp con mensaje pre-armado — D-195)
212. `_archivo/handoffs/HANDOFF_SalonyMas_2026-09-02_D195.md` (handoff de D-195, reemplazado)
213. `../supabase/migrations/20260902200000_tope_equipo_y_alertas_por_sede_d196.sql`, `../supabase/sql/206_test_tope_equipo_y_alertas_por_sede.sql` y `../supabase/functions/send-subscription-expiry-alerts/index.ts` (**Bloque 2 "Pulido Multi-Sede y Alertas de Suscripción"**: tope de equipo proporcional `9 * sedes_activas` y alertas por sede agrupadas en un solo correo por negocio — D-196)
214. `_archivo/handoffs/HANDOFF_SalonyMas_2026-09-02_D196.md` (handoff de D-196, reemplazado)
215. `../.github/workflows/ci.yml` (**Bloque 3 "Pipeline de Integración Continua"**: GitHub Actions corriendo `flutter analyze` y `flutter test` en cada push a main y pull request, cierra TL-07 — D-197)
216. `_archivo/handoffs/HANDOFF_SalonyMas_2026-09-02_D197.md` (handoff de D-197, reemplazado)
217. `../lib/models/ticket_board.dart` y 13 archivos migrados (**Bloque 4 "Función canónica de moneda"**: `formatCOP` único, arreglado para números negativos `-$100`, eliminando 13 copias dispersas de `_formatCop` y `formatMoney`, cierra TL-12 — D-198)
218. `_archivo/handoffs/HANDOFF_SalonyMas_2026-09-02_D198.md` (handoff de D-198, reemplazado)
219. `../lib/services/image_compression.dart`, los 5 servicios de subida, `../lib/services/tickets_service.dart` y `../lib/pages/tickets_page.dart` (**Bloque 5 "Rendimiento, Resiliencia y Optimización de Carga"**: fuera el `catch (_)` ciego y su respaldo — TL-16 —, compresión de imágenes a 1920 px y calidad 85 en un solo sitio — TL-20 — y la lista de Tickets por tandas de 10 con botón "Ver más" — TL-09 — D-199)
220. `../test/salto_agenda_tickets_test.dart`, `../test/compresion_de_imagenes_test.dart` y `../test/tickets_rendimiento_y_resiliencia_test.dart` (**12 pruebas guardianas** del Bloque 5, incluida la de C-03 que blinda la adyacencia Agenda→Tickets de la que depende el salto de D-163 — D-199)
221. `_archivo/handoffs/HANDOFF_SalonyMas_2026-09-02_D199.md` (handoff de D-199, reemplazado)
222. `../lib/models/aviso_de_pago.dart`, `../lib/main.dart` y `../lib/pages/tickets_page.dart` (**Bloque 6 "Velocidad de Caja y Feedback de Pasarela"**: atajo "Pagar saldo exacto" al cobrar — UX-07 —, el retorno de ePayco deja de ser mudo sin convertir un fallo del atajo en un pago fallido, y `TicketRow` baja de ocho callbacks obligatorios a tres — C-02 — D-200)
223. `../test/aviso_de_pago_epayco_test.dart` y `../test/saldo_exacto_en_cobro_test.dart` (**20 pruebas nuevas** del Bloque 6; a diferencia de las de D-199 ejercitan el comportamiento, no leen el código fuente — D-200)
224. `_archivo/handoffs/HANDOFF_SalonyMas_2026-09-02_D200.md` (handoff de D-200, reemplazado)
225. `../lib/main.dart` (**Bloque 7 "Ciclo de vida reactivo de pestañas"**: `pilaDeModulos` con carga perezosa y contador de visitas, el embudo `_irAIndice` como único camino de navegación, y `BeautyModule.recargaAlEntrar` — **cierra TL-10 y con él el Hallazgo Q**, abierto desde el 09-ago — D-201)
226. `../lib/pages/complete_tenant_setup_page.dart` (**C-05**: fuera los desplegables "Sedes" y "Equipo" del registro, huérfanos desde D-162 — verificado antes que ninguna pantalla los muestra — D-201)
227. `../test/ciclo_de_vida_de_pestanas_test.dart` (**8 pruebas que cuentan montajes reales** de `initState` en vez de leer el código: lo no abierto no se monta, volver a entrar remonta, y la red que impide la pantalla en blanco — D-201)
228. `_archivo/handoffs/HANDOFF_SalonyMas_2026-09-03_D201.md` (handoff de D-201, reemplazado)
229. `../web/_headers` y `../test/web_headers_security_test.dart` (**Bloque 8 "Blindaje de cabeceras web de seguridad"**: `X-Frame-Options: DENY`, `Content-Security-Policy: frame-ancestors 'none'` y `Permissions-Policy` apagando cámara, micrófono y ubicación — cierra la parte de **TL-03** que no necesita el panel de Cloudflare; **HSTS queda como paso 8.25, pendiente del propietario** — D-202)
230. `_archivo/handoffs/HANDOFF_SalonyMas_2026-09-04_D202.md` (handoff de D-202, reemplazado)
231. `../lib/services/tickets_service.dart` y `../test/contrato_rpc_fechas_test.dart` (🔴 **hotfix de producción**: la pantalla de Tickets caía con `Rango de fechas invalido.` porque `get_ticket_board_list_v2` rechaza fechas nulas **desde que existe** y un `catch (_)` lo tapaba desde el 17-ago. **Corrige a D-199**, y la prueba nueva compara el Dart con el SQL — la que lo habría cazado — D-203)
232. `_archivo/handoffs/HANDOFF_SalonyMas_2026-09-04_D203.md` (handoff de D-203, reemplazado)
233. `../lib/services/tickets_service.dart` y `../test/historial_de_tickets_test.dart` (**paso 8.27**: la lista de Tickets vuelve a `get_ticket_board_list_v2` con rango de fechas y se reordena en el cliente — recupera el chip `VTA-0000045`, el botón de WhatsApp y la búsqueda por teléfono tras 2,5 semanas invisibles. El saldo cambia de nombre entre las dos RPC (`pending_balance` / `balance_amount`) y el orden viene invertido: las dos diferencias fallan en silencio — D-204)
234. `_archivo/handoffs/HANDOFF_SalonyMas_2026-09-04_D204.md` (handoff de D-204, reemplazado)
235. `../lib/pages/dashboard_page.dart`, `../lib/main.dart` y `../test/dashboard_page_test.dart` (**paso 8.28**: el Dashboard hace caso a la píldora de sede en vez de abrir siempre en consolidado, y su desplegable de sedes se sustituye por el botón de dos posiciones de Reportes — `ControlesDelDashboard` y `sedesDelDashboard` quedan públicos para poder probarlos — D-205)
236. `_archivo/handoffs/HANDOFF_SalonyMas_2026-09-04_D205.md` (handoff de D-205, reemplazado)
237. 9 páginas de `../lib/pages/` y `../test/sin_jerga_tecnica_test.dart` (**paso 8.29**: fuera las tarjetas fijas de cabecera del prototipo; las tres que llevaban reglas de permisos pasan al subtítulo en vez de borrarse, y la mención legal a Supabase en Términos se conserva a propósito — D-206)
238. `HANDOFF/HANDOFF_SalonyMas_2026-09-04_D206.md` (**handoff vigente**, con el prompt exacto para retomar)

Los ADR dentro de `01_arquitectura/ADR/` explican por qué se tomó cada decisión
estructural. No se reescriben para ocultar el pasado: una decisión futura la
reemplaza mediante otro ADR.

## Regla de actualización

Una modificación de arquitectura, alcance, rol, plan o flujo exige actualizar el
plan de lanzamiento, el registro de decisiones y el documento especializado
correspondiente **en el mismo cambio**.

Los respaldos, capturas y exportaciones se conservan además en la carpeta
personal de OneDrive del proyecto.
