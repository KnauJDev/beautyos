# Plan de lanzamiento de Salón y Más — de proyecto a negocio

**Creado:** 6 de agosto de 2026 · **Reorganizado:** 7 de agosto de 2026
**Reemplaza a:** `RUTA_A_PRODUCCION_2026-07-25.md` (archivado). Este es el
**único mapa de lanzamiento**, para no repetir el problema de documentos que
compiten entre sí (D-063).
**Para quién:** el propietario, que no tiene formación técnica. Todo aquí está
en lenguaje simple y separa siempre **lo que haces tú** de **lo que hago yo**.

---

## 1. Cómo se usa este documento

| Marca | Significa |
|---|---|
| 👤 **TÚ** | Solo lo puedes hacer tú (comprar, registrar cuentas, decidir precios) |
| 🤖 **YO** | Lo hago yo en una sesión de trabajo (código, migraciones, configuración) |
| 👥 **JUNTOS** | Yo te guío paso a paso mientras tú lo ejecutas en pantalla |

**Regla de oro:** no se salta de etapa sin terminar la anterior. Cada etapa
existe porque la siguiente la necesita.

**Regla de hallazgos** (acordada el 07-ago): lo que aparezca en el camino se
anota y se ataca **donde le corresponde** dentro de este plan. Si no cabe en
ninguna etapa, va al apartado 11 y se decide al final.

---

## 2. Dónde estamos hoy (7 de agosto de 2026)

**El producto está vivo en internet:** `https://salonymas.com` y
`https://www.salonymas.com`, con HTTPS, instalable como app en el celular, y
publicándose sola en cada `git push`.

**Lo que funciona:** núcleo operativo completo (agenda, tickets, cobros,
comisiones, inventario, compras, gastos, reseñas, fotos), multi-negocio y
multi-sede con seguridad seria (41 tablas, 173 funciones), reserva pública sin
cuenta **con tope antiabuso**, 2FA, panel de plataforma, correos automáticos,
los 4 roles operativos con sus pantallas, y toda la infraestructura de planes
de pago ya construida (D-044, D-068, D-069).

**Lo que falta para vender:** el pulido visual, los precios, la pasarela de
pago y lo legal.

> ✅ **RESPALDO AL DÍA (08-ago-2026).** Se hizo y se verificó: 5 cuentas de
> usuario, 1 negocio, 2 sedes, 5 clientes, 30 tickets, 11 cobros, 72 tablas y
> 182 funciones, con el trabajo de hoy dentro (`theme_key`,
> `get_dashboard_overview`). Vive en `OneDrive\Documents\BeautyOS Backups`.
> **Sigue pendiente la restauración de ensayo:** un respaldo sin restaurar
> comprobada es una promesa, no un respaldo. Ver apartado 11, hallazgo G.

---

## 3. Decisiones vigentes

| Tema | Decisión | Dónde |
|---|---|---|
| **Arquitectura** | Flutter Web como PWA. Sin reescribir nada | D-088 |
| **Hosting** | Cloudflare Pages (gratis, tráfico ilimitado) | D-088 |
| **Dominio** | `salonymas.com`, comprado en Cloudflare Registrar | D-091 |
| **Nombre del producto** | "Salón y Más" de cara al cliente; el código interno sigue diciendo `beautyos` a propósito | D-089 |
| **Pasarela de pago** | ePayco, no Wompi | D-088 |
| **Supabase Pro** | Todavía no. Se paga cuando un negocio real distinto al propio empiece a cargar datos | D-088 |
| **Apps nativas** | Aplazadas. La PWA cubre la necesidad | D-088 |
| **Figura legal** | Persona natural con RUT | D-088 |
| **Marca blanca** | Cinco temas predefinidos **más uno personalizado**: el dueño elige un color y la app deriva el resto, garantizando que se lea. Por negocio, no por sede | D-093, D-109 |
| **Enlace de cada negocio** | Ruta para todos (`salonymas.com/naguaradeunas`); dominio propio como función de pago | D-098 |
| **Identidad visual** | Morado `#7C3AED` ratificado; personalidad compacta con carácter | D-097 |

