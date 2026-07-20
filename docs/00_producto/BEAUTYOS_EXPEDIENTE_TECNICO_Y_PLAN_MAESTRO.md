# BeautyOS — Expediente técnico y plan maestro de construcción

**Versión:** 1.3
**Estado:** Rector aprobado — Fase 1 en implementación; Tramo A aprobado en producción; Tramo B diseñado
**Fecha:** 20 de julio de 2026
**Propietario del producto:** Proyecto BeautyOS  
**Regla de uso:** este documento define la dirección del producto. Cualquier cambio de alcance, regla de negocio o arquitectura debe registrarse aquí o en una decisión asociada antes de implementarse.

---

## 1. Propósito de este expediente

BeautyOS será una plataforma SaaS multiempresa para centros de estética: salones, peluquerías, barberías, spa de uñas y negocios similares. No es solo una agenda: es el sistema operativo comercial y operativo del centro.

Este expediente sirve para:

1. Mantener una visión única, aunque cambien conversaciones, herramientas o personas.
2. Convertir ideas en decisiones explícitas antes de hacer cambios difíciles de revertir.
3. Medir avance por entregables verificables, no por cantidad de pantallas o líneas de código.
4. Proteger seguridad, datos financieros e historial de clientes.
5. Crear una base reutilizable para vender BeautyOS por planes.

### Principio rector

**Primero se diseña el negocio, luego las reglas, después la experiencia y finalmente el código.**

---

## 2. Visión, problema y propuesta de valor

### 2.1 Visión

Permitir que un centro de belleza gestione sus reservas, equipo, servicios, operación diaria y finanzas desde una sola plataforma; y que sus clientes puedan reservar de manera simple desde web, enlace, QR o WhatsApp.

### 2.2 Problemas que resuelve

- Citas anotadas en papel, WhatsApp y varias agendas sin una fuente única.
- Choques de horario y falta de visibilidad de la disponibilidad real de estilistas.
- Falta de control de pagos, saldos, cierres y comisiones.
- Clientes sin historial, sin recordatorios y sin experiencia de reserva moderna.
- Negocios con más de una sede sin control consolidado ni separación operativa.
- Operación digital dependiente de una sola persona o de conversaciones dispersas.

### 2.3 Propuesta de valor

BeautyOS ofrece una operación segura por tenant y sede, con reservas confiables, agenda por profesional, control financiero básico y una futura presencia pública que convierte visitantes en clientes recurrentes.

---

## 3. Alcance comercial y planes

Los planes comerciales deben traducirse a permisos y funcionalidades (entitlements), no solo a textos de mercadeo.

| Plan | Incluye | Objetivo |
|---|---|---|
| **Básico** | Sedes, estilistas, servicios, clientes, agenda, reserva web/QR, estados de cita. | Digitalizar la operación y reducir choques. |
| **Business** | Todo Básico + pagos, caja, comisiones, compras, gastos, inventario y reportes financieros. | Controlar la rentabilidad del centro. |
| **Profesional** | Todo Business + perfil público, galería, reseñas, publicaciones y conexiones sociales. | Captar y fidelizar clientes. |

Regla: un módulo puede existir técnicamente, pero estará habilitado por plan y por configuración del tenant. Nunca se debe ocultar seguridad mediante una pantalla: el permiso se valida en backend.

---

## 4. Roles y fronteras de seguridad

### 4.1 Plataforma BeautyOS

| Rol | Responsabilidad | Límites |
|---|---|---|
| **Operador de plataforma / Superadmin** | Alta de tenants, planes, facturación SaaS, suspensión y soporte. | No usa los datos del negocio para la operación diaria; acceso excepcional, auditado y mínimo. |

Este rol es distinto del actual `owner` de un centro. No debe ser una cuenta común ni una llave universal expuesta en la aplicación.

### 4.2 Dentro de cada tenant

