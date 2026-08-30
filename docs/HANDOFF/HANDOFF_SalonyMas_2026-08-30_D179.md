# HANDOFF Salón y Más — 30 de agosto de 2026 ("Limpieza Técnica y Reenvío de Soporte", D-174 a D-180)

**Bloque documentado:** decisiones **D-174 a D-180** · Pasos **8.1 al 8.7** de la **FASE 8 — Limpieza técnica, seguridad y preparación de lanzamiento**.
- **8.1 (D-176 / H-05):** Purga de 30 funciones huérfanas en DB y preservación de 6 funciones internas de tickets con comentarios de protección.
- **8.2 (D-175 / H-08):** Blindaje de columnas de dinero en pesos COP enteros (`round(x)` en comisiones y 14 `CHECK NOT VALID`).
- **8.3 (D-174 / H-11):** Alineación de permisos sueltos de Storage en `beautyos_can_upload_work_photo`.
- **8.4 (D-177 / Hallazgo U):** Blindaje perimetral de Edge Functions en `supabase/config.toml` (`verify_jwt = true`), registro formal de Smart Checkout V2 y despliegue en la nube.
- **8.5 (D-178 / Hallazgo S):** Clarificación de pantalla de acceso y registro para colaboradores invitados (desacople de creación de negocio vs. inicio de sesión de empleado invitado).
- **8.6 (D-179 / Hallazgo V):** Gestión de sedes para usuarios de equipo multi-sede (RPCs `get_tenant_user_branches`, `set_tenant_user_branches`, sincronización en `branch_stylists`, modelo `UserBranchAccess` y selector interactivo de sedes en `UsuariosPage`).
- **8.7 (D-180 / Idea I-12):** Reenvío de correos de soporte `hola@salonymas.com` al Gmail del propietario mediante Cloudflare Email Routing (arquitectura de cero colisiones con Resend, documentación operativa en `docs/02_operacion/CORREO_Y_DOMINIO.md`).

**Estado:** `flutter analyze` 100% limpio (0/0), **262 de 262 pruebas en verde** (`flutter test`).

---

## 1. Qué se construyó en este bloque

### 1.1 Base de datos y Migraciones SQL
- **Paso 8.1:** `supabase/migrations/20260830160000_purga_funciones_huerfanas_h05.sql` y Control `195_test_purga_funciones_huerfanas_h05.sql` (30 funciones purgadas, 6 protegidas).
- **Paso 8.2:** `supabase/migrations/20260830140000_regla_dinero_entero_h08.sql` y Control `194_test_regla_dinero_entero_h08.sql` (0 violaciones históricas, comisiones enteras).
- **Paso 8.3:** `supabase/migrations/20260830120000_alinear_permiso_storage_h11.sql` y Control `193_test_alinear_permiso_storage_h11.sql` (Storage revocado de anon/public, asignado a authenticated).
- **Paso 8.6:** `supabase/migrations/20260830170000_gestion_sedes_usuarios_equipo_hallazgo_v.sql` y Control `196_test_gestion_sedes_usuarios_hallazgo_v.sql`:
  - `get_tenant_user_branches(p_profile_id uuid)`: consulta sedes del negocio con flags `has_access` e `in_catalog`.
  - `set_tenant_user_branches(p_profile_id uuid, p_branch_ids uuid[])`: asigna/desasigna en `branch_memberships` y sincroniza automáticamente `branch_stylists` si el usuario es estilista.
  - Reglas de integridad: `owner` protegido con acceso total, auto-modificación bloqueada, usuarios activos de equipo no pueden quedar con 0 sedes.

### 1.2 Edge Functions y Seguridad Perimetral (Paso 8.4)
- En `supabase/config.toml`:
  - `verify_jwt = true` en: `send-invitation-email`, `send-low-stock-alert`, `create-epayco-session`.
  - `verify_jwt = false` en: `epayco-webhook`, `verify-epayco-transaction`, `send-subscription-expiry-alerts`.
- Desplegadas las 6 funciones en Supabase Cloud. Verificado que llamadas sin JWT son rechazadas con HTTP 401 perimetral sin despertar contenedores Deno.

