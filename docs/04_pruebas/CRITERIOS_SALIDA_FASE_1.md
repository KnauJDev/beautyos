# Criterios de salida — Fase 1

**Estado:** lista de aceptación en implementación; Tramos A y B aprobados en producción; Tramo C completo en ensayo aislado y pendiente de autorización productiva
**Propósito:** no declarar multisede, roles o suscripción terminados solo porque la interfaz se vea bien.

## 1. Entregables documentales

- [x] Modelo plataforma → tenant → sede.
- [x] Separación de catálogos tenant y operación de sede.
- [x] Matriz de roles y permisos.
- [x] Especificación de planes, estados y entitlements.
- [x] Auditoría de impacto y migración por tramos.
- [x] ADR de decisiones fundacionales.
- [x] Aprobación funcional del propietario del producto.

## 2. Preparación técnica

- [x] Esquema vivo exportado y comparado con SQL versionado.
  - [x] Inventario vivo, objetos, RLS, RPC, migraciones administradas y diferencias documentados el 19/07/2026.
  - [x] Dump completo `schema.sql` generado y conservado fuera de Git.
- [x] Respaldo restaurable validado en entorno de prueba.
- [x] Migraciones de los Tramos A y B revisadas y ejecutadas primero en ensayo.
- [x] Conteos y sumas financieras base registrados.
- [x] Plan de reversión del Tramo A ensayado.

Evidencia actual: `docs/01_arquitectura/auditorias/TRAMO_0_LINEA_BASE_2026-07-19.md`, `docs/01_arquitectura/auditorias/TRAMO_A_ESTRUCTURA_MULTISEDE_2026-07-20.md`, `docs/01_arquitectura/auditorias/TRAMO_B_DISENO_BACKFILL_OPERACIONAL_2026-07-20.md` y `supabase/sql/103–110`. Los Tramos A y B ya fueron aplicados y verificados en producción. Las pruebas con escrituras controladas 108 y 110 se ejecutaron únicamente en ensayo; las auditorías de solo lectura 104 y 107 se repitieron sobre producción.

### Evidencia parcial completada por el Tramo A

- [x] Toda entidad de catálogo existente tiene correspondencia en la Sede principal.
- [x] Claves compuestas bloquean servicios y membresías pertenecientes a otro tenant.
- [x] Pagos vigentes/anulados y comisiones vigentes/anuladas conservaron sus totales.
- [x] El stock inicial copiado a la Sede principal coincide con el modelo anterior.
- [x] Las tablas nuevas tienen RLS, grants mínimos e índices para sus claves foráneas.
- [x] Las RPC heredadas principales siguieron respondiendo en la base restaurada.

Estas comprobaciones no cierran todavía los criterios globales de los Tramos B–F.

### Preparación documental completada para el Tramo B

- [x] Tablas objetivo y fuente de herencia de sede enumeradas.
- [x] Compatibilidad temporal para escrituras heredadas diseñada.
- [x] Claves compuestas, índices y controles de coherencia previstos.
- [x] Invariantes financieras y de inventario fijadas.
- [x] Pruebas negativas y condiciones de reversión diseñadas.
- [x] Migración, auditoría y reversión del Tramo B creadas.
- [x] Tramo B aplicado, revertido y reaplicado en ensayo.
- [x] Tramo B aplicado y verificado en producción.

### Evidencia técnica completada por el Tramo B en ensayo

- [x] Las 139 filas de las 15 tablas objetivo recibieron sede coherente y sin nulos.
- [x] Los conteos, pagos, comisiones y stock conservaron los valores de la línea base.
- [x] Claves compuestas y triggers rechazaron cruces de tenant, sede y padres operativos.
- [x] Las RPC heredadas principales siguieron funcionando y derivaron sede de forma segura.
- [x] Todas las claves foráneas del esquema público quedaron con índice de apoyo.
- [x] Flutter mantuvo análisis limpio y sus pruebas automatizadas aprobadas.

### Evidencia productiva del Tramo B

- [x] Respaldo fresco creado y verificado antes del despliegue.
- [x] Historial local y remoto de migraciones reconciliado sin reparar ni reescribir producción.
- [x] Vista previa de despliegue mostró exclusivamente la migración `20260720111110`.
- [x] Migración aplicada y registrada por Supabase.
- [x] Auditorías 104 y 107 terminaron sin excepciones y conservaron pagos, comisiones y stock.
- [x] Asesores oficiales ejecutados: sin errores bloqueantes; advertencias preexistentes documentadas para endurecimiento posterior.
- [x] `flutter analyze` sin hallazgos y `flutter test` aprobado después del despliegue.

