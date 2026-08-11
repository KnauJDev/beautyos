# HANDOFF Salón y Más — 10 de agosto de 2026

**Bloque documentado:** decisiones **D-124 a D-128** · 12 commits · 0 migraciones
**Estado:** todo aplicado y verificado en producción por el propietario
**Reemplaza como handoff vigente a:** `HANDOFF_SalonyMas_2026-08-09.md`

---

## 1. Qué pasó hoy

Un día de **cerrar cosas viejas y ordenar la casa**. Nada de esto fue código nuevo:

1. **Se creó el PLAN MAESTRO** y se jubilaron **siete documentos** que opinaban
   sobre el plan. 74 archivos archivados, ninguno borrado (D-126).
2. **Se cerró H-04** — las claves expuestas el 03-ago ya no sirven (D-127).
3. **Se cerró H-12** — los correos por fin llegan (D-128). Costó dos horas y la
   causa no era Resend.
4. **Se decidieron planes, precios, límites, IA y el filtro de aceptación**
   (D-124, D-125).

---

## 2. Dónde estamos

```
Fase 0  Que exista en internet        ✅
Fase 1  Que sea seguro compartirla    ✅
Fase 2  Seguridad                     🔄 5 de 6  ← AQUÍ
        2.1 Rotar claves              ✅ H-04 cerrado hoy
        2.2 Restauración de ensayo    ⬜ 👥 ← LO ÚNICO QUE FALTA
        2.3 Verificar Resend          ✅ H-12 cerrado hoy
        2.4 Almacenes                 ✅
        2.5 Negocio de prueba         ✅
        2.6 Pruebas de dinero y roles ✅ (mitad; la otra espera a 2.2)
Fase 3  Poder cobrar                  🔄 3.1 ✅ (ePayco confirma recurrencia)
Fase 4  Pulido módulo a módulo        🔄 4.1 ✅ (número de ticket)
```

**La Fase 3 quedó desbloqueada:** el filtro de aceptación (3.7) y los avisos de
vencimiento (3.11) ya no dependen de nada.

---

## 3. Lo que hay que hacer primero mañana

| # | Qué | Por qué |
|---|---|---|
| 1 | **Arreglar `send-low-stock-alert`** | Sigue usando `withSupabase` con `^1`: **está rota por la misma causa que D-128**. Ya sabemos el arreglo exacto — media hora |
| 2 | **Impedir el estilista duplicado** (hallazgo R) | Hoy se pueden vincular dos cuentas al mismo estilista del catálogo. Las dos verían la misma agenda y las mismas comisiones |
| 3 | **Paso 3.12: SMTP de Supabase a Resend** | El *"Confirma tu correo"* lo manda Supabase con un tope diario bajísimo. **Con clientes reales rompe el registro el primer día** |

---

## 4. Lo que aprendimos hoy, y cuesta caro olvidarlo

### La lección de D-128 — la más cara del proyecto

> **Una dependencia anclada con rango (`^1`) en algo desplegado no es una
> comodidad: es una bomba de tiempo.** El mismo código se comporta distinto en
> dos despliegues y no hay forma de saber por qué.
>
> `@supabase/server@^1` reventaba **antes** de ejecutar la primera línea propia.
> Se comprobó instrumentando con `console.log` en cada paso: los registros
> seguían mostrando solo `booted`, **ni un mensaje nuestro**. Eso probó que el
> fallo estaba encima de nuestro código.

**Todas las dependencias de Edge Functions van con versión exacta.**

### La segunda: código que se muere callado

El `fetch` a Resend estaba sin `try`. Cualquier fallo mataba la función en
silencio. **Dos horas para encontrar algo que un mensaje de error habría dicho
en dos minutos.**

### La tercera: reescribir una función pierde cosas

Tres fallos en dos días (D-119, D-122, D-123) salieron de reescribir una
función para agregarle una columna. **Comparar línea por línea contra la
original, no solo la firma.**

---

## 5. Advertencias para quien siga

1. **Los cinco fallos de hoy los encontró el propietario probando.** Ninguna
   prueba automática vio ninguno. El asistente no ve la interfaz: **su prueba
   en producción no es un trámite, es parte de la verificación**.
2. **El consecutivo de ticket NO sirve como número contable** (hallazgo P). Se
   arregla en el paso 4.4 separándolo en dos.
3. **Al borrar la semilla de ensayo, el primer ticket real sería el 0000701.**
   Se corrige con `set_ticket_numbering`.
4. **Ningún módulo se actualiza solo** (hallazgo Q): entrar a un módulo no
   recarga sus datos. Se arregla en 4.3.
5. **Un usuario con membresía NO se puede borrar desde Supabase**: las llaves
   tienen `RESTRICT`. La base se defiende sola. Verificado el 10-ago.
6. **La prueba gratis del propietario vence pronto.** Cuando llegue a cero, su
   propio negocio deja de aceptar citas nuevas y no podrá probar. Se extiende
   con `platform_extend_trial`.

---

## 6. Cómo trabajamos — no negociable

