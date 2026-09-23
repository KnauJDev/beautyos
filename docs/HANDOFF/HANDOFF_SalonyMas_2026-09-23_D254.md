# HANDOFF Salón y Más — 23 de septiembre de 2026 ("La revisión integral", D-253 y D-254)

**Bloque documentado:** decisiones **D-253** (el `push` va incluido al aprobar el bloque) y **D-254** (revisión integral, ampliada con la radiografía de la base) · hallazgos **BC** a **BI** nuevos, **BE** y **BF** cerrados · ADR-006 nuevo.

**Estado:** ✅ Documentación puesta al día y publicada. Un solo cambio de código: un letrero.
`flutter analyze` **0/0** · **453 pruebas** · Guardián en verde.

> 🔴 **La radiografía de la base encontró un fallo de cobro serio (BI).** Ver §1.
> ⚠️ **Quedan dos cosas por verificar tuyas.** Ver §6.
> El bloque anterior está en `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-22_D252.md`.

---

## 1. Lo que hay que leer si solo se lee una cosa

**El proyecto está sano donde más cuesta y débil donde es más barato arreglarlo.**
El CI pasa en verde en los últimos 20 commits, las 169 decisiones que cita el
código existen todas, y la seguridad vive en el servidor. Lo débil era
documental: **y eso quedó corregido hoy.**

Lo único de la revisión que puede costar dinero de un cliente:

> **El camino de cobro que queda nunca ha cobrado un peso real.** Los dos únicos
> cobros de la historia fueron por el camino del negocio, que D-252 cerró. La
> sede de la Peluquería Éxito tiene pactados **$4.500**: es la prueba real más
> barata posible (paso 9.8).

**Y lo que encontró la radiografía de la base, ese mismo día, pesa más:**

> 🔴 **BI — Vencer sin pagar no pasa a mora.** Aquí el pago es manual cada mes.
> Solo un pago **rechazado** pone la suscripción en mora, y quien simplemente
> **no paga** no produce ningún rechazo. Resultado, al día siguiente de vencer:
>
> - el panel sigue diciendo **ACTIVO**;
> - pero ya **no deja crear citas nuevas**, con un mensaje que habla de
>   *"la prueba gratis"* aunque el salón haya pagado meses;
> - **sin los días de gracia** que D-192 prometió;
> - y **una sede secundaria que no paga no se corta nunca**.
>
> Se ve hoy en Naguara: *ACTIVE · Válido hasta 22/09* y la sede *Al día ·
> Pagada hasta 22/09*, el 23-sep. **Va primero en el turno A**: probar el cobro
> sin saber qué pasa cuando no se cobra es probar la mitad.

---

## 2. Dónde está ahora cada cosa

| Quiero saber… | Dónde |
|---|---|
| **Qué es el sistema, cómo está construido y cómo funciona el dinero hoy** | **`docs/01_arquitectura/ARQUITECTURA_Y_EVOLUCION.md`** — nuevo |
| **Qué está mal hoy y qué opina el Tech Lead del stack** | `docs/01_arquitectura/auditorias/AUDITORIA_INTEGRAL_2026-09-23.md` — nuevo |
| **Qué falta y en qué orden** | `PLAN_MAESTRO`, Fase 9, **"Orden propuesto el 23-sep"** — pendiente de aprobar |
| **El papel del asistente** | `PLAN_MAESTRO` §8, *"El papel del asistente"* — rescatado del archivo |
| Dónde está cada cosa y cómo se opera | `MAPA_TECNICO` — puesto al día |
| Por qué el cobro es de la sede | `ADR-006` — nuevo |

---

## 3. Las dos decisiones

### D-253 — El `push` va incluido al aprobar el bloque

La regla 12 decía *"pedir permiso antes de cada `push`"* y el 22-sep se publicó
seis veces sin preguntar. El propietario cambió la regla en vez de la costumbre.
**Tocar Cloudflare por su panel sigue necesitando permiso.**

