# Fundación de suscripciones y entitlements

**Fecha:** 22 de julio de 2026
**Estado:** desplegado en el único proyecto real
**Producción modificada:** sí (aditivo únicamente; sin DDL destructivo)

## 1. Objetivo

Construir el modelo de datos definido en
`01_arquitectura/SUSCRIPCION_Y_ENTITLEMENTS.md` (diseño aprobado el
2026-07-19, sin implementar hasta ahora). Es el prerrequisito técnico para
ofrecer un periodo de prueba gratis y, después, cobrar.

## 2. Qué incluye

- Tablas `plans`, `features`, `plan_features`, `tenant_subscriptions`,
  `subscription_events`, `tenant_feature_overrides`. RLS activa, sin
  políticas directas: todo acceso pasa por RPC (mismo patrón que
  `tenant_memberships`).
- `private.beautyos_resolve_entitlement(tenant_id, feature_key)`: resuelve
  en el orden del diseño (suscripción operativa → plan vigente → feature del
  plan → override temporal). El paso 5 del diseño ("consumo actual si existe
  límite") **no se implementó de forma genérica a propósito**: cada RPC que
  necesite contar algo (sedes, usuarios) lo hará con su propio conteo; no
  existe todavía ninguna RPC que dependa de eso.
- RPC de lectura: `get_my_entitlements()` (gatear UI del tenant actual),
  `get_my_tenant_subscription()` (owner/admin, para un banner de prueba/pago
  pendiente), `list_public_plans()` (pública/anónima, para una futura página
  de precios).
- Semillas: los 3 planes (Básico/Business/Profesional) y las 5
  funcionalidades ya nombradas en el diseño, con la matriz exacta de la
  sección 2 del documento rector.

## 3. Decisiones tomadas sin autorización de negocio (documentadas, no inventadas)

- **Precios quedan `NULL`** ("por definir"): no existe todavía un precio de
  lista decidido por el propietario para ningún plan.
- **Límites numéricos (sedes, usuarios, mensajes, almacenamiento) quedan sin
  definir**: el diseño rector los menciona pero no fija cifras. No se
  inventaron números.
- **Los tenants existentes reciben una suscripción `active` en Profesional
  sin fecha de fin**: son cuentas de desarrollo (no clientes reales), y así
  no pierden acceso el día que una RPC empiece a exigir un entitlement.

## 4. Fuera de alcance (bloques aparte)

Pasarela de pago y webhooks, alta de tenant self-serve con periodo de
prueba automático, panel de plataforma para gestionar suscripciones, y la
integración de `get_my_entitlements()`/`beautyos_resolve_entitlement()`
dentro de las RPC existentes (hoy ninguna RPC de negocio consulta
entitlements todavía; esta migración solo construye el cimiento).

## 5. Prueba y despliegue

Mismo método que D3.5.3: Postgres real desechable (imagen de Supabase) con
el esquema sintético ya existente (`supabase/sql/132`) más la migración real
de D3.5.3 y esta migración nueva. Prueba de comportamiento:
`supabase/sql/134_verify_suscripciones_entitlements_fundacion.sql`.

**Resultado: 9 de 9 verificaciones aprobadas**, incluyendo: sin suscripción
no autoriza nada; Básico no incluye inventario; Business sí lo incluye pero
no portafolio; un override temporal habilita una función sin cambiar de
plan; un override vencido no aplica; una suscripción `cancelled` bloquea
todo aunque exista un override activo; `list_public_plans()` responde sin
sesión (anon).

`flutter analyze`: sin hallazgos. `flutter test`: 5 pruebas aprobadas.

Desplegado al único proyecto real con `supabase db push --linked` (respaldo
previo del mismo día, ver `TRAMO_D_CIERRE_PRODUCTIVO_2026-07-22.md`).
`supabase db push --linked --dry-run` confirma sincronía total.

## 6. Siguiente bloque

Registro self-serve de un tenant nuevo (crear tenant + membresía owner +
suscripción `trialing` automática al plan que el propietario decida ofrecer
por defecto). Requiere que el propietario decida: duración del periodo de
prueba y plan por defecto al registrarse.
