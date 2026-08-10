# HANDOFF Salón y Más — Etapas 0, 1 y sistema de diseño

**Fechas cubiertas:** 6 y 7 de agosto de 2026
**Bloque documentado:** decisiones **D-090 a D-108** · 31 commits
**Estado:** todo aplicado, desplegado y verificado en producción
**Producto en internet:** `https://salonymas.com` · `https://www.salonymas.com`

> **Nota de nombre.** El producto se llama **Salón y Más** de cara al cliente
> desde D-089. El código interno, el repositorio (`KnauJDev/beautyos`) y el
> proyecto de Supabase siguen diciendo `beautyos` **a propósito**: no lo lee
> ningún usuario y renombrarlos costaría más de lo que aporta.

---

## 1. Resumen ejecutivo

En dos días el producto pasó de "corre en el computador del propietario" a
**estar publicado, ser seguro de compartir y tener sistema de diseño**.

Se cerraron las **Etapas 0 y 1** completas y las tareas **2.1, 2.2 y 2.3** de
la Etapa 2. Y lo más valioso no estaba en el plan: **ocho fallos reales que
nadie sabía que existían**, todos descubiertos porque el propietario probó en
producción, no por las pruebas automáticas.

### Los ocho fallos encontrados

| # | Fallo | Decisión |
|---|---|---|
| 1 | **La app no arrancaba en web.** D-089 quitó un script creyéndolo huérfano; `supabase_flutter` depende de él y su plugin muere antes de `runApp`. Rota desde `30a1f05` | D-090 |
| 2 | **`pubspec.lock` sin versionar.** Cloudflare habría compilado con versiones distintas a las probadas | H-07 |
| 3 | **El asistente no podía leer lo que sí podía escribir.** Se verificaron las 14 funciones de acción, no las de lectura | D-094 |
| 4 | **Regresión propia:** reemplacé `is_owner_or_admin()` por `get_my_role()` creyéndolos equivalentes. **El propietario perdió su pantalla de Clientes** | D-095 |
| 5 | **Caché de 4 horas.** Los navegadores se quedaban con versiones viejas y el dominio pisaba las cabeceras de la app | D-096 |
| 6 | **El correo de confirmación apuntaba a `localhost:3000`.** Nadie podía completar un registro nuevo | — (arreglado en el panel de Supabase) |
| 7 | **El dueño de la SaaS no podía activar 2FA.** El panel de plataforma nunca tuvo el botón | D-103 |
| 8 | **Abandonar el 2FA una vez bloqueaba la cuenta para siempre.** Trampa sin salida desde la app | D-104 |
| 9 | **En celular no se veía en qué sede se trabajaba.** La barra mostraba el negocio y no la sede: cambiar de sede no cambiaba nada en pantalla | D-108 |

**Los tres primeros y el sexto llevaban días o semanas rotos sin que nadie lo
supiera.** Todos afectaban a producción.

> **Dos de los nueve los introduje yo** en esta misma sesión (el 4 y el 9), y
> los dos los encontró el propietario probando. Queda dicho aquí para que el
> registro sea honesto.

---

## 2. Estado actual, verificado

| Área | Estado |
|---|---|
| Dominio y hosting | ✅ Cloudflare Pages + Registrar. Despliegue automático en cada `push` a `main` |
| Cabeceras de caché | ✅ `web/_headers` + *Respect Existing Headers* en la zona |
| Aviso de versión nueva | ✅ Verificado de punta a punta: la franja apareció sola y al pulsar actualizó |
| Sello de versión | ✅ En Configuración y en *Seguridad de tu cuenta* (todos los roles) |
| Tope de reserva pública | ✅ Probado por el propietario: la 5ª reserva fue rechazada |
| Rol Asistente | ✅ Agenda, Tickets, Clientes + editar clientes. Sin anular pagos ni corregir finalizados |
| 2FA | ✅ Disponible para los 5 roles, incluido `platform_owner` |
| Sistema de diseño | ✅ Tema único, tipografía propia, componentes base, guardián de colores |
| Navegación en celular | ✅ 4 módulos + "Más"; barra superior con módulo, negocio, persona y rol |

**Pruebas:** `flutter analyze` limpio · **6/6** (una es el guardián de colores).

---

