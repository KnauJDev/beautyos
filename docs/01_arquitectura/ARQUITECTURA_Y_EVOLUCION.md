# Arquitectura y evolución — cómo está hecho Salón y Más y cómo llegó aquí

**Creado:** 23 de septiembre de 2026 (revisión integral, D-254) · **Se actualiza cuando cambia un hecho de arquitectura, no cada sesión**

**Para qué sirve.** Para entender el sistema **entero** sin reconstruirlo desde
253 decisiones. Reúne en un sitio lo que hoy está disperso: las fronteras del
modelo, los invariantes técnicos, **cómo funciona el dinero hoy**, y cómo se
llegó hasta aquí.

**Lo que NO hace.** No opina sobre qué falta ni en qué orden: eso lo manda el
`PLAN_MAESTRO` (D-126). No sustituye al `REGISTRO_DE_DECISIONES`, que guarda el
porqué completo: aquí se cita, no se copia. Y no repite el `MAPA_TECNICO`, que
dice **dónde** está cada cosa y **cómo** se opera; este dice **qué es** y
**por qué es así**.

> **Por qué nació.** Al revisar el proyecto el 23-sep apareció que las reglas
> técnicas con las que nació —y el papel del asistente— **se archivaron el
> 09-ago** junto al `PROMPT_MAESTRO_IA` (D-126) y **nunca se mudaron a un
> documento vivo**. El Plan Maestro se quedó con *cómo trabajamos*; se perdieron
> *cómo está construido* y *quién lo construye*. Y el tema más reescrito del
> proyecto —el precio— necesitaba veinte filas del registro para saber cómo
> funciona hoy.

---

## 1. El principio rector

> **Primero se diseña el negocio, luego las reglas, después la experiencia y
> finalmente el código.**
> — `BEAUTYOS_EXPEDIENTE_TECNICO_Y_PLAN_MAESTRO`, versión 1.6 (archivado)

Casi todos los fallos caros de septiembre fueron este principio al revés: un
número de negocio escrito dentro del código (D-245, **AY**, el 50% de D-252).

---

## 2. El sistema en una página

```
                         ┌──────────────────────────────────────────────┐
  Navegador / celular    │  Flutter Web (PWA)  —  Cloudflare Pages       │
  (dueña, equipo,        │  salonymas.com  ·  publica sola con git push  │
   clienta, plataforma)  └───────────────┬──────────────────────────────┘
                                         │  supabase_flutter (clave publicable)
                         ┌───────────────▼──────────────────────────────┐
                         │  Supabase  (proyecto `beautyos-dev` = PRODUCCIÓN)
                         │  • PostgreSQL 17.6: RPC `security definer`     │
                         │    con search_path fijo + RLS en toda tabla    │
                         │  • Auth: correo+contraseña, código por correo  │
                         │    (D-248; su largo lo decide Supabase), 2FA   │
                         │  • Storage: fotos privadas / públicas (D-119)  │
                         │  • Edge Functions (Deno): cobro, webhook,      │
                         │    correos, alertas                            │
                         │  • pg_cron + pg_net + Vault: alertas diarias   │
                         └──┬───────────────┬───────────────┬───────────┘
                            │               │               │
                     ePayco Smart      Resend (SMTP de   Sentry (errores,
                     Checkout V2       Auth + correos)   saneados, D-209)
```

**Cuatro caminos de publicación que no se tocan entre sí** (detalle en
`MAPA_TECNICO` §2): la app sale con `git push`; las Edge Functions con la CLI;
las migraciones las aplica el propietario con `aplicar_sql.ps1`; y las
plantillas de correo se pegan a mano en el panel de Supabase.

---

## 3. Las fronteras del modelo

| Frontera | Qué es | Decisión |
|---|---|---|
| **Plataforma** | Salón y Más como empresa: aprueba negocios, fija precios, da soporte | D-009, ADR-001 |
| **Negocio** (*tenant*) | La empresa cliente. Dueña del **catálogo**: clientas, servicios, profesionales, productos | D-011, ADR-003 |
| **Sede** (*branch*) | Donde ocurre el trabajo: agenda, caja, inventario. **Y desde D-239, quien paga** | ADR-001, D-239 |
| **Clienta** | Persona que reserva. Sus datos son del negocio, nunca compartidos entre negocios | ROLES §5 |