| Rol | Puede hacer | No puede hacer |
|---|---|---|
| **Owner del tenant** | Administración total del centro, sedes, equipo, configuración, reportes y facturación de su suscripción. | Administrar otros tenants o la plataforma. |
| **Admin** | Gestión diaria de sedes autorizadas, agenda, equipo, clientes, pagos y reportes según permisos. | Cambiar la propiedad del tenant o sus reglas de plataforma. |
| **Estilista** | Ver su agenda, solicitudes, iniciar/finalizar servicios, crear/invitar clientes y solicitar reservas dentro de sedes autorizadas. | Ver finanzas globales, otros datos sensibles o modificar políticas. |
| **Cliente** | Mantener su cuenta, reservar, cancelar/reprogramar según política, ver historial propio, reseñar y autorizar contenidos. | Acceder a clientes, equipo o finanzas del negocio. |

### 4.3 Regla de aislamiento

Todo registro operativo debe pertenecer como mínimo a un `tenant_id`; cuando se implemente multisede, además tendrá `branch_id` o una relación inequívoca con una sede. Ninguna consulta, RPC, Storage bucket, notificación o integración puede cruzar estos límites.

---

## 5. Decisiones fundacionales aprobadas

1. **Colombia es el primer mercado piloto.** Moneda COP, zona horaria predeterminada `America/Bogota`, pero configurables por tenant/sede para expansión futura.
2. **Bella Mujer es un tenant ficticio de pruebas**, no el piloto comercial real.
3. **Multisede desde la arquitectura inicial.** Un tenant tendrá una o más sedes; una sede ofrece servicios, horarios, recursos y personal habilitado.
4. **Reserva firme automática para cliente identificado.** La reserva con franja disponible crea una cita confirmada de inmediato, salvo que la sede configure revisión manual o anticipo obligatorio.
5. **Identidad de cliente.** Teléfono es identificador principal; documento es opcional y se trata como dato sensible. El correo es opcional. Nunca se muestran documentos completos en listados públicos o de estilistas.
6. **Reputación interna.** Las inasistencias y cancelaciones tardías construyen una señal operativa privada; no una calificación pública automática. Debe permitir corrección administrativa y trazabilidad.
7. **Compensación configurable.** Salario fijo, monto fijo por servicio, porcentaje del servicio y combinaciones; con fechas de vigencia e historial inmutable de liquidaciones.
8. **Suscripción recurrente desde el inicio.** La arquitectura contempla planes, estado de suscripción, eventos de cobro y suspensión controlada. La elección final de pasarela se validará para Colombia antes de integración.
9. **Canales de captación.** Web pública/QR primero; WhatsApp comienza con enlaces y mensajes prellenados, y evoluciona a automatización oficial cuando el flujo esté validado.
10. **Seguridad por defecto.** Las tablas sensibles no se abren al cliente; se usan RLS y RPCs estrictas, con autorización por rol, tenant y sede.

---

## 6. Modelo operativo objetivo

### 6.1 Entidades de negocio principales

| Dominio | Entidades previstas | Nota |
|---|---|---|
| Plataforma | `platform_operators`, `plans`, `subscriptions`, `subscription_events`, `tenant_entitlements` | Separado de la operación de un salón. |
| Organización | `tenants`, `branches`, `business_hours`, `branch_settings` | La sede define dirección, horario, zona y reglas locales. |
| Equipo | `user_profiles`, `staff_branch_memberships`, `stylists`, `stylist_service_capabilities`, `compensation_policies` | Un estilista puede trabajar en una o varias sedes autorizadas. |
| Catálogo | `service_categories`, `services`, `service_prices`, `service_durations` | Precio y duración deben poder variar por sede. |
| Cliente | `customer_accounts`, `clients`, `client_identities`, `client_reliability_events`, `consents` | Cuenta digital y ficha operativa separadas pero relacionadas. |
| Agenda | `tickets`, `ticket_services`, `appointments`, `availability_rules`, `blocked_slots`, `booking_events` | Una reserva debe conservar historial y no permitir choques. |
| Dinero | `payments`, `payment_voids`, `cash_closings`, `commission_liquidations`, `payroll_obligations`, `expenses`, `purchases` | No se altera el pasado: correcciones generan reversos o ajustes. |
| Inventario | `products`, `stock_movements`, `suppliers`, `purchase_orders` | Business. |
| Presencia | `public_profiles`, `portfolio_items`, `reviews`, `social_publications` | Profesional. |
| Auditoría | `audit_events`, `security_events`, `integration_events` | Quién hizo qué, cuándo y desde dónde. |

### 6.2 Principios de datos

