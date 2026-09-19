# Plantillas de correo de Supabase Auth — en español

**Fecha:** 17 de agosto de 2026 · **Decisión:** D-146 · **Cierra:** hallazgo W, paso 3.13
**Para qué sirve este documento:** las seis plantillas de correo de cuenta de
Supabase Auth, en español colombiano y con la marca de Salón y Más, **listas
para copiar y pegar tal cual** en el panel de Supabase. No opina sobre el plan
ni sobre qué falta: eso lo manda el `PLAN_MAESTRO`. Cómo está montado el envío
(SMTP, dominio, remitente) vive en `CORREO_Y_DOMINIO.md`; aquí no se repite.

---

## 1. Dónde se pegan

**Authentication → Emails → Templates**, en el panel de Supabase
(`beautyos-dev`). Hay un formulario por plantilla con dos campos: **Subject
heading** (el asunto) y **Message body** (el HTML). Se pega el asunto y el
HTML de cada sección de abajo, tal cual, y se guarda con **Save**.

**Después de pegar cada una, pruébala de verdad.** Supabase no tiene una
vista previa fiel dentro del panel; la única forma confiable de ver cómo
llega es disparar el flujo real (crear una cuenta de prueba, pedir "olvidé mi
contraseña", etc.) y mirar el correo en una bandeja real.

---

## 2. Cuáles de estas seis ya se usan hoy en la app, y cuáles no

**Verificado contra el código, no asumido.** Solo una de las seis se dispara
hoy desde algún lugar de la aplicación:

| Plantilla | ¿Se usa hoy en Salón y Más? |
|---|---|
| **Confirm signup** | ✅ **Sí.** `register_page.dart` llama a `auth.signUp(...)` y este es el correo que confirma la cuenta nueva. **Reescrita el 18-sep (D-248): ya no lleva enlace, lleva un código de 6 números.** |
| **Reset Password** | ⬜ No. No existe todavía un enlace de "olvidé mi contraseña" en `LoginPage` ni ninguna llamada a `resetPasswordForEmail`. |
| **Magic Link** | ⬜ No. Ninguna pantalla llama a `signInWithOtp`. |
| **Invite user** | ⬜ No. Las invitaciones de equipo de este proyecto usan un flujo propio (`create_team_invitation` + Edge Function `send-invitation-email` por Resend, D-062/D-065) — **no** el invite nativo de Supabase Auth (`admin.inviteUserByEmail`). Esta plantilla queda lista por si alguna vez se usa ese camino nativo, pero hoy no lo dispara nada. |
| **Change Email Address** | ⬜ No. No hay pantalla para cambiar el correo de la cuenta todavía. |
| **Reauthentication** | ⬜ No. Ninguna pantalla llama a `reauthenticate()`. |

**Por qué se traducen las seis igual, aunque cinco estén dormidas:** el panel
de Supabase no avisa cuándo una plantilla en inglés queda huérfana el día que
alguien construye "olvidé mi contraseña" sin acordarse de revisar el idioma
primero. Traducirlas ahora, todas juntas, evita que ese día se repita el
mismo hallazgo W con un nombre distinto.

---

## 3. Variables usadas

Solo las nativas de Supabase Auth, ninguna inventada:

- `{{ .ConfirmationURL }}` — el enlace de acción (confirmar, resetear, entrar).
- `{{ .Token }}` — el código numérico de un solo uso. *(Hasta el 18-sep aquí ponía «solo en Reautenticación». **Es falso:** también existe en Confirm signup, y desde D-248 es justo lo que usa esa plantilla.)*
- `{{ .Email }}` — el correo actual de la cuenta.
- `{{ .NewEmail }}` — el correo nuevo solicitado (solo en Cambio de correo).
- `{{ .SiteURL }}` — la URL configurada como Site URL del proyecto.

---

## 4. Confirm signup (Confirmacion de registro)

**Estado:** activa hoy. **Reescrita el 18-sep (D-248).**

> ### Por que esta plantilla ya no lleva enlace
>
> Hasta el 18-sep mandaba un boton **Confirmar mi correo** con
> `{{ .ConfirmationURL }}`. Ese enlace es **de un solo uso**, y los escaneres
> antifraude del buzon lo visitan antes que la persona: cuando el destinatario
> pulsaba, **ya estaba gastado**.
>
> **Verificado, no supuesto:** correo enviado 12:38, pulsado 12:40,
> `error_code=otp_expired`, y **la cuenta quedo confirmada igual** — el
> estilista entro con su contrasenya acto seguido, cosa que exige el correo ya
> verificado.
>
> El hallazgo **AH** decia al principio que el enlace *caducaba* y que se
> arreglaba **subiendo el plazo en Authentication -> Email**. **Las dos cosas
> eran falsas** y el arreglo no habria cambiado nada (D-247).
>
> **Un codigo de seis numeros no se puede gastar visitandolo: no hay nada que
> visitar.** Y de regalo funciona aunque el correo se abra en otro navegador o
> en otro telefono, cosa que el enlace con PKCE no hacia.
>
> **Ya no se promete la prueba de 21 dias** (hallazgo **AL**): esta misma
> plantilla la recibe tambien el empleado invitado, que no tiene prueba ni es
> un negocio. Supabase manda una sola plantilla para todo el que crea cuenta.

**Subject heading:**

```
Tu código para activar tu cuenta en Salón y Más
```

**Message body:**

```html
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8" />
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #F8F5FF; margin:0; padding:20px; color:#111827; }
  .container { max-width: 560px; margin: 0 auto; background:#FFFFFF; border-radius:12px; border:1px solid #E5E7EB; overflow:hidden; }
  .header { background:#7C3AED; padding:28px 24px; text-align:center; }
  .header h1 { color:#FFFFFF; margin:0; font-size:20px; font-weight:700; }
  .content { padding:32px 24px; line-height:1.6; font-size:14px; }
  .codigo { text-align:center; margin:28px 0; }
  .codigo span { display:inline-block; background:#F8F5FF; border:2px solid #7C3AED; border-radius:10px; padding:16px 28px; font-size:34px; font-weight:800; letter-spacing:10px; color:#4C1D95; }
  .muted { font-size:12px; color:#6B7280; }
  .footer { background:#F8FAFC; border-top:1px solid #E5E7EB; padding:16px; text-align:center; font-size:12px; color:#94A3B8; }
  .footer a { color:#7C3AED; text-decoration:none; }
</style>
</head>
<body>
  <div class="container">
    <div class="header"><h1>Salón y Más</h1></div>
    <div class="content">
      <p>¡Hola!</p>
      <p>Para activar tu cuenta, escribe este código en la pantalla donde te
      lo estamos pidiendo:</p>
      <div class="codigo"><span>{{ .Token }}</span></div>
      <p class="muted">El código sirve una sola vez y caduca en una hora. Si se
      te pasa, pide otro desde la misma pantalla.</p>
      <p style="color:#6B7280;">Si tú no creaste esta cuenta, puedes ignorar
      este correo con tranquilidad: no se activará nada.</p>
    </div>
    <div class="footer">
      Salón y Más &mdash; Plataforma de gestión para centros de estética, barberías y spas<br>
      <a href="{{ .SiteURL }}">{{ .SiteURL }}</a> &middot; hola@salonymas.com
    </div>
  </div>
</body>
</html>
```

> **Las tildes son parte de la plantilla, no un adorno.** La primera versión
> de esta reescritura (18-sep) se entregó **sin una sola tilde** y el
> propietario la pegó así antes de que se viera. Es el hallazgo **AV**
> repetido — texto de cara al cliente sin acentuar — pero en **el primer
> correo que recibe alguien que se registra. Corregido el 19-sep.**

> **Al pegarla, no dejes ningun `{{ .ConfirmationURL }}` en el cuerpo.** Si
> queda uno, aunque sea en un enlace de respaldo, el escaner del buzon lo
> visitara y volvera a gastar el token: el problema seguiria ahi, solo que mas
> dificil de ver.

## 5. Reset Password (Recuperación de contraseña)

**Estado:** ⬜ dormida — lista para cuando exista "olvidé mi contraseña".

**Subject heading:**
```
Recupera el acceso a tu cuenta en Salón y Más
```

**Message body:**
```html
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8" />
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #F8F5FF; margin:0; padding:20px; color:#111827; }
  .container { max-width: 560px; margin: 0 auto; background:#FFFFFF; border-radius:12px; border:1px solid #E5E7EB; overflow:hidden; }
  .header { background:#7C3AED; padding:28px 24px; text-align:center; }
  .header h1 { color:#FFFFFF; margin:0; font-size:20px; font-weight:700; }
  .content { padding:32px 24px; line-height:1.6; font-size:14px; }
  .btn-container { text-align:center; margin:28px 0; }
  .btn { display:inline-block; background-color:#7C3AED; color:#FFFFFF !important; text-decoration:none; padding:14px 28px; font-weight:700; font-size:15px; border-radius:8px; }
  .muted { font-size:12px; color:#6B7280; word-break:break-all; }
  .footer { background:#F8FAFC; border-top:1px solid #E5E7EB; padding:16px; text-align:center; font-size:12px; color:#94A3B8; }
  .footer a { color:#7C3AED; text-decoration:none; }
</style>
</head>
<body>
  <div class="container">
    <div class="header"><h1>Salón y Más</h1></div>
    <div class="content">
      <p>Hola,</p>
      <p>Recibimos una solicitud para restablecer la contraseña de tu cuenta en
      <strong>Salón y Más</strong>. Si fuiste tú, crea una nueva contraseña aquí:</p>
      <div class="btn-container">
        <a href="{{ .ConfirmationURL }}" class="btn">Crear nueva contraseña</a>
      </div>
      <p>Si el botón no funciona, copia y pega este enlace en tu navegador:</p>
      <p class="muted">{{ .ConfirmationURL }}</p>
      <p style="color:#6B7280;">Si no solicitaste este cambio, ignora este correo:
      tu contraseña actual sigue siendo válida y tu cuenta está segura.</p>
    </div>
    <div class="footer">
      Salón y Más — Plataforma de gestión para centros de estética, barberías y spas<br>
      <a href="{{ .SiteURL }}">{{ .SiteURL }}</a> · hola@salonymas.com
    </div>
  </div>
</body>
</html>
```

---

## 6. Magic Link (Enlace de acceso rápido)

**Estado:** ⬜ dormida — lista para cuando se ofrezca entrar sin contraseña.

**Subject heading:**
```
Tu enlace de acceso rápido a Salón y Más
```

**Message body:**
```html
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8" />
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #F8F5FF; margin:0; padding:20px; color:#111827; }
  .container { max-width: 560px; margin: 0 auto; background:#FFFFFF; border-radius:12px; border:1px solid #E5E7EB; overflow:hidden; }
  .header { background:#7C3AED; padding:28px 24px; text-align:center; }
  .header h1 { color:#FFFFFF; margin:0; font-size:20px; font-weight:700; }
  .content { padding:32px 24px; line-height:1.6; font-size:14px; }
  .btn-container { text-align:center; margin:28px 0; }
  .btn { display:inline-block; background-color:#7C3AED; color:#FFFFFF !important; text-decoration:none; padding:14px 28px; font-weight:700; font-size:15px; border-radius:8px; }
  .muted { font-size:12px; color:#6B7280; word-break:break-all; }
  .footer { background:#F8FAFC; border-top:1px solid #E5E7EB; padding:16px; text-align:center; font-size:12px; color:#94A3B8; }
  .footer a { color:#7C3AED; text-decoration:none; }
</style>
</head>
<body>
  <div class="container">
    <div class="header"><h1>Salón y Más</h1></div>
    <div class="content">
      <p>Hola,</p>
      <p>Usa el siguiente botón para entrar a tu cuenta de <strong>Salón y Más</strong>
      sin necesidad de escribir tu contraseña:</p>
      <div class="btn-container">
        <a href="{{ .ConfirmationURL }}" class="btn">Ingresar ahora</a>
      </div>
      <p>Si el botón no funciona, copia y pega este enlace en tu navegador:</p>
      <p class="muted">{{ .ConfirmationURL }}</p>
      <p style="color:#6B7280;">Este enlace es de un solo uso y vence pronto. Si no
      intentaste ingresar, puedes ignorar este correo.</p>
    </div>
    <div class="footer">
      Salón y Más — Plataforma de gestión para centros de estética, barberías y spas<br>
      <a href="{{ .SiteURL }}">{{ .SiteURL }}</a> · hola@salonymas.com
    </div>
  </div>
</body>
</html>
```

---

## 7. Invite user (Invitación de usuario al equipo — nativa de Supabase)

**Estado:** ⬜ dormida. **No confundir con el correo de invitación real de
Salón y Más** (`send-invitation-email`, Resend, D-062/D-065), que es el que
de verdad reciben hoy los estilistas y asistentes invitados. Esta plantilla
solo se dispararía si algún día se usa `admin.inviteUserByEmail` directo de
Supabase.

**Subject heading:**
```
Te invitaron a unirte a un negocio en Salón y Más
```

**Message body:**
```html
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8" />
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #F8F5FF; margin:0; padding:20px; color:#111827; }
  .container { max-width: 560px; margin: 0 auto; background:#FFFFFF; border-radius:12px; border:1px solid #E5E7EB; overflow:hidden; }
  .header { background:#7C3AED; padding:28px 24px; text-align:center; }
  .header h1 { color:#FFFFFF; margin:0; font-size:20px; font-weight:700; }
  .content { padding:32px 24px; line-height:1.6; font-size:14px; }
  .btn-container { text-align:center; margin:28px 0; }
  .btn { display:inline-block; background-color:#7C3AED; color:#FFFFFF !important; text-decoration:none; padding:14px 28px; font-weight:700; font-size:15px; border-radius:8px; }
  .muted { font-size:12px; color:#6B7280; word-break:break-all; }
  .footer { background:#F8FAFC; border-top:1px solid #E5E7EB; padding:16px; text-align:center; font-size:12px; color:#94A3B8; }
  .footer a { color:#7C3AED; text-decoration:none; }
</style>
</head>
<body>
  <div class="container">
    <div class="header"><h1>Salón y Más</h1></div>
    <div class="content">
      <p>¡Hola!</p>
      <p>Te invitaron a unirte a un equipo en <strong>Salón y Más</strong>, la
      plataforma de gestión para centros de estética, barberías y spas. Para
      aceptar la invitación y crear tu acceso, haz clic aquí:</p>
      <div class="btn-container">
        <a href="{{ .ConfirmationURL }}" class="btn">Aceptar invitación</a>
      </div>
      <p>Si el botón no funciona, copia y pega este enlace en tu navegador:</p>
      <p class="muted">{{ .ConfirmationURL }}</p>
      <p style="color:#6B7280;">Si no esperabas esta invitación, puedes ignorar
      este correo con tranquilidad.</p>
    </div>
    <div class="footer">
      Salón y Más — Plataforma de gestión para centros de estética, barberías y spas<br>
      <a href="{{ .SiteURL }}">{{ .SiteURL }}</a> · hola@salonymas.com
    </div>
  </div>
</body>
</html>
```

---

## 8. Change Email Address (Confirmación de cambio de correo)

**Estado:** ⬜ dormida — lista para cuando exista "cambiar mi correo" en
Configuración.

**Subject heading:**
```
Confirma el cambio de correo de tu cuenta en Salón y Más
```

**Message body:**
```html
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8" />
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #F8F5FF; margin:0; padding:20px; color:#111827; }
  .container { max-width: 560px; margin: 0 auto; background:#FFFFFF; border-radius:12px; border:1px solid #E5E7EB; overflow:hidden; }
  .header { background:#7C3AED; padding:28px 24px; text-align:center; }
  .header h1 { color:#FFFFFF; margin:0; font-size:20px; font-weight:700; }
  .content { padding:32px 24px; line-height:1.6; font-size:14px; }
  .btn-container { text-align:center; margin:28px 0; }
  .btn { display:inline-block; background-color:#7C3AED; color:#FFFFFF !important; text-decoration:none; padding:14px 28px; font-weight:700; font-size:15px; border-radius:8px; }
  .muted { font-size:12px; color:#6B7280; word-break:break-all; }
  .footer { background:#F8FAFC; border-top:1px solid #E5E7EB; padding:16px; text-align:center; font-size:12px; color:#94A3B8; }
  .footer a { color:#7C3AED; text-decoration:none; }
</style>
</head>
<body>
  <div class="container">
    <div class="header"><h1>Salón y Más</h1></div>
    <div class="content">
      <p>Hola,</p>
      <p>Recibimos una solicitud para cambiar el correo asociado a tu cuenta en
      <strong>Salón y Más</strong> de <strong>{{ .Email }}</strong> a
      <strong>{{ .NewEmail }}</strong>. Para confirmar este cambio, haz clic aquí:</p>
      <div class="btn-container">
        <a href="{{ .ConfirmationURL }}" class="btn">Confirmar cambio de correo</a>
      </div>
      <p>Si el botón no funciona, copia y pega este enlace en tu navegador:</p>
      <p class="muted">{{ .ConfirmationURL }}</p>
      <p style="color:#6B7280;">Si no solicitaste este cambio, ignora este correo y
      escríbenos a hola@salonymas.com para revisar la seguridad de tu cuenta.</p>
    </div>
    <div class="footer">
      Salón y Más — Plataforma de gestión para centros de estética, barberías y spas<br>
      <a href="{{ .SiteURL }}">{{ .SiteURL }}</a> · hola@salonymas.com
    </div>
  </div>
</body>
</html>
```

---

## 9. Reauthentication (Código de verificación / Reautenticación)

**Estado:** ⬜ dormida — lista para cuando exista una acción sensible que
pida confirmar identidad de nuevo.

**Distinto de las otras cinco:** no es un enlace, es un **código numérico**
que la persona debe volver a escribir dentro de la aplicación. Por eso no usa
`{{ .ConfirmationURL }}`, usa `{{ .Token }}`.

**Subject heading:**
```
Tu código de verificación de Salón y Más
```

**Message body:**
```html
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8" />
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #F8F5FF; margin:0; padding:20px; color:#111827; }
  .container { max-width: 560px; margin: 0 auto; background:#FFFFFF; border-radius:12px; border:1px solid #E5E7EB; overflow:hidden; }
  .header { background:#7C3AED; padding:28px 24px; text-align:center; }
  .header h1 { color:#FFFFFF; margin:0; font-size:20px; font-weight:700; }
  .content { padding:32px 24px; line-height:1.6; font-size:14px; text-align:center; }
  .code-box { background:#EDE9FE; border:1px solid #7C3AED; border-radius:8px; padding:18px; font-size:30px; font-weight:800; letter-spacing:8px; color:#2D1B69; margin:24px 0; }
  .footer { background:#F8FAFC; border-top:1px solid #E5E7EB; padding:16px; text-align:center; font-size:12px; color:#94A3B8; }
  .footer a { color:#7C3AED; text-decoration:none; }
</style>
</head>
<body>
  <div class="container">
    <div class="header"><h1>Salón y Más</h1></div>
    <div class="content">
      <p style="text-align:left;">Hola,</p>
      <p style="text-align:left;">Para confirmar esta acción dentro de tu cuenta de
      <strong>Salón y Más</strong>, usa el siguiente código de verificación:</p>
      <div class="code-box">{{ .Token }}</div>
      <p style="text-align:left;color:#6B7280;">Este código vence en pocos minutos. Si no intentaste
      realizar esta acción, ignora este correo y considera revisar la seguridad de
      tu cuenta.</p>
    </div>
    <div class="footer">
      Salón y Más — Plataforma de gestión para centros de estética, barberías y spas<br>
      <a href="{{ .SiteURL }}">{{ .SiteURL }}</a> · hola@salonymas.com
    </div>
  </div>
</body>
</html>
```

---

## 10. Colores usados

Los mismos hex del sistema de diseño de la aplicación (`lib/theme/app_colors.dart`,
D-097/D-102), copiados a mano porque el HTML de estos correos no puede importar
`AppColors`:

| Uso | Color | Igual a |
|---|---|---|
| Encabezado / botón | `#7C3AED` | `AppColors.brand` |
| Texto del código de reautenticación | `#2D1B69` | `AppColors.brandDeep` |
| Fondo general del correo | `#F8F5FF` | `AppColors.brandSurface` |
| Texto secundario | `#6B7280` | `AppColors.textSecondary` |
| Borde de tarjetas | `#E5E7EB` | `AppColors.border` |

**Si el tema de la aplicación cambia de morado (D-109, marca blanca), estos
correos no se actualizan solos** — son HTML estático dentro del panel de
Supabase, no leen `AppColors` en tiempo real. Quedan fuera de alcance del
sistema de marca blanca por diseño: son correos de **la plataforma**
(Salón y Más), no del negocio de cada tenant.