---

## 4. ETAPA 0 — Que exista en internet 🌍 ✅ CERRADA (06-ago-2026)

| # | Tarea | Quién | Estado |
|---|---|---|---|
| 0.1 | Comprar el dominio en Cloudflare Registrar | 👥 | ✅ `salonymas.com` |
| 0.2 | Crear cuenta en Cloudflare | 👤 | ✅ |
| 0.3 | Configurar la PWA de verdad: nombre, descripción, color e íconos propios | 🤖 | ✅ D-090 |
| 0.4 | Compilar producción y verificar que arranca | 🤖 | ✅ D-090 — **destapó que la app no arrancaba** |
| 0.5 | Conectar GitHub a Cloudflare Pages para publicar en cada `push` | 👥 | ✅ |
| 0.6 | Conectar el dominio y activar HTTPS | 👥 | ✅ |
| 0.7 | Probar en el celular | 👤 | ✅ — con hallazgos, ver 6.2 y 11 |

**Costo real:** ~12 USD al año.

---

## 5. ETAPA 1 — Que sea seguro compartirla 🔒 ✅ CERRADA (06-ago-2026)

| # | Tarea | Quién | Estado |
|---|---|---|---|
| 1.1 | **H-02 (bloqueante):** tope de reservas en la reserva pública | 🤖 | ✅ D-092 — máx. 4 citas futuras y 8 en 24 h, por celular |
| 1.2 | **H-01:** decidir el rol Asistente | 👤 decide, 🤖 ejecuta | ✅ D-092 — se conserva con Agenda, Tickets y Clientes |
| 1.3 | **H-06:** actualizar el encabezado del expediente rector | 🤖 | ✅ v1.6 |
| 1.4 | **H-07:** versionar `pubspec.lock` | 🤖 | ✅ D-091 |

**Correcciones posteriores** (salieron de que el propietario probara en
producción): D-094 y D-095 cerraron el acceso de lectura del asistente y una
regresión que dejó al propietario sin su pantalla de Clientes. D-096 arregló
que los navegadores se quedaran hasta 4 horas con una versión vieja.

> **Límite conocido y aceptado:** el celular que escribe el cliente al reservar
> nadie lo verifica. Los topes son un freno, no una cerradura: detienen al
> bromista y al doble clic accidental, no a alguien que cambie de número en
> cada intento. Las dos soluciones de fondo están en el apartado 11.

---

## 6. ETAPA 2 — Que se vea profesional 🎨 ⬅️ **AQUÍ ESTAMOS**

**Duración estimada:** varias sesiones. **Costo:** $0.

### 6.1 Primero el sistema de diseño (no negociable)

Hoy los colores están escritos a mano: **302 colores literales en 33 archivos**
(medido el 06-ago). Rediseñar módulo por módulo sin arreglar esto obliga a
repintar todo cada vez que cambies de opinión sobre un tono.

| # | Tarea | Quién | Estado |
|---|---|---|---|
| 2.1 | Definir la identidad visual: paleta, tipografía, esquinas, sombras, espaciados, **y los 4-5 temas para tus clientes** | 👥 | ✅ D-097, D-100 |
| 2.2 | Centralizar todo en un archivo de tema y reemplazar los colores sueltos. **Incluye arreglar la navegación en celular** (ver 6.3) | 🤖 | ✅ D-102, D-105, D-106 |
| 2.3 | Componentes base reutilizables (tarjetas, botones, tablas, estados vacíos, errores), ya leyendo el tema | 🤖 | ✅ D-107 |
| 2.4 | Selector de tema en Configuración: columna `tenants.theme_key`, desplegable y lectura al entrar | 🤖 | ✅ D-109 |

**Beneficio doble:** abarata el rediseño a la mitad **y** es lo que hace
posible la marca blanca.

#### Marca blanca: reglas acordadas (D-093)

El **logo por negocio ya está construido** (`tenants.logo_url`, se pinta en el
panel, la reserva pública y las reseñas). Falta la mitad de los colores, que
depende de 2.2.

