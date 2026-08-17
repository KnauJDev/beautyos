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

## 3. Los planes, los precios y los límites

**Decidido el 09-ago (D-124), corrige a D-004.**

### Qué incluye cada plan

| Capacidad | Básico | Business | Profesional |
|---|:---:|:---:|:---:|
| Sedes, clientes, equipo, servicios y agenda | ✅ | ✅ | ✅ |
| Reserva pública web / QR | ✅ | ✅ | ✅ |
| Estados, choques de agenda y operación diaria | ✅ | ✅ | ✅ |
| Pagos, caja y comisiones | ✅ | ✅ | ✅ |
| Inventario, compras y gastos | ❌ | ✅ | ✅ |
| Reportes financieros ampliados | ❌ | ✅ | ✅ |
| **"Tu negocio en palabras" (IA)** | ❌ | ✅ | ✅ |
| Fotos de trabajos | ❌ | ❌ | ✅ |
| Reseñas | ❌ | ❌ | ✅ |
| **Estudio de publicación (IA)** | ❌ | ❌ | ✅ |
| **Respuestas a reseñas asistidas (IA)** | ❌ | ❌ | ✅ |
| WhatsApp con agente e Instagram automático | ❌ | ❌ | ✅ *(fase 6)* |

### Precios

| | Precio de lista | **Precio pionero** |
|---|---:|---:|
| **Básico** | $160.000 | **$80.000** |
| **Business** | $200.000 | **$100.000** |
| **Profesional** | $240.000 | **$120.000** |

- **25 pioneros**, 50% de descuento, **de por vida mientras sigan activos.**
- **Por qué de por vida y no 6 meses:** al mes 7 el precio se duplicaría y se
  irían justo los 25 primeros, que son los que dan las referencias. Son
  ~$2.000.000/mes de base garantizada y los mejores vendedores que va a tener.
- **Todo esto es modificable desde el panel del dueño de la plataforma**, por
  cliente y con motivo registrado.

> ⚠️ **A precio de lista ya no se compite por precio.** El Básico a $160.000
> queda por encima de los ~$137.000 de la competencia. **Es a propósito:** a
> partir del cliente 26 el argumento es ser local, con soporte en su horario y
> factura colombiana — y para entonces habrá 25 salones funcionando que lo
> demuestren.

### Límites por plan

| | Básico | Business | Profesional |
|---|:---:|:---:|:---:|
| Sedes | 1 | 3 | Sin límite |
| Cuentas de equipo | 5 | 15 | Sin límite |
| Clientes, citas y tickets | Sin límite | Sin límite | Sin límite |
| Almacenamiento de fotos | — | — | 5 GB |
| Publicaciones asistidas por IA | — | — | 50 al mes |

**Los criterios, para que no se toquen sin pensar:**

- **Se limita lo que cuesta plata** (almacenamiento, IA) **y lo que vale más**
  (sedes, cuentas). Nada más.
- **No se limitan clientes, citas ni tickets a propósito:** es lo que más usa el
  salón, pesa kilobytes, y limitarlo se siente mezquino justo donde el producto
  debe sentirse generoso.
- **Todos los límites son negociables por cliente** con
  `tenant_feature_overrides`, que ya existe desde julio con motivo, vigencia y
  autor.

---

## 4. Estado real, módulo a módulo

Un dueño ve **16 módulos**. Esto es lo que hay hoy.

