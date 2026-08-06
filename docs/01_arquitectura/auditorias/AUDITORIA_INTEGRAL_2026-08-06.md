# BeautyOS — Auditoría integral y expediente técnico

**Fecha:** 6 de agosto de 2026
**Alcance:** revisión completa del aplicativo: código Flutter, base de datos real, funciones, seguridad, perfiles de usuario y recorridos funcionales.
**Método:** todo lo que se afirma aquí fue **verificado contra el código real y contra el proyecto Supabase real** (`eogppgbdnwxdtcbctaol`) el día de la auditoría. No hay nada dicho de memoria ni supuesto.
**Estado del proyecto auditado:** commit `6a3d912` (D-086), rama `main`, árbol de trabajo limpio.

---

## 1. Resumen ejecutivo (en lenguaje simple)

BeautyOS **está sólido**. La arquitectura de seguridad es coherente y, en varios aspectos, más estricta que la de muchos productos comerciales: ninguna de las 41 tablas de datos permite que la aplicación entre a leer o escribir directamente, salvo dos excepciones controladas. Todo pasa por funciones del servidor que verifican quién eres, a qué negocio perteneces y a qué sede tienes acceso, **cada vez**.

La verificación más importante de esta auditoría: se compararon las **111 llamadas** que la aplicación Flutter hace al servidor contra las **122 funciones** que el servidor expone. **Ninguna llamada está rota.** Esto significa que no hay pantallas que vayan a fallar por una función que no existe o que cambió de forma — un riesgo real, porque en los últimos bloques (D-084, D-086) se cambió la firma de cuatro funciones.

Lo que sí encontré, en orden de importancia:

1. **El rol "Asistente" no tiene ninguna pantalla.** Es el valor que aparece **por defecto** cuando invitas a alguien a tu equipo. Si invitas a un asistente, esa persona se registra, entra… y ve un mensaje que dice "Tu usuario no tiene modulos asignados". Mientras tanto, 14 funciones del servidor **sí** lo autorizan a crear clientes, agendar citas y cobrar. Es trabajo ya construido que quedó invisible.
2. **La reserva pública no tiene freno contra abuso.** Cualquiera con el enlace de reservas puede crear reservas sin límite, y cada una **ocupa el horario de inmediato**. Alguien malintencionado podría llenar la agenda de una sede con citas falsas y ensuciar la lista de clientes. Hoy no es urgente (nadie tiene el enlace), pero sí lo es antes de publicarlo a clientes reales.
3. **Casi no hay pruebas automáticas.** Hay 5 pruebas para ~24.800 líneas de código y 173 funciones de base de datos, y ninguna cubre dinero, comisiones ni tickets. Cada bloque se ha probado a mano con SQL y rollback (bien hecho), pero eso no protege contra romper algo viejo al construir algo nuevo.

Nada de lo encontrado es un error que esté causando daño hoy. Son **huecos y deudas** que conviene cerrar antes de tener clientes reales pagando.

---

## 2. Cifras verificadas del aplicativo

### 2.1 Aplicación Flutter

| Concepto | Cantidad |
|---|---|
| Líneas de código Dart | 24.773 |
| Páginas (`lib/pages/`) | 29 |
| Servicios (`lib/services/`) | 42 |
| Modelos (`lib/models/`) | 49 |
| Widgets compartidos (`lib/widgets/`) | 6 |
| Archivo más grande | `tickets_page.dart` (3.700 líneas) |
| Marcadores `TODO`/`FIXME`/`HACK` | **0** |
| Pruebas automatizadas | 3 archivos, 5 pruebas, 111 líneas |

**Dependencias externas (5, todas de uso justificado):** `supabase_flutter ^2.15.0`, `image_picker ^1.1.2`, `uuid ^4.5.1`, `flutter_svg ^2.3.0`, `cupertino_icons ^1.0.8`. No hay gestor de estado externo — se cumple la regla de `StatefulWidget + setState` de `PROMPT_MAESTRO_IA.md`.

### 2.2 Base de datos (Supabase/PostgreSQL)

