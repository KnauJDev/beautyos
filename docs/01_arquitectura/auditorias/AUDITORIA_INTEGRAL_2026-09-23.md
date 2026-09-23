# Revisión integral — 23 de septiembre de 2026

**Pedida por el propietario el 23-sep:** *"barras todo el proyecto y revises y
acomodes la documentación y nuestro plan maestro… tu punto de vista crítico y
actualizado en temas de Tech Stack, recuerda tu papel"*.
**Hecha por:** Claude Code, en el papel de Senior Tech Lead (`PLAN_MAESTRO` §8).
**Estado del proyecto revisado:** commit `d9176d6` (D-253), rama `main`, CI en verde.
**Decisión:** D-254.

> **Qué es este documento.** Una **foto de un momento**, como la auditoría del
> 06-ago: qué está mal hoy y qué haría el Tech Lead. **No manda sobre el plan**:
> lo que sale de aquí entra al `PLAN_MAESTRO` como hallazgos y como orden
> propuesto, y ahí se decide.

---

## 1. El resumen en una página

**El proyecto está sano donde más cuesta estarlo, y débil donde es más barato
arreglarlo.**

**Lo sano, medido:**

- **El CI pasa en verde en los últimos 20 commits**: analizador, 453 pruebas, el
  guardián de documentos y `deno check` de cada Edge Function.
- **Las 169 decisiones que cita el código existen todas.** El fallo de D-102 —el
  código citando una decisión que no está— no se ha repetido.
- **La seguridad está en el sitio correcto**: RPC en el servidor, RLS en las
  tablas, `verify_jwt` donde hay sesión, cabeceras web, secretos fuera del
  repositorio, dependencias de las Edge Functions fijadas a versión exacta.
- **La disciplina de registro es excepcional** para un proyecto de dos meses:
  253 decisiones con su porqué, y un guardián que las vigila.

**Lo débil, y todo es documental o de proceso, no de código:**

1. **El camino de cobro que queda nunca ha cobrado un peso real** (§3, R-01). Es
   lo único de esta revisión que puede costar dinero de un cliente.
2. **Las reglas técnicas con las que nació el proyecto, y el papel del
   asistente, se archivaron el 09-ago y nunca se mudaron** a un documento vivo
   (R-02).
3. **El Plan Maestro dejó de mandar sobre el orden el 07-sep** (R-03), y su tabla
   de módulos describía el producto de agosto (R-05).
4. **Los documentos que se leen antes de actuar estaban congelados**: el
   `MAPA_TECNICO` en agosto, los rectores de julio contradichos sin nota (R-04, R-07).
5. **Las cifras que reportábamos eran falsas**: el recuento de hallazgos no
   contaba la Ñ y daba por abiertos cinco cerrados (R-06).

**Todo lo documental quedó corregido en esta revisión.** Lo que queda es trabajo
del plan, con un orden propuesto en el `PLAN_MAESTRO` §5, Fase 9.

---

## 2. Cómo se hizo, y sus límites

| Qué | Cómo | Honestidad |
|---|---|---|
| `PLAN_MAESTRO` | **Entero, línea por línea** | — |
| `REGISTRO_DE_DECISIONES` | **El índice entero** (253 líneas) y el cuerpo de las decisiones núcleo (D-076, D-088, D-135, D-219, D-226, D-239) | La integridad índice↔cuerpo la vigila el guardián; no se releyeron los 660 KB de cuerpos |
| Los otros 20 documentos vivos | Leídos buscando lo que ya no es cierto | Las especificaciones de agosto se miraron solo en su estado |
| Los documentos que fundaron el proyecto | `PROMPT_MAESTRO_IA` y `EXPEDIENTE_TECNICO`, archivados | Leídos por lo que el propietario llamó *"las reglas con las que nació"* |
| **El código** | **Por estructura** (tamaños, capas, módulos, roles) y **barridos dirigidos** a los errores que ya se sabe que se repiten | **No se leyeron las 57.000 líneas una por una**: no caben en una lectura, y decirlo es parte del informe |
| **La base** | Por el catálogo vivo (`radiografia_de_la_base.sql`) | Ver §5 |
| El stack | `pubspec`, CI, Edge Functions, `web/`, servicios externos, historial del CI por la API de GitHub | — |

