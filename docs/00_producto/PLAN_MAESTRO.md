# PLAN MAESTRO — Salón y Más

**Creado:** 9 de agosto de 2026 · **Última revisión:** 10 de agosto de 2026
**Estado:** vigente · **Manda sobre:** todo lo demás en materia de qué falta y en qué orden

> **Este documento reemplaza y jubila a siete:** `PLAN_DE_LANZAMIENTO_2026-08-06`,
> `BARRIDO_Y_PLAN_MAESTRO_2026-08-08`, `PLAN_DE_TRABAJO_A_PRODUCCION.xlsx`,
> `RUTA_GENERAL_2026-07-25`, `RUTA_A_PRODUCCION_2026-07-25`,
> `BEAUTYOS_EXPEDIENTE_TECNICO_Y_PLAN_MAESTRO` y `PROMPT_MAESTRO_IA`.
> Todos están en `docs/_archivo/` — no se borraron, porque guardan el porqué.
>
> **Se creó porque siete documentos opinando sobre lo mismo ya se contradijeron
> dos veces** (D-063 el 25-jul, D-118 el 09-ago) y en la segunda se trabajó una
> etapa entera fuera de orden sin que nadie lo notara.

---

## 1. Qué es y para quién

**Salón y Más es una aplicación por suscripción para dueños de salones de
estética:** spas de uñas, barberías, peluquerías, estéticas caninas.

**A quién se le vende:** al dueño o dueña del salón. Persona que no es técnica,
que trabaja dentro de su propio negocio, y que hoy lleva su agenda en un
cuaderno o en el WhatsApp.

**Qué le resuelve, en una frase por plan:**

- **Básico** — *"que no se me pierda ninguna cita ni ningún cobro"*
- **Business** — *"que sepa si estoy ganando plata de verdad"*
- **Profesional** — *"que me vean y me busquen"*

**Cómo se vende, al principio:** salón por salón, de forma personalizada. Por
eso existe el filtro de aceptación de la fase 3: **nadie entra solo**.

**El mercado:** Colombia. La competencia principal es chilena y argentina, con
soporte en otra zona horaria y sin factura colombiana. **No hay hoy una
aplicación de gestión de salones viralizada en Colombia.**

---

## 2. Cómo se usa este documento

| Marca | Significa |
|---|---|
| 👤 **TÚ** | Solo lo puede hacer el propietario (comprar, registrar cuentas, decidir) |
| 🤖 **YO** | Lo hace el asistente en una sesión de trabajo |
| 👥 **JUNTOS** | El asistente guía paso a paso mientras el propietario ejecuta |

| Estado | Significa |
|---|---|
| ✅ | Cerrado y verificado en producción |
| 🔄 | En curso |
| ⬜ | Pendiente |
| ⛔ | Bloqueado por otra cosa |

**Regla de oro:** no se salta de fase sin cerrar la anterior. Si hay que
saltarse algo, **se anota aquí por qué**.

**Las tres reglas que sostienen la continuidad del proyecto:**

1. **Este documento manda** sobre qué falta y en qué orden.
2. **`REGISTRO_DE_DECISIONES.md` manda sobre el porqué.** Solo crece, nunca se
   resume, nunca se borra una fila. Es lo que permitió el 09-ago descubrir tres
   errores propios que ninguna prueba automática vio.
3. **El HANDOFF más reciente manda sobre dónde quedamos hoy.** Se reemplaza
   cada sesión.

**No hay un cuarto documento con opinión sobre el plan. Si aparece, está mal.**

---

## 3. El plan, el precio y la sede

**Decidido el 01-sep (D-188). Corrige a D-004, D-124, D-136 y D-140, y resuelve
la Idea I-14.**

### Un solo plan

Se retiró la escalera de tres (Básico / Business / Profesional). Queda **un solo
plan, "Todo Incluido"**, y el eje de cobro deja de ser *qué módulos te dejo
usar* para pasar a ser **cuántas sedes tienes activas**.

**Por qué:** enamorar al salón desde el día cero con el producto entero, quitar
la sensación de mezquindad de los candados por módulo, y que el ingreso crezca
con el negocio del cliente en vez de con lo que se le esconde.

**Qué trae, que es todo:** agenda y citas, caja y cobros, comisiones, clientes
con historial, inventario, compras y gastos, reportes financieros, fotos de
trabajos, reseñas y la vitrina web pública. Sin topes de estilistas, de cuentas
de equipo ni de fotos.

**Lo único que no está incluido es lo que no existe:** WhatsApp con agente e
Instagram automático son Fase 6, y la regla de esa fase sigue en pie — *nada de
la fase 6 se vende como disponible hasta que exista*.

### Precios

**Ajustado el 02-sep (D-189).**

| | Por sede al mes |
|---|---:|
| **Precio de lista** | **$150.000** |
| | *$5.000 al día* |

**El descuento de lanzamiento no se publica.** Ni cifra ni cupo. En la web hay
un *"Consulta la tarifa especial de lanzamiento"* con enlace a WhatsApp, y el
precio de cada salón se fija **uno a uno desde el panel**, al aprobarlo. Así no
se atan las manos en la negociación ni se promete en público algo que luego
haya que sostener con todo el mundo.

- **El descuento se fija como precio pactado, nunca como porcentaje.** Un
  33,33% de 150.000 tampoco cae redondo, y `beautyos_procesar_evento_epayco`
  compara el monto pagado contra el calculado (D-159): un peso de diferencia se
  ve en el checkout.
- Los pioneros que ya tienen $80.000 pactados **se quedan con su precio**.

### Cuánta gente cabe

**10 personas por salón: el dueño más 9 cuentas de equipo** entre
administradores, recepcionistas y estilistas.

- ⚠️ **El tope guardado es 9, no 10**, porque **el propietario no cuenta contra
  el límite** (D-136: *"su cuenta no es de equipo, es el negocio"*). Poner 10
  daría once personas.
- ⚠️ **Y el tope es por NEGOCIO, no por sede.** `create_team_invitation` cuenta
  el tenant entero. Que sea "10 por sede" solo será cierto cuando la Etapa 2
  haga la suscripción por sede — **hay que arreglarlo ahí, o la promesa
  comercial y el código dejan de coincidir**.
- **Al salón grande se le concede la excepción desde el panel**, con
  `tenant_feature_overrides`. Es mejor tener algo que conceder que no tener
  nada.

**Clientas, citas, tickets y fotos no tienen tope ninguno.**

### Qué cambia de precio para quién

| | Antes | Ahora | |
|---|---:|---:|---|
| Salón de **1 sede** | $160.000 (Básico, sin inventario ni reportes ni fotos) | **$150.000 con todo** | algo más barato, y completo |
| Cadena de **3 sedes** | $240.000 (Profesional, sedes ilimitadas) | **$450.000** | casi el doble |

Es coherente —el valor escala con el negocio— pero **cambia para quién es barato
el producto**: el salón de barrio, que es el cliente objetivo escrito en el
apartado 1, sale ganando; la cadena paga más.

**Frente a AgendaPro** ($99.000 el capado, $510.000 el completo, precios reales
de una cuenta de prueba, ver el benchmarking del 28-jul): su equivalente a *todo
incluido* cuesta **más de cuatro veces**. Ese es el argumento de la primera
visita, no el precio de entrada.

### Cómo se cobra la sede — en tres etapas

El cobro por sede rehace el ciclo de facturación anclado (D-160), el webhook y
las intenciones de pago (D-182), que es el código de dinero recién blindado. Por
eso va por partes:

| Etapa | Qué | Estado |
|---|---|---|
| 1 | Catálogo de un solo plan, capacidades abiertas y pantalla pública | ✅ **CERRADA 02-sep (D-188, D-189).** Migración aplicada, Control 201 en verde (8 de 8) y `create-epayco-session` desplegada con el plan por defecto `pro` |
| 2 | **Suscripción por sede:** tabla propia, la sede nace inactiva y se activa al pagarse | ⬜ |
| 3a | **La base:** `branch_id` en la intención de pago y el cálculo del cargo por sede con prorrateo | ✅ **CERRADA 02-sep (D-191).** Control 203 en verde |
| 3b | **Lo que cobra:** checkout y webhook por sede, y la pantalla de pago del salón | ✅ **CERRADA 02-sep (D-192, D-193).** Faltan las alertas por sede y el tope de equipo por sede, anotados aparte |

> 🔴 **Hasta que la Etapa 3 esté hecha no se puede vender la segunda sede.** Hoy
> un negocio paga una suscripción y puede crear las sedes que quiera sin que se
> le cobren. Con cero clientes pagando no cuesta dinero, pero es un agujero de
> ingreso en cuanto entre el primer salón con dos locales.

---

## 4. Estado real, módulo a módulo

Un dueño ve **16 módulos**. Esto es lo que hay hoy.

