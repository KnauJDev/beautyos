# HANDOFF Salón y Más — 9 de agosto de 2026

**Bloque documentado:** decisiones **D-116 a D-121** · 8 commits · 3 migraciones
**Estado:** todo aplicado y verificado en producción, salvo una prueba de interfaz
**Versión publicada:** `d8c556f` · `https://salonymas.com`
**Reemplaza como handoff vigente a:** `HANDOFF_SalonyMas_2026-08-08.md`

---

## 1. Qué pasó en esta sesión

Se cerraron **2.6a** y **las tres acciones de la Etapa A que le tocaban al
asistente** (A4, A5, A6). Pero lo importante no fue el código:

1. **El propietario detectó que se estaba trabajando en la Etapa B con la
   Etapa A intacta**, y tenía razón. La causa no fue distracción: **cuatro
   documentos decían tres cosas distintas** sobre cuándo va la seguridad. Se
   corrigió dejando escrito quién manda sobre el orden.
2. **Frenó una fusión que ya estaba decidida** (D-105) y **corrigió una
   propuesta mía sobre las fotos** que habría estorbado su propia hoja de ruta.
   Las dos veces tenía razón, y las dos quedaron registradas con el porqué.
3. **Detectó que el consecutivo de ticket no sirve como número contable**
   mirando sus propios datos: una cita de diciembre ya tenía número.
4. **Se hizo el repaso completo** de las 118 decisiones y la auditoría integral,
   que destapó un hallazgo que yo mismo había anotado mal esa misma mañana.

---

## 2. Lo que quedó construido

| Qué | Dónde |
|---|---|
| **Número de ticket consecutivo y ajustable** — arranca en `0000001`, se puede fijar para seguir una numeración propia o DIAN | D-117 |
| **Las fotos de trabajo nacen privadas**; aprobarlas es lo que las publica, con dirección permanente | D-119 |
| **Papelera para borrar fotos** y borrado del archivo viejo al reemplazar logo o portada | D-119 |
| **Negocio de prueba marcado**, con insignia en el panel de plataforma | D-120 |
| **Primeras pruebas de dinero y de roles** — 16 en Dart y un guion SQL con `ROLLBACK` | D-121 |
| **`scripts/aplicar_sql.ps1`** para ejecutar migraciones sin romper la contraseña | — |

**Pruebas:** 89, en 10 archivos (eran 70) · `flutter analyze` limpio.

---

## 3. La corrección de rumbo más importante

> **Manda `PLAN_DE_TRABAJO_A_PRODUCCION.xlsx` sobre el ORDEN de ejecución.**
> El plan de lanzamiento manda sobre el **qué** y el **por qué**.

Se escribió porque el apartado 11-J del plan ponía el barrido de seguridad *"al
cerrar la Etapa 2"* mientras la hoja del propietario lo pone **antes**. Es la
reaparición del problema que D-063 quiso cerrar hace dos semanas.

**Ante cualquier duda de orden: manda la hoja.**

---

## 4. Dónde estamos, de verdad

```
Etapa 0  Que exista en internet        ✅ CERRADA
Etapa 1  Que sea seguro compartirla    ✅ CERRADA
Etapa A  Seguridad y red de protección 🔄 AQUÍ  (3 de 6)
         A1 Rotar claves               ⬜ 👥 ← el que desbloquea lo demás
         A2 Restauración de ensayo     ⬜ 👥
         A3 Verificar Resend           ⬜ 👥
         A4 Cerrar almacenes           ✅
         A5 Negocio de prueba          ✅
         A6 Pruebas de dinero y roles  ✅ a medias, espera a A2
Etapa B  Pulido visual (Etapa 2)       🔄 2.6a ✅ · 2.6b y 2.6c ⬜
Etapa C  El enlace propio              ⬜
Etapa D  Cobrar                        ⬜
Etapa E  Limpieza técnica              ⬜
```

**Lo que falta de la Etapa A es todo del propietario.** A1 además decide si el
asistente puede aplicar migraciones por su cuenta: dar acceso con unas claves
que ya sabemos expuestas (H-04) sería hacerlo al revés.

---

## 5. Lo único que quedó pendiente de esta sesión

**Una prueba de interfaz que solo puede hacer el propietario:** subir una foto,
aprobarla, retirarle la aprobación y borrarla con la papelera. La mitad de base
de datos está verificada (8 controles en verde); lo que falta es comprobar que
la pantalla se comporta.

Antes de esta sesión, subir una foto fallaba con `Bucket not found` porque el
código nuevo ya estaba publicado y la migración no. **Ya está aplicada.**

---

## 6. Lo que bloquea de verdad

| Qué | Quién |
|---|---|
| **Definir los 3 precios** | 👤 **Marca la fecha de salida** |
| **A1 — Rotar claves de Supabase (H-04)** | 👥 Abierto desde el 03-ago |
| A2 — Restaurar un respaldo de ensayo | 👥 **Y desbloquea la otra mitad de A6** |
| A3 — Verificar Resend: hoy las invitaciones no llegan a nadie | 👥 |

---

## 7. Cómo trabajamos — método acordado

- **Verifica en el código antes de afirmar. No asumas.**
- **Antes de construir, di en dos líneas qué vas a hacer y por qué, y espera
  confirmación.**
- Cuando haya varios puntos que plantear, repetirlos en una lista para
  confirmar que se entendieron **antes** de empezar a resolver.
