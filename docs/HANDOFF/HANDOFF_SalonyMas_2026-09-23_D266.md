# HANDOFF Salón y Más — 23 de septiembre de 2026, noche ("El ciclo del cobro, completo", D-255 a D-267)

**Bloque documentado:** decisiones **D-255** a **D-267**. Por la tarde, cerrando
hallazgos con permiso del propietario mientras descansaba (D-255 a D-259). Por la
noche, con él presente: sus decisiones, la **regla 25** y **cinco migraciones
aplicadas por él**, todas con su control en verde.

**Estado:** ✅ Todo publicado y aplicado. **Nada escrito queda sin aplicar.**
`flutter analyze` **0/0** · **489 pruebas** · Guardián en verde · CI en verde.
**Hallazgos: 57 en total, 40 cerrados o decididos, 17 abiertos** (los cuenta el guardián; esta mañana eran 51 y 24).

> El HANDOFF anterior está en `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-23_D259.md`.

---

## 1. Lo que hay que saber si solo se lee una cosa

**El ciclo entero de una sede que no paga funciona en la base y se ve en la
pantalla.** Esta mañana no funcionaba ni la mitad:

| Momento | Qué pasa | Decisión |
|---|---|---|
| Vence el mes pagado | Al día siguiente, a las 07:50, pasa a **mora con 5 días de gracia**. Sigue agendando | D-258 |
| Paga dentro de la gracia | Paga **el mes completo**, y la fecha de corte no se corre | D-265 |
| No paga en la gracia | Queda **suspendida**: **no agenda citas nuevas**; lo agendado se atiende y se cobra; las demás sedes siguen | D-261 |
| Lo ve el salón | La cabecera y *Tus sedes* dicen en qué estado está y llevan a pagar | D-255, D-262 |

**Y el primer cobro real (paso 9.8) ya no chocará contra un mínimo:** la sede de
la Peluquería Éxito estaba en $4.500 y la activación exige $10.000. **El cobro
mínimo de una sede es $10.000** (decisión del propietario): Éxito subió a
$10.000, y ninguna puerta deja pactar por debajo.

---

## 2. Qué se decidió hoy (el propietario)

| | Decisión | Dónde |
|---|---|---|
| 1 | **Una sede suspendida no agenda citas nuevas**; hereda del negocio la gracia, la suspensión y la fecha de corte, **no** el precio ni los módulos | D-260 |
| 2 | **La gracia de 5 días es solo de los meses pagados**, no de la prueba | D-263 |
| 3 | **Pagar en la gracia cobra el mes completo** | D-264 |
| 4 | **El cobro mínimo de una sede es $10.000** | D-265 |
| 5 | **El estilista NO agenda**, para que no pueda llevarse la base de clientas. Si trae a alguien, comparte el enlace del salón o la reserva pública | D-266 (revierte D-263) |
| 6 | **La foto se toma con la clienta presente y de acuerdo; publicarla lo autoriza solo ella**, desde el enlace que se le envía | D-260 |
| 7 | **La regla 25** (Plan Maestro §8): afirmar exige prueba; lo aprobado no se cambia sin avisar; el producto se pregunta aunque haya permiso general; lo que corre el propietario se copia de algo que ya funcionó; un letrero rancio se busca por lo que llama | D-260 |

---

## 3. Las migraciones de hoy, todas aplicadas

| Migración | Control | Qué hace |
|---|---|---|
| `20260923120000_vencer_sin_pagar_pasa_a_mora_bi` | 222: 10/10 | Mora por fecha con 5 días de gracia; tarea diaria 07:50 |
| `20260923130000_una_sola_register_tenant_y_permisos_de_private_bg_bh` | 223: 5/5 | Una sola `register_tenant`; nada de `private` para `anon` |
| `20260923150000_la_sede_suspendida_no_agenda_bi` | 224: 9/9 | La sede suspendida no agenda; el candado dice el motivo real |
| `20260923170000_las_tildes_de_corregir_servicio_bl` | 225: 4/4 | Las tildes de *Corregir un servicio finalizado* |
| `20260923190000_la_gracia_se_cobra_y_el_cobro_minimo_bn_bo` | 226: 7/7 | Mes completo en la gracia; cobro mínimo $10.000 |

**Todas se escribieron desde el texto vivo de la base**, leído antes con una
`intervenciones/extraer_*.sql`, y generadas por un guion que aplica solo los
cambios queridos. Es la regla 10 hecha método: la diferencia con lo vivo se midió
antes de aplicar (una línea sale y nueve entran, por ejemplo).

---

## 4. Lo que tienes que mirar en pantalla (regla 21)

Pulsa **Actualizar** en el aviso de versión nueva primero. **No pagues nada.**

1. ✅ **Verificado por ti el 23-sep:** píldora **ámbar**, *"5 días de gracia · Pagar"*, y *Tus sedes* con las dos sedes en *Pago vencido*. **El 28-sep**, si no se paga, la píldora pasará a roja: *"Suspendido por falta de pago · Pagar"*.
2. **Configuración → Tus sedes (Naguara):** la sede dice **Pago vencido**, con un botón para pagarla.
3. **Nueva cita en Naguara:** te deja crearla, porque está en su gracia. Y la reserva en línea también (ya lo viste).
4. **Configuración → la tarjeta con el nombre de tu sede → Editar:** pon un correo **sin arroba** y pulsa Guardar. El formulario **no se cierra**, y el error sale **debajo del correo**.
5. **Panel de plataforma:** la píldora **En Prueba** dice **(0)**; Naguara dice **PAGO PENDIENTE**; en la ficha de Éxito, su sede dice **$10.000**.
6. **La página pública de precios** (`salonymas.com/?planes=1`): con tildes, y las preguntas empiezan por **¿**.
7. **Nueva cita → Crear cliente rápido** con el celular de una clienta que ya existe: el diálogo **se queda abierto** con el aviso dentro.