| Módulo | Qué hace hoy | Qué le falta | Dónde se arregla |
|---|---|---|---|
| **Dashboard** | ✅ 4 indicadores comparados, gráfico, agenda de hoy, avisos | "Tu negocio en palabras" | F6.1 |
| **Agenda** | Lista básica. **234 líneas** | Pasa a ser el tablero día/semana/mes | F4.2, F4.3 |
| **Tickets** | Panel completo de cobro. **3.699 líneas** | Nivel 2 y 3; número de venta; píldora de estado | F4.4, F4.5 |
| **Clientes** | Solo lista | Nuevos vs recurrentes, retorno, valor, quién dejó de venir. Falta apellido separado | F4.6 |
| **Reportes** | Ventas, resultado financiero y **consolidado de todas las sedes**, con desglose de cuánto puso cada una ✅ (D-194) | Nivel 2 y 3, métodos de pago, comparación entre períodos | F4.7 |
| **Estilistas** | Lista y configuración | Producción por persona | F4.9 |
| **Servicios** | Catálogo y precios | Cuáles dejan más dinero. Foto por servicio | F4.9 |
| **Usuarios** | Invitar y gestionar. **El correo de invitación ya llega** (H-12 cerrado el 10-ago) y **un estilista no puede tener dos cuentas activas** (R, cerrado el 11-ago) | Separar el texto de la pantalla de acceso (**S**) y **poder dar acceso a una segunda sede** (**V**) | Fase 4 |
| **Inventario / Compras / Gastos** | Funcionan | Pulido visual | F4.8 |
| **Fotos de trabajos** | ✅ Privadas hasta aprobar, papelera. **Ya van amarradas al ticket, al cliente y al estilista** | **No se ve el número de ticket** en la galería; sin filtros por cliente ni por estilista; flujo de captura sin definir; tipos de foto confusos | F4.9, F5.7 |
| **Reseñas** | Funcionan | Respuestas asistidas | F6.3 |
| **Configuración** | Completa, con tema y versión | Numeración de ticket ajustable; explicar "Subir portada" | F4.9 |
| **Panel de plataforma** | Solo lectura de negocios | Rediseño completo, aprobar clientes, tarifas, referidos | F3.7, F7 |
| **Mi agenda / Mis fotos / Mis reseñas / Mi panel** *(estilista)* | Funcionan | Pulido | F4.9 |

---

## 5. LA RUTA

### FASE 0 — Que exista en internet ✅ CERRADA (06-ago)

Dominio comprado, Cloudflare Pages publicando en cada `push`, HTTPS,
instalable como app. **Costo real: ~12 USD al año.**

### FASE 1 — Que sea seguro compartirla ✅ CERRADA (06-ago)

Tope antiabuso en la reserva pública, rol Asistente con sus pantallas, 2FA.

### FASE 2 — Seguridad y red de protección ✅ **CERRADA (12-ago)** — 7 de 7

> **El paso 2.2 encontró que el respaldo estaba incompleto desde el 08-ago**
> (hallazgo Y): no incluía el esquema `private`, donde viven las 18 funciones
> que autorizan cada operación. **Se habrían recuperado todos los datos con la
> aplicación inutilizada.** Corregido y verificado el mismo día.
>
> Queda desbloqueada la mitad automática de H-03 (D-121).

| # | Paso | Quién | Estado |
|---|---|---|---|
| 2.1 | **Rotar las claves `service_role` y `secret`** (H-04). Expuestas el 03-ago | 👥 | ✅ **CERRADO 09-ago (D-127).** Se borró la clave secreta y se **desactivaron** las claves antiguas — mejor que rotarlas. Verificado de extremo a extremo en producción |
| 2.2 | Restaurar un respaldo de ensayo en un segundo proyecto gratuito (D-111) | 👥 | ✅ **CERRADO 12-ago (D-134).** Se creó `salonymas-ensayo`, se restauró y se comparó con un censo de 37 cifras: **36 idénticas**. La única diferencia es el registro de archivos de Storage (hallazgo Z). **Encontró que el respaldo llevaba 4 días incompleto** (hallazgo Y) |
| 2.3 | **Verificar el dominio en Resend** (H-12) | 👥 | ✅ **CERRADO 10-ago (D-128).** Eran tres problemas encadenados; el de fondo era una dependencia anclada con rango. *(El mismo arreglo en `send-low-stock-alert` ya se aplicó: paso 2.7.)* |
| 2.4 | Cerrar los almacenes de archivos (H-09) | 🤖 | ✅ D-119 |
| 2.5 | Marcar "Naguara de Uñas" como negocio de prueba | 🤖 | ✅ D-120 |
| 2.6 | Pruebas de las 3 reglas de dinero y de los roles (H-03) | 🤖 | ✅ D-121 — la mitad automática espera a 2.2 |
| 2.7 | **Arreglar `send-low-stock-alert`** — estaba rota por la misma causa que D-128 (hallazgo T) | 🤖 | ✅ **CERRADO 11-ago (D-131).** Arreglada, publicada (versión 6) y **verificada de extremo a extremo por el propietario**: consumo interno de 6 unidades de "Gel para Peinar" → quedó en 3 con mínimo 5 → **el correo llegó** desde `hola@salonymas.com` con el producto, la sede y las cantidades correctas |

### FASE 3 — Poder cobrar — *el camino corto al primer cliente*

| # | Paso | Quién | Estado |
|---|---|---|---|
| 3.1 | Confirmar con ePayco si admite **cobros recurrentes** | 👤 | ✅ **CONFIRMADO 09-ago: la cuenta sí admite cobros recurrentes.** Era el mayor riesgo de esta fase y quedó descartado |
| 3.2 | Consultar a un contador las obligaciones al facturar (DIAN, IVA) | 👤 | ⬜ |
| 3.3 | Términos de servicio y política de privacidad (Ley 1581) | 👥 | 🔄 **Contenido técnico construido 17-ago (D-144).** `TermsAndPrivacyPage`, enrutamiento público, checkbox obligatorio en registro, 113/113 pruebas. **Falta la mitad no técnica:** revisión de un abogado colombiano antes de tratarlo como vinculante |
| 3.4 | Subir Supabase a plan Pro (~25 USD/mes) | 👤 | ⬜ |
| 3.5 | Cargar los 3 planes con precios de lista y límites | 🤖 | ✅ **CERRADO 12-ago (D-136).** Precios en **pesos** (160/200/240 mil), columna renombrada a `price_cop`, y **se crearon "sedes" y "cuentas de equipo"**, que no existían como capacidad — sin ellas no se podía ni escribir *"3 sedes pero 25 cuentas"*. **Y se hacen cumplir**: antes `create_branch` no tenía ni una comprobación |
| 3.6 | **Precio y descuento por cliente** en la suscripción (columnas nuevas) | 🤖 | ✅ **CERRADO 12-ago (D-136).** Precio propio **o** descuento con fecha de fin, motivo obligatorio, y marca de pionero. **El pionero es un descuento sin fecha de fin**: 50% mientras siga activo. La regla de cuánto paga vive en `beautyos_precio_efectivo`, un solo sitio |
| 3.7 | **Filtro de aceptación:** formulario, estado `pending`, aprobar/rechazar. La prueba gratis **empieza al aprobar** | 🤖 | ✅ **CERRADO 16-ago (D-138).** Formulario con cuestionario (ciudad, sedes, equipo, medio), estado `pending` sin tiempo de prueba, aprobación con plan / 50% Pionero, rechazo con motivo, y pantalla de espera/rechazo para el usuario. 98/98 pruebas |
| 3.8 | Pantalla pública de planes (`list_public_plans` ya existe, dormida) | 🤖 | ✅ **CERRADO 17-ago (D-140).** Pantalla pública responsiva de planes y precios en COP (`PublicPlansPage`) conectada a `list_public_plans()` y catálogo de respaldo (D-124, D-136). Comparativa de características, FAQ, badges de prueba de 21 días / sin tarjeta de crédito, enrutamiento público `?planes=1` / `?pricing=1` y enlaces desde login y registro. 100/100 pruebas en verde |
| 3.9 | **ePayco con confirmación en el servidor.** Nunca creerle al navegador | 🤖 | ✅ **CERRADO 17-ago (D-141).** Edge Function `epayco-webhook` que valida la firma criptográfica SHA-256 en servidor con credenciales privadas (cero secretos en cliente). Idempotencia estricta en base de datos mediante `UNIQUE(provider, provider_event_id)` en `subscription_events` |
| 3.10 | Pago → suscripción: activar, renovar, manejar el fallido | 🤖 | ✅ **CERRADO 17-ago (D-141).** RPC `private.beautyos_procesar_evento_epayco` (solo `service_role`) que transiciona de inmediato a `active` por 1 mes al confirmar pago (reactivación automática). Si falla un cobro en negocio activo, pasa a `past_due` con 5 días de gracia (D-141). Botón de checkout multimetodo ePayco en Flutter (`EpaycoCheckoutService`), banner de gracia con cuenta regresiva día a día en `main.dart`, y tarjeta de Suscripción en Configuración. 103/103 pruebas en verde. **Migrado a Smart Checkout V2 el 23-ago** (Edge Functions `create-epayco-session` y `verify-epayco-transaction`, sesión segura en backend en vez de URL directa de checkout, commits `a73562f`…`47bc121`, no registrados individualmente). **Auditoría del mismo día (D-159) encontró y corrigió una regresión crítica**: la migración de esa tarde había eliminado la validación de monto contra el precio pactado (cualquier pago ≥ $10.000 COP activaba cualquier plan), dejaba que el cliente controlara `tenantId`/monto, tenía un fallback que podía activar el negocio equivocado, y un nombre de columna erróneo que habría hecho fallar todo evento de pago. Corregido en `20260823130000_epayco_validar_precio_por_plan.sql`, **aplicada en Supabase y verificada con el Control 179 contra la base real el 23-ago** (rechaza pago insuficiente, activa con el precio correcto). **El mismo día, a pedido del propietario (D-160), se rediseñó el ciclo de facturación:** de "reinicia el período en cada pago" a ciclos de 30 días anclados al primer pago (renovación anticipada acumula al final del período vigente, pago tardío en gracia prorratea hacia la próxima ancla, reactivación tras suspensión reancla — salvo suspensión manual del owner, que bloquea la reactivación por pago), con precedencia absoluta del plan/precio pactado desde el panel (`price_reason is not null` cubre tanto precio fijo como solo-descuento). Corrige de paso dos bugs: `plan_id` nunca se actualizaba al pagar, y el candado de pactado no cubría descuento-sin-precio-fijo. Migración `20260823150000_ciclo_facturacion_ancla_y_plan_pactado.sql`, **aplicada en Supabase y verificada con el Control 180 (9 pruebas) contra la base real el 23-ago**; Edge Function `create-epayco-session` redesplegada (v7). `git push` hecho y **confirmado en producción el 23-ago**: el texto nuevo del checkout con precio pactado ya aparece en el `main.dart.js` publicado en `salonymas.com` |
| 3.11 | Avisos por correo **10, 5 y 3 días** antes de vencer | 🤖 | ✅ **CERRADO 17-ago (D-143, disparador diario D-145).** Edge Function `send-subscription-expiry-alerts` con Resend (`hola@salonymas.com`), tabla `subscription_notification_logs` con filtro anti-spam diario, cuenta regresiva diaria durante los 5 días de gracia, botón directo de pago en ePayco y suspensión automática de cuentas que agotaron la gracia (`private.beautyos_suspender_suscripciones_vencidas`). **Disparador diario real** con `pg_cron`+`pg_net` (08:00 hora Colombia), secreto en Supabase Vault — requiere el paso manual de `vault.create_secret(...)` con el valor real de `CRON_SECRET`, fuera de git. 106/106 pruebas en verde |
| 3.12 | 🔴 **Se adelantó a la Fase 2 a propósito** — la regla de oro pide anotar por qué: el tope de correos se agota probando, así que **bloqueaba las pruebas de ese día**, no solo las ventas de mañana. **Que los correos de cuenta salgan por Resend, no por Supabase.** El *"Confirma tu correo"* del registro lo mandaba el servicio interno de Supabase (`noreply@mail.app.supabase.io`), con un **tope diario bajísimo** que el propietario agotó el 10-ago probando (`email rate limit exceeded`) | 👥 | ✅ **CERRADO 11-ago (D-133).** SMTP de Supabase Auth apuntando a Resend. **Verificado de extremo a extremo:** el correo llegó desde `hola@salonymas.com`, Resend lo registró con `200`, y el registro se completó. El tope subió solo a 30/hora. **Queda el hallazgo W: esos correos están en inglés** |
| 3.13 | **Traducir las plantillas de correo de cuenta** (hallazgo W) — confirmar registro, invitación, recuperar contraseña, cambio de correo y reautenticación | 👥 | ✅ **CERRADO 17-ago (D-146).** Las 6 plantillas redactadas en español con la marca de Salón y Más, listas para copiar/pegar en `docs/02_operacion/PLANTILLAS_CORREO_AUTH.md`. **Falta el paso manual, fuera de git:** pegarlas una por una en Authentication → Emails → Templates del panel de Supabase |