**Quién es quién no lo dice el perfil, lo dicen las membresías** (ADR-002):
`user_profiles` es la identidad; `tenant_memberships` y `branch_memberships`
dan el permiso, con vigencia. Una membresía de rol estilista **exige** apuntar a
su ficha del catálogo (`tenant_memberships_stylist_role_check`).

**Cada operación vuelve a resolver la sede en el servidor** (ADR-005):
`private.beautyos_resolve_branch_access(...)` comprueba cuenta, membresía, sede
del mismo negocio, rol y —para el estilista— su vínculo con esa sede. Lo que
Flutter manda como `branch_id` es la **elección** del usuario, nunca la prueba
de que puede.

**La clienta se identifica por su celular**, y desde D-249 **esa llave no se
comparte**: diez dígitos, uno por persona dentro de cada negocio
(`clients_tenant_phone_uidx`). No es orden de datos: con el celular y su PIN
entra al portal a ver sus citas y sus fotos, así que compartirlo sería compartir
el permiso. Ya estaba en el diseño del 19-jul (D-006, `ROLES_Y_PERMISOS` §5);
se impuso dos meses después.

### Los seis roles

| Rol | Alcance | Nota |
|---|---|---|
| Dueño de plataforma | Todos los negocios | **Ve datos de cualquier negocio en solo lectura y sin rastro (D-076), sin fecha de vencimiento (D-277)** |
| `tenant_owner` | Todas las sedes de su negocio | No necesita fila de sede |
| `admin` | Sedes asignadas | Hoy ve lo mismo que el dueño, rentabilidad incluida (**I-17**) |
| `assistant` (recepción) | Sedes asignadas | Cobra; no deshace pagos ni decide sueldos (D-095, D-251) |
| `stylist` | Lo suyo en sus sedes | Su agenda, sus fotos, su comisión |
| Clienta | Lo suyo | Portal con celular + PIN (D-167, D-185) |

---

## 4. Los invariantes técnicos

Estas reglas son **de construcción**, no de trabajo: dicen cómo tiene que estar
hecho el código. Nacieron con el proyecto en el `PROMPT_MAESTRO_IA` (julio) y
se archivaron con él el 09-ago. **Se devuelven aquí a un documento vivo.**
Las reglas de *cómo trabajamos* siguen viviendo solo en `PLAN_MAESTRO` §8.

| # | Invariante | De dónde sale | Excepción conocida |
|---|---|---|---|
| 1 | **Flutter con `StatefulWidget` + `setState`.** No se introduce Riverpod, Bloc ni Provider sin una decisión escrita | PROMPT_MAESTRO §3 | — |
| 2 | **Capas simples:** `lib/pages`, `services`, `models`, `widgets`, `theme`. No es Clean Architecture ni por funcionalidad | PROMPT_MAESTRO §3 | La lógica de dinero **vive dentro de las pantallas** (9.13/9.14, pendiente) |
| 3 | **Toda escritura sensible es una RPC `security definer` con `search_path` fijo**, que autoriza dentro. Nunca `insert`/`update` directo desde Flutter | PROMPT_MAESTRO §3, AGENTS.md, D-087 | Lecturas públicas cubiertas por RLS explícita |
| 4 | **RLS encendida en toda tabla nueva.** Muchas tienen **cero políticas a propósito**: solo se llega por RPC | PROMPT_MAESTRO §4.5, ROLES §7 | — |
| 5 | **Dinero en pesos enteros**, nunca decimales. Candados `CHECK (col = round(col))` | PROMPT_MAESTRO §3, D-175 | — |
| 6 | **UUID como llave; `tenant_id` en toda tabla operativa y `branch_id` cuando aplica** | PROMPT_MAESTRO §3, D-015 | — |
| 7 | **El catálogo es del negocio y la agenda lee las tablas de sede.** Escribir el catálogo obliga a sincronizar `branch_services` / `branch_stylists` | PROMPT_MAESTRO §3, D-048, D-049 | — |
| 8 | **No se borra nada físicamente**: se marca inactivo. El historial se conserva | Plantilla del PROMPT_MAESTRO, D-051, D-056 | **D-246**: borrar un negocio **marcado de prueba**, con rastro en `deleted_demo_tenants`. **Desde D-278/D-279 (24-sep, hallazgo AS) la excepción también borra sus archivos de Storage y las cuentas de Auth de su equipo que se queden sin ningún otro negocio** — antes esos dos quedaban huérfanos, sin ninguna fila que los reclamara |
| 9 | **Un valor de negocio no se escribe a mano donde se usa.** Precios, plazos, longitudes y códigos de plan viven en la base | `SUSCRIPCION_Y_ENTITLEMENTS` §2 (**19-jul**) | Respaldos documentados: catálogo de planes sin red (`public_plans_service`), el 10 del celular (dos sitios, comentados, D-249) |
| 10 | **Las funciones nuevas de operación llevan `_v2` y `p_branch_id` obligatorio**; sin sobrecargas ambiguas en `public` | ADR-005, D-021 | En `private` conviven versiones del cálculo de cobro: el webhook usa una (D-252) |
| 11 | **Los secretos nunca van al código ni al repositorio** | AGENTS.md | El DSN de Sentry, a propósito: es de solo escritura (D-228) |
| 12 | **Dinero de la plataforma y dinero del salón nunca comparten tablas** | `SUSCRIPCION_Y_ENTITLEMENTS` §1, D-013 | — |

