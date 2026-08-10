# Registro self-serve de un negocio nuevo

**Fecha:** 22 de julio de 2026
**Estado:** desplegado en el único proyecto real
**Producción modificada:** sí (aditivo únicamente)

## 1. Objetivo

Permitir que alguien se registre solo (después de `auth.signUp`) y quede con
su negocio, su sede principal y una prueba gratis activa, sin intervención
manual por SQL como se hacía hasta ahora (`supabase/sql/034`, `042`).

## 2. Decisión de negocio aplicada

El propietario definió: **21 días de prueba gratis**, plan **Profesional**
por defecto (para mostrar todo el potencial del producto durante la
prueba). Ambos valores están codificados en
`public.register_tenant()` — cambiarlos requiere una migración nueva, no
son constantes de Flutter.

## 3. Qué hace `register_tenant(business_name, owner_full_name, whatsapp, business_type?)`

En una sola transacción atómica: crea el `tenant`, su primera `branch`
(`slug = 'principal'`, `is_primary = true`), el `user_profile` del
propietario (identidad, rol `owner`), la `tenant_membership` (`tenant_owner`,
autorización), la `branch_membership` correspondiente, y la
`tenant_subscription` en estado `trialing` al plan Profesional con
`trial_ends_at = now() + 21 días`, más su evento en `subscription_events`.

Reglas:

- Requiere sesión autenticada (`auth.uid()` no nulo) — se llama después de
  `signUp`, nunca antes.
- Un usuario que ya pertenece a un negocio no puede registrar otro (evita
  duplicados por doble clic o reintento).
- Nombre del negocio, nombre del propietario y WhatsApp son obligatorios;
  `contact_email` del tenant se toma de `auth.users.email`, no se pide de
  nuevo.

## 4. Prueba y despliegue

Mismo método que los bloques anteriores: Postgres real desechable con el
esquema sintético (`supabase/sql/132`, actualizado en este bloque con las
columnas reales de `tenants`/`branches`/`branch_memberships` — antes eran
una aproximación basada en fragmentos de RPC; ahora están contrastadas
contra el dump de solo lectura real tomado en el cierre del Tramo D).

`supabase/sql/135_verify_registro_self_serve_tenant.sql`: **14 de 14
verificaciones aprobadas**, incluyendo: rechazo sin sesión, duración exacta
de 21 días, consistencia de las 6 filas creadas, plan Profesional con
prueba habilitando todas las funcionalidades vía `get_my_entitlements()`,
bloqueo de doble registro para el mismo usuario, y que un segundo usuario
distinto sí puede registrar su propio negocio en paralelo.

`flutter analyze`: sin hallazgos. `flutter test`: 5 pruebas aprobadas (no se
tocó Dart en este bloque — la pantalla de registro en Flutter es un paso
aparte).

Desplegado al único proyecto real con `supabase db push --linked`; dry-run
confirma sincronía total.

## 5. Fuera de alcance (bloques aparte)

- **Pantalla de Flutter para registrarse** (esta migración solo deja lista
  la RPC; todavía no hay UI que la llame).
- Verificación de correo/teléfono, invitar a un negocio existente (ya
  existe vía `update_tenant_user_access`), pasarela de pago al terminar la
  prueba, y qué pasa automáticamente cuando `trial_ends_at` se cumple sin
  pago (hoy no hay ningún job que cambie el estado de `trialing` a
  `past_due`/`suspended`; es trabajo pendiente del bloque de cobro).

## 6. Siguiente bloque

Con el backend de registro listo, el bloque de mayor valor ahora es
**la pantalla de Flutter de registro** (llama a `register_tenant`, con
loading/empty/error/éxito) para poder de verdad probar el flujo de punta a
punta antes de salir a vender.