- **Verifica en el código antes de afirmar. No asumas.**
- **Antes de construir, di en dos líneas qué y por qué, y espera confirmación.**
- Varios puntos a la vez: repetirlos en una lista y confirmar **antes** de
  resolver.
- Preguntar **"¿algo más antes de seguir?"** antes de cerrar cada bloque.
- **Registrar cada decisión con su porqué**, incluyendo lo descartado.
- **Regla de hallazgos:** lo que aparezca se anota donde le corresponde. Si no
  cabe, va al **buzón de ideas** del Plan Maestro.
- **Pedir permiso antes de tocar Supabase, Cloudflare o hacer push.**
- **Las instalaciones las ejecuta el propietario.**
- **Respaldar antes de cada sesión con migraciones.**
- **El propietario prueba en producción y reporta.**
- **Al reescribir una función, compararla línea por línea contra la original.**

---

## 7. Estado técnico

- **Pruebas:** 89, en 10 archivos · `flutter analyze` limpio
- **Migraciones:** todas aplicadas
- **Edge Functions:** `send-invitation-email` ✅ arreglada ·
  `send-low-stock-alert` ❌ **rota, pendiente**
- **Claves:** legacy `anon` y `service_role` **desactivadas**; la app usa
  `publishableKey`
- **Correo:** dominio `salonymas.com` verificado en Resend, remitente
  `hola@salonymas.com`
- **Respaldo:** del 09-ago. **Hacer uno nuevo antes de la próxima sesión con
  migraciones**

---

## 8. Prompt para retomar

```
Buenos días Claude. Retomo Salón y Más en C:\Proyectos\salonymas.

Antes de proponer nada, lee en este orden:
1. docs/README.md
2. docs/HANDOFF/HANDOFF_SalonyMas_2026-08-10.md   (dónde quedamos)
3. docs/00_producto/PLAN_MAESTRO.md   (el ÚNICO que manda sobre qué falta
   y en qué orden: visión, planes, precios, los 16 módulos, 8 fases,
   buzón de ideas y hallazgos abiertos)
4. docs/00_producto/REGISTRO_DE_DECISIONES.md, las últimas 15 entradas
   (por qué está hecho así — solo crece, nunca se resume)

Estamos en la FASE 2 (seguridad), 5 de 6. Solo falta 2.2, la restauración
de ensayo, que es "juntos".

Lo primero de hoy, en este orden:
1. Arreglar send-low-stock-alert: sigue rota por la misma causa que D-128
   (dependencia @supabase/server anclada como ^1). El arreglo ya está
   probado en send-invitation-email.
2. Impedir que se invite a dos cuentas al mismo estilista del catálogo
   (hallazgo R).
3. Paso 3.12: apuntar el SMTP de Supabase Auth a Resend.

Cómo trabajamos — esto es lo que más me importa:
- Verifica en el código antes de afirmar; no asumas nunca.
- ANTES de construir, dime en dos líneas qué vas a hacer y por qué, y
  espera mi confirmación. Quiero entender qué hacemos, por qué y para qué.
- Cuando tengas varios puntos, repítemelos en una lista para confirmar que
  los entendiste ANTES de empezar a resolver.
- Pregunta "¿algo más antes de seguir?" antes de cerrar cada bloque.
- Registra cada decisión en REGISTRO_DE_DECISIONES.md con el porqué, no
  solo el qué, incluyendo lo que se descartó y por qué.
- Lo que aparezca en el camino se anota donde le corresponde en el Plan
  Maestro; si no cabe en ninguna fase, va al buzón de ideas.
- Pide permiso antes de tocar Cloudflare, Supabase o hacer push.
- Las migraciones las aplico yo con:
  powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" -Archivo "<ruta>"
- Cualquier instalación en mi computador la ejecuto yo, no tú.
- Recuérdame respaldar antes de cualquier sesión con migraciones:
  powershell -ExecutionPolicy Bypass -File scripts\respaldo_supabase.ps1
- Yo pruebo en producción y te reporto; tú no puedes ver la interfaz.
- Háblame claro, sin tecnicismos, y dime cuando me equivoque o cuando te
  equivoques tú. Prefiero que me discutas con argumentos a que me des la
  razón.

No soy técnico: no sé de programación ni de arquitectura. Explícame el
porqué de las cosas, no solo el qué.

Pendiente mío: definir si salgo con precio de lista o con precio pionero,
y conseguir los primeros 25 salones.
```

---

## 9. Evidencia

- **12 commits**, de `2c8ec43` a `6271fa3`
- **Decisiones D-124 a D-128** en `REGISTRO_DE_DECISIONES.md`
- **Hallazgos R, S y T** en el Plan Maestro, sección 7 — **escritos el 11-ago.**
  El 10-ago esta línea afirmaba que ya estaban y **era falsa**: la edición se
  ancló en un documento recién archivado y no hizo nada. Lo detectó el
  propietario leyendo el handoff contra el plan (D-129)
- **Verificado en producción por el propietario:** correo de invitación
  recibido, registro completado, cuenta unida al negocio como estilista, y
  todo funcionando **con las claves antiguas ya desactivadas**
