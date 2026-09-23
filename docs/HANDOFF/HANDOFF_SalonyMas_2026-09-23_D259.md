# HANDOFF Salón y Más — 23 de septiembre de 2026, tarde ("Cerrando hallazgos", D-255 a D-259)

**Bloque documentado:** decisiones **D-255** a **D-259**, hechas mientras el propietario descansaba y con su autorización expresa: *"resolviendo y cerrando los hallazgos que más puedas, tienes todo mi consentimiento, a medida que vayas cerrando ve documentando"*.

**Estado:** ✅ Cinco bloques publicados. **Dos migraciones escritas y SIN APLICAR** (§3).
`flutter analyze` **0/0** · **483 pruebas** (eran 453) · Guardián en verde · CI en verde.

> El bloque anterior (la revisión integral, D-253 y D-254) está en
> `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-23_D254.md`. **Sus seis
> decisiones pendientes siguen pendientes**: se copian en el §5.

---

## 1. Lo que hay que saber si solo se lee una cosa

**BI —vencer sin pagar no pasa a mora— lo confirmaste tú en pantalla**: Nueva
cita en Naguara → *"La prueba gratis… vencida"*, con la cabecera en verde
diciendo *Vence 22/09*. Tiene dos mitades:

| Mitad | Estado |
|---|---|
| **La pantalla** (D-255) | ✅ **Publicada.** Lo vencido se ve rojo, y **una sede vencida ya se puede renovar**: antes no tenía botón |
| **El servidor** (D-258) | 📝 **Escrita, sin aplicar.** Es la que da los 5 días de gracia y corta las sedes. **La aplicas tú** (§3) |

**Y al arreglar la píldora apareció otro fallo peor (BK):** las píldoras de la
cabecera abrían el cobro *por negocio* que cerramos el 22-sep. Quien pulsaba
*"Prueba vencida · Activar plan"* recibía un error. Ya llevan a Configuración.

---

## 2. Qué se hizo, bloque por bloque

| | Qué | Hallazgos |
|---|---|---|
| **D-255** | La cabecera roja con *Venció el 22/09/2026 · Renovar*; *Tus sedes* con **Renovar esta sede** y **Pagar el mes siguiente** a 5 días de vencer; el Panel dice *VENCIDO SIN PAGAR* y la ficha deja de decir *Estado: ACTIVE* en inglés; el `\n` escrito en la nueva cita | BI (mitad), **BJ ✅, BK ✅** |
| **D-256** | Las páginas públicas de precios y de reseñas **con tildes y con ¿**; los candados ya no mandan a comprar *Business* o *Profesional*; la casilla de la foto dice *"Confirmo que le pedí a la clienta su autorización"* | **AV ✅, BD ✅**, AQ (mitad), AL (nota) |
| **D-257** | La píldora *En Prueba* del Panel ya no cuenta los ensayos (**0 arriba, 0 abajo**); la reserva pública avisa *"esa hora ya pasó"* o *"alguien acaba de reservarla"* y recarga la lista sin borrar lo escrito | **AR ✅, AX ✅** |
| **D-258** | Las dos migraciones de §3 y sus controles 222 y 223 | BI, BG, BH (escritas) |
| **D-259** | Cuatro formularios que se quedan abiertos si el servidor rechaza: precio de sede, **datos de la sede (eran dos copias, ahora uno)** y *Crear cliente rápido* | AK (a medias: quedan 6) |

**Hallazgos:** 53 en total, **33 cerrados o decididos, 20 abiertos** (los cuenta el guardián). Esta mañana eran 51 y 24.

---

## 3. ⚠️ Lo que tienes que hacer tú: dos migraciones

**Nada de esto lo publica el `push`.** Las migraciones las aplicas tú (regla 16). En este orden, **un comando a la vez**, y me pegas lo que sale:

**1. Respaldo**

```bash
powershell -ExecutionPolicy Bypass -File scripts\respaldo_supabase.ps1
```

**2. BI — vencer sin pagar pasa a mora.** Al aplicarse corre una vez: Naguara pasará a *período de gracia* hasta el 27-sep y **volverá a poder agendar** esos días.

```bash
powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" -Archivo "supabase\migrations\20260923120000_vencer_sin_pagar_pasa_a_mora_bi.sql"
```

**3. Su control** — tiene que terminar en **10/10**:

```bash
powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" -Archivo "supabase\sql\222_test_vencer_sin_pagar_pasa_a_mora.sql"
```

**4. BG y BH — una sola `register_tenant` y permisos de `private`**

```bash
powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" -Archivo "supabase\migrations\20260923130000_una_sola_register_tenant_y_permisos_de_private_bg_bh.sql"
```

**5. Su control** — tiene que terminar en **5/5**:

```bash
powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" -Archivo "supabase\sql\223_test_una_sola_register_tenant.sql"
```

**Si algo sale con `FALLO` o `PARADA`, para ahí** y me lo pegas: las dos migraciones comprueban antes de tocar nada.

---

## 4. Lo que tienes que mirar en pantalla (regla 21)

Pulsa **Actualizar** en el aviso de versión nueva primero.

1. **Naguara, arriba a la derecha:** píldora **roja** *Venció el 22/09/2026 · Renovar*. Al tocarla, te lleva a **Configuración**. *(Después de aplicar la migración de BI cambia a ámbar: "N días de gracia · Pagar".)*
2. **Configuración → Tus sedes:** la sede dice **Período vencido** en rojo con el botón **Renovar esta sede**. **No lo pulses hasta el final: NO PAGAR.** Basta con ver que está.
3. **Configuración → la tarjeta con el nombre de tu sede → Editar:** pon un correo **sin arroba** y pulsa Guardar. El formulario **no se cierra**, y el error sale **debajo del correo**, con los otros seis campos intactos.
4. **Panel de plataforma:** la píldora **En Prueba** dice **(0)**, y Naguara dice **VENCIDO SIN PAGAR**.
5. **La página pública de precios** (`salonymas.com/?planes=1`): con tildes, y las preguntas empiezan por **¿**.
6. **Nueva cita → Crear cliente rápido** con el celular de una clienta que ya existe: el diálogo **se queda abierto** con el aviso dentro.