- **Cinco temas predefinidos y uno personalizado** (D-109, corrige D-093a). El
  argumento original —un dueño puede elegir una combinación ilegible sin darse
  cuenta, y el botón de **eliminar** no puede ser rojo en un tema rojo y negro—
  dejó de aplicar cuando D-097 sacó los colores de estado de la marca blanca y
  D-100d encerró el color de marca en la barra, los títulos, los botones y las
  selecciones. En **Personalizado** el propietario elige **un** color y la app
  deriva los otros cinco, oscureciéndolo si el texto blanco no llegara a 4.5:1.
  Lo que sigue descartado es elegir los seis a mano: ahí sí no hay red.
- **Se guarda el nombre del tema, no los códigos de color.** Así, al mejorar un
  tema, mejoran solos todos los negocios que lo usan.
- **El tema es por negocio, no por sede.** Las sedes son el mismo negocio.
- **Los colores de estado quedan fuera** de la marca blanca: el ámbar significa
  "pendiente" en todos los temas (D-097).
- Aplica al panel interno **y a la página pública de reservas**, que es la que
  ven los clientes del negocio.

### 6.2 Después, módulo por módulo con el benchmarking

Las 57 capturas de AgendaPro viven en `Escritorio/Proyecto BeautyOS/
Benchmarking`. **Se abren de a 2 o 3**, justo cuando se rediseña ese módulo —
abrirlas todas de golpe gasta créditos sin aportar nada.

| # | Módulo | Incluye | Capturas |
|---|---|---|---|
| 2.5 | **Dashboard** — el que cuenta la historia del negocio | ⚠️ **Tramo propio, no solo rediseño.** Especificación completa en `ESPECIFICACION_DASHBOARD_2026-08-08.md` (D-110). Se parte en **2.5a** ✅ **CERRADA (D-113)** — motor de comparación, Vista 1, gráfico, agenda de hoy y avisos, verificada en producción · **2.5b** ✅ **CERRADA (D-114)** — horas vendidas comparadas, sin porcentaje de ocupación · **2.5c** vistas de Negocio, Clientes y Equipo. Absorbe la tarea 4.4 de onboarding | `reportes - resumen 1/2` |
| 2.6 | **Agenda** — la pantalla más usada | ⚠️ **Tramo propio, no solo rediseño.** Pasa a ser un tablero de tickets con vistas de día, semana y mes. Especificación completa en `ESPECIFICACION_AGENDA_2026-08-07.md` (D-101). Incluye el filtro de fecha que hoy no existe, y **exige construir antes el número de ticket** | `agenda` |
| 2.7 | **Tickets / Ventas** | **Resolver el desplazamiento excesivo** para encontrar y cobrar un ticket abierto | `ventas - caja de ventas`, `detalle de ventas`, `transacciones` |
| — | *(nota para 2.11)* | **"Subir portada" no dice qué hace.** Verificado el 07-ago: la portada solo se pinta en el enlace público de reservas, nunca en el panel. El propietario subió el botón y nunca vio el resultado (D-109) | |
| 2.8 | **Clientes** | | `clientes - base clientes` |
| 2.9 | **Reportes** | | `reportes - reporte de ventas 1/2`, `reporte de reservas 1/2` |
| 2.10 | **Inventario / Productos** | | `productos - inventario`, `movimiento de stock` |
| 2.11 | **Administración** (servicios, profesionales, sedes) | | `administracion - *` |

**Nota técnica:** los gráficos requieren `fl_chart`. Es la única dependencia
nueva prevista en todo el plan.

**Nota de alcance:** varias pantallas de AgendaPro son funciones que **no
tenemos** (gift cards, email marketing, encuestas, consentimientos,
recordatorios). Eso no es rediseño: son funciones nuevas, inventariadas en
`BENCHMARKING_2026-07-28.md`, y se deciden aparte.

### 6.3 Adaptación a celular (hallazgo del 06-ago, tarea 0.7)

