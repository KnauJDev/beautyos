# HANDOFF Salón y Más — 12 de agosto de 2026

**Bloque documentado:** decisiones **D-134 a D-137** · restauración de ensayo + pasos 3.5 y 3.6
**Estado:** todo verificado en producción por el propietario
**Reemplaza como handoff vigente a:** `HANDOFF_SalonyMas_2026-08-11.md`

---

## 1. Dónde estamos

```
Fase 0  Que exista en internet        ✅
Fase 1  Que sea seguro compartirla    ✅
Fase 2  Seguridad                     ✅ CERRADA HOY — 7 de 7
Fase 3  Poder cobrar                  🔄  ← AQUÍ
        3.1  ePayco admite recurrencia    ✅
        3.5  Precios y límites            ✅ CERRADO HOY
        3.6  Precio por cliente           ✅ CERRADO HOY
        3.12 Correos de cuenta por Resend ✅
        3.7  Filtro de aceptación         ⬜ 🤖  ← LO SIGUIENTE
        3.8–3.11  Planes públicos, ePayco, avisos  ⬜ 🤖
        3.2  Contador (DIAN, IVA)         ⬜ 👤
        3.3  Términos y privacidad        ⬜ 👥  Ley 1581, obligatorio
        3.4  Supabase Pro (~25 USD/mes)   ⬜ 👤
        3.13 Traducir los correos         ⬜ 👥  hallazgo W
Fase 4  Pulido módulo a módulo        🔄 4.1 ✅
```

**La Fase 3 es el camino corto al primer cliente.** No queda nada bloqueando.

---

## 2. Antes de nada: qué hay realmente dentro de la base

**Esto se malinterpretó tres veces el 12-ago. Está en `MAPA_TECNICO.md`
apartado 1-bis, y se resume aquí porque cambia cómo se trata todo:**

> **La BASE es producción de verdad** — es la única que existe y sirve la app
> publicada. **Los DATOS son sembrados** — el único negocio es "Naguara de
> Uñas", que es del propietario, está marcado `is_demo` (D-120), y sus 703
> tickets y 36 clientas los sembró el asistente (D-112). **No hay una sola
> persona real ahí dentro.**
>
> **"De prueba" describe los datos, no la base.**

**El día que entre el primer cliente real, eso cambia de golpe.** La lista de
qué cambia está en `MAPA_TECNICO`, 1-bis. Consúltala ese día.

---

## 3. Qué pasó hoy

| Qué | Decisión |
|---|---|
| **Paso 2.2 cerrado: restauración de ensayo hecha y verificada** | D-134 |
| **El respaldo llevaba 4 días sin servir** (hallazgo Y) — corregido | D-134 |
| **Hallazgo Z:** `storage.objects` no vuelve al restaurar | D-134 |
| **Queda escrito qué hay en la base y qué cambia el día 1** | D-135 |
| **Pasos 3.5 y 3.6: la máquina de cobrar** — precios, límites y precio por cliente | D-136 |
| **Se aplaza a propósito la matriz de los planes** (idea I-14) | D-136 |
| **Tres reglas nuevas para cuando trabaja más de un asistente** | D-137 |

### Los pasos 3.5 y 3.6, en corto

**Ya se puede cobrar.** Precios en **pesos** (160/200/240 mil), la columna
renombrada a `price_cop` para que nadie lea centavos donde hay pesos, y **las
dos capacidades que no existían**: sedes y cuentas de equipo. Sin ellas no se
podía ni escribir *"3 sedes pero 25 cuentas"* — que es justo lo que el
propietario quiere poder negociar. **Y se hacen cumplir**: antes `create_branch`
no tenía **ni una sola** comprobación de límite.

La suscripción admite **precio propio o descuento con fecha de fin**, con motivo
obligatorio. **El pionero es un descuento sin fecha de fin**: 50% mientras siga
activo.

### Lo que NO se decidió, y es deliberado

**Qué módulo lleva cada plan.** El propietario no está decidido y tiene una idea
que lo cambiaría: fotos visibles en el Básico, Instagram en el Profesional.