| Concepto | Cantidad |
|---|---|
| Tablas en `public` | 41 |
| Tablas con RLS activo | 41 (**100%**) |
| Tablas con acceso directo para la app | **2** (`services`, `user_profiles`) |
| Funciones en `public` | 159 |
| Funciones en `private` | 14 |
| Funciones sin `search_path` fijo | **0** |
| Triggers activos | 28 |
| Buckets de Storage | 4 |
| Edge Functions desplegadas | 2 (ambas `ACTIVE`) |
| Migraciones versionadas | 56 |
| Diferencias local ↔ remoto | **0** |

### 2.3 Estado real del único proyecto

| Dato | Valor |
|---|---|
| Negocio | Naguara de Uñas |
| Plan | `profesional` |
| Estado suscripción | `trialing` hasta **2026-08-14** |
| Sedes | 2 |
| Miembros activos | 2 |

> **Nota operativa:** la prueba gratis vence en 8 días. El banner de aviso de D-068 (amarillo a 10 días) **ya debería estar visible** en la app para el propietario. Es la primera ocasión real de comprobar ese banner funcionando.

---

## 3. Arquitectura de seguridad — cómo está realmente construida

Este es el punto más fuerte del producto y conviene entenderlo bien.

### 3.1 El principio: la base de datos está cerrada por defecto

Las 41 tablas tienen RLS (seguridad por fila) activo. Pero lo revelador es que **solo 3 políticas RLS existen en todo el esquema público**. En la mayoría de sistemas eso sería un error grave. Aquí es deliberado y correcto:

> RLS activo **sin ninguna política** significa: *nadie puede leer ni escribir esta tabla directamente, nunca, sin importar quién sea.*

Se confirmó con permisos: **39 de 41 tablas no tienen ningún `GRANT`** para los roles `anon` ni `authenticated`. La aplicación literalmente no puede tocarlas. Todo acceso ocurre a través de funciones `SECURITY DEFINER` que validan autorización en el servidor.

### 3.2 Las dos excepciones controladas

| Tabla | Permiso | Política que la protege |
|---|---|---|
| `services` | `SELECT` | Solo servicios del propio tenant, activos y visibles al cliente |
| `user_profiles` | `SELECT` + `UPDATE` **por columna** (solo `full_name`, `updated_at`) | Solo la propia fila del usuario y estando activo |

El caso de `user_profiles` está especialmente bien resuelto: el permiso de escritura está limitado **a nivel de columna**, así que aunque la política permitiera más, un usuario no puede cambiarse su propio `role` ni su `tenant_id`. Esa es una defensa en profundidad correcta.

**Matiz relevante para el rol estilista:** la política de `services` permite que *cualquier* usuario autenticado del tenant lea el catálogo de servicios directamente. Un estilista no ve el menú "Servicios" (correcto, D-066), pero técnicamente podría leer esos datos vía API. No es una fuga (son los servicios de su propio negocio, que ya conoce), pero es la diferencia entre "no se lo mostramos" y "no puede verlo".

### 3.3 Estado de las funciones

| Categoría | Cantidad | Lectura |
|---|---|---|
| `public`, accesibles sin sesión (`anon`) | **7** | Superficie pública — el área a vigilar |
| `public`, con sesión, `search_path=pg_catalog` | 104 | Estándar actual, endurecido |
| `public`, con sesión, `search_path=public` | 11 | Heredadas, aún vivas |
| `public`, cerradas (sin acceso externo) | 37 | Deuda: código muerto retirado en D-024/D-040 |
| `private` | 14 | Ayudantes internos |

**Cero funciones sin `search_path` fijo.** Esto elimina por completo una familia de ataques (inyección por `search_path`) que es la vulnerabilidad más común en funciones `SECURITY DEFINER` de PostgreSQL. Es un acierto que conviene mantener como regla al crear cada función nueva.

### 3.4 Las 7 puertas abiertas al público (sin sesión)

| Función | Qué hace | Riesgo |
|---|---|---|
| `public_get_branch_booking_info` | Datos de la sede para reservar | Bajo — información que el negocio quiere pública |
| `public_get_bookable_services` | Servicios, precios, profesionales | Bajo — es un catálogo comercial |
| `public_get_available_slots` | Horarios libres | Bajo |
| `public_create_booking` | **Crea la reserva** | **Ver hallazgo H-02** |
| `public_get_ticket_for_review` | Datos del ticket para reseñar | Bajo |
| `public_create_review` | Crea la reseña | Bajo — índice único impide duplicados |
| `list_public_plans` | Lista de planes | Nulo — hoy sin consumidor y sin precios |