### D-254 — La revisión integral

- **Se rescató lo que se perdió el 09-ago** al archivar el `PROMPT_MAESTRO_IA`:
  el papel (*Senior Tech Lead*) y los invariantes de construcción.
- **La lección más cara de septiembre ya estaba escrita el 19-jul**: *"los
  límites comerciales no se codifican como constantes en Flutter"*.
- **El Plan Maestro vuelve a mandar sobre el orden**, que desde el 07-sep lo
  dictaban los HANDOFF.
- **El guardián cuenta los hallazgos solo** (la Ñ no se contaba) y **falla si el
  código cita una decisión que no existe**.
- **Nada se borró**: lo rancio quedó rotulado como historia.

---

## 4. Tres correcciones del asistente el mismo día

Quedan escritas porque son el patrón, no para disculparse:

1. *"Solo archivo interno"* y *"Visible al cliente"* **no se contradicen**: una
   es el permiso y otra la visibilidad. **La lectura del propietario es justo el
   flujo del 9.48.**
2. **Las reseñas sí están en el portal**: *"Calificar servicios pendientes"*.
3. **El acceso de soporte a las fotos lo decidió el propietario** en D-076, con
   una condición que caduca con el primer cliente real (hallazgo **BC**).

> **La regla 1 existe. Lo que falló fue aplicarla antes de contestar, no después.**

---

## 5. Seis decisiones que son tuyas

Ninguna se resolvió por iniciativa propia (regla 20):

| | Qué | Por qué importa |
|---|---|---|
| **a** | **Aprobar el orden propuesto** de la Fase 9 | Sin aprobar, el orden vuelve a vivir en el HANDOFF |
| **b** | **El pago real de $4.500** con la sede de Éxito (9.8) | Es una excepción deliberada a *NO PAGAR NADA*, y la única forma de saber que cobrar funciona |
| **c** | **Cuándo pasar a Supabase Pro** | D-088 decía *cuando un negocio real cargue datos*; D-226 lo movió a *cuando pague*. Entre las dos caben 21 días de datos de terceros sin recuperación a un punto en el tiempo |
| **d** | **I-13**: acceso de lectura a la base para el asistente | Hoy cada lectura son varios comandos tuyos con la contraseña. Es acceso permanente a producción: por eso es tuyo |
| **e** | **El acceso de soporte a los datos de los salones** (BC) | D-076 caduca con el primer cliente real |
| **f** | **Las reglas 5 y 9** (*esperar confirmación* y *¿algo más antes de seguir?*) | Se cumplen menos de lo que dicen: la misma forma que D-253 resolvió con la 12 |

---

## 6. ⚠️ Lo que quedó a medias

1. ~~**La radiografía de la base no se ha corrido.**~~ ✅ **Corrida el 23-sep.**
   Lo sano: ninguna tabla sin RLS, ninguna función `security definer` sin
   `search_path`, 22 MB de 500. Lo que no: **BI**, **BG** y **BH**. Todo en la
   auditoría §5 y en el `MAPA_TECNICO` §1-bis.
   **Falta ver BI en pantalla:** entrar con la cuenta titular de **Naguara de Uñas**
   (Yelimar, es de prueba) → **Nueva cita** para hoy. Se espera el aviso de
   *"la prueba gratis… vencida"* mientras el panel de plataforma dice ACTIVO.
2. **Los letreros de D-252 no se han visto en pantalla.** Eran cuatro y la
   revisión encontró **un quinto** (*"la tarifa se pacta abajo"*), ya corregido.
   Panel de plataforma → **🏪 Salones Clientes** → **Naguara de Uñas** → tarjeta
   **3. Plan del negocio** → **Cambiar plan o etiqueta**.

---

## 7. Lo que NO hay que hacer