---

## 5. Las decisiones que siguen siendo tuyas

Las seis de esta mañana, sin tocar (regla 20), **más una nueva**:

| | Qué | Por qué importa |
|---|---|---|
| **a** | **Aprobar el orden propuesto** de la Fase 9 (`PLAN_MAESTRO`) | Sin aprobar, el orden vuelve a vivir en el HANDOFF |
| **b** | **El pago real de $4.500** con la sede de Éxito (9.8) | Excepción deliberada a *NO PAGAR NADA*; la única forma de saber que cobrar funciona |
| **c** | **Cuándo pasar a Supabase Pro** | D-088 decía *cuando cargue datos*, D-226 *cuando pague* |
| **d** | **I-13**: acceso de lectura a la base para el asistente | Hoy cada lectura son comandos tuyos con contraseña |
| **e** | **El acceso de soporte a los datos de los salones** (BC) | D-076 caduca con el primer cliente real |
| **f** | **Las reglas 5 y 9** | Se cumplen menos de lo que dicen |
| **g — nueva** | **¿Una sede secundaria suspendida debe dejar de agendar?** | Hoy el acceso es del negocio (ADR-006): una sede que no paga queda *suspendida* en el Panel, pero **sigue agendando**. Es una decisión de producto, no un arreglo |

---

## 6. Lo que quedó a medias

1. **Las dos migraciones del §3**, escritas y sin aplicar.
2. **BI — el mensaje del candado.** Sigue diciendo *"La prueba gratis… vencida"* a quien pagó meses y está suspendido. Cambiarlo es reescribir `create_scheduled_ticket_with_service_v2` y `public_create_booking`: primero hay que extraer su texto vivo con `supabase\sql\intervenciones\extraer_candado_y_vencimiento_bi.sql` (deja archivos `_vivo_*.sql` que ya no se suben: `.gitignore` los ignora desde D-258).
3. **AK — quedan seis diálogos en `tickets_page.dart`** (agregar, cambiar y quitar servicio; reprogramar; cambiar estado; corregir). Van con el **9.13**, porque son flujos de caja.
4. **AQ** — el texto ya es honesto; lo cierra que la clienta apruebe desde su portal (9.48).
5. **AL** — la frase de pantalla ya no existe (se fue con D-248); queda la plantilla de correo, en Supabase.

---

## 7. Lo que NO hay que hacer

- 🔴 **NO pagar nada.** Ni la suscripción de $150.000 ni el botón *Renovar esta sede* de Naguara. El pago de $4.500 del 9.8 es una decisión tuya pendiente (§5 b).
- **NO borrar la Peluquería Éxito Prueba.** Es el banco de pruebas.
- **NO retirar `beautyos_calcular_cargo_epayco` ni `beautyos_procesar_evento_epayco`**: el webhook liquida con ellas.
- **NO arreglar los seis diálogos de Tickets sueltos**: van con el 9.13.
- **NO volver a nombrar un plan en un candado**: el campo que lo hacía se quitó a propósito (D-256, una prueba lo vigila).
- **NO contar hallazgos a mano**: `python scripts/verificar_documentos.py`.

---

## 8. Por dónde seguir

1. **Tus verificaciones** (§3 y §4), y lo que salga de ellas.
2. **Tus decisiones** (§5), sobre todo **a** (el orden) y **g** (las sedes suspendidas).
3. Con BI aplicado, el turno A sigue: **9.8 + 9.7** con $4.500 propios → 9.40 → AD → 9.9.

---

## 9. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-255 a D-259).

Antes de tocar documentación: python scripts/verificar_documentos.py

DÓNDE ESTAMOS
El 23-sep por la tarde, con el propietario descansando y su autorización, se
cerraron BJ, BK, AV, BD, AR y AX, y se avanzaron BI, AQ y AK. Todo publicado.
Quedan DOS MIGRACIONES ESCRITAS Y SIN APLICAR (HANDOFF §3): la de BI (mora
por fecha con 5 días de gracia, control 222) y la de BG+BH (una sola
register_tenant y permisos de private, control 223). Las aplica él.

LO PRIMERO
Preguntarle si aplicó las migraciones y cómo salieron los controles 222 y
223, y si miró en pantalla lo del §4. Después, sus decisiones del §5: la
principal es aprobar el orden de la Fase 9, y hay una nueva (g): si una sede
secundaria suspendida debe dejar de agendar.

CÓMO SE TRABAJA CON ÉL
Va paso a paso y confirma cada uno. No es técnico: qué se hace, cómo y por
dónde, con los nombres exactos de los botones. Los comandos van en bloques
bash de una sola línea y los ejecuta él. VERIFICA EN EL CÓDIGO ANTES DE
CONTESTAR. Tu papel está en el PLAN_MAESTRO §8: Senior Tech Lead.

ANTES DE REESCRIBIR CUALQUIER FUNCIÓN DE LA BASE
Extraer su texto vivo y compararlo línea por línea (D-119, D-122, D-123). El
repositorio NO es la fuente del esquema (hallazgo AI).

NO PAGAR NADA. NO borrar la Peluquería Éxito Prueba. NO retirar las
funciones de cobro del negocio: el webhook liquida con ellas.
```