### 1.3 Frontend Flutter (Pasos 8.5 y 8.6)
- **`lib/pages/login_page.dart` & `lib/pages/register_page.dart` (Paso 8.5):**
  - Subtítulo neutral en login: *"Ingresa a tu cuenta"*.
  - Tarjeta de orientación para colaboradores invitados: *"¿Te invitaron a un equipo? Inicia sesión con el correo de tu invitación"*.
  - Botón delimitado para nuevos negocios: *"Registra tu negocio gratis"*.
  - `RegisterPage` aclara *"Registra tu negocio en Salón y Más"* y pie con enlace *"¿Ya tienes cuenta o te invitaron a un equipo? Inicia sesión"*.
- **`lib/models/user_branch_access.dart` (Paso 8.6):**
  - Modelo para encapsular el acceso por sede de un colaborador.
- **`lib/services/tenant_users_service.dart` (Paso 8.6):**
  - Métodos `getUserBranches(String profileId)` y `setUserBranches({required String profileId, required List<String> branchIds})`.
- **`lib/pages/users_page.dart` (Paso 8.6):**
  - En `_ManageUserDialog`: sección interactiva **"Sedes autorizadas"** con checkboxes por sede, indicador de sede principal y advertencia de actividad en catálogo para estilistas.
  - Valida que al guardar se mantenga al menos 1 sede activa para usuarios con rol de equipo.

### 1.4 Reenvío de Soporte en Cloudflare (Paso 8.7 / D-180)
- Configuración y guía de Cloudflare Email Routing para reenviar respuestas y mensajes a `hola@salonymas.com` directo a `juankdev2026@gmail.com`.
- Documentada en `docs/02_operacion/CORREO_Y_DOMINIO.md` la arquitectura de cero colisiones DNS: Resend envía por subdominio `send.salonymas.com`, mientras que Cloudflare recibe en la raíz `salonymas.com`.

---

## 2. Lo que está completado y lo que está pendiente

### Completado:
- Pasos 8.1, 8.2, 8.3, 8.4, 8.5, 8.6 y 8.7 terminados, probados y documentados.
- 262 pruebas automatizadas pasando al 100%. `flutter analyze` con 0 advertencias y 0 errores.
- Decisiones D-174 a D-180 registradas en `docs/00_producto/REGISTRO_DE_DECISIONES.md`.
- `docs/00_producto/PLAN_MAESTRO.md` actualizado con el cierre de los hallazgos H-05, H-08, H-11, U, S, V y la Idea I-12.

### Pendiente en la Fase 8:
- **Paso 8.8 (Broche de Oro):** Onboarding interactivo guiado *"Primeros pasos"* en el Dashboard para nuevos salones registrados (checklist de bienvenida para cargar servicios, horarios, estilistas y portafolio). El propietario ha indicado reservarlo como el último paso final.

---

## 3. Guía de aplicación de Base de Datos para el Propietario

Las migraciones de la Fase 8 están versionadas en `supabase/migrations/` con sus respectivos controles transaccionales en `supabase/sql/`:

Para aplicar la migración del Paso 8.6:
```powershell
# 1. Aplicar migración
powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" -Archivo "supabase\migrations\20260830170000_gestion_sedes_usuarios_equipo_hallazgo_v.sql"

# 2. Correr control de verificación (termina en ROLLBACK, no deja residuos)
powershell -ExecutionPolicy Bypass -File "scripts\aplicar_sql.ps1" -Archivo "supabase\sql\196_test_gestion_sedes_usuarios_hallazgo_v.sql"
```

---

## 4. Prompt para retomar en cualquier momento

```
Lee el HANDOFF más reciente en docs/HANDOFF/ (bloque D-174 a D-180: Fase 8, pasos 8.1 al 8.7 completados).
El proyecto está 100% limpio en flutter analyze (0/0) y 262 de 262 pruebas pasando en flutter test.

Pendiente final de la Fase 8 (reservado como último del todo):
- Paso 8.8: Onboarding interactivo guiado "Primeros pasos" en Dashboard para nuevos salones.
```

