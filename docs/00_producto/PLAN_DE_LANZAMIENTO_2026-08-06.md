# Plan de lanzamiento de BeautyOS — de proyecto a negocio

**Fecha:** 6 de agosto de 2026
**Reemplaza a:** `RUTA_A_PRODUCCION_2026-07-25.md` (que queda archivado como
antecedente). Este es ahora el **único mapa de lanzamiento**, para no repetir
el problema de documentos que compiten entre sí (D-063).
**Para quién:** el propietario, que no tiene formación técnica. Todo aquí está
en lenguaje simple y separa siempre **lo que haces tú** de **lo que hago yo**.

---

## 1. Cómo se usa este documento

Cada etapa tiene tareas numeradas con un responsable claro:

| Marca | Significa |
|---|---|
| 👤 **TÚ** | Solo lo puedes hacer tú (comprar, registrar cuentas, decidir precios) |
| 🤖 **YO** | Lo hago yo en una sesión de trabajo (código, migraciones, configuración) |
| 👥 **JUNTOS** | Yo te guío paso a paso mientras tú lo ejecutas en pantalla |

**Regla de oro:** no se salta de etapa sin terminar la anterior. Cada etapa
existe porque la siguiente la necesita.

---

## 2. Dónde estamos hoy (verificado en la auditoría D-087)

**Lo que ya funciona y está desplegado:** núcleo operativo completo (agenda,
tickets, cobros, comisiones, inventario, compras, gastos, reseñas, fotos),
multi-negocio y multi-sede con seguridad seria (41 tablas, 173 funciones),
reserva pública sin cuenta, 2FA, panel de plataforma, correos automáticos y
**toda la infraestructura de planes de pago ya construida** (D-044, D-068,
D-069): los 3 planes, el bloqueo por plan y la prueba de 21 días que expira
sola.

**El hecho que define todo este plan:**

> La aplicación **no existe en internet**. Solo corre en el computador del
> propietario. Hoy no hay ninguna dirección web que darle a un negocio.

Faltan además: precios, pasarela de pago, dominio, hosting y el pulido visual.

---

## 3. Decisiones tomadas el 2026-08-06

| Tema | Decisión | Motivo |
|---|---|---|
| **Arquitectura** | Se mantiene **Flutter Web como PWA**. Sin reescribir nada. | 24.800 líneas funcionando y probadas. La PWA se instala en celular y computador sin pasar por tiendas de apps. |
| **Hosting** | **Cloudflare Pages** (gratis), **no** hosting compartido de pago | Flutter compila a archivos estáticos: no necesita servidor con cPanel. Cloudflare da tráfico ilimitado, publicación automática desde GitHub y es la mejor base para los subdominios por negocio (D-062). |
| **Dominio** | Comprar en **Cloudflare Registrar** | Lo vende a precio de costo, sin sobreprecio en la renovación. |
| **Pasarela de pago** | **ePayco reemplaza a Wompi** | El propietario ya tiene cuenta en ePayco. Anula la decisión de D-046. |
| **Supabase Pro** | **Todavía no.** Se paga el día que un negocio real distinto al propio empiece a cargar datos de verdad | El plan gratis alcanza mientras se construye. Ahorra ~25 USD por cada mes de rediseño. |
| **Apps nativas (Play Store / App Store)** | Aplazadas | La PWA cubre la necesidad. Se evalúan cuando haya ingresos. |
| **Figura legal** | Persona natural con RUT | Suficiente para arrancar. Las obligaciones tributarias las debe confirmar un contador, no este documento. |

---

## 4. ETAPA 0 — Que exista en internet 🌍

**Objetivo:** pasar de "corre en mi computador" a "tiene una dirección web
real y se instala como app en el celular".
**Duración estimada:** 1 sesión de trabajo.
**Costo:** ~15 USD al año (solo el dominio).

| # | Tarea | Quién |
|---|---|---|
| 0.1 | Elegir y **comprar el dominio** en Cloudflare Registrar | 👥 JUNTOS |
| 0.2 | Crear cuenta gratuita en Cloudflare (si no existe) | 👤 TÚ |
| 0.3 | Configurar la PWA de verdad: nombre real, descripción, color morado corporativo e íconos propios (hoy dice *"A new Flutter project"* con el azul por defecto de Flutter) | 🤖 YO |
| 0.4 | Compilar la versión de producción y verificar que arranca rápido | 🤖 YO |
| 0.5 | Conectar el repositorio de GitHub a Cloudflare Pages para que **cada `git push` publique solo** | 👥 JUNTOS |
| 0.6 | Conectar el dominio al sitio y activar el candado HTTPS | 👥 JUNTOS |
| 0.7 | Probar en tu celular: abrir, instalar como app, iniciar sesión | 👤 TÚ |

**Resultado:** le puedes mostrar la app a cualquier persona, desde cualquier
lugar, con solo pasarle un enlace.

---

## 5. ETAPA 1 — Que sea seguro compartirla 🔒