> **Se aplazó con argumento:** si hoy se mueven las fotos al Básico, **el
> Profesional se queda sin nada exclusivo que exista** — Instagram y la IA son
> Fase 6. La matriz son 15 casillas: una instrucción hoy, un clic en la Fase 7.
> **Se decide después de las primeras cinco visitas a salones reales.**

Está anotado como **I-14**, con la discrepancia entre la imagen que él maneja
(10 filas) y este plan (12).

### El resultado del ensayo, en una línea

**36 de 37 cifras idénticas** entre producción y la copia restaurada. Las cinco
sumas de dinero cuadran **al peso** ($67.630.000 en pagos), y los números de
ticket llegaron intactos del **0000001 al 0000703**.

### Lo que encontró, que es el motivo de que el paso existiera

**`respaldo_supabase.ps1` no incluía el esquema `private`** desde el 08-ago.
Ahí viven las **18 funciones que autorizan cada operación** del negocio.
Restaurar ese respaldo habría devuelto todos los datos **con la aplicación
inutilizada**: ni agenda, ni cobrar, ni fotos.

**Y era invisible:** el respaldo se creaba sin un solo error, con su
verificación en verde, todos los días. **El fallo era una ausencia, no un
error.** Solo se ve restaurando.

---

## 4. Lo que aprendimos, y cuesta caro olvidarlo

### Verificar que un proceso termina bien no es verificar que sirve

**Tercera vez en cuatro días con la misma forma:**

| Cuándo | Qué parecía | Qué era |
|---|---|---|
| D-122 | Los permisos estaban puestos | Faltaba uno, y solo se vio usando la app |
| D-133 | La pantalla estaba publicada | Cloudflare había fallado y nadie avisó |
| **D-134** | **El respaldo se creaba perfecto** | **No servía para reconstruir nada** |

### Los números demasiado limpios son más sospechosos que los feos

El guion informó **"0 errores"** habiendo **364**. Se descubrió porque el cero
contradecía lo que se había visto un minuto antes. **Si un resultado sale mejor
de lo que la experiencia dice, hay que dudarlo antes de celebrarlo.**

### Un dato que hay que redescubrir para trabajar, se pierde cada sesión

El asistente advirtió tres veces sobre "datos reales de clientas" que no
existen. La información estaba escrita — en D-112 y D-120 — pero en el registro
de decisiones, que guarda **porqués**, no en el mapa técnico, que responde
**cómo está esto hoy** (D-135).

---

## 5. Advertencias para quien siga

1. **`beautyos-dev` ES producción.** Y ahora existe `salonymas-ensayo`
   (`aljnxvewqyxyfooarnte`), que **no lo es** y puede pausarse o borrarse.
2. **Si se crea un esquema nuevo, hay que añadirlo a la lista de esquemas de
   `respaldo_supabase.ps1` en el mismo cambio.** Un esquema que no esté ahí no
   existe para el respaldo, y nadie se entera hasta el día que haga falta.
3. **Al restaurar, `storage.objects` vuelve a 0** (hallazgo Z). Las fotos se
   recuperan de `respaldo_archivos.ps1`; `public.work_photos` conserva a qué
   ticket, cliente y estilista pertenece cada una.
4. **Los correos de cuenta están en inglés** (hallazgo W). Paso 3.13.
5. **Las dos Edge Functions se ejecutan sin cuenta** (hallazgo U). Datos
   protegidos; cuota no.
6. **No se puede dar acceso a una segunda sede** a quien ya tiene cuenta
   (hallazgo V). Importa antes de vender a un salón de varias sedes.
7. **Hay dos llaves de Resend y no son intercambiables** (`CORREO_Y_DOMINIO`).
8. **El consecutivo de ticket no sirve como número contable** (hallazgo P), y
   **ningún módulo se actualiza solo** (hallazgo Q).
9. **La prueba gratis del propietario vence.** `platform_extend_trial`.
10. **La contraseña de la base nunca se ha rotado** (hallazgo X). Higiene, no
    incendio.

---

## 6. Cómo trabajamos

