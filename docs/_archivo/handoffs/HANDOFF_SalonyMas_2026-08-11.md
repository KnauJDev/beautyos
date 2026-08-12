# HANDOFF Salón y Más — 11 de agosto de 2026

**Bloque documentado:** decisiones **D-129 a D-133** · 1 migración · 2 despliegues
**Estado:** todo aplicado y **verificado en producción por el propietario**
**Reemplaza como handoff vigente a:** `HANDOFF_SalonyMas_2026-08-10.md`

---

## 1. Dónde estamos

```
Fase 0  Que exista en internet        ✅
Fase 1  Que sea seguro compartirla    ✅
Fase 2  Seguridad                     🔄 6 de 7  ← AQUÍ
        2.1 Rotar claves              ✅
        2.2 Restauración de ensayo    ⬜ 👥 ← LO ÚNICO QUE FALTA
        2.3 Verificar Resend          ✅
        2.4 Almacenes                 ✅
        2.5 Negocio de prueba         ✅
        2.6 Pruebas de dinero y roles  ✅ (mitad; la otra espera a 2.2)
        2.7 send-low-stock-alert      ✅ CERRADO HOY
Fase 3  Poder cobrar                  🔄 3.1 ✅ · 3.12 ✅ CERRADO HOY · 3.13 nuevo
Fase 4  Pulido módulo a módulo        🔄 4.1 ✅
```

**A la Fase 2 le queda un solo paso: el 2.2.** Y desbloquea además la mitad
pendiente de H-03 (D-121), que hoy hay que correr a mano.

---

## 2. Qué pasó hoy

| # | Qué | Decisión |
|---|---|---|
| 1 | **Se rescataron los hallazgos R, S y T**, que una edición fallida había perdido, y se corrigió una afirmación falsa del handoff anterior | D-129 |
| 2 | **Barrido de siete decisiones habladas y nunca escritas** + tres contradicciones | D-130 |
| 3 | **`send-low-stock-alert` arreglada** (paso 2.7, hallazgo T) | D-131 |
| 4 | **Las reglas dejan de estar en seis sitios**, el registro estrena índice y nace el `MAPA_TECNICO` | D-131 |
| 5 | **Un estilista, una sola cuenta activa** (hallazgo R) | D-132 |
| 6 | **Los correos de cuenta salen por Resend** (paso 3.12) | D-133 |

**Todo verificado en producción por el propietario**, no solo aplicado.

---

## 3. Lo que cambió en cómo trabajamos

### La CLI de Supabase está conectada

El propietario la autorizó. **El asistente publica Edge Functions sin pedir
permiso** — se avisa, no se pregunta. Todo lo demás de Supabase sigue
necesitando permiso.

```
npx.cmd supabase@latest functions deploy <nombre> --project-ref eogppgbdnwxdtcbctaol --use-api --workdir C:\Proyectos\salonymas
```

**`npx.cmd`, no `npx`** — Windows bloquea los guiones de PowerShell.

### Las reglas viven en un solo sitio

**`PLAN_MAESTRO.md`, apartado 8.** Son 21. `AGENTS.md`, `CLAUDE.md`, `README` y
los HANDOFF apuntan ahí y **no las copian**. Estaban en seis sitios y ya
divergían.

### El mensaje de arranque es de tres líneas

```
Buenos días Claude. Retomo Salón y Más en C:\Proyectos\salonymas.

Lee el HANDOFF más reciente de docs/HANDOFF/ y el índice del principio de
docs/00_producto/REGISTRO_DE_DECISIONES.md. Las reglas están en el apartado 8
del PLAN_MAESTRO y no son negociables.

Hoy quiero: <lo que sea>
```

**El registro de decisiones tiene índice** desde hoy: 133 líneas al principio,
una por decisión. **Es una tabla de contenidos, no un resumen** — ninguna
entrada se tocó. Se lee el índice y se abren enteras solo las que hagan falta.
**Al añadir una decisión hay que añadir también su línea al índice.**

---

## 4. Lo que aprendimos hoy, y cuesta caro olvidarlo

### La más importante: un cambio a medio publicar parece un fallo de programación

El propietario probó la pantalla nueva, **no filtraba**, y el mensaje de error
nuevo **sí aparecía**. Parecía un cambio publicado y roto.

> **No lo estaba.** El mensaje venía de la migración, ya aplicada; la pantalla
> venía de un `main.dart.js` viejo. **La compilación de Cloudflare había fallado
> en 3 segundos y nadie avisó.**

**Cuando un cambio toca la base y la aplicación a la vez, verificar que se
publicó NO es mirar la pantalla.** Se comprueba en el código publicado:

```
curl -s https://salonymas.com/main.dart.js -o /tmp/pub.js
grep -c "algo_que_solo_exista_en_el_cambio_nuevo" /tmp/pub.js
```

`0` = lo publicado es la versión vieja, aunque GitHub tenga el commit.

### La segunda: un `push` correcto no publica nada por sí solo

El fallo fue `server certificate verification failed. CAfile: none` al
descargarse el código — **una avería de la máquina de Cloudflare, no del
proyecto**. Se arregla con **"Retry deployment"**. A la segunda salió en 2m57s.

### La tercera: ir a mirar antes de diseñar

Las dos mejores decisiones del día salieron de comprobar, no de razonar:

1. **No se construyó el "traslado de historial"** que se iba a construir,
   porque el historial **cuelga del estilista, no de la cuenta** — verificado en
   el esquema real. Ya funcionaba.
2. **No se tocó `get_stylists_summary`**, porque ampliarla obliga a recrearla y
   eso pierde sus permisos — **y el respaldo no los trae**. Inventarlos era
   repetir D-122.

---

## 5. Advertencias para quien siga

1. **`beautyos-dev` ES producción.** Es el único proyecto que existe.
2. **No hay base de pruebas.** Por eso existe el paso 2.2.
3. **Hay dos llaves de Resend y no son intercambiables:** `BeautyOS` la usan las
   Edge Functions; `SMTP Supabase Auth` es la contraseña del SMTP. Borrar la
   primera deja sin correo las invitaciones y las alarmas de stock.
4. **Los correos de cuenta están en inglés** (hallazgo W). Paso 3.13.
5. **Las dos Edge Functions se pueden ejecutar sin cuenta** (hallazgo U). Los
   datos no están expuestos; la cuota sí.
6. **No se puede dar acceso a una segunda sede** a quien ya tiene cuenta
   (hallazgo V). Importa antes de vender a un salón de varias sedes.
7. **El consecutivo de ticket no sirve como número contable** (hallazgo P).
8. **Ningún módulo se actualiza solo** (hallazgo Q).
9. **La prueba gratis del propietario vence.** Se extiende con
   `platform_extend_trial`.
10. **La cuenta duplicada `elboga010` queda suspendida, no borrada** — y así se
    queda: la base lo impide con `RESTRICT` y el proyecto no borra historial.

---

## 6. Cómo trabajamos

**Las 21 reglas están en `00_producto/PLAN_MAESTRO.md`, apartado 8.**
Aquí no se copian, y **ningún HANDOFF futuro debe volver a copiarlas** (D-131).

---

## 7. Estado técnico

- **Pruebas:** 95, en 11 archivos · `flutter analyze` limpio
- **Migraciones:** todas aplicadas, la última `20260811100000`
- **Edge Functions:** `send-invitation-email` v6 ✅ · `send-low-stock-alert` v6 ✅
- **Correo:** invitaciones, stock bajo **y correos de cuenta** salen por Resend
  desde `hola@salonymas.com`. Tope 30/hora
- **App publicada:** commit `d51324d`, verificado en el JavaScript servido
- **Respaldo:** del 11-ago, antes de la migración

---

## 8. Lo primero de la próxima sesión

| # | Qué | Por qué |
|---|---|---|
| 1 | **Paso 2.2 — restauración de ensayo** 👥 | Es lo único que le falta a la Fase 2, y desbloquea la mitad pendiente de H-03. **Un respaldo que nadie ha restaurado no es un respaldo: es una esperanza** |
| 2 | **Paso 3.13 — traducir los correos** 👥 | Es el primer correo que recibe la clienta, y está en inglés |
| 3 | Fase 3: 3.2 (contador), 3.3 (términos), 3.5 a 3.11 | El camino corto al primer cliente |

**Pendiente del propietario, sin fecha:** decidir si sale con precio de lista o
con precio pionero, y conseguir los primeros 25 salones.

---

## 9. Evidencia

- **6 commits**, de `8bbe3fd` a `d51324d` (más el cierre de hoy)
- **Decisiones D-129 a D-133** en `REGISTRO_DE_DECISIONES.md`
- **Hallazgos U, V y W** nuevos en el Plan Maestro, sección 7
- **Verificado en producción por el propietario:** el correo de stock bajo llegó
  tras un consumo interno real; los 7 controles del candado en verde con prueba
  de escritura; el correo de cuenta llegó desde `hola@salonymas.com` y el
  registro se completó; y el aviso de *"todos los estilistas ya tienen cuenta"*
  se vio funcionando en pantalla