### FASE 4 — Pulido módulo a módulo

| # | Paso | Quién | Estado |
|---|---|---|---|
| 4.1 | Número de ticket consecutivo y ajustable | 🤖 | ✅ D-117 |
| 4.2 | Las dos funciones del tablero de agenda | 🤖 | ✅ **CERRADO 17-ago (D-147).** RPCs `get_ticket_board_counts_v2` y `get_ticket_board_list_v2` con granularidad dinámica (15m, 30m, 1h, día), zona horaria `America/Bogota`, lista Nivel 2 con consecutivo `#0000701`, cliente, teléfono para WhatsApp directo y saldos. 5/5 pruebas SQL en verde (Control 173). **Ampliado el 27-ago (D-163):** la tarjeta del Nivel 2 abre con un toque la Ficha Completa Nivel 3 del ticket (ver detalle en el paso 4.5) |
| 4.3 | **El tablero:** día, semana, mes + buscador múltiple + refresco automático | 🤖 | ✅ **CERRADO 17-ago (D-148, corregido D-149).** `AgendaPage` en Flutter con 3 vistas (Día con granularidad de 15 min, Semana, Mes), banner de regla del cero y cancelaciones/no asistió (D-101), cuadrícula con ceros atenuados, lista de Nivel 2 con consecutivo `#0000701`, WhatsApp directo (sin "+", D-149) y Realtime híbrido. **Días pasados atenuados en Semana/Mes** (D-101, D-149). 123/123 pruebas en verde |
| 4.4 | **Número de venta** al cerrar el ticket (hallazgo P) | 🤖 | ✅ **CERRADO 17-ago (D-150, corregido D-151).** Separación estricta de consecutivo operativo (`ticket_code` D-117) y venta contable (`sale_code` ej. `VTA-0000001` / DIAN). Tabla `branch_sale_numbering` por sede, triggers atómicos e inmutables, backfill histórico y chips duales en Nivel 2. **Inmutabilidad reforzada frente a reapertura** (`void_ticket_payment`, D-151): un ticket que ya tiene número de venta lo conserva sin importar cuántas veces se reabra y se vuelva a cerrar. 128/128 pruebas Flutter, 7/7 en el Control 174 |
| 4.5 | Tickets: pulido del nivel 2 y 3 + cambiar `TicketStatusBadge` por `StatusPill` (hallazgo N) | 🤖 | ✅ **CERRADO 18-ago (D-152).** Buscador universal (cliente, celular, `#cita`, `VTA-venta`, servicios, estilistas), selector temporal rápido (Hoy, Semana, Mes, Rango), chips de estado semánticos con conteo en vivo, filtro por estilista, chips duales correlativos, enlace directo a WhatsApp sin `+`, eliminación total de `TicketStatusBadge` adoptando `StatusPill`, y modal responsivo Nivel 3 (`_TicketDetailSheet`) con scroll continuo organizado en 6 tarjetas modulares. 132/132 pruebas en verde. **Ampliado el 27-ago (D-163)** a pedido del propietario: la tarjeta del Nivel 2 de Agenda abre esta misma Ficha Completa con un toque (sin pasar por la pestaña de Tickets); el `StatusPill` del header ahora es un botón con tooltip "Cambiar estado" que dispara el diálogo de cambio de estado; y el salón puede cobrar abonos/anticipos desde que la cita se solicita, no solo en `finalizado`/`cerrado` — el bloqueo real estaba en el RPC `register_ticket_payment` (exigía `finalizado` y cerraba la cita + generaba comisiones apenas el saldo llegaba a 0), corregido con un helper compartido (`private.beautyos_close_ticket_if_fully_paid`) que solo cierra y genera comisión cuando el ticket ya está `finalizado` de verdad. Migración `20260827100000_abonos_en_citas_activas.sql` y control `183_test_abonos_en_citas_activas.sql` (5 casos en `ROLLBACK`) escritos y revisados; **pendiente que el propietario los aplique en Supabase**. 157/157 pruebas en verde |
| 4.6 | Clientes: análisis de retorno y valor. Decidir si se separa el apellido | 🤖 | ✅ **CERRADO 18-ago (D-153).** Se mantiene nombre comercial unificado con helper extractor reactivo `firstName` para WhatsApp. `get_clients_management_summary()` con métricas RFM: visitas, gasto total acumulado, ticket promedio, cadencia de visita ("cada ~X días"), última cita y segmentación automática (VIP, Recurrente, Nuevo, En riesgo +45 días). `ClientesPage` con buscador universal, chips de segmentación con contadores, `ClientRow` con WhatsApp contextual y ficha de detalle Nivel 3 (`_ClientDetailSheet`). 138/138 pruebas en verde |
| 4.7 | Reportes: nivel 2 y 3, métodos de pago, comparación | 🤖 | ✅ **CERRADO 18-ago (D-154).** Selector temporal dinámico (Hoy, Esta semana, Este mes, Rango personalizado), desglose de cobros por método de pago (Efectivo, Transferencias Nequi/Daviplata, Tarjetas, Otros), arqueo de efectivo real en caja, comparación de tendencias vs período anterior (con guardián para negocios nuevos) y modales de drill-down Nivel 3 para comisiones por estilista y ventas por servicio. 141/141 pruebas en verde |
| 4.8 | Inventario, Compras y Gastos: pulido visual. **Y el plural de las unidades en el correo de stock bajo**: hoy dice *"quedó con 3 unidad"* y *"el mínimo (5 unidad)"*, porque la unidad se guarda en singular. Con unidades como `ml` o `gr` se lee bien; con `unidad` no. Visto el 11-ago en el correo real | 🤖 | ✅ **CERRADO 18-ago (D-155).** Corrección gramatical unificada (`formatUnitQuantity`) en Edge Function de alerta de stock bajo y modelos de Flutter (`1 unidad` vs `3 unidades` / unidades métricas intactas). Modernización integral de `InventarioPage`, `ComprasPage` y `GastosPage` con buscadores universales reactivos, chips de filtrado con contadores dinámicos y `AppColors.surface`. 146/146 pruebas en verde |
| 4.9 | Servicios, Estilistas y Configuración: pulido, producción por persona, numeración ajustable, tipos de foto. **Y la galería de fotos: mostrar el número de ticket y poder filtrar por cliente y por estilista** | 🤖 | ✅ **CERRADO 18-ago (D-156).** Galería de fotos (`FotosTrabajosPage`) con chip de cita `#0000701` conectado a BD, buscador y filtros por estilista y cliente. Servicios (`ServiciosPage`) y Estilistas (`EstilistasPage`) modernizados con buscadores interactivos, chips por categorías/especialidades y métricas. Configuración (`ConfiguracionPage`) con `SaleNumberingCard` y diálogo para prefijo/número/resolución DIAN con preview en vivo (`previewNextCode`) y políticas de fotos de trabajo. 151/151 pruebas en verde |
| 4.10 | **Barra inferior de celular con acciones**, no módulos (hallazgo D) + **Rediseño integral de Shell, Header blanco minimalista y Sidebar categorizado estilo WeiBook/Fresha** | 🤖 | ✅ **CERRADO 22-ago (D-157).** Rediseño integral de la experiencia visual y arquitectura de información en `lib/main.dart`: (1) Header superior minimalista en fondo blanco (`AppColors.surface`) con borde sutil, isotipo degradado de Salón y Más/BeautyOS, selector de sede en píldora interactiva (`_BranchSelectorPill`), botón de Acción Rápida Global destacada (`+ Nueva Cita`), badge de prueba/gracia minimalista (`_TrialHeaderBadge`) y avatar de usuario con popup de seguridad/cierre de sesión. (2) Sidebar de escritorio categorizado (`_CategorizedSideMenu`) en 4 grupos semánticos con subtítulos (`OPERACIÓN`, `FINANZAS Y GESTIÓN`, `PORTAFOLIO`, `CATÁLOGO Y AJUSTES`), items ergonómicos redondeados con indicador activo. (3) Navegación móvil (`_MobileNavBar`) con los 4 destinos clave (`Agenda`, `Tickets`, `Clientes`, `Dashboard`) y modal "Más" categorizado. 152/152 pruebas en verde. |
| 4.11 | Rediseño del panel de plataforma (hallazgo O) + **Ficha Completa Nivel 3 de Negocio (bosquejo del propietario) y selector interactivo de planes en Checkout ePayco** | 🤖 | ✅ **CERRADO 22-ago (D-158).** Modernización integral de `PlatformPanelPage` (`lib/pages/platform_panel_page.dart`): (1) Header blanco con isotipo, (2) Banner superior de 5 KPIs cuantitativos interactivos (*Total salones, Por aprobar, Activos, En prueba, Gracia/Mora*), (3) Buscador universal en vivo por salón, titular, WhatsApp, correo o ciudad con chips de filtro rápido, (4) Tarjetas `_TenantCard` con botones rápidos de WhatsApp y llamada telefónica, (5) Ficha Completa Nivel 3 (`_TenantDetailSheet`) fiel al bosquejo del propietario (Datos de contacto, Plan y Tarifa fijada en COP, Botonera de gestión y Tabla de historial de pagos/periodos), (6) `EpaycoCheckoutService` con selector de planes interactivo (Básico, Business, Profesional) con cálculo automático del 50% Pionero. 156/156 pruebas en verde. **Ampliado el 23-ago (D-161)** a pedido del propietario tras pruebas reales y un segundo bosquejo suyo: la Tarjeta 1 de la Ficha Nivel 3 gana el botón "Editar Contacto" (RPC `platform_update_tenant_contact`, solo `platform_owner`) y muestra el nombre real del titular (`contact_name`, antes fingido con `correo.split('@').first`); la Tabla de historial (Tarjeta 4) pasa de dos filas sintéticas en memoria a consumir `platform_get_tenant_subscription_history` de verdad, con las 4 columnas del bosquejo (Fecha y Hora, Plan, Período Comprometido, Valor/Medio/Ref, con franquicia/banco/referencia de ePayco). El header (`main.dart`) gana una píldora verde con plan y fecha de corte cuando la suscripción está `ACTIVE`, pierde el botón suelto de "agregar sede" (reubicado en una tarjeta nueva de Configuración) y "+ Nueva Cita" abre el diálogo real en vez de solo cambiar de pestaña. El propio salón puede mantener su nombre de contacto titular, tipo de negocio, teléfono y WhatsApp desde Configuración (owner **o admin**) con la nueva RPC de autoservicio `update_tenant_contact_info`. Migración `20260823160000_contacto_titular_y_historial_completo.sql`, **aplicada en Supabase y verificada con el Control 181 contra la base real el 23-ago**. 156/156 pruebas en verde. **Refinado el mismo 23-ago (D-162):** la Tarjeta 1 se separa en A. Contacto Administrativo (agrega Teléfono, Ciudad e Instagram/Facebook de solo lectura) y B. Capacidad Operativa Real — en vivo, que reemplaza las "Sedes Estimadas"/"Equipo Estimado" del formulario de registro por conteos reales calculados en `platform_list_tenants()` (`real_branches_count` desde `branches.active`, `real_team_count`/`team_breakdown` desde `user_profiles`, con desglose por rol pluralizado, ej. "1 dueño, 2 admins, 3 estilistas"). El propio salón puede editar Instagram y Facebook desde Configuración (`update_tenant_contact_info` amplía de 4 a 6 parámetros). Migración `20260823170000_redes_sociales_y_equipo_real.sql`, **aplicada en Supabase y verificada con el Control 182 contra la base real el 23-ago**. 156/156 pruebas en verde. |

