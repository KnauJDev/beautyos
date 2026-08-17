# HANDOFF Salón y Más — 17 de agosto de 2026 (bloque D-146)

**Bloque documentado:** decisión **D-146** · Paso 3.13: plantillas de correo de Supabase Auth traducidas al español (hallazgo W)
**Estado:** documento operativo escrito y verificado contra el código. **Falta el paso manual, fuera de git:** pegar cada una de las 6 plantillas en el panel de Supabase (Authentication → Emails → Templates).
**Reemplaza como handoff vigente a:** la versión anterior de este mismo archivo (bloque D-145, archivada en `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-08-17_D145.md`)

---

## 1. Dónde estamos

```
Fase 0  Que exista en internet        ✅
Fase 1  Que sea seguro compartirla    ✅
Fase 2  Seguridad                     ✅ CERRADA (12-ago) — 7 de 7
Fase 3  Poder cobrar                  🔄  ← AQUÍ
        3.1  ePayco admite recurrencia    ✅
        3.5  Precios y límites            ✅ CERRADO (12-ago)
        3.6  Precio por cliente           ✅ CERRADO (12-ago)
        3.7  Filtro de aceptación         ✅ CERRADO (16-ago / D-138)
        3.8  Pantalla pública de planes   ✅ CERRADO (17-ago / D-140)
        3.9  ePayco en servidor (webhook) ✅ CERRADO (17-ago / D-141, D-142)
        3.10 Pagos y suscripciones        ✅ CERRADO (17-ago / D-141, D-142)
        3.11 Avisos por correo y gracia   🔄 CÓDIGO LISTO (17-ago / D-143, D-145) — falta aplicar la migración y el paso de Vault
        3.12 Correos de cuenta por Resend ✅
        3.13 Traducir correos de Auth     ✅ CERRADO 17-ago (D-146) — falta pegar en el panel de Supabase
        3.3  Términos y privacidad        🔄 CONTENIDO TÉCNICO LISTO (17-ago / D-144) — falta revisión legal 👥
        3.2  Contador (DIAN, IVA)         ⬜ 👤
        3.4  Supabase Pro (~25 USD/mes)   ⬜ 👤
Fase 4  Pulido módulo a módulo        🔄 4.1 ✅
```

**Con esto, todo lo técnico de la Fase 3 que dependía de este asistente está
escrito.** Lo que queda abierto en Fase 3 son tres cosas que no son código:
aplicar dos piezas ya construidas (3.11 y 3.13, ambas esperando un paso manual
del propietario fuera de git), y dos que dependen enteramente de él (3.2
contador, 3.4 Supabase Pro) más la revisión legal de 3.3.

---

## 2. Qué pasó en este bloque (Paso 3.13 / D-146)

El hallazgo W señalaba que las 6 plantillas de correo de cuenta de Supabase
Auth seguían en inglés de fábrica — el primer correo que recibe cada dueña de
salón. Se redactaron las 6 en español colombiano, con la marca de la
plataforma.

### Lo que se construyó:

1. **`docs/02_operacion/PLANTILLAS_CORREO_AUTH.md`** (documento nuevo): las 6
   plantillas completas — **Confirm signup, Reset Password, Magic Link,
   Invite user, Change Email Address, Reauthentication** — cada una con su
   asunto y su HTML exacto, listos para copiar y pegar en Authentication →
   Emails → Templates. Mismo sistema visual que la app (morado `#7C3AED` /
   `#2D1B69`, copiado a mano porque el HTML de Supabase no puede importar
   `AppColors`).
   - **Reautenticación es distinta a las otras cinco:** usa `{{ .Token }}`
     (un código de 6 dígitos para escribir de vuelta en la app), no
     `{{ .ConfirmationURL }}` — es un flujo de código, no de enlace.
   - **Verificado contra el código, no asumido:** de las 6, hoy **solo
     "Confirm signup" se dispara de verdad** en la app (`register_page.dart`
     llama a `auth.signUp`). Las otras cinco quedan listas para cuando
     existan sus flujos — no hay ningún llamado a `resetPasswordForEmail`,
     `signInWithOtp`, `admin.inviteUserByEmail`, cambio de correo ni
     `reauthenticate()` todavía en `lib/`.
   - Se documentó explícitamente que la plantilla nativa "Invite user" de
     Supabase **no es** el correo real de invitación de equipo de este
     proyecto (ese es `send-invitation-email` por Resend, D-062/D-065, ya en
     español desde que se construyó) — para que nadie las confunda después.