- UUID como clave técnica; nunca usar teléfono o documento como clave primaria.
- Valores monetarios en enteros COP, no en decimales flotantes.
- Fechas y horas en UTC; presentación en la zona horaria configurada de la sede.
- El precio, duración y regla de comisión se copian como “snapshot” al ticket al venderse, para conservar historia.
- Las anulaciones no borran: producen eventos y reversos trazables.
- Los estados se cambian mediante funciones seguras, no actualizaciones libres desde la aplicación.

---

## 7. Flujos rectores que se documentarán y aprobarán

Cada flujo tendrá diagrama, reglas, estados, permisos, errores esperados y criterios de aceptación.

1. Descubrimiento público → sede → servicios → profesional/disponibilidad → reserva → confirmación.
2. Cuenta de cliente e identidad por teléfono/documento.
3. Reserva creada por admin o estilista para cliente existente/nuevo.
4. Cancelación, reprogramación, no-asistencia y reputación interna.
5. Agenda de estilista: solicitud, confirmación, inicio, finalización y corrección.
6. Agenda administrativa por sede y consolidada por tenant.
7. Pago parcial/completo, anulación, saldo, cierre y reporte.
8. Compensación de estilistas y liquidación histórica.
9. Gestión de servicios, capacidades y precios por sede.
10. Inventario, compra, consumo y gasto.
11. Reseña, galería, consentimiento y publicación social.
12. Vida de una suscripción SaaS: prueba, activa, pago fallido, gracia, suspendida, reactivada y cancelada.

---

## 8. Estados operativos mínimos

### 8.1 Cita / ticket

`solicitado` → `confirmado` → `en_espera` → `en_proceso` → `finalizado` → `cerrado`

Rutas alternativas: `cancelado`, `no_asistio` y `reprogramado` como evento, no como pérdida de la historia del ticket.

Reglas:

- Una reserva pública automática nace `confirmado` solo si se cumplió disponibilidad y reglas de la sede.
- Una solicitud interna puede nacer `solicitado` si requiere revisión.
- Solo una cita confirmada/en espera/en proceso ocupa agenda.
- Un ticket finalizado puede requerir pago antes de cierre.
- Corregir finalización o pago nunca elimina el hecho: deja auditoría.

### 8.2 Salud operativa

El sistema debe alertar, no cambiar estados unilateralmente, cuando encuentre:

- Citas pasadas en `solicitado`, `confirmado`, `en_espera` o `en_proceso`.
- Servicios finalizados y aún impagos.
- Suscripciones próximas a vencerse, vencidas o suspendidas.
- Stock bajo o negativo.

Este bloque está pausado hasta que se autorice reanudarlo.

---

## 9. Arquitectura técnica objetivo

### 9.1 Aplicaciones

- **Flutter Web y móvil Android primero.** Una base de interfaz, adaptación responsiva y pruebas en ambos formatos.
- **Web pública de reservas.** Rápida, indexable y separada de los paneles privados; acceso por subdominio o ruta pública del tenant/sede.
- **Panel administrativo.** Diseño de escritorio, tablet y móvil; información priorizada, no pantallas densas.
- **App/área de estilista.** Agenda rápida y acciones enfocadas a la atención.

### 9.2 Backend y servicios

- Supabase: Auth, PostgreSQL, RLS, funciones/RPCs, Storage y Realtime cuando aporte valor.
- Funciones seguras para operaciones de dominio: reservar, cambiar estado, registrar pago, anular, calcular disponibilidad y liquidar.
- Edge Functions o backend aislado para webhooks de pasarela, WhatsApp, redes sociales y tareas que requieran secretos.
- Pasarela de pago SaaS aislada de pagos del centro: son dos dominios financieros distintos.

### 9.3 Seguridad no negociable

- Nunca exponer `service_role`, llaves secretas, credenciales de pasarela o tokens sociales en Flutter/Web.
- RLS activo en tablas expuestas; privilegios mínimos.
- RPC `security definer` solo con justificación, `search_path` fijo, revocación de `PUBLIC` y validación explícita de identidad, tenant, sede y rol.
- Registro de auditoría en cambios de acceso, pagos, estados, comisiones y configuración.
- Backups, pruebas de restauración y monitoreo antes de piloto comercial.
- Revisión de protección de contraseñas, MFA para operadores sensibles y políticas de sesión antes del lanzamiento.