**Las reglas de trabajo están en `00_producto/PLAN_MAESTRO.md`, apartado 8.**
Aquí no se copian, y ningún HANDOFF futuro debe volver a copiarlas (D-131).

---

## 7. Estado técnico

- **Pruebas:** 95, en 11 archivos · `flutter analyze` limpio
- **Migraciones:** todas aplicadas, la última `20260812100000`
- **Edge Functions:** las dos en v6, funcionando
- **Correo:** invitaciones, stock bajo y correos de cuenta salen por Resend
  desde `hola@salonymas.com`. Tope 30/hora
- **App publicada:** commit `d51324d`, verificado en el JavaScript servido
- **Respaldo:** `Backup_2026-08-12_05-11-22`, **ya con el esquema `private`**,
  restaurado y verificado
- **Proyectos Supabase:** `beautyos-dev` (producción) y `salonymas-ensayo`

---

## 8. Lo primero de la próxima sesión

**La Fase 3 no tiene un orden obligado.** Recomendación, por lo que desbloquea:

| # | Qué | Por qué |
|---|---|---|
| 1 | **3.7 — filtro de aceptación** 🤖 | *"Nadie entra solo"* (D-125). **Es donde se usa lo que se construyó hoy**: al aprobar un salón se le asigna precio o descuento. Sin esto, cualquiera se registra y entra |
| 2 | **3.3** — términos y privacidad 👥 | **Obligatorio por ley** antes del primer cliente |
| 3 | **3.13** — traducir los correos 👥 | 30 minutos, y es el primer correo que ve la clienta |
| 4 | **3.2 y 3.4** — contador y Supabase Pro 👤 | Dependen de terceros; conviene arrancarlos ya en paralelo |
| 5 | **I-14** — la matriz de los planes 👤 | **Después de las primeras cinco visitas**, no antes |

**Pendiente del propietario, sin fecha:** decidir si sale con precio de lista o
con precio pionero, y conseguir los primeros 25 salones.

---

## 9. Si quien retoma es una IA distinta

**Esto es lo mínimo que necesita saber alguien que llega sin historia.** No
sustituye a leer los tres documentos: los enumera y avisa de lo que muerde.

### Los tres documentos, y qué manda cada uno

| Documento | Responde | Regla |
|---|---|---|
| **`docs/HANDOFF/`** (el más reciente) | ¿Dónde quedamos? | Se reemplaza cada sesión |
| **`docs/00_producto/PLAN_MAESTRO.md`** | ¿Qué falta y en qué orden? | **El único que manda sobre el plan** |
| **`docs/00_producto/REGISTRO_DE_DECISIONES.md`** | ¿Por qué está hecho así? | **Solo crece.** Nunca se resume ni se borra una fila. Tiene un **índice** al principio: léelo entero y abre solo las decisiones que necesites |

**Si aparece un cuarto documento opinando sobre el plan, está mal.** Siete
compitiendo causaron dos desviaciones reales (D-063, D-118).

**Y dos de apoyo que se leen antes de hacer algo, no para saber qué hacer:**
`02_operacion/MAPA_TECNICO.md` (dónde está cada cosa, cómo se publica, **las
trampas que ya mordieron**) y `02_operacion/CORREO_Y_DOMINIO.md`.

### Lo que no es obvio y cuesta caro

1. **`beautyos-dev` ES el proyecto de producción.** Es el único que existe. El
   nombre ya hizo archivar un hallazgo falso dos veces.
2. **La base es producción; los datos son sembrados.** El único negocio es del
   propietario y está marcado de prueba. Lee `MAPA_TECNICO` apartado **1-bis**,
   que incluye **qué cambia el día que entre el primer cliente real**.
3. **El propietario no es técnico.** Explícale el porqué, no solo el qué, en
   español claro. **Él prueba en producción y reporta** — y así encontró la
   mayoría de los fallos que ninguna prueba automática vio.
4. **Las migraciones las aplica él**, con
   `powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" -Archivo "<ruta>"`.
   Van dentro de `begin/commit`: si algo falla, no se aplica nada.