### FASE 5 — La cara pública

| # | Paso | Quién | Estado |
|---|---|---|---|
| 5.1 | Identificador único por negocio, sin ñ ni tildes (`salonymas.com/naguaradeunas`) | 🤖 | ✅ **CERRADO 27-ago (D-164).** Columna `slug` en `tenants`, `private.beautyos_slugify` (minúsculas, sin acentos ni eñe, separadores en guiones) y `private.beautyos_generate_unique_tenant_slug` (corto/reservado/largo/colisión con sufijo numérico). Backfill de los tenants existentes y `register_tenant` generándolo desde el nombre para los nuevos. Lista de palabras reservadas del sistema. Control `184_test_slugs_publicos.sql` |
| 5.2 | Función pública que lo resuelva sin sesión | 🤖 | ✅ **CERRADO 27-ago (D-164).** `get_public_salon_by_slug` (rol `anon`): solo datos de vitrina (nombre, tipo, logo, portada, tema, ciudad, dirección de la sede principal, WhatsApp, teléfono, Instagram, Facebook). `check_slug_availability` y `update_tenant_slug` (autoservicio, owner/admin) |
| 5.3 | Enrutado por ruta en Flutter y `_redirects` | 🤖 | ✅ **CERRADO 27-ago (D-164).** `web/_redirects` (`/* /index.html 200`, no existía) y `BeautyOSApp.build()` en `main.dart` resuelve el slug desde `Uri.base.pathSegments` (o `?salon=<slug>` de respaldo) antes de `AuthGate`, igual que las demás rutas públicas. `PublicSalonPage` nueva, con el mismo patrón visual que `PublicBookingPage` y el tema del negocio aplicado (D-093d) |
| 5.4 | Editarlo desde Configuración | 🤖 | ✅ **CERRADO 27-ago (D-164).** `PublicSalonLinkCard`: copiar, compartir por WhatsApp y "Modificar enlace" con comprobación de disponibilidad en vivo (debounce de 400 ms) contra `check_slug_availability`/`update_tenant_slug`. `get_business_settings` gana la columna `slug` |
| 5.5 | **La página del negocio:** portafolio, equipo, reseñas y reservar | 🤖 | ✅ **CERRADO 28-ago (D-165).** Cuatro RPC públicas nuevas (servicios, portafolio, equipo, reseñas) más `get_public_salon_by_slug` ampliada con `primary_branch_id` y `business_hours`. `PublicSalonPage` completa: encabezado con estrellas y botón "📅 Agendar Cita", servicios con "Reservar" que precarga la reserva, portafolio en grid con visor modal, equipo, reseñas y horarios/ubicación — secciones que se ocultan solas si no hay contenido. Control `185_test_perfil_publico_completo.sql`. 168/168 pruebas en verde. **Ampliado el 28-ago (D-166):** dirección física editable de la sede principal desde Configuración con botón "📍 Ver en Google Maps" en la página pública; `PublicBookingPage` retira "Conoce a nuestro equipo" (redundante con la página del negocio) y separa el servicio y el profesional en dos pasos (dropdown de servicio, luego dropdown de profesional con "Cualquiera disponible" combinando horarios de todos), botón renombrado a "Solicitar cita"; pantalla de éxito con WhatsApp al salón, Google Calendar y volver a la página del negocio. Migración `20260828180000` y control `186_test_direccion_sede_y_contacto.sql`. 168/168 pruebas en verde. **Migraciones `20260827160000` y `20260828180000` aplicadas en Supabase por el propietario.** |
| 5.6 | **Cuenta del cliente final:** ver sus fotos y su historial de visitas | 🤖 | ✅ **CERRADO 29-ago (D-167).** Portal "Mis citas y fotos" con PIN de 4 dígitos, asignado solo por el salón (nunca autoservicio — decisión de seguridad confirmada con el propietario). `client_portal_authenticate`/`get_client_portal_data` (RPC públicas, hash salado, bloqueo tras 5 intentos, token de 60 días) y `admin_reset_client_portal_pin` desde la Ficha del cliente. `ClientPortalPage`: próximas citas, fotos con visor modal (`PhotoGridViewer`, compartido con el portafolio de D-165) y calificar servicios pendientes. Control `187_test_habeas_data_y_portal_cliente.sql`. 176/176 pruebas en verde |
| 5.7 | **Permiso de publicación de la clienta** — hoy no existe el campo | 🤖 | ✅ **CERRADO 29-ago (D-167).** `work_photos.client_consent`/`client_consent_at`; `set_work_photo_portfolio_approval` rechaza publicar en portafolio sin consentimiento (Ley 1581); checkbox en `AddWorkPhotoDialog` e indicador visual en `FotosTrabajosPage`. Migración `20260829120000` **aplicada en Supabase y Control 187 (11 casos) en verde contra la base real**, tras corregir dos bugs reales encontrados al correrlo (ver D-167) |

### FASE 6 — El plan Profesional: IA, WhatsApp y redes