| Módulo | Qué hace hoy | Qué le falta | Dónde se arregla |
|---|---|---|---|
| **Dashboard** | ✅ 4 indicadores comparados, gráfico, agenda de hoy, avisos | "Tu negocio en palabras" | F6.1 |
| **Agenda** | Lista básica. **234 líneas** | Pasa a ser el tablero día/semana/mes | F4.2, F4.3 |
| **Tickets** | Panel completo de cobro. **3.699 líneas** | Nivel 2 y 3; número de venta; píldora de estado | F4.4, F4.5 |
| **Clientes** | Solo lista | Nuevos vs recurrentes, retorno, valor, quién dejó de venir. Falta apellido separado | F4.6 |
| **Reportes** | Ventas + resultado financiero | Nivel 2 y 3, métodos de pago, comparación entre períodos | F4.7 |
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
| 3.10 | Pago → suscripción: activar, renovar, manejar el fallido | 🤖 | ✅ **CERRADO 17-ago (D-141).** RPC `private.beautyos_procesar_evento_epayco` (solo `service_role`) que transiciona de inmediato a `active` por 1 mes al confirmar pago (reactivación automática). Si falla un cobro en negocio activo, pasa a `past_due` con 5 días de gracia (D-141). Botón de checkout multimetodo ePayco en Flutter (`EpaycoCheckoutService`), banner de gracia con cuenta regresiva día a día en `main.dart`, y tarjeta de Suscripción en Configuración. 103/103 pruebas en verde |
| 3.11 | Avisos por correo **10, 5 y 3 días** antes de vencer | 🤖 | ✅ **CERRADO 17-ago (D-143).** Edge Function `send-subscription-expiry-alerts` con Resend (`hola@salonymas.com`), tabla `subscription_notification_logs` con filtro anti-spam diario, cuenta regresiva diaria durante los 5 días de gracia, botón directo de pago en ePayco y suspensión automática de cuentas que agotaron la gracia (`private.beautyos_suspender_suscripciones_vencidas`). 106/106 pruebas en verde |
| 3.12 | 🔴 **Se adelantó a la Fase 2 a propósito** — la regla de oro pide anotar por qué: el tope de correos se agota probando, así que **bloqueaba las pruebas de ese día**, no solo las ventas de mañana. **Que los correos de cuenta salgan por Resend, no por Supabase.** El *"Confirma tu correo"* del registro lo mandaba el servicio interno de Supabase (`noreply@mail.app.supabase.io`), con un **tope diario bajísimo** que el propietario agotó el 10-ago probando (`email rate limit exceeded`) | 👥 | ✅ **CERRADO 11-ago (D-133).** SMTP de Supabase Auth apuntando a Resend. **Verificado de extremo a extremo:** el correo llegó desde `hola@salonymas.com`, Resend lo registró con `200`, y el registro se completó. El tope subió solo a 30/hora. **Queda el hallazgo W: esos correos están en inglés** |
| 3.13 | **Traducir las plantillas de correo de cuenta** (hallazgo W) — confirmar registro, invitación, recuperar contraseña, cambio de correo y reautenticación | 👥 | ⬜ **Antes del primer cliente** |

### FASE 4 — Pulido módulo a módulo

| # | Paso | Quién | Estado |
|---|---|---|---|
| 4.1 | Número de ticket consecutivo y ajustable | 🤖 | ✅ D-117 |
| 4.2 | Las dos funciones del tablero de agenda | 🤖 | ⬜ |
| 4.3 | **El tablero:** día, semana, mes + buscador múltiple + refresco automático | 🤖 | ⬜ |
| 4.4 | **Número de venta** al cerrar el ticket (hallazgo P) | 🤖 | ⬜ |
| 4.5 | Tickets: pulido del nivel 2 y 3 + cambiar `TicketStatusBadge` por `StatusPill` (hallazgo N) | 🤖 | ⬜ |
| 4.6 | Clientes: análisis de retorno y valor. Decidir si se separa el apellido | 🤖 | ⬜ |
| 4.7 | Reportes: nivel 2 y 3, métodos de pago, comparación | 🤖 | ⬜ |
| 4.8 | Inventario, Compras y Gastos: pulido visual. **Y el plural de las unidades en el correo de stock bajo**: hoy dice *"quedó con 3 unidad"* y *"el mínimo (5 unidad)"*, porque la unidad se guarda en singular. Con unidades como `ml` o `gr` se lee bien; con `unidad` no. Visto el 11-ago en el correo real | 🤖 | ⬜ |
| 4.9 | Servicios, Estilistas y Configuración: pulido, producción por persona, numeración ajustable, tipos de foto. **Y la galería de fotos: mostrar el número de ticket y poder filtrar por cliente y por estilista** | 🤖 | ⬜ |
| 4.10 | **Barra inferior de celular con acciones**, no módulos (hallazgo D) | 🤖 | ⬜ |
| 4.11 | Rediseño del panel de plataforma (hallazgo O) | 🤖 | ⬜ |

### FASE 5 — La cara pública

| # | Paso | Quién | Estado |
|---|---|---|---|
| 5.1 | Identificador único por negocio, sin ñ ni tildes (`salonymas.com/naguaradeunas`) | 🤖 | ⬜ |
| 5.2 | Función pública que lo resuelva sin sesión | 🤖 | ⬜ |
| 5.3 | Enrutado por ruta en Flutter y `_redirects` | 🤖 | ⬜ |
| 5.4 | Editarlo desde Configuración | 🤖 | ⬜ |
| 5.5 | **La página del negocio:** portafolio, equipo, reseñas y reservar | 🤖 | ⬜ **Falta especificar** |
| 5.6 | **Cuenta del cliente final:** ver sus fotos y su historial de visitas | 🤖 | ⬜ |
| 5.7 | **Permiso de publicación de la clienta** — hoy no existe el campo | 🤖 | ⬜ **Legal** |

