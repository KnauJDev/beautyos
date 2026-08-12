# HANDOFF Salón y Más — 12 de agosto de 2026

**Bloque documentado:** decisiones **D-134 y D-135** · restauración de ensayo
**Estado:** todo verificado en producción por el propietario
**Reemplaza como handoff vigente a:** `HANDOFF_SalonyMas_2026-08-11.md`

---

## 1. Dónde estamos

```
Fase 0  Que exista en internet        ✅
Fase 1  Que sea seguro compartirla    ✅
Fase 2  Seguridad                     ✅ CERRADA HOY — 7 de 7
Fase 3  Poder cobrar                  🔄  ← AQUÍ EMPIEZA LO SIGUIENTE
        3.1  ePayco admite recurrencia    ✅
        3.12 Correos de cuenta por Resend ✅
        3.2  Contador (DIAN, IVA)         ⬜ 👤
        3.3  Términos y privacidad        ⬜ 👥  Ley 1581, obligatorio
        3.4  Supabase Pro (~25 USD/mes)   ⬜ 👤
        3.5–3.11  Planes, precios, filtro, ePayco, avisos  ⬜ 🤖
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

**Las 21 reglas están en `00_producto/PLAN_MAESTRO.md`, apartado 8.**
Aquí no se copian, y ningún HANDOFF futuro debe volver a copiarlas (D-131).

---

## 7. Estado técnico

- **Pruebas:** 95, en 11 archivos · `flutter analyze` limpio
- **Migraciones:** todas aplicadas, la última `20260811100000`
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

| # | Qué | Por qué primero |
|---|---|---|
| 1 | **3.5 y 3.6** — cargar planes, precios y límites; precio y descuento por cliente 🤖 | Es lo único de la fase que **no depende de nadie externo**. Se puede hacer entero hoy |
| 2 | **3.7** — filtro de aceptación 🤖 | *"Nadie entra solo"* (D-125). Sin esto no hay forma de aprobar un salón |
| 3 | **3.3** — términos y privacidad 👥 | **Obligatorio por ley** antes del primer cliente |
| 4 | **3.13** — traducir los correos 👥 | 30 minutos, y es el primer correo que ve la clienta |
| 5 | **3.2 y 3.4** — contador y Supabase Pro 👤 | Dependen de terceros; conviene arrancarlos ya en paralelo |

**Pendiente del propietario, sin fecha:** decidir si sale con precio de lista o
con precio pionero, y conseguir los primeros 25 salones.

---

## 9. Evidencia

- **Decisiones D-134 y D-135** en `REGISTRO_DE_DECISIONES.md` (135 en total)
- **Hallazgos Y y Z** nuevos en el Plan Maestro, sección 7; **Y cerrado** el
  mismo día
- **`MAPA_TECNICO.md` apartado 1-bis**: qué hay en la base y qué cambia el día
  del primer cliente
- **`RESPALDO_Y_RESTAURACION_SUPABASE.md`**: procedimiento de ensayo, en 5
  pasos, con las diferencias que son normales
- **Verificado por el propietario:** respaldo creado, ensayo restaurado, censo
  comparado. 36 de 37 cifras idénticas