2. **`docs/02_operacion/CORREO_Y_DOMINIO.md`:** actualizada la fila de
   "Correos de cuenta" — ya no dice "están en inglés", apunta al documento
   nuevo.

### Corrección de un error propio encontrado en este mismo bloque:

**Al revisar el registro de decisiones antes de agregar D-146, se encontró
que la fila completa de D-143 había desaparecido** — sobrevivía su línea de
índice, pero no el detalle. Comparado contra el commit `c2b5611` (donde sí
existía completa) contra `670fbce` (donde ya no), quedó claro que se perdió
durante la edición del bloque D-145 de esta misma sesión: un reemplazo de
texto que debía insertar la fila de D-145 delante de la de D-144 en realidad
usó como ancla el texto de D-143, borrándola. **Se restauró carácter por
carácter desde `c2b5611`** (diff verificado como idéntico) antes de escribir
nada de D-146. Es exactamente el fallo que la regla 19 del Plan Maestro pide
evitar — "no se afirma que algo quedó escrito sin haberlo comprobado" — y se
detectó comprobando, no asumiendo.

**Segundo error propio, encontrado en la auditoría de este mismo bloque:** al
marcar cerrado el hallazgo **W** en `PLAN_MAESTRO.md`, se reemplazó por
completo la descripción original del problema (la cita real *"Confirm your
email address..."* y su razonamiento) por la nota de cierre, en vez de
conservarla y solo **agregar** el cierre — rompiendo el patrón que sí
siguieron los hallazgos R, Y y T (descripción original intacta, nota de
cierre añadida aparte). Se restauró la descripción original y se le agregó
la nota de cierre de D-146, siguiendo el mismo patrón que esos tres.

**De paso, verificando la integridad del registro completo (D-137 a D-146,
índice contra fila), se encontró un segundo glitch, mucho más antiguo (12-ago,
antes de esta sesión): la fila de D-137 quedó pegada sin salto de línea al
final de la fila de D-136** (`...a proposit| D-137 | ...`), por lo que no se
renderiza como fila propia de la tabla. **No se tocó**, porque no se pudo
confirmar si además se perdió una palabra de D-136 al mismo tiempo, y esta
decisión no es de este bloque ni de esta sesión — queda señalado para que el
propietario decida cómo repararlo, sin resolverlo por iniciativa propia
(regla 20).

---

## 3. Estado técnico

- **Sin cambios de código Flutter ni migraciones SQL en este bloque:** es
  100% documentación operativa.
- **Proyectos Supabase:** `beautyos-dev` (producción) y `salonymas-ensayo`

---

## 4. Instrucción para aplicar (Propietario)

No hay migración que correr. El único paso es manual, en el panel:

1. Abrir `docs/02_operacion/PLANTILLAS_CORREO_AUTH.md`.
2. En Supabase → **Authentication → Emails → Templates**, para cada una de
   las 6 plantillas: pegar el **Subject heading** y el **Message body** de la
   sección correspondiente, y **Save**.
3. Probar al menos "Confirm signup" con una cuenta de prueba real (es la
   única que se dispara hoy) para confirmar que llega bien formateada.

---

## 5. Lo siguiente según el Plan Maestro

1. **Aplicar 3.11** (migración `pg_cron` + paso de Vault, ver bloque D-145).
2. **Aplicar 3.13** (pegar las 6 plantillas en el panel, este bloque).
3. **Revisión legal humana del paso 3.3** (fuera del alcance de este asistente).
4. **Opcional, señalado, no decidido:** reparar el salto de línea perdido entre D-136 y D-137 en `REGISTRO_DE_DECISIONES.md`.
5. **3.2 — Contador** (DIAN, IVA) — 👤 pendiente del propietario.
6. **3.4 — Supabase Pro** (~25 USD/mes) — 👤 pendiente del propietario.