> **La lección más cara de septiembre ya estaba escrita el 19-jul.**
> El invariante 9 aparece en `SUSCRIPCION_Y_ENTITLEMENTS` desde el primer día:
> *"los límites comerciales no se codifican como constantes en Flutter"*. Nadie
> lo releyó, y costó dieciséis días sin registros (D-245), un código cortado
> (**AY**) y seis escondites de un descuento abolido (D-252).

---

## 5. Cómo funciona el dinero HOY

El precio es **el tema más reescrito del proyecto**: más de veinte decisiones
entre el 19-jul y el 22-sep (ver §8). Esto es lo vigente, en un solo sitio.

### 5.1 El plan y el precio

- **Un solo plan**, `pro` — *Todo Incluido* — con todas las funciones (D-188).
- **Precio de lista: $150.000 por sede al mes** (D-189). Vive en `plans.price_cop`.
- **El precio negociado es de cada sede, en pesos** (`branch_subscriptions.price_cop`,
  con su motivo). **No existe precio de negocio que cobre** ni descuento
  porcentual (D-252). El pionero es **una etiqueta** (`is_founder`), no un
  descuento (D-221).
- **Prueba gratis**: 21 días por defecto, **empieza al aprobar**, no al
  registrarse (D-125, D-138). Nadie entra solo.
- **Equipo**: 9 cuentas por sede activa + el dueño, que no cuenta (D-189, D-196).

### 5.2 Dos estados de suscripción, cosidos por la sede principal

Este es el hecho menos obvio de toda la arquitectura:

| Tabla | Decide | Quién la mueve |
|---|---|---|
| `tenant_subscriptions` | **Si el salón puede entrar y trabajar** (D-068), el aviso de vencimiento, la prueba gratis | La aprobación; y **el pago de la sede principal** |
| `branch_subscriptions` | **Qué se cobra** y si cada sede está al día | El pago de cada sede |

**Pagar la sede principal mueve también la suscripción del negocio**; pagar una
secundaria, no (`beautyos_procesar_pago_de_sede`, D-192, conservado en D-232).
Si no fuera así, un salón de una sede pagaría y **se quedaría fuera de su propia
aplicación**.

### 5.3 El camino de un cobro

```
Configuración → "Activar esta sede"
   → create-epayco-session: registra la INTENCIÓN de pago con su sede (D-182, D-191)
      y calcula el cargo con beautyos_calcular_cargo_sede (prorrateo, D-191)
   → pasarela de ePayco
   → epayco-webhook (firma SHA-256) ─┐  resuelven la intención por factura
   → verify-epayco-transaction ──────┘  y derivan a beautyos_procesar_pago_de_sede
   → la sede queda al día; si es la principal, el negocio también
```

