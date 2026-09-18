# HANDOFF Salón y Más — 17 de septiembre de 2026 ("Nadie podía registrarse, y lo descubrió un desconocido", D-245 y D-246)

**Bloque documentado:** decisiones **D-245** y **D-246** · Fase **9**, pasos **9.46** y **9.47** · hallazgos **AG** a **AL**, e idea **I-17**.

**Estado:** ✅ Todo aplicado y verificado. Controles **214** y **215** en verde.
⏳ **Hay un recorrido de prueba a medias**: ver apartado 5.

> El bloque anterior está en `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-16_D244.md`.

---

## 1. Lo que hay que leer si solo se lee una cosa

**El registro llevaba dieciséis días roto** (D-245). `register_tenant` pedía el plan `'profesional'`, y D-188 jubiló ese código el 1-sep.

**No lo encontró ninguna de las 404 pruebas ni ninguno de los 15 controles.** Lo encontró una persona a la que el propietario invitó a probar, y llegó por captura de pantalla.

> **Un camino que nadie recorre no avisa de que está roto: avisa el primero que lo recorre, y suele ser un cliente.**

Es la tercera vez con esa forma: el cobro caído 26 días por las llaves heredadas (D-215), el `calc is not defined` en producción (hallazgo AB), y esto.

**El arreglo no fue escribir `'pro'`** — eso habría dejado la misma trampa armada para el siguiente cambio de catálogo. El plan se pide **sin nombrarlo**: el único activo, y si hay cero o varios la función se para y dice cuál es el caso.

---

## 2. Una lección de método que costó dos corridas en rojo

La comprobación contra la regresión del control 214 se escribió **leyendo la fuente** con `pg_get_functiondef`. Dio FALLO **dos veces seguidas estando la función bien**, porque el cuerpo **explica el fallo citándolo** en un comentario. Quitar los comentarios antes de buscar tampoco bastó.

Se cambió por una de **comportamiento**: jubilar el plan activo, crear otro con un código jamás escrito, y comprobar que el registro sigue funcionando — todo dentro del `rollback`.

**Es el 16-sep al revés:** allí un comentario hizo que un guardián de Dart diera VERDE con la llamada comentada; aquí hizo que diera ROJO estando bien.

> **Una prueba que lee código comprueba la intención; una que lo ejecuta comprueba el hecho. Cuando se puede ejecutar, se ejecuta.**

---

## 3. D-246: borrar los negocios de prueba, y solo esos

`platform_delete_demo_tenant` **se niega si `is_demo` no es true**. Ese seguro vive en el servidor y no en la pantalla: un `if` en Dart lo salta cualquiera que llame a la RPC. La pantalla añade una segunda puerta — hay que **escribir el nombre del negocio**.

**Descubre las tablas en `information_schema`**, no en una lista: al escribirlo se vio que las migraciones solo conocen 25 tablas y **faltan `tenants`, `clients`, `tickets` y `work_photos`** (hallazgo AI). Una lista a mano habría dejado el negocio "borrado" con sus 703 tickets dentro.

Borra a pasadas, **verifica al final que no quede una sola fila** —si sobra algo deshace todo— y deja rastro en `deleted_demo_tenants` con el dinero, que es lo que pide `AGENTS.md`.

**No borra** cuentas de `auth.users` ni archivos de Storage, a propósito.

---

## 4. Seis hallazgos nuevos, y tres son de dinero

| | Qué | Estado |
|---|---|---|
| **AG** 🔴 | **El precio del negocio no llega a la sede, y la sede es la que cobra.** `beautyos_precio_efectivo_sede` hace `coalesce(bs.price_cop, p.price_cop)`: ni el precio pactado del negocio ni su descuento entran | Abierto |
| **AH** 🔴 | El enlace de confirmación por correo caduca antes de que la gente lo pulse | Abierto — **ajuste de Supabase, del propietario** |
| **AI** 🟡 | **El repositorio no contiene el esquema completo.** Las tablas grandes no están en ninguna migración | Abierto |
| **AJ** 🔴 | **El salón nace con comisión del 40% que nadie le pide confirmar**, y ese valor vive en un default de tabla que el repositorio no tiene | Abierto |
| **AK** 🔴 | **Los diálogos validan DESPUÉS de cerrarse: un dato rechazado borra todo lo escrito.** El patrón es el mismo en los cuatro que escriben datos (D-236, D-237, D-241, D-242) | Abierto |
| **AL** 🟡 | **Al empleado invitado le llega el correo del dueño**, prometiéndole *"tu prueba gratuita de 21 días"*. Ni tiene prueba ni son 21 | Abierto |

**AG con evidencia del propietario:** aprobó un negocio con 97% de descuento y su Configuración enseña **«Plan Todo Incluido — $4.500/mes»** y diez centímetros más abajo **«Peluquería Éxito Prueba · $150.000 al mes»** con un botón *Activar esta sede*. **Dos precios para lo mismo, dos botones que cobran distinto.**

**AK lo dijo el propietario con la voz de un cliente:** *"me salió error abajo casi imperceptible y al parecer me sacó sin guardar... para mí me daría jartera y no volvería a usarlo"*. Tuvo que reescribir siete campos por una arroba. **No rompe nada y aun así pierde clientes.**

