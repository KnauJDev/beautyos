# HANDOFF Salón y Más — 2 de septiembre de 2026 ("Pulido Multi-Sede y Alertas de Suscripción", D-196)

**Bloque documentado:** decisión **D-196** · Paso **8.18** de la **FASE 8**.

**Estado:** ✅ **CERRADO y verificado en producción.** El propietario aplicó
la migración con `aplicar_sql.ps1`, corrió el Control 206 (**10 de 10 casos
en verde, `ROLLBACK` limpio**) y desplegó `send-subscription-expiry-alerts`.
`flutter analyze` 0/0 y **297 de 297 pruebas en verde** (sin cambios en
Flutter: este bloque es enteramente de base de datos y Edge Function). El
apartado 3 queda como referencia de los comandos ya ejecutados, por si hace
falta repetirlos en otro entorno (por ejemplo `salonymas-ensayo`, D-134).

> El bloque anterior (D-195, "Velocidad Operativa de Mostrador") está en
> `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-02_D195.md`.

---

## 1. Lo que cambió: los dos pendientes que ya estaban escritos

El propietario pidió cerrar dos huecos que D-189 y el HANDOFF de D-195 ya
habían dejado anotados como pendientes — no hubo que descubrir nada nuevo,
solo construirlo.

### 1. El tope de equipo se multiplica por las sedes activas

`create_team_invitation` comparaba el equipo del negocio contra un tope
plano de 9 cuentas (D-189). Ahora el tope efectivo es
`9 * sedes_activas`, en un ayudante nuevo,
`private.beautyos_require_team_limit`, que NO vive dentro de
`beautyos_require_limit` (esa la comparte `create_branch` para el tope de
SEDES, y multiplicarlo por sedes activas sería circular).

**La cuenta de "sedes activas" no es simétrica, y hay una razón concreta:**

- La sede **principal** cuenta siempre que el negocio esté `entitled` —
  exactamente el mismo criterio que regía *antes* de este cambio. **Cero
  regresión** para el salón de una sola sede: sigue teniendo sus 9 cuentas +
  el dueño, igual que ayer.
- Las sedes **secundarias** cuentan por su propio
  `branch_subscriptions.status in ('active', 'trialing')`.

**Por qué no se trató a la principal igual que a las secundarias:** se
comprobó antes de escribir código que `branch_subscriptions` **solo la
mantiene al día el flujo NUEVO de pago por sede (D-192)**. La inmensa
mayoría de los negocios sigue pagando su sede principal por el flujo VIEJO
(`beautyos_procesar_evento_epayco`, D-159/D-182), que nunca toca esa tabla —
`grep -rn "branch_subscriptions" supabase/migrations/*.sql` solo devuelve
las migraciones de la Etapa 2/3 de D-188. Contar la principal por ese estado
la habría dejado `pending` para siempre en casi todos los negocios, y el
tope se habría ido a **cero** — justo lo contrario de lo que pedía el
encargo.

### 2. Las alertas de vencimiento ya avisan de sedes secundarias

Nueva función hermana de la del negocio (D-143):
`private.beautyos_obtener_alertas_sede_pendientes()`, mismo cálculo por
días de calendario, sobre `branch_subscriptions` en vez de
`tenant_subscriptions`, y **sin la sede principal** (su vencimiento ya lo
cubre la alerta del negocio).

El candado anti-spam (`subscription_notification_logs`) ganó una columna
`branch_id` en vez de una tabla nueva. **El detalle que no era obvio:** el
`UNIQUE` de siempre no podía crecer agregándole `branch_id` sin más — un
`NULL` cuenta como distinto de otro `NULL` en un `UNIQUE` estándar, así que
eso habría dejado mandar el aviso del NEGOCIO varias veces el mismo día. Se
reemplazó por **dos índices parciales** (`branch_id IS NULL` /
`branch_id IS NOT NULL`) en vez de depender de `NULLS NOT DISTINCT`
(Postgres 15+, no se puede dar por hecha la versión del proyecto). El
Control 206 (caso 7) comprueba explícitamente que el candado del negocio
sigue dejando **una sola fila**, no dos.

