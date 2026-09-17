# HANDOFF Salón y Más — 17 de septiembre de 2026 ("Nadie podía registrarse, y lo descubrió un desconocido", D-245 y D-246)

**Bloque documentado:** decisiones **D-245** y **D-246** · Fase **9**, pasos **9.46** y **9.47** · hallazgos **AG** a **AJ**.

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

## 4. Cuatro hallazgos nuevos, y dos son de dinero

| | Qué | Estado |
|---|---|---|
| **AG** 🔴 | **El precio del negocio no llega a la sede, y la sede es la que cobra.** `beautyos_precio_efectivo_sede` hace `coalesce(bs.price_cop, p.price_cop)`: ni el precio pactado del negocio ni su descuento entran | Abierto |
| **AH** 🔴 | El enlace de confirmación por correo caduca antes de que la gente lo pulse | Abierto — **ajuste de Supabase, del propietario** |
| **AI** 🟡 | **El repositorio no contiene el esquema completo.** Las tablas grandes no están en ninguna migración | Abierto |
| **AJ** 🔴 | **El salón nace con comisión del 40% que nadie le pide confirmar**, y ese valor vive en un default de tabla que el repositorio no tiene | Abierto |

**AG con evidencia del propietario:** aprobó un negocio con 97% de descuento y su Configuración enseña **«Plan Todo Incluido — $4.500/mes»** y diez centímetros más abajo **«Peluquería Éxito Prueba · $150.000 al mes»** con un botón *Activar esta sede*. **Dos precios para lo mismo, dos botones que cobran distinto.**

**AJ es el más silencioso:** un horario mal puesto se nota el primer día; **una comisión mal puesta se nota al pagar nóminas.**

---

## 5. ⏳ DÓNDE QUEDÓ EL RECORRIDO DE PRUEBA

**El guion está en `docs/04_pruebas/RECORRIDO_COMPLETO_DE_UN_CLIENTE.md`.** Tiene el reparto y 18 pasos con casillas.

**Hecho: pasos 1, 2 y 3.** Existe ahora mismo en producción:

| | |
|---|---|
| Negocio | **Peluquería Éxito Prueba** — `TRIALING`, 7 días, vence 24-sep |
| Propietaria | Alicia Propietaria · `elboga008@gmail.com` |
| Precio del negocio | **$4.500/mes** (150.000 con 97% de descuento) |
| Precio de su sede | **$150.000/mes** ← el de AG |
| Marcado como demo | **NO** — hay que marcarlo antes de poder borrarlo |

**Siguiente: paso 4** — Alicia carga los datos de su sede desde **su propia** Configuración.

> **El 17-sep se corrigió el orden de los pasos 4 y 5.** Antes decían que el dueño de plataforma cargaba los datos del cliente desde su Panel. Lo señaló el propietario: *"no soy yo el que debo ingresar los datos de las sedes de los clientes"*. **Tenía razón.** La puerta del Panel (D-241) es la de **servicio**; la principal es la del salón (D-242).

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
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-245 y D-246).

Antes de tocar documentación: python scripts/verificar_documentos.py

Estamos a mitad del recorrido de prueba de
docs/04_pruebas/RECORRIDO_COMPLETO_DE_UN_CLIENTE.md: hechos los pasos 1 a 3,
toca el 4. El propietario va paso a paso y confirma cada uno antes del
siguiente; es no técnico, así que hay que decirle qué hace, cómo y dónde.

NO pagar nada: la sede de prueba dice $150.000 y el modo real está activo.

Al acabar el recorrido, atacar AG (el precio del negocio no llega a la sede)
y AJ (la comisión del 40% que nadie confirma). Los dos son de dinero.

Todo lo demás aplicado y publicado. Controles 214 y 215 en verde,
404 pruebas, analyze 0/0.
```