| # | Paso | Quién | Estado |
|---|---|---|---|
| 6.1 | ⭐ **"Tu negocio en palabras"** — el Dashboard contado en un párrafo | 🤖 | ✅ **CERRADO 29-ago (D-168).** `NarrativaNegocioBuilder` (`lib/widgets/tu_negocio_en_palabras_card.dart`): motor narrativo determinista, sin IA, sobre los datos que el Dashboard ya carga (`DashboardHoy`/`DashboardOverview`) — saludo por hora (mañana/tarde/noche), ritmo de citas, avisos de confirmar/cobrar/reactivar, tendencia de ventas solo con historia suficiente, y tres chips de acción a Agenda/Tickets/Clientes. Sin migración: no consume datos nuevos. 197/197 pruebas en verde |
| 6.2 | **Estudio de publicación:** foto estandarizada + reseña + datos, lista para Instagram | 🤖 | ✅ **CERRADO 29-ago (D-169), versión determinista.** `get_publication_studio_data`: junta servicio(s) del ticket y una reseña real de 4-5 estrellas (si existe) para una foto ya aprobada para portafolio. Composición 100% en Flutter (`RepaintBoundary.toImage()`, sin servidor de imágenes): tarjeta 1080×1080 con foto + logo + servicio + reseña opcional + WhatsApp, descargable como PNG vía `data:` URI (sin paquete nuevo). **No conecta con Instagram** (eso es 6.4, aparte). **Decisión de producto del propietario:** abierto a todos los planes por ahora, no exclusivo de Profesional como preveía D-124 — se restringe el día que se sume mejora con IA real. Botón en la Galería de fotos, habilitado solo con la foto ya publicada. 205/205 pruebas en verde |
| 6.3 | Respuestas a reseñas asistidas | 🤖 | ✅ **CERRADO 29-ago (D-170), versión determinista.** `ReviewReplyDraftBuilder`: plantilla por franja de calificación (5★/4★/3★/1-2★) con el nombre de la clienta y el servicio, que el salón edita antes de guardar. `set_review_reply` (owner/admin) guarda/edita/quita la respuesta; se publica bajo la reseña en la página pública del negocio. No exclusivo de ningún plan. 216/216 pruebas en verde |
| 6.4 | Publicación automática en Instagram | 🤖 | ⬜ **Requiere revisión de Meta** |
| 6.5 | **WhatsApp con agente:** servicios, horarios, disponibilidad, agendar | 🤖 | ⬜ **Requiere verificación de empresa con Meta. Semanas** |
| 6.6 | Blog de artículos de belleza y estética | 🤖 | ✅ **CERRADO 29-ago (D-171).** Blog **por cada salón** (decisión confirmada con el propietario), sin url propia por artículo todavía. Tabla `blog_posts` (tenant, no sede), bucket `blog-covers`, RPC autoservicio (`create`/`update`/`delete_blog_post`, `get_blog_posts_summary`) y pública (`get_public_salon_blog_posts`, solo publicados). Módulo "Blog" nuevo (owner/admin) y sección "Blog" en la página pública (D-165) con `PublicBlogPostPage` (`Navigator.push`, mismo patrón que reserva/reseñas). 222/222 pruebas en verde |

> ⚠️ **Nada de la fase 6 se vende como disponible hasta que exista.** Cobrar
> por WhatsApp e Instagram sin haberlos construido es una promesa que no se
> puede cumplir, y con el primer cliente eso no se recupera.

**Reglas de la IA, para que no se olviden:**

1. **La IA embellece la foto, nunca el trabajo.** Mejorar luz y encuadre, sí;
   "arreglar" unas uñas para que se vean mejor de lo que quedaron, jamás.
2. **La llave de la IA vive en el servidor**, nunca en la aplicación.
3. **Se descarta "sugerir horarios" y "rellenar huecos"** por el mismo motivo
   por el que se descartó el porcentaje de ocupación (D-110, D-114): el horario
   se guarda por negocio y no por profesional, así que sería inventar precisión.

### FASE 7 — Tu panel de dueño de la plataforma ✅ **CERRADA (30-ago)**

| # | Paso | Quién | Estado |
|---|---|---|---|
| 7.1 | Ver cada cliente: desde cuándo, cuántos periodos ha pagado, cuánto debe | 🤖 | ✅ **CERRADO 30-ago (D-172).** Antigüedad, períodos pagados, LTV en COP, mora con monto adeudado y botón WhatsApp de cobro cordial. Migración `20260829200000` y Control `191` aplicados y en verde (21/21 aserciones). 238/238 pruebas Flutter |
| 7.2 | **Cambiar tarifas y límites por cliente** — pantalla sobre `tenant_feature_overrides`, que ya existe | 🤖 | ✅ **CERRADO 30-ago (D-172).** RPCs `platform_get`/`set`/`delete_tenant_feature_override` y Tarjeta 5 en la Ficha Nivel 3 para conceder/revocar excepciones (sedes, equipo). Misma migración y control 191 |
| 7.3 | **Sistema de referidos:** quién trajo a quién y qué comisión le corresponde | 🤖 | ✅ **CERRADO 30-ago (D-173).** Partners con código propio, comisión configurable (% o fijo; primer pago/N meses/recurrente), generación automática al pagar por ePayco, liquidación consolidada. Migración `20260830100000` y Control `192` aplicados y en verde (22/22 casos en Supabase). 257/257 pruebas Flutter |
| 7.4 | Métricas del negocio SaaS: activos, morosos, cancelados, ingreso mensual | 🤖 | ✅ **CERRADO 30-ago (D-172).** Cabecera ejecutiva del SaaS (`platform_get_saas_metrics`): MRR estimado, recaudo histórico, salud de cartera y conversión prueba→pago. Misma migración y control 191 |

**Además, D-173 unificó visualmente el Panel de Plataforma:** se retiró la
`_PlatformKPIBanner` (5 tarjetas blancas redundantes con las píldoras de
filtro) y el cuerpo pasó a dos pestañas ejecutivas: `🏪 Salones Clientes` y
`🤝 Partners y Referidos`.

### FASE 8 — Limpieza técnica, seguridad y pulido final a producción

| # | Paso | Quién | Estado |
|---|---|---|---|
| 8.1 | Eliminar las 42 funciones que nadie llama (H-05), en dos pasos | 🤖 | ✅ **CERRADO 30-ago (D-176).** 30 funciones huérfanas purgadas con `DROP FUNCTION IF EXISTS`; 6 funciones internas blindadas con `COMMENT ON FUNCTION` "NO ELIMINAR". Migración `20260830160000` y Control `195` en verde en Supabase |
| 8.2 | Unificar las reglas de las columnas de dinero (H-08) | 🤖 | ✅ **CERRADO 30-ago (D-175).** Bug de `round(x, 2)` corregido a `round(x)` en comisiones; 14 candados `CHECK (col = round(col)) NOT VALID` aplicados y diagnosticados con 0 violaciones históricas. Migración `20260830140000` y Control `194` en verde en Supabase |
| 8.3 | Alinear el permiso suelto de Storage (H-11) | 🤖 | ✅ **CERRADO 30-ago (D-174).** Revocado de public/anon en `beautyos_can_upload_work_photo(uuid)`, solo authenticated. Migración `20260830120000` y Control `193` aplicados y en verde (3/3 casos en Supabase) |
| 8.4 | **Blindar Edge Functions y sincronizar configuración (Hallazgo U):** `verify_jwt = true` para funciones con sesión de usuario y declarar funciones de Smart Checkout en `config.toml` | 🤖 | ✅ **CERRADO 30-ago (D-177).** `verify_jwt = true` en `send-invitation-email`, `send-low-stock-alert` y `create-epayco-session`; `verify_jwt = false` en `epayco-webhook`, `verify-epayco-transaction` y alertas. 6 funciones desplegadas en la nube y verificadas con rechazo 401 perimetral sin sesión |
| 8.5 | **Clarificar pantalla de acceso para colaboradores invitados (Hallazgo S):** separar camino de dueño ("Registra tu salón") frente a empleado invitado ("Inicia sesión con tu correo") | 🤖 | ✅ **CERRADO 30-ago (D-178).** Subtítulo neutro ("Ingresa a tu cuenta") en `login_page.dart` con tarjeta guía para colaboradores invitados y botón explícito "Registra tu negocio gratis"; `register_page.dart` titulado como "Registra tu negocio" con enlace de retorno para invitados. 259 pruebas en verde |
| 8.6 | **Gestión de sedes para usuarios de equipo multi-sede (Hallazgo V):** interfaz en Usuarios y RPC para asignar/revocar acceso a sedes (`branch_memberships`) a un colaborador existente | 🤖 | ✅ Cerrado (D-179) |
| 8.7 | **Reenvío de correos de soporte `hola@salonymas.com` (Idea I-12):** activación en Cloudflare Email Routing para recibir respuestas de salones en Gmail | 👥 | ✅ **Cerrado 30-ago (D-180).** Enrutamiento en Cloudflare hacia `juankdev2026@gmail.com` desacoplado de Resend (que envía por `send.salonymas.com`). Documentación operativa en `docs/02_operacion/CORREO_Y_DOMINIO.md` |
| 8.8 | **Broche de oro: Onboarding guiado "Primeros pasos"** — checklist interactivo de bienvenida en Dashboard para salones nuevos | 🤖 | 🔄 **Escrito 01-sep (D-186).** `get_onboarding_progress` + `PrimerosPasosCard`: contador «X de 4», barra de avance y botón **Empezar** por paso. Los cuatro son servicios, equipo, horario y primera cita — el portafolio queda fuera porque desde D-184 es de plan Profesional. Desaparece sola al completarse. Migración `20260901180000` y Control `200`. 278/278 pruebas en verde. ✅ **CERRADO 01-sep: migración aplicada en Supabase y Control 200 en verde contra la base real, con `ROLLBACK` limpio** |
| 8.9 | 🔴 **Cerrar TL-01: `verify-epayco-transaction` activaba suscripciones con pagos hechos en otro comercio de ePayco.** Primer hallazgo de la auditoría de 4 revisiones del 01-sep | 🤖 | 🔄 **Escrito 01-sep (D-181).** `verify_jwt = true`, comparación de `x_cust_id_cliente` contra `EPAYCO_P_CUST_ID`, negocio resuelto desde `tenant_memberships` de quien llama, y eliminado el rastreo por prefijo de factura. `flutter analyze` 0/0 y 262/262 en verde. **Pendiente que el propietario despliegue y verifique contra una transacción real.** No cierra TL-02 |
| 8.10 | 🔴 **Cerrar TL-02: la firma de ePayco no cubre `x_extra1` ni `x_extra2`**, así que un pago propio legítimo se puede reenviar con el negocio cambiado. Necesita tabla de intenciones de pago generada en el servidor | 🤖 | 🔄 **Escrito 01-sep (D-182).** Tabla `subscription_payment_intents` (RLS deny-all), `beautyos_registrar_intencion_pago` y `beautyos_resolver_intencion_pago` (solo `service_role`). `create-epayco-session` registra la intención **antes** del checkout; `epayco-webhook` resuelve por `x_id_invoice` y **falla cerrado**. Retirado el rastreo por prefijo de factura. Migración `20260901120000` y Control `197`. ✅ **CERRADO 01-sep: migración aplicada en Supabase, Control 197 en verde (9 de 9 casos contra la base real, con el ataque de TL-02 rechazado y `ROLLBACK` limpio), y las dos Edge Functions desplegadas en la nube en el orden correcto** |

