# HANDOFF Salón y Más — 8 de agosto de 2026

**Bloque documentado:** decisiones **D-109 a D-115** · 22 commits · 9 migraciones
**Estado:** todo aplicado, desplegado y verificado en producción
**Versión publicada:** `f0806da` · `https://salonymas.com`
**Reemplaza como handoff vigente a:** `HANDOFF_SalonyMas_Etapas_0_1_2_2026-08-07.md`

---

## 1. Qué pasó en esta sesión

Se cerraron **2.4** (marca blanca), **2.5a** y **2.5b** (Dashboard). Pero lo más
valioso no fue el código:

1. **Se descubrió que no había respaldo desde el 22 de julio**, y que el script
   que existía llevaba semanas sin poder ejecutarse porque exigía Docker, que
   ya no estaba instalado. Se reemplazó, se respaldó y se verificó por
   contenido.
2. **Se montó monitoreo de errores**, que no estaba en el plan. Hasta hoy, si
   la app fallaba para otro usuario, nadie se enteraba.
3. **El propietario corrigió el rumbo del Dashboard**: en vez de construir tres
   vistas nuevas, el análisis va dentro de los módulos que ya existen. Su
   propuesta era mejor que la mía.
4. **Se hizo un barrido completo** que destapó que la fusión Agenda + Tickets
   se decidió el 07-ago y nunca se ejecutó, y que hay 42 funciones huérfanas.

---

## 2. Lo que quedó construido

| Qué | Dónde |
|---|---|
| **Marca blanca completa** — 5 temas + personalizado con color propio | D-109 |
| **Dashboard Vista 1** — 4 indicadores comparados, gráfico, agenda de hoy, avisos | D-110, D-113 |
| **Horas vendidas** comparadas, sin porcentaje de ocupación | D-114 |
| **Respaldo** de base y archivos, con scripts que no necesitan Docker | D-111 |
| **Monitoreo de errores** sin enviar datos personales | D-115 |
| **Segunda sede operativa** y datos de ensayo de 6 meses | D-112 |

**Pruebas:** 70, en 8 archivos · `flutter analyze` limpio · `build web` correcto.

---

## 3. Las reglas que gobiernan el Dashboard

Están en `ESPECIFICACION_DASHBOARD_2026-08-08.md`. Las tres que más importan:

1. **Nunca mostrar una precisión que los datos no soportan.** Por eso no hay
   porcentaje de ocupación ni "dinero perdido": el horario se guarda por
   negocio y no por profesional, así que el denominador no existe.
2. **Venta es dinero cobrado**, no ticket finalizado. Lo terminado sin cobrar
   vive en "por cobrar".
3. **Si no hay historia para comparar, se dice con palabras.** Ni `0%` ni `∞%`.

---

## 4. Dónde estamos, de verdad

```
Etapa 0  Que exista en internet        ✅ CERRADA
Etapa 1  Que sea seguro compartirla    ✅ CERRADA
Etapa 2  Que se vea profesional        🔄 AQUÍ
         2.1 a 2.4  Sistema de diseño  ✅
         2.5  Dashboard  2.5a ✅  2.5b ✅
         2.6  Agenda + Tickets         ⬅️ SIGUIENTE
         2.7 a 2.11  Módulo por módulo ⬜
Etapa 2.5 El enlace propio             ⬜
Etapa 3  Que cobre                     ⬜
```

> **2.5c dejó de existir.** El análisis se disuelve dentro de Clientes (2.8),
> Reportes (2.9) y Estilistas (2.11), que ya existen. Decisión del propietario.

---

## 5. El plan de trabajo vigente

**`PLAN_DE_TRABAJO_A_PRODUCCION.xlsx`** — 26 acciones en 5 etapas, con columna
de estado para seguimiento. Es el documento de seguimiento del propietario.

**`BARRIDO_Y_PLAN_MAESTRO_2026-08-08.md`** — el detalle de cada acción y el
estado real de los 16 módulos.

### Lo que bloquea de verdad

| Qué | Quién |
|---|---|
| **Definir los 3 precios** | 👤 **Marca la fecha de salida** |
| Rotar claves de Supabase (H-04) | 👥 |
| Restaurar un respaldo de ensayo | 👥 |
| Verificar Resend: hoy las invitaciones no llegan a nadie | 👥 |

---

## 6. Cómo trabajamos — método acordado

- **Verifica en el código antes de afirmar. No asumas.**
- **Antes de construir, di en dos líneas qué vas a hacer y por qué, y espera
  confirmación.** Acordado el 08-ago: *"quiero saber muy bien qué estamos
  haciendo, por qué y para qué"*.
- Cuando haya varios puntos que plantear, repetirlos en una lista para
  confirmar que se entendieron **antes** de empezar a resolver.