---

## 10. Plan maestro por fases y puertas de calidad

No se inicia la siguiente fase sin aprobar la puerta de salida de la anterior.

### Fase 0 — Gobierno del producto y documentación

**Propósito:** evitar decisiones dispersas.

1. Crear este expediente como fuente rectora.
2. Crear registro de decisiones de arquitectura (ADR).
3. Crear catálogo de flujos, glosario y registro de riesgos.
4. Definir versión de producto, backlog, criterios de “hecho” y pruebas manuales.
5. Establecer Miro como tablero visual y Markdown versionado como fuente canónica técnica.

**Salida:** repositorio con estructura documental, plan aprobado y una lista priorizada de flujos.

### Fase 1 — Diseño multisede y control de plataforma

**Propósito:** preparar el modelo SaaS correcto antes de ampliar funcionalidades.

**Estado al 19/07/2026:** diseño completado y documentado. La fase no se considera implementada hasta superar los criterios técnicos de `docs/04_pruebas/CRITERIOS_SALIDA_FASE_1.md`.

1. Especificar tenant, sede, zona horaria, horario de atención, moneda y configuración.
2. Diseñar relación de personal con sede: rol, vigencia, disponibilidad y permisos.
3. Diseñar servicios, precios, duración y capacidades por sede.
4. Separar identidad de operador SaaS, owner de tenant y administrador de sede.
5. Diseñar suscripción, plan, entitlements, período de gracia, suspensión y reactivación.
6. Auditar todas las entidades actuales que deben recibir `branch_id` o una relación de sede.
7. Definir migración sin pérdida de los datos de Bella Mujer.

**Pruebas de salida:** dos sedes ficticias del mismo tenant no mezclan agenda, inventario, caja, servicios ni personal; un reporte puede verse por sede y consolidado.

### Fase 2 — Identidad de cliente y reserva pública confiable

**Propósito:** convertir visitas en reservas sin fricción ni duplicados.

1. Definir `customer_account` y su vínculo con `client` dentro de tenant/sede.
2. Normalizar teléfono colombiano e internacional; validar duplicados sin revelar datos ajenos.
3. Capturar documento opcional con protección y consentimiento.
4. Diseñar registro e ingreso por teléfono/OTP o canal equivalente; no exigir contraseña en primera reserva.
5. Construir catálogo público de sedes, ubicación, servicios, profesionales, fotos y disponibilidad.
6. Aplicar reglas de antelación, horario laboral, duración, descanso, capacidad y choques.
7. Crear reserva firme automática y confirmación por canal configurado.
8. Crear vista de historial, cancelación y reprogramación del cliente.

**Pruebas de salida:** cliente nuevo y existente pueden reservar sin duplicar ficha; no pueden seleccionar franjas ocupadas; la reserva aparece instantáneamente donde corresponde.

### Fase 3 — Política de asistencia, cancelación y reputación interna

**Propósito:** proteger la operación sin castigar injustamente a clientes.

1. Definir plazo de cancelación por sede.
2. Diseñar eventos: cancelación temprana, tardía, no-asistencia, excepción y corrección.
3. Crear puntuación interna explicable, con historial y derecho de corrección administrativa.
4. Configurar consecuencias progresivas: aviso, requerir confirmación, requerir anticipo, bloqueo temporal; nunca bloqueo opaco.
5. Diseñar alertas de citas vencidas y finalizados impagos.

**Pruebas de salida:** cada evento deja trazabilidad; administrador puede explicar y corregir una decisión.

### Fase 4 — Compensación y finanzas operativas robustas

**Propósito:** convertir el flujo actual de pagos/comisiones en contabilidad operativa confiable.

1. Diseñar políticas de compensación con vigencia.
2. Separar salario fijo, obligación de nómina, comisión por servicio y ajuste manual autorizado.
3. Congelar snapshots de precio y regla de comisión al finalizar/liq​​uidar servicio.
4. Construir períodos de liquidación, aprobación y pago a estilista.
5. Mantener pagos de clientes, pagos SaaS y pagos de nómina como dominios distintos.
6. Definir cierre diario por sede y consolidado por tenant.
7. Completar controles de reverso/anulación y auditoría.