- **Ciclos de 30 días anclados al primer pago** (D-160). Renovar antes acumula.
  *(Hasta el 23-sep, pagar tarde en la gracia prorrateaba: los días de gracia
  salían gratis. **Desde D-265/D-266 se cobra el mes completo** y la fecha de
  corte no se corre. Hallazgo BN.)*
- **El cobro mínimo de una sede es $10.000** (D-265): lo exige la activación
  desde D-159, y desde el 23-sep un disparador en `branch_subscriptions` impide
  pactar por debajo **por cualquier puerta** (hallazgo BO).
- **Gracia de 5 días** y luego suspensión, gradual y reversible, **sin borrar
  datos** (D-014, D-141). ⚠️ **Hoy solo funciona si ePayco rechaza un pago.** Si
  el salón simplemente no paga, nada lo pasa a mora: pierde las citas nuevas al
  día siguiente sin gracia, y **una sede secundaria que no paga nunca se corta**
  (hallazgo **BI**, 23-sep). **Corregido el mismo 23-sep (D-258):** una tarea
  diaria a las 07:50 pasa a mora **por fecha** —negocio y sede— con sus 5 días,
  y suspende las sedes con la gracia vencida. **Y D-261:** una sede suspendida
  **no agenda citas nuevas** —las demás siguen—, y el candado dice el motivo
  real en vez de *"prueba gratis"*. Hallazgo BI, cerrado.
- **Avisos por correo** a 10, 5 y 3 días, y cada día de la gracia (D-143, D-196),
  disparados por `pg_cron` a las 8:00 de Colombia (D-145).
- **El camino del negocio está cerrado** en la entrada (`public.beautyos_calcular_cargo_epayco`
  se niega, D-252), pero **la maquinaria que liquida sigue viva** a propósito: un
  pago rezagado tiene que poder registrarse.

> ✅ **Superado el 23-sep (D-269 a D-272):** dos pagos reales de $10.000 por el
> camino de la sede —Éxito, aplicado al volver a la app; Naguara, aplicado **por el
> webhook solo**—, después de corregir la llave de firma `EPAYCO_P_KEY` (D-271).
> Lo de abajo es cómo estaba ese día por la mañana.
>
> ⚠️ **El camino de cobro que queda nunca ha cobrado un peso real.** Los dos
> únicos cobros de la historia (23-ago y 08-sep, $10.000 cada uno, negocios de
> prueba) fueron por el camino del negocio, que desde el 22-sep está cerrado. El
> de la sede solo lo han ejercitado controles SQL (203, 204, 220, 221). **El
> primer pago del primer cliente será la primera vez que funcione de verdad** —
> salvo que antes se haga el paso 9.8.

### 5.4 El dinero del salón (no el de la plataforma)

- **Ticket**: la cita. Tiene servicios, cada uno con su estado: *pendiente → en
  proceso → finalizado* (`AccionesDeTicket`, D-250). El ticket pasa a *Por
  cobrar* cuando termina el último servicio.
- **Pagos**: se admiten desde que la cita existe — abonos y anticipos (D-163).
- **Cierre y comisión**: el ticket se cierra y **nace la comisión** cuando está
  finalizado **y** pagado entero (`beautyos_close_ticket_if_fully_paid`). Se
  mira en los dos momentos: al entrar un pago **y** al terminar el último
  servicio (D-250).
- **Comisión**: la política del negocio (`commission_policies`, 40% por defecto
  de la tabla) con excepciones por sede, estilista y servicio (D-078). **Nace
  sin confirmar** y se avisa en tres sitios hasta que alguien la guarda (D-251).
- **Numeración**: consecutivo de ticket ajustable (D-117) y número de venta
  inmutable por sede, preparado para resolución DIAN (D-150, D-151).

---

## 6. Entrada y cuentas

- **Registro**: el negocio llena el filtro y **espera aprobación** (D-125). El
  correo de confirmación trae **un código** —no un enlace, porque los escáneres
  del buzón lo gastaban— y la longitud la decide Supabase (D-248, **AY**).
