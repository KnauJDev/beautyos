# PLAN MAESTRO — Salón y Más

**Creado:** 9 de agosto de 2026 · **Última revisión:** 9 de agosto de 2026
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
| **Usuarios** | Invitar y gestionar | ⚠️ **Las invitaciones no llegan** (H-12) | F2.3 |
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

### FASE 2 — Seguridad y red de protección 🔄 **AQUÍ ESTAMOS** (4 de 6)

| # | Paso | Quién | Estado |
|---|---|---|---|
| 2.1 | **Rotar las claves `service_role` y `secret`** (H-04). Expuestas el 03-ago | 👥 | ✅ **CERRADO 09-ago (D-127).** Se borró la clave secreta y se **desactivaron** las claves antiguas — mejor que rotarlas. Verificado de extremo a extremo en producción |
| 2.2 | Restaurar un respaldo de ensayo en un segundo proyecto gratuito (D-111) | 👥 | ⬜ |
| 2.3 | **Verificar el dominio en Resend** (H-12). Hoy ningún correo llega a nadie | 👥 | ⬜ **Bloquea F3.7** |
| 2.4 | Cerrar los almacenes de archivos (H-09) | 🤖 | ✅ D-119 |
| 2.5 | Marcar "Naguara de Uñas" como negocio de prueba | 🤖 | ✅ D-120 |
| 2.6 | Pruebas de las 3 reglas de dinero y de los roles (H-03) | 🤖 | ✅ D-121 — la mitad automática espera a 2.2 |

### FASE 3 — Poder cobrar — *el camino corto al primer cliente*

| # | Paso | Quién | Estado |
|---|---|---|---|
| 3.1 | Confirmar con ePayco si admite **cobros recurrentes** | 👤 | ✅ **CONFIRMADO 09-ago: la cuenta sí admite cobros recurrentes.** Era el mayor riesgo de esta fase y quedó descartado |
| 3.2 | Consultar a un contador las obligaciones al facturar (DIAN, IVA) | 👤 | ⬜ |
| 3.3 | Términos de servicio y política de privacidad (Ley 1581) | 👥 | ⬜ **Obligatorio: se manejan datos de terceros** |
| 3.4 | Subir Supabase a plan Pro (~25 USD/mes) | 👤 | ⬜ |
| 3.5 | Cargar los 3 planes con precios de lista y límites | 🤖 | ⬜ |
| 3.6 | **Precio y descuento por cliente** en la suscripción (columnas nuevas) | 🤖 | ⬜ |
| 3.7 | **Filtro de aceptación:** formulario, estado `pending`, aprobar/rechazar. La prueba gratis **empieza al aprobar** | 🤖 | ⛔ necesita 2.3 |
| 3.8 | Pantalla pública de planes (`list_public_plans` ya existe, dormida) | 🤖 | ⬜ |
| 3.9 | **ePayco con confirmación en el servidor.** Nunca creerle al navegador | 🤖 | ⬜ |
| 3.10 | Pago → suscripción: activar, renovar, manejar el fallido | 🤖 | ⬜ |
| 3.11 | Avisos por correo **10, 5 y 3 días** antes de vencer | 🤖 | ⛔ necesita 2.3 |

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
| 4.8 | Inventario, Compras y Gastos: pulido visual | 🤖 | ⬜ |
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

---

## 7. Deuda y hallazgos abiertos

### De la auditoría integral del 06-ago

| # | Hallazgo | Estado |
|---|---|---|
| H-01 | Rol Asistente sin pantallas | ✅ Cerrado (D-092) |
| H-02 | Reserva pública sin protección | ✅ Mitigado (D-092). Fondo en I-04, I-05 |
| H-03 | Sin pruebas de dinero ni roles | 🔄 Mitad hecha (D-121). La otra mitad necesita 2.2 |
| H-04 | Claves expuestas sin rotar | ✅ **Cerrado 09-ago (D-127)** |
| H-05 | 42 funciones heredadas | ⬜ Paso 8.1 |
| H-06 | Documento rector desactualizado | ✅ Cerrado — y este documento lo reemplaza |
| H-07 | `pubspec.lock` sin versionar | ✅ Cerrado (D-091) |
| H-08 | Columnas de dinero inconsistentes | ⬜ Paso 8.2 |
| H-09 | Archivos públicos permanentes | ✅ Cerrado (D-119) |
| H-10 | `social_publishing` sin nada detrás | 🔄 Es la fase 6 |
| H-11 | Permiso suelto de Storage | ⬜ Paso 8.3 |
| H-12 | **Resend en sandbox: los correos no llegan** | ⬜ **Paso 2.3** |
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

---

## 8. Reglas de trabajo — no negociables

1. **Verificar en el código antes de afirmar.** No asumir.
2. **Antes de construir, decir en dos líneas qué y por qué**, y esperar
   confirmación.
3. Cuando haya varios puntos, **repetirlos en una lista** para confirmar que se
   entendieron **antes** de resolver.
4. Preguntar **"¿algo más antes de seguir?"** antes de cerrar cada bloque.
5. **Registrar cada decisión con su porqué**, incluyendo lo descartado.
6. **Regla de hallazgos:** lo que aparezca se anota y se ataca donde le
   corresponde. Si no cabe en ninguna fase, va al **buzón de ideas**.
7. **Pedir permiso antes de tocar Supabase, Cloudflare o hacer push.**
8. **Cualquier instalación en el computador del propietario la ejecuta él.**
9. **Respaldar antes de cada sesión con migraciones:**
   `powershell -ExecutionPolicy Bypass -File scripts\respaldo_supabase.ps1`
10. **El propietario prueba en producción y reporta.** El asistente no ve la
    interfaz — y el 09-ago eso encontró tres fallos que ninguna prueba vio.
11. **Al reescribir una función, compararla línea por línea contra la
    original**, no solo la firma. Tres fallos de un mismo día salieron de ahí
    (D-119, D-122, D-123).

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
