# Tramo D — cierre productivo

**Fecha:** 22 de julio de 2026
**Estado:** Tramo D desplegado en el único proyecto Supabase real
**Base Git:** `9a8485c` (cierre de NC-D-01) + despliegue de esta fecha

## 1. Qué cambió frente al plan original (D4/D5)

El plan D4/D5 de `TRAMO_D5_PRE_2_AUDITORIA_NO_CONFORMIDADES_2026-07-20.md`
asumía dos proyectos Supabase (uno productivo, uno no productivo) y una
compuerta formal para pasar de uno a otro. NC-D-01 (ver `D-042`) confirmó que
**solo existe un proyecto** (`beautyos-dev`, `eogppgbdnwxdtcbctaol`), sin
clientes reales todavía. Por decisión del propietario, el Tramo D se cerró
desplegando directamente sobre ese único proyecto, con respaldo previo, en
lugar de rehacer D4/D5 sobre un segundo entorno que no existe.

## 2. Hallazgo antes de desplegar

`supabase migration list --linked` mostró que el proyecto real ya tenía
aplicadas dos migraciones sin archivo local (`20260720200109`,
`20260720200141`, aplicadas 2026-07-20 20:01) — contenido de D3.2/D3.4
cargado durante el ensayo MCP de D4.6, con otro identificador de versión.
D2, D3.5.1, D3.5.2 y D3.5.3 nunca se habían aplicado remotamente.

Se verificó que D3.2, D3.4, D3.5.1, D3.5.2 y D3.5.3 son `create or replace
function` y `revoke`/`grant` (repetibles sin riesgo); D2 es `alter column
... set not null` (repetible: no falla si ya está aplicado). Ningún archivo
pendiente crea tablas nuevas.

## 3. Procedimiento ejecutado

1. Dump de solo lectura del esquema real (`supabase db dump --linked
   --schema public`), sin datos, para tener por fin una fuente confiable
   del esquema vivo completo.
2. Respaldo fresco completo (`roles.sql`, `schema.sql`, `data.sql`) vía
   `supabase db dump --linked`, con hash SHA-256, movido a
   `OneDrive/Documents/BeautyOS Backups/BeautyOS_Backup_2026-07-22_pre_tramo_d_deploy/`.
3. `supabase migration repair --status reverted 20260720200109
   20260720200141` — solo edita la tabla de seguimiento remota; no toca
   ninguna función, tabla ni dato.
4. `supabase db push --linked` con autorización explícita del propietario:
   aplicó `20260720175139` (D2), `20260720183122` (D3.2), `20260720190528`
   (D3.4), `20260720222044` (D3.5.1), `20260720225344` (D3.5.2) y
   `20260722175530` (D3.5.3), sin errores.
5. `supabase migration list --linked` y `supabase db push --linked
   --dry-run` confirman: **"Remote database is up to date"**.

## 4. Estado resultante

- El único proyecto Supabase real ahora tiene: `branch_id NOT NULL` en las
  15 tablas operativas, las 6 RPC `_v2` conscientes de sede, las 6 RPC
  heredadas sustituidas sin acceso externo, los 8 triggers de sede
  endurecidos, los privilegios de las 46 RPC heredadas reconciliados, y la
  autorización basada en `tenant_memberships` (no `user_profiles`) en los
  seis puntos de D3.5.3.
- NC-D-02, NC-D-03 y NC-D-04 (`TRAMO_D5_PRE_2...md`) quedan cerradas en
  producción, no solo localmente.
- No se tocó ningún dato de negocio (el `push` no incluye DML); el respaldo
  previo cubre cualquier reversión necesaria.

## 5. Pendiente (deuda no bloqueante, ya conocida)

- Retiro completo de las 24 RPC heredadas sin consumidor (siguen sin
  `EXECUTE` externo, solo pendiente su eliminación física).
- Protección de contraseñas filtradas sigue desactivada en Auth — activar
  antes de abrir registro a desconocidos.
- El proyecto sigue en plan Free (pausa por inactividad, sin respaldos
  automáticos) — subir a un plan pago antes de aceptar el primer cliente
  de pago.

## 6. Siguiente bloque

Con el esquema del único proyecto real ya sincronizado y estable, el
siguiente bloque de valor es el sistema de suscripciones/entitlements
(`01_arquitectura/SUSCRIPCION_Y_ENTITLEMENTS.md`), diseñado pero sin
construir, seguido del registro self-serve de un tenant nuevo.