Las seis `public_*` exigen un UUID de sede o de ticket. Los UUID no son adivinables, así que el acceso requiere que alguien comparta el enlace deliberadamente — que es justamente su propósito.

### 3.5 Almacenamiento de archivos (Storage)

4 buckets, **todos públicos**, cada uno con **una sola política, de solo inserción**:

| Bucket | Quién puede subir | Ruta |
|---|---|---|
| `work-photos` | Dueño / admin / estilista de esa sede | `{branch_id}/…` |
| `tenant-logos` | Solo `tenant_owner` | `{tenant_id}/…` |
| `tenant-covers` | Solo `tenant_owner` | `{tenant_id}/…` |
| `stylist-photos` | Dueño / admin del tenant | `{tenant_id}/{stylist_id}/…` |

Dos consecuencias reales de este diseño (ver **H-09**):
- **No hay política de borrado ni de reemplazo.** Al cambiar un logo, el archivo anterior **queda para siempre** en el bucket. Con el tiempo se acumula basura que nadie puede limpiar desde la app.
- **Los buckets son públicos:** cualquiera con la URL ve la imagen, para siempre, aunque en la app la foto se haya ocultado. Los interruptores de visibilidad de D-061 controlan qué se muestra **en la app**, no el acceso al archivo.

---

## 4. Perfiles de usuario — matriz completa de accesos

El sistema maneja **tres fronteras independientes** (D-009): plataforma, negocio (tenant) y sede (branch). Ser dueño de la plataforma no te da acceso a un negocio, y pertenecer a un negocio no te da acceso a todas sus sedes.

### 4.1 Mapa general

| Perfil | Dónde se define | Módulos en la app | Funciones backend |
|---|---|---|---|
| **Dueño de plataforma** (`platform_owner`) | `platform_operators` | Panel de plataforma + soporte | 11 `platform_*` |
| **Operador de plataforma** (`platform_operator`) | `platform_operators` | Panel (solo lectura) | Ver sí, actuar no |
| **Propietario del negocio** (`owner`) | `tenant_memberships` | **14** | Todas |
| **Administrador** (`admin`) | `tenant_memberships` | **14** | Casi todas |
| **Estilista** (`stylist`) | `tenant_memberships` + `stylist_id` | **4** | Solo lo propio |
| **Asistente** (`assistant`) | `tenant_memberships` | **0** ⚠️ | 14 lo autorizan |
| **Cliente** (`client`) | Rol por defecto | **0** | — |
| **Anónimo** | Sin sesión | Reserva y reseña públicas | 7 |

### 4.2 Los 18 módulos y quién los ve

| Módulo | owner | admin | stylist | assistant |
|---|:--:|:--:|:--:|:--:|
| Dashboard | ✅ | ✅ | — | — |
| Agenda | ✅ | ✅ | — | — |
| Tickets | ✅ | ✅ | — | — |
| Clientes | ✅ | ✅ | — | — |
| Servicios | ✅ | ✅ | — | — |
| Estilistas | ✅ | ✅ | — | — |
| Usuarios | ✅ | ✅ | — | — |
| Reportes | ✅ | ✅ | — | — |
| Compras | ✅ | ✅ | — | — |
| Gastos | ✅ | ✅ | — | — |
| Inventario | ✅ | ✅ | — | — |
| Fotos de trabajos | ✅ | ✅ | — | — |
| Reseñas | ✅ | ✅ | — | — |
| Configuración | ✅ | ✅¹ | — | — |
| Mi agenda | — | — | ✅ | — |
| Mis fotos | — | — | ✅ | — |
| Mis reseñas | — | — | ✅ | — |
| Mi panel financiero | — | — | ✅ | — |

¹ El admin ve Configuración pero **sin** los botones de logo y portada (`isOwner == false`), coherente con que esas dos acciones son exclusivas del dueño en el backend.

### 4.3 Acciones exclusivas del propietario

Verificadas en el backend, no solo ocultas en la interfaz:

- Crear sedes (`create_branch`)
- Subir/cambiar logo y portada (`update_tenant_logo`, `update_tenant_cover_photo`)
- Editar encabezado de compra y anular compras (`update_purchase_header`, `void_purchase`)
- Editar y anular gastos (`update_expense`, `set_expense_active`)