- Preguntar *"¿algo más antes de seguir?"* antes de cerrar cada bloque.
- **Registrar cada decisión con su porqué**, incluyendo lo que se descartó.
- **Regla de hallazgos:** lo que aparezca se anota y se ataca donde le
  corresponde. Si no cabe, va al apartado 11.
- **Pedir permiso antes de tocar Supabase, Cloudflare o hacer push.**
- **Cualquier instalación en el computador del propietario la ejecuta él.**
- **Respaldar antes de cada sesión con migraciones.**
- El propietario prueba en producción y reporta; el asistente no ve la interfaz.

---

## 8. Advertencias para quien siga

1. **El consecutivo de ticket NO sirve como número contable** (hallazgo P). Se
   asigna al crear, así que no sigue el orden de las ventas, las canceladas
   queman números y lo que nunca se cobra también se lleva uno. **Se arregla en
   2.6** separándolo en dos: número de ticket (operativo) y número de venta
   (al cerrar). No empeora por esperar: `ticket_history` guarda cada cambio de
   estado, así que los números de venta se pueden asignar hacia atrás.
2. **Al borrar la semilla de ensayo, el primer ticket real sería el 0000701.**
   Se corrige con `set_ticket_numbering` devolviendo el contador a 1 — posible
   solo porque el propietario pidió numeración ajustable.
3. **Los datos de febrero a julio son sembrados** (D-112), marcados
   `SEMILLA_DEMO`. No generan comisiones, así que la utilidad de ese período
   sale más alta de lo real.
4. **Las migraciones van directo a producción.** No hay entorno de ensayo: es
   justo lo que resuelve A2.
5. **Una foto borrada no está en ningún respaldo.** El respaldo guarda la lista
   de archivos, no los archivos.
6. **`TicketStatusBadge` todavía pinta los colores viejos de D-082** y
   contradice a D-097 y D-101 (hallazgo N): `en_proceso` usa el color de marca,
   que en el tema de barbería se volvería rojo. Se arregla en 2.6c/2.7
   cambiándola por `StatusPill`, que ya existe y no la usa nadie.

---

## 9. Prompt para retomar

```
Retomo Salón y Más en C:\Proyectos\salonymas.

Lee primero, en este orden:
1. docs/README.md   (el mapa: qué significa cada código y qué manda sobre qué)
2. docs/HANDOFF/HANDOFF_SalonyMas_2026-08-09.md      (dónde quedamos)
3. docs/00_producto/PLAN_DE_TRABAJO_A_PRODUCCION.xlsx (MANDA SOBRE EL ORDEN)
4. docs/00_producto/PLAN_DE_LANZAMIENTO_2026-08-06.md (qué falta y por qué)
5. docs/00_producto/REGISTRO_DE_DECISIONES.md, decisiones D-116 a D-121
6. docs/00_producto/BARRIDO_Y_PLAN_MAESTRO_2026-08-08.md

Estamos en la ETAPA A (seguridad). Cerradas A4, A5 y A6 (esta última a
medias: la parte automática espera a A2). Faltan A1, A2 y A3, que son
"juntos". De la Etapa B está cerrada 2.6a.

IMPORTANTE: el orden lo manda la hoja .xlsx, no el plan de lanzamiento.
Etapa A antes que Etapa B. Se corrigió el 09-ago en D-118 porque se había
trabajado en 2.6 con la Etapa A intacta.

Cómo trabajamos:
- Verifica en el código antes de afirmar; no asumas.
- ANTES de construir, dime en dos líneas qué vas a hacer y por qué, y espera
  mi confirmación. Quiero entender qué hacemos, por qué y para qué.
- Cuando tengas varios puntos que plantear, repítemelos en una lista para
  confirmar que los entendiste ANTES de empezar a resolver.
- Pregunta "¿algo más antes de seguir?" antes de cerrar cada bloque.
- Registra cada decisión en REGISTRO_DE_DECISIONES.md con el porqué, no solo
  el qué, incluyendo lo que se descartó y por qué.
- Lo que aparezca en el camino se anota y se ataca donde le corresponde en el
  plan; si no cabe en ninguna etapa, va al apartado 11.
- Pide permiso antes de tocar Cloudflare, Supabase o hacer push.
- Las migraciones las aplico yo con:
  powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" -Archivo "<ruta>"
- Cualquier instalación en mi computador la ejecuto yo, no tú.
- Recuérdame respaldar antes de cualquier sesión con migraciones:
  powershell -ExecutionPolicy Bypass -File scripts\respaldo_supabase.ps1
- Yo pruebo en producción y te reporto; tú no puedes ver la interfaz.

Pendiente mío y bloqueante: definir los 3 precios de los planes.
```

---

## 10. Evidencia

- **8 commits**, de `7f91f25` a `d8c556f`
- **3 migraciones** aplicadas al proyecto real el 09-ago
- **Decisiones D-116 a D-121** en `REGISTRO_DE_DECISIONES.md`
- **Hallazgos L a P** anotados en el apartado 11 del plan
- **Respaldo del 09-ago** en `OneDrive\Documents\BeautyOS Backups`
- **Verificaciones ejecutadas contra producción, todas en verde:**
  - `161_verify_numero_de_ticket.sql` — 6 controles, 700 tickets numerados del
    1 al 700 sin repetidos ni huecos, y la base rechazó cambiar un número
    emitido
  - `162_verify_fotos_privadas.sql` — 8 controles, dos almacenes con la
    privacidad correcta, 9 políticas, la política vieja desaparecida y **cero
    incoherencias entre aprobada y publicada**
  - `163_test_reglas_de_dinero.sql` — **11 de 11**, a la primera y sin ajustes