**Objetivo:** cerrar los dos huecos que hacen peligroso repartir el enlace.
**Duración estimada:** 1–2 sesiones.
**Costo:** $0.

| # | Tarea | Quién |
|---|---|---|
| 1.1 | **H-02 (bloqueante):** poner tope de reservas por celular y por día en la reserva pública | 🤖 YO |
| 1.2 | **H-01:** decidir el rol Asistente — darle sus pantallas (Agenda, Tickets, Clientes) o quitarlo del formulario de invitación | 👤 TÚ decide, 🤖 YO ejecuto |
| 1.3 | Actualizar el encabezado del expediente rector, que sigue diciendo que el proyecto está bloqueado (H-06) | 🤖 YO |
| 1.4 | Versionar `pubspec.lock` para que la app compile igual en cualquier máquina (H-07) | 🤖 YO |

> **Advertencia seria:** hasta que 1.1 esté hecho, **no le des el enlace de
> reservas a clientes reales**. Hoy cualquiera con ese enlace puede llenarte
> la agenda de citas falsas, porque cada reserva ocupa el horario de
> inmediato, sin que tú confirmes nada.

---

## 6. ETAPA 2 — Que se vea profesional 🎨

**Objetivo:** que la app se vea como el producto que quieres vender.
**Duración estimada:** varias sesiones (una o dos por módulo).
**Costo:** $0.

### 6.1 Primero el sistema de diseño (no negociable)

Hoy los colores están **escritos a mano en cada archivo**. Si rediseñamos
módulo por módulo sin arreglar esto, hay que repintar 29 pantallas cada vez
que cambies de opinión sobre un tono.

| # | Tarea | Quién |
|---|---|---|
| 2.1 | Definir la identidad visual: paleta, tipografía, esquinas, sombras, espaciados | 👥 JUNTOS |
| 2.2 | Centralizar todo eso en un solo archivo de tema, y reemplazar los colores sueltos de las 29 pantallas | 🤖 YO |
| 2.3 | Construir los componentes base reutilizables (tarjetas, botones, tablas, estados vacíos, mensajes de error) | 🤖 YO |

**Beneficio doble:** además de abaratar el rediseño a la mitad, esto es lo que
hace posible la **marca blanca** (que cada negocio tenga sus colores), ya
decidida en D-062.

### 6.2 Después, módulo por módulo con el benchmarking

Las 57 capturas de AgendaPro viven en la carpeta personal del propietario
(`Escritorio/Proyecto BeautyOS/Benchmarking`). **Se abren de a 2 o 3, justo
cuando se rediseña ese módulo** — abrirlas todas de golpe gasta créditos sin
aportar nada.

Orden sugerido, de mayor a menor impacto visual:

| # | Módulo | Capturas de referencia |
|---|---|---|
| 2.4 | **Dashboard** — el que cuenta la historia del negocio con gráficos | `reportes - resumen 1/2` |
| 2.5 | **Agenda** — la pantalla más usada del día a día | `agenda` |
| 2.6 | **Tickets / Ventas** | `ventas - caja de ventas`, `detalle de ventas`, `transacciones` |
| 2.7 | **Clientes** | `clientes - base clientes` |
| 2.8 | **Reportes** | `reportes - reporte de ventas 1/2`, `reporte de reservas 1/2` |
| 2.9 | **Inventario / Productos** | `productos - inventario`, `movimiento de stock` |
| 2.10 | **Administración** (servicios, profesionales, sedes) | `administracion - *` |

**Nota técnica:** los gráficos requieren una librería nueva (`fl_chart`). Es
la única dependencia nueva prevista en todo el plan.

**Nota de alcance:** varias pantallas de AgendaPro son funciones que BeautyOS
**no tiene** (gift cards, email marketing, encuestas, consentimientos,
recordatorios). Eso **no es parte del rediseño**: son funciones nuevas, ya
inventariadas en `BENCHMARKING_2026-07-28.md`, y se deciden aparte.

---

## 7. ETAPA 3 — Que cobre 💰

**Objetivo:** que un negocio pueda pagarte y activarse solo.
**Duración estimada:** 3–4 sesiones.
**Costo:** Supabase Pro (~25 USD/mes) + comisión de ePayco por transacción.

### 7.1 Antes de tocar código

| # | Tarea | Quién |
|---|---|---|
| 3.1 | **Verificar en tu panel de ePayco** si tu cuenta permite **cobros recurrentes** (suscripción mensual automática) con RUT de persona natural. Si no, preguntar a soporte qué requiere | 👤 TÚ |
| 3.2 | Consultar a un contador tus obligaciones al facturar como persona natural (facturación electrónica DIAN, IVA) | 👤 TÚ |
| 3.3 | **Definir los 3 precios reales** (Básico / Business / Profesional). El sistema ya tiene la estructura; faltan los números | 👤 TÚ |
| 3.4 | Redactar términos de servicio y política de privacidad. **Obligatorio:** manejas datos personales de terceros (Ley 1581 de 2012, habeas data) | 👥 JUNTOS |