El criterio es consistente y está bien pensado: **corregir errores de digitación que afectan dinero ya registrado es exclusivo del dueño.**

### 4.4 Aislamiento del estilista

Las funciones del panel personal (`get_my_stylist_reviews`, `get_my_commission_summary`, `get_my_stylist_time_off`, `get_my_stylist_work_photos_v2`) son **exclusivas del rol `stylist` sobre sus propios datos** — se probó explícitamente en D-067 que ni siquiera el dueño puede usarlas. Un estilista ve su comisión, nunca el valor de venta total ni las finanzas del negocio. Es un modelo de privacidad laboral correcto.

---

## 5. Recorridos funcionales verificados

### 5.1 Cliente final (sin cuenta)
1. Recibe enlace/QR → `?reservar=<branch_id>`
2. Ve portada, logo, nombre, dirección y el equipo con foto y biografía (D-084)
3. Elige servicio + profesional → fecha → horario real disponible
4. Deja nombre, celular, correo y notas
5. La reserva queda en `solicitado`, **siempre**, sin importar la configuración de anticipo (decisión de D-053, se mantiene hasta que exista pasarela de pago)
6. Tras el servicio: enlace `?resena=<ticket_id>` → califica una sola vez

### 5.2 Propietario del negocio
Registro self-serve → prueba de 21 días, plan Profesional → carga catálogo (servicios, estilistas, productos) → configura horario, políticas y comisiones → invita al equipo (correo automático vía Resend) → opera agenda y tickets → cobra → el sistema calcula comisiones aplicando excepciones por sede/estilista/servicio (D-078) → revisa reportes → modera reseñas y fotos.

### 5.3 Estilista
Recibe invitación → se registra con ese correo → la app lo reconoce y lo une al negocio → ve **solo** su agenda, sus bloqueos (incluidos los recurrentes de D-080), sus fotos, sus reseñas y su comisión por servicio con filtro de fechas.

### 5.4 Dueño de plataforma
Entra y **no** ve la app de negocio: `AuthenticatedRouter` lo desvía al Panel de plataforma. Lista negocios, suspende/reactiva/extiende pruebas (con motivo obligatorio y auditoría en `subscription_events`) y entra a "Ver datos (soporte)" — 6 vistas de solo lectura sobre clientes, tickets, finanzas, equipo, reseñas y fotos. Decisión consciente de D-076: **este acceso no deja rastro de auditoría**, a diferencia de suspender/reactivar.

### 5.5 Asistente
Recibe invitación → se registra → **ve "Tu usuario no tiene modulos asignados"**. Fin del recorrido. Ver H-01.

---

## 6. Modelo comercial y su cumplimiento

| Plan | Precio | Reportes | Inventario | Portafolio | Reseñas | Publicación social |
|---|---|:--:|:--:|:--:|:--:|:--:|
| `basico` | **NULL** | ❌ | ❌ | ❌ | ❌ | ❌ |
| `business` | **NULL** | ✅ | ✅ | ❌ | ❌ | ❌ |
| `profesional` | **NULL** | ✅ | ✅ | ✅ | ✅ | ✅ |

**Cómo se hace cumplir (D-069):** solo se bloquean las acciones que **crean algo nuevo** (`create_product`, `create_purchase`, `create_expense`, `create_stock_consumption`, `create_work_photo`, `public_create_review`). Editar, anular o aprobar lo que ya existe sigue funcionando sin importar el plan. Excepción: `financial_reports` no tiene acciones de creación, así que ahí se bloquea la lectura misma.

Ese criterio —**nunca quitarle a alguien el acceso a datos que ya son suyos**— es una decisión de producto madura y está aplicada de forma consistente.

**Dos observaciones:**
- Los **tres precios están en `NULL`**. Es una decisión comercial pendiente, no un error técnico (D-044).
- `social_publishing` está sembrada como funcionalidad diferenciadora del plan Profesional, pero **no existe ninguna función que la haga cumplir ni ninguna funcionalidad detrás**. Es una bandera vacía (ver H-10).

---

## 7. Verificación de integridad Flutter ↔ Base de datos

Es la prueba más valiosa de esta auditoría, porque detecta el tipo de error que solo aparece cuando un usuario real abre la pantalla.