La Edge Function `send-subscription-expiry-alerts` ahora pide las dos
listas (negocio y sedes secundarias), las **agrupa por `tenant_id`** y manda
**un solo correo por negocio** — literalmente lo que pedía el encargo ("un
solo correo claro al dueño indicando cuáles de sus sedes..."). Si el negocio
y dos sedes tienen alerta el mismo día, es un correo, no tres. Cada alerta
individual se registra por separado en el log, para que el filtro de "no
repetir hoy" siga funcionando por componente aunque el correo salga
combinado.

### Lo que NO se hizo, a propósito

**Ninguna sede secundaria se suspende sola todavía** al agotar su período de
gracia — solo el negocio completo, vía
`beautyos_suspender_suscripciones_vencidas`, que no se tocó. El encargo
pedía **alertas**, no suspensión automática; construirla es un cambio de
comportamiento más grande que nadie pidió. Si algún día se necesita, es su
propio bloque, con su propia decisión.

---

## 2. Verificación — Control 206, corrido por el propietario: 10 de 10 en verde

**Control 206** (`supabase/sql/206_test_tope_equipo_y_alertas_por_sede.sql`),
terminado en `ROLLBACK` limpio:

1. Las cuatro funciones nuevas/redefinidas existen y son `SECURITY DEFINER`
   (con un caso extra, 1b: la firma vieja de 5 argumentos de
   `beautyos_registrar_alerta_enviada` ya no existe — ver la nota de la
   trampa de D-174 en el apartado 4).
2. Con solo la sede principal, el tope se comporta **igual que antes** (9).
3. Una sede secundaria **pendiente** de pago no amplía el cupo.
4. Una sede secundaria **activa** sí lo amplía (9 → 18).
5. Un tenant sin suscripción operativa se rechaza (`entitled = false`).
6. `limit_value = null` (override sin límite) sigue significando sin límite.
7. **El candado anti-spam del negocio no se rompe con `branch_id` NULL**
   (el caso más delicado de todo el bloque).
8. El candado anti-spam por sede funciona aparte del de negocio.
9. `beautyos_obtener_alertas_sede_pendientes` encuentra una sede por vencer
   y deja de encontrarla tras registrar el envío; la sede principal nunca
   aparece ahí.
10. `anon`/`authenticated` no alcanzan ninguna función nueva.

Aplicado y verificado en producción el 02-sep. La Edge Function
`send-subscription-expiry-alerts` quedó desplegada en el mismo bloque.

---

## 3. Los tres pasos, ya ejecutados — queda como referencia

Los tres se corrieron el 02-sep y quedaron verificados. Se dejan los
comandos exactos por si hace falta repetirlos en otro entorno (por ejemplo
`salonymas-ensayo`, D-134).

### 3.1 Aplicar la migración

```powershell
powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
  -Archivo "supabase\migrations\20260902200000_tope_equipo_y_alertas_por_sede_d196.sql"
```

Va dentro de `begin`/`commit`: si algo falla a mitad, la base queda como
estaba.

### 3.2 Correr el Control 206 contra la base real

```powershell
powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" `
  -Archivo "supabase\sql\206_test_tope_equipo_y_alertas_por_sede.sql"
```

Termina en `ROLLBACK`: no deja datos de prueba. Los 10 casos salieron en
verde, y por eso este bloque está `✅ CERRADO` en el Plan Maestro y el
Registro.

### 3.3 Desplegar la Edge Function

```
supabase functions deploy send-subscription-expiry-alerts
```

(o el camino equivalente de despliegue que use el proyecto — ver
`docs/02_operacion/MAPA_TECNICO.md`, "los tres caminos de publicación").
**No hace falta ninguna variable de entorno nueva**: sigue usando
`CRON_SECRET`, `RESEND_API_KEY`, `SUPABASE_URL` y
`SUPABASE_SERVICE_ROLE_KEY`, que ya existen.

### 3.4 Probar un envío real

El cron diario (D-145) la llama sola, pero para verlo antes de esperar al
cron: invocar la función a mano con el `x-cron-secret` correcto y revisar en
la respuesta JSON `alertas_negocio`, `alertas_sede` y
`negocios_notificados`. Si en ese momento algún negocio de prueba tiene una
sede secundaria por vencer, debería llegar un solo correo mencionando ambas
cosas.

---

## 4. Qué NO hacer

- **No tratar la sede principal igual que las secundarias en el conteo de
  equipo.** `branch_subscriptions.status` no está al día para la principal
  en la mayoría de los negocios (ver apartado 1.1). Si algún día el flujo
  viejo de pago (`beautyos_procesar_evento_epayco`) empieza a sincronizar
  `branch_subscriptions` también, ahí sí se puede unificar el criterio —
  hoy no.
- **No juntar los dos índices parciales del log de alertas en un `UNIQUE`
  con `NULLS NOT DISTINCT`** sin antes confirmar la versión de Postgres del
  proyecto real. Los dos índices parciales funcionan en cualquier versión.
- **No construir suspensión automática por sede** sin que el propietario lo
  pida explícitamente: es un cambio de comportamiento, no una alerta.
- **No aplicar la migración 20260902200000 sin correr el Control 206
  después.** El caso 7 (el candado del negocio con `NULL`) es exactamente
  el tipo de error que pasa las pruebas de humo y falla en producción tres
  semanas después.
- Todo lo que ya decía el HANDOFF de D-195 sigue vigente: no tocar los
  candados de plan de D-184/D-187, no forzar `get_my_entitlements`, no
  poner `verify_jwt = true` en `epayco-webhook`.

---

## 5. Lo que sigue abierto (heredado, nadie lo tocó en este bloque)

1. **La pantalla pública de planes, la tarjeta de sedes y el desglose de
   reportes por sede siguen sin verse con los ojos** (HANDOFF de D-195,
   apartado 3.3). Compilan y pasan pruebas; nadie las ha visto en un
   navegador.
2. **El candado 2 de D-181** (comparar `x_cust_id_cliente` contra una
   transacción real de ePayco) sigue sin ejercitarse.
3. Del Plan Maestro: Fase 3 con dos casillas de 👤 abiertas (3.2 contador
   sobre DIAN/IVA, 3.4 subir Supabase a Pro).

---

## 6. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-196: Bloque 2 "Pulido
Multi-Sede y Alertas de Suscripción" -- tope de equipo multiplicado por
sedes activas, y alertas de vencimiento agrupadas por negocio incluyendo
sedes secundarias).

El código y el Control 206 están escritos y revisados, con flutter analyze
0/0 y 297/297 pruebas en verde (sin cambios en Flutter). PERO la migracion
20260902200000 NO esta aplicada en Supabase y la Edge Function
send-subscription-expiry-alerts NO esta desplegada -- los comandos exactos
estan en el apartado 3 de este HANDOFF. Si el propietario ya los corrio,
lo primero es preguntar si el Control 206 salio en verde y actualizar el
Plan Maestro y el Registro de CERRADO-pendiente a CERRADO-verificado (mismo
patron que D-190 a D-194).

Lo que sigue abierto, heredado de bloques anteriores, por orden de daño:
1. Pantalla publica de planes, tarjeta de sedes y desglose de reportes por
   sede sin verificar visualmente (apartado 5.1).
2. El candado 2 de D-181 sin ejercitar contra un pago real (apartado 5.2).

Ojo con lo que NO hay que tocar: el tope de equipo cuenta la sede principal
por "esta entitled", NO por branch_subscriptions.status -- esa tabla no la
mantiene al dia el flujo viejo de pago para la principal, y cambiar el
criterio dejaria el tope en cero para casi todos los negocios existentes.
```