- **Equipo**: se invita por correo (Resend); la cuenta se vincula a su ficha del
  catálogo, una sola cuenta activa por estilista (D-132).
- **Plataforma**: rol aparte (`platform_operators`), fuera de los negocios (D-046).
- **Clienta**: portal con celular y PIN de 4 dígitos, asignado por el salón,
  guardado con bcrypt y con bloqueo escalonado (D-167, D-183, D-185).

---

## 7. Fotos y consentimiento

- Toda foto **nace privada** (`work-photos-private`) y solo pasa al almacén
  público al aprobarse para el portafolio (D-119, H-09).
- El servidor **no deja publicar sin consentimiento** (D-167, Ley 1581). **Pero
  hoy la casilla de consentimiento la marca quien sube la foto, no la clienta**
  (**AQ**), y el interruptor *"Visible al cliente"* no consigue que ella la vea
  mientras sea privada (**AU**).
- **El diseño rector ya preveía que consintiera ella**: la matriz de
  `ROLES_Y_PERMISOS` dice *"Fotos, reseñas y redes — Customer: P/consentido"*.
  El paso **9.48** no inventa nada: cumple el diseño del 19-jul.

> **26-sep (D-281): el Bloque 1 de 9.48 está escrito, sin aplicar.** Nace
> `clients.consent_link_token` (enlace directo, permanente) junto al token
> de sesión del portal que ya existía; `work_photos.client_consent_decided_at`
> y `reviews.client_name_consent`/`_decided_at` distinguen "pendiente de
> preguntarle" de "ya decidió". Cinco funciones nuevas y una Edge Function
> (`client-consent-photo-url`) que firma la ruta de una foto privada
> **después** de que la RPC de SQL ya autorizó el acceso con el token — la
> autorización entera vive en SQL, no en TypeScript. Sin sesión de Supabase
> Auth: se identifica con su token, igual que el resto del portal (D-167).

---

## 8. Cómo llegó aquí — la evolución

### Por épocas

| Época | Qué pasó | Decisiones |
|---|---|---|
| **19-jul — La fundación** | SaaS para estética en Colombia, multisede desde la base, fronteras plataforma/negocio/sede, membresías, entitlements en el servidor, dinero SaaS separado del dinero del salón | D-001 a D-015, ADR-001 a 004 |
| **20 al 22-jul — El multisede** | Tramos A-D: `branch_id` en todo, RPC `_v2` con sede obligatoria, se cierran las heredadas. Se descubre que el único proyecto de Supabase —llamado `beautyos-dev`— **es producción** | D-016 a D-043, ADR-005 |
| **22-jul al 05-ago — El producto** | Catálogo editable, invitaciones, reserva pública, inventario, reseñas, fotos, marca blanca, 2FA, sedes adicionales | D-044 a D-086 |
| **06 al 12-ago — Salir a internet** | Stack de producción (D-088), nombre *Salón y Más*, auditoría integral de 13 hallazgos, un solo Plan Maestro, reglas en un sitio, primer ensayo de restauración | D-087 a D-137 |
| **16 al 30-ago — Las fases 3 a 8 a toda velocidad** | Cobro con ePayco, avisos, términos, tablero de agenda, página pública, portal de la clienta, IA determinista, panel de plataforma, referidos. Trabajan varios asistentes (D-137), y varias decisiones son auditorías de Claude Code sobre trabajo ya hecho (D-139, D-149, D-151, D-159 — esta última caza una regresión crítica del cobro el mismo día) | D-138 a D-180 |
| **01 al 09-sep — Un plan, cobro por sede, Fase 9** | Auditoría de 4 revisiones, **un solo plan por sede** (D-188), el cobro se parte por sede, CI, nace la Fase 9 (D-216), dirección de producto a 5 lugares (D-219), **un solo editor** (D-218) | D-181 a D-238 |
| **16 al 22-sep — El recorrido con personas reales** | El cobro se muda a la sede (D-239). Un invitado descubre que **nadie podía registrarse desde hacía 16 días** (D-245). Recorrido de punta a punta con personas: doce hallazgos (D-247). Puerta por código, celular como llave, comisiones, precio por sede | D-239 a D-253 |