| Verificación | Resultado |
|---|---|
| RPC invocadas desde Flutter | 111 |
| Funciones expuestas en la base de datos | 122 |
| **Llamadas de Flutter que no existen en la base** | **0** ✅ |
| Funciones expuestas sin consumidor en Flutter | 11 |

**Ninguna pantalla va a fallar por una función inexistente.** Esto confirma que los cambios de firma de D-084 (`create_stylist`, `update_stylist`) y D-086 (`create_product`, `update_product`) se completaron bien en ambos lados.

Las 11 funciones sin consumidor, clasificadas:

| Función | Diagnóstico |
|---|---|
| `get_team_invitation_email_context` | ✅ Correcto — la usa la Edge Function de invitación |
| `get_low_stock_alert_context` | ✅ Correcto — la usa la Edge Function de alarma |
| `get_my_tenant_id`, `get_my_role`, `is_owner_or_admin` | ✅ Ayudantes internos usados por otras funciones |
| `get_my_entitlements` | ⚠️ Construida en D-044, **nunca conectada** a la interfaz |
| `list_public_plans` | ⚠️ Sin pantalla de precios (y sin precios que mostrar) |
| `get_financial_summary_v2` | ⚠️ Sustituida por `get_branch_financial_summary_v2` |
| `get_expenses_summary_v2`, `get_products_summary_v2`, `get_purchases_summary_v2` | ⚠️ Sustituidas por las variantes `*_for_management` |

---

## 8. Hallazgos

### Severidad ALTA

---

**H-01 — El rol "Asistente" no tiene ninguna pantalla, y es el valor por defecto al invitar**

*Evidencia:* `lib/main.dart` define 18 módulos; ninguno incluye `assistant` en `allowedRoles`. En `lib/pages/users_page.dart:269`, el formulario de invitación arranca con `String role = 'assistant';`. En la base de datos, **14 funciones expuestas autorizan explícitamente a `assistant`**: `create_client`, `create_scheduled_ticket_with_service_v2`, `create_recurring_scheduled_tickets_v2`, `register_ticket_payment_v2`, `reschedule_ticket_v2`, `remove_ticket_service_v2`, `update_ticket_service_assignment_v2`, `get_ticket_payments_v2`, `get_ticket_payment_summary_v2`, `get_ticket_service_options_v2`, `get_ticket_services_for_management_v2`, `get_available_appointment_slots_v2`, `create_team_invitation`, `update_tenant_user_access`.

*Impacto:* si el propietario invita a alguien sin cambiar el rol sugerido, esa persona completa todo el registro y llega a un callejón sin salida. La app no se rompe (muestra un mensaje limpio), pero la funcionalidad de recepcionista —**que ya está construida en el servidor**— es inalcanzable.

*Es el mismo patrón de D-066, invertido:* allí la interfaz mostraba algo que el backend rechazaba; aquí el backend permite algo que la interfaz no muestra.

*Recomendación:* decidir una de dos, explícitamente:
- **(a)** Darle al asistente el menú que su backend ya soporta: Agenda, Tickets y Clientes. Es principalmente trabajo de Flutter, sin migración.
- **(b)** Si el asistente no es un rol deseado hoy, quitarlo del formulario de invitación para que nadie lo elija por accidente.

---

**H-02 — La reserva pública no tiene ninguna protección contra abuso**

*Evidencia:* `public_create_booking` valida correctamente casi todo (negocio activo, plan vigente, nombre, celular de ≥7 dígitos, fecha futura, servicio y profesional realmente reservables, y **revalida que el horario siga libre**). Pero **no tiene límite de tasa, ni CAPTCHA, ni verificación del celular, ni tope por día**.

Además se verificó que **la reserva ocupa el horario de inmediato**: crea un `ticket_services` en estado `pendiente`, y tanto `public_get_available_slots` como el trigger `enforce_stylist_schedule_conflict` consideran ocupado todo lo que esté en `pendiente` o `en_proceso`. No hace falta que el negocio confirme nada.

*Impacto:* quien tenga el enlace público puede:
1. **Bloquear la agenda completa** de una sede con citas falsas, dejando al negocio sin horarios vendibles.
2. **Ensuciar la base de clientes**, creando una fila en `clients` por cada celular nuevo inventado.
3. Adjuntar reservas falsas a un cliente real si acierta su número de celular (la función reutiliza el cliente existente cuando el teléfono coincide).

