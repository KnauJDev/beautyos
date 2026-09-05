# HANDOFF Salón y Más — 5 de septiembre de 2026 ("Desenmascaramiento de errores de pasarela ePayco y flujo directo de registro para colaboradores invitados", D-213)

**Bloque documentado:** decisión **D-213** · Paso **8.36** de la **FASE 8**.

**Estado:** ✅ **CERRADO.** `flutter analyze` 0/0 y **387 de 387 pruebas en verde**.

> El bloque anterior (D-212) está archivado en
> `docs/_archivo/handoffs/HANDOFF_SalonyMas_2026-09-04_D212.md`.

---

## 1. Qué cambió

Se resolvieron de raíz los dos incidentes de flujo reportados por el usuario tras la activación de tarifas personalizadas:

1. **Desenmascaramiento de errores reales en ePayco Checkout (`epayco_checkout_service.dart`):**
   - **El bug de fondo:** ePayco denomina internamente sus transacciones como *"sesiones de pago"* (*payment sessions*). El interceptor de errores en Flutter filtraba genéricamente `errorStr.contains('sesión') || errorStr.contains('session')`. Cuando la pasarela o la Edge Function retornaba un mensaje como *"No se pudo generar la sesión de pago en ePayco"*, la app lo categorizaba falsamente como vencimiento de la sesión de autenticación de Supabase, arrojando en bucle: *"Tu sesión ha expirado. Por favor inicia sesión de nuevo para continuar con el pago."*.
   - **La solución:** Se desacopló la expiración de autenticación de los errores de pasarela. La advertencia de sesión de usuario solo se muestra cuando `sesionFresca()` arroja una expiración de auth real o la Edge Function responde HTTP 401 con detalles explícitos de JWT/token/autenticación. Cualquier otro fallo de pasarela/servidor se muestra con su mensaje limpio y fidedigno: *"No se pudo abrir la pasarela de ePayco: $limpio"*.

2. **Flujo y pantalla directa de registro para colaboradores invitados (`LoginPage` y `RegisterPage`):**
   - **El bug de fondo:** Al invocar `send-invitation-email` para un nuevo estilista/asistente (ej. `elboga033@gmail.com`), el correo instruye al colaborador a ingresar a `salonymas.com`. En `LoginPage`, el formulario principal solo ofrecía "Ingresar" con credenciales existentes en `auth.users` (lo que generaba `Invalid login credentials` al no tener aún contraseña creada), y la única vía alternativa era "Registra tu negocio gratis", diseñada exclusivamente para dueños de nuevos salones.
   - **La solución:**
     * En `LoginPage`, se mejoró la tarjeta informativa para colaboradores integrando una acción destacada: `¿Primera vez? Crea tu contraseña de colaborador →`.
     * En `RegisterPage`, se añadió el modo `isCollaborator: true`. Al activarse, la pantalla cambia su título y propósito a *"Crea tu cuenta de colaborador"* (*"Ingresa el correo al que te llegó la invitación y define tu contraseña."*), botón *"Crear mi cuenta"* y enlace de retorno a login, ocultando el botón comercial de planes.
     * Al registrarse con `signUp()`, `_BeautyOSHomeState._loadHomeContext` detecta automáticamente la invitación pendiente mediante `getMyPendingInvitation()` y lo conduce de inmediato a `AcceptInvitationPage`.

3. **Aclaración arquitectónica sobre prueba vencida (D-014/D-046/D-053):**
   - Bajo el modelo de entitlements, una prueba vencida bloquea estrictamente la creación de citas en la agenda y las reservas públicas de clientes (`public_create_booking`), pero permite a los dueños y administradores configurar el catálogo de servicios, colaboradores, gastos y operar la plataforma interna para facilitar su reactivación.

---

## 2. Verificación y Suite de Pruebas

- **Análisis estático:** `flutter analyze` 0/0 (0 errores, 0 advertencias).
- **Suite de pruebas:** **387 de 387 pruebas en verde** (`flutter test`).
- **Pruebas actualizadas y añadidas:** `test/terms_and_privacy_test.dart` y `test/epayco_checkout_test.dart` verificando modos de registro de colaborador vs. negocio, tarjeta de invitación en login y discriminación de errores de pasarela vs. sesión expirada.

---

## 3. Lo que sigue abierto

1. La otra mitad de **UX-07** (Nequi vs. Daviplata en BD y Reportes).
2. El tercio de **TL-09**: acotar la consulta histórica de Tickets.
3. **HSTS** en el panel de Cloudflare — paso 8.25, 👤 propietario.
4. Fase 3 con dos casillas de 👤 abiertas (3.2 DIAN/IVA, 3.4 Supabase a Pro).

---

## 4. Prompt para retomar

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (D-213: desenmascaramiento de errores
de ePayco y flujo directo de registro para colaboradores invitados).

flutter analyze 0/0 y 387/387 pruebas en verde.

Próximo paso según Plan Maestro: continuar con las tareas de la Fase 8 o atender
observaciones de verificación en producción.
```