### Diseño cerrado para el Tramo C

- [x] Contrato de sede efectiva definido por rol y vigencia.
- [x] Selección automática para una sede y explícita para varias.
- [x] Versionado `_v2` con `p_branch_id` obligatorio y sin sobrecargas ambiguas.
- [x] Migración por familias C1–C4 y reversión compatible definidas.
- [x] Matriz Tenant A/A1/A2 y Tenant B especificada.
- [x] Helper privado y listado de contextos implementados y verificados en ensayo.
- [x] Reservas, tickets y agendas `_v2` aprobados en dos sedes.
- [x] Caja, reportes e inventario separados por sede.
- [x] Flutter transmite sede y recarga módulos al cambiarla.

## 3. Aislamiento obligatorio

Preparar Tenant A y Tenant B; Tenant A tendrá Sede A1 y A2.

- [x] Owner A no ve Tenant B en el contrato C1.
- [x] Admin A1 no puede seleccionar A2 en el contrato C1.
- [ ] Owner A consolida A1+A2.
- [x] Stylist A1 solo recibe sedes con membresía y vínculo profesional activos en C1.
- [ ] Customer solo ve sus datos.
- [ ] Plataforma no obtiene operación por privilegio implícito.
- [x] Un `branch_id` manipulado contra Tenant B devuelve denegación uniforme en C1.
- [x] Usuario/membresía desactivada pierde el contexto de sede en la siguiente RPC C1.

## 4. Integridad multisede

- [x] Todo registro operativo existente tiene tenant y sede coherentes.
- [x] No puede asignarse a un ticket un servicio/profesional de otra sede.
- [x] Una sede inactiva no acepta nuevas reservas y conserva historia.
- [x] Un profesional puede trabajar en dos sedes autorizadas.
- [x] Los choques se detectan según profesional y tiempo dentro de cada sede. La regla de traslado entre sedes queda como política futura configurable.
- [x] Horarios y disponibilidad se calculan con zona de la sede.
- [x] Caja, pagos, compras, gastos, stock y cierres no se mezclan entre sedes.

## 5. Conservación de datos

- [x] Conteos de tickets, servicios e historiales coinciden.
- [x] Totales de pagos vigentes/anulados coinciden.
- [x] Comisiones históricas conservan valor y regla aplicada.
- [x] Stock inicial de Sede principal coincide con el modelo anterior.
- [x] Ningún registro operativo del alcance A–C queda sin tenant/sede coherentes.
- [x] Flutter existente sigue funcionando durante la ventana compatible.

## 6. Suscripción y entitlements

- [ ] Básico no ejecuta funciones Business/Profesional desde UI ni RPC.
- [ ] Upgrade habilita sin migración manual de datos.
- [ ] Downgrade conserva datos y bloquea nuevas operaciones restringidas.
- [ ] Webhook duplicado es idempotente.
- [ ] `past_due`, `grace`, `suspended` y reactivación siguen la política.
- [ ] Pagos SaaS nunca aparecen en la caja del tenant.

## 7. Seguridad técnica

- [ ] RLS activa en toda tabla expuesta.
- [ ] Grants mínimos revisados.
- [ ] Helpers sensibles están fuera del esquema expuesto.
- [ ] RPC `security definer` fija `search_path`, valida usuario y revoca `PUBLIC`.
- [ ] Índices cubren FKs, RLS y consultas principales.
- [ ] Logs no contienen tokens, documentos ni secretos.
- [ ] Auditoría registra permisos, soporte, suscripción y correcciones.

## 8. Flujo integral de aceptación

- [ ] Crear tenant/sede/equipo/catálogos.
- [ ] Crear o identificar cliente.
- [ ] Reservar servicio y profesional disponible.
- [ ] Confirmar, consultar agendas y evitar choque.
- [ ] Iniciar/finalizar, registrar/anular/corregir pago.
- [ ] Verificar cierre, comisión y reportes de sede/consolidado.
- [ ] Verificar consumo de inventario cuando aplique.
- [ ] Confirmar trazabilidad completa.

## 9. Puerta de aprobación

La Fase 1 solo se marca **implementada** cuando todas las casillas técnicas aplicables estén verificadas con evidencia. Mientras tanto su estado correcto es **diseñada** o **en implementación**.