*Atenuantes:* requiere conocer el UUID de la sede, que no es adivinable. Hoy el enlace no está publicado. Las reservas quedan en `solicitado` y son visibles y cancelables por el negocio.

*Recomendación:* **no publicar el enlace a clientes reales sin al menos una de estas defensas.** La más simple y efectiva: un tope de reservas por celular y por día, validado dentro de la propia función (no requiere infraestructura nueva). Un límite por IP requeriría Edge Function; un CAPTCHA, una dependencia nueva.

---

**H-03 — Cobertura de pruebas automatizadas casi inexistente**

*Evidencia:* 3 archivos, 5 pruebas, 111 líneas en total. `test/widget_test.dart` son **7 líneas** (un esqueleto). Las pruebas existentes cubren únicamente el modelo `BranchContext` y contratos de sede. **Cero pruebas** sobre dinero, comisiones, pagos, saldos, inventario o estados de ticket.

*Impacto:* el proyecto tiene ~24.800 líneas de Dart y 173 funciones SQL. La verificación se hace con SQL de rollback por bloque (una práctica excelente, sostenida en D-047 a D-086), pero ese método **prueba lo que se acaba de construir, no protege lo que ya existía.** No hay red de seguridad contra regresiones. En un módulo financiero, ese es el riesgo estructural más grande del proyecto.

*Recomendación:* no perseguir "cobertura" como métrica. Empezar por las **tres reglas de dinero** cuya ruptura sería más costosa y silenciosa:
1. El saldo de un ticket = servicios finalizados − pagos registrados (base de D-083).
2. La resolución de comisión: excepción de sede/estilista/servicio primero, política del negocio como respaldo (D-078).
3. Costo promedio ponderado al comprar y su reversión al anular (D-055).

---

### Severidad MEDIA

---

**H-04 — Claves `service_role` y `secret` expuestas, pendientes de rotar**

Las claves del proyecto `eogppgbdnwxdtcbctaol` quedaron impresas en texto plano en un historial de herramientas el 2026-08-03. Se decidió conscientemente no rotarlas por ser un entorno de pruebas personal. **Esa decisión deja de ser válida en el momento en que entre el primer cliente real.**

*Recomendación:* incluir la rotación de ambas claves (Supabase → Project Settings → API → Regenerate) como paso **obligatorio y bloqueante** en la lista de salida a producción de `RUTA_A_PRODUCCION_2026-07-25.md`.

---

**H-05 — Deuda acumulada de funciones heredadas**

37 funciones cerradas (sin acceso externo) más 11 vivas con el estándar antiguo `search_path=public`, más 5 expuestas sin ningún consumidor. En total, cerca de **50 funciones** que no aportan y que confunden a quien lea el esquema.

*Atenuante:* las cerradas no son un riesgo de seguridad — ya se les revocó el acceso en D-024/D-040. Es deuda de mantenimiento, no exposición.

*Recomendación:* no es urgente. Cuando se toque, hacerlo en un bloque dedicado y en dos pasos: primero eliminar las 37 sin acceso externo (riesgo nulo), después migrar las 11 vivas al estándar `search_path=pg_catalog`.

---

**H-06 — El documento rector está desactualizado**

`docs/00_producto/BEAUTYOS_EXPEDIENTE_TECNICO_Y_PLAN_MAESTRO.md` sigue en **v1.5, fechado 20 de julio**, y su encabezado declara *"Tramo D completo en NO-GO por no conformidades pendientes"*. Eso dejó de ser cierto el **22 de julio** (D-042/D-043 cerraron el Tramo D en producción). Han pasado 44 decisiones desde entonces.

*Impacto:* es el documento que `PROMPT_MAESTRO_IA.md` señala como fuente de verdad. Un chat nuevo que lo lea de arriba puede concluir que el proyecto está bloqueado cuando no lo está.

*Hallazgo relacionado:* el índice `docs/README.md` también se quedó atrás — su última entrada es el número 79 (D-076, del 27 de julio). **No lista ninguno de los 10 bloques posteriores** (D-077 a D-086: logo, comisiones por sede, 2FA, recurrencia, colores, saldo acumulado, portada y perfil del profesional, marca y alarma de stock).

