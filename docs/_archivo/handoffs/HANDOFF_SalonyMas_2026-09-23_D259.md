# HANDOFF Salón y Más — 23 de septiembre de 2026, tarde ("Cerrando hallazgos", D-255 a D-259)

**Bloque documentado:** decisiones **D-255** a **D-259**, hechas mientras el propietario descansaba y con su autorización expresa: *"resolviendo y cerrando los hallazgos que más puedas, tienes todo mi consentimiento, a medida que vayas cerrando ve documentando"*. **Y D-260**, con sus respuestas al volver, y la **regla 25**.

**Estado:** ✅ Cinco bloques publicados. ✅ **Las dos migraciones, aplicadas por el propietario** (controles 222: 10/10 y 223: 5/5).
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
| **El servidor** (D-258) | ✅ **Aplicada el 23-sep.** Naguara y dos sedes pasaron a mora con sus 5 días de gracia; la tarea diaria corre a las 07:50 |
| **La sede suspendida deja de agendar** (D-260) | 📝 **Decidido, sin construir.** Espera la extracción del §3 |

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

## 3. ✅ Las dos migraciones: aplicadas. Lo siguiente es una lectura

Las aplicaste el 23-sep con respaldo previo (`Backup_2026-09-23_09-45-57`):
**control 222 en 10/10** y **control 223 en 5/5**. BG y BH quedan cerrados.

**La lectura ya se hizo (D-261):** las dos puertas coincidían línea por línea
con el repositorio, y el candado y el vigilante eran lo que suponía D-258.

**La migración de la sede suspendida (D-261): aplicada, control 224 en 9/9.**
BI queda cerrado (D-262): la sede suspendida no agenda y la pantalla lo dice.

**BL: cerrado (D-264).** Control 225 en 4/4, y cero filas del historial dañadas.

**BN y BO: migración escrita desde el texto vivo, SIN APLICAR (D-265).** La
gracia se cobra entera, la sede de Éxito sube a $10.000 y nadie pacta por
debajo del mínimo. Después, la lectura para que el estilista agende:

```bash
powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" -Archivo "supabase\migrations\20260923190000_la_gracia_se_cobra_y_el_cobro_minimo_bn_bo.sql"
```

```bash
powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" -Archivo "supabase\sql\226_test_la_gracia_se_cobra_y_el_minimo.sql"
```

```bash
powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" -Archivo "supabase\sql\intervenciones\extraer_agenda_del_estilista_bm.sql"
```

El control debe decir **7/7**. La lectura deja `_vivo_bm_agenda_del_estilista.sql`.

---

## 4. Lo que tienes que mirar en pantalla (regla 21)

Pulsa **Actualizar** en el aviso de versión nueva primero.

1. **Naguara, arriba a la derecha:** como ya aplicaste la migración, la píldora ya no es roja: es **ámbar**, *"N días de gracia · Pagar"*. Al tocarla, te lleva a **Configuración**.
2. **Configuración → Tus sedes:** la sede dice **Pago vencido**, con un botón para pagarla (*Ponerla al día*, o *Activar esta sede* si nunca se registró un pago suyo). **No lo pulses: NO PAGAR.** Basta con ver que está.
2-bis. **Nueva cita en Naguara:** ahora **debería dejarte crearla**, porque está en sus días de gracia (el control 222 lo comprobó con un negocio de prueba). Antes de la migración te la negaba.
3. **Configuración → la tarjeta con el nombre de tu sede → Editar:** pon un correo **sin arroba** y pulsa Guardar. El formulario **no se cierra**, y el error sale **debajo del correo**, con los otros seis campos intactos.
4. **Panel de plataforma:** la píldora **En Prueba** dice **(0)**, y Naguara dice **PAGO PENDIENTE** (ya no *VENCIDO SIN PAGAR*: la migración la movió de estado).
5. **La página pública de precios** (`salonymas.com/?planes=1`): con tildes, y las preguntas empiezan por **¿**.
6. **Nueva cita → Crear cliente rápido** con el celular de una clienta que ya existe: el diálogo **se queda abierto** con el aviso dentro.

---

## 5. Las decisiones que siguen siendo tuyas

**Dos quedaron contestadas el 23-sep (D-260):** la **f** —*"realiza todas las preguntas que necesites siempre"*: las reglas 5 y 9 siguen, reforzadas por la 25— y la **g** —una sede suspendida **deja de agendar citas nuevas**; hereda del negocio la gracia, la suspensión y la fecha de corte, no el precio ni los módulos—. Quedan cinco:

| | Qué | Por qué importa |
|---|---|---|
| **a** | **Aprobar el orden propuesto** de la Fase 9 (`PLAN_MAESTRO`) | Sin aprobar, el orden vuelve a vivir en el HANDOFF |
| **b** | **El pago real de $4.500** con la sede de Éxito (9.8) | Excepción deliberada a *NO PAGAR NADA*; la única forma de saber que cobrar funciona |
| **c** | **Cuándo pasar a Supabase Pro** | D-088 decía *cuando cargue datos*, D-226 *cuando pague* |
| **d** | **I-13**: acceso de lectura a la base para el asistente | Hoy cada lectura son comandos tuyos con contraseña |
| **e** | **El acceso de soporte a los datos de los salones** (BC) | D-076 caduca con el primer cliente real |
| ~~f~~ | ~~Las reglas 5 y 9~~ | ✅ Contestada (D-260) |
| ~~g~~ | ~~¿Una sede suspendida debe dejar de agendar?~~ | ✅ **Sí**: solo las citas nuevas de esa sede (D-260) |
| **h — nueva** | **Las fotos: ¿qué hacemos con los tipos *Final* y *Portafolio*?** | Definiste el flujo (se toma con la clienta presente; publicarla lo autoriza solo ella desde su enlace), pero el hallazgo Ñ también decía que esos dos tipos sobran |
| ~~i~~ | ~~¿El estilista puede agendar citas?~~ | ✅ **Sí, para sí mismo** (D-263). Faltan dos detalles: si da de alta a la clienta nueva, y si la cita nace por confirmar o confirmada |
| ~~j~~ | ~~¿Gracia al terminar la prueba?~~ | ✅ **No**: la gracia es solo de los meses pagados (D-263) |
| ~~k~~ | ~~¿Cobrar el mes completo en la gracia?~~ | ✅ **Sí** (D-264). Falta la migración |
| ~~l~~ | ~~¿Corregir las filas del historial dañadas?~~ | ✅ **No hace falta**: el control 225 contó cero |
| ~~m~~ | ~~¿Mínimo de ePayco?~~ | ✅ **El cobro mínimo de una sede es $10.000** (D-265). Éxito sube a $10.000 |
| **n — nueva** | **¿Qué clientas ve el estilista al escoger para quién es la cita?** (BM) | Todas las del salón, como recepción, o solo las que él atendió o dio de alta. Pesa el día que un estilista se va con la lista de clientas |

---

## 6. Lo que quedó a medias

1. **BI — la sede suspendida deja de agendar** (decidido en D-260). Espera la extracción del §3; después, una migración que toca las dos puertas por las que nace una cita, con su control.
2. **BI — el mensaje del candado.** Sigue diciendo *"La prueba gratis… vencida"* a quien pagó meses y está suspendido. Cambiarlo es reescribir `create_scheduled_ticket_with_service_v2` y `public_create_booking`: primero hay que extraer su texto vivo con `supabase\sql\intervenciones\extraer_candado_y_vencimiento_bi.sql` (deja archivos `_vivo_*.sql` que ya no se suben: `.gitignore` los ignora desde D-258).
3. **AK — quedan seis diálogos en `tickets_page.dart`** (agregar, cambiar y quitar servicio; reprogramar; cambiar estado; corregir). Van con el **9.13**, porque son flujos de caja.
4. **AQ y Ñ** — el flujo ya lo definiste (D-260): **publicar la foto lo autoriza solo la clienta desde su enlace**. Hoy la casilla del salón todavía la habilita; construir esa aprobación es lo que cierra AQ (9.48).
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

1. **Aplicar BN y BO** (§3) con su control 226, y correr la lectura del estilista.
1-bis. **Tu decisión n**, y con la lectura, construir que el estilista agende para sí mismo (BM).
2. **Tus verificaciones en pantalla** (§4).
3. **Tus decisiones** (§5), sobre todo **a** (el orden).
4. Con BI cerrado, el turno A sigue: **9.8 + 9.7** con $4.500 propios → 9.40 → AD → 9.9.

---

## 9. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-255 a D-259).

Antes de tocar documentación: python scripts/verificar_documentos.py

DÓNDE ESTAMOS
El 23-sep se cerraron BJ, BK, AV, BD, AR, AX, BG y BH, y se avanzaron BI, AQ
y AK. Las dos migraciones (D-258) están APLICADAS: controles 222 (10/10) y
223 (5/5). El propietario decidió (D-260) que una sede suspendida por no
pago deja de agendar citas nuevas, y definió el flujo de las fotos.

LEE LA REGLA 25 DEL PLAN MAESTRO §8 ANTES DE NADA: afirmar exige prueba, lo
aprobado no se cambia sin avisar, el producto se pregunta aunque haya
permiso general, y lo que corre el propietario se copia de algo que ya
funcionó.

LO PRIMERO
BI está cerrado (D-261 aplicada, control 224 en 9/9; D-262). BN (la gracia se
cobra entera) y BO (el cobro mínimo de una sede es $10.000, Éxito sube a
$10.000) están en una migración escrita desde el texto vivo, SIN APLICAR:
preguntarle por el control 226 (7/7). Para BM (el estilista agenda para sí
mismo, da de alta a la clienta desde Mi agenda, la cita nace por confirmar)
hay una lectura preparada y falta su decisión n: qué clientas ve.

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