5. **Respaldar antes de cualquier migración**, con `scripts\respaldo_supabase.ps1`.
6. **Las Edge Functions no salen del repositorio.** Un `push` no las publica.

### Las cinco reglas de método que salieron de fallos reales

Están completas en el **apartado 8 del Plan Maestro** (son 21). Estas cinco son
las que más caro salieron:

1. **Verificar en el código antes de afirmar.** Adivinar nombres de tablas y
   columnas ya causó fallos reales.
2. **Al reescribir una función, compararla línea por línea contra la
   original**, no solo la firma. Tres fallos en un mismo día salieron de ahí
   (D-119, D-122, D-123).
3. **Al borrar una función, sus permisos se pierden — y el respaldo no los
   trae.** Cópialos antes y repónlos. Reinventarlos rompió la app una vez
   (D-122) y casi rompe la página pública de precios otra (D-136).
4. **Que un proceso termine sin errores no prueba que sirva.** El respaldo se
   creaba perfecto y no servía para reconstruir nada (D-134). Un `push`
   correcto no publicó la app (D-133). **Verifica el resultado, no el proceso.**
5. **Toda edición documental comprueba que su ancla existe ANTES y que el texto
   quedó escrito DESPUÉS** — y no se afirma en un commit que algo quedó escrito
   sin haberlo comprobado (D-129).

### Y tres reglas que son para ti en concreto

**Desde el 12-ago el proyecto lo puede tocar más de un asistente** (D-137). El
riesgo no es equivocarse: es **trabajar sin verse**. Están completas en el
apartado 8 del Plan Maestro, reglas **22 a 24**:

1. **Quien construye es quien registra**, en el mismo cambio: la decisión con
   su porqué, su línea en el índice, el Plan Maestro y el HANDOFF. **Lo que no
   está escrito no existe**, porque el siguiente no tiene cómo saberlo.
2. **Un solo HANDOFF vigente.** Se reemplaza, nunca se duplica: lee el que hay
   y archiva el anterior en `_archivo/handoffs/`.
3. **Antes de proponer nada, mira si el repositorio avanzó sin que el HANDOFF
   lo cuente.** Si hay commits posteriores al último HANDOFF, **otro asistente
   trabajó**: lee ese `git log` y cierra el hueco antes de tocar nada.

### El prompt para arrancar

```
Voy a trabajar contigo en Salón y Más, una SaaS para salones de estética en
Colombia, en C:\Proyectos\salonymas. No soy técnico: explícame el porqué de
las cosas, no solo el qué, en español claro.

Antes de proponer nada, lee en este orden:
1. docs/HANDOFF/ — el más reciente por fecha. Dónde quedamos.
2. docs/00_producto/PLAN_MAESTRO.md — el único que manda sobre qué falta y en
   qué orden. Sus reglas de trabajo están en el apartado 8 y no son
   negociables.
3. El índice del principio de docs/00_producto/REGISTRO_DE_DECISIONES.md, y
   abre enteras solo las decisiones que necesites.
4. docs/02_operacion/MAPA_TECNICO.md — dónde está cada cosa, cómo se publica,
   y las trampas que ya nos costaron tiempo.

No empieces por el código: hay más de 136 decisiones registradas con su
porqué, y leerlo sin ellas es reconstruir a ciegas razonamientos que ya están
escritos.

Cuando termines de leer, dime en pocas líneas dónde estamos y cuál es el
siguiente paso según el Plan Maestro, y espera mi confirmación antes de
construir nada.
```

---

## 10. Evidencia

- **Decisiones D-134 y D-135** en `REGISTRO_DE_DECISIONES.md` (135 en total)
- **Hallazgos Y y Z** nuevos en el Plan Maestro, sección 7; **Y cerrado** el
  mismo día
- **`MAPA_TECNICO.md` apartado 1-bis**: qué hay en la base y qué cambia el día
  del primer cliente
- **`RESPALDO_Y_RESTAURACION_SUPABASE.md`**: procedimiento de ensayo, en 5
  pasos, con las diferencias que son normales
- **Verificado por el propietario:** respaldo creado, ensayo restaurado, censo
  comparado. 36 de 37 cifras idénticas