*Recomendación:* actualizar el bloque de encabezado del expediente rector (Versión / Estado / Fecha) para que apunte al estado real y a `REGISTRO_DE_DECISIONES.md` como fuente viva —no hace falta reescribir las 582 líneas— y completar el índice de `docs/README.md` con los bloques faltantes.

---

**H-07 — `pubspec.lock` no está versionado**

El `.gitignore` contiene `*.lock`, así que `pubspec.lock` **no está en Git**. Para una aplicación (no una librería), Flutter recomienda lo contrario.

*Impacto:* dos máquinas —o una futura CI— pueden compilar con versiones distintas de las dependencias sin que nadie lo note, y un fallo que aparece en una y no en otra es muy difícil de diagnosticar.

*Recomendación:* excluir `pubspec.lock` de esa regla y versionarlo. Es un cambio de una línea y elimina toda una categoría de "en mi máquina sí funciona".

---

**H-08 — El manejo del dinero no coincide con la regla documentada**

`PROMPT_MAESTRO_IA.md` §3 dice: *"Dinero en enteros COP (nunca floats)"*. La realidad verificada:

- **Ninguna columna es float** ✅ — el riesgo grave está evitado, todo es `numeric` (decimal exacto).
- Pero **ninguna es entera** tampoco: unas son `numeric(12,2)` (`ticket_payments.amount`, `expenses.amount`, `stylist_commissions.commission_amount`, `branch_services.price`…) y otras son **`numeric` sin restricción alguna** (`services.price`, `ticket_services.price`, `purchases.total_amount`, `purchase_items.unit_cost`, `inventory_movements.unit_cost`, `commission_policies.*`).
- La interfaz formatea con `toStringAsFixed(0)`, es decir **muestra sin decimales**.
- `plans.price_cents` es `bigint` en centavos — el único entero, con un criterio distinto al resto.

*Impacto:* bajo pero real. Un precio guardado como `15000.4` se **mostraría** como `15000` y se **sumaría** como `15000.4`. Con suficientes operaciones, los reportes dejan de cuadrar contra lo que el dueño ve en pantalla, sin ningún error visible.

*Recomendación:* elegir un criterio y escribirlo. Lo más simple y menos invasivo: dejar los tipos como están y **redondear a peso entero al escribir** en las funciones que registran dinero (varias ya lo hacen, como el costo promedio de D-055). Alternativamente, corregir la regla del documento para que refleje `numeric`, que es lo realmente implementado.

---

**H-09 — Storage: archivos huérfanos permanentes y URLs públicas para siempre**

Los 4 buckets tienen **solo política de inserción**. No existe forma de borrar ni reemplazar un archivo desde la aplicación.

*Impacto:*
1. Cada cambio de logo, portada o foto de estilista **deja el archivo anterior almacenado indefinidamente**, sin manera de limpiarlo desde la app. Consume cuota y crece sin techo.
2. Los buckets son públicos: una foto de trabajo ocultada con el interruptor de D-061 **sigue siendo accesible** por su URL directa. Los interruptores controlan la app, no el archivo.

*Recomendación:* no bloquea nada hoy. Antes de producción conviene (a) advertir en la interfaz que ocultar una foto no la borra de internet, y (b) decidir si se agrega una política de borrado para el dueño.

---

**H-10 — `social_publishing`: funcionalidad de plan sin nada detrás**

Sembrada como diferenciador del plan Profesional en `20260722184914`, pero no existe ninguna función que la verifique ni ninguna funcionalidad asociada. Si mañana se publica una tabla de precios generada desde `plan_features`, aparecería como beneficio del plan más caro algo que no existe.

*Recomendación:* o marcarla claramente como "futura", o retirarla de `plan_features` hasta que se construya.

---

### Severidad BAJA

---

**H-11 — Inconsistencia de permisos entre ayudantes de Storage**

`private.beautyos_can_upload_work_photo` es ejecutable por `anon`; sus dos hermanas (`beautyos_can_upload_tenant_logo`, `beautyos_can_manage_stylist_photo`) no lo son. **No es explotable**: la función resuelve `auth.uid()`, que para un anónimo es nulo, y devuelve `false`. Es un descuido de higiene de D-060 que conviene alinear.

---

**H-12 — Correo en modo sandbox**

