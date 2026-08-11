# Correo y dominio — cómo está montado

**Fecha:** 10 de agosto de 2026 · **Decisiones:** D-128, y el paso 3.12 del Plan Maestro
**Para qué sirve este documento:** para poder **reconstruir o diagnosticar** el
envío de correo sin volver a averiguarlo. No opina sobre el plan ni sobre qué
falta: eso lo manda el `PLAN_MAESTRO`.

---

## 1. Quién manda cada correo hoy

| Correo | Quién lo manda | Estado |
|---|---|---|
| **Invitación de equipo** | Nuestra función `send-invitation-email` → Resend | ✅ Funciona |
| **Alarma de stock bajo** | Nuestra función `send-low-stock-alert` → Resend | ❌ **Rota** (paso 2.7) |
| **"Confirma tu correo"** del registro | **Supabase Auth**, con su servicio interno | ⚠️ **Tope diario bajísimo** — paso 3.12 |

> **La confusión que costó dos horas el 10-ago:** el correo de confirmación
> **no pasa por Resend**. Sale de `noreply@mail.app.supabase.io`. Verificar el
> dominio en Resend no lo arregla; hay que apuntar el SMTP de Supabase a Resend.

---

## 2. Dominio en Resend

| | |
|---|---|
| Dominio | `salonymas.com` — **verificado** el 10-ago |
| Cuenta | `juankdev2026@gmail.com` |
| Región | North Virginia (`us-east-1`) |
| Remitente | `Salon y Mas <hola@salonymas.com>` |
| Nombre **sin tildes** | A propósito (D-089): el campo "De:" es el más propenso a mostrar símbolos raros. Queda pendiente probarlo con acentos cuando se toque esa función por otro motivo |
| Llave | `BeautyOS`, permiso **Sending access**. Vive en Supabase como secreto `RESEND_API_KEY` |

### Rastreo: apagado a propósito

**Ni clics ni aperturas.** Dos motivos: el rastreo de clics reescribe los
enlaces y algunos filtros lo castigan —y además no aporta, porque si alguien
usó la invitación aparece registrado en la app—; y el de apertura mete un píxel
invisible que **rastrea a una persona sin avisarle**, justo lo que habrá que
explicar en la política de privacidad (Ley 1581). Mismo criterio que D-115.

---

## 3. Los cuatro registros DNS, en Cloudflare

**Se pusieron a mano, no con la configuración automática de Resend.** Motivo: la
automática pide acceso de escritura al DNS de Cloudflare, donde vive el dominio
**y el sitio**. Se prefirió no abrir esa puerta el mismo día que se cerraron
otras dos (D-127).

| Type | Name | Para qué | Proxy |
|---|---|---|---|
| TXT | `resend._domainkey` | **DKIM** — la firma que prueba que el correo salió de ti | DNS only |
| MX | `send` (prioridad **10**) | Por donde vuelven los rebotes | DNS only |
| TXT | `send` | **SPF** — autoriza a Resend a enviar en tu nombre | DNS only |
| TXT | `_dmarc` → `v=DMARC1; p=none;` | Le dice a Gmail que te tomas en serio tu dominio. `p=none` **solo observa**, no rechaza nada | DNS only |

> ⚠️ **Los cuatro van "DNS only", nunca "Proxied".** Si Cloudflare se mete en
> medio, el correo deja de funcionar.
>
> ⚠️ **Y en el campo Name se escribe solo la parte corta.** Cloudflare agrega el
> dominio solo: poner `resend._domainkey.salonymas.com` lo convierte en
> `resend._domainkey.salonymas.com.salonymas.com`.

**El `send.` no es un error.** Es el camino técnico de los rebotes. El
remitente visible sigue siendo `hola@salonymas.com`.

---

## 4. Lo que hay que saber si algo falla

1. **Mira primero los registros de Resend** (`resend.com/logs`). Si **no hay
   ninguna solicitud**, el problema está en la función, no en Resend.
2. **Después las invocaciones de la función** en Supabase. `EDGE_FUNCTION_ERROR`
   significa que la función **reventó**, no que devolviera un error propio.
3. **Si los registros solo muestran `booted` y ningún mensaje nuestro**, el
   fallo está **encima** de nuestro código: en la librería o en el arranque.
4. **`hola@salonymas.com` hoy solo envía.** Nadie recibe ahí; si un cliente
   responde, ese mensaje se pierde. Se resuelve con el reenvío gratuito de
   Cloudflare (idea I-12).

---

## 5. La regla que dejó D-128

> **Ninguna dependencia de una Edge Function va con rango (`^1`, `~2`).**
> Siempre versión exacta.
>
> `@supabase/server@^1` traía un código distinto en cada despliegue y reventaba
> antes de ejecutar la primera línea propia. **Dos horas para encontrarlo.**