La app funciona en celular pero se ve mal. **Se resuelve dentro de 2.2**, no
después: rediseñar las pantallas y luego cambiarles la navegación sería hacer
el trabajo dos veces.

| Problema | Qué se ve |
|---|---|
| **En vertical**, la barra superior no cabe | El logo y "Salón y Más" quedan cortados fuera de pantalla |
| **En vertical**, la barra de abajo aprieta 15 pestañas | Parte las palabras: "Das hbo ard", "Foto s de trab ajos" |
| **En horizontal**, las dos barras se comen la altura | Se ven los menús, no la información |

**Causa de fondo:** la navegación está pensada para pantalla ancha. En celular
necesita otra forma — menú lateral desplegable, o barra inferior con los 4 o 5
módulos más usados y el resto en "Más".

### 6.4 Que la app se actualice sola ✅ HECHA (07-ago-2026, D-099)

**Se hizo antes que 2.1** — no depende del diseño y beneficia a todo lo
que venga después.

El 06-ago costó tres rondas averiguar qué versión estaba corriendo el
propietario, y el botón de anular pago siguió apareciendo horas después de
corregirlo. D-096 arregló que el navegador se quedara pegado, pero **falta que
la app avise**: quien deje la pestaña abierta toda la semana seguiría con la
versión del lunes sin enterarse.

| # | Tarea | Quién | Estado |
|---|---|---|---|
| 2.16 | Sello de versión en Configuración | 🤖 | ✅ |
| 2.17 | Aviso de versión nueva, cada 5 min y al volver a la pestaña | 🤖 | ✅ verificado en producción |

**Por qué avisar y no recargar solo:** recargar sin permiso le borraría a la
recepcionista el ticket que está escribiendo. El aviso lo decide la persona.

---

## 7. ETAPA 2.5 — El enlace propio de cada negocio 🔗

**Cuándo:** al terminar la Etapa 2, antes de la 3 (D-098).
**Duración:** 1 sesión. **Costo:** $0.

Hoy el enlace público es `salonymas.com/?reservar=3f2b8c1a-9d4e-...`,
impresentable para un Instagram. Pasa a `salonymas.com/naguaradeunas`.

| # | Tarea | Quién |
|---|---|---|
| 2.12 | Identificador único por negocio, generado del nombre **sin ñ, sin tildes ni espacios** | 🤖 |
| 2.13 | Función pública que lo resuelva sin sesión | 🤖 |
| 2.14 | Enrutado por ruta en Flutter y `_redirects` para Cloudflare Pages | 🤖 |
| 2.15 | Editarlo desde Configuración, avisando que el enlace viejo deja de servir | 🤖 |

**Por qué ruta y no subdominio:** Cloudflare Pages no admite comodines, así que
cada subdominio habría que darlo de alta a mano y automatizarlo contra su API
al crecer. Y quien quiere identidad propia de verdad quiere su dominio, no un
subdominio nuestro.

**El dominio propio del negocio** (`naguaradeunas.com`) va en la Etapa 3 como
función del plan Profesional: Cloudflare for SaaS incluye **100 dominios de
clientes sin costo**, luego 0,10 USD al mes cada uno.

---

## 8. ETAPA 3 — Que cobre 💰

**Duración:** 3–4 sesiones. **Costo:** Supabase Pro (~25 USD/mes) + comisión
de ePayco.

### 8.1 Antes de tocar código

| # | Tarea | Quién |
|---|---|---|
| 3.1 | Verificar en ePayco si tu cuenta permite **cobros recurrentes** con RUT de persona natural | 👤 |
| 3.2 | Consultar a un contador tus obligaciones al facturar (DIAN, IVA) | 👤 |
| 3.3 | **Definir los 3 precios reales** (Básico / Business / Profesional) | 👤 |
| 3.4 | Redactar términos de servicio y política de privacidad. **Obligatorio:** manejas datos de terceros (Ley 1581 de 2012) | 👥 |

### 8.2 Construcción