---

## 3. Los hallazgos de la revisión

| # | Qué | Gravedad | Dónde quedó |
|---|---|---|---|
| **R-01** | **El camino de cobro que queda nunca ha cobrado un peso real.** Los dos únicos cobros de la historia (23-ago y 08-sep) fueron por el camino del negocio, que D-252 cerró. El de la sede solo lo han ejercitado controles SQL | 🔴 | Paso **9.8**, subido al primer turno del orden propuesto. **La sede de Éxito, pactada en $4.500, es la prueba real más barata posible** |
| **R-02** | **El papel del asistente y los invariantes técnicos se perdieron al archivar el `PROMPT_MAESTRO_IA`** (D-126). El Plan Maestro se quedó con *cómo trabajamos*; se perdió *cómo está construido* —`setState`, capas simples, RPC `security definer`, dinero entero, no borrar— y *quién lo construye* | 🟡 | ✅ `ARQUITECTURA_Y_EVOLUCION.md` §4 y `PLAN_MAESTRO` §8 *"El papel del asistente"* |
| **R-03** | **El orden de la Fase 9 dejó de gobernar el 07-sep.** Desde entonces el orden lo dictaban los HANDOFF, contra la regla 1 del §2 | 🟡 | ✅ Orden nuevo propuesto en el `PLAN_MAESTRO`, **pendiente de tu aprobación** |
| **R-04** | **El `MAPA_TECNICO` estaba congelado a mediados de agosto**: 2 Edge Functions de 6, el hallazgo U abierto (cerrado el 30-ago), recuentos de un mes, y *"pedir permiso"* para el `push` una hora después de cambiar la regla | 🟡 | ✅ Puesto al día, con once trampas nuevas |
| **R-05** | **Pasos cerrados que otra decisión superó, sin nota.** Quien lea el 3.6 aprende que *el pionero es un 50%*. Doce filas así, más la tabla de módulos del §4 | 🟡 | ✅ Notas *"Superado por D-xxx"* sin borrar el texto; tabla de módulos nueva encima de la vieja |
| **R-06** | **El recuento de hallazgos estaba mal**: `[A-Z]` no incluye la Ñ, y D, G, O, P y AB estaban cerrados sin marcar | 🟡 | ✅ **BF**. Filas marcadas y **el guardián los cuenta solo** |
| **R-07** | **Los documentos rectores de julio contradicen decisiones posteriores sin decirlo** (D-076, D-188, D-239, D-250) | 🟡 | ✅ **BE**. *"Estado a 23-sep"* en cada uno, sin tocar el texto de julio |
| **R-08** | **D-076 caduca con el primer cliente real y no estaba en la lista de lo que cambia ese día.** Y la vista de soporte no ve las fotos: una decisión tuya rota en silencio por H-09 | 🟡 | **BC** y `MAPA_TECNICO` §1-bis |
| **R-09** | **AV es más grande de lo anotado: la página pública de precios no tiene tildes** —*resenas, pagina web publica, 21 dias, en linea*—, y es lo primero que ve un salón interesado | 🟡 | **AV** ampliado |
| **R-10** | **Los candados de plan sugieren subir a *Business* o *Profesional*, planes que no existen.** Latentes hoy; el 9.41 los vuelve a encender | 🟡 | **BD** |
| **R-11** | **Un quinto letrero rancio de D-252**: la ventana *Plan y etiqueta* decía *"la tarifa se pacta abajo"* y abajo ya no hay tarifa | 🟢 | ✅ Corregido en el código (regla 16-ter) |
| **R-12** | **La lógica de dinero sigue creciendo dentro de las pantallas.** Los tres archivos que el 9.13 y el 9.14 mandaban adelgazar **crecieron**: el panel de plataforma, 1.190 líneas más | 🟡 | Notas en 9.13 y 9.14 |
| **R-13** | **Deriva entre regla y práctica en las reglas 5 y 9**, la misma forma que la regla 12 (D-253): *"esperar confirmación antes de construir"* y *"preguntar ¿algo más antes de seguir?"* no se cumplen de forma consistente | 🟢 | **Pregunta abierta al propietario** (regla 20: se señala, no se resuelve por iniciativa propia) |
| **R-14** | **El asistente afirmó sin mirar tres veces el mismo día de la revisión**: que *Solo archivo interno* y *Visible al cliente* se contradecían (no: son el permiso y la visibilidad); que las reseñas no estaban en el portal (sí: *Calificar servicios pendientes*); y que el acceso de soporte a las fotos *"no lo decidió nadie"* (lo decidió el propietario, D-076). Las tres las destapó verificar después | 🟢 | Registrado en D-254. **La regla 1 existe; lo que falla es aplicarla antes de contestar, no después** |

