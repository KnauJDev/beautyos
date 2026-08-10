# Ruta general de BeautyOS — mapa único (reemplaza listas dispersas)

**Fecha:** 25 de julio de 2026
**Por qué existe este documento:** el propietario señaló que había demasiados
pendientes repartidos en varios documentos (`PROMPT_MAESTRO_IA.md`,
`AUDITORIA_ROLES_Y_BRECHAS_2026-07-24.md`, `RUTA_A_PRODUCCION_2026-07-25.md`,
`CRITERIOS_SALIDA_FASE_1.md`) y que eso podía hacer que la ruta se confundiera
entre chats nuevos. Este documento es ahora **la única fuente de "qué sigue y
en qué orden"**. Los demás documentos siguen existiendo como evidencia y
detalle de cada bloque, pero ya no proponen su propio orden por separado.

## Decisión de fases

1. **Fase MVP (foco actual):** terminar de pulir el producto -- todo lo que
   pasa dentro de la app y su base de datos.
2. **Fase Final (después, no ahora):** todo lo que convierte el producto en
   un negocio real que cobra -- hosting permanente, dominio propio, plan
   pago de Supabase, precios definidos, empresa constituida, términos y
   política de privacidad, pasarela de pago (Wompi) y cómo conseguir
   clientes. Todo esto ya está mapeado en `RUTA_A_PRODUCCION_2026-07-25.md`
   y no se repite aquí; simplemente queda pausado hasta terminar la Fase MVP.

---

## Fase MVP — orden sugerido

### 1. Terminar lo que ya está a medias

**1.1 Correo automático de invitación de equipo -- [x] Hecho (2026-07-25).**
Construido, desplegado y verificado de extremo a extremo contra el proyecto
real: correo enviado automáticamente al invitar, y aceptación de la
invitación probada en el navegador del propietario (login nuevo → pantalla
"Te invitaron a..." → unido como estilista). Ver D-065.

**1.2 Verificar en el navegador real que subir una foto de trabajo funciona
-- [x] Hecho (2026-07-25).** El propietario probó en su navegador: subir
imagen, aprobar/ocultar (interruptores) y los contadores de fotos, todo
correcto. Cierra por completo D-060/D-061. Ver D-064.

### 2. Una brecha real que hoy nadie está vigilando: los planes no se hacen cumplir

Se construyó toda la base de suscripciones y planes (D-044: `plans`,
`tenant_subscriptions`, límites por plan) y el registro con prueba gratis de
21 días (D-045), pero **ninguna función del negocio consulta esos límites
todavía**. En la práctica, hoy:

- Un negocio en plan Básico puede usar funciones de Business/Profesional sin
  ninguna restricción.
- Una prueba gratis vencida **no se corta sola** -- sigue funcionando como
  si nada.

Esto no apareció en las listas anteriores como bloque propio porque se
registró como "fundación" (D-044/D-045), pero es justamente el tipo de
"cosita que no se está trabajando": ya se construyó la mitad y quedó
invisible. Se sugiere resolverlo antes de seguir sumando funciones nuevas,
para no construir sobre una base de planes que no hace nada todavía.

**2.1 Hecho (2026-07-26): prueba gratis vencida.** Se decidió y construyó
el primer sub-bloque: cuando la prueba se vence sin pago, el negocio no
puede aceptar reservas ni citas nuevas, pero conserva todo lo demás
(catálogo, equipo, compras, gastos, reportes, cerrar tickets abiertos).
Avisos dentro de la app a 10 y 3 días antes de vencer. Ver D-068.

**2.2 Hecho (2026-07-26):** un plan Básico ya no puede crear inventario,
compras, gastos, consumo interno, fotos de trabajo nuevas, ni un cliente
dejar una reseña nueva; los reportes financieros ampliados quedan
bloqueados por completo (son de solo lectura). Editar/gestionar lo que ya
existe sigue igual sin importar el plan. Ver D-069. Hoy no hay ningún
tenant real en Básico, así que no tiene efecto visible todavía.

### 3. Descartado (2026-07-26): no era un bug real

Este punto decía que `UsuariosPage` estaba restringida a `owner` en
Flutter aunque el backend ya permitía también a `admin` (nota de D-050).
Al verificar el código real, eso es falso: `get_tenant_users` y
`update_tenant_user_access` exigen explícitamente `tenant_owner` desde
D-041 (2026-07-22), un día *antes* de que se escribiera esa nota -- la
nota nunca fue cierta, no es que algo cambiara después. Flutter y la base
de datos coinciden: solo el dueño administra usuarios, tal como está hoy.
Ver D-070.

**Actualización (2026-07-26):** el propietario aclaró que sí quería que
un administrador gestionara usuarios -- se corrigió: `get_tenant_users` y
`update_tenant_user_access` ahora aceptan también `admin`, con las mismas
protecciones (no puede tocar su propia cuenta ni la del dueño). Ver
D-071.

### 3.1 Corregido durante pruebas reales (2026-07-25): menú "Servicios"

Se encontró y corrigió un bug real: el menú "Servicios" se mostraba
también a estilistas y asistentes, pero la función detrás solo autoriza a
dueño/administrador -- por eso la pantalla truena para cualquier estilista
real. Ver D-066.

