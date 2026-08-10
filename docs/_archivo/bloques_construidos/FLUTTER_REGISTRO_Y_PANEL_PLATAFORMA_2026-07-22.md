# Flutter: registro self-serve y panel de plataforma

**Fecha:** 22 de julio de 2026
**Estado:** desplegado (Flutter Web); verificado de extremo a extremo contra el único proyecto real

## 1. Objetivo

Construir la interfaz que finalmente usa el backend de los tres bloques
anteriores (suscripciones/entitlements, registro self-serve, panel de
plataforma), y probarla de verdad — no solo con pruebas SQL — para llegar a
un flujo de registro público real.

## 2. Archivos nuevos

- `lib/services/tenant_registration_service.dart`, `lib/services/platform_service.dart`
- `lib/models/platform_tenant_summary.dart`
- `lib/pages/register_page.dart` (crea solo el acceso: correo/contraseña)
- `lib/pages/complete_tenant_setup_page.dart` (pide los datos del negocio;
  llama a `register_tenant`)
- `lib/pages/platform_panel_page.dart` (lista de tenants + suspender/
  reactivar/extender prueba, solo visible para roles de plataforma)
- `lib/pages/authenticated_router.dart` (decide panel de plataforma vs. app
  de negocio según `get_my_platform_role()`)
- `.claude/launch.json` (config para previsualizar la app web localmente)

## 3. Tres bugs reales encontrados probando de extremo a extremo

Ninguno se encontró por revisión de código; los tres aparecieron al probar
el flujo real en el navegador contra el único proyecto real, y cada uno se
diagnosticó con evidencia antes de corregirlo:

### 3.1 Condición de carrera en el registro

La primera versión de `RegisterPage` creaba la cuenta (`signUp`) y en la
misma pantalla llamaba a `register_tenant`. `AuthGate` escucha el estado de
sesión de forma global e independiente, y reaccionaba a la sesión nueva
**antes** de que `register_tenant` alcanzara a ejecutarse, reemplazando el
árbol de widgets a mitad de camino. Corrección: `RegisterPage` ahora solo
crea el acceso; los datos del negocio se piden en una pantalla aparte
(`CompleteTenantSetupPage`), montada de forma estable después de que la
sesión ya existe. Una sola fuente de verdad para llamar a `register_tenant`
elimina la carrera por diseño, no por parche.

### 3.2 `getMyProfile()` fallaba con HTTP 406 en el primer login real

`get_my_profile()` es `returns table` (un conjunto), no un escalar.
`.maybeSingle()` le pide a PostgREST forzar el arreglo a un solo objeto; con
0 filas (exactamente el caso de un usuario recién registrado, antes de
`register_tenant`) eso produce un error HTTP 406
(`PGRST116: Cannot coerce the result to a single JSON object`) en vez de un
cuerpo vacío. Nunca se había visto antes porque hasta ahora todo usuario de
prueba ya tenía perfil sembrado a mano. Corrección: `MyProfileService`
trata la respuesta como lista desde el principio (mismo patrón ya usado en
`BranchContextService`), sin depender de `.maybeSingle()`.

### 3.3 `register_tenant()` no dejaba la sede lista para operar

El backend creaba tenant + sede + owner + membresía + suscripción, pero no
sembraba `business_hours`, `appointment_policies` ni `commission_policies`
para la sede nueva. Configuración, Horarios y Política de citas usan
`.single()` en Flutter y se habrían roto con el mismo error 406 en cuanto
el propietario entrara a esas pantallas. Corrección: migración
`20260722232511_registro_self_serve_datos_base.sql` — `register_tenant`
ahora también inserta 7 filas de horario (lunes a sábado 08:00-20:00,
domingo cerrado) y una fila de política de citas y de comisión, usando los
valores por defecto ya existentes en cada tabla (no se inventó ninguna
regla de negocio nueva).

## 4. Cambio de método de verificación (a partir de este bloque)

Los tres bugs de la sección 3 se encontraron en una secuencia de "arreglar
→ reconstruir Flutter (2-3 min) → probar en el navegador → error nuevo",
porque las pruebas SQL previas corrían contra un esquema sintético
reconstruido de memoria, no contra el esquema real. Se descubrió
`supabase db query --linked -f archivo.sql`: ejecuta SQL de verdad contra
el único proyecto real (protegido con `begin; ... rollback;` cuando escribe
algo), sin necesitar contraseña de base de datos ni exponer secretos. A
partir de ahora, toda RPC nueva se prueba primero así, antes de tocar
Flutter — más rápido (segundos, no minutos de rebuild) y sin el riesgo de
que el esquema sintético esté desactualizado, que fue la causa raíz de los
tres bugs.

Con ese método se verificaron, de solo lectura y contra el tenant real
"Pepito Pelos y Uñas" (creado durante esta misma prueba), las RPC que
tocan las primeras pantallas de un owner recién registrado:
`get_my_profile`, `get_my_branch_context_v2`, `get_business_settings`,
`get_commission_policy`, `get_dashboard_metrics_v2`,
`get_appointment_policy_v2`, `get_business_hours_v2` — las 7 responden
correctamente. Evidencia en `supabase/sql/138` a `140b`.

## 5. Limitación de entorno (no relacionada con el código)

El navegador embebido de esta sesión de herramientas no pudo tomar
capturas de pantalla ("Browser pane is not displayed"). La verificación
visual real la hizo el propietario directamente en Chrome, sirviendo
`flutter build web` de forma estática en `localhost`. `flutter run -d
web-server` requiere ademas la extension "Dart Debug" de Chrome, no
disponible aqui; se uso `flutter build web --pwa-strategy=none` (sin
service worker, para evitar cache durante las pruebas manuales).

## 6. Pendiente conocido

- Límite de correo de confirmación del plan gratuito de Supabase Auth
  (pocos envíos por hora): bloquea pruebas repetidas de registro en la
  misma sesión. El propietario decidió esperar el reinicio del límite en
  vez de desactivar la confirmación de correo temporalmente. Antes de
  abrir registro público real se necesita un proveedor SMTP propio
  (Resend/SendGrid/Postmark).
- El tenant de prueba "Pepito Pelos y Uñas" (creado durante esta
  verificación) queda en el proyecto real; es una cuenta de prueba
  identificable, sin impacto, pero conviene limpiarla antes del
  lanzamiento real.
- `flutter build web --pwa-strategy=none` es apropiado para pruebas
  locales; el build de producción real debe decidir explícitamente si
  quiere PWA/offline antes de desplegar a un dominio público.

## 7. Siguiente bloque

Con el registro self-serve y el panel de plataforma verificados de extremo
a extremo, el siguiente paso natural es la reserva pública de cliente
(prioridad 7 del plan maestro) — es lo que un salón le muestra a sus
propios clientes, y el argumento de venta más fuerte para salir a ofrecer
BeautyOS.
