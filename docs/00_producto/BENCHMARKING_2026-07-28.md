# Benchmarking — BeautyOS vs. AgendaPro

**Fecha:** 28 de julio de 2026
**Estado:** primer corte, cubre AgendaPro. Se amplía si se revisan otras
apps (Fresha, Booksy, etc.) o si se agregan más capturas.
**Por qué existe:** punto 5 de `RUTA_GENERAL_2026-07-25.md` ("Pulido
general antes de dar la Fase MVP por cerrada") incluye mejorar la
apariencia y funcionalidad de la app comparando contra referencias reales
del mercado. Este documento es el primer benchmarking hecho con datos
reales (cuenta de prueba propia en AgendaPro, no capturas de marketing).

## 1. Metodología

El propietario creó una cuenta de prueba gratuita real en
`app.agendapro.com` y compartió ~25 capturas de pantalla navegando:
onboarding, configuración de sede/profesionales, comisiones, WhatsApp,
consentimientos, encuestas, membresías, recursos, planes de suscripción y
precios, login con 2FA, agenda con una cita real, bloqueo de horas
recurrente, flujo de crear una reserva, base de clientes y ficha de
cliente, e inventario de productos.

Cada punto de BeautyOS mencionado abajo fue **verificado contra el código
real** (tablas, migraciones, modelos Flutter) en esta sesión, no de
memoria — así que las brechas descritas son las que existen hoy, no
supuestos.

## 2. Resumen por módulo

| Módulo | AgendaPro | BeautyOS hoy | Prioridad sugerida |
|---|---|---|---|
| Onboarding de negocio nuevo | Checklist guiado "Primeros pasos X/6" | Formulario único de registro, sin guía posterior | **Alta** |
| Comisión de estilista | Por defecto + editable por profesional y por servicio | Una sola política por tenant (%, o fijo), igual para todos | **Alta** |
| Marca del negocio en reserva pública | Logo + foto de portada + foto/bio por profesional | Logo (recién construido, D-077); sin portada ni foto/bio de profesional | **Media-Alta** |
| Ficha de cliente / saldo | Documento, dirección, género, fecha nacimiento, saldo y deudas acumuladas, pestañas (Fichas, Consentimiento, Encuestas, Sesiones, Mensajería, Archivos) | Nombre, teléfono, correo, notas. Deuda solo por ticket individual, no acumulada | **Media** |
| Paquetes/membresías de cliente | Sí (paquetes de sesiones prepagadas) | No existe | **Media** |
| Checklist de seguridad (2FA) | Login con 2FA por correo | Login de un solo factor | **Media** (ya está en el punto 5 de la ruta como "repetir checklist de seguridad") |
| Recurrencia (citas y bloqueos) | Repetir cita o bloqueo (diario/semanal hasta fecha) | Solo rango único, sin repetición | **Media** |
| Colores por estado de reserva | 6 estados con color distinto cada uno | 10 estados (más granular que AgendaPro), pero un solo color para todos en la UI | **Baja** (cosmético) |
| Inventario: marca, formato, IVA, comisión de venta, alarma por correo | Todo lo anterior | Categoría y stock mínimo sí; sin marca, sin IVA, sin comisión de venta de producto, alarma solo visual (sin correo) | **Baja-Media** |
| Encuestas de satisfacción (aparte de reseñas) | Sí, módulo separado | No — se cubre parcialmente con reseñas (D-059) | **Baja** |
| Consentimientos digitales | Sí, formularios firmables | No existe | **Baja** (depende del vertical del negocio; Naguara de Uñas no lo necesita hoy) |
| WhatsApp con plantillas automáticas | Sí (bienvenida, recordatorio, encuesta) | No — decisión ya tomada de posponerlo (D-005, D-058) | Sin cambio — ya es una decisión consciente, no una brecha nueva |
| Precios de referencia | Básico $99.000 / Premium $150.000 / Pro $510.000 COP/mes | Sin precios definidos todavía (`RUTA_A_PRODUCCION`, Fase Final) | Informativo, no accionable todavía |

## 3. Detalle por módulo

### 3.1 Onboarding guiado — Alta prioridad

AgendaPro muestra un panel "Primeros pasos" con contador (`1/6`, `2/6`...)
que guía al dueño nuevo: configurar horario, agregar un profesional,
crear un servicio, probar una reserva por WhatsApp, conocer su sitio web.
Cada tarea tiene un botón "Iniciar" directo a la pantalla correspondiente.

BeautyOS hoy (`complete_tenant_setup_page.dart`) solo pide nombre del
negocio, nombre del dueño y WhatsApp, y después de eso el dueño llega a
una app vacía sin ninguna guía de qué hacer primero (crear servicios,
estilistas, horario...).

**Por qué es alta prioridad:** el propietario mismo definió como
principio del proyecto que quien usa BeautyOS "no tiene formación
técnica" — un checklist así reduce fricción real de adopción sin tocar
nada de seguridad. Además, la mayoría de las pantallas que necesitaría el
checklist ya existen (Horarios, Estilistas, Servicios), así que es
principalmente una pantalla nueva que enlaza trabajo ya construido, no
una funcionalidad nueva de cero.

### 3.2 Comisión por profesional y por servicio — Alta prioridad

BeautyOS (`commission_policies`) tiene **una sola política por tenant**
(restricción `unique(tenant_id)`) — mismo porcentaje o monto fijo para
cualquier estilista y cualquier servicio. AgendaPro permite una comisión
por defecto y luego editarla por profesional individual, y dentro de eso
por servicio específico (ej. "Corte de Cabello: 0%" distinto del
default).

**Por qué es alta prioridad:** las comisiones son dinero real de
estilistas — es común en la industria que un estilista senior tenga
mejor comisión que uno junior, o que un servicio de alto margen pague
distinto a uno de bajo margen. Hoy BeautyOS no puede modelar eso en
absoluto, y es del tipo de brecha que "ya se construyó la mitad y quedó
invisible" (mismo patrón que la brecha de planes detectada en D-063).

### 3.3 Marca del negocio: portada + perfil del profesional — Media-Alta

D-077 (recién cerrado) agregó logo por negocio. AgendaPro va más allá:
foto de portada grande (banner) separada del logo, y cada profesional
tiene su propia foto + biografía visible en la página pública de
reserva. BeautyOS hoy (`public_get_bookable_services`) solo expone
`stylist_name` — sin foto ni bio del profesional en la reserva pública.

**Por qué media-alta:** es una extensión natural y de bajo riesgo del
trabajo de Storage que ya existe (reutilizado tres veces: fotos de
trabajo D-060, logo D-077) — el patrón ya está probado.

### 3.4 Ficha de cliente y saldo acumulado — Media

La ficha de AgendaPro es mucho más completa: documento de identidad,
dirección con códigos de departamento/municipio (parece preparación para
facturación electrónica DIAN, que BeautyOS no necesita todavía), género,
fecha de nacimiento, y — lo más relevante — una pestaña "Pagos y deudas"
con saldo acumulado del cliente, no solo por ticket.

BeautyOS (`clients`) solo tiene nombre, teléfono, correo y notas; la
deuda existe solo a nivel de un ticket individual (`ticket_payments`),
sin un acumulado histórico del cliente.

**Por qué media:** los campos tipo documento/dirección/género no
parecen urgentes para el negocio real actual (Naguara de Uñas), pero un
saldo/deuda acumulada del cliente sí podría ser útil para negocios con
clientes frecuentes que dejan cuentas pendientes.

### 3.5 Membresías/paquetes de sesiones — Media

AgendaPro permite venderle a un cliente un paquete prepagado de
sesiones (ej. "5 manicures por $X"). BeautyOS no tiene nada parecido —
ni tabla ni concepto. Es distinto de los planes SaaS de suscripción
(D-044), que son para el negocio, no para el cliente final.

**Por qué media:** es una funcionalidad de negocio real y común en
estética/belleza (fideliza clientes, mejora flujo de caja anticipado),
pero es una construcción nueva completa (tabla, RPCs de consumo,
UI), no una extensión de algo existente — más esfuerzo que las
anteriores.

### 3.6 Checklist de seguridad — 2FA — Media

AgendaPro pide un código de 6 dígitos por correo al iniciar sesión.
BeautyOS usa login de un solo factor (`signInWithPassword`), sin ningún
segundo factor. Esto conecta directamente con el punto 5 de
`RUTA_GENERAL_2026-07-25.md` que ya menciona "repetir el checklist de
seguridad técnica" — no es una idea nueva, es una instancia concreta de
ese punto ya planeado.

### 3.7 Recurrencia en citas y bloqueos — Media

`stylist_time_off` (D-075) y `public_create_booking` solo admiten un
rango único de fecha/hora — sin columnas ni lógica de repetición.
AgendaPro permite "Repetir" tanto al crear una reserva como al bloquear
horas (diario/semanal, hasta una fecha). Sin esto, un estilista que
necesita bloquear todos los lunes de un mes tiene que crear el bloqueo
manualmente uno por uno.

### 3.8 Cosas donde BeautyOS ya está a la par o mejor

Para no dar una impresión sesgada — no todo es brecha:

- **Estados de ticket**: BeautyOS tiene 10 estados (`solicitado`,
  `cotizado`, `apartado`, `confirmado`, `en_espera`, `en_proceso`,
  `finalizado`, `cerrado`, `cancelado`, `no_asistio`) más un sub-estado
  por servicio dentro del ticket — más granular que los 6 estados de
  AgendaPro. Solo falta el color por estado en la UI (hoy todos los
  badges son del mismo color morado), que es puramente cosmético.
- **Protección contra choques de agenda entre sedes** (D-073): no se
  verificó si AgendaPro la tiene, pero es un problema real que BeautyOS
  ya resolvió explícitamente tras una prueba real.
- **Multi-sede con aislamiento fuerte por tenant/sede** vía RLS + RPC
  `SECURITY DEFINER` en cada escritura — no es visible en las capturas
  de AgendaPro si tienen el mismo nivel de rigor en su arquitectura,
  pero es un principio no negociable de BeautyOS (`AGENTS.md`) que vale
  la pena mantener como diferenciador, no abandonar por copiar UI.

## 4. Ejecución acordada (2026-07-28): de más difícil a más fácil

El propietario pidió construir todos los hallazgos, uno por uno, en este
orden (el más difícil primero):

1. **Hecho (2026-07-28):** comisión por profesional y por servicio, con
   la variante adicional de que cada sede puede fijar su propia
   excepción (no solo por negocio completo como se propuso originalmente
   en el punto 2 de este documento). Ver D-078.
2. **Pausado (2026-07-28), no descartado:** paquetes/membresías de
   sesiones para clientes. El propietario decidió no construir esto sin
   un negocio real que lo pida -- hay demasiadas formas válidas de
   diseñarlo (por servicio específico vs. crédito genérico, integrado al
   cobro/comisiones vs. desacoplado) para decidirlas sin un caso real que
   guíe la elección. Se retoma cuando un tenant real lo necesite.
3. **Hecho (2026-07-28):** 2FA en el login, con TOTP (app autenticadora)
   en vez de código por correo, opcional por usuario. Ver D-079.
4. Recurrencia en citas y bloqueos de agenda -- dividido en dos por
   riesgo:
   - **4a. Hecho (2026-07-28):** bloqueo de agenda del estilista
     recurrente (diario/semanal hasta una fecha, tope 180 días). Bajo
     riesgo: cada ocurrencia es una fila normal, no tocó ninguna función
     de disponibilidad/choque de agenda existente. Ver D-080.
   - **4b. Hecho (2026-07-28):** citas recurrentes, solo agenda interna
     (no reserva pública). Si una fecha de la serie choca con otra cita,
     se crean las que no chocan y se avisa cuáles fallaron y por qué, en
     vez de cancelar toda la serie. Ver D-081.
5. Ficha de cliente con saldo acumulado
6. Portada + foto/bio del profesional en reserva pública
7. Onboarding guiado ("Primeros pasos")
8. Inventario: marca, alarma de stock por correo
9. **Hecho (2026-07-28):** colores por estado de reserva -- un color
   distinto para cada uno de los 10 estados de ticket, antes todos
   compartían el mismo morado. Cambio cosmético, 100% Flutter, sin
   migración. Ver D-082.

Si se revisa otra app (Fresha, Booksy) o se agregan más capturas de
AgendaPro, este documento se actualiza en vez de crear uno nuevo.

## 5. Estado al cierre de la sesión del 2026-07-28 (para el siguiente chat)

**Hecho y desplegado contra el proyecto real hoy:** D-077 (logo de
negocio, sesión anterior) y en esta sesión D-078 (comisión por
sede+estilista+servicio), D-079 (2FA por TOTP), D-080 (bloqueo de
agenda recurrente), D-081 (citas recurrentes, agenda interna), D-082
(colores por estado de ticket). Las migraciones de hoy son
`20260728100000`, `20260728120000` y `20260728130000` -- las tres
confirmadas aplicadas en el proyecto real (`supabase migration list
--linked` sin diferencias). `flutter analyze` y `flutter test` (5/5)
limpios al cierre.

**Verificación visual pendiente del propietario** (todo lo demás ya se
probó por SQL con rollback contra el proyecto real, pero un humano
todavía no lo ha visto funcionar en el navegador):
- D-078: la sección "Excepciones de comisión por estilista" en
  Configuración.
- D-079: activar 2FA con un teléfono real (botón de escudo en el
  encabezado) y confirmar que pide el código al volver a iniciar
  sesión.
- D-080/D-081: el interruptor "Repetir" en bloqueos de agenda ("Mi
  agenda") y en crear una cita nueva (Tickets → Nueva reserva).

**Sin construir todavía, en el orden acordado ("de más difícil a más
fácil"):**
- Punto 2 (paquetes/membresías de sesiones) -- **pausado a propósito**,
  no se retoma hasta que un negocio real lo pida.
- Punto 5: ficha de cliente con saldo acumulado.
- Punto 6: portada + foto/bio del profesional en reserva pública.
- Punto 7: onboarding guiado ("Primeros pasos").
- Punto 8: inventario -- marca, alarma de stock por correo.

**Importante -- nada de esto está en git todavía.** Toda la sesión del
2026-07-28 (D-078 a D-082, ~30 archivos) sigue como cambios locales sin
commit. Antes de cerrar esta sesión o abrir un chat nuevo, hay que
decidir si se hace commit ahora (recomendado, para no perder el trabajo
si algo pasa con el directorio local) -- ver la conversación para la
propuesta de mensaje de commit.

**Cómo arrancar el siguiente chat:** pegar `PROMPT_MAESTRO_IA.md`
completo, decir que se sigue en el punto 5 de este documento (ficha de
cliente con saldo acumulado) o el que se prefiera del orden de arriba, y
enlazar este archivo (`BENCHMARKING_2026-07-28.md`) más las últimas
entradas de `REGISTRO_DE_DECISIONES.md` (D-077 a D-082).
