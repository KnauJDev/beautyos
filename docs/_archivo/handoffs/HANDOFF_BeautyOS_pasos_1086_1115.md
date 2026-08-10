# HANDOFF BeautyOS — pasos 1086–1115

**Proyecto:** BeautyOS  
**Bloque documentado:** pasos 1086 al 1115  
**Fecha de cierre:** 20 de julio de 2026  
**Repositorio:** `https://github.com/KnauJDev/beautyos.git`  
**Ruta local:** `C:\Proyectos\BeautyOS`  
**Rama:** `main`  
**Commit de implementación:** `923a32c - Preparar estructura multisede del Tramo A`  
**Estado remoto:** no actualizado; el propietario todavía no autorizó `push`

## 1. Resumen ejecutivo

Este bloque corrigió la pérdida de rumbo percibida después del paso 1085 y convirtió la visión del producto en una arquitectura y un plan de construcción permanentes. BeautyOS quedó definido como un SaaS multi-tenant y multisede para centros de belleza, con separación expresa entre la plataforma, cada negocio y cada sede.

Se cerró el Tramo 0 mediante una auditoría del proyecto vivo, un respaldo externo completo y una restauración comprobada. A continuación se construyó el Tramo A como migración aditiva: sedes, membresías, catálogos por sede y stock por sede. La migración se probó dos veces sobre una restauración local, se sometió a pruebas negativas de aislamiento y se revirtió de manera controlada sin alterar los datos anteriores.

No se aplicó el Tramo A al proyecto Supabase de producción y no se publicó ningún commit en GitHub.

## 2. Decisiones de producto consolidadas — pasos 1086–1093

**1086.** Se reafirmó la visión: BeautyOS será una SaaS para peluquerías, barberías, spas de uñas y centros de estética, comercializada mediante mensualidad.

**1087.** Se definieron tres niveles de producto: Básico, Business y Profesional, con capacidades crecientes de agenda, finanzas/inventario y contenido/redes sociales.

**1088.** Se separaron los roles plataforma y tenant. El propietario de BeautyOS no es el mismo rol que el dueño de un centro. Los roles operativos previstos son tenant owner, administración, asistencia, estilista y cliente.

**1089.** Se aprobó soporte multisede desde la arquitectura inicial. Un tenant podrá tener una o varias sedes sin duplicar el negocio ni mezclar su información con otros tenants.

**1090.** Se definió que la compensación de profesionales será configurable: salario fijo, porcentaje o valor fijo por servicio, preservando siempre el valor aplicado históricamente.

**1091.** Se acordó que la reserva del cliente debe tener poca fricción y disponibilidad real. La identidad del cliente se apoyará inicialmente en celular normalizado y podrá incorporar documento sin fusionar duplicados automáticamente.

**1092.** Se decidió preparar cobro recurrente de la SaaS, planes y entitlements desde la arquitectura, manteniendo los pagos de suscripción separados de la caja de cada tenant.

**1093.** Se mantuvo el benchmarking de experiencias como Fresha como referencia, sin copiar su interfaz. Reserva pública, WhatsApp, web y Android se construirán por fases sobre el mismo núcleo seguro.

## 3. Fuente canónica y gobierno — pasos 1094–1097

**1094.** Se creó el Expediente técnico y Plan Maestro como documento rector. Consolida los pasos 001–1085, el alcance, las fases, riesgos, prioridades y criterios de éxito.

**1095.** Se creó `AGENTS.md` con instrucciones permanentes: seguridad, RLS/RPC, trazabilidad financiera, documentación, pruebas, no tocar producción sin autorización y mantener pausadas las alertas operativas.

**1096.** Se documentaron el modelo multisede, roles, suscripciones, migración por tramos y cuatro ADR fundacionales. Markdown versionado quedó establecido como fuente canónica; Word/PDF son copias de lectura.

**1097.** Se definieron puertas de salida por fase. Ninguna pantalla visual permite declarar terminada una capacidad sin pruebas de aislamiento, integridad, seguridad, conservación y reversión.

## 4. Tramo 0 — auditoría, respaldo y restauración — pasos 1098–1103

**1098.** Se creó y ejecutó la auditoría repetible `supabase/sql/103_tramo_0_audit_multisite_baseline.sql` sobre el proyecto vivo.

**1099.** La línea base registró 24 tablas públicas, 54 funciones, 12 tickets, 13 servicios asignados, pagos vigentes/anulados, comisiones e inventario. Los 17 controles de integridad no reportaron violaciones.

**1100.** Se documentó el procedimiento seguro de respaldo y se creó `scripts/crear_respaldo_supabase.ps1`, que solicita la conexión y contraseña sin guardarlas en el repositorio.

**1101.** Se instaló y preparó Docker Desktop, Node.js/Supabase CLI y el entorno local necesario. Node.js no requiere cuenta. La cuenta Docker solo sirve al servicio Docker y no forma parte del código BeautyOS.

**1102.** Se generaron `roles.sql`, `schema.sql` y `data.sql` fuera de Git en OneDrive. El respaldo fue verificado y no contiene credenciales añadidas por el proyecto.

**1103.** Se restauró el esquema y la información pública en PostgreSQL 17.6 dentro de un contenedor local desechable. Los conteos y totales coincidieron con la línea base, cerrando el Tramo 0.