---

## 5. Las decisiones que siguen siendo tuyas

| | Qué | Por qué importa |
|---|---|---|
| ~~a~~ | ~~Aprobar el orden de la Fase 9~~ | ✅ **Aprobado** (D-268), con método: paso a paso, confirmado por él antes de cerrar |
| **b** | **El pago real del 9.8, de $10.000**, con la sede de Éxito | **No hay que cambiar nada**: la sede ya está en $10.000 (D-265). Antes de pagar, mira qué botón enseña *Tus sedes* de Éxito. Recae en tu propia cuenta; pagas impuestos y comisión |
| **c** | **Cuándo pasar a Supabase Pro** | D-088 decía *cuando cargue datos*, D-226 *cuando pague* |
| **d** | **I-13**: acceso de lectura a la base para el asistente | Hoy cada lectura es un comando tuyo con contraseña: hoy fueron cinco |
| ~~e~~ | ~~El acceso de soporte a los datos de los salones~~ | ✅ **Se queda igual para siempre** (D-277): sin solicitud, motivo, vencimiento ni registro |
| **h** | **Las fotos: ¿quitamos los tipos *Final* y *Portafolio*?** | Lo decía el hallazgo Ñ, y ya definiste el flujo |
| ~~o~~ | ~~¿Aviso en *Mi agenda* con el enlace de reservas?~~ | ✅ **Aprobado y construido** (D-267): *"¿Tienes una clienta nueva?"*, con WhatsApp y Copiar |
| ~~p~~ | ~~¿Quién ve el pago de cada sede?~~ | ✅ **El dueño ve todas y paga cada una por su sede; cada administrador, solo la suya** (D-268, hallazgo BP). Va después del 9.8 |

---

## 6. Lo que quedó a medias

1. **AK — seis diálogos en `tickets_page.dart`** (agregar, cambiar y quitar servicio; reprogramar; cambiar estado; corregir) todavía se cierran antes de guardar. Van con el **9.13**, porque son flujos de caja.
2. **AQ y Ñ** — publicar una foto lo autoriza solo la clienta desde su enlace (decidido); hoy la casilla del salón todavía la habilita. Construir esa aprobación es el **9.48**.
3. **AL** — queda la plantilla de correo del empleado invitado, que se ajusta en Supabase.
4. ✅ **La tarjeta del estilista** (D-267): vista por el propietario en *Mi agenda* de Erick.

---

## 7. Lo que NO hay que hacer

- 🔴 **NO pagar nada** hasta decidir la **b**. Tampoco los botones de pagar de Naguara.
- **NO borrar la Peluquería Éxito Prueba.** Es el banco de pruebas, y su sede está en $10.000 para el 9.8.
- **NO pactar una sede por debajo de $10.000**: la base lo niega a propósito (D-265).
- **NO retirar `beautyos_calcular_cargo_epayco` ni `beautyos_procesar_evento_epayco`**: el webhook liquida con ellas.
- **NO reescribir una función de la base sin su lectura viva**: hoy hubo cinco, y las cinco salieron a la primera por eso.
- **NO arreglar los seis diálogos de Tickets sueltos**: van con el 9.13.
- **NO contar hallazgos a mano**: `python scripts/verificar_documentos.py`.

---

## 8. Por dónde seguir

1. ✅ **El turno A quedó cerrado el 23/24-sep** (D-262, D-272, D-274). Sigue el **turno B**: **BC (D-275)** — falta aplicar su migración —, **AS**, **9.48** (en construcción), **9.20** (documento para el abogado ya publicado) y **9.16** (aplazado por el propietario hasta que empiece a facturar).
2. **AK** con el 9.13, y **9.48** siguiendo su curso.

---

## 9. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-255 a D-266).

Antes de nada: la REGLA 25 del PLAN_MAESTRO §8. Afirmar exige prueba; lo
aprobado no se cambia sin avisar; el producto se pregunta aunque haya
permiso general; lo que corre el propietario se copia de algo que ya
funcionó; un letrero rancio se busca por lo que llama.

Y: python scripts/verificar_documentos.py (cuenta los hallazgos por ti).

DÓNDE ESTAMOS
El 23-sep quedó completo el ciclo de una sede que no paga: mora con 5 días
de gracia, mes completo si paga en la gracia, suspensión sin citas nuevas,
y la pantalla lo dice. El cobro mínimo de una sede es $10.000 y nadie pacta
por debajo. El estilista NO agenda (decisión del propietario). Cinco
migraciones aplicadas, controles 222 a 226 en verde. Nada queda sin aplicar.

LO PRIMERO
Preguntarle por las verificaciones en pantalla (HANDOFF §4) y por sus
decisiones (§5): la principal, aprobar el orden de la Fase 9 y el pago real
de $10.000 del paso 9.8.

CÓMO SE TRABAJA CON ÉL
Paso a paso, en español claro y con los nombres exactos de los botones. Los
comandos van en bloques bash de una sola línea y los ejecuta él.
ANTES DE REESCRIBIR UNA FUNCIÓN DE LA BASE: una lectura en
intervenciones/extraer_*.sql, y la migración GENERADA desde ese texto vivo,
midiendo la diferencia antes de aplicar. Controles que EJECUTAN el camino,
con fixtures copiados de un control que ya funciona (el 218, el 224, el 226).

NO PAGAR NADA sin su decisión b. NO borrar la Peluquería Éxito Prueba. NO
pactar una sede por debajo de $10.000. NO contar hallazgos a mano.
```
