# HANDOFF Salón y Más — 17 de agosto de 2026 (bloque D-145)

**Bloque documentado:** decisión **D-145** · Cierre real del Paso 3.11 (disparador diario) señalado como pendiente en la auditoría del bloque D-143
**Estado:** migración y script de verificación **escritos, sin aplicar todavía** — regla 16: las migraciones las aplica el propietario. Requiere además un paso manual de Vault, fuera de git.
**Reemplaza como handoff vigente a:** la versión anterior de este mismo archivo (bloque D-144, archivada en `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-08-17_D144.md`)

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
        3.3  Términos y privacidad        🔄 CONTENIDO TÉCNICO LISTO (17-ago / D-144) — falta revisión legal 👥
        3.2  Contador (DIAN, IVA)         ⬜ 👤
        3.4  Supabase Pro (~25 USD/mes)   ⬜ 👤
        3.13 Traducir correos de Auth     ⬜ 👥  hallazgo W
Fase 4  Pulido módulo a módulo        🔄 4.1 ✅
```

---

## 2. Qué pasó en este bloque (D-145)

La auditoría del bloque anterior (sobre D-143) dejó un solo punto pendiente: `send-subscription-expiry-alerts` estaba bien blindada (`CRON_SECRET` fail-closed) pero **nadie la llamaba sola cada día**. Se cerró con `pg_cron` + `pg_net`, ya soportados por Supabase.

### Lo que se construyó:

1. **`supabase/migrations/20260817140000_programar_alertas_suscripcion_diarias.sql`:**
   - Habilita las extensiones `pg_cron` y `pg_net` (`create extension if not exists`).
   - Reprograma de forma idempotente (`cron.unschedule` si ya existía, luego `cron.schedule`) una tarea diaria **`avisos_vencimiento_suscripcion_diario`** a las **08:00 hora Colombia (`0 13 * * *` UTC)**.
   - La tarea llama a `send-subscription-expiry-alerts` vía `net.http_post`, con la cabecera `x-cron-secret` leída **por nombre** desde `vault.decrypted_secrets` — **el valor real de `CRON_SECRET` no está escrito en este archivo ni en ningún otro versionado.**

2. **`supabase/sql/172_verify_disparador_alertas_suscripcion.sql`:** control de solo lectura (sin `BEGIN`/`ROLLBACK`, no escribe nada) que confirma extensiones instaladas, la tarea activa con el horario y destino correctos, y **avisa sin fallar** si el secreto de Vault todavía no se guardó, para que ese paso manual no quede invisible.

### Lo que NO se hizo, a propósito:
- No se escribió el valor real de `CRON_SECRET` en ningún lado del repositorio. Es un paso manual, ver sección 4.
- No se pudo aplicar ni verificar contra `beautyos-dev` en esta sesión (sin acceso directo a la base) — es la **primera vez que este proyecto usa `pg_cron`/`pg_net`/Vault**, así que aunque la sintaxis sigue el patrón oficial de Supabase para invocar Edge Functions desde `pg_cron`, el control 172 es la forma real de confirmarlo después de aplicar.

---

## 3. Estado técnico

- **Pruebas Flutter:** sin cambios en este bloque (100% backend/infraestructura) — siguen 113/113 en verde
- **Migraciones pendientes de aplicar:**
  * `supabase/migrations/20260817140000_programar_alertas_suscripcion_diarias.sql`
- **Scripts de verificación:** `172_verify_disparador_alertas_suscripcion.sql`
- **Proyectos Supabase:** `beautyos-dev` (producción) y `salonymas-ensayo`

---

## 4. Instrucción para aplicar (Propietario) — dos pasos, en este orden

1. **Respaldar la base de datos:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\respaldo_supabase.ps1
   ```
2. **Aplicar la migración:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" -Archivo "supabase\migrations\20260817140000_programar_alertas_suscripcion_diarias.sql"
   ```
3. **Paso manual obligatorio, fuera de git, en el Editor SQL de Supabase** (una sola vez, con el mismo valor que ya usaste al configurar `CRON_SECRET` en los secretos de la Edge Function):
   ```sql
   select vault.create_secret(
     '<el mismo valor exacto de CRON_SECRET>',
     'cron_secret_subscription_alerts',
     'Secreto usado por pg_cron para llamar a send-subscription-expiry-alerts'
   );
   ```
   Si ese nombre ya existiera, usar `vault.update_secret(...)` en su lugar (la migración trae el comando exacto en un comentario).
4. **Verificar con el control 172** (`supabase/sql/172_verify_disparador_alertas_suscripcion.sql`) — debe confirmar la tarea activa y, si falta el paso 3, avisarlo sin fallar el resto de los controles.

---

## 5. Lo siguiente según el Plan Maestro

1. **Aplicar este bloque** (migración + paso de Vault) y confirmar con el control 172.
2. **Revisión legal humana del paso 3.3** (fuera del alcance de este asistente).
3. **3.2 — Contador** (DIAN, IVA) — 👤 pendiente del propietario.
4. **3.4 — Supabase Pro** (~25 USD/mes) — 👤 pendiente del propietario.
5. **3.13 — Traducir plantillas de correo de Auth a español** (hallazgo W).