| 8.11 | 🔴 **Cerrar TL-04 y TL-05: el portal de la clienta permitía enumerar qué celulares son clientas de un salón**, sin tope y sin adivinar ningún PIN (Ley 1581), y además sin índice sobre la búsqueda por dígitos del teléfono | 🤖 | 🔄 **Escrito 01-sep (D-183).** Un solo mensaje para los cuatro casos de fallo, tiempo de respuesta igualado, e índice funcional `clients_tenant_phone_digits_idx`. Migración `20260901140000` y Control `198`. ✅ **CERRADO 01-sep: migración aplicada en Supabase y Control 198 en verde (9 de 9 casos contra la base real — oráculo eliminado, los cuatro mensajes idénticos, índice funcional verificado y `ROLLBACK` limpio)** |
| 8.12 | **Cerrar TL-06: el PIN del portal es `sha256` de una sola vuelta sobre 4 dígitos**, y 5 intentos errados bloquean a la clienta real sabiendo solo su celular | 🤖 | 🔄 **Escrito 01-sep (D-185).** bcrypt con `pgcrypto`, **migración al vuelo** de los hashes heredados cuando la clienta entra (nadie pierde su PIN), y bloqueo escalonado 1/5/30 min en vez de 15 planos. Migración `20260901160000` y Control `199`. ✅ **CERRADO 01-sep: migración aplicada en Supabase y Control 199 en verde (9 de 9 casos contra la base real — bcrypt activo, migración al vuelo probada, bloqueo escalonado y `ROLLBACK` limpio)** |
| 8.13 | 🔴 **Cerrar TL-19: la interfaz nunca consulta `get_my_entitlements()`.** Un salón en Básico ve módulos que no tiene, entra, y recibe una excepción de PostgreSQL en crudo. Toda la escalera de precios es invisible dentro del producto | 🤖 | 🔄 **Escrito 01-sep (D-184).** `EntitlementsService`, `requiredFeature` en `BeautyModule` y `PlanLockedPage`: el módulo **se ve con candado** (esconderlo mataría la venta) y explica qué gana al subir. Falla **abierto** a propósito. Acotado a Reportes, Inventario, Compras y Gastos, que son los que de verdad revientan (Fotos y Reseñas van aparte, en 8.14). Botón de WhatsApp a soporte con el mensaje pre-armado del módulo. ✅ **CERRADO 01-sep.** `flutter analyze` 0/0 y 271/271 pruebas en verde |
| 8.14 | **Candado por botón en Fotos de trabajos y Reseñas.** El Plan Maestro §3 las reserva al Profesional, pero `portfolio` solo protege `create_work_photo` y `reviews` solo `public_create_review`: bloquear el módulo entero escondería fotos que el salón ya tiene. Necesita candado en la acción, no en el módulo | 🤖 | ✅ **CERRADO 01-sep (D-187).** `mostrarCandadoDePlan` en los dos únicos sitios que abren esas acciones. **El caso de Reseñas era el peor:** el salón manda el enlace y es **la clienta** quien recibe el error. Al estilista se le da un mensaje distinto que al dueño. 279/279 pruebas en verde. **Cierra la auditoría de 4 revisiones** |

| 8.15 | 🔴 **Etapa 2 de D-188 — suscripción por sede.** Tabla propia con su estado y su ancla, la sede nace pendiente, `beautyos_precio_efectivo` por sede. Y el tope de equipo pasa a ser por sede: hoy `create_team_invitation` cuenta el tenant entero, así que la promesa de "10 por sede" (D-189) no es cierta para multi-sede hasta que se arregle aquí | 🤖 | ✅ **CERRADO 02-sep (D-190).** `branch_subscriptions` con estado, período y precio por sede; las sedes existentes **heredan lo que se les vendió** y solo las nuevas nacen pendientes; la plataforma las activa a mano hasta la Etapa 3. Migración `20260902120000` y Control `202`, en verde (9 de 9). **El tope de equipo por sede se resolvió en 8.18** (D-196); la pantalla del salón se resolvió en 8.16 |
| 8.16 | 🔴 **Etapa 3 de D-188 — ePayco por sede.** `create-epayco-session` y las intenciones de pago (D-182) con `branch_id`, prorrateo hasta la fecha ancla al activar a mitad de ciclo (reutiliza D-160), alertas y panel de plataforma por sede | 🤖 | ✅ **CERRADO 02-sep (D-191, D-192, D-193).** 3a: `branch_id` en las intenciones y `beautyos_calcular_cargo_sede` (migración `20260902140000`, Control `203`). 3b: `beautyos_procesar_pago_de_sede`, checkout y webhook con `branchId` (migración `20260902160000`, Control `204`), y la pantalla de sedes en Configuración con su estado y botón de pago — de paso se corrigió `epayco_checkout_service.dart`, que desde el 01-sep enseñaba los tres planes retirados con sus precios viejos. **Ya se puede vender la segunda sede.** Las alertas de vencimiento por sede se resolvieron en 8.18 (D-196) |
| 8.17 | **Bloque 1 "Velocidad Operativa de Mostrador": cita express, cobro directo y WhatsApp pre-armado.** Encargo directo del propietario citando UX-01/UX-03/UX-04/UX-05/UX-10 de la Revisión 2; esa numeración no coincidía con la de la auditoría verificada (UX-04 ahí es Onboarding, UX-05 quedó refutado) y se aclaró con el propietario antes de tocar código | 🤖 | ✅ **CERRADO 02-sep (D-195).** Cita express reutiliza "Cualquiera disponible" (D-166) en vez de saltarse el cálculo de disponibilidad, cerrando la mitad barata del hallazgo C-01. Botón "Cobrar" nuevo en la tarjeta de Agenda, mismo mecanismo que D-163, abriendo el pago directo sin la Ficha Completa (la lista de Tickets ya lo hacía, por eso UX-05 estaba refutado). WhatsApp con mensaje pre-armado vía `buildAppointmentReminderMessage`. `flutter analyze` 0/0 y **297 de 297 pruebas en verde** (5 nuevas). Sin migración: es un bloque de interfaz, no toca base de datos |
| 8.18 | 🔴 **Bloque 2 "Pulido Multi-Sede y Alertas de Suscripción": tope de equipo por sede y alertas de vencimiento por sede.** Los dos pendientes que D-189 (apartado del tope) y el HANDOFF de D-195 (apartado 3.1, alertas) dejaron escritos, ahora que la Etapa 2/3 de D-188 ya existe | 🤖 | ✅ **CERRADO 02-sep (D-196): aplicado en Supabase y verificado en producción.** `private.beautyos_require_team_limit` multiplica el tope (9) por las sedes activas: la principal cuenta si el negocio está `entitled` (cero regresión), las secundarias por su propio `branch_subscriptions.status`. `send-subscription-expiry-alerts` agrupa alertas de negocio y de sedes secundarias en un solo correo por dueño, y ya está desplegada en producción. Migración `20260902200000` aplicada y **Control `206` en verde: 10 de 10 casos, con `ROLLBACK` limpio** (tope multi-sede proporcional, cero regresión en la principal, alertas de sede agrupadas, y los permisos verificados). `flutter analyze` 0/0 y 297/297 pruebas en verde (sin cambios en Flutter: el bloque es de base de datos y Edge Function). No se construyó suspensión automática por sede: el encargo pedía alertas, no suspensión |
| 8.19 | **Bloque 3 "Pipeline de Integración Continua": `.github/workflows/ci.yml` corriendo `flutter analyze` y `flutter test` en cada push a `main` y cada pull request.** Cierra TL-07 de la auditoría técnica del 01-sep | 🤖 | ✅ **CERRADO 02-sep (D-197).** Flutter fijado en `3.44.2`/`stable` (misma versión de desarrollo). Sin secretos: la `publishableKey` es pública por diseño (TL-07 lo confirmó) y las pruebas usan servicios falsos, nunca la base real. `flutter analyze` sin `--fatal-infos` a propósito: hay 2 infos preexistentes que habrían roto el primer run sin que nadie tocara nada |

> **La auditoría de 4 revisiones del 01-sep** (técnica, UX, producto y crítica
> brutal/seguridad) está verificada hallazgo por hallazgo en
> `docs/01_arquitectura/auditorias/AUDITORIA_4_REVISIONES_2026-09-01.md`. Ese
> documento **no manda sobre este**: es el expediente de evidencia. Los pasos
> que salgan de él entran aquí, uno a uno, como 8.9, 8.10 y siguientes.

---

## 6. BUZÓN DE IDEAS

**Aquí caen las ideas cuando aparecen, sin interrumpir lo que se está
construyendo.** Cada una se mira al cerrar una fase y se manda a la que le
toque, o se descarta con su motivo.

