# HANDOFF Salón y Más — 6 de septiembre de 2026 ("Wrappers `public` para las RPC del cobro, migración rota corregida y unificación de claves de Supabase", D-214)

**Bloque documentado:** decisión **D-214** · Paso **8.37** de la **FASE 8**.

**Estado:** ✅ **CERRADO EN CÓDIGO.** `flutter analyze` 0/0 y **387 de 387 pruebas en verde**.
✅ **MIGRACIÓN APLICADA** el 06-sep por el propietario con `scripts\aplicar_sql.ps1` contra producción: seis `CREATE FUNCTION` y `COMMIT` limpio. Los cuerpos `language sql` los valida PostgreSQL al crearlos, así que las seis `private.beautyos_*` existen con la firma esperada. Respaldo previo en `Backup_2026-09-06_08-17-20`.
✅ **EDGE FUNCTIONS DESPLEGADAS** el 06-sep 13:26-13:27 UTC. La CLI sube `_shared/supabase_keys.ts` como asset junto a cada función, verificado en la salida de las cuatro. Versiones confirmadas contra la foto previa: `create-epayco-session` 17→18, `verify-epayco-transaction` 14→15, `epayco-webhook` 13→14, `send-subscription-expiry-alerts` 6→7. `send-invitation-email` y `send-low-stock-alert` siguen en 10, sin tocar (hallazgo AA).
⚠️ **SIN PROBAR CONTRA UN COBRO REAL.** Ni la migración ni las Edge Functions tienen cobertura automática: la única prueba que existe es un pago de punta a punta.

> El bloque anterior (D-213) está archivado en
> `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-05_D213.md`.

---

## 1. Cómo se llegó aquí

Los cuatro commits del 05-sep posteriores a D-213 (`9d40df6`, `6ac837e`, `e90736f`, `33a62de`) quedaron **sin documentar**: el HANDOFF era más viejo que el último commit, y D-214 estaba nombrada en un mensaje de commit pero no existía en el registro ni en el Plan Maestro. Este bloque cierra ese hueco y termina el trabajo que había quedado a medias en el disco.

---

## 2. Qué cambió

**1. La causa raíz: las RPC del cobro no eran invocables.**
D-176 (paso 8.1) blindó las funciones internas en el esquema `private`, y ahí quedaron las seis del cobro. **PostgREST —y por tanto `supabase-js`— solo expone el esquema `public`**, así que cada `.rpc()` de `create-epayco-session` y `epayco-webhook` fallaba. La migración `20260905180000` añade seis wrappers `public.*` `security definer` que delegan en su función `private`, con `revoke all` a `public`, `anon` y `authenticated` y `grant execute` **solo** a `service_role`. El perímetro de D-177 no se toca.

**2. La migración se había commiteado rota.**
Los seis cuerpos `$$` estaban escapados como `\$\$` (12 veces) y el archivo llevaba BOM: se escribió desde un heredoc de PowerShell y se commiteó sin releerla desde disco. **Era SQL inválido; ningún cuerpo de función abría.** Corregido en este bloque.
**Regla que sale de aquí: una migración escrita desde PowerShell se relee desde disco antes de commitear.** Es el fallo silencioso de D-129 aplicado al SQL.

**3. `Legacy API keys are disabled`.**
Las cuatro Edge Functions del cobro leían `SUPABASE_SERVICE_ROLE_KEY` y `SUPABASE_ANON_KEY` y morían en 401 antes de llegar a la pasarela. Ahora se prioriza `SUPABASE_SECRET_KEYS` / `SUPABASE_PUBLISHABLE_KEYS`, se admite fijar `BEAUTYOS_SUPABASE_SECRET_KEY` como variable no reservada, y se avisa por consola si la clave resuelta sigue siendo legacy. La lógica estaba **copiada cuatro veces**: se extrajo a `supabase/functions/_shared/supabase_keys.ts` (−166/+61 líneas).

**4. Resolución en cascada del negocio y del usuario.**
`create-epayco-session` resolvía el tenant solo por `get_my_tenant_id`; ahora cae en orden a `tenant_memberships` activas, `user_profiles` y `tenants.owner_user_id`. El `userId` se toma del payload del JWT que el gateway de Supabase ya verificó, antes de recurrir a `auth.getUser()`.

