# Barrido general y plan maestro hasta producción

**Fecha:** 8 de agosto de 2026 · **Pedido por:** el propietario
**Sustituye como hoja de ruta operativa a:** nada. **Complementa** a
`PLAN_DE_LANZAMIENTO_2026-08-06.md`, que sigue siendo el mapa de etapas.

> **Por qué existe.** El propietario detectó que estábamos a punto de construir
> tres vistas nuevas sin haber revisado qué existe ya, y recordó que módulos
> como Agenda y Tickets se habían decidido fusionar y seguían separados. Tenía
> razón. Este documento es el resultado de mirar **todo** antes de seguir.

---

## 1. Lo que se encontró — resumen

| # | Hallazgo | Gravedad |
|---|---|---|
| **1** | **La fusión Agenda + Tickets se decidió (D-105) y nunca se ejecutó.** Siguen siendo dos módulos | 🔴 Alta |
| **2** | **Los almacenes de archivos son públicos** (H-09). Cualquiera con la dirección ve una foto para siempre, aunque en la app esté oculta | 🔴 Alta — protección de datos |
| **3** | **42 funciones de base de datos que nadie llama** (H-05, medido hoy) | 🟡 Media |
| **4** | **Toda la infraestructura de planes de pago existe y está dormida**: `list_public_plans` y `get_my_entitlements` no los usa nadie | 🟡 Media — se despierta en Etapa 3 |
| **5** | **Las columnas de dinero no siguen la regla documentada** (H-08): unas con dos decimales, otras sin restricción | 🟡 Media — antes de cobrar |
| **6** | **Ninguna prueba toca dinero, roles ni el tamaño de un teléfono** (H-03). Los fallos los encuentra el propietario probando | 🔴 Alta |
| **7** | **El enlace propio por negocio se decidió (D-098) y no se construyó** | 🟢 Planificado (2.12–2.15) |
| **8** | **Falta marcar "Naguara de Uñas" como negocio de prueba** (D-112) | 🟡 Antes del primer cliente |
| **9** | Descuido de permisos en Storage, no explotable (H-11) | 🟢 Baja |
| **10** | **Sin restauración de ensayo del respaldo nuevo** (D-111) | 🔴 Alta |
| **11** | **Claves de Supabase sin rotar** (H-04) | 🔴 Alta |
| **12** | **Correos de invitación no llegan a nadie** (H-12): Resend en sandbox | 🔴 Alta — bloquea al primer cliente |

---

## 2. Estado real de cada módulo

Un propietario ve **16 módulos**. Esto es lo que hay hoy y lo que le falta.

| Módulo | Qué muestra hoy | Qué le falta o sobra | Dónde se arregla |
|---|---|---|---|
| **Dashboard** | ✅ Resumen completo: 4 indicadores comparados, gráfico, agenda de hoy, avisos | Nada urgente | Hecho (2.5a/b) |
| **Agenda** | Lista básica de citas. **234 líneas** | ⚠️ **Debe absorber Tickets** (D-105). Le falta filtro de fecha y las vistas día/semana/mes de la especificación | **2.6** |
| **Tickets** | Panel completo de cobro. **3.699 líneas** | ⚠️ **Debe dejar de ser módulo** y pasar a ser el nivel de detalle dentro de Agenda | **2.6** |
| **Clientes** | Solo una lista | Nuevos vs recurrentes, tasa de retorno, valor del cliente, quién dejó de venir | **2.8** |
| **Reportes** | Ventas por servicio + **resultado financiero** (ya calcula utilidad) | Ordenarlo, métodos de pago, comparación entre períodos | **2.9** |
| **Estilistas** | Lista y configuración | Producción por persona: ventas, servicios, comisiones, ocupación | **2.11** |
| **Servicios** | Catálogo y precios | Cuáles dejan más dinero (hoy hay que ir a Reportes) | **2.11** |
| **Usuarios** | Invitar y gestionar | ⚠️ **Las invitaciones no llegan** (H-12) | **3.10** |
| **Inventario / Compras / Gastos** | Funcionan | Pulido visual | **2.10** |
| **Fotos de trabajos / Reseñas** | Funcionan | ⚠️ **Archivos públicos permanentes** (H-09) | Barrido técnico |
| **Configuración** | Completa, con tema y versión | Explicar qué hace "Subir portada" | **2.11** |
| **Panel de plataforma** | Solo lectura de negocios | ⚠️ **No distingue negocios de prueba de reales** (D-112) | Antes del 1er cliente |

### La corrección de rumbo más importante

**No se construyen "vistas nuevas".** Lo que iba a ser la tarea 2.5c —tres
pantallas de análisis— **se disuelve dentro de los módulos que ya existen**:

- Análisis de clientes → **módulo Clientes** (2.8)
- Análisis financiero → **módulo Reportes** (2.9)
- Producción del equipo → **módulo Estilistas** (2.11)

**Motivo:** no duplicar información, no sumar entradas a un menú que ya tiene
16, y arreglar módulos pobres en vez de añadir módulos nuevos. **La propuesta
es del propietario y es mejor que la original.**

---

## 3. El plan maestro hasta producción

### ETAPA A — Seguridad y red de protección (todo $0, antes de vender)

| # | Acción | Quién |
|---|---|---|
| A1 | Rotar las claves `service_role` y `secret` de Supabase (H-04) | 👥 |
| A2 | Restaurar un respaldo de ensayo en un segundo proyecto gratuito (D-111) | 👥 |
| A3 | Verificar el dominio en Resend para que lleguen las invitaciones (H-12) | 👥 |
| A4 | Cerrar los almacenes de archivos y borrar los huérfanos (H-09) | 🤖 |
| A5 | Marcar "Naguara de Uñas" como negocio de prueba (D-112) | 🤖 |
| A6 | Pruebas automáticas de las 3 reglas de dinero y de los roles (H-03) | 🤖 |

### ETAPA B — Terminar el pulido visual (Etapa 2 del plan)

| # | Acción | Quién |
|---|---|---|
| B1 | **2.6 — Fusionar Agenda y Tickets** y construir el tablero con vistas día/semana/mes (D-101, D-105) | 🤖 |
| B2 | 2.8 — Clientes: lista + análisis de retorno y valor | 🤖 |
| B3 | 2.9 — Reportes: ordenar el financiero, métodos de pago, comparación | 🤖 |
| B4 | 2.10 — Inventario, Compras y Gastos: pulido | 🤖 |
| B5 | 2.11 — Servicios, Estilistas y Configuración: pulido + producción por persona | 🤖 |

### ETAPA C — El enlace propio (Etapa 2.5 del plan)

| # | Acción | Quién |
|---|---|---|
| C1 | 2.12 a 2.15 — `salonymas.com/naguaradeunas` en vez del enlace con código (D-098) | 🤖 |

### ETAPA D — Cobrar (Etapa 3 del plan)

| # | Acción | Quién |
|---|---|---|
| D1 | **Definir los 3 precios reales** | 👤 **Bloquea todo lo demás** |
| D2 | Términos de servicio y política de privacidad (Ley 1581) | 👥 |
| D3 | Verificar en ePayco si admite cobros recurrentes con RUT de persona natural | 👤 |
| D4 | Consultar a un contador las obligaciones al facturar | 👤 |
| D5 | Subir Supabase a plan Pro | 👤 |
| D6 | Pantalla pública de planes (`list_public_plans` ya existe, dormida) | 🤖 |
| D7 | Integrar ePayco con confirmación **en el servidor** | 🤖 |
| D8 | Conectar el pago con la suscripción: activar, renovar, fallido | 🤖 |
| D9 | Dominio propio por negocio con Cloudflare for SaaS | 🤖 |

### ETAPA E — Limpieza técnica (cuando no bloquee nada)

| # | Acción | Quién |
|---|---|---|
| E1 | Eliminar las 42 funciones huérfanas, en dos pasos (H-05) | 🤖 |
| E2 | Unificar las reglas de las columnas de dinero (H-08) | 🤖 |
| E3 | Alinear el permiso suelto de Storage (H-11) | 🤖 |
| E4 | Onboarding guiado "Primeros pasos" (4.4) | 🤖 |

---

## 4. Lo que NO se hace todavía, y por qué

| Idea | Por qué se aplaza |
|---|---|
| Porcentaje de ocupación y "dinero perdido" | Sin horarios por profesional sería una cifra inventada (D-110, D-114) |
| WhatsApp oficial | Requiere verificación de empresa con Meta. Es un proyecto en sí mismo |
| Citas recurrentes mensuales | El backend solo admite diaria y semanal. Función nueva |
| Cierre de sesión por inactividad | Decidido recomendarlo, sin fecha (apartado 11-C) |
| Docker y entorno local | Solo haría falta para probar migraciones antes de producción. Vale la pena en la Etapa D, no antes |
| Propinas | No existe ni la columna. Es un cambio del flujo de cobro |

---

## 5. Estado del proyecto al cerrar este barrido

- **Repositorio:** limpio y sincronizado con el remoto
- **Producción:** `f0806da` publicada y verificada
- **Pruebas:** 70, en 8 archivos
- **Migraciones:** 9 aplicadas el 8 de agosto
- **Respaldo:** base y archivos, del 8 de agosto, verificados por contenido
- **Monitoreo:** activo, sin enviar datos personales

*Este documento se revisa al cerrar cada etapa de las cinco de arriba.*