| # | Idea | De cuándo | Destino |
|---|---|---|---|
| I-01 | Citas recurrentes **mensuales** (hoy solo diaria y semanal) | 07-ago | Sin asignar |
| I-02 | Crear una serie larga de citas es lento | 07-ago | Junto con I-01 |
| I-03 | **Cierre de sesión por inactividad** (30 min) — el riesgo real es la recepcionista que deja la sesión abierta | 07-ago | Sin asignar |
| I-04 | **Verificar el celular del cliente con un código** al reservar. Cierra del todo H-02. Cuesta por mensaje | 06-ago | Sin asignar |
| I-05 | **Que la reserva pública no ocupe el horario** hasta que el negocio confirme. Arreglo estructural de H-02 | 06-ago | Sin asignar |
| I-06 | **Pagos en línea para los negocios clientes**, que cada salón cobre a sus propias clientas. ⚠️ No confundir con ePayco cobrando la suscripción: es una pasarela por negocio, cambia la figura legal | 09-ago | Sin asignar — con contador |
| I-07 | Días específicos por sede para un estilista | 27-jul | Bajado de prioridad (D-074) |
| I-08 | Paquetes / membresías de sesiones para el cliente final | 28-jul | Pausado hasta que un negocio real lo pida |
| I-09 | Propinas — no existe ni la columna | 08-ago | Sin asignar |
| I-10 | Vista de ausencias de todo el equipo para el administrador | 27-jul | Sin asignar |
| I-11 | **Correos del salón a SUS clientas**: cumpleaños, recordatorios de cita. Idea del propietario, 09-ago | **No existe nada.** Decidido cómo se hará cuando toque: salen del dominio propio pero **con el nombre del salón como remitente** y respuesta al correo del salón, para que la clienta vea *"Naguara de Uñas"* y no *"Salón y Más"*. Van por **subdominio aparte**, para que si algún día caen en spam no arrastren a los correos de negocio. Fase 6 |
| I-12 | **Reenvío gratuito de `hola@salonymas.com` al Gmail del propietario** con Cloudflare Email Routing | ✅ **Cerrado 30-ago (D-180, Paso 8.7).** Enrutamiento en Cloudflare hacia `juankdev2026@gmail.com`. Arquitectura de cero colisiones con Resend (send vs raíz) y guía documentada en `docs/02_operacion/CORREO_Y_DOMINIO.md` |
| I-14 | ~~Decidir la matriz definitiva: qué módulo lleva cada plan.~~ | ✅ **RESUELTA 01-sep (D-188), y sin decidirse: ya no hay matriz.** Se retiró la escalera de tres planes y quedó uno solo con todo dentro, cobrado por sede. Las 15 casillas que esperaban cinco visitas a salones reales dejaron de existir. La idea del propietario —*«que los pequeños accedan a lo que solo tienen los grandes»*— se cumple entera: el salón de una sede paga menos que antes y tiene todo |
| I-13 | **Darle al asistente acceso directo a Supabase** con el conector oficial y un token revocable | Se aplazó el 09-ago hasta rotar las claves. **Ya están rotadas (D-127), así que la condición se cumplió.** Hoy el asistente dicta clics porque la extensión de Chrome tiene bloqueado el dominio de Supabase; con el conector leería registros y desplegaría funciones solo. **Es acceso permanente a producción: decisión del propietario, no del asistente** |
| I-15 | **El desglose "Ventas por Servicio" de Reportes (Nivel 3, D-154) puede cambiar de período con el tiempo.** `get_branch_reports_v3` ubica cada venta con `coalesce(t.closed_at, t.scheduled_at)`: un ticket "finalizado" (servicio prestado, saldo pendiente) aparece en el reporte del día del servicio mientras no se cierra; si se cierra días después, la venta se traslada silenciosamente al reporte del día de cierre. El total financiero de arriba (`total_received`) no tiene este problema porque usa `tp.received_at`, que es estable | 18-ago | Sin asignar — decidir a propósito si el desglose por servicio se ancla a `scheduled_at` (estable, mismo criterio que D-153) o se mantiene con `closed_at` (fecha de cierre contable, coherente con D-150). Hallazgo de la auditoría técnica del Paso 4.7 |
| I-16 | **Branding e identidad visual integral de Salón y Más** (diseño del logo definitivo, paleta extendida, manual de marca y kit de activos en alta resolución para marketing, pasarelas y material promocional). El propietario solicitó dejarlo explícitamente como último punto pendiente. | 23-ago | Último punto del backlog / Post-lanzamiento |

---

## 7. Deuda y hallazgos abiertos

> ✅ **`epayco_checkout_service.dart` quedó obsoleto con D-188 y nadie lo notó.**
> Ofrecía un desplegable con los tres planes retirados y sus precios viejos, y
> elegía `profesional` por defecto. El cobro salía bien, pero al dueño se le
> enseñaba un precio que no era el suyo. **Cerrado el 02-sep (D-193)**, y la
> corrección no fue actualizar las cifras: fue quitarlas del cliente, porque esa
> cuenta vive en el servidor.

### De la auditoría integral del 06-ago

| # | Hallazgo | Estado |
|---|---|---|
| H-01 | Rol Asistente sin pantallas | ✅ Cerrado (D-092) |
| H-02 | Reserva pública sin protección | ✅ Mitigado (D-092). Fondo en I-04, I-05 |
| H-03 | Sin pruebas de dinero ni roles | 🔄 Mitad hecha (D-121). **La otra mitad quedó desbloqueada el 12-ago:** ya existe base de ensayo (2.2) contra la que correr las pruebas solas |
| H-04 | Claves expuestas sin rotar | ✅ **Cerrado 09-ago (D-127)** |
| H-05 | 42 funciones heredadas | ✅ **Cerrado 30-ago (D-176, Paso 8.1)** |
| H-06 | Documento rector desactualizado | ✅ Cerrado — y este documento lo reemplaza |
| H-07 | `pubspec.lock` sin versionar | ✅ Cerrado (D-091) |
| H-08 | Columnas de dinero inconsistentes | ✅ **Cerrado 30-ago (D-175, Paso 8.2)** |
| H-09 | Archivos públicos permanentes | ✅ Cerrado (D-119) |
| H-10 | `social_publishing` sin nada detrás | 🔄 Es la fase 6 |
| H-11 | Permiso suelto de Storage | ✅ **Cerrado 30-ago (D-174, Paso 8.3)** |
| H-12 | Resend en sandbox: los correos no llegan | ✅ **Cerrado 10-ago (D-128)** |
| H-13 | Commits sin publicar | ✅ Cerrado |

### Anotados en el camino

| # | Hallazgo | Destino |
|---|---|---|
| **D** | La barra de celular podría llevar **acciones**, no módulos | Paso 4.10 |
| **G** | Restauración de ensayo del respaldo | Paso 2.2 |
| **N** | `TicketStatusBadge` contradice a D-097 y D-101 | Paso 4.5 |
| **Ñ** | **El flujo de las fotos no está definido:** quién las toma, cuándo, por dónde. Y los tipos "Final" y "Portafolio" sobran | Pasos 4.9 y 5.7 |
| **O** | Rediseño del panel de plataforma | Paso 4.11 |
| **P** | **El consecutivo de ticket no sirve como número contable** | Paso 4.4 |
| **Q** | **Ningún módulo se actualiza solo.** Empezó como "que el administrador se entere cuando el estilista finaliza", pero el 09-ago se comprobó que es general: **entrar a un módulo no recarga sus datos**, hay que pulsar Actualizar o F5. Se vio con las fotos, y aplica igual a Tickets, Clientes y el resto | Paso 4.3, ampliado a todos los módulos |
| **R** | 🔴 **Se puede invitar a DOS cuentas distintas al MISMO estilista del catálogo.** Lo encontró el propietario el 10-ago: invitó `elboga010` vinculándolo a "Erick Chaparro", que ya tenía cuenta con `elboga005`. **Quedaron dos usuarios llamados Erick Chaparro apuntando al mismo estilista.** **No es cosmético:** las dos cuentas ven la misma agenda, las mismas comisiones y las mismas fotos, porque todo cuelga del `stylist_id`, y no hay forma de saber cuál es la persona real. Se arregla **rechazando la invitación** cuando ese estilista ya tiene una cuenta activa vinculada. *(El duplicado real quedó suspendido, no borrado.)* | ✅ **Cerrado 11-ago (D-132).** Se adelantó a la fase 4 a petición del propietario, y la regla de oro pide decir por qué: **el duplicado ya existía en producción y cada invitación nueva podía crear otro.** Verificado con 7 controles y una prueba de escritura real |
| **Y** | 🔴 **El respaldo llevaba 4 días sin incluir el esquema `private`**, donde viven las **18 funciones que autorizan cada operación del negocio** (`beautyos_resolve_branch_access` la primera) y los disparadores que numeran el ticket. **Restaurarlo habría devuelto todos los datos con la aplicación inutilizada:** ni agenda, ni cobrar, ni fotos. `respaldo_supabase.ps1` volcaba solo `public`, `auth` y `storage` desde el 08-ago (D-111). **Nadie podía saberlo porque nadie había restaurado nunca un respaldo** | ✅ **Cerrado 12-ago (D-134).** Lo encontró el propio paso 2.2, que es exactamente para lo que existe. **Regla nueva en el guion: un esquema nuevo se añade a esa línea en el mismo cambio** |
| **Z** | **Al restaurar, el registro de archivos de Storage no vuelve.** `storage.objects` pasó de 11 filas a 0: en un Supabase gestionado no eres superusuario y esas tablas de plataforma no se dejan escribir. **Lo que SÍ vuelve es `public.work_photos`** (6 = 6), con el ticket, el cliente y el estilista de cada foto — o sea, **no se pierde a qué pertenece cada imagen**, solo hay que volver a subirlas desde `respaldo_archivos.ps1` | Documentar el procedimiento de recuperación de fotos. Fase 8, o antes si entra un cliente con muchas fotos |
| **X** | **La contraseña de la base de datos nunca se ha rotado.** No formaba parte de H-04 —aquello eran las claves `service_role` y `secret`— y por eso se quedó fuera del paso 2.1. Se escribe a mano en cada migración con `aplicar_sql.ps1` y **no se guarda en ningún archivo**, que es lo correcto. **No hay ninguna fuga conocida:** esto es higiene, no incendio | Fase 8, con el resto de limpieza. **Pasa a urgente si alguna vez se teclea en una sesión compartida, se pega en un chat o aparece en una captura** |
| **V** | **No hay forma de dar acceso a una segunda sede a alguien que ya tiene cuenta.** Encontrado el 11-ago verificando el hallazgo R: solo **tres** funciones insertan en `branch_memberships` — `register_tenant`, `create_branch` y `accept_team_invitation` — y ninguna sirve para eso; `create_branch` solo mete a quien crea la sede. **Consecuencia real con las dos sedes de hoy:** puedes asignar a una estilista a trabajar en la sede 2 en el catálogo (`branch_stylists`) y **su cuenta no podrá verla** (`branch_memberships`). Son dos cosas distintas y hoy solo se puede tocar una | ✅ **Cerrado 30-ago (D-179, Paso 8.6).** Migración `20260830170000`, RPCs `get_tenant_user_branches` y `set_tenant_user_branches` con sincronización en `branch_stylists`, modelo `UserBranchAccess` y selector interactivo de sedes en `_ManageUserDialog` (`UsuariosPage`). Control `196` y 262 pruebas en verde |
| **S** | **La pantalla de acceso solo le habla a los dueños.** Dice *"¿No tienes cuenta? Crea tu negocio"*, pero por ahí también entra un **empleado invitado**, que no viene a crear ningún negocio. Observación del propietario, 10-ago | ✅ **Cerrado 30-ago (D-178, Paso 8.5).** Subtítulo neutro en login ("Ingresa a tu cuenta") con guía para invitados por correo y botón destacado "Registra tu negocio gratis"; `RegisterPage` titulada "Registra tu negocio en Salón y Más" con enlace de retorno que asiste a empleados invitados |
| **T** | **`send-low-stock-alert` sigue rota por la misma causa que D-128.** Usa `withSupabase` con la dependencia anclada como `^1` | **Va a fallar igual que la de invitaciones.** Mismo arreglo: quitar esa librería y fijar la versión | ✅ **Cerrado el 11-ago** en el paso **2.7** (D-131) |
| **U** | **Las dos Edge Functions se pueden ejecutar sin ninguna cuenta** (`verify_jwt = false`). | ✅ **Cerrado 30-ago (D-177, Paso 8.4)** |