### 3.2 Construido durante pruebas reales (2026-07-25): panel del estilista

A partir de probar con la cuenta real de un estilista, se agregaron
**"Mis reseñas"** (sus propias calificaciones/comentarios, algo prometido
desde D-058 y nunca construido) y **"Mi panel financiero"** (solo su
comisión por servicio prestado, con filtro de rango de fechas). Ver D-067.

### 4. Brechas funcionales confirmadas contra el código real (D-058)

En el orden sugerido por la propia auditoría de roles:

**4.1 Hecho (2026-07-27):** `create_branch` ya existe -- el dueño puede
crear sedes adicionales desde un botón junto al selector de sede. La sede
nueva no es una copia: queda vacía de catálogo (hay que asignarle
servicios/estilistas después), pero con horario y política de citas por
defecto ya sembrados. Ver D-072.

**4.1.1 Hecho (2026-07-27): choque de agenda entre sedes.** Al probar
4.1 con una sede real, se encontró que el choque de horarios solo
revisaba la sede actual -- un estilista activo en dos sedes podía quedar
doble-agendado a la misma hora en sedes distintas. Corregido: ahora
revisa todas las sedes del tenant para ese estilista. Ver D-073.

**4.1.2 Bajado de prioridad (2026-07-27):** la idea de días específicos
por sede para un estilista, y ver en su agenda qué sedes tiene asignadas.
El propietario y el chat coincidieron: con D-073 ya resuelto (no hay
riesgo de doble cita entre sedes), esto deja de ser una corrección
urgente y pasa a ser una comodidad de planeación administrativa (por
ejemplo, evitar agendas físicamente imposibles por tiempo de traslado
entre sedes el mismo día) -- se retoma más adelante, no bloquea la Fase
MVP. Distinto del punto 4.2 (ausencias).

**4.2 Hecho (2026-07-27):** el estilista ya puede bloquear su agenda
(vacaciones, incapacidad) desde "Mi agenda"; el dueño/administrador
también puede hacerlo por él. El rango bloqueado desaparece de horarios
disponibles (reserva pública y agenda manual) en todas sus sedes, y una
cita forzada en ese horario se rechaza. Ver D-075.

**4.3 Hecho (2026-07-27):** se reconfirmó D-009 -- el dueño de la
plataforma decidió que sí quiere ver (nunca editar ni borrar) los datos
de cualquier negocio para dar soporte: clientes/tickets, finanzas,
equipo, reseñas y fotos. Sin auditoría, por decisión explícita. Nuevo
botón "Ver datos (soporte)" en el Panel de plataforma. Ver D-076.

**4.4 Hecho (2026-07-27), solo logo:** el propietario acotó el alcance
original (logo + colores, D-062) a solo logo por ahora -- colores y
disposición visual quedan para el benchmarking del punto 5. Solo
`tenant_owner` puede subir/cambiar el logo; se ve en Configuración, el
encabezado interno, la reserva pública y el enlace de reseña pública. El
propietario probó en su propio navegador (Naguara de Uñas): subió un logo
real y se ve correcto en Configuración. Ver D-077. El dominio propio por
negocio sigue fuera de alcance por ahora (ver Fase Final).

### 5. Pulido general antes de dar la Fase MVP por cerrada

- **Apariencia visual de la app** -- pulir lo que ya existe (esto seguía
  mencionado en `RUTA_A_PRODUCCION` como punto 1 de Fase 1, pero es trabajo
  de producto/código, no de negocio; se reubica aquí). El 2026-07-28 se hizo
  el primer benchmarking real (cuenta de prueba en AgendaPro) con
  priorización sugerida -- ver `BENCHMARKING_2026-07-28.md`. Nada de esto
  implementado todavía; queda para cuando el propietario confirme cuál
  candidato sigue.
- **Ampliar pruebas automatizadas** -- hoy solo hay 3 archivos de prueba
  (`test/`) para unos 30 servicios de Flutter. La validación real se ha
  hecho a mano (SQL con rollback, pruebas en navegador) en cada bloque, lo
  cual es sólido pero no queda como red de seguridad repetible contra
  regresiones futuras.
- **Repetir el checklist de seguridad técnica** de
  `docs/04_pruebas/CRITERIOS_SALIDA_FASE_1.md` (sección 7: RLS, grants,
  `search_path`, índices, logs sin secretos, auditoría). Ese documento es
  anterior al Tramo D y probablemente varios puntos ya están resueltos sin
  marcarse; conviene una pasada honesta para marcar qué quedó cerrado de
  verdad y qué no, en vez de asumir.

---

## Qué NO se toca hasta terminar la Fase MVP

Pasarela de pago (Wompi), hosting, dominio, plan pago de Supabase, precios,
empresa constituida, términos/privacidad y marketing quedan en
`RUTA_A_PRODUCCION_2026-07-25.md`, sin trabajarse todavía. Wompi en
particular ya estaba bloqueada por un trámite presencial tuyo (D-046); ahora
además queda deliberadamente pospuesta de prioridad.

## Cómo usar este documento en un chat nuevo

Igual que indica `PROMPT_MAESTRO_IA.md`: pega ese documento completo, di en
qué punto de este mapa vas, y sigue el orden de arriba salvo que tú decidas
cambiarlo explícitamente.
