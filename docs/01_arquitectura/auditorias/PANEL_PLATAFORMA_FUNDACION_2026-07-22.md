# Fundación del panel de plataforma (platform_owner)

**Fecha:** 22 de julio de 2026
**Estado:** desplegado en el único proyecto real
**Producción modificada:** sí (aditivo únicamente)

## 1. Objetivo

Antes de esta migración no existía ningún dato que distinguiera al
propietario de BeautyOS de un usuario cualquiera de un tenant. Se agrega la
identidad de plataforma (ADR-001: plataforma, tenant y sede son fronteras
distintas) y las acciones mínimas de administración de suscripciones que el
propietario pidió: ver todos los tenants y poder suspender/reactivar/
extender una prueba, con motivo y auditoría.

## 2. Qué incluye

- `public.platform_operators`: `platform_owner` / `platform_operator`,
  separada por completo de `tenant_memberships`. Un usuario puede tener
  membresías de tenant y, además, ser platform_operator — son identidades
  independientes, tal como exige `ROLES_Y_PERMISOS.md`.
- `get_my_platform_role()`: para que Flutter decida si muestra la entrada
  al panel de plataforma.
- `platform_list_tenants()`: cualquier rol de plataforma (owner u operator)
  puede ver todos los tenants con su plan y estado de suscripción.
- `platform_suspend_tenant`, `platform_reactivate_tenant`,
  `platform_extend_trial`: **solo `platform_owner`**; exigen motivo
  obligatorio; cada acción queda auditada en `subscription_events`
  (`suspended_by_platform`, `reactivated_by_platform`, `trial_extended`).

## 3. Identidad sembrada

El propietario creó su cuenta real (`juankdev2026@gmail.com`) directamente
en el panel de Supabase (Authentication → Users), separada de las dos
cuentas de prueba del tenant ficticio "Bella Mujer". Se confirmó su UID
(`dbee91f0-36e0-4bd8-9303-fe173418ba55`) por captura de pantalla y se
sembró como `platform_owner` único hasta ahora.

## 4. Prueba y despliegue

Postgres real desechable con el esquema sintético (`supabase/sql/132`) más
la fundación de suscripciones. `supabase/sql/136_verify_panel_plataforma_fundacion.sql`:
**12 de 12 verificaciones aprobadas**, incluyendo: un usuario sin rol de
plataforma no puede listar tenants; el owner ve ambos tenants sintéticos;
suspender sin motivo falla; suspender y reactivar funcionan y quedan
auditados; extender la prueba solo aplica a un tenant en `trialing`; un
`platform_operator` puede listar pero no suspender (solo el owner puede).

`flutter analyze`: sin hallazgos. `flutter test`: 5 pruebas aprobadas.

Desplegado al único proyecto real con `supabase db push --linked`; dry-run
confirma sincronía total.

## 5. Fuera de alcance (bloques aparte)

- Pantalla de Flutter para este panel (hoy solo existe el backend).
- Flujo de soporte con acceso temporal y auditado a datos operativos de un
  tenant (`ROLES_Y_PERMISOS.md`, sección 6) — distinto de administrar la
  suscripción.
- Gestión de otros `platform_operators` desde la UI (hoy solo la semilla
  inicial; agregar un segundo operador requiere SQL manual por ahora).
- Integración de pasarela de pago (Wompi): pendiente porque el propietario
  debe crear la cuenta comercial presencialmente; no bloquea este bloque.

## 6. Siguiente bloque

Con el backend del panel de plataforma listo, el propietario decide entre:
construir la pantalla de Flutter para este panel, o continuar con la
pantalla de registro self-serve (bloque anterior, también sin UI todavía).