### FASE 6 — El plan Profesional: IA, WhatsApp y redes

| # | Paso | Quién | Estado |
|---|---|---|---|
| 6.1 | ⭐ **"Tu negocio en palabras"** — el Dashboard contado en un párrafo | 🤖 | ⬜ **La de más valor por menos trabajo** |
| 6.2 | **Estudio de publicación:** foto estandarizada + reseña + datos, lista para Instagram | 🤖 | ⬜ |
| 6.3 | Respuestas a reseñas asistidas | 🤖 | ⬜ |
| 6.4 | Publicación automática en Instagram | 🤖 | ⬜ **Requiere revisión de Meta** |
| 6.5 | **WhatsApp con agente:** servicios, horarios, disponibilidad, agendar | 🤖 | ⬜ **Requiere verificación de empresa con Meta. Semanas** |
| 6.6 | Blog de artículos de belleza y estética | 🤖 | ⬜ |

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

### FASE 7 — Tu panel de dueño de la plataforma

| # | Paso | Quién | Estado |
|---|---|---|---|
| 7.1 | Ver cada cliente: desde cuándo, cuántos periodos ha pagado, cuánto debe | 🤖 | ⬜ |
| 7.2 | **Cambiar tarifas y límites por cliente** — pantalla sobre `tenant_feature_overrides`, que ya existe | 🤖 | ⬜ |
| 7.3 | **Sistema de referidos:** quién trajo a quién y qué comisión le corresponde | 🤖 | ⬜ **Nada construido** |
| 7.4 | Métricas del negocio SaaS: activos, morosos, cancelados, ingreso mensual | 🤖 | ⬜ |

### FASE 8 — Limpieza técnica

| # | Paso | Quién | Estado |
|---|---|---|---|
| 8.1 | Eliminar las 42 funciones que nadie llama (H-05), en dos pasos | 🤖 | ⬜ |
| 8.2 | Unificar las reglas de las columnas de dinero (H-08) | 🤖 | ⬜ |
| 8.3 | Alinear el permiso suelto de Storage (H-11) | 🤖 | ⬜ |
| 8.4 | Onboarding guiado "Primeros pasos" | 🤖 | ⬜ |

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
| I-12 | **Reenvío gratuito de `hola@salonymas.com` al Gmail del propietario** con Cloudflare Email Routing | Hoy esa dirección **solo envía, no recibe**: si un cliente responde una invitación, ese mensaje se pierde. Es gratis y son cinco minutos. **No confligue con Resend**: el MX de Resend vive en `send.`, el del reenvío iría en la raíz |
| I-14 | 🔴 **Decidir la matriz definitiva: qué módulo lleva cada plan.** El propietario **no está decidido**, y tiene una idea buena que la cambiaría: *"ayudar a los pequeños centros de estética a acceder a lo que solo tienen los grandes"* — las fotos visibles en el Básico, la publicación en Instagram en el Profesional. 12-ago | **Se aplazó a propósito (D-136), y no es pereza:** si hoy se mueven las fotos al Básico, **el Profesional se queda sin nada exclusivo que exista** — Instagram y la IA son Fase 6 y no están construidos. La matriz son **15 casillas**: una instrucción hoy, un clic desde el panel en la Fase 7. **Se decide después de las primeras cinco visitas a salones reales**, que es el dato que falta. ⚠️ **Y hay que resolver una discrepancia:** la imagen que maneja el propietario tiene 10 filas y este documento 12 — a la imagen le faltan las tres capacidades de IA de D-124 y le sobra *"WhatsApp asistido (enlace)"*, que no está escrito en ninguna parte |
| I-13 | **Darle al asistente acceso directo a Supabase** con el conector oficial y un token revocable | Se aplazó el 09-ago hasta rotar las claves. **Ya están rotadas (D-127), así que la condición se cumplió.** Hoy el asistente dicta clics porque la extensión de Chrome tiene bloqueado el dominio de Supabase; con el conector leería registros y desplegaría funciones solo. **Es acceso permanente a producción: decisión del propietario, no del asistente** |

---