**AJ es el más silencioso:** un horario mal puesto se nota el primer día; **una comisión mal puesta se nota al pagar nóminas.**

---

## 5. ⏳ DÓNDE QUEDÓ EL RECORRIDO DE PRUEBA

**El guion está en `docs/04_pruebas/RECORRIDO_COMPLETO_DE_UN_CLIENTE.md`**, con el reparto real, 18 pasos y una tabla de resultados.

### Hechos y en verde: pasos 1 a 8

| # | Qué se probó | Resultado |
|---|---|---|
| 1-3 | Registro, primera sede automática, aprobación | ✅ **D-245 verificado por el camino de una persona**, no solo por el control |
| 4 | Alicia carga los datos de su sede desde **su** Configuración | ✅ a la segunda — la primera la tumbó **AK** |
| 5 | Lo mismo visto desde el Panel | ✅ **dos puertas, un solo dato** |
| 6-7 | Invitación a la administradora | ✅ **correo enviado 18:36, en bandeja 18:37**, en *Primary* |
| 8 | Invitación a la asistente | ✅ su menú son **3 entradas**, no 15 |
| 16 | Marcar como ensayo → aparece el botón rojo de borrar | ✅ **adelantado** |

**Dos comprobaciones de permisos, las dos bien:**

- Desde el lado de la administradora, la dueña sale **«Protegido»**, no «Gestionar». **No hay agujero.**
- La asistente ve **Agenda, Tickets & Caja y Clientes**. Nada más. El rol está bien delimitado.

### Lo que existe ahora mismo en producción

| | |
|---|---|
| Negocio | **Peluquería Éxito Prueba** — `TRIALING`, 7 días, vence **24-sep** |
| Marcado como demo | **SÍ** — el botón de borrar está disponible |
| Precio del negocio | **$4.500/mes** (150.000 con 97 % de descuento) |
| Precio de su sede | **$150.000/mes** ← esto es **AG** |
| Equipo | 3 cuentas: dueña, administradora, asistente |
| Partner vinculado | Julio Cesar Rodriguez Giraldo · código `MANITO` · 50 % recurrente |

> El partner **no estaba en el guion**: lo añadió el propietario por su cuenta y funcionó, incluida la línea `partner_assigned` en el historial. Y corrigió algo que se había afirmado mal: el código de referido **sí** se puede asignar a mano desde la ficha; lo que no existe es que el salón lo escriba al registrarse.

### Siguiente: **paso 9**

**Crear a Erick Santiago Estilista en el catálogo (menú Estilistas) ANTES de invitarlo.** Es el único punto del recorrido donde el orden no es opcional: la regla *"un estilista, una cuenta"* exige enlazar la invitación a un estilista que ya exista.

**Y al crearlo, mirar qué pide el formulario.** Si le asigna una comisión por omisión sin pedir confirmación, es **AJ otra vez pero por persona**.

Después: paso 10 (invitarlo, con `elboga025`), y de ahí hasta el 18.

---

## 6. Lo que NO hay que hacer

- 🔴 **NO pagar la suscripción de ese negocio de prueba.** Su sede dice **$150.000** y `EPAYCO_TEST_MODE` es `false`: sería dinero real. Primero hay que resolver **AG**.
- **No invitar a los diez socios** hasta mirar **AH**. Si el enlace caduca corto, se caen en la puerta y solo se ve que no entraron.
- **No escribir un código de plan** dentro de `register_tenant`. Es lo que lo tuvo roto 16 días.
- **No escribir una prueba que lea código** cuando se puede ejecutar el comportamiento.
- **No dar por probado el camino del dinero sin un pago real.** Sigue pendiente el de una segunda sede (9.7 y 9.8).

---

## 7. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-245 y D-246), y con él
docs/04_pruebas/RECORRIDO_COMPLETO_DE_UN_CLIENTE.md.

Antes de tocar documentación: python scripts/verificar_documentos.py

DÓNDE ESTAMOS
Recorriendo con el propietario, paso a paso y con personas reales, el alta
completa de un salón. Hechos los pasos 1 a 8 (y el 16, adelantado). Toca el
paso 9: crear a Erick Santiago Estilista en el catálogo ANTES de invitarlo.

CÓMO SE TRABAJA CON ÉL
Va paso a paso y confirma cada uno antes del siguiente. No es técnico: hay
que decirle QUÉ hace, CÓMO y POR DÓNDE, con los nombres exactos de los
botones. Los comandos se le dan en bloques ```bash de una sola línea, y los
ejecuta él. Encuentra fallos reales mirando pantallas: cuando dice "esto no
es", casi siempre tiene razón — verificarlo antes de defender el código.

NO PAGAR NADA. La sede de prueba dice $150.000 y EPAYCO_TEST_MODE es false.

AL ACABAR EL RECORRIDO, por orden de valor:
  AG - el precio del negocio no llega a la sede (dinero)
  AJ - la comisión del 40% que nadie confirma (dinero)
  AK - los diálogos pierden lo escrito al rechazar un dato
  AH - el enlace del correo caduca (lo ajusta él en Supabase)

Todo aplicado y publicado. Controles 214 y 215 en verde, 404 pruebas,
flutter analyze 0/0, 246 decisiones, guardián de documentación en verde.
```