## 3. Lo que quedó construido y por qué importa

### Sistema de diseño (2.1 a 2.3)

- **`lib/theme/`** — `AppColors`, `AppSpacing`, `AppRadius`, `AppTheme`.
  Consolidó **54 colores distintos** en ~20 tokens. Había cinco morados claros
  casi iguales, cuatro verdes de éxito y dos grises de texto secundario.
- **Tipografía Plus Jakarta Sans empaquetada.** Google Fonts solo publica la
  variable; con 113 sitios fijando el grosor a mano, todo se habría visto
  delgado. Se extrajeron tres pesos con `fontTools`.
- **`test/sin_colores_sueltos_test.dart`** — falla si alguien escribe un
  `Color(0xFF...)` fuera del tema. **Sin esto el sistema se degrada solo.**
- **`lib/widgets/app_states.dart`** — `AppCard` (con barra de color),
  `LoadingCard`, `EmptyState`, `ErrorState`. Lo más útil es separar vacío de
  error: hoy los 153 sitios restantes los pintan igual.
- **`lib/widgets/ticket_status.dart`** — enum único con etiqueta, color, grupo
  del tablero y si el estado exige acción.

### Infraestructura de versión

`build-info.json` lo escribe Cloudflare al compilar con `CF_PAGES_COMMIT_SHA`.
La app lo consulta al arrancar, cada 5 minutos y **al volver a la pestaña**.
**Avisa, no recarga sola** — recargar borraría el ticket a medio escribir.

---

## 4. Decisiones de producto tomadas

| Tema | Decisión | Dónde |
|---|---|---|
| Identidad visual | Morado `#7C3AED`; compacta con carácter; sin sombras; esquinas 14/10/píldora | D-097, D-100 |
| Marca blanca | Temas predefinidos (no selector libre), por negocio, guardando el **nombre** del tema y no los colores | D-093 |
| Colores de estado | **Fuera** de la marca blanca. "Por cobrar" en coral, no rojo | D-097, D-101 |
| Enlace por negocio | Ruta `salonymas.com/naguaradeunas` para todos; dominio propio como función de pago (100 gratis en Cloudflare for SaaS) | D-098 |
| **Agenda = tablero de tickets** | Tres vistas (día/semana/mes) contando por estado. Regla: *al cerrar el día, todo en cero salvo "Cerrado"* | D-101 |
| **Agenda y Tickets se fusionan** | Son la misma tabla. Se llama **Agenda**; el panel de tickets es el nivel 2 | D-105 |
| Número de ticket | Consecutivo por negocio desde `0000001`, sin reinicios ni prefijo | D-101 |

**La especificación completa de la Agenda está en
`docs/00_producto/ESPECIFICACION_AGENDA_2026-08-07.md`.** Es el documento
contra el que se construirá la tarea 2.6.

---

## 5. Dónde estamos en el plan

```
Etapa 0  Que exista en internet        ✅ CERRADA
Etapa 1  Que sea seguro compartirla    ✅ CERRADA
Etapa 2  Que se vea profesional        🔄 AQUÍ
         2.1 Identidad visual          ✅
         2.2 Tema y colores            ✅
         2.3 Componentes base          ✅
         2.4 Selector de tema          ⬅️ SIGUIENTE
         2.5 a 2.11 Módulo por módulo  ⬜
Etapa 2.5 El enlace propio             ⬜
Etapa 3  Que cobre                     ⬜
Etapa 4  Que enamore                   ⬜
```

---

## 6. Pendientes del propietario

| # | Qué | Urgencia |
|---|---|---|
| 1 | ~~Activar el 2FA de `juankdev2026@gmail.com`~~ **✅ HECHO el 07-ago.** Queda el recordatorio de **guardar la clave de respaldo** en sitio seguro: si pierde el teléfono sin ella, pierde el panel que controla todos los negocios | — |
| 2 | Verificar en el celular que la barra superior muestre módulo, negocio, nombre y rol sin cortarse | Media |
| 3 | **Decidir los 4 módulos de la barra inferior.** Hoy son los cuatro primeros de la lista, no una elección. Su propia idea, mejor: que sean **acciones** (confirmar agenda, ver quién falta por cobrar, cobrar) y no módulos | Media |
| 4 | Antes de la Etapa 3: **rotar `service_role` y `secret`** de Supabase (H-04) | Bloqueante para Etapa 3 |