### La cadena del precio, que es la historia en miniatura

D-004 tres planes → D-045 Profesional por defecto → D-124 precios y límites →
D-136 pionero al 50% → D-138 aprobar con 50% → D-140 página de tres planes →
D-158 selector de planes → **D-188 un solo plan por sede** → D-189 $150.000 →
D-190 a D-193 cobro por sede → **D-212 reintroduce el 50%** → D-221 el pionero es
etiqueta → D-222 socios de diseño a $50.000 → D-236/D-237 precio de sede
editable → **D-239 cobra la sede** → **D-252 el precio solo existe en la sede, y el
50% aparece en seis escondites más**.

**Lo que enseña:** cada cambio de modelo se aplicó al servidor y dejó restos en
pantallas, pruebas y textos. El 50% se abolió el 01-sep y seguía vivo el 22-sep
en la función que aprueba clientes y en un cartel que se lo prometía al salón.

---

## 9. Lo que el repositorio NO sabe

- **El esquema completo** (hallazgo **AI**): las migraciones crean parte de las
  tablas; las más grandes —`tenants`, `clients`, `tickets`, `work_photos`—
  nacieron antes de usar migraciones. `supabase db reset` **no** reconstruye la
  base. **Antes de reescribir una función, se extrae su texto vivo** (guiones de
  ejemplo en `supabase/sql/intervenciones/`).
- **Qué versiones de una función existen**: el 22-sep aparecieron tres del
  cálculo de cobro que ninguna migración reciente menciona, y el 23-sep **dos de
  `register_tenant`**, la vieja con el fallo de D-245 dentro (hallazgo **BG**).
  `CREATE OR REPLACE` con otra lista de parámetros **no reemplaza: añade**.
- **Lo que depende de decisiones con fecha de caducidad.** Una está escrita
  para *"mientras no haya clientes reales"*: los datos sembrados (D-135). El
  acceso de soporte de la plataforma a todos los datos, sin rastro (D-076),
  **ya no tiene fecha**: el propietario decidió el 24-sep que se queda igual
  para siempre (D-277, hallazgo BC cerrado). La lista completa de lo que
  cambia el día del primer cliente real vive en `MAPA_TECNICO` §1-bis.

---

## 10. Las lecciones de método, con su decisión

No son reglas —las reglas viven en `PLAN_MAESTRO` §8—: son lo que cada regla
costó aprender.

| Lección | Costó | Decisión |
|---|---|---|
| **Verificar en el código antes de afirmar** | Tres fallos por nombres supuestos | D-049, regla 1 |
| **Al reescribir una función, comparar línea por línea contra la viva** | Tres fallos en un día | D-119, D-122, D-123 |
| **Una edición que falla en silencio es peor que no hacerla** | Tres hallazgos perdidos | D-129 |
| **Una regla copiada en seis sitios no se refuerza: diverge** | Reglas que se contradecían | D-126, D-131 |
| **Leer comprueba intención; ejecutar comprueba el hecho; recorrer comprueba el producto** | 16 días sin registros | D-245, D-247 |
| **Un valor que vive en otra parte no se escribe a mano donde se usa** | D-245, **AY**, el 50% | Invariante 9 (desde el 19-jul) |
| **Quitar un respaldo sin probar el camino principal destapa lo que tapaba** | Tickets caído en producción | D-199, D-203 |
| **Cuando el servidor cambia, la pantalla que lo ofrece cambia en el mismo bloque** — rótulos incluidos | Carteles prometiendo el 50% | D-229, D-230, regla 16-ter |
| **Un control que vigila una función no vigila una regla** | El 50% sobrevivió 15 días por la otra puerta | D-252 |
| **Una prueba puede defender un fallo** | Dos pruebas sujetando el 50% | D-252 |
| **Una regla escrita que no se cumple no protege: engaña** | La regla 12 | D-253 |

---

*Si un hecho de aquí deja de ser cierto, se corrige aquí mismo y se registra la
decisión que lo cambió. El historial vive en el `REGISTRO_DE_DECISIONES`.*