**Pruebas de salida:** cambiar una regla futura no modifica una liquidación histórica; totales del cierre coinciden con pagos no anulados.

### Fase 5 — Inventario, compras y gastos (Business)

**Propósito:** controlar costo real y evitar pérdidas por inventario.

1. Catálogo de productos y unidades de medida.
2. Stock inicial por sede y movimientos inmutables.
3. Compras, proveedores, gastos y soporte documental opcional.
4. Consumo de productos por servicio cuando aplique.
5. Alertas de mínimo, caducidad si aplica y movimientos negativos.
6. Integración con resultados financieros sin duplicar contabilidad.

**Pruebas de salida:** cada compra/consumo ajusta stock y los reportes distinguen venta, gasto, compra y comisión.

### Fase 6 — Presencia pública, reseñas y portafolio (Profesional)

**Propósito:** permitir adquisición y fidelización de clientes.

1. Perfil público por tenant y sede: descripción, dirección, mapa, horarios, servicios y equipo.
2. Galería de trabajos con consentimiento, atribución y moderación.
3. Solicitud de reseña después de servicio cerrado, con prevención de abuso.
4. Publicación social asistida: contenido preparado y aprobación humana primero.
5. Integraciones oficiales con Instagram/Facebook solo tras validar permisos, tokens y políticas.

**Pruebas de salida:** ningún contenido se publica sin autorización; una reseña pertenece al servicio/cliente correcto y se puede moderar.

### Fase 7 — Cobro recurrente de BeautyOS y operación SaaS

**Propósito:** comercializar de manera sostenible.

1. Seleccionar pasarela disponible para Colombia tras matriz de costo, recurrencia, webhooks, soporte y cumplimiento.
2. Implementar productos/planes, período de prueba y checkout seguro.
3. Procesar webhooks firmados e idempotentes.
4. Gestionar fallos de cobro, reintentos, período de gracia, suspensión suave y reactivación.
5. Crear panel de plataforma: tenants, plan, estado, uso y soporte.
6. Registrar auditoría de cambios de plan, cobros y suspensión.

**Pruebas de salida:** un cobro duplicado no duplica suscripción; una suspensión limita módulos según política sin borrar datos.

### Fase 8 — Calidad, rendimiento, seguridad y piloto

**Propósito:** pasar de demo a producto probado con usuarios reales.

1. Pruebas unitarias, de RPC, de autorización, de estados y de choques.
2. Pruebas de flujo integral por rol y sede.
3. Pruebas móviles reales Android y navegación pública de baja conectividad.
4. Auditoría RLS, funciones privilegiadas, Storage, secretos y dependencias.
5. Backup, restauración y procedimiento de incidentes.
6. Observabilidad: errores, trazas de integración y métricas de reserva.
7. Piloto controlado con un centro real, datos de prueba y retroalimentación semanal.

**Salida MVP vendible:** un tenant puede pagar, configurar sede/equipo/servicios, recibir reservas, atender, cobrar, cerrar y consultar resultados sin intervención técnica diaria.

---

## 11. Qué ya existe y cómo se aprovecha

El proyecto ya cuenta con una base operativa valiosa:

- Clientes y edición/activación.
- Tickets, servicios, estilistas, reprogramación y estados protegidos.
- Detección de choque de agenda.
- Agenda administrativa y agenda de estilista por fecha.
- Inicio/finalización de servicio y corrección administrativa.
- Pagos parciales, anulación, cierre, comisiones y reportes iniciales.
- Gestión básica de usuarios.
- Creación rápida de cliente y reserva guiada con franjas disponibles.
- Visibilidad de solicitudes pendientes para estilista.

No se descarta este trabajo: se refactoriza cuidadosamente para que el modelo multisede y de plataforma lo soporte.

---

## 11.A Azimut único: trazabilidad 001–1085 y desviaciones

### Material revisado

Este expediente consolida las fuentes canónicas de los pasos **001–450**, **451–926** y los handoffs **927–969**, **970–999**, **1000–1023**, **1024–1059** y **1060–1085**. La historia confirma una progresión saludable: prototipo Flutter, datos reales, módulos operativos, seguridad/tenant, roles, flujo de cita, pagos y disponibilidad guiada.

### Hitos verificados