## 5. Tramo A — estructura aditiva — pasos 1104–1109

**1104.** Supabase CLI creó la migración administrada `20260720090817_tramo_a_estructura_multisede.sql`.

**1105.** Se añadieron siete tablas: `branches`, `tenant_memberships`, `branch_memberships`, `branch_services`, `branch_stylists`, `branch_stylist_services` y `branch_products`.

**1106.** Se implementaron claves compuestas con `tenant_id`, restricciones, índices y vigencias para impedir relaciones entre negocios o sedes incompatibles.

**1107.** Se creó una Sede principal por tenant y se copiaron, sin retirar los originales, las relaciones de usuarios, servicios, estilistas, capacidades y productos.

**1108.** Las siete tablas quedaron con RLS habilitada y acceso denegado por defecto a `anon` y `authenticated`. Solo `service_role` posee acceso directo; las políticas y RPC por sede llegarán juntas en el Tramo C.

**1109.** El helper de `updated_at` quedó en el esquema privado como `private.beautyos_set_updated_at()`, con permisos revocados a clientes.

## 6. Verificación, aislamiento y reversión — pasos 1110–1114

**1110.** `104_verify_tramo_a_multisite.sql` comprobó correspondencia exacta: 1 sede, 2 membresías tenant, 2 membresías de sede, 4 servicios, 2 estilistas, 4 capacidades y 4 productos.

**1111.** `105_test_tramo_a_tenant_isolation.sql` intentó cruzar un servicio y una membresía con otro tenant, además de insertar un rol inválido. PostgreSQL bloqueó los tres casos y la prueba terminó con rollback.

**1112.** Se conservaron 12 tickets, 13 servicios de ticket, $250.000 en pagos vigentes, $115.000 anulados, $100.000 en comisiones vigentes, $36.000 anuladas y 2.530 unidades de stock.

**1113.** `106_rollback_tramo_a_test_only.sql` fue bloqueado sin la autorización especial de ensayo. Con autorización explícita retiró solo el Tramo A y dejó intacta la base anterior.

**1114.** La migración se volvió a aplicar después de la reversión. La verificación y las pruebas negativas pasaron por segunda vez. Las RPC heredadas de tickets, clientes, agenda, servicios, productos y usuarios continuaron respondiendo.

## 7. Cierre de calidad — paso 1115

**1115.** Se ejecutaron las comprobaciones finales:

- `flutter analyze --no-pub`: sin problemas;
- `flutter test --no-pub`: todas las pruebas pasaron;
- `git diff --check`: sin errores;
- búsqueda de secretos en los archivos nuevos: sin credenciales reales;
- contenedor de ensayo eliminado al terminar;
- evidencia técnica actualizada;
- commit local creado: `923a32c`.

## 8. Archivos principales creados

- `docs/00_producto/BEAUTYOS_EXPEDIENTE_TECNICO_Y_PLAN_MAESTRO.md`
- `AGENTS.md`
- documentos de arquitectura y ADR dentro de `docs/01_arquitectura/`
- `docs/01_arquitectura/auditorias/TRAMO_0_LINEA_BASE_2026-07-19.md`
- `docs/01_arquitectura/auditorias/TRAMO_A_ESTRUCTURA_MULTISEDE_2026-07-20.md`
- `docs/02_operacion/RESPALDO_Y_RESTAURACION_SUPABASE.md`
- `docs/04_pruebas/CRITERIOS_SALIDA_FASE_1.md`
- `scripts/crear_respaldo_supabase.ps1`
- `supabase/sql/103_tramo_0_audit_multisite_baseline.sql`
- `supabase/migrations/20260720090817_tramo_a_estructura_multisede.sql`
- `supabase/sql/104_verify_tramo_a_multisite.sql`
- `supabase/sql/105_test_tramo_a_tenant_isolation.sql`
- `supabase/sql/106_rollback_tramo_a_test_only.sql`

## 9. Estado exacto al cierre

- Aplicación actual: sin cambios funcionales en este Tramo A.
- Supabase de producción: sin cambios del Tramo A.
- Respaldo: creado fuera de Git y restauración comprobada.
- Migración: preparada, reversible y aprobada en ensayo.
- Git local: contiene el commit `923a32c` y los dos commits locales anteriores del Tramo 0.
- GitHub: pendiente de publicación; no hacer push sin confirmar alcance.
- Alertas operativas: continúan pausadas.

## 10. Siguiente paso correcto

La próxima acción no es comenzar el Tramo B todavía. Primero se debe abrir la **compuerta de producción del Tramo A**:

1. comprobar si el esquema vivo cambió desde la auditoría;
2. generar un respaldo fresco si corresponde;
3. revisar los commits locales pendientes y el alcance que se publicará;
4. solicitar autorización explícita para aplicar la migración en Supabase;
5. aplicar únicamente el Tramo A;
6. ejecutar inmediatamente la verificación 104;
7. detenerse y revisar antes de diseñar o aplicar el Tramo B.

Modelo recomendado para esa compuerta: **GPT-5.6 Sol, esfuerzo Alto, en modalidad Codex**.

Fin del HANDOFF 1086–1115.