## 7. Deuda y hallazgos abiertos

### De la auditoría integral del 06-ago

| # | Hallazgo | Estado |
|---|---|---|
| H-01 | Rol Asistente sin pantallas | ✅ Cerrado (D-092) |
| H-02 | Reserva pública sin protección | ✅ Mitigado (D-092). Fondo en I-04, I-05 |
| H-03 | Sin pruebas de dinero ni roles | 🔄 Mitad hecha (D-121). **La otra mitad quedó desbloqueada el 12-ago:** ya existe base de ensayo (2.2) contra la que correr las pruebas solas |
| H-04 | Claves expuestas sin rotar | ✅ **Cerrado 09-ago (D-127)** |
| H-05 | 42 funciones heredadas | ⬜ Paso 8.1 |
| H-06 | Documento rector desactualizado | ✅ Cerrado — y este documento lo reemplaza |
| H-07 | `pubspec.lock` sin versionar | ✅ Cerrado (D-091) |
| H-08 | Columnas de dinero inconsistentes | ⬜ Paso 8.2 |
| H-09 | Archivos públicos permanentes | ✅ Cerrado (D-119) |
| H-10 | `social_publishing` sin nada detrás | 🔄 Es la fase 6 |
| H-11 | Permiso suelto de Storage | ⬜ Paso 8.3 |
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
| **W** | 🔴 **Los correos de cuenta están en INGLÉS.** Visto el 11-ago en el correo real: *"Confirm your email address — Follow the link below to confirm this email address and finish signing up."* Son las plantillas de fábrica de Supabase. **Y es el PRIMER correo que recibe tu clienta**, que es la dueña de un salón en Colombia y no tiene por qué saber inglés. Un correo en inglés en el primer contacto dice *"esto es una herramienta extranjera"* — justo lo contrario del argumento de venta a partir del cliente 26, que es **ser local**. Son 6 plantillas en Authentication → Emails → Templates | **No se arregló el mismo día a propósito**, mismo criterio que el hallazgo U: no se cambia algo de rebote mientras se cierra otra cosa. Paso **3.13**, antes del primer cliente |
| **V** | **No hay forma de dar acceso a una segunda sede a alguien que ya tiene cuenta.** Encontrado el 11-ago verificando el hallazgo R: solo **tres** funciones insertan en `branch_memberships` — `register_tenant`, `create_branch` y `accept_team_invitation` — y ninguna sirve para eso; `create_branch` solo mete a quien crea la sede. **Consecuencia real con las dos sedes de hoy:** puedes asignar a una estilista a trabajar en la sede 2 en el catálogo (`branch_stylists`) y **su cuenta no podrá verla** (`branch_memberships`). Son dos cosas distintas y hoy solo se puede tocar una | Fase 4, junto con el pulido de Usuarios. **Antes de vender a un salón de varias sedes** |
| **S** | **La pantalla de acceso solo le habla a los dueños.** Dice *"¿No tienes cuenta? Crea tu negocio"*, pero por ahí también entra un **empleado invitado**, que no viene a crear ningún negocio. Observación del propietario, 10-ago | Confunde justo a quien acaba de recibir una invitación. Se resuelve separando los dos caminos: *"Crea tu negocio"* y *"Te invitaron a un equipo"*. Pulido de la pantalla de acceso, fase 4 |
| **T** | **`send-low-stock-alert` sigue rota por la misma causa que D-128.** Usa `withSupabase` con la dependencia anclada como `^1` | **Va a fallar igual que la de invitaciones.** Mismo arreglo: quitar esa librería y fijar la versión | ✅ **Cerrado el 11-ago** en el paso **2.7** (D-131) |
| **U** | **Las dos Edge Functions se pueden ejecutar sin ninguna cuenta** (`verify_jwt = false`). **Los datos NO están expuestos** — quien autoriza es la función de base de datos, que exige sesión de dueño o administrador de esa sede —, pero **cualquiera puede hacerlas correr en vacío y gastar cuota**. Encontrado el 11-ago al publicar la de stock. **No lo decidió nadie:** lo generó Supabase con sus valores por defecto al crear `config.toml` el 27-jul, y nunca se revisó | Se probó a propósito **no arreglarlo en el mismo movimiento**: cambiar un ajuste de seguridad de rebote, mientras se arregla otra cosa, es cómo se cuelan los fallos que después nadie sabe explicar (D-131) | Fase 8, junto con H-11 (el otro permiso suelto) |

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