**5. Fallback de cálculo del cargo.** Si la RPC no devuelve fila, la función calcula el monto leyendo `tenant_subscriptions` y el plan `pro`. **Contradice a D-193** y queda anotado como hallazgo **W**, sin resolver.

---

## 3. Verificación

- **Análisis estático:** `flutter analyze` 0/0.
- **Suite de pruebas:** **387 de 387 en verde** (`flutter test`), las mismas que en D-213: este bloque no toca Dart, solo Edge Functions y SQL.
- **Lo que NO está verificado:** nada de esto se ha ejecutado contra Supabase. Las Edge Functions y la migración **no tienen pruebas automáticas** — la suite de Flutter no las cubre.

---

## 4. Lo que sigue abierto

**Primero, y bloquea el cobro:**

1. ✅ ~~Aplicar la migración~~ **HECHO el 06-sep**, con respaldo previo. Queda registrado arriba.
2. ✅ ~~Desplegar las cuatro Edge Functions~~ **HECHO el 06-sep**, versiones verificadas una a una. **Nota para la próxima vez:** el despliegue del 05-sep a las 16:34 ya llevaba el refactor de `_shared`, escrito 16 minutos antes y aún sin commitear — durante casi un día estuvo corriendo en producción código que no existía en `main`. Es la cara opuesta de D-159 y merece la misma vigilancia.
3. 👤 **Confirmar en Supabase** que existe una clave moderna en `SUPABASE_SECRET_KEYS` o en `BEAUTYOS_SUPABASE_SECRET_KEY`. Si solo hay legacy, el arreglo 3 no sirve de nada.
4. **Probar un cobro real de punta a punta.** Es la única prueba que existe para esto.

**Heredado y anotado:**

5. Hallazgo **W**: decidir si el fallback del cargo debe existir o si un fallo de la RPC debe fallar a la vista (contradice D-193).
6. Hallazgo **AA**: `send-invitation-email` y `send-low-stock-alert` siguen con claves heredadas.
7. La otra mitad de **UX-07** (Nequi vs. Daviplata en BD y Reportes).
8. El tercio de **TL-09**: acotar la consulta histórica de Tickets.
9. **HSTS** en el panel de Cloudflare — paso 8.25, 👤 propietario.
10. Fase 3 con dos casillas 👤 abiertas (3.2 DIAN/IVA, 3.4 Supabase a Pro).

---

## 5. Contradicciones y duplicados encontrados (señalados, no resueltos)

- **El índice del registro se había quedado sin la línea de D-213.** Es exactamente lo que D-129 y D-131 mandan vigilar. **Repuesta en este bloque**, junto con la de D-214: el índice vuelve a estar completo, 214 de 214.
- **Documentación duplicada fuera del repositorio.** En `BeautyOS Archivos Varios` (OneDrive) hay 51 `.txt` numerados por "pasos" (001 → 1640) que cuentan la misma historia que los 60 `.md` de `docs/_archivo/handoffs/`, con otra numeración. El externo se quedó en el commit `4dd461c` del 04-sep. **Son dos contabilidades del mismo proyecto.**
- **`.agents/` es una copia vendorizada de `modern-web-guidance`** (141 `.md`, 928 KB, versionados) que duplica el plugin ya instalado en `~/.claude/plugins`. Dos copias que se desactualizan por separado.
- **`C:\Proyectos\.claude\launch.json` apunta a `C:\Proyectos\BeautyOS`, que no existe.** Es config de máquina, fuera del repositorio. El `launch.json` de dentro del repo sí es correcto.

---

## 6. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-214: wrappers public para las RPC
del cobro, migración corregida y unificación de claves de Supabase).

flutter analyze 0/0 y 387/387 pruebas en verde, pero la migración
20260905180000_public_wrappers_epayco_rpc_d214.sql NO está aplicada en Supabase y
las Edge Functions no están desplegadas. Hasta que eso ocurra, el cobro no funciona.

Empieza por confirmar si la migración ya se aplicó. Si no, ese es el paso 1.
```
