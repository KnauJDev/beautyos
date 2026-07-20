# Criterios de salida — Fase 1

**Estado:** lista de aceptación en implementación; Tramo A aprobado en producción; Tramo B diseñado
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
- [ ] Migraciones de cada tramo revisadas y ejecutadas primero en ensayo.
- [x] Conteos y sumas financieras base registrados.
- [x] Plan de reversión del Tramo A ensayado.

Evidencia actual: `docs/01_arquitectura/auditorias/TRAMO_0_LINEA_BASE_2026-07-19.md`, `docs/01_arquitectura/auditorias/TRAMO_A_ESTRUCTURA_MULTISEDE_2026-07-20.md`, `docs/01_arquitectura/auditorias/TRAMO_B_DISENO_BACKFILL_OPERACIONAL_2026-07-20.md` y `supabase/sql/103–106`. El Tramo A ya fue aplicado y verificado en producción. El Tramo B está diseñado, pero todavía no tiene migración ni autorización de despliegue.

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
- [ ] Migración, auditoría y reversión del Tramo B creadas.
- [ ] Tramo B aplicado, revertido y reaplicado en ensayo.
- [ ] Tramo B aplicado y verificado en producción.

## 3. Aislamiento obligatorio

Preparar Tenant A y Tenant B; Tenant A tendrá Sede A1 y A2.

- [ ] Owner A no ve Tenant B.
- [ ] Admin A1 no ve ni modifica A2.
- [ ] Owner A consolida A1+A2.
- [ ] Stylist A1 solo ve lo propio autorizado.
- [ ] Customer solo ve sus datos.
- [ ] Plataforma no obtiene operación por privilegio implícito.
- [ ] IDs manipulados en una RPC devuelven denegación sin filtrar información.
- [ ] Usuario/membresía desactivada pierde acceso inmediatamente.

## 4. Integridad multisede

- [ ] Todo registro operativo tiene tenant y sede coherentes.
- [ ] No puede asignarse a un ticket un servicio/profesional de otra sede.
- [ ] Una sede inactiva no acepta nuevas reservas y conserva historia.
- [ ] Un profesional puede trabajar en dos sedes autorizadas.
- [ ] Los choques se detectan según profesional, tiempo y regla de traslado.
- [ ] Horarios y disponibilidad se calculan con zona de la sede.
- [ ] Caja, pagos, compras, gastos, stock y cierres no se mezclan entre sedes.

## 5. Conservación de datos

- [ ] Conteos de tickets, servicios e historiales coinciden.
- [ ] Totales de pagos vigentes/anulados coinciden.
- [ ] Comisiones históricas conservan valor y regla aplicada.
- [ ] Stock inicial de Sede principal coincide con el modelo anterior.
- [ ] Ningún registro queda huérfano.
- [ ] Flutter existente sigue funcionando durante la ventana compatible.

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