- 🔴 **NO pagar la suscripción de $150.000.** El pago de $4.500 del 9.8 es otra cosa, y es tuyo decidirlo.
- **NO borrar la Peluquería Éxito Prueba.** Es el banco de pruebas y su sede está en $4.500.
- **NO retirar `beautyos_calcular_cargo_epayco` ni `beautyos_procesar_evento_epayco`**: el webhook liquida con ellas.
- **NO reescribir los documentos rectores de julio**: llevan un *"Estado a 23-sep"* arriba y así se quedan, como los ADR.
- **NO contar hallazgos a mano**: la cifra la da `python scripts/verificar_documentos.py`.
- **NO empezar I-19 antes del 9.25**: la cadena es 9.24 → 9.25 → I-19.

---

## 8. Por dónde seguir

**El orden propuesto** (Plan Maestro, Fase 9), si lo apruebas:

| Turno | Qué |
|---|---|
| **A** | **Que el primer cobro funcione**: **BI** (vencer sin pagar) → 9.8 + 9.7 con $4.500 propios → 9.40 → AD → 9.9 |
| **B** | **Lo legal antes de datos de otra persona**: 9.20 (abogado) · 9.16 (contador) · **9.48** · BC · AS |
| **C** | **Lo que ve el cliente, barato**: **BG** · AV (incluida la página de precios) · BD · AR · AX · AN · AK · I-18 · 9.17 · 9.30 · AA · BH |
| **D** | **El campo**: 9.33 · 9.24 · **9.26 (Meta) ya, en paralelo** |
| **E** | **La estructura**: 9.25 → 9.13/9.14 → I-19 · 9.41 · AI |

**Estado de los hallazgos:** lo dice el guardián — **51 en total, 27 cerrados o decididos, 24 abiertos** (N Ñ Z AA AC AD AE AI AK AL AN AQ AR AS AT AU AV AX BB BC BD BG BH BI). *Antes de la radiografía eran 48 y 21.* *Hasta el 22-sep se reportaban 43 y 24: no se contaba la Ñ y cinco cerrados seguían sin marcar (BF)*.

---

## 9. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-253 y D-254).

Antes de tocar documentación: python scripts/verificar_documentos.py
(te dice además cuántos hallazgos hay abiertos: no los cuentes a mano)

DÓNDE ESTAMOS
El 23-sep se hizo una revisión integral. La documentación dice la verdad otra
vez. Para entender el sistema entero sin leer 254 decisiones:
docs/01_arquitectura/ARQUITECTURA_Y_EVOLUCION.md. Tu papel está en el
PLAN_MAESTRO §8: eres el Senior Tech Lead del proyecto.

LO PRIMERO
Hay seis decisiones pendientes del propietario (HANDOFF §5) y dos
verificaciones suyas en pantalla (§6: BI y los letreros). La principal:
aprobar el orden propuesto de la Fase 9. Su turno A empieza por BI -vencer
sin pagar no pasa a mora, y una sede que no paga no se corta nunca- y sigue
con un pago real de $4.500 para probar el único camino de cobro que queda,
que nunca ha cobrado un peso.

CÓMO SE TRABAJA CON ÉL
Va paso a paso y confirma cada uno antes del siguiente. No es técnico: hay
que decirle QUÉ hace, CÓMO y POR DÓNDE, con los nombres exactos de los
botones. Los comandos se le dan en bloques bash de una sola línea, y los
ejecuta él. Encuentra fallos reales probando. VERIFICA EN EL CÓDIGO ANTES DE
CONTESTARLE, no después: el 23-sep hubo que corregirse tres veces.

ANTES DE REESCRIBIR CUALQUIER FUNCION DE LA BASE
Extraer su texto vivo y compararlo linea por linea (D-119, D-122, D-123). El
repositorio NO es la fuente del esquema (hallazgo AI). Copiar los fixtures de
un control que ya funciona: no inventar nombres de tablas.

NO PAGAR la suscripción de $150.000. NO borrar la Peluqueria Exito Prueba.
NO retirar las funciones de cobro del negocio: el webhook liquida con ellas.
NO contar hallazgos a mano: lo hace el guardián.
```