---

## 8. Reglas de trabajo — no negociables

> **Este apartado es el ÚNICO sitio donde se escriben las reglas.** `AGENTS.md`,
> `CLAUDE.md`, `README.md` y los HANDOFF apuntan aquí y no las repiten.
>
> **Por qué:** hasta el 11-ago las mismas reglas estaban escritas en **seis
> sitios** y ya decían cosas distintas — el Plan Maestro tenía 11 y el README 8,
> y al README le faltaba justo *"comparar línea por línea al reescribir"*, la
> que nació de tres fallos en un mismo día. Es la enfermedad que D-126 curó con
> los planes, sin aplicarla a las reglas. Corregido en D-131.

### Cómo hablamos

1. **Verificar en el código antes de afirmar.** No asumir. Confirmar el nombre
   exacto de tablas, columnas, RPC y políticas antes de escribir una migración:
   adivinar ya causó fallos reales.
2. **No inventar.** Si falta un dato de negocio o una decisión de producto,
   **preguntar**.
3. **Explicar en español claro, apto para una persona no técnica.** El porqué
   de las cosas, no solo el qué.
4. **Discutir con argumentos** antes que dar la razón. El propietario lo pidió
   así expresamente.

### Cómo se construye

5. **Antes de construir, decir en dos líneas qué y por qué**, y esperar
   confirmación.
6. Cuando haya varios puntos, **repetirlos en una lista** para confirmar que se
   entendieron **antes** de resolver.
7. **Un bloque a la vez.** Una pieza por turno. Al terminar: qué se hizo, qué
   falta, y esperar confirmación.
8. **Tarea grande = primero un plan** con pasos numerados y una recomendación
   de por dónde empezar. Código después.
9. Preguntar **"¿algo más antes de seguir?"** antes de cerrar cada bloque.
10. **Al reescribir una función, compararla línea por línea contra la
    original**, no solo la firma. Tres fallos de un mismo día salieron de ahí
    (D-119, D-122, D-123).
11. **Después de implementar:** pruebas proporcionales, `flutter analyze`, y
    documentar el resultado.

### Qué se puede tocar y qué no

12. **Pedir permiso antes de tocar Cloudflare o hacer `push`.**
13. **Publicar Edge Functions no necesita permiso** desde el 11-ago (D-131): el
    propietario autorizó la CLI justamente para eso. Se avisa, no se pregunta.
    **Todo lo demás de Supabase sigue necesitando permiso.**
14. **Cualquier instalación en el computador del propietario la ejecuta él.**
15. **Respaldar antes de cada sesión con migraciones:**
    `powershell -ExecutionPolicy Bypass -File scripts\respaldo_supabase.ps1`
16. **Las migraciones las aplica el propietario:**
    `powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" -Archivo "<ruta>"`

### Qué queda escrito

17. **Registrar cada decisión con su porqué**, incluyendo lo descartado.
18. **Regla de hallazgos:** lo que aparezca se anota y se ataca donde le
    corresponde. Si no cabe en ninguna fase, va al **buzón de ideas**.
19. **Toda edición documental automática comprueba que su ancla existe ANTES de
    sustituir, y que el texto quedó escrito DESPUÉS.** Y no se afirma en un
    commit ni en un handoff que algo quedó escrito sin haberlo comprobado
    (D-129).
20. **Señalar contradicciones y duplicados encontrados**, sin resolverlos por
    iniciativa propia.

### Quién verifica de verdad

21. **El propietario prueba en producción y reporta.** El asistente no ve la
    interfaz — y el 09-ago eso encontró tres fallos que ninguna prueba vio.
    **Su prueba no es un trámite: es parte de la verificación.**

### Cuando trabaja más de un asistente

> **Desde el 12-ago el proyecto lo pueden tocar varios asistentes distintos**
> (D-137). El riesgo nuevo no es que uno se equivoque: es que **dos trabajen
> sin verse**. Estas tres reglas lo evitan.

22. **El repositorio es la única fuente de verdad, y quien construye es quien
    registra.** Cualquier asistente que construya algo lo deja escrito **en el
    mismo cambio**: la decisión con su porqué, su línea en el índice, el Plan
    Maestro actualizado y el HANDOFF. **Lo que no está escrito no existe** —
    porque el siguiente asistente no tiene forma de saberlo.
23. **Un solo HANDOFF vigente, y se reemplaza, nunca se duplica.** Antes de
    escribir uno nuevo hay que **leer el que hay** y archivar el anterior en
    `_archivo/handoffs/`. Dos HANDOFF a la vez es la enfermedad de D-126 con
    otro nombre.
24. **Antes de proponer nada, comprobar si el repositorio avanzó sin que el
    HANDOFF lo cuente.** Si hay commits posteriores al último HANDOFF,
    **otro asistente trabajó**: hay que leer ese `git log` y cerrar el hueco
    **antes** de tocar nada. Proponer sobre un estado viejo es cómo se
    reconstruye a ciegas lo que ya estaba hecho.


---

## 9. Mapa de documentos

### Vivos

| Documento | Su trabajo |
|---|---|
| **PLAN_MAESTRO.md** *(este)* | Qué falta y en qué orden |
| **REGISTRO_DE_DECISIONES.md** | Por qué está hecho así. **Solo crece** |
| **HANDOFF/** *(el más reciente)* | Dónde quedamos hoy |
| **README.md** | El mapa de entrada |
| `ESPECIFICACION_AGENDA_2026-08-07.md` | Contrato del tablero (fase 4) |
| `ESPECIFICACION_DASHBOARD_2026-08-08.md` | Contrato del Dashboard |
| `AUDITORIA_INTEGRAL_2026-08-06.md` | Los 14 hallazgos |
| `BENCHMARKING_2026-07-28.md` | Comparación con AgendaPro |
| `02_operacion/RESPALDO_Y_RESTAURACION_SUPABASE.md` | Cómo respaldar y restaurar |
| `02_operacion/CORREO_Y_DOMINIO.md` | Cómo está montado el correo y qué mirar cuando falle |
| **`02_operacion/MAPA_TECNICO.md`** | **Dónde está cada cosa y cómo se publica.** El proyecto de Supabase, la CLI, los guiones, qué cubren las pruebas y qué no, y las trampas que ya mordieron (D-131) |
| `01_arquitectura/ADR/` | Las 5 decisiones estructurales |
| `01_arquitectura/ROLES_Y_PERMISOS.md`, `SUSCRIPCION_Y_ENTITLEMENTS.md` | Referencia de arquitectura |

### Archivados en `docs/_archivo/`

68 documentos: 10 handoffs viejos, ~45 auditorías de tramos de julio, los 3
documentos de la Fase 1 y los 7 planes que este documento reemplaza. **No se
borraron:** guardan el porqué de lo que hoy está construido.

---

## 10. Costos

| Concepto | Cuándo | Costo |
|---|---|---|
| Dominio | Fase 0 ✅ | ~12 USD **al año** |
| Hosting (Cloudflare Pages) | Fase 0 ✅ | **$0**, tráfico ilimitado |
| Supabase Free | Fases 0–2 | **$0** |
| Supabase Pro | Fase 3 | ~25 USD/mes |
| Resend | Fase 3 | $0 hasta 3.000 correos/mes |
| ePayco | Fase 3 | % por transacción |
| Dominios propios de clientes | Fase 5 | **$0 los primeros 100**, luego 0,10 USD/mes |
| IA | Fase 6 | Por uso — de ahí el límite de 50 publicaciones/mes |

> **El dato que ordena todo: el costo fijo son ~$105.000 COP al mes y NO crece
> con cada cliente.** Un cliente Básico pionero casi lo cubre. El segundo ya es
> ganancia.

---

*Este documento se revisa al cerrar cada fase. Si una decisión cambia, se
registra primero en `REGISTRO_DE_DECISIONES.md` y luego se refleja aquí.*