Resend sigue sin dominio verificado, así que **tanto las invitaciones de equipo (D-065) como la nueva alarma de stock (D-086) solo llegan a la cuenta propia del propietario**. Cualquier prueba con un correo de tercero fallará silenciosamente. Verificar un dominio está correctamente ubicado en la Fase Final.

---

**H-13 — Cuatro commits sin publicar**

`main` está **4 commits adelante de `origin/main`** (D-083, D-084, D-085, D-086). El trabajo está commiteado localmente pero no respaldado en el remoto.

---

## 9. Lo que está notablemente bien hecho

Para que el balance sea justo, esto no es opinión: son patrones verificados que muchos proyectos de este tamaño no logran.

1. **Cero funciones sin `search_path` fijo** entre 173. Elimina por completo la vulnerabilidad más común de PostgreSQL en funciones privilegiadas.
2. **Cero llamadas rotas** entre Flutter y la base de datos, incluso después de cuatro cambios de firma recientes.
3. **Cero deriva de migraciones**: las 56 migraciones locales coinciden exactamente con el remoto.
4. **Cero `TODO`/`FIXME`** en 24.800 líneas — no hay trabajo abandonado a medias marcado en el código.
5. **Trazabilidad ejemplar:** 86 decisiones numeradas, cada una con motivo, evidencia de prueba y consecuencia. Es superior a la documentación de la mayoría de productos comerciales pequeños.
6. **Disciplina de prueba antes de desplegar:** cada bloque desde D-047 se probó con `begin/rollback` contra datos reales antes de aplicar. Ese hábito ha atrapado bugs reales (D-053, D-055, D-080).
7. **No se borra historial financiero.** Sin borrado físico en ninguna parte; todo es desactivación o anulación con motivo y trazabilidad.
8. **Aislamiento multi-sede real**, incluyendo el choque de agenda entre sedes (D-073) con candado de concurrencia por estilista — un detalle que se suele descubrir tarde y caro.

---

## 10. Recomendaciones priorizadas

| # | Acción | Por qué ahora | Esfuerzo |
|---|---|---|---|
| 1 | Resolver el rol Asistente (darle menú o quitarlo del formulario) | Es el default al invitar; hoy produce un usuario roto | Bajo (solo Flutter si es opción b) |
| 2 | Poner un tope de reservas por celular/día en `public_create_booking` | **Bloqueante** antes de publicar el enlace a clientes reales | Bajo (una migración) |
| 3 | Actualizar el encabezado del expediente rector | Un chat nuevo puede leerlo y concluir que el proyecto está bloqueado | Mínimo |
| 4 | Versionar `pubspec.lock` | Evita fallos irreproducibles cuando haya CI o segunda máquina | Mínimo |
| 5 | Primeras pruebas automáticas de las 3 reglas de dinero | Única red contra regresiones financieras silenciosas | Medio |
| 6 | Añadir rotación de claves a la lista de salida a producción | Deuda de seguridad con fecha de vencimiento conocida | Mínimo |
| 7 | Definir el criterio de redondeo del dinero | Evita descuadres invisibles entre pantalla y reportes | Bajo |
| 8 | Limpiar funciones heredadas (37 cerradas primero) | Higiene; sin urgencia | Medio |

---

## 11. Conclusión

BeautyOS es un producto **técnicamente sano y con una arquitectura de seguridad bien pensada y aplicada con consistencia**. La base multi-tenant y multi-sede está cerrada correctamente, el historial financiero es trazable e inmutable, y la disciplina de decisiones documentadas es su mayor activo intangible: cualquier persona nueva —o cualquier chat nuevo— puede reconstruir el porqué de cada pieza.

Los tres asuntos que merecen atención antes de tener clientes reales pagando son, en orden: **cerrar el hueco del rol Asistente**, **proteger la reserva pública contra abuso**, y **empezar a cubrir con pruebas automáticas las reglas de dinero**. Ninguno de los tres es un error activo; los tres son huecos que solo se vuelven costosos cuando hay un negocio real dependiendo del sistema.

El resto de hallazgos son deuda ordenada, del tipo que se paga cuando conviene y no cuando urge.

---

*Auditoría realizada contra el commit `6a3d912` y el proyecto Supabase `eogppgbdnwxdtcbctaol`. Toda cifra de este documento fue obtenida por consulta directa al código o a la base de datos real, no de documentación previa.*