| Bloque | Avance confirmado | Estado frente a la visión |
|---|---|---|
| 001–450 | Base Flutter, GitHub, Supabase, navegación, servicios y dashboard. | Fundacional. |
| 451–700 | Configuración, inventario, compras, gastos, fotos, reseñas y reportes demostrables. | Amplio funcionalmente; inicialmente en modo demo. |
| 701–926 | Login, perfiles, tenant, roles, RLS/RPC, reducción de permisos directos. | Corrigió el riesgo principal de seguridad y aislamiento. |
| 927–999 | Experiencia por rol: estilista, agenda, fotos, clientes y tickets. | Operación interna encaminada. |
| 1000–1059 | Flujo real: cita, servicio, estilista, estados, agenda, pagos, cierre, comisiones y usuarios. | Núcleo operativo MVP funcional. |
| 1060–1085 | Flujo integral probado, solicitudes visibles al estilista, cliente rápido, reserva guiada y disponibilidad real. | Base de reserva interna sólida. |

### Diagnóstico de desviaciones

No se encontró una desviación grave del objetivo original. Lo que ocurrió fue una evolución natural: primero se construyeron muchos módulos demostrables y posteriormente se endureció seguridad, roles y tenant. Eso era correcto para aprender y validar, pero deja tres cambios de rumbo necesarios antes de seguir agregando pantallas:

1. **De tenant único de demostración a SaaS multisede.** El código actual aísla por tenant, pero no modela todavía sede como frontera operativa completa. Esta es la prioridad arquitectónica número uno.
2. **De operación interna a producto público.** La reserva guiada actual es una excelente base para administración; la reserva web/WhatsApp del cliente requiere identidad, consentimiento, reglas de cancelación y una superficie pública aislada.
3. **De pagos internos a negocio SaaS cobrable.** Los pagos registrados hoy pertenecen al centro y su cliente. La suscripción recurrente de BeautyOS es un dominio independiente y no debe mezclarse con caja, comisiones ni reportes del tenant.

### Decisiones de alineación

- No reiniciar ni reescribir el núcleo de tickets, disponibilidad, pagos o agendas.
- No retomar alertas operativas todavía: continúan pausadas por decisión del propietario.
- No iniciar inventario/social/reportes avanzados antes de definir multisede, entitlements y suscripción.
- Toda nueva función debe indicar explícitamente: plataforma, tenant, sede, rol, plan comercial y flujo afectado.

---

## 11.B Investigación externa aplicable

### Recurrente SaaS en Colombia