- Preguntar *"¿algo más antes de seguir?"* antes de cerrar cada bloque.
- **Registrar cada decisión en `REGISTRO_DE_DECISIONES.md` con el porqué**,
  incluyendo lo que se descartó y por qué.
- **Regla de hallazgos:** lo que aparezca en el camino se anota y se ataca
  donde le corresponde en el plan. Si no cabe, va al apartado 11.
- **Pedir permiso antes de tocar Supabase, Cloudflare o hacer push.**
- **Cualquier instalación en el computador del propietario la ejecuta él.**
  Los programas que ejecuta el asistente corren aislados: lo que instalan no
  llega a su máquina (lección de D-111, costó cuatro intentos).
- **Recordar respaldar antes de cada sesión con migraciones.**
- El propietario prueba en producción y reporta; el asistente no ve la
  interfaz.

---

## 7. Advertencias para quien siga

1. **Los datos de febrero a julio son sembrados**, no reales (D-112). Están
   marcados `SEMILLA_DEMO` y se borran con
   `supabase/sql/160_borrar_semilla_demo.sql`. **No generan comisiones**, así
   que la utilidad de ese período sale más alta de lo real.
2. **Las migraciones van directo a producción.** No hay entorno de ensayo. Van
   en transacción y se escriben aditivas, pero es la parte más frágil del
   método.
3. **Los almacenes de archivos son públicos** (H-09). Una foto oculta en la app
   sigue siendo visible con su dirección. Es lo más urgente del barrido.
4. **Los tres fallos del 08-ago los encontró el propietario probando.** Ninguna
   prueba automática toca dinero, roles ni el tamaño de un teléfono.

---

## 8. Prompt para retomar

```
Retomo Salón y Más en C:\Proyectos\salonymas.

Lee primero, en este orden:
1. docs/README.md   (el mapa: qué significa cada código y qué manda sobre qué)
2. docs/HANDOFF/HANDOFF_SalonyMas_2026-08-08.md      (dónde quedamos)
3. docs/00_producto/BARRIDO_Y_PLAN_MAESTRO_2026-08-08.md  (qué hay y qué falta)
4. docs/00_producto/PLAN_DE_LANZAMIENTO_2026-08-06.md     (el mapa de etapas)
5. docs/00_producto/REGISTRO_DE_DECISIONES.md, decisiones D-109 a D-115
6. docs/00_producto/ESPECIFICACION_AGENDA_2026-08-07.md   (para la tarea 2.6)

Estamos en la Etapa 2. Cerradas 2.1 a 2.4, y 2.5a y 2.5b del Dashboard.
El seguimiento vive en docs/00_producto/PLAN_DE_TRABAJO_A_PRODUCCION.xlsx.

Siguiente: tarea 2.6 — fusionar Agenda y Tickets en un solo módulo y
construir el tablero con vistas de día, semana y mes. La fusión se decidió
en D-105 el 07-ago y NUNCA se ejecutó: hoy Agenda tiene 234 líneas y
Tickets 3.699. La especificación está en ESPECIFICACION_AGENDA_2026-08-07.md.

Cómo trabajamos:
- Verifica en el código antes de afirmar; no asumas.
- ANTES de construir, dime en dos líneas qué vas a hacer y por qué, y espera
  mi confirmación. Quiero entender qué hacemos, por qué y para qué.
- Cuando tengas varios puntos que plantear, repítemelos en una lista para
  confirmar que los entendiste ANTES de empezar a resolver.
- Pregunta "¿algo más antes de seguir?" antes de cerrar cada bloque.
- Registra cada decisión en REGISTRO_DE_DECISIONES.md con el porqué, no solo
  el qué, incluyendo lo que se descartó y por qué.
- Lo que aparezca en el camino se anota y se ataca donde le corresponde en el
  plan; si no cabe en ninguna etapa, va al apartado 11.
- Pide permiso antes de tocar Cloudflare, Supabase o hacer push.
- Cualquier instalación en mi computador la ejecuto yo, no tú: lo que instalan
  tus procesos no llega a mi máquina.
- Recuérdame respaldar antes de cualquier sesión con migraciones:
  scripts\respaldo_supabase.ps1
- Yo pruebo en producción y te reporto; tú no puedes ver la interfaz.

Pendiente mío y bloqueante: definir los 3 precios de los planes.
```

---

## 9. Evidencia

- **22 commits**, de `1560f2f` a `617f390`
- **9 migraciones** aplicadas al proyecto real el 08-ago
- **Decisiones D-109 a D-115** en `REGISTRO_DE_DECISIONES.md`
- **Respaldo del 08-ago** en `OneDrive\Documents\BeautyOS Backups`
- Versión publicada verificable en Configuración → Versión