| # | Tarea | Quién |
|---|---|---|
| 3.5 | Subir Supabase a plan Pro | 👤 |
| 3.6 | **Rotar las claves `service_role` y `secret`** — expuestas en un historial el 03-ago (H-04). **Bloqueante** | 👥 |
| 3.7 | Cargar precios y construir la pantalla pública de planes (`list_public_plans` ya existe sin usar) | 🤖 |
| 3.8 | Integrar ePayco: botón de pago + **Edge Function que valida la confirmación en el servidor** | 🤖 |
| 3.9 | Conectar el pago con la suscripción: activar, renovar, manejar el fallido | 🤖 |
| 3.10 | Verificar el dominio en Resend (H-12) — **hoy los correos de invitación no llegan a nadie salvo a ti** | 👥 |
| 3.11 | Dominio propio por negocio con Cloudflare for SaaS, como función del plan Profesional | 🤖 |

> **Regla de oro de pagos, no negociable:** el pago se confirma **en el
> servidor**, mediante la notificación que ePayco envía a nuestra Edge
> Function. **Nunca** se le cree al navegador del cliente. Ya tienes ese patrón
> construido dos veces (correo de invitación y alarma de stock).

---

## 9. ETAPA 4 — Que enamore 🚀

**Solo después de los primeros ingresos.** Construir esto antes es gastar en la
dirección equivocada.

| # | Función | Nota realista |
|---|---|---|
| 4.1 | **WhatsApp** (recordatorios, confirmaciones) | Requiere API oficial de Meta, verificación de empresa y plantillas aprobadas. Es un proyecto en sí mismo. Aplazado dos veces (D-005, D-058) |
| 4.2 | **Agentes de IA** | Resumir el negocio en lenguaje natural, sugerir horarios, redactar respuestas a reseñas |
| 4.3 | **Publicación en Instagram/Facebook** | La bandera `social_publishing` está sembrada pero vacía (H-10) |
| 4.4 | **Onboarding guiado** ("Primeros pasos") | Pospuesto hasta que la app esté visualmente terminada (D-085). **Su momento natural es al cerrar la Etapa 2** |
| 4.5 | Pruebas automáticas de las 3 reglas de dinero (H-03) | **Debería entrar antes de la Etapa 3.** Las tres regresiones del 06-ago las encontró el propietario probando, no las pruebas: hay 5 pruebas y ninguna toca roles ni dinero |

---

## 10. Costos reales

| Concepto | Cuándo | Costo |
|---|---|---|
| Dominio | Etapa 0 ✅ | ~12 USD **al año** |
| Hosting (Cloudflare Pages) | Etapa 0 ✅ | **$0** |
| Supabase Free | Etapas 0–2 | **$0** |
| Supabase Pro | Etapa 3 | ~25 USD/mes |
| Resend | Etapa 3 | $0 hasta 3.000 correos/mes |
| ePayco | Etapa 3 | % por transacción |
| Dominios propios de clientes | Etapa 3 | **$0 los primeros 100**, luego 0,10 USD/mes cada uno |

**Hoy llevas gastados ~12 USD.** Operar con clientes reales, ~25 USD al mes.

---

## 11. Anotado en el camino, sin etapa asignada

Hallazgos que no bloquean nada y aún no tienen sitio. Se deciden al cerrar la
Etapa 2.

| # | Hallazgo | Nota |
|---|---|---|
| A | **Las citas recurrentes solo admiten diaria y semanal.** Falta **mensual**, la periodicidad más común de un cliente fiel. No es solo la pantalla: el backend valida `p_repeat_frequency not in ('daily','weekly')` | Función nueva |
| B | **Crear una serie larga es lento**: 19 citas semanales tardaron un buen rato | Revisar junto con A |
| C | **La sesión sobrevive al cierre del navegador** | Ver abajo |
| D | **La barra inferior de celular podría llevar acciones, no módulos** — ver agenda, confirmar agenda, ver quién falta por cobrar, cobrar. Es lo que de verdad se hace desde un teléfono (idea del propietario, 07-ago) | Se planifica antes de fijar los cuatro puestos |
| E | **Verificar el celular del cliente con un código** (SMS/WhatsApp) al reservar | Cierra del todo H-02. Cuesta por mensaje |
| F | **Que la reserva pública no ocupe el horario** hasta que el negocio la confirme | Arreglo estructural de H-02. Cambia cómo funciona la agenda |
| **G** | ~~No hay respaldo desde el 22 de julio~~ **✅ HECHO el 08-ago** con `scripts/respaldo_supabase.ps1`, que reemplaza al de julio (aquel exigía Docker y llevaba semanas sin poder correr, sin que nadie lo notara). Verificado por contenido, no solo por tamaño | 👤 **Queda la restauración de ensayo.** Se puede hacer contra un segundo proyecto gratuito de Supabase, sin tocar producción. Antes de la Etapa 3 |