---

## 4. La visión del stack, como Tech Lead

**Veredicto: el stack es el correcto para esta etapa. No cambiaría ninguna pieza
antes del cliente cero.** Lo que cambiaría es **cómo se opera**.

### Flutter Web como PWA

**A favor:** un solo código para web y celular, ya construido, costo cero de
hospedaje, y encaja con que la dueña lo instale desde el navegador (D-088).

**En contra, y conviene saberlo ya:**

- **12 MB antes de pintar nada** (hallazgo AC). No empeora con más usuarios, pero
  la primera impresión de un salón con datos móviles es lenta. **El Panel de
  Plataforma viaja al navegador de cada salón.** El arreglo de fondo es partir la
  app, que es el mismo trabajo que el 9.25 (D-226).
- **Una página hecha en Flutter la leen mal los buscadores.** La página pública
  de cada salón (`salonymas.com/<nombre>`) y la de precios se dibujan en un lienzo:
  Google ve poco texto. Para *"MI VITRINA"* y para que un salón *"lo busquen"*,
  eso importa. **No es para ahora** —primero el cliente cero—, pero cuando llegue
  la vitrina en serio, lo sensato es servir esas páginas públicas como HTML desde
  el servidor, leyendo las mismas funciones, y dejar Flutter para la aplicación.
  **Conviene verificarlo antes** con Google Search Console en la página de un salón.
- **`setState` no es el problema; los archivos de 5.000 líneas sí.** No
  introduciría Riverpod ni Bloc (invariante 1). Seguiría el patrón que ya funciona
  en este proyecto: **sacar reglas a modelos pequeños con pruebas**
  (`AccionesDeTicket`, `CelularColombiano`, `CodigoDeConfirmacion`).

### Supabase

**Encaja muy bien** y es lo mejor del stack: RLS y RPC resuelven la seguridad
multisede en el sitio correcto, y Auth, Storage, Edge Functions y `pg_cron`
evitan montar servidores.

**Los riesgos son del plan y de la operación, no de la tecnología:**

- **Un solo proyecto, que es producción, y se llama `beautyos-dev`.** No hay
  entorno de ensayo para migraciones: todo se prueba con controles que terminan
  en `rollback` contra la base real. Funciona —y es ingenioso— pero cada
  migración toca producción la primera vez que corre de verdad.
- **El plan Free no tiene recuperación a un punto en el tiempo y se pausa tras 7
  días sin actividad** (D-088).
- **Una pregunta para ti, no una corrección:** D-088 decía pasar a Pro *"cuando
  un negocio real empiece a cargar datos"*; D-226 lo movió a *"cuando pague el
  primer cliente"*. **Entre las dos fechas caben los 21 días de prueba**, con
  nombres y teléfonos de clientas de otro salón sin más red que un respaldo manual
  semanal. D-226 evaluó bien el riesgo de capacidad; **ese hueco no lo miró**.