### 7.2 Construcción

| # | Tarea | Quién |
|---|---|---|
| 3.5 | Subir Supabase a plan Pro (respaldos diarios, sin pausas) | 👤 TÚ |
| 3.6 | **Rotar las claves `service_role` y `secret`** de Supabase — quedaron expuestas en un historial el 03-ago (hallazgo H-04). Paso bloqueante | 👥 JUNTOS |
| 3.7 | Cargar los precios en la base y construir la pantalla pública de planes (la función `list_public_plans` ya existe sin usar) | 🤖 YO |
| 3.8 | Integrar ePayco: botón de pago + **Edge Function que recibe y valida la confirmación del pago en el servidor** | 🤖 YO |
| 3.9 | Conectar el pago confirmado con la suscripción: activar, renovar y manejar el pago fallido | 🤖 YO |
| 3.10 | Verificar el correo del dominio en Resend, para que las invitaciones y alarmas lleguen a cualquiera y no solo a ti (H-12) | 👥 JUNTOS |

> **Regla de oro de pagos, no negociable:** el pago se confirma **en el
> servidor**, mediante la notificación que ePayco envía a nuestra Edge
> Function. **Nunca** se le cree al navegador del cliente. Ya tienes ese
> patrón construido dos veces (correo de invitación y alarma de stock), así
> que se reutiliza.

---

## 8. ETAPA 4 — Que enamore 🚀

**Solo después de los primeros ingresos.** Construir esto antes es gastar en
la dirección equivocada.

| # | Función | Nota realista |
|---|---|---|
| 4.1 | **WhatsApp** (recordatorios, confirmaciones) | Requiere API oficial de Meta (WhatsApp Cloud API), verificación de empresa y plantillas aprobadas. Es un proyecto en sí mismo. Decisión ya aplazada dos veces (D-005, D-058) |
| 4.2 | **Agentes de IA** | Alta valor: resumir el negocio en lenguaje natural, sugerir horarios, redactar respuestas a reseñas. Se define alcance cuando lleguemos |
| 4.3 | **Publicación en Instagram/Facebook** | La bandera `social_publishing` ya está sembrada en el plan Profesional pero **vacía** (H-10). Requiere API de Meta y cuentas Business |
| 4.4 | **Onboarding guiado** ("Primeros pasos") | Ya pospuesto a propósito hasta que la app esté visualmente terminada (D-085). **Su momento natural es al terminar la Etapa 2** |
| 4.5 | Pruebas automáticas de las 3 reglas de dinero (H-03) | Debería entrar **antes** de la Etapa 3 si el presupuesto de tiempo lo permite |

---

## 9. Costos reales

| Concepto | Cuándo | Costo |
|---|---|---|
| Dominio (Cloudflare Registrar) | Etapa 0 | ~12–15 USD **al año** |
| Hosting (Cloudflare Pages) | Etapa 0 | **$0** |
| Supabase Free | Etapas 0–2 | **$0** |
| Supabase Pro | Etapa 3 (o antes si entra un negocio real) | ~25 USD/mes |
| Resend (correos) | Etapa 3 | $0 hasta 3.000/mes |
| ePayco | Etapa 3 | % por transacción (verificar tarifa vigente) |
| Play Store / App Store | Aplazado | 25 USD única vez / 99 USD al año |

**Arrancar cuesta ~15 USD al año.** Operar con clientes reales, ~25 USD al mes.

---

## 10. Lo que NO vamos a hacer todavía, y por qué

| Idea | Por qué se aplaza |
|---|---|
| Reescribir la app en otra tecnología | No hay ningún problema que lo justifique. Sería tirar 24.800 líneas probadas |
| Apps en Play Store / App Store | La PWA cubre la necesidad sin costo ni revisiones de tienda |
| Página pública optimizada para Google (SEO) | Flutter Web no indexa bien, pero eso solo importa si el buscador va a ser un canal de ventas. Se evalúa cuando haya clientes |
| Paquetes/membresías de sesiones | Pausado a propósito hasta que un negocio real lo pida (D-078, punto 2) |
| Dominio propio por cada negocio | Se empieza con subdominios automáticos (D-062). El dominio propio queda como función de pago futura |

---

## 11. Documentos relacionados

- `REGISTRO_DE_DECISIONES.md` — historial completo, fuente de verdad de decisiones
- `01_arquitectura/auditorias/AUDITORIA_INTEGRAL_2026-08-06.md` — los 14 hallazgos que este plan va cerrando
- `BENCHMARKING_2026-07-28.md` — funciones de AgendaPro pendientes de decidir
- `RUTA_GENERAL_2026-07-25.md` — orden de la fase MVP (producto)
- `RUTA_A_PRODUCCION_2026-07-25.md` — **archivado**, reemplazado por este documento

---

*Este plan se actualiza al cerrar cada etapa. Si una decisión cambia (como
Wompi → ePayco), se registra primero en `REGISTRO_DE_DECISIONES.md` y luego
se refleja aquí.*