### Sobre la sesión que no se cierra (C)

Es el comportamiento por defecto de Supabase. **El riesgo real en un salón no
es que se cierre el navegador, sino lo contrario:** la recepcionista se levanta
y deja la sesión abierta en el computador del mostrador.

1. **Sesión por pestaña** — resuelve lo preguntado, pero obliga a iniciar
   sesión en cada pestaña nueva y no protege del caso real.
2. **Casilla "mantener sesión iniciada"** — le pasa la decisión al usuario.
3. **Cierre por inactividad** (30 min). **Recomendado:** es el único que cubre
   lo que de verdad pasa en un mostrador.

---

## 12. Lo que NO vamos a hacer todavía, y por qué

| Idea | Por qué se aplaza |
|---|---|
| Reescribir la app en otra tecnología | No hay ningún problema que lo justifique. Sería tirar 24.800 líneas probadas |
| Apps en Play Store / App Store | La PWA cubre la necesidad sin costo ni revisiones de tienda |
| Página optimizada para Google (SEO) | Flutter Web no indexa bien, pero eso solo importa si el buscador va a ser canal de ventas |
| Paquetes/membresías de sesiones | Pausado hasta que un negocio real lo pida (D-078) |
| Subdominios por negocio | Descartados el 07-ago (D-098). Se sustituyen por ruta + dominio propio |

---

## 13. Documentos relacionados

- `REGISTRO_DE_DECISIONES.md` — historial completo, fuente de verdad
- `01_arquitectura/auditorias/AUDITORIA_INTEGRAL_2026-08-06.md` — los 14 hallazgos
- `BENCHMARKING_2026-07-28.md` — funciones de AgendaPro pendientes de decidir
- `RUTA_GENERAL_2026-07-25.md` — orden de la fase MVP
- `RUTA_A_PRODUCCION_2026-07-25.md` — **archivado**
- `ESPECIFICACION_AGENDA_2026-08-07.md` — el tablero de tickets (tarea 2.6)
- `ESPECIFICACION_DASHBOARD_2026-08-08.md` — el Dashboard como historia (tarea 2.5)
- `GUIA_TECNICA_PARA_PRODUCCION_2026-08-08.md` — sobre qué corre, cuánto cuesta y qué falta para vender
- `HANDOFF/HANDOFF_SalonyMas_Etapas_0_1_2_2026-08-07.md` — cierre de las Etapas 0 y 1 y del sistema de diseño

### Equivalencias tras la reorganización del 07-ago

Algunas decisiones citan la numeración anterior. Traducción:

| Decía | Ahora es |
|---|---|
| 2.3-bis (selector de tema) | **2.4** |
| 2.4 Dashboard | **2.5** |
| 2.5 Agenda | **2.6** |
| 2.6 Tickets | **2.7** |
| 2.7 a 2.10 (módulos) | **2.8 a 2.11** |
| 2.11 a 2.14 (enlace propio) | **2.12 a 2.15** |
| 6.1-bis (celular) | **6.3** |
| 6-bis (anotado en el camino) | **11** |
| 6-ter (Etapa 2.5) | **7** |

---

*Este plan se actualiza al cerrar cada etapa. Si una decisión cambia, se
registra primero en `REGISTRO_DE_DECISIONES.md` y luego se refleja aquí.*