- **El esquema no está en el repositorio** (AI). **Hay un arreglo barato que nadie
  ha propuesto:** el respaldo semanal **ya genera `schema.sql`** con el esquema
  entero. Guardar una copia —solo esquema, sin datos— en el repositorio le daría
  la foto completa, y es el primer paso para poder correr los controles SQL en el
  CI algún día.

### La operación de la base

**Es la fricción más grande del proyecto.** Cada migración son tres comandos que
corre el propietario, pegando la cadena de conexión y la contraseña cada vez. En
esta revisión, **una extracción de lectura tardó cinco idas y vueltas** por tres
errores del asistente (una tabla inventada, un agregado, una sobrecarga).

La idea **I-13** —darle al asistente acceso de lectura con un token revocable—
cumple su condición desde el 09-ago y **espera tu decisión**. Solo lectura ya
quitaría la mitad de las idas y vueltas sin tocar la regla de que las migraciones
las aplicas tú. **Es tu decisión, no la mía**: es acceso permanente a producción.

### ePayco, Resend, Sentry, Cloudflare, GitHub

- **ePayco** encaja con la cuña de D-219 (PSE, Nequi, pesos). Hoy el cobro es **un
  pago por período** que la dueña hace a mano; la cuenta admite cobro recurrente
  (paso 3.1) y conviene pasarse a él **después** del cliente cero: cobrar solo cada
  mes es la diferencia entre retener y perseguir.
- **Resend** (correos), **Sentry** (errores, con datos personales saneados),
  **Cloudflare** (hospedaje, dominio, reenvío de correo) y **GitHub** (código y CI)
  están bien elegidos y cuestan casi nada.
- **Falta HSTS en Cloudflare** (9.17): dos minutos tuyos en su panel.

### Dependencias

Diez dependencias directas, magras. `supabase_flutter` va dos versiones atrás; el
`passkeys_bundle.js` que exige para arrancar (D-090) **hay que revisarlo en cada
subida**. Conviene una ventana de actualización **antes** del cliente cero, no
durante.

### Lo que no existe y habrá que tener

- **WhatsApp**, que D-219 declaró la cuña competitiva: **el trámite con Meta (9.26)
  son semanas de espera y lleva parado desde el 07-sep.** Es lo único del plan que
  se retrasa solo por no pedirlo.
- **Los derechos de la clienta sobre sus datos** (Ley 1581): consultar, corregir y
  suprimir. El diseño de julio los daba por existentes y no hay ningún camino.
  Va con el 9.20.

---

## 5. La base de datos, vista desde el catálogo

*Pendiente: se completa con la salida de
`supabase/sql/intervenciones/radiografia_de_la_base.sql`.*

---

## 6. Qué haría yo, en orden

Es el **orden propuesto** que quedó en el `PLAN_MAESTRO` (Fase 9), resumido:

1. **Que el primer cobro funcione**: un pago real de $4.500 con la sede de Éxito
   (9.8 y 9.7), y el historial con sede (9.40).
2. **Lo legal antes de datos de otra persona**: abogado (9.20), contador (9.16),
   que la clienta autorice (9.48), el acceso de soporte (BC).
3. **Lo que ve el cliente, barato**: tildes (AV), candados (BD) y los sueltos.
4. **El campo**: protocolo de bienvenida, entrevistas, y **Meta ya**.
5. **La estructura**, con lo que digan las entrevistas: 9.25 → I-19.

**Y dos decisiones tuyas que abaratan todo lo demás:** I-13 (acceso de lectura
para el asistente) y cuándo pasar a Supabase Pro (§4).

---

*Esta revisión no se actualiza: es una foto. Lo que cambie después se registra
como decisión y se refleja en el `PLAN_MAESTRO`.*