---

## 7. Decisiones pendientes de conversar

| # | Asunto | Contexto |
|---|---|---|
| A | Resumen agregado para el estilista en el tablero | Aplazado a propósito en D-101 |
| B | Cierre de sesión por inactividad | Apartado 11 del plan, opción recomendada de tres |
| C | Citas recurrentes **mensuales** | Backend solo admite `daily` y `weekly` |
| D | Barra inferior con acciones en vez de módulos | Idea del propietario, 07-ago |

---

## 8. Límites conocidos y aceptados

1. **No se puede verificar visualmente desde el entorno de trabajo.** El panel
   de vista previa no compone imagen (igual que en D-084 y D-086). Se comprueba
   que arranca sin errores; **que se vea bien lo confirma el propietario**.
2. **El celular del cliente al reservar nadie lo verifica.** Los topes de H-02
   son un freno, no una cerradura.
3. **Resend sigue en sandbox:** las invitaciones por correo no llegan a nadie
   salvo al propietario. Se cierra en la tarea 3.10.
4. **Hay dos armazones** (panel de negocio y panel de plataforma) y lo que se
   agrega a uno **no llega al otro**. Revisar ambos al tocar algo transversal.

---

## 9. Lecciones de método

1. **Autorizar un rol en el backend no es autorizarlo a leer.** Dar acceso a un
   módulo obliga a revisar las dos mitades (D-094).
2. **Para sumar un rol se EXTIENDE la comprobación existente, nunca se
   reescribe.** Reescribirla dejó al propietario fuera de su negocio (D-095).
3. **Compactar una pantalla no es quitar, es decidir a dónde va cada cosa.** Al
   compactar la barra se borró la identidad del usuario (D-106).
4. **Ante "no veo el cambio", comparar el ETag y las cabeceras de las tres
   direcciones** (despliegue, proyecto y dominio) antes de culpar al navegador
   del usuario. Se falló en esto dos veces (D-096).
5. **Las tres regresiones y los ocho fallos los encontró el propietario
   probando.** Hay 6 pruebas y ninguna toca roles, dinero ni seguridad
   (hallazgo H-03). **La tarea 4.5 debería entrar antes de la Etapa 3.**

---

## 10. Prompt para retomar

```
Retomo Salón y Más en C:\Proyectos\salonymas.

Lee primero, en este orden:
1. docs/HANDOFF/HANDOFF_SalonyMas_Etapas_0_1_2_2026-08-07.md  (este documento)
2. docs/00_producto/PLAN_DE_LANZAMIENTO_2026-08-06.md          (el mapa vigente)
3. docs/00_producto/REGISTRO_DE_DECISIONES.md, decisiones D-090 a D-107
4. docs/00_producto/ESPECIFICACION_AGENDA_2026-08-07.md        (para la tarea 2.6)

Estamos en la Etapa 2. Cerradas 2.1, 2.2 y 2.3.
Siguiente: tarea 2.4 — selector de tema en Configuración (marca blanca):
columna tenants.theme_key, los 5 temas de D-093/D-097, desplegable y lectura
al entrar. Aplica al panel interno y a la página pública de reservas.

Cómo trabajamos:
- Verifica en el código antes de afirmar; no asumas.
- Cuando tenga varios puntos que plantear, repítemelos en una lista para
  confirmar que los entendiste ANTES de empezar a resolver.
- Pregunta "¿algo más antes de seguir?" antes de cerrar cada bloque.
- Registra cada decisión en REGISTRO_DE_DECISIONES.md con el porqué, no solo
  el qué, incluyendo lo que se descartó y por qué.
- Pide permiso antes de tocar Cloudflare, Supabase o hacer push.
- Yo pruebo en producción y te reporto; tú no puedes ver la interfaz.
```

---

## 11. Evidencia

- **29 commits**, de `463e14a` a `e401aa2`
- **4 migraciones aplicadas** al proyecto real: `20260806140000`,
  `20260806160000`, `20260806180000`, `20260806190000`
- **Decisiones D-090 a D-107** en `REGISTRO_DE_DECISIONES.md`
- Última versión publicada verificable en Configuración → Versión