Mercado Pago documenta cobros recurrentes programables con frecuencia, reintentos, período de prueba, gestión de pausa/cancelación/reactivación y webhooks. Será un candidato de evaluación para la suscripción de BeautyOS; no es todavía una elección definitiva. Fuentes: [suscripciones con API](https://www.mercadopago.com.co/developers/es/docs/subscriptions/overview), [gestión de suscripciones](https://www.mercadopago.com.co/developers/es/docs/subscriptions/subscription-management).

Wompi dispone de entorno sandbox y documentación para pagos recurrentes en medios colombianos; se incluirá en la matriz de selección y se validará expresamente su capacidad de recurrencia, reintentos, webhooks, conciliación y costo antes de contratar. Fuente: [sandbox y pagos recurrentes](https://docs.wompi.co/docs/colombia/datos-de-prueba-en-sandbox/).

**Regla de selección:** ningún proveedor se integra porque “parece conocido”. La decisión se toma con una prueba sandbox, revisión contractual/comercial, validación de webhooks firmados e idempotencia y una matriz de criterios.

### Seguridad y datos

Supabase establece RLS para tablas expuestas y el uso de privilegios mínimos como parte esencial de la seguridad desde cliente; su guía destaca que RLS es especialmente adecuada para aislamiento multi-tenant. Fuentes: [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security), [datos seguros](https://supabase.com/docs/guides/database/secure-data).

Los datos de clientes, teléfono, documento, fotos y reseñas deberán respetar la regulación colombiana de tratamiento de datos personales. Esta es una exigencia de diseño y debe convertirse en políticas, consentimientos y procedimientos antes del piloto. Fuente: [Ley 1581 de 2012](https://sedeelectronica.sic.gov.co/sites/default/files/normatividad/Ley_1581_2012.pdf).

---

## 12. Backlog priorizado inmediato

| Prioridad | Entregable | Dependencia | Estado |
|---|---|---|---|
| P0 | Aprobar este expediente y decisiones fundacionales | Producto | Aprobado; versión 1.1 |
| P0 | Diagrama de dominio multisede y roles | Fase 1 | Diseñado; Tramo A aplicado y Tramo B diseñado |
| P0 | Auditoría de impacto de `branch_id` en esquema actual | Fase 1 | Contrastada con esquema vivo; backfill diseñado |
| P0 | Especificación de suscripción/entitlements | Fase 1 | Diseñada; proveedor pendiente |
| P1 | Flujo de cuenta de cliente y reserva pública | Fase 2 | Pendiente |
| P1 | Política de cancelación/no-show | Fase 3 | Pendiente |
| P1 | Modelo de compensación con vigencias | Fase 4 | Pendiente |
| P2 | Alertas operativas previamente pausadas | Fase 3 | Pausado por decisión del producto |
| P2 | Inventario y gastos | Fase 5 | Pendiente |
| P3 | Reseñas, galería y redes | Fase 6 | Pendiente |

---

## 13. Definición de “hecho” para cualquier módulo

Un módulo no está terminado porque “se ve bonito”. Debe cumplir todos los puntos aplicables:

1. Alcance y reglas aprobados en un flujo/documento.
2. Permisos validados por rol, tenant y sede.
3. Operación sensible protegida en backend.
4. Errores explicables y recuperables para el usuario.
5. Pruebas de caso feliz, error, permisos y datos de otra sede/tenant.
6. Prueba visual web y móvil.
7. `flutter analyze` sin problemas y pruebas automatizadas relevantes.
8. SQL/RPC probado con usuario real de cada rol cuando aplique.
9. Documentación y bitácora actualizadas.
10. Commit descriptivo, revisión de cambios y publicación solo después de validación.

---

## 14. Registro inicial de riesgos

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Añadir multisede tarde | Alto | Diseñarla antes de ampliar módulos. |
| Mezclar superadmin con owner de tenant | Crítico | Separar control de plataforma y operación. |
| Datos de una sede visibles en otra | Crítico | RLS/RPC con `tenant_id` y `branch_id`; pruebas negativas. |
| Duplicar pagos o webhooks | Alto | Idempotencia, eventos y reversos. |
| Modificar comisiones históricas | Alto | Vigencias y snapshots. |
| Reserva automática abusada | Medio/alto | Identidad, políticas, reputación interna y anticipo configurable. |
| Integrar redes sin permisos válidos | Alto | APIs oficiales, secretos en backend y aprobación humana. |
| Alcance sin priorización | Alto | Fases, puertas de salida y backlog P0/P1/P2/P3. |

---

## 15. Sistema de fuentes permanentes

La documentación debe estar dentro del repositorio principal y viajar con el código. La estructura propuesta es:

```text
docs/
  00_product/
    BEAUTYOS_EXPEDIENTE_TECNICO_Y_PLAN_MAESTRO.md
    VISION_Y_PLANES.md
    GLOSARIO.md
  01_flows/
    FLUJO_RESERVA_PUBLICA.md
    FLUJO_OPERACION_CITA.md
    FLUJO_PAGOS_Y_CIERRE.md
  02_architecture/
    MODELO_MULTISEDE.md
    ROLES_Y_PERMISOS.md
    MODELO_DE_DATOS.md
    ADR/
  03_security/
    MODELO_DE_SEGURIDAD.md
    CHECKLIST_LANZAMIENTO.md
  04_testing/
    CASOS_DE_PRUEBA_MANUAL.md
    MATRIZ_DE_ROLES.md
  05_operations/
    RUNBOOK_SOPORTE.md
    BACKUP_Y_RESTAURACION.md
  HANDOFF/
    HANDOFF_BeautyOS_pasos_XXXX_YYYY.md
```

Reglas de conservación:

- Markdown es la **fuente canónica** porque se puede versionar con Git y revisar como código.
- Word/PDF son copias de lectura o presentación; nunca la única fuente.
- Los archivos de flujo de Miro/draw.io se exportan a `docs/01_flows/assets/` y se enlazan desde su Markdown.
- Las decisiones importantes se registran como ADR numerado: contexto, alternativas, decisión, consecuencias y fecha.
- El HANDOFF conserva qué se hizo y cómo continuar; no reemplaza las reglas maestras.

---

## 16. Instrucciones permanentes para trabajar con IA/Codex

### 16.1 Archivo de instrucciones del repositorio

Crear y mantener `AGENTS.md` en la raíz del repositorio. Allí se guardan reglas de trabajo para toda tarea técnica, por ejemplo:

- No tocar producción ni borrar datos sin autorización explícita.
- Usar migraciones y SQL de prueba para cambios de datos.
- Mantener aislamiento tenant/sede y auditoría.
- Ejecutar análisis y pruebas antes de publicar.
- Actualizar documentación y HANDOFF al completar bloques.
- No cambiar reglas de negocio sin actualizar el expediente o un ADR.

### 16.2 Skills

Las skills son procedimientos reutilizables para Codex. Se crean cuando una tarea se repite y necesita un método estable, por ejemplo:

- `beautyos-supabase-safe`: patrón de RPC, RLS, SQL de prueba y auditoría.
- `beautyos-flutter-feature`: estructura de página/servicio/modelo, análisis y prueba visual.
- `beautyos-handoff`: formato fijo de bitácora y verificación de Git.
- `beautyos-product-flow`: convertir una idea aprobada en flujo, reglas, criterios y backlog.

No crearemos skills por cada idea aislada. Primero estabilizamos este expediente y repetimos el proceso dos o tres veces; entonces extraemos una skill madura para no congelar prácticas prematuras.

### 16.3 Parámetros e instrucciones de cada tarea

Cada solicitud futura debe comenzar, idealmente, con:

```text
Módulo: <nombre>
Objetivo: <resultado de negocio>
Usuarios: <roles involucrados>
Sede: <una / varias / consolidado>
Reglas: <qué está permitido y prohibido>
Datos sensibles: <si aplica>
Éxito esperado: <qué probaré visualmente>
```

Si el usuario no conoce estos campos, Codex debe proponerlos antes de cambios estructurales.

---

## 17. Decisiones pendientes para la siguiente aprobación

1. **Cerrada:** un estilista puede pertenecer a varias sedes del mismo tenant mediante asignaciones con vigencia, capacidades y horario por sede.
2. **Pendiente:** si la reserva automática exige anticipo. Recomendación: configurable por sede/servicio; inicialmente sin anticipo para simplificar el piloto, con arquitectura preparada.
3. **Pendiente:** pasarela de cobro recurrente SaaS para Colombia. Evaluar Wompi, Mercado Pago y PayU por recurrencia, webhooks, soporte, costo y conciliación.
4. **Pendiente:** política de cancelación predeterminada del piloto. Recomendación: cancelación libre hasta un umbral configurable y registro interno de no-show/cancelación tardía.
5. **Pendiente:** regla de traslado cuando un profesional trabaja en sedes distintas el mismo día.

---

## 18. Próxima acción autorizable

**Implementar el Tramo B primero en ensayo:** el diseño de contexto operacional por sede ya fue cerrado, sin cambios en producción. El siguiente bloque autorizado deberá crear la migración, auditoría y reversión protegida; restaurar un respaldo fresco posterior al Tramo A; aplicar, probar, revertir y reaplicar el Tramo B. Solo tras conservar los 139 registros objetivo y todas las invariantes podrá proponerse su despliegue al proyecto vivo. No se modificará Flutter ni se retirará el modelo heredado dentro de esta compuerta.

Documentos de ejecución:

- `docs/01_arquitectura/IMPACTO_Y_MIGRACION_MULTISEDE.md`
- `docs/01_arquitectura/auditorias/TRAMO_0_LINEA_BASE_2026-07-19.md`
- `docs/01_arquitectura/auditorias/TRAMO_A_ESTRUCTURA_MULTISEDE_2026-07-20.md`
- `docs/01_arquitectura/auditorias/TRAMO_B_DISENO_BACKFILL_OPERACIONAL_2026-07-20.md`
- `docs/02_operacion/RESPALDO_Y_RESTAURACION_SUPABASE.md`
- `docs/04_pruebas/CRITERIOS_SALIDA_FASE_1.md`
